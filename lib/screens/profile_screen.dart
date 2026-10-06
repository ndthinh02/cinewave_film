import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../blocs/auth_cubit.dart';
import '../blocs/theme_cubit.dart';
import 'auth_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _accent = Color(0xFFFF375F);

  bool _loggingOut = false;
  bool _clearingHistory = false;
  bool _uploadingAvatar = false;

  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;

    final auth = context.read<AuthCubit>();
    if (!auth.api.loggedIn) return;

    setState(() => _uploadingAvatar = true);

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      await auth.uploadAvatar(image.path);

      if (mounted) {
        _notify('Đã cập nhật ảnh đại diện.');
      }
    } catch (_) {
      if (mounted) {
        _notify(
            'Không cập nhật được ảnh. Hãy thử ảnh khác hoặc kiểm tra mạng.');
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Widget _avatar({
    required bool loggedIn,
    required String initial,
    required String url,
  }) {
    Widget fallback() => Center(
          child: loggedIn
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 34,
                ),
        );

    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: _accent,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: loggedIn && !_uploadingAvatar ? _changeAvatar : null,
                child: _uploadingAvatar
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : url.isEmpty
                        ? fallback()
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => fallback(),
                          ),
              ),
            ),
          ),
          if (loggedIn)
            Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: _accent,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openAccountPage(Widget page) async {
    final backend = context.read<AuthCubit>().api;

    if (!backend.loggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(),
        ),
      );

      if (!mounted || !backend.loggedIn) return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _login() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _notify(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _clearSearchHistory() async {
    if (_clearingHistory) return;

    final confirmed = await _confirm(
      title: 'Xóa lịch sử tìm kiếm?',
      message: 'Các từ khóa đã tìm trên thiết bị này sẽ bị xóa. '
          'Phim yêu thích và lịch sử xem vẫn được giữ nguyên.',
      action: 'Xóa lịch sử',
    );

    if (!confirmed || !mounted) return;

    setState(() => _clearingHistory = true);

    try {
      final preferences = await SharedPreferences.getInstance();
      final success = await preferences.remove(
        'cinewave_search_history',
      );

      if (!success) throw StateError('Cannot remove history');

      _notify('Đã xóa lịch sử tìm kiếm.');
    } catch (_) {
      _notify('Chưa xóa được lịch sử. Anh thử lại nhé.');
    } finally {
      if (mounted) {
        setState(() => _clearingHistory = false);
      }
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await _confirm(
      title: 'Đăng xuất tài khoản?',
      message: 'Bạn vẫn có thể xem phim khi chưa đăng nhập.',
      action: 'Đăng xuất',
    );

    if (!confirmed || !mounted) return;

    final auth = context.read<AuthCubit>();
    setState(() => _loggingOut = true);

    try {
      await auth.logout();
      _notify('Đã đăng xuất.');
    } catch (_) {
      _notify('Đăng xuất chưa thành công. Anh thử lại nhé.');
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  void _showAccountInfo(String name, String email) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Thông tin tài khoản',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Tên hiển thị'),
                const SizedBox(height: 6),
                SelectableText(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Email'),
                const SizedBox(height: 6),
                SelectableText(
                  email.isEmpty ? 'Chưa có thông tin' : email,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: 'CineWave',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.movie_filter_rounded,
          color: Colors.white,
        ),
      ),
      children: const [
        Text(
          'Khám phá phim, lưu những bộ phim yêu thích '
          'và tiếp tục xem cùng tài khoản của bạn.',
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: colors.onSurface.withAlpha(18),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 66,
                      endIndent: 16,
                      color: colors.onSurface.withAlpha(12),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 5,
      ),
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0x1AFF375F),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: _accent, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: colors.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ),
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
            size: 22,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>();
    final backend = auth.api;
    final colors = Theme.of(context).colorScheme;

    final dark = Theme.of(context).brightness == Brightness.dark;

    final rawName = (backend.user?['name'] ?? '').toString().trim();
    final name = backend.loggedIn
        ? (rawName.isEmpty ? 'Người dùng' : rawName)
        : 'Chào bạn!';

    final email = (backend.user?['email'] ?? '').toString().trim();

    final initial = name.characters.first.toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Thẻ tài khoản.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF30202D),
                      Color(0xFF191920),
                    ]
                  : const [
                      Color(0xFFFFE8EE),
                      Color(0xFFFFF7F9),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0x30FF375F),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(
                    loggedIn: backend.loggedIn,
                    initial: initial,
                    url: backend.mediaUrl(
                      (backend.user?['avatarUrl'] ?? '').toString(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          backend.loggedIn
                              ? (email.isEmpty ? 'Tài khoản CineWave' : email)
                              : 'Đăng nhập để lưu phim yêu thích',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (backend.loggedIn)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFF375F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: _accent,
                        size: 15,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Đã đăng nhập',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login_rounded, size: 20),
                    label: const Text('Đăng nhập / Đăng ký'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ),

        _section(
          title: 'THƯ VIỆN CỦA BẠN',
          children: [
            _settingTile(
              icon: Icons.favorite_border_rounded,
              title: 'Phim yêu thích',
              subtitle: 'Những bộ phim bạn đã lưu',
              onTap: () => _openAccountPage(
                const FavoritesScreen(),
              ),
            ),
            _settingTile(
              icon: Icons.history_rounded,
              title: 'Lịch sử & xem tiếp',
              subtitle: 'Theo dõi tiến độ xem trên tài khoản',
              onTap: () => _openAccountPage(
                const HistoryScreen(),
              ),
            ),
            if (backend.loggedIn)
              _settingTile(
                icon: Icons.person_outline_rounded,
                title: 'Thông tin tài khoản',
                subtitle: 'Xem tên hiển thị và email',
                onTap: () => _showAccountInfo(name, email),
              ),
          ],
        ),

        _section(
          title: 'CÀI ĐẶT',
          children: [
            _settingTile(
              icon: dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              title: 'Giao diện tối',
              subtitle: 'Điều chỉnh giao diện theo sở thích',
              trailing: Switch(
                value: dark,
                onChanged: (_) => context.read<ThemeCubit>().toggle(),
              ),
              onTap: () => context.read<ThemeCubit>().toggle(),
            ),
            _settingTile(
              icon: Icons.manage_search_rounded,
              title: 'Xóa lịch sử tìm kiếm',
              subtitle: 'Chỉ xóa từ khóa lưu trên thiết bị này',
              onTap: _clearingHistory ? null : _clearSearchHistory,
              trailing: _clearingHistory
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: _accent,
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),
          ],
        ),

        _section(
          title: 'ỨNG DỤNG',
          children: [
            _settingTile(
              icon: Icons.info_outline_rounded,
              title: 'Về CineWave',
              subtitle: 'Thông tin ứng dụng và giấy phép thư viện',
              onTap: _showAbout,
            ),
          ],
        ),

        if (backend.loggedIn) ...[
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: _accent,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.logout_rounded, size: 20),
            label: Text(
              _loggingOut ? 'Đang đăng xuất...' : 'Đăng xuất',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: const BorderSide(
                color: Color(0x50FF375F),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),
        Text(
          'CINEWAVE',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant.withAlpha(130),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}
