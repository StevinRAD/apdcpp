import 'package:flutter/material.dart';

class TemaAplikasi {
  static const Color emas = Color(0xFFD2A92B);
  static const Color emasTua = Color(0xFF9F7A16);
  static const Color biruTua = Color(0xFF102845);
  static const Color biruMuda = Color(0xFFE9F1FB);
  static const Color latar = Color(0xFFF4F7FB);
  static const Color kartu = Colors.white;
  static const Color teksUtama = Color(0xFF1A2330);
  static const Color sukses = Color(0xFF1E8E5A);
  static const Color bahaya = Color(0xFFC44536);
  static const Color netral = Color(0xFF617083);

  static ThemeData get tema {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: emas,
      primary: emas,
      secondary: biruTua,
      surface: kartu,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: latar,
      cardTheme: CardThemeData(
        color: kartu,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: const Color(0x12000000),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: biruTua,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: biruTua,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: emas, width: 1.4),
        ),
        labelStyle: const TextStyle(color: netral),
        hintStyle: const TextStyle(color: Color(0xFF8A96A8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emas,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: biruTua,
          side: const BorderSide(color: Color(0xFFD0D9E5)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: emas,
        unselectedItemColor: Color(0xFF7A8798),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: biruMuda,
        selectedColor: emas.withValues(alpha: 0.16),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        labelStyle: const TextStyle(
          color: teksUtama,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );
  }
}

