import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ────────────────────────────────────────────────────
  // Warm Brown "Uxintace" Palette
  // ────────────────────────────────────────────────────
  static const Color background   = Color(0xFF3E2522); // Deep Espresso
  static const Color surface      = Color(0xFF5A3A34); // Dark Mocha
  static const Color surfaceLight = Color(0xFF8C6E63); // Warm Taupe
  static const Color primary      = Color(0xFFD3A376); // Sandy Amber  ← main accent
  static const Color secondary    = Color(0xFFFFE0B2); // Soft Cream   ← secondary accent
  static const Color accent       = Color(0xFFD3A376); // Sandy Amber  (alias)
  static const Color warning      = Color(0xFFFFB74D); // Warm Orange
  static const Color danger       = Color(0xFFE57373); // Muted Red
  static const Color success      = Color(0xFF81C784); // Soft Green
  static const Color textPrimary  = Color(0xFFFFF2DF); // Warm Off-White
  static const Color textSecondary= Color(0xFFFFE0B2); // Creamy Tan

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        background: background,
        error: danger,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white12),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primary, width: 1.8),
          borderRadius: BorderRadius.circular(12),
        ),
        hintStyle: const TextStyle(color: surfaceLight),
      ),
      useMaterial3: true,
    );
  }

  /// Frosted glass card decoration using the new brown palette
  static BoxDecoration glassDecoration({
    double opacity = 0.55,
    double borderRadius = 16,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: surface.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? primary.withOpacity(0.18),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 18,
          spreadRadius: 2,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}
