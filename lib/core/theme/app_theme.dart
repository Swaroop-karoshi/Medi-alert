import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium minimal aesthetics (Notion/Apple/Stripe inspired)
  static const _primary = Color(0xFF6366F1); // Indigo
  static const _onPrimary = Color(0xFFFFFFFF);
  static const _secondary = Color(0xFFE2E8F0); // Soft grey-blue for secondary actions
  static const _onSecondary = Color(0xFF1E293B);
  
  static const _surface = Color(0xFFFFFFFF);
  static const _onSurface = Color(0xFF0F172A); // Very dark slate for primary text
  static const _background = Color(0xFFFAFAFA); // Off-white
  
  static const _error = Color(0xFFEF4444); // Red
  static const _onError = Color(0xFFFFFFFF);

  static const _outline = Color(0xFFE2E8F0); // Subtle borders
  static const _outlineVariant = Color(0xFFF1F5F9); 

  static const _mutedText = Color(0xFF64748B); // Muted slate gray

  static TextTheme _buildTextTheme() {
    // Inter provides the premium, clean sans-serif look
    final base = GoogleFonts.interTextTheme();
    
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.0, color: _onSurface),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8, color: _onSurface),
      displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5, color: _onSurface),
      headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4, color: _onSurface),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2, color: _onSurface),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: _onSurface),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: _onSurface),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: _onSurface),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: _onSurface),
      bodyLarge: base.bodyLarge?.copyWith(color: _onSurface, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: _onSurface, height: 1.5),
      bodySmall: base.bodySmall?.copyWith(color: _mutedText, height: 1.5),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.1),
      labelSmall: base.labelSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0),
    );
  }

  static ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: _onPrimary,
      secondary: _secondary,
      onSecondary: _onSecondary,
      error: _error,
      onError: _onError,
      surface: _surface,
      onSurface: _onSurface,
      outline: _outline,
      outlineVariant: _outlineVariant,
      surfaceContainerHighest: _outlineVariant,
      onSurfaceVariant: _mutedText,
    ),
    scaffoldBackgroundColor: _background,
    canvasColor: _background,
    textTheme: _buildTextTheme(),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: _onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: _onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: _onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _outline, width: 1),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: _onSurface),
      contentTextStyle: GoogleFonts.inter(fontSize: 15, color: _mutedText, height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _onSurface,
      contentTextStyle: GoogleFonts.inter(color: _surface, fontSize: 14, fontWeight: FontWeight.w500),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: _outlineVariant,
      selectedColor: _primary.withValues(alpha: 0.1),
      disabledColor: _outlineVariant.withValues(alpha: 0.3),
      labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: _onSurface),
      secondaryLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _primary),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: Colors.transparent),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surface,
      hintStyle: GoogleFonts.inter(color: _mutedText, fontSize: 15),
      labelStyle: GoogleFonts.inter(color: _mutedText, fontSize: 15),
      prefixIconColor: _mutedText,
      suffixIconColor: _mutedText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: _onPrimary,
        backgroundColor: _primary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: _outline, width: 1.5),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _primary,
      foregroundColor: _onPrimary,
      elevation: 4,
      focusElevation: 4,
      hoverElevation: 6,
      highlightElevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    iconTheme: const IconThemeData(color: _onSurface, size: 24),
    listTileTheme: ListTileThemeData(
      iconColor: _mutedText,
      textColor: _onSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _onPrimary;
        return _mutedText;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primary;
        return _outlineVariant;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _primary,
      linearTrackColor: _outlineVariant,
      circularTrackColor: _outlineVariant,
    ),
    dividerTheme: const DividerThemeData(
      color: _outline,
      thickness: 1,
      space: 1,
    ),
  );

  // Defaulting to light as dark is removed or aliased for this clean redesign
  static ThemeData dark = light; 
}
