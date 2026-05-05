import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color _lightBg = Color(0xFFFBFBFA);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _accent = Color(0xFF0D9488); // Deep Teal/Sage

  // Light Theme Definition
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBg,
    colorScheme: const ColorScheme.light(
      primary: _accent,
      surface: Colors.white,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.lora(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E293B),
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        color: const Color(0xFF334155),
      ),
    ),
  );

  // Dark Theme Definition
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBg,
    colorScheme: const ColorScheme.dark(
      primary: _accent,
      surface: Color(0xFF1E293B),
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.lora(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: const Color(0xFFF8FAFC),
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        color: const Color(0xFFCBD5E1),
      ),
    ),
  );
}