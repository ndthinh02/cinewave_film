import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/movie.dart';
import '../services/backend_api.dart';

class PlayerScreen extends StatefulWidget {
  final Movie movie;
  final List<Episode> episodes;
  final int initialIndex;
  final BackendApi backend;
  final int initialPositionSeconds;

  const PlayerScreen({
    super.key,
    required this.movie,
    required this.episodes,
    required this.backend,
    this.initialIndex = 0,
    this.initialPositionSeconds = 0,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;

  Timer? _hideTimer;
  Timer? _saveTimer;

  int _index = 0;
  bool _loading = true;
  bool _controlsVisible = true;
  bool _fullscreen = false;
  String? _error;
  bool _resumeApplied = false;
  Timer? _nextEpisodeTimer;

  bool _locked = false;
  bool _switchingEpisode = false;
  bool _completionHandled = false;
  bool _appActive = true;
  static const MethodChannel _pipChannel = MethodChannel(
    'movie_app/pip',
  );

  bool _isInPip = false;
  bool _pipRequested = false;

  int? _nextEpisodeCountdown;
  double _playbackSpeed = 1.0;

  bool get _ready => !_loading && _controller?.value.isInitialized == true;

  Future<void> _enterPictureInPicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _loading ||
        _pipRequested) {
      return;
    }

    try {
      _hideTimer?.cancel();

      setState(() {
        _pipRequested = true;
        _controlsVisible = false;
      });

      final success = await _pipChannel.invokeMethod<bool>(
        'enterPiP',
      );

      if (!mounted) return;

      if (success != true) {
        setState(() {
          _pipRequested = false;
          _controlsVisible = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thiết bị này không hỗ trợ Picture-in-Picture.',
            ),
          ),
        );
      }
    } on PlatformException {
      if (!mounted) return;

      setState(() {
        _pipRequested = false;
        _controlsVisible = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể bật chế độ cửa sổ nổi.',
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Nhận trạng thái PiP từ MainActivity.kt.
    _pipChannel.setMethodCallHandler(_handlePipMethod);

    if (widget.episodes.isNotEmpty) {
      _index = widget.initialIndex.clamp(0, widget.episodes.length - 1).toInt();
    }

    _openEpisode(_index);
  }

  Future<dynamic> _handlePipMethod(MethodCall call) async {
    if (call.method != 'pipChanged') {
      return null;
    }

    final inPip = call.arguments == true;

    if (!mounted) return null;

    setState(() {
      _isInPip = inPip;
      _pipRequested = false;

      _appActive = inPip ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    });

    if (inPip) {
      _hideTimer?.cancel();
      _controlsVisible = false;
    } else {
      _controlsVisible = true;
      _scheduleHide();
    }

    return null;
  }

  Future<void> _saveProgress() async {
    final controller = _controller;

    if (!widget.backend.loggedIn ||
        controller == null ||
        !controller.value.isInitialized ||
        widget.episodes.isEmpty) {
      return;
    }

    final episode = widget.episodes[_index];
    final value = controller.value;
    final position = value.position.inSeconds;
    final duration = value.duration.inSeconds;

    if (duration <= 0 || position <= 0) return;

    final lastEpisode = _index == widget.episodes.length - 1;

    // Chỉ đánh dấu hoàn thành phim khi gần cuối tập cuối.
    final completed = lastEpisode &&
        (value.isCompleted || (duration > 20 && position >= duration - 20));

    try {
      await widget.backend.saveProgress(
        movie: widget.movie,
        episode: episode,
        position: position,
        duration: duration,
        completed: completed,
      );
    } catch (_) {
      // Lỗi lưu tiến độ không làm gián đoạn phát phim.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appActive = true;

        if (mounted) {
          setState(() {
            _pipRequested = false;
          });
        }

        _scheduleHide();
        break;

      case AppLifecycleState.inactive:
        // Android thường đi qua inactive trước khi vào PiP.
        // Không pause ở đây.
        break;

      case AppLifecycleState.hidden:
        // Không pause vội vì PiP cũng có thể làm app
        // chuyển lifecycle.
        break;

      case AppLifecycleState.paused:
        if (_pipRequested || _isInPip) {
          // PiP: video tiếp tục chạy.
          _appActive = true;
          return;
        }

        _appActive = false;

        _controller?.pause();

        unawaited(_saveProgress());

        _hideTimer?.cancel();
        _cancelAutoNext();

        if (mounted) {
          setState(() {
            _controlsVisible = true;
          });
        }

        break;

      case AppLifecycleState.detached:
        _appActive = false;
        unawaited(_saveProgress());
        break;
    }
  }

  void _cancelAutoNext({bool updateUi = true}) {
    _nextEpisodeTimer?.cancel();
    _nextEpisodeTimer = null;

    if (_nextEpisodeCountdown == null) return;

    if (updateUi && mounted) {
      setState(() => _nextEpisodeCountdown = null);
    } else {
      _nextEpisodeCountdown = null;
    }
  }

  void _onVideoChanged() {
    final controller = _controller;

    if (!mounted ||
        !_appActive ||
        !_ready ||
        controller == null ||
        controller.value.hasError) {
      return;
    }

    final value = controller.value;

    // Tua về trước hoặc phát lại sẽ cho phép đếm ngược lần sau.
    if (!value.isCompleted) {
      _completionHandled = false;

      if (_nextEpisodeCountdown != null) {
        scheduleMicrotask(() {
          if (mounted && _controller == controller) {
            _cancelAutoNext();
          }
        });
      }

      return;
    }

    if (_completionHandled) return;
    _completionHandled = true;

    // Listener có thể được gọi lúc widget đang rebuild.
    scheduleMicrotask(() {
      if (!mounted ||
          !_appActive ||
          _controller != controller ||
          !controller.value.isCompleted ||
          _switchingEpisode) {
        return;
      }

      unawaited(_saveProgress());

      if (_index + 1 >= widget.episodes.length) return;

      _hideTimer?.cancel();

      setState(() {
        _nextEpisodeCountdown = 5;
        _controlsVisible = true;
      });

      _nextEpisodeTimer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          if (!mounted || !_appActive || _controller != controller) {
            timer.cancel();
            return;
          }

          final remaining = (_nextEpisodeCountdown ?? 0) - 1;

          if (remaining <= 0) {
            _cancelAutoNext();
            unawaited(_openEpisode(_index + 1));
          } else {
            setState(() => _nextEpisodeCountdown = remaining);
          }
        },
      );
    });
  }

