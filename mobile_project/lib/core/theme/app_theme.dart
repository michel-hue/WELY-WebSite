import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: WellyColors.ink,
    onPrimary: WellyColors.ivoire,
    secondary: WellyColors.laiton,
    onSecondary: WellyColors.ink,
    surface: WellyColors.surface,
    onSurface: WellyColors.ink,
    outline: WellyColors.line,
    error: WellyColors.expired,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: WellyColors.ivoire,
    fontFamily: 'Inter',
  );
  TextStyle inter(double size, FontWeight weight, Color color) => TextStyle(
        fontFamily: 'Inter',
        fontWeight: weight,
        fontSize: size,
        color: color,
      );
  final text = base.textTheme
      .apply(
        fontFamily: 'Inter',
        bodyColor: WellyColors.ink,
        displayColor: WellyColors.ink,
      )
      .copyWith(
        bodyLarge: inter(16, FontWeight.w300, WellyColors.ink),
        bodyMedium: inter(14, FontWeight.w300, WellyColors.ink),
        bodySmall: inter(12, FontWeight.w300, WellyColors.muted),
        titleMedium: inter(16, FontWeight.w500, WellyColors.ink),
        labelLarge: inter(14, FontWeight.w500, WellyColors.ink),
      );
  const stadium = StadiumBorder();
  const buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 14);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(WellyRadii.card),
        borderSide: BorderSide(color: color),
      );
  return base.copyWith(
    textTheme: text,
    dividerColor: WellyColors.line,
    appBarTheme: const AppBarTheme(
      backgroundColor: WellyColors.ivoire,
      foregroundColor: WellyColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: WellyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WellyRadii.card),
        side: const BorderSide(color: WellyColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WellyColors.ink,
        foregroundColor: WellyColors.ivoire,
        shape: stadium,
        padding: buttonPadding,
        textStyle: text.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: WellyColors.laiton,
        foregroundColor: WellyColors.ink,
        elevation: 0,
        shape: stadium,
        padding: buttonPadding,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: WellyColors.ink,
        side: const BorderSide(color: WellyColors.line),
        shape: stadium,
        padding: buttonPadding,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: WellyColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(WellyRadii.sheet)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WellyColors.surface,
      border: border(WellyColors.line),
      enabledBorder: border(WellyColors.line),
      focusedBorder: border(WellyColors.laiton),
    ),
  );
}
