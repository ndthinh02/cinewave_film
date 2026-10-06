import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';
import '../widgets/auth_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;
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
      await auth.login(_email.text.trim(), _password.text);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Không đăng nhập được. Kiểm tra email, '
            'mật khẩu và kết nối mạng rồi thử lại.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRegister() async {
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );

    // Truyền kết quả về Detail/Profile đang chờ đăng nhập.
    if (!mounted) return;

    if (registered == true) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Chào mừng trở lại',
      subtitle: 'Đăng nhập để lưu phim yêu thích và tiến độ xem.',
      loading: _loading,
      form: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !_loading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.username],
              decoration: authDecoration(
                context,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
              ),
              validator: validateAuthEmail,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _password,
              enabled: !_loading,
              obscureText: _hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: authDecoration(
                context,
                label: 'Mật khẩu',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _hidePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: _loading
                      ? null
                      : () => setState(
                        () => _hidePassword = !_hidePassword,
                  ),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (value) {
                return (value ?? '').isEmpty
                    ? 'Vui lòng nhập mật khẩu.'
                    : null;
              },
            ),
            if (_error != null) AuthError(message: _error!),
            const SizedBox(height: 24),
            AuthSubmitButton(
              loading: _loading,
              label: 'Đăng nhập',
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: TextButton(
        onPressed: _loading ? null : _openRegister,
        style: TextButton.styleFrom(foregroundColor: authAccent),
        child: const Text(
          'Chưa có tài khoản? Đăng ký ngay',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}