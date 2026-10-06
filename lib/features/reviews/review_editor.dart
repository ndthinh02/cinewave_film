import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import 'review_model.dart';
import '../../widgets/cine_ui.dart';

Future<bool> confirmDeleteReview(BuildContext context) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Xóa review?'),
                content: const Text(
                    'Bạn có chắc muốn xóa nhận xét này? Điểm Rating vẫn được giữ.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Xóa'))
                ])) ??
    false;

class ReviewEditor extends StatefulWidget {
  const ReviewEditor(
      {super.key,
      this.review,
      required this.onSave,
      required this.onDelete,
      required this.sessionValid});
  final MovieReview? review;
  final Future<bool> Function(String, bool) onSave;
  final Future<bool> Function() onDelete;
  final bool Function() sessionValid;
  @override
  State<ReviewEditor> createState() => _ReviewEditorState();
}

class _ReviewEditorState extends State<ReviewEditor> {
  late final TextEditingController _content =
      TextEditingController(text: widget.review?.content ?? '');
  late bool _spoiler = widget.review?.hasSpoiler ?? false;
  bool _busy = false;
  String? _error;
  Future<void> _submit({bool delete = false}) async {
    if (_busy) return;
    if (!widget.sessionValid()) {
      setState(
          () => _error = 'Phiên đã thay đổi. Vui lòng đóng và mở lại editor.');
      return;
    }
    if (!delete &&
        (_content.text.trim().isEmpty || _content.text.length > 2000)) {
      setState(() => _error = 'Nội dung phải có từ 1 đến 2000 ký tự.');
      return;
    }
    if (delete && (!await confirmDeleteReview(context) || !mounted)) return;
    if (!widget.sessionValid()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = delete
          ? await widget.onDelete()
          : await widget.onSave(_content.text.trim(), _spoiler);
      if (!mounted) return;
      if (success) {
        cineFeedback(context, delete ? 'Đã xóa đánh giá' : 'Đã lưu đánh giá');
        Navigator.pop(context);
        return;
      }
      setState(() => _error =
          'Không thể lưu hoặc xóa review. Kiểm tra phiên đăng nhập và thử lại.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không thể lưu review. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<AuthCubit, int>(
      listener: (context, _) {
        if (!widget.sessionValid()) {
          _content.clear();
          Navigator.pop(context);
        }
      },
      child: Scaffold(
          appBar: AppBar(
              title: Text(
                  widget.review == null ? 'Viết đánh giá' : 'Sửa đánh giá')),
          body: PopScope(
              canPop: !_busy,
              child: Padding(
                  padding: EdgeInsets.zero,
                  child: SafeArea(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  widget.review == null
                                      ? 'Viết review'
                                      : 'Chỉnh sửa review',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: _content,
                                  enabled: !_busy,
                                  minLines: 4,
                                  maxLines: 8,
                                  maxLength: 2000,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                      hintText: 'Viết nhận xét của bạn...',
                                      counterText:
                                          '${_content.text.length} / 2000',
                                      border: const OutlineInputBorder())),
                              CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _spoiler,
                                  onChanged: _busy
                                      ? null
                                      : (value) => setState(
                                          () => _spoiler = value ?? false),
                                  title: const Text('Nội dung có spoiler')),
                              if (_error != null)
                                Text(_error!,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error)),
                              if (_busy) const LinearProgressIndicator(),
                              FilledButton(
                                  onPressed: _busy ? null : () => _submit(),
                                  child: Text(widget.review == null
                                      ? 'Đăng review'
                                      : 'Cập nhật review')),
                              if (widget.review != null)
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _submit(delete: true),
                                    child: const Text('Xóa review')),
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text('Hủy')),
                            ])),
                  )))));
  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }
}
