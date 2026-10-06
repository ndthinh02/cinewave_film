import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/auth_cubit.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const _accent = Color(0xFFFF375F);

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _register = false;
  bool _loading = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;
  String? _error;

  void _changeMode(bool register) {
    if (_loading || _register == register) return;

    FocusScope.of(context).unfocus();
    _formKey.currentState?.reset();

    setState(() {
      _register = register;
      _error = null;
      _password.clear();
      _confirmPassword.clear();
      _hidePassword = true;
      _hideConfirmation = true;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthCubit>();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_register) {
        await auth.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      } else {
        await auth.login(
          _email.text.trim(),
          _password.text,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = _register
            ? 'Chưa tạo được tài khoản. Kiểm tra thông tin '
            'hoặc thử đăng nhập nếu email đã được sử dụng.'
            : 'Không đăng nhập được. Kiểm tra email, mật khẩu '
            'và kết nối mạng rồi thử lại.';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  InputDecoration _decoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(
        color: colors.onSurfaceVariant,
        fontSize: 13,
      ),
      prefixIcon: Icon(icon, size: 21),
      suffixIcon: suffix,
      filled: true,
      fillColor: colors.onSurface.withAlpha(5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      errorMaxLines: 2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colors.onSurface.withAlpha(22),
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colors.onSurface.withAlpha(12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: colors.error,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _modeButton({
    required String label,
    required bool register,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selected = _register == register;

    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: _loading ? null : () => _changeMode(register),
          style: TextButton.styleFrom(
            backgroundColor: selected
                ? _accent
                : Colors.transparent,
            foregroundColor: selected
                ? Colors.white
                : colors.onSurfaceVariant,
            disabledForegroundColor: selected
                ? Colors.white70
                : colors.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF0D0D12)
        : const Color(0xFFF7F7FA);

    return PopScope(
      canPop: !_loading,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: _loading
                ? null
                : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFF5C7C),
                              Color(0xFFE91E4D),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x26FF375F),
                              blurRadius: 24,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.movie_filter_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'CineWave',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _register
                          ? 'Tạo tài khoản, lưu những bộ phim bạn yêu thích.'
                          : 'Chào mừng bạn trở lại với thế giới điện ảnh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 28),

                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colors.onSurface.withAlpha(8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.onSurface.withAlpha(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          _modeButton(
                            label: 'Đăng nhập',
                            register: false,
                          ),
                          const SizedBox(width: 5),
                          _modeButton(
                            label: 'Đăng ký',
                            register: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: dark
                            ? const Color(0xFF191920)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: colors.onSurface.withAlpha(15),
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _register
                                  ? 'Bắt đầu cùng CineWave'
                                  : 'Đăng nhập tài khoản',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _register
                                  ? 'Điền thông tin để tạo tài khoản mới.'
                                  : 'Tiếp tục với tài khoản của bạn.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 24),

                            if (_register) ...[
                              TextFormField(
                                controller: _name,
                                enabled: !_loading,
                                textCapitalization:
                                TextCapitalization.words,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [
                                  AutofillHints.name,
                                ],
                                decoration: _decoration(
                                  label: 'Tên hiển thị',
                                  hint: 'Nhập tên của bạn',
                                  icon: Icons.person_outline_rounded,
                                ),
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Không được bỏ trống.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                            ],

                            TextFormField(
                              controller: _email,
                              enabled: !_loading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [
                                AutofillHints.email,
                              ],
                              decoration: _decoration(
                                label: 'Email',
                                hint: 'example@email.com',
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: (value) {
                                final email = (value ?? '').trim();

                                if (email.isEmpty) {
                                  return 'Không được bỏ trống.';
                                }

                                if (!RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(email)) {
                                  return 'Email chưa đúng định dạng.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 18),

                            TextFormField(
                              controller: _password,
                              enabled: !_loading,
                              obscureText: _hidePassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: _register
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              autofillHints: [
                                _register
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              onFieldSubmitted: (_) {
                                if (!_register) _submit();
                              },
                              decoration: _decoration(
                                label: 'Mật khẩu',
                                hint: 'Nhập mật khẩu',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Hiện mật khẩu'
                                      : 'Ẩn mật khẩu',
                                  onPressed: _loading
                                      ? null
                                      : () => setState(
                                        () => _hidePassword =
                                    !_hidePassword,
                                  ),
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 21,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Không được bỏ trống.';
                                }
                                return null;
                              },
                            ),

                            if (_register) ...[
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _confirmPassword,
                                enabled: !_loading,
                                obscureText: _hideConfirmation,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: _decoration(
                                  label: 'Xác nhận mật khẩu',
                                  hint: 'Nhập lại mật khẩu',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    tooltip: _hideConfirmation
                                        ? 'Hiện mật khẩu'
                                        : 'Ẩn mật khẩu',
                                    onPressed: _loading
                                        ? null
                                        : () => setState(
                                          () => _hideConfirmation =
                                      !_hideConfirmation,
                                    ),
                                    icon: Icon(
                                      _hideConfirmation
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 21,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Không được bỏ trống.';
                                  }
                                  if (value != _password.text) {
                                    return 'Hai mật khẩu chưa khớp.';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            if (_error != null) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.error.withAlpha(18),
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: colors.error,
                                      size: 19,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 12,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  if (_loading) ...[
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Flexible(
                                    child: Text(
                                      _loading
                                          ? 'Đang xử lý...'
                                          : _register
                                          ? 'Tạo tài khoản'
                                          : 'Đăng nhập',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (!_loading) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 19,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => _changeMode(!_register),
                      style: TextButton.styleFrom(
                        foregroundColor: _accent,
                      ),
                      child: Text(
                        _register
                            ? 'Đã có tài khoản? Đăng nhập'
                            : 'Chưa có tài khoản? Đăng ký ngay',
                        textAlign: TextAlign.center,
                      ),
                    ),

                    Text(
                      'Tài khoản giúp lưu phim yêu thích\n'
                          'và đồng bộ tiến độ xem của bạn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }
}