import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';
import '../widgets/auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _error;

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthCubit>();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await auth.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Chưa tạo được tài khoản. Email có thể đã được '
            'sử dụng hoặc kết nối mạng đang bị gián đoạn.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _visibilityButton({
    required bool hidden,
    required VoidCallback toggle,
  }) {
    return IconButton(
      tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
      onPressed: _loading ? null : toggle,
      icon: Icon(
        hidden
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Tạo tài khoản mới',
      subtitle: 'Bắt đầu thư viện phim của riêng bạn cùng CineWave.',
      loading: _loading,
      form: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: !_loading,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: authDecoration(
                context,
                label: 'Tên hiển thị',
                icon: Icons.person_outline_rounded,
              ),
              validator: (value) {
                final name = (value ?? '').trim();

                if (name.isEmpty) return 'Vui lòng nhập tên.';
                if (name.length > 80) return 'Tên tối đa 80 ký tự.';

                return null;
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              decoration: authDecoration(
                context,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final error = validateAuthEmail(value);
                if (error != null) return error;

                return value!.trim().length > 254
                    ? 'Email quá dài.'
                    : null;
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _password,
              enabled: !_loading,
              obscureText: _hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) {
                if (_confirmation.text.isNotEmpty) {
                  _formKey.currentState?.validate();
                }
              },
              decoration: authDecoration(
                context,
                label: 'Mật khẩu',
                icon: Icons.lock_outline_rounded,
                suffix: _visibilityButton(
                  hidden: _hidePassword,
                  toggle: () => setState(
                        () => _hidePassword = !_hidePassword,
                  ),
                ),
              ),
              validator: (value) {
                final password = value ?? '';

                if (password.length < 6) {
                  return 'Mật khẩu cần ít nhất 6 ký tự.';
                }

                if (utf8.encode(password).length > 72) {
                  return 'Mật khẩu không được vượt quá 72 byte.';
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _confirmation,
              enabled: !_loading,
              obscureText: _hideConfirmation,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: authDecoration(
                context,
                label: 'Xác nhận mật khẩu',
                icon: Icons.lock_outline_rounded,
                suffix: _visibilityButton(
                  hidden: _hideConfirmation,
                  toggle: () => setState(
                        () => _hideConfirmation = !_hideConfirmation,
                  ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Vui lòng nhập lại mật khẩu.';
                }

                return value != _password.text
                    ? 'Hai mật khẩu chưa khớp.'
                    : null;
              },
            ),
            if (_error != null) AuthError(message: _error!),
            const SizedBox(height: 24),
            AuthSubmitButton(
              loading: _loading,
              label: 'Tạo tài khoản',
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: TextButton(
        onPressed: _loading ? null : () => Navigator.pop(context),
        style: TextButton.styleFrom(foregroundColor: authAccent),
        child: const Text(
          'Đã có tài khoản? Quay lại đăng nhập',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }
}