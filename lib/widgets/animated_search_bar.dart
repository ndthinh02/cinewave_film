import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedSearchBar extends StatefulWidget {
  final VoidCallback onTap;

  const AnimatedSearchBar({
    super.key,
    required this.onTap,
  });

  @override
  State<AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<AnimatedSearchBar> {
  static const _hints = [
    'Hôm nay bạn muốn xem gì?',
    'Tìm phim bộ yêu thích...',
    'Khám phá phim chiếu rạp...',
    'Tìm phim hoạt hình...',
  ];

  Timer? _timer;
  int _hintIndex = 0;
  bool _pressed = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _reduceMotion = MediaQuery.of(context).disableAnimations;
    _timer?.cancel();

    if (!_reduceMotion) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        // Không đổi chữ khi Home đang bị ẩn bởi tab hoặc màn khác.
        if (!mounted ||
            !TickerMode.valuesOf(context).enabled ||
            ModalRoute.of(context)?.isCurrent == false) {
          return;
        }

        setState(() {
          _hintIndex = (_hintIndex + 1) % _hints.length;
        });
      });
    }
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const accent = Color(0xFFFF375F);

    return Semantics(
      button: true,
      label: 'Tìm kiếm phim',
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration:
            _reduceMotion ? Duration.zero : const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: colors.onSurface.withAlpha(20),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: _setPressed,
            splashColor: const Color(0x1AFF375F),
            highlightColor: const Color(0x0DFF375F),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x1AFF375F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Text(
                        _hints[_hintIndex],
                        key: ValueKey(_hintIndex),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: colors.onSurfaceVariant,
                    size: 18,
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
