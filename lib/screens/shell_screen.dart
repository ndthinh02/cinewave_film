import 'package:flutter/material.dart';

import 'favorites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import '../features/community/community_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const _accent = Color(0xFFFF375F);

  int _selectedIndex = 0;
  int _favoritesRefreshKey = 0;

  static const _titles = [
    'CineWave',
    'Yêu thích',
    'Tài khoản',
    'Cộng đồng',
  ];

  static const _subtitles = [
    'Thế giới phim trong tay bạn',
    'Những bộ phim bạn yêu thích',
    'Không gian cá nhân của bạn',
    'Chia sẻ cảm nhận điện ảnh',
  ];

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  Widget _navigationItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selectedIndex == index;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              setState(() {
                if (index == 1) {
                  _favoritesRefreshKey++;
                }

                _selectedIndex = index;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: 54,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0x1AFF375F)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      color: selected ? _accent : colors.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _accent : colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: _selectedIndex == 0 || _selectedIndex == 3
          ? null
          : AppBar(
              toolbarHeight: 76,
              titleSpacing: 20,
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF5C7C),
                          Color(0xFFE91E4D),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26FF375F),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.movie_filter_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titles[_selectedIndex],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitles[_selectedIndex],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
                    tooltip: 'Tìm kiếm phim',
                    onPressed: _openSearch,
                    style: IconButton.styleFrom(
                      backgroundColor: colors.onSurface.withAlpha(10),
                      foregroundColor: colors.onSurface,
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: colors.onSurface.withAlpha(18),
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.search_rounded,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),

      // Giữ vị trí cuộn và trạng thái khi chuyển tab.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TickerMode(
            enabled: _selectedIndex == 0,
            child: const HomeScreen(),
          ),
          FavoritesScreen(
            refreshKey: _favoritesRefreshKey,
          ),
          const ProfileScreen(),
          const CommunityScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF191920) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.onSurface.withAlpha(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(dark ? 35 : 12),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    _navigationItem(
                      index: 0,
                      label: 'Trang chủ',
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                    ),
                    _navigationItem(
                      index: 1,
                      label: 'Yêu thích',
                      icon: Icons.favorite_border_rounded,
                      selectedIcon: Icons.favorite_rounded,
                    ),
                    _navigationItem(
                      index: 2,
                      label: 'Tôi',
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                    ),
                    _navigationItem(
                        index: 3,
                        label: 'Cộng đồng',
                        icon: Icons.people_outline,
                        selectedIcon: Icons.people),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
