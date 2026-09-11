import 'package:flutter/material.dart';

/// Seed colour that drives the example app's Material 3 colour scheme.
const Color seedColor = Color(0xFF6366F1);

/// Builds the light theme for the example app.
ThemeData buildLightTheme() => _themeFor(Brightness.light);

/// Builds the dark theme for the example app.
ThemeData buildDarkTheme() => _themeFor(Brightness.dark);

ThemeData _themeFor(Brightness brightness) {
  final ColorScheme colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
  );
}
