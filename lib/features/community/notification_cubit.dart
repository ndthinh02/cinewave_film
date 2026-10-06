import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_cubit.dart';
import '../../core/config.dart';
import 'community_api.dart';

class NotificationState {
  const NotificationState(this.unread, this.revision);
  final int unread, revision;
}

class NotificationCubit extends Cubit<NotificationState>
    with WidgetsBindingObserver {
  NotificationCubit(this.auth) : super(const NotificationState(0, 0)) {
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = auth.stream.listen((_) => _session());
    _session();
  }
  final AuthCubit auth;
  final _api = CommunityApi();
  late final StreamSubscription<int> _authSubscription;
  String? _token;
  WebSocket? _socket;
  Timer? _poll, _retry, _heartbeat;
  int _epoch = 0, _attempt = 0;
  bool _refreshing = false, _connecting = false;
  void _session() {
    if (_token == auth.api.token) return;
    _token = auth.api.token;
    _epoch++;
    _socket?.close();
    _socket = null;
    _poll?.cancel();
    _retry?.cancel();
    _heartbeat?.cancel();
    _attempt = 0;
    _refreshing = false;
    _connecting = false;
    emit(NotificationState(0, state.revision + 1));
    if (_token != null) {
      refresh();
      _connect(_epoch);
      _poll = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    }
  }

  Future<void> refresh() async {
    if (_token == null || _refreshing || isClosed) return;
    final epoch = _epoch;
    _refreshing = true;
    try {
      final data = await _api.request('/notifications/unread-count', _token);
      if (!isClosed && epoch == _epoch)
        emit(NotificationState(
            (data['count'] as num?)?.toInt() ?? 0, state.revision + 1));
    } catch (_) {
    } finally {
      if (epoch == _epoch) _refreshing = false;
    }
  }

  Future<void> _connect(int epoch) async {
    if (epoch != _epoch ||
        _token == null ||
        isClosed ||
        _connecting ||
        _socket != null) return;
    _connecting = true;
    try {
      final base = Uri.parse(AppConfig.backendBaseUrl);
      final uri = base.replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '/socket.io/',
          query: 'EIO=4&transport=websocket');
      final socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 10));
      if (epoch != _epoch || isClosed) {
        await socket.close();
        return;
      }
      _socket = socket;
      _connecting = false;
      int timeout = 45000;
      void heartbeat() {
        _heartbeat?.cancel();
        _heartbeat =
            Timer(Duration(milliseconds: timeout), () => socket.close());
      }

      heartbeat();
      socket.listen(
          (packet) {
            if (epoch != _epoch || packet is! String) return;
            heartbeat();
            if (packet.startsWith('0')) {
              try {
                final open = jsonDecode(packet.substring(1));
                timeout = (open['pingInterval'] as int) +
                    (open['pingTimeout'] as int);
                heartbeat();
              } catch (_) {}
              socket.add('40${jsonEncode({'token': _token})}');
            } else if (packet == '2')
              socket.add('3');
            else if (packet.startsWith('40')) {
              _attempt = 0;
              refresh();
            } else if (packet.startsWith('42')) {
              try {
                final event = jsonDecode(packet.substring(2));
                if (event is List && event.first == 'notification') refresh();
              } catch (_) {}
            } else if (packet.startsWith('44') ||
                packet == '41' ||
                packet == '1') socket.close();
          },
          onDone: () => _reconnect(epoch),
          onError: (Object _) {
            _socket?.close();
          },
          cancelOnError: false);
    } catch (_) {
      if (epoch == _epoch) _connecting = false;
      _reconnect(epoch);
    }
  }

  void _reconnect(int epoch) {
    if (epoch != _epoch || isClosed || _token == null) return;
    _socket = null;
    _heartbeat?.cancel();
    _retry?.cancel();
    _attempt = (_attempt + 1).clamp(1, 5);
    _retry = Timer(Duration(seconds: 1 << _attempt), () => _connect(epoch));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      refresh();
      if (_socket == null) _connect(_epoch);
    }
  }

  @override
  Future<void> close() async {
    _epoch++;
    _poll?.cancel();
    _retry?.cancel();
    _heartbeat?.cancel();
    await _socket?.close();
    await _authSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
