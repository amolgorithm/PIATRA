import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core palette ───────────────────────────────────────────────────────────
  static const Color primaryPurple    = Color(0xFF7C6EFA);
  static const Color primaryPurpleDeep = Color(0xFF5B4FD4);
  static const Color secondaryTeal    = Color(0xFF00D4AA);
  static const Color accentOrange     = Color(0xFFFF6B6B);
  static const Color accentAmber      = Color(0xFFFFB347);

  // Light surface — neutral off-white, not lavender-tinted
  static const Color backgroundLight  = Color(0xFFF7F7F8);
  static const Color surfaceLight     = Color(0xFFFFFFFF);
  static const Color cardLight        = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF12111A);
  static const Color textSecondaryLight = Color(0xFF7B7A8E);

  // Dark surface — deep space aesthetic
  static const Color backgroundDark   = Color(0xFF0D0C14);
  static const Color surfaceDark      = Color(0xFF13121C);
  static const Color cardDark         = Color(0xFF1C1A2A);
  static const Color cardDarkElevated = Color(0xFF242235);
  static const Color textPrimaryDark  = Color(0xFFEEECFF);
  static const Color textSecondaryDark = Color(0xFF7C7A9A);

  // Semantic
  static const Color successGreen   = Color(0xFF00D4AA);
  static const Color errorRed       = Color(0xFFFF6B6B);
  static const Color warningYellow  = Color(0xFFFFB347);
  static const Color infoBlue       = Color(0xFF5B9EF9);

  // Legacy aliases used across the app
  static const Color primaryGreen   = secondaryTeal;
  static const Color secondaryOrange = accentOrange;
  static const Color textPrimary    = textPrimaryLight;
  static const Color textSecondary  = textSecondaryLight;

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF7C6EFA), Color(0xFF5B4FD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF00D4AA), Color(0xFF00A882)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0D0C14), Color(0xFF13121C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Mesh-style background glow for dark mode hero areas
  static RadialGradient get purpleGlow => const RadialGradient(
    colors: [Color(0x337C6EFA), Color(0x00000000)],
    radius: 0.8,
  );

  // ── Text styles ────────────────────────────────────────────────────────────
  // Using Sora for display + DM Sans for body — distinctive pairing
  static TextStyle _display(Color c) => GoogleFonts.sora(
    color: c, fontWeight: FontWeight.w800, letterSpacing: -1.0,
  );
  static TextStyle _body(Color c) => GoogleFonts.dmSans(color: c);

  // ── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    const c = ColorScheme(
      brightness: Brightness.light,
      primary: primaryPurple,
      onPrimary: Colors.white,
      secondary: secondaryTeal,
      onSecondary: Colors.white,
      surface: surfaceLight,
      onSurface: textPrimaryLight,
      error: errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: c,
      scaffoldBackgroundColor: backgroundLight,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimaryLight),
        titleTextStyle: GoogleFonts.sora(
          color: textPrimaryLight, fontSize: 22, fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x10000000)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: _inputTheme(Brightness.light),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // ── Dark Theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    const c = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryPurple,
      onPrimary: Colors.white,
      secondary: secondaryTeal,
      onSecondary: Colors.black,
      surface: surfaceDark,
      onSurface: textPrimaryDark,
      error: errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: c,
      scaffoldBackgroundColor: backgroundDark,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        centerTitle: false,
        iconTheme: const IconThemeData(color: textPrimaryDark),
        titleTextStyle: GoogleFonts.sora(
          color: textPrimaryDark, fontSize: 22, fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x18FFFFFF)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: _inputTheme(Brightness.dark),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? textPrimaryDark : textPrimaryLight;
    final secondary = isDark ? textSecondaryDark : textSecondaryLight;

    return TextTheme(
      displayLarge: GoogleFonts.sora(
        fontSize: 40, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.sora(
        fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1.0,
      ),
      displaySmall: GoogleFonts.sora(
        fontSize: 26, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.sora(
        fontSize: 26, fontWeight: FontWeight.w700, color: primary,
      ),
      headlineMedium: GoogleFonts.sora(
        fontSize: 22, fontWeight: FontWeight.w700, color: primary,
      ),
      headlineSmall: GoogleFonts.sora(
        fontSize: 18, fontWeight: FontWeight.w600, color: primary,
      ),
      titleLarge: GoogleFonts.sora(
        fontSize: 17, fontWeight: FontWeight.w600, color: primary,
      ),
      titleMedium: GoogleFonts.dmSans(
        fontSize: 15, fontWeight: FontWeight.w600, color: primary,
      ),
      bodyLarge: GoogleFonts.dmSans(fontSize: 16, color: primary, height: 1.6),
      bodyMedium: GoogleFonts.dmSans(fontSize: 14, color: primary, height: 1.5),
      bodySmall: GoogleFonts.dmSans(fontSize: 12, color: secondary, height: 1.4),
      labelLarge: GoogleFonts.dmSans(
        fontSize: 14, fontWeight: FontWeight.w600, color: primary,
      ),
    );
  }

  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? cardDark : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x18000000)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0x20FFFFFF) : const Color(0x18000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryPurple, width: 2),
      ),
      hintStyle: GoogleFonts.dmSans(
        color: isDark ? textSecondaryDark : textSecondaryLight, fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    );
  }
}