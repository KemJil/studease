import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/book.dart';
import '../../models/streak_update.dart';
import '../../services/book_repository.dart';
import '../../services/sound_service.dart';
import '../../services/study_progress_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_progress_bar.dart';
import '../../widgets/toast.dart';

/// In-app PDF reader for URL and local books.
///
/// Page changes are debounced into `lastReadPage` / `totalPages`, and
/// **Complete Reading Session & Log Streak** feeds `recordActivity('book')`.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({super.key, required this.uid, required this.book});

  final String uid;
  final Book book;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  static const BookRepository _books = BookRepository();
  static const StudyProgressService _progress = StudyProgressService();

  final PdfViewerController _controller = PdfViewerController();
  Timer? _saveTimer;

  late int _currentPage = widget.book.lastReadPage < 1
      ? 1
      : widget.book.lastReadPage;
  late int _totalPages = widget.book.totalPages;
  late String? _localPath = widget.book.localPath;
  late bool _fileMissing = _isLocalFileMissing();
  Key _viewerKey = UniqueKey();
  bool _loadFailed = false;
  bool _logged = false;
  bool _busy = false;

  bool _isLocalFileMissing() {
    if (!widget.book.isLocal) return false;
    final String? path = widget.book.localPath;
    if (path == null || path.trim().isEmpty) return true;
    try {
      return !File(path).existsSync();
    } catch (error) {
      debugPrint('Local PDF check failed: $error');
      return true;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  int get _progressPercent {
    if (_totalPages <= 0) return widget.book.progressPercent;
    return ((_currentPage / _totalPages).clamp(0.0, 1.0) * 100).round();
  }

  double get _progressValue {
    if (_totalPages <= 0) return widget.book.progress;
    return (_currentPage / _totalPages).clamp(0.0, 1.0);
  }

  Future<void> _persistProgress(int page) async {
    try {
      await _books.saveProgress(
        uid: widget.uid,
        bookId: widget.book.id,
        lastReadPage: page,
        totalPages: _totalPages > 0 ? _totalPages : null,
      );
    } catch (error) {
      debugPrint('Book progress save failed: $error');
    }
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final int page = details.newPageNumber;
    if (page <= 0 || page == _currentPage) return;
    setState(() => _currentPage = page);
    _saveTimer?.cancel();
    _saveTimer = Timer(
      const Duration(milliseconds: 800),
      () => _persistProgress(page),
    );
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    final int pages = details.document.pages.count;
    if (!mounted) return;
    setState(() {
      _totalPages = pages;
      _loadFailed = false;
    });
    if (pages > 0) unawaited(_persistProgress(_currentPage));
  }

  void _onDocumentLoadFailed(PdfDocumentLoadFailedDetails details) {
    debugPrint('PDF load failed: ${details.error} — ${details.description}');
    if (!mounted) return;
    setState(() => _loadFailed = true);
  }

  Future<void> _completeSession() async {
    if (_busy || _logged) return;
    setState(() => _busy = true);

    try {
      await _persistProgress(_currentPage);
      final StreakUpdate update = await _progress.recordActivity(
        uid: widget.uid,
        type: StudyActivityType.book,
        title: 'Read "${widget.book.title}"',
        tag: widget.book.subject,
      );
      if (!mounted) return;
      setState(() {
        _logged = true;
        _busy = false;
      });
      unawaited(SoundService.instance.play(SoundEffect.streak));
      showAppToast(
        context,
        'Reading session saved! ${update.message}',
        type: AppToastType.streak,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppToast(
        context,
        StudyProgressService.messageFor(error),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _reattachFile() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        dialogTitle: 'Re-attach the PDF',
        type: FileType.custom,
        allowedExtensions: <String>['pdf'],
      );
      if (files.isEmpty) return;

      final PlatformFile file = files.first;
      final Uint8List bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        showAppToast(
          context,
          'That PDF looks empty — try another file.',
          type: AppToastType.error,
        );
        return;
      }

      final String storedPath = await _books.reattachLocalFile(
        uid: widget.uid,
        bookId: widget.book.id,
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      setState(() {
        _localPath = storedPath;
        _fileMissing = false;
        _loadFailed = false;
        _viewerKey = UniqueKey();
      });
      showAppToast(
        context,
        'PDF re-attached to this device.',
        type: AppToastType.success,
      );
    } catch (error) {
      debugPrint('Re-attaching local PDF failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not attach that PDF. Please pick it again.',
        type: AppToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to library',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.book.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: context.surfaces.successSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_progressPercent% read',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: context.surfaces.successInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(color: Colors.white, child: _viewer()),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _viewer() {
    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.cloud_off_rounded,
                size: 30,
                color: context.surfaces.amberInk,
              ),
              const SizedBox(height: 10),
              Text(
                'This PDF did not load',
                style: context.cardTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Check your connection and try again, or re-attach the file '
                'from this device.',
                textAlign: TextAlign.center,
                style: context.caption.copyWith(height: 1.5),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() {
                  _loadFailed = false;
                  _viewerKey = UniqueKey();
                }),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.book.isLocal) {
      final String? path = _localPath;
      if (_fileMissing || path == null) return _missingFileCard();
      return SfPdfViewer.file(
        File(path),
        key: _viewerKey,
        controller: _controller,
        initialPageNumber: _currentPage,
        onDocumentLoaded: _onDocumentLoaded,
        onDocumentLoadFailed: _onDocumentLoadFailed,
        onPageChanged: _onPageChanged,
      );
    }

    final String? url = widget.book.pdfUrl;
    if (url == null || url.trim().isEmpty) return _missingFileCard();
    return SfPdfViewer.network(
      url,
      key: _viewerKey,
      controller: _controller,
      initialPageNumber: _currentPage,
      onDocumentLoaded: _onDocumentLoaded,
      onDocumentLoadFailed: _onDocumentLoadFailed,
      onPageChanged: _onPageChanged,
    );
  }

  Widget _missingFileCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: context.surfaces.amberSoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: context.surfaces.amberInk,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The PDF is not on this device',
              style: context.cardTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Local books live in StudEase storage. Re-attach the same PDF '
              'to keep reading and syncing your page.',
              textAlign: TextAlign.center,
              style: context.caption.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _reattachFile,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Re-attach PDF file'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: context.surfaces.surface,
        border: Border(top: BorderSide(color: context.surfaces.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  _totalPages > 0
                      ? 'Page $_currentPage of $_totalPages'
                      : 'Page $_currentPage',
                  style: context.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.surfaces.inkSoft,
                  ),
                ),
                const Spacer(),
                Text(
                  '$_progressPercent%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: context.surfaces.successInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AppProgressBar(value: _progressValue),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy || _logged ? null : _completeSession,
              style: FilledButton.styleFrom(
                backgroundColor: _logged
                    ? AppColors.success
                    : AppColors.brand600,
                disabledBackgroundColor: _logged
                    ? AppColors.success
                    : AppColors.brand200,
                disabledForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _logged
                          ? '✓ Reading Session Logged'
                          : 'Complete Reading Session & Log Streak 🔥',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
