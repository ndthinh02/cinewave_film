import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.dark);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    emit((p.getBool('dark') ?? true) ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> toggle() async {
    final n = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    emit(n);
    (await SharedPreferences.getInstance()).setBool(
      'dark',
      n == ThemeMode.dark,
    );
  }
}
