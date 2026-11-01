import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF0F4C5C); // azul petróleo
  static const accent = Color(0xFFF4A259); // ámbar: XP, racha, logros
  static const good = Color(0xFF2E9E6A); // puntaje >= 80
  static const ok = Color(0xFFD99100); // 60–79
  static const bad = Color(0xFFD64545); // < 60
  static const lightBg = Color(0xFFF6F7F9);
  static const darkBg = Color(0xFF0E1417);
}

/// Color, icono y etiqueta según el puntaje (nunca solo color: accesibilidad).
Color scoreColor(num score) =>
    score >= 80 ? AppColors.good : (score >= 60 ? AppColors.ok : AppColors.bad);

IconData scoreIcon(num score) => score >= 80
    ? Icons.check_circle
    : (score >= 60 ? Icons.error_outline : Icons.cancel);

String scoreLabel(num score) => score >= 80
    ? 'Muy bien'
    : (score >= 60 ? 'Casi' : 'A mejorar');

/// Tipografía de los textos de lectura: serif, como un documento real.
TextStyle readingStyle(BuildContext context, {double size = 18}) {
  final color = Theme.of(context).colorScheme.onSurface;
  return GoogleFonts.getFont('Source Serif 4',
      fontSize: size, height: 1.6, color: color);
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
    primary: isDark ? const Color(0xFF7FC4D4) : AppColors.primary,
    secondary: AppColors.accent,
    surface: isDark ? const Color(0xFF162024) : Colors.white,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
