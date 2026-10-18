import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class AppTheme {
  // Verde V10 escurecido para manter contraste AA sobre fundo claro (luz solar direta).
  static const Color _lightGreen = Color(0xFF1B7F0A);
  static const Color _lightBackground = Color(0xFFF8F9FA);
  static const Color _lightText = Color(0xFF111111);

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _lightGreen,
        brightness: Brightness.light,
      ).copyWith(
        primary: _lightGreen,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black,
      ),
      scaffoldBackgroundColor: _lightBackground,
      cardColor: Colors.white,
      dividerColor: const Color(0xFFCFD4DA),
      useMaterial3: true,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: _lightText,
        displayColor: Colors.black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        titleTextStyle: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.successGreen,
        brightness: Brightness.dark,
      ).copyWith(
        surface: const Color(0xFF151A22),
        onSurface: AppColors.textWhite,
      ),
      scaffoldBackgroundColor: AppColors.backgroundBody,
      cardColor: const Color(0xFF151A22),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundBody,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textWhite),
        titleTextStyle: TextStyle(color: AppColors.textWhite, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
