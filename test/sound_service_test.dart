import 'package:flutter_test/flutter_test.dart';
import 'package:studease/core/app_constants.dart';
import 'package:studease/models/app_user.dart';
import 'package:studease/services/sound_service.dart';

void main() {
  group('SoundEffect', () {
    test('maps every effect to an asset-relative wav path', () {
      expect(SoundEffect.flip.assetPath, 'sounds/flip.wav');
      expect(SoundEffect.correct.assetPath, 'sounds/correct.wav');
      expect(SoundEffect.wrong.assetPath, 'sounds/wrong.wav');
      expect(SoundEffect.streak.assetPath, 'sounds/streak.wav');
      expect(SoundEffect.tap.assetPath, 'sounds/tap.wav');
    });

    test('keeps the chimes quiet and throttle-safe', () {
      for (final SoundEffect effect in SoundEffect.values) {
        expect(effect.volume, greaterThan(0));
        expect(effect.volume, lessThanOrEqualTo(0.4));
        expect(effect.minGap, greaterThan(Duration.zero));
      }
    });
  });

  group('SoundService', () {
    test('stays muted when platform audio is unavailable', () async {
      int calls = 0;
      final SoundService service = SoundService.forTest(
        platformAudioAvailable: false,
        playback: (SoundEffect effect) async => calls += 1,
      );

      expect(service.isPlatformAudioAvailable, isFalse);
      expect(service.enabled, isFalse);
      await service.play(SoundEffect.correct);
      expect(calls, 0);
    });

    test('setEnabled(false) mutes an enabled service', () async {
      int calls = 0;
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async => calls += 1,
      );
      expect(service.enabled, isTrue);

      service.setEnabled(false);
      expect(service.enabled, isFalse);
      await service.play(SoundEffect.flip);
      expect(calls, 0);

      service.setEnabled(true);
      expect(service.enabled, isTrue);
      await service.play(SoundEffect.flip);
      expect(calls, 1);
    });

    test('plays through the injected seam when enabled', () async {
      final List<SoundEffect> played = <SoundEffect>[];
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async => played.add(effect),
      );

      await service.play(SoundEffect.flip);
      expect(played, <SoundEffect>[SoundEffect.flip]);
    });

    test('a failing playback never escapes', () async {
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async =>
            throw StateError('audio device unavailable'),
      );

      await expectLater(service.play(SoundEffect.wrong), completes);
      expect(service.enabled, isTrue);
    });

    test('throttles a rapid burst of the same effect', () async {
      DateTime now = DateTime(2026, 11, 17, 9);
      int calls = 0;
      final SoundService service = SoundService.forTest(
        clock: () => now,
        playback: (SoundEffect effect) async => calls += 1,
      );

      await service.play(SoundEffect.tap);
      await service.play(SoundEffect.tap);
      expect(calls, 1);

      now = now.add(const Duration(milliseconds: 200));
      await service.play(SoundEffect.tap);
      expect(calls, 2);
    });

    test('streak plays after an earlier answer chime', () async {
      final List<SoundEffect> played = <SoundEffect>[];
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async => played.add(effect),
      );

      await service.play(SoundEffect.correct);
      await service.play(SoundEffect.streak);
      expect(played, <SoundEffect>[SoundEffect.correct, SoundEffect.streak]);
    });

    test('dispose() silences the service', () async {
      int calls = 0;
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async => calls += 1,
      );

      await service.dispose();
      expect(service.enabled, isFalse);
      await service.play(SoundEffect.streak);
      expect(calls, 0);
    });

    test('the app singleton is muted under flutter test', () async {
      // `flutter test` starts the tester with FLUTTER_TEST=true, so no
      // platform channel (audioplayers) is ever reached by the suite.
      expect(SoundService.instance.isPlatformAudioAvailable, isFalse);
      expect(SoundService.instance.enabled, isFalse);
      await expectLater(SoundService.instance.play(SoundEffect.tap), completes);
    });
  });

  group('SoundService volume', () {
    test('defaults to the shared 75 % gain', () {
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async {},
      );

      expect(SoundService.defaultVolume, AppConstants.defaultSoundVolume);
      expect(service.volume, 0.75);
    });

    test('clamps the gain and ignores invalid values', () {
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async {},
      );

      service.setVolume(1.8);
      expect(service.volume, 1.0);
      service.setVolume(-2);
      expect(service.volume, 0.0);
      service.setVolume(0.4);
      service.setVolume(double.nan);
      expect(service.volume, 0.4);
    });

    test('scales every chime by the slider gain', () {
      final SoundService service = SoundService.forTest(
        volume: 0.5,
        playback: (SoundEffect effect) async {},
      );

      expect(
        service.volumeFor(SoundEffect.correct),
        closeTo(SoundEffect.correct.volume * 0.5, 1e-9),
      );
      service.setVolume(1);
      expect(
        service.volumeFor(SoundEffect.streak),
        closeTo(SoundEffect.streak.volume, 1e-9),
      );
      service.setVolume(0);
      expect(service.volumeFor(SoundEffect.correct), 0);
    });

    test('a zero gain silences playback without muting the toggle', () async {
      int calls = 0;
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async => calls += 1,
      );

      service.setVolume(0);
      expect(service.enabled, isTrue);
      expect(service.audible, isFalse);
      await service.play(SoundEffect.tap);
      expect(calls, 0);

      service.setVolume(0.5);
      expect(service.audible, isTrue);
      await service.play(SoundEffect.tap);
      expect(calls, 1);
    });

    test('applies the gain straight from the profile document', () async {
      final SoundService service = SoundService.forTest(
        playback: (SoundEffect effect) async {},
      );

      service.setVolume(0.35);
      expect(service.volume, 0.35);
      expect(service.volumeFor(SoundEffect.flip), closeTo(0.30 * 0.35, 1e-9));
    });
  });

  group('AppUser.soundEffectsEnabled', () {
    test('defaults to on for documents written before the field existed', () {
      final AppUser user = AppUser.fromMap('uid-a', const <String, dynamic>{});
      expect(user.soundEffectsEnabled, isTrue);
    });

    test('round-trips through fromMap, copyWith and toCreateMap', () {
      final AppUser muted = AppUser.fromMap('uid-b', <String, dynamic>{
        'name': 'Ana Cruz',
        'soundEffectsEnabled': false,
      });

      expect(muted.soundEffectsEnabled, isFalse);
      expect(
        muted.copyWith(subjects: <String>['Science']).soundEffectsEnabled,
        isFalse,
      );
      expect(
        muted.copyWith(soundEffectsEnabled: true).soundEffectsEnabled,
        isTrue,
      );
      expect(muted.toCreateMap()['soundEffectsEnabled'], isFalse);
    });
  });
}
