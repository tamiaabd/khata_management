import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/constants.dart';

ThemeData buildAppTheme({
  required String urduFont,
  required String englishFont,
}) {
  const primary = AppColors.primary;

  final englishTextTheme = _englishTextTheme(englishFont);

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: AppColors.paper,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: _englishStyle(
        englishFont,
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.paper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.gridLine,
      thickness: 1,
      space: 1,
    ),
    textTheme: TextTheme(
      bodyLarge: _mergeUrdu(englishTextTheme.bodyLarge, urduFont),
      bodyMedium: _mergeUrdu(englishTextTheme.bodyMedium, urduFont),
      titleMedium: _mergeUrdu(englishTextTheme.titleMedium, urduFont),
      titleLarge: _mergeUrdu(englishTextTheme.titleLarge, urduFont),
    ),
  );
}

TextTheme _englishTextTheme(String font) {
  return switch (font) {
    'Poppins' => Typography.material2021().black.apply(fontFamily: 'Poppins'),
    'Roboto' => GoogleFonts.robotoTextTheme(),
    'Open Sans' => GoogleFonts.openSansTextTheme(),
    'Inter' => GoogleFonts.interTextTheme(),
    'Lato' => GoogleFonts.latoTextTheme(),
    _ => Typography.material2021().black.apply(fontFamily: 'Poppins'),
  };
}

TextStyle? _mergeUrdu(TextStyle? base, String urduFont) {
  return base?.copyWith(fontFamilyFallback: [urduFont]);
}

TextStyle _englishStyle(
  String font, {
  required double fontSize,
  required FontWeight fontWeight,
  required Color color,
}) {
  final base = TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
  return switch (font) {
    'Poppins' => base.copyWith(fontFamily: 'Poppins'),
    'Roboto' => GoogleFonts.roboto(textStyle: base),
    'Open Sans' => GoogleFonts.openSans(textStyle: base),
    'Inter' => GoogleFonts.inter(textStyle: base),
    'Lato' => GoogleFonts.lato(textStyle: base),
    _ => base.copyWith(fontFamily: 'Poppins'),
  };
}
