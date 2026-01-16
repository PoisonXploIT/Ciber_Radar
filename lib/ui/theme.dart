import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color background = Color(0xFF000000); // Deep Black
  static const Color primary = Color(0xFF00FF41); // Matrix Green / Neon Green
  static const Color secondary = Color(0xFF008F11); // Darker Green
  static const Color accent = Color(0xFFD60270); // Cyberpunk Pink (for errors/alerts)
  static const Color warning = Color(0xFFFF9F00); // Neon Orange/Yellow
  static const Color textHigh = Color(0xFF00FF41); // High contrast text
  static const Color textMedium = Color(0xFF00B02E); // Medium contrast
  static const Color textDim = Color(0xFF003B00); // Dimmed text

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: background,
        error: accent,
        onPrimary: background,
        onSecondary: background,
        onSurface: textHigh,
        onError: background,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.jetBrainsMono(color: textHigh, fontWeight: FontWeight.bold),
        displayMedium: GoogleFonts.jetBrainsMono(color: textHigh, fontWeight: FontWeight.bold),
        bodyLarge: GoogleFonts.jetBrainsMono(color: textHigh, fontSize: 16),
        bodyMedium: GoogleFonts.jetBrainsMono(color: textHigh, fontSize: 14),
        labelLarge: GoogleFonts.jetBrainsMono(color: background, fontWeight: FontWeight.bold), // Button text
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.jetBrainsMono(color: primary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        iconTheme: const IconThemeData(color: primary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade800,
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          shape: const BeveledRectangleBorder(), // Angled corners like cyberpunk
          textStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}