import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/backend_api.dart';

class AuthCubit extends Cubit<int> {
  final BackendApi api;

  AuthCubit(this.api) : super(0);

  Future<void> restore() async {
    await api.restore();
    emit(state + 1);
  }

  Future<void> login(String e, String p) async {
    await api.login(e, p);
    emit(state + 1);
  }

  Future<void> register(String n, String e, String p) async {
    await api.register(n, e, p);
    emit(state + 1);
  }

  Future<void> logout() async {
    await api.logout();
    emit(state + 1);
  }

  Future<void> uploadAvatar(String filePath) async {
    await api.uploadAvatar(filePath);

    if (!isClosed) {
      emit(state + 1);
    }
  }
}
