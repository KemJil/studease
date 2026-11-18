import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';

/// The five subtle sounds used across StudEase.
///
/// `volume` keeps the chimes quiet and `minGap` throttles bursts so rapid taps
/// never clip or stutter.
enum SoundEffect {
  flip('flip.wav', 0.30, Duration(milliseconds: 90)),
  correct('correct.wav', 0.36, Duration(milliseconds: 120)),
  wrong('wrong.wav', 0.26, Duration(milliseconds: 120)),
  streak('streak.wav', 0.34, Duration(milliseconds: 200)),
  tap('tap.wav', 0.20, Duration(milliseconds: 45));

  const SoundEffect(this.fileName, this.volume, this.minGap);

  final String fileName;
  final double volume;
  final Duration minGap;

  /// Path handed to `AssetSource`; `AudioCache` prepends `assets/`, so this
  /// resolves to `assets/sounds/<fileName>`.
  String get assetPath => 'sounds/$fileName';
}

/// One playback attempt. Injected by tests so they never touch a platform
/// channel; the device implementation lives in [SoundService].
typedef SoundPlayback = Future<void> Function(SoundEffect effect);

/// Plays the generated UI sounds in `assets/sounds`.
///
/// Guarantees:
/// * never throws and never blocks the UI (every plugin call is guarded);
/// * silent when the student mutes sound effects (`setEnabled(false)`);
/// * silent under `flutter test` (`FLUTTER_TEST`), so the suite never reaches
///   the audioplayers platform channel.
class SoundService {
  SoundService._(
    this._platformAudioAvailable, {
    SoundPlayback? playback,
    DateTime Function()? clock,
  }) : _playbackOverride = playback,
       _clock = clock ?? DateTime.now;

  /// App-wide instance used by the screens.
  static final SoundService instance = SoundService._(_detectPlatformAudio());

  /// Test seam: full behaviour without platform channels.
  @visibleForTesting
  factory SoundService.forTest({
    bool platformAudioAvailable = true,
    bool enabled = true,
    double volume = SoundService.defaultVolume,
    DateTime Function()? clock,
    SoundPlayback? playback,
  }) {
    final SoundService service = SoundService._(
      platformAudioAvailable,
      playback: playback,
      clock: clock,
    );
    service._enabled = enabled;
    service._volume = volume.clamp(0.0, 1.0).toDouble();
    return service;
  }

  /// Default playback gain (75 %), shared with `AppUser.soundVolume`.
  static const double defaultVolume = AppConstants.defaultSoundVolume;

  final bool _platformAudioAvailable;
  final SoundPlayback? _playbackOverride;
  final DateTime Function() _clock;

  /// One warmed player per effect so chimes can layer without waiting.
  final Map<SoundEffect, AudioPlayer> _players = <SoundEffect, AudioPlayer>{};
  final Map<SoundEffect, DateTime> _lastPlayedAt = <SoundEffect, DateTime>{};

  bool _enabled = true;
  double _volume = defaultVolume;
  bool _disposed = false;
  bool _preloadAttempted = false;

  /// True when the host can actually output audio (false under `flutter test`).
  bool get isPlatformAudioAvailable => _platformAudioAvailable;

  /// True when sound effects are switched on *and* can be heard.
  bool get enabled => _enabled && _platformAudioAvailable && !_disposed;

  /// Current gain, `0.0`–`1.0`. Mirrors `users/{uid}.soundVolume`.
  double get volume => _volume;

  /// True when a chime would actually be audible right now.
  bool get audible => enabled && _volume > 0;

  bool get _usesDevicePlayback => _playbackOverride == null;

  SoundPlayback get _playback => _playbackOverride ?? _playOnDevice;

  /// Mirrors `users/{uid}.soundEffectsEnabled`. Idempotent and safe to call
  /// from a build method: it never notifies listeners.
  void setEnabled(bool value) {
    _enabled = value;
    if (enabled) unawaited(preload());
  }

  /// Mirrors `users/{uid}.soundVolume`. Idempotent, clamped and never throws.
  void setVolume(double value) {
    if (value.isNaN || value.isInfinite) return;
    final double next = value.clamp(0.0, 1.0).toDouble();
    if (next == _volume) return;
    _volume = next;
    if (audible) unawaited(preload());
  }

  /// Effective gain for [effect]: its subtle base volume × the slider gain.
  double volumeFor(SoundEffect effect) =>
      (effect.volume * _volume).clamp(0.0, 1.0).toDouble();

  /// Best-effort warm-up: copies the five WAVs into the audio cache so the
  /// first chime is immediate. Runs at most once and never surfaces failures.
  Future<void> preload() async {
    if (!enabled || !_usesDevicePlayback || _preloadAttempted) return;
    _preloadAttempted = true;
    try {
      await AudioCache.instance.loadAll(<String>[
        for (final SoundEffect effect in SoundEffect.values) effect.assetPath,
      ]);
    } catch (error) {
      debugPrint('SoundService.preload skipped: $error');
    }
  }

  /// Plays [effect] when enabled. Fire-and-forget: the returned future never
  /// completes with an error.
  Future<void> play(SoundEffect effect) async {
    if (!audible) return;

    final DateTime now = _clock();
    final DateTime? last = _lastPlayedAt[effect];
    if (last != null && now.difference(last) < effect.minGap) return;
    _lastPlayedAt[effect] = now;

    try {
      // A streak win supersedes any answer chime still ringing.
      if (effect == SoundEffect.streak) await _stopOtherPlayers(effect);
      await _playback(effect);
    } catch (error) {
      debugPrint('SoundService.play(${effect.fileName}) skipped: $error');
    }
  }

  /// Releases the players; the service stays silent afterwards.
  Future<void> dispose() async {
    _disposed = true;
    final List<AudioPlayer> players = _players.values.toList(growable: false);
    _players.clear();
    for (final AudioPlayer player in players) {
      try {
        await player.dispose();
      } catch (error) {
        debugPrint('SoundService.dispose skipped: $error');
      }
    }
  }

  // Device playback -----------------------------------------------------------

  Future<void> _playOnDevice(SoundEffect effect) async {
    final AudioPlayer player = await _ensurePlayer(effect);
    await player.stop();
    await player.play(AssetSource(effect.assetPath), volume: volumeFor(effect));
  }

  Future<AudioPlayer> _ensurePlayer(SoundEffect effect) async {
    final AudioPlayer? cached = _players[effect];
    if (cached != null) return cached;

    final AudioPlayer player = AudioPlayer(playerId: 'studease_${effect.name}');
    _players[effect] = player;
    await player.setPlayerMode(PlayerMode.lowLatency);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(effect.assetPath));
    return player;
  }

  Future<void> _stopOtherPlayers(SoundEffect keep) async {
    for (final MapEntry<SoundEffect, AudioPlayer> entry in _players.entries) {
      if (entry.key == keep) continue;
      try {
        await entry.value.stop();
      } catch (error) {
        debugPrint('SoundService stop(${entry.key.fileName}) skipped: $error');
      }
    }
  }

  /// `flutter test` starts the tester with `FLUTTER_TEST=true`.
  static bool _detectPlatformAudio() {
    try {
      return Platform.environment['FLUTTER_TEST'] != 'true';
    } catch (error) {
      debugPrint('SoundService environment check skipped: $error');
      return true;
    }
  }
}
