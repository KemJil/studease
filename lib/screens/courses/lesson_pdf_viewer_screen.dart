import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

/// Full-screen reader for a lesson attachment (`SfPdfViewer.file`).
///
/// The lesson PDF lives in the app documents directory (never Cloud Storage),
/// so it renders offline exactly like the inline preview in
/// `LessonReaderScreen`.
class LessonPdfViewerScreen extends StatefulWidget {
  const LessonPdfViewerScreen({
    super.key,
    required this.filePath,
    required this.title,
  });

  final String filePath;
  final String title;

  @override
  State<LessonPdfViewerScreen> createState() => _LessonPdfViewerScreenState();
}

class _LessonPdfViewerScreenState extends State<LessonPdfViewerScreen> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to lesson',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.screenTitle.copyWith(fontSize: 15),
            ),
            Text('Lesson PDF', style: context.caption.copyWith(fontSize: 10)),
          ],
        ),
      ),
      body: _failed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 34,
                      color: context.surfaces.dangerInk,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This PDF could not be opened',
                      textAlign: TextAlign.center,
                      style: context.cardTitle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Go back to the lesson and re-attach the file.',
                      textAlign: TextAlign.center,
                      style: context.caption,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Back to lesson'),
                    ),
                  ],
                ),
              ),
            )
          : SfPdfViewer.file(
              File(widget.filePath),
              canShowScrollHead: true,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                debugPrint('Lesson PDF failed to load: ${details.description}');
                if (mounted) setState(() => _failed = true);
              },
            ),
    );
  }
}
