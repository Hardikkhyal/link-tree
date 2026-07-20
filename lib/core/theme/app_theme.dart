import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Curated Color Palette
  static const Color background = Color(0xFF0F172A); // Deep Slate
  static const Color surface = Color(0xFF1E293B);    // Slate Dark Glass
  static const Color surfaceLight = Color(0xFF334155);
  static const Color primary = Color(0xFF06B6D4);    // Electric Cyan
  static const Color secondary = Color(0xFF6366F1);  // Vibrant Indigo
  static const Color accent = Color(0xFF10B981);     // Emerald Green
  static const Color warning = Color(0xFFF59E0B);    // Amber
  static const Color danger = Color(0xFFEF4444);     // Crimson Red
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

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
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      useMaterial3: true,
    );
  }

  /// Frosted Glass Decoration Box
  static BoxDecoration glassDecoration({
    double opacity = 0.6,
    double borderRadius = 16,
    Color borderColor = Colors.white10,
  }) {
    return BoxDecoration(
      color: surface.withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 16,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
