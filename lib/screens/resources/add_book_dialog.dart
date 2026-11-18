import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_surfaces.dart';

import '../../models/subject_course.dart';
import '../../services/book_repository.dart';
import '../../services/course_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/course_picker_field.dart';
import '../../widgets/segmented_switch.dart';
import '../../widgets/studease_text_field.dart';
import '../../widgets/toast.dart';

enum _BookInput { url, local }

/// **+ Add Book** dialog: a PDF URL or a PDF stored on the device.
///
/// Local files are copied into the app documents directory — Firebase Cloud
/// Storage is never used.
class AddBookDialog extends StatefulWidget {
  const AddBookDialog({super.key, required this.uid, this.colorIndex = 0});

  final String uid;
  final int colorIndex;

  @override
  State<AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends State<AddBookDialog> {
  static const BookRepository _books = BookRepository();
  static const CourseRepository _courses = CourseRepository();
  static const int _maxFileBytes = 40 * 1024 * 1024;

  final TextEditingController _title = TextEditingController();
  final TextEditingController _author = TextEditingController();
  final TextEditingController _url = TextEditingController();
  late final Stream<List<SubjectCourse>> _courseStream = _courses
      .watchSubjectCourses(widget.uid);

  _BookInput _mode = _BookInput.url;

  /// `General` keeps an unlinked book in the Uncategorized bucket.
  String _subject = 'General';
  String? _courseId;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        dialogTitle: 'Choose a PDF',
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
      if (bytes.length > _maxFileBytes) {
        showAppToast(
          context,
          'That PDF is larger than 40 MB. Try a smaller file or use a URL.',
          type: AppToastType.error,
        );
        return;
      }

      setState(() {
        _fileName = file.name;
        _fileBytes = bytes;
        if (_title.text.trim().isEmpty) {
          _title.text = _titleFromFileName(file.name);
        }
      });
    } catch (error) {
      debugPrint('AddBookDialog FilePicker failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not read that file. Please pick it again.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _submit() async {
    if (_saving) return;

    final String title = _title.text.trim();
    if (title.isEmpty) {
      showAppToast(
        context,
        'Give the book a title first.',
        type: AppToastType.info,
      );
      return;
    }

    if (_mode == _BookInput.url && !_isValidUrl(_url.text)) {
      showAppToast(
        context,
        'Enter a valid PDF link that starts with http:// or https://',
        type: AppToastType.error,
      );
      return;
    }
    if (_mode == _BookInput.local && _fileBytes == null) {
      showAppToast(
        context,
        'Choose a PDF file from this device first.',
        type: AppToastType.info,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_mode == _BookInput.url) {
        await _books.addFromUrl(
          uid: widget.uid,
          title: title,
          author: _author.text,
          subject: _subject,
          pdfUrl: _url.text,
          colorIndex: widget.colorIndex,
          courseId: _courseId,
        );
      } else {
        await _books.addLocalFile(
          uid: widget.uid,
          title: title,
          author: _author.text,
          subject: _subject,
          bytes: _fileBytes!,
          fileName: _fileName ?? 'book.pdf',
          colorIndex: widget.colorIndex,
          courseId: _courseId,
        );
      }
      if (!mounted) return;
      showAppToast(
        context,
        '"$title" added to your library.',
        type: AppToastType.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('AddBookDialog save failed: $error');
      if (!mounted) return;
      showAppToast(
        context,
        'We could not add that book. Check your connection and try again.',
        type: AppToastType.error,
      );
      setState(() => _saving = false);
    }
  }

  static bool _isValidUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String _titleFromFileName(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    final String base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final String cleaned = base.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return cleaned.isEmpty ? 'My PDF' : cleaned;
  }

  String get _fileLabel {
    final int bytes = _fileBytes?.length ?? 0;
    final String size = bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).round()} KB';
    return '${_fileName ?? 'PDF'} • $size';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.surfaces.brandSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.library_add_rounded,
              size: 18,
              color: context.surfaces.brandInk,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Add a book')),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SegmentedSwitch(
                labels: const <String>['PDF URL', 'Local PDF File'],
                selectedIndex: _mode.index,
                onChanged: (int index) =>
                    setState(() => _mode = _BookInput.values[index]),
              ),
              const SizedBox(height: 14),
              StudEaseTextField(
                controller: _title,
                label: 'Title',
                hint: 'e.g. College Physics 2e',
              ),
              const SizedBox(height: 10),
              StudEaseTextField(
                controller: _author,
                label: 'Author (optional)',
                hint: 'e.g. OpenStax',
              ),
              const SizedBox(height: 14),
              _coursePicker(),
              const SizedBox(height: 10),
              if (_mode == _BookInput.url)
                StudEaseTextField(
                  controller: _url,
                  label: 'PDF link',
                  hint: 'https://…/book.pdf',
                  keyboardType: TextInputType.url,
                  prefixIcon: Icons.link_rounded,
                )
              else
                _localFilePicker(),
              const SizedBox(height: 10),
              Text(
                _mode == _BookInput.url
                    ? 'The book opens in the in-app reader — no browser needed.'
                    : 'The PDF is copied into StudEase and read offline. '
                          'Nothing is uploaded to Cloud Storage.',
                style: context.caption.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Adding…' : 'Add to Library'),
        ),
      ],
    );
  }

  /// Course category picker: any subject course **or** Uncategorized.
  Widget _coursePicker() {
    return StreamBuilder<List<SubjectCourse>>(
      stream: _courseStream,
      builder:
          (BuildContext context, AsyncSnapshot<List<SubjectCourse>> snapshot) {
            final List<SubjectCourse> courses =
                snapshot.data ?? const <SubjectCourse>[];
            if (_courseId != null &&
                !courses.any(
                  (SubjectCourse course) => course.id == _courseId,
                )) {
              // The linked course is gone → save as Uncategorized.
              _courseId = null;
              _subject = 'General';
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'COURSE',
                  style: context.sectionLabel.copyWith(fontSize: 10),
                ),
                const SizedBox(height: 6),
                CoursePickerField(
                  courses: courses,
                  courseId: _courseId,
                  onChanged: (String? courseId) => setState(() {
                    _courseId = courseId;
                    _subject = 'General';
                    for (final SubjectCourse course in courses) {
                      if (course.id == courseId) {
                        _subject = course.name;
                        return;
                      }
                    }
                  }),
                ),
                if (snapshot.hasError) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'We could not load your courses — this book will be saved '
                    'as Uncategorized.',
                    style: context.caption.copyWith(
                      fontSize: 9.5,
                      color: context.surfaces.dangerInk,
                    ),
                  ),
                ],
              ],
            );
          },
    );
  }

  Widget _localFilePicker() {
    final bool hasFile = _fileBytes != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surfaces.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasFile ? AppColors.brand200 : context.surfaces.border,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            hasFile ? Icons.picture_as_pdf_rounded : Icons.upload_file_rounded,
            size: 20,
            color: hasFile
                ? context.surfaces.brandInk
                : context.surfaces.inkFaint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasFile ? _fileLabel : 'No PDF chosen yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: context.surfaces.inkSoft,
              ),
            ),
          ),
          TextButton(
            onPressed: _pickFile,
            child: Text(hasFile ? 'Change' : 'Choose'),
          ),
        ],
      ),
    );
  }
}
