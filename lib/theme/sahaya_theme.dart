import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sahaya Design Tokens — Airbnb/Spotify-inspired
class SahayaColors {
  // ── Primary Emerald ──
  static const emerald     = Color(0xFF10B981);
  static const emeraldDark = Color(0xFF059669);
  static const emeraldMuted= Color(0xFFD1FAE5);

  // ── Accent Amber ──
  static const amber       = Color(0xFFF59E0B);
  static const amberMuted  = Color(0xFFFEF3C7);

  // ── Coral / Destructive ──
  static const coral       = Color(0xFFEF4444);
  static const coralMuted  = Color(0xFFFEE2E2);

  // ── Light palette ──
  static const lightBg     = Color(0xFFF9FAFB);
  static const lightSurface= Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE5E7EB);
  static const lightText   = Color(0xFF111827);
  static const lightMuted  = Color(0xFF6B7280);

  // ── Dark palette ──
  static const darkBg      = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkBorder  = Color(0xFF334155);
  static const darkText    = Color(0xFFF1F5F9);
  static const darkMuted   = Color(0xFF94A3B8);
}

BoxShadow sahayaCardShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxShadow(
    color: isDark ? Colors.black26 : const Color(0x0A000000),
    blurRadius: 20,
    offset: const Offset(0, 4),
  );
}

class SahayaTheme {
  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.interTextTheme(base);
  }

  // ━━━━━━━━━━━━━━━━ LIGHT ━━━━━━━━━━━━━━━━
  static ThemeData light() {
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: SahayaColors.lightBg,
      colorScheme: ColorScheme.light(
        primary:   SahayaColors.emerald,
        secondary: SahayaColors.amber,
        surface:   SahayaColors.lightSurface,
        error:     SahayaColors.coral,
        onPrimary: Colors.white,
        onSurface: SahayaColors.lightText,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: SahayaColors.lightSurface,
        foregroundColor: SahayaColors.lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: SahayaColors.lightText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: SahayaColors.lightText),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: SahayaColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: SahayaColors.emerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: SahayaColors.emerald,
          side: const BorderSide(color: SahayaColors.emerald, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SahayaColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SahayaColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SahayaColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SahayaColors.emerald, width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: SahayaColors.lightMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SahayaColors.lightSurface,
        indicatorColor: SahayaColors.emeraldMuted,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: SahayaColors.emerald);
          }
          return GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: SahayaColors.lightMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: SahayaColors.emerald);
          }
          return const IconThemeData(color: SahayaColors.lightMuted);
        }),
      ),
      dividerTheme: const DividerThemeData(color: SahayaColors.lightBorder, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: SahayaColors.lightBg,
        selectedColor: SahayaColors.emeraldMuted,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: const BorderSide(color: SahayaColors.lightBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━ DARK ━━━━━━━━━━━━━━━━
  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: SahayaColors.darkBg,
      colorScheme: ColorScheme.dark(
        primary:   const Color(0xFF34D399),
        secondary: const Color(0xFFFBBF24),
        surface:   SahayaColors.darkSurface,
        error:     const Color(0xFFF87171),
        onPrimary: SahayaColors.darkBg,
        onSurface: SahayaColors.darkText,
      ),
      textTheme: _buildTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: SahayaColors.darkSurface,
        foregroundColor: SahayaColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          color: SahayaColors.darkText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: SahayaColors.darkText),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: SahayaColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF34D399),
          foregroundColor: SahayaColors.darkBg,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF34D399),
          side: const BorderSide(color: Color(0xFF34D399), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: SahayaColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SahayaColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SahayaColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF34D399), width: 2),
        ),
        labelStyle: GoogleFonts.inter(color: SahayaColors.darkMuted),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: SahayaColors.darkSurface,
        indicatorColor: const Color(0xFF34D399).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF34D399));
          }
          return GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: SahayaColors.darkMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF34D399));
          }
          return const IconThemeData(color: SahayaColors.darkMuted);
        }),
      ),
      dividerTheme: const DividerThemeData(color: SahayaColors.darkBorder, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: SahayaColors.darkSurface,
        selectedColor: const Color(0xFF34D399).withValues(alpha: 0.15),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: const BorderSide(color: SahayaColors.darkBorder),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
