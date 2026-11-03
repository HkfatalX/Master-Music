import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF0B0714);
  static const surface = Color(0xFF161022);
  static const surface2 = Color(0xFF1F1830);
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const cyan = Color(0xFF22D3EE);
  static const text = Color(0xFFF5F3FF);
  static const muted = Color(0xFFA79BC4);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, pink],
  );
}

ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.violet,
    brightness: Brightness.dark,
    surface: C.surface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
