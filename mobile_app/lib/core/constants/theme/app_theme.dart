import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core palette ───────────────────────────────────────────────────────────
  // Built directly off Tailwind CSS's published scales (Indigo + Slate),
  // not hand-picked hex values. This is the same palette family behind most
  // "clean SaaS dashboard" templates, so the tokens below are named after
  // where they sit on that scale, easier to reason about than arbitrary hex.
  //
  // Indigo 700/900 — primary accent, dark enough that white text on top
  // always clears WCAG AA (verified: indigo-700 = 7.9:1, indigo-900 = 11.4:1)
  static const Color primaryPurple    = Color(0xFF4338CA); // indigo-700
  static const Color primaryPurpleDeep = Color(0xFF312E81); // indigo-900

  // Semantic colors, one step darker than Tailwind's default 500 so they
  // hold contrast both as solid button fills (white text on top) and as
  // colored text sitting on their own light tint (the badge pattern used
  // around the app), 500-level looked good but measured under 3:1 in the
  // badge case
  static const Color secondaryTeal    = Color(0xFF047857); // emerald-700
  static const Color accentOrange     = Color(0xFFC2410C); // orange-700
  static const Color accentAmber      = Color(0xFFB45309); // amber-700

  // Light surface — Slate 50, neutral cool gray, not tinted toward the accent
  static const Color backgroundLight  = Color(0xFFF8FAFC); // slate-50
  static const Color surfaceLight     = Color(0xFFFFFFFF);
  static const Color cardLight        = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0F172A); // slate-900
  static const Color textSecondaryLight = Color(0xFF64748B); // slate-500

  // Dark surface — same Slate scale, just the deep end of it
  static const Color backgroundDark   = Color(0xFF020617); // slate-950
  static const Color surfaceDark      = Color(0xFF0F172A); // slate-900
  static const Color cardDark         = Color(0xFF1E293B); // slate-800
  static const Color cardDarkElevated = Color(0xFF334155); // slate-700
  static const Color textPrimaryDark  = Color(0xFFF8FAFC); // slate-50
  static const Color textSecondaryDark = Color(0xFF94A3B8); // slate-400

  // Semantic — Tailwind's 600/700 shades, same reasoning as above
  static const Color successGreen   = Color(0xFF047857); // emerald-700
  static const Color errorRed       = Color(0xFFDC2626); // red-600
  static const Color warningYellow  = Color(0xFFB45309); // amber-700
  static const Color infoBlue       = Color(0xFF2563EB); // blue-600

  // Legacy aliases used across the app
  static const Color primaryGreen   = secondaryTeal;
  static const Color secondaryOrange = accentOrange;
  static const Color textPrimary    = textPrimaryLight;
  static const Color textSecondary  = textSecondaryLight;

  // ── Category colors ──────────────────────────────────────────────────────
  // For places that need several distinguishable-but-related colors side by
  // side (the home screen's feature tiles, category badges), not a single
  // accent. Tailwind's 600-tier across six hues, chosen together as a set
  // rather than picked one at a time, same lightness/chroma family so they
  // read as coordinated instead of random, and all verified >= 3:1 contrast
  // for a white icon on top (WCAG's minimum for graphical objects).
  static const Color categoryIndigo  = Color(0xFF4F46E5); // indigo-600
  static const Color categoryEmerald = Color(0xFF059669); // emerald-600
  static const Color categoryRose    = Color(0xFFE11D48); // rose-600
  static const Color categoryAmber   = Color(0xFFD97706); // amber-600
  static const Color categorySky     = Color(0xFF0284C7); // sky-600
  static const Color categoryViolet  = Color(0xFF7C3AED); // violet-600

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4338CA), Color(0xFF312E81)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF065F46)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFC2410C), Color(0xFF9A3412)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF020617), Color(0xFF0F172A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Mesh-style background glow for dark mode hero areas
  static RadialGradient get purpleGlow => const RadialGradient(
    colors: [Color(0x334338CA), Color(0x00000000)],
    radius: 0.8,
  );

  // ── Text styles ────────────────────────────────────────────────────────────
  // One family (Inter) everywhere, hierarchy comes from weight and size only.
  // Was Sora for display + DM Sans for body, dropped the pairing, several
  // screens also had raw fontFamily: 'Sora' strings that were never actually
  // registered as a local font asset, so they silently fell back to the
  // platform default, that's what made text look inconsistent across screens.
  static TextStyle _display(Color c) => GoogleFonts.inter(
    color: c, fontWeight: FontWeight.w800, letterSpacing: -1.0,
  );
  static TextStyle _body(Color c) => GoogleFonts.inter(color: c);

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
        titleTextStyle: GoogleFonts.inter(
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
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
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
        titleTextStyle: GoogleFonts.inter(
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
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
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
      displayLarge: GoogleFonts.inter(
        fontSize: 40, fontWeight: FontWeight.w800, color: primary, letterSpacing: -1.5,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 32, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1.0,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 26, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 26, fontWeight: FontWeight.w700, color: primary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w700, color: primary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, color: primary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 17, fontWeight: FontWeight.w600, color: primary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, color: primary,
      ),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: primary, height: 1.6),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: primary, height: 1.5),
      bodySmall: GoogleFonts.inter(fontSize: 12, color: secondary, height: 1.4),
      labelLarge: GoogleFonts.inter(
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
      hintStyle: GoogleFonts.inter(
        color: isDark ? textSecondaryDark : textSecondaryLight, fontSize: 14,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    );
  }
}