  void _toggleLock() {
    _hideTimer?.cancel();

    setState(() {
      _locked = !_locked;
      _controlsVisible = true;
    });

    if (!_locked) _scheduleHide();
  }

  Future<void> _showPlaybackSpeed() async {
    final controller = _controller;
    if (!_ready || _locked || controller == null) return;

    _hideTimer?.cancel();

    final speed = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Tốc độ phát',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final value in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  ListTile(
                    title: Text(
                      value == 1.0 ? 'Bình thường · 1×' : '$value×',
                    ),
                    trailing: _playbackSpeed == value
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFFFF375F),
                          )
                        : null,
                    textColor: colors.onSurface,
                    onTap: () => Navigator.pop(sheetContext, value),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || _controller != controller) return;

    if (speed != null) {
      try {
        await controller.setPlaybackSpeed(speed);

        if (!mounted || _controller != controller) return;
        setState(() => _playbackSpeed = speed);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video này chưa hỗ trợ tốc độ đã chọn.'),
            ),
          );
        }
      }
    }

    if (mounted) _scheduleHide();
  }

  Widget _autoNextOverlay() {
    final remaining = _nextEpisodeCountdown;
    if (remaining == null) return const SizedBox.shrink();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Material(
            color: const Color(0xF2191920),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tập tiếp theo sau $remaining giây',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => _cancelAutoNext(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text('Hủy'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            _cancelAutoNext();
                            _openEpisode(_index + 1);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF375F),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Xem ngay'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEpisode(int nextIndex) async {
    if (_switchingEpisode || !mounted) return;

    _switchingEpisode = true;
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _cancelAutoNext(updateUi: false);

    setState(() {
      _loading = true;
      _controlsVisible = true;
      _error = null;
    });

    try {
      await _saveProgress();
      if (!mounted) return;

      final previous = _controller;
      previous?.removeListener(_onVideoChanged);

      _controller = null;
      await previous?.dispose();

      if (!mounted) return;

      if (widget.episodes.isEmpty ||
          nextIndex < 0 ||
          nextIndex >= widget.episodes.length) {
        setState(() {
          _loading = false;
          _error = 'Không có tập phim để phát.';
        });
        return;
      }

      _index = nextIndex;
      _completionHandled = false;

      final episode = widget.episodes[_index];

      if (episode.m3u8.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Tập này chưa có đường dẫn video.';
        });
        return;
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(episode.m3u8),
      );

      _controller = controller;

      await controller.initialize();
      if (!mounted || _controller != controller) return;

      if (!_resumeApplied) {
        final initialIndex =
            widget.initialIndex.clamp(0, widget.episodes.length - 1).toInt();

        if (_index == initialIndex &&
            widget.initialPositionSeconds > 0 &&
            controller.value.duration.inSeconds > 0) {
          final seconds = widget.initialPositionSeconds
              .clamp(0, controller.value.duration.inSeconds - 1)
              .toInt();

          await controller.seekTo(Duration(seconds: seconds));

          if (!mounted || _controller != controller) return;
        }

        _resumeApplied = true;
      }

      try {
        await controller.setPlaybackSpeed(_playbackSpeed);
      } catch (_) {
        _playbackSpeed = 1.0;
      }

      if (!mounted || _controller != controller) return;

      controller.addListener(_onVideoChanged);

      if (_appActive) {
        await controller.play();

        try {
          await _pipChannel.invokeMethod(
            'enableAutoPiP',
          );
        } catch (_) {
          // Android cũ vẫn dùng PiP thủ công.
        }
      }

      if (!mounted || _controller != controller) return;

      setState(() => _loading = false);

      _saveTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) {
          if (_appActive || _isInPip) {
            unawaited(_saveProgress());
          }
        },
      );

      _scheduleHide();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Không phát được video. Anh thử tải lại nhé.';
      });
    } finally {
      _switchingEpisode = false;
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_locked || _nextEpisodeCountdown != null) return;

    if (_controller?.value.isPlaying != true) return;

    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_locked) return;

    setState(() => _controlsVisible = !_controlsVisible);

    if (_controlsVisible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (!_ready || controller == null) return;
    if (_locked) return;
    _cancelAutoNext();

    if (controller.value.isPlaying) {
      await controller.pause();
      await _saveProgress();
    } else {
      await controller.play();
    }

    if (!mounted) return;

    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  Future<void> _seekBy(int seconds) async {
    final controller = _controller;
    if (!_ready || controller == null) return;

    final target = (controller.value.position.inMilliseconds + seconds * 1000)
        .clamp(
          0,
          controller.value.duration.inMilliseconds,
        )
        .toInt();

    await controller.seekTo(Duration(milliseconds: target));
    _scheduleHide();
  }

  Future<void> _setFullscreen(bool enabled) async {
    if (_fullscreen == enabled) return;

    setState(() {
      _fullscreen = enabled;
      _controlsVisible = true;
    });

    if (enabled) {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
      if (!mounted) return;

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      if (_locked) return;
      _cancelAutoNext();
      await _restoreSystemUi();
    }

    if (mounted) _scheduleHide();
  }

  Future<void> _restoreSystemUi() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );
  }

  String _formatTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');

    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  Widget _controlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    double size = 28,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size,
      color: Colors.white,
      disabledColor: Colors.white24,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black26,
        padding: const EdgeInsets.all(10),
      ),
      icon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ==========================================
    // PICTURE IN PICTURE
    // ==========================================
    //
    // Khi Android thu nhỏ Activity, tuyệt đối
    // không render AppBar + danh sách tập.
    //
    // Chỉ render video.
    //
    if (_isInPip || _pipRequested) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SizedBox.expand(
          child: _video(),
        ),
      );
    }

    // ==========================================
    // PLAYER BÌNH THƯỜNG
    // ==========================================

    return PopScope(
      canPop: !_fullscreen && !_locked,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_locked) {
          _toggleLock();
        } else if (_fullscreen) {
          _setFullscreen(false);
        }
      },
      child: Scaffold(
        backgroundColor: _fullscreen ? Colors.black : null,
        appBar: _fullscreen
            ? null
            : AppBar(
                title: Text(widget.movie.name),
                centerTitle: true,
              ),
        body: _fullscreen
            ? SizedBox.expand(
                child: _video(),
              )
            : Column(
                children: [
                  // =========================
                  // VIDEO
                  // =========================

                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _video(),
                  ),

                  // =========================
                  // DANH SÁCH TẬP
                  // =========================

                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final colors = Theme.of(context).colorScheme;

                        const accent = Color(0xFFFF375F);

                        return CustomScrollView(
                          slivers: [
                            // Header
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  20,
                                  16,
                                  16,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: colors.onSurface.withAlpha(8),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colors.onSurface.withAlpha(18),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0x1AFF375F,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.video_library_rounded,
                                          color: accent,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Danh sách tập',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.onSurface,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Chọn tập để bắt đầu xem',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.onSurfaceVariant,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.onSurface.withAlpha(12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          '${widget.episodes.length} tập',
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            if (widget.episodes.isEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Chưa có tập phim.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),

                            if (widget.episodes.isNotEmpty)
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  MediaQuery.paddingOf(context).bottom + 20,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 150,

                                    // Cố định đủ cao cho 2 dòng.
                                    mainAxisExtent: 82,

                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final selected = index == _index;

                                      final episode = widget.episodes[index];

                                      return AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? const Color(
                                                  0x1AFF375F,
                                                )
                                              : colors.onSurface.withAlpha(8),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? accent
                                                : colors.onSurface
                                                    .withAlpha(20),
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            onTap: _loading || _locked
                                                ? null
                                                : () => _openEpisode(
                                                      index,
                                                    ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 8,
                                              ),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      if (selected && _loading)
                                                        const SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child:
                                                              CircularProgressIndicator(
                                                            color: accent,
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      else
                                                        Icon(
                                                          selected
                                                              ? Icons
                                                                  .equalizer_rounded
                                                              : Icons
                                                                  .play_circle_outline_rounded,
                                                          color: selected
                                                              ? accent
                                                              : colors
                                                                  .onSurfaceVariant,
                                                          size: 20,
                                                        ),
                                                      const SizedBox(
                                                        width: 6,
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          'Tập ${episode.name}',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: selected
                                                                ? accent
                                                                : colors
                                                                    .onSurface,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(
                                                    height: 4,
                                                  ),
                                                  Text(
                                                    selected
                                                        ? (_loading
                                                            ? 'Đang tải...'
                                                            : 'Đang xem')
                                                        : 'Nhấn để xem',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: selected
                                                          ? accent
                                                          : colors
                                                              .onSurfaceVariant,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: widget.episodes.length,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _video() {
    const accent = Color(0xFFFF375F);
    final controller = _controller;

    if (_loading) {
      return const ColoredBox(
        color: Color(0xFF08080A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Đang tải phim...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || controller == null) {
      return ColoredBox(
        color: const Color(0xFF08080A),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white54,
                  size: 30,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'Không có video.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                TextButton.icon(
                  onPressed: () => _openEpisode(_index),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final ratio = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
        final visible = !_isInPip &&
            !_pipRequested &&
            !_locked &&
            (_controlsVisible || !value.isPlaying || value.hasError);

        final playable = value.isInitialized && !value.hasError;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: (_isInPip || _pipRequested) ? null : _toggleControls,
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Giữ nguyên tỉ lệ video, vừa trong khung.
                Center(
                  child: AspectRatio(
                    aspectRatio: ratio,
                    child: VideoPlayer(controller),
                  ),
                ),

                if (value.isBuffering)
                  const IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accent,
                        ),
                      ),
                    ),
                  ),

                IgnorePointer(
                  ignoring: !visible,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black87,
                            Colors.black12,
                            Colors.black87,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        top: _fullscreen,
                        bottom: _fullscreen,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              left: 12,
                              right: 12,
                              child: Row(
                                children: [
                                  if (_fullscreen) ...[
                                    _controlButton(
                                      icon: Icons.arrow_back_rounded,
                                      tooltip: 'Thu nhỏ',
                                      onPressed: () => _setFullscreen(false),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Text(
                                      _fullscreen
                                          ? '${widget.movie.name}'
                                              ' · Tập ${widget.episodes[_index].name}'
                                          : 'Tập ${widget.episodes[_index].name}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        playable ? _showPlaybackSpeed : null,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      minimumSize: const Size(40, 44),
                                    ),
                                    child: Text(
                                      '$_playbackSpeed×',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  _controlButton(
                                    icon: Icons.lock_outline_rounded,
                                    tooltip: 'Khóa điều khiển',
                                    size: 22,
                                    onPressed: playable ? _toggleLock : null,
                                  ),
                                ],
                              ),
                            ),
                            Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _controlButton(
                                    icon: Icons.replay_10_rounded,
                                    tooltip: 'Lùi 10 giây',
                                    onPressed:
                                        playable ? () => _seekBy(-10) : null,
                                  ),
                                  const SizedBox(width: 20),
                                  IconButton(
                                    tooltip:
                                        value.isPlaying ? 'Tạm dừng' : 'Phát',
                                    onPressed:
                                        playable ? _togglePlayback : null,
                                    style: IconButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: accent,
                                      disabledBackgroundColor: Colors.white24,
                                      padding: const EdgeInsets.all(12),
                                    ),
                                    icon: Icon(
                                      value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: _fullscreen ? 42 : 32,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  _controlButton(
                                    icon: Icons.forward_10_rounded,
                                    tooltip: 'Tua 10 giây',
                                    onPressed:
                                        playable ? () => _seekBy(10) : null,
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 2,
                              left: 12,
                              right: 12,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Listener(
                                    onPointerDown: (_) => _hideTimer?.cancel(),
                                    onPointerUp: (_) => _scheduleHide(),
                                    onPointerCancel: (_) => _scheduleHide(),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: VideoProgressIndicator(
                                        controller,
                                        allowScrubbing: playable,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        colors: const VideoProgressColors(
                                          playedColor: accent,
                                          bufferedColor: Colors.white38,
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_formatTime(value.position)}'
                                          ' / '
                                          '${_formatTime(value.duration)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      _controlButton(
                                        icon: Icons.skip_next_rounded,
                                        tooltip: 'Tập tiếp theo',
                                        size: 24,
                                        onPressed:
                                            _index + 1 < widget.episodes.length
                                                ? () => _openEpisode(_index + 1)
                                                : null,
                                      ),
                                      const SizedBox(width: 4),
                                      _controlButton(
                                        icon: Icons
                                            .picture_in_picture_alt_rounded,
                                        tooltip: 'Cửa sổ nổi',
                                        size: 23,
                                        onPressed: playable
                                            ? _enterPictureInPicture
                                            : null,
                                      ),
                                      const SizedBox(width: 4),
                                      _controlButton(
                                        icon: _fullscreen
                                            ? Icons.fullscreen_exit_rounded
                                            : Icons.fullscreen_rounded,
                                        tooltip: _fullscreen
                                            ? 'Thu nhỏ'
                                            : 'Toàn màn hình',
                                        size: 24,
                                        onPressed: () =>
                                            _setFullscreen(!_fullscreen),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                if (value.hasError)
                  Positioned(
                    top: 48,
                    left: 16,
                    right: 16,
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => _openEpisode(_index),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Video bị lỗi · Thử lại'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                if (_locked)
                  Positioned.fill(
                    child: SafeArea(
                      top: _fullscreen,
                      bottom: _fullscreen,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _controlButton(
                            icon: Icons.lock_rounded,
                            tooltip: 'Mở khóa điều khiển',
                            onPressed: _toggleLock,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),

                if (_nextEpisodeCountdown != null)
                  Positioned.fill(
                    child: SafeArea(
                      top: _fullscreen,
                      bottom: _fullscreen,
                      child: _autoNextOverlay(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _pipChannel.setMethodCallHandler(null);

    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _nextEpisodeTimer?.cancel();

    _controller?.removeListener(_onVideoChanged);

    unawaited(_saveProgress());
    _controller?.dispose();
    unawaited(_restoreSystemUi());

    super.dispose();
  }
}
