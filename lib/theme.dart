import 'package:flutter/material.dart';

const kBg = Color(0xFF2F3656);
const kBarBg = Color(0xFF2A3050);
const kCard = Color(0xFF3B4163);
const kChip = Color(0xFF3A4570);
const kTrack = Color(0xFF3A4060);
const kAccent = Color(0xFF7EA8F5);
const kDim = Color(0xFFA9B0C8);
const kText = Color(0xFFEDEFF7);
const kOnAccent = Color(0xFF16203D);
const kRed = Color(0xFFFF7A85);
const kGreen = Color(0xFF6FD39B);
const kAmber = Color(0xFFFFC857);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kAccent,
    brightness: Brightness.dark,
  ).copyWith(
    surface: kBg,
    primary: kAccent,
    onPrimary: kOnAccent,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    canvasColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kText,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: kBarBg,
      indicatorColor: kChip,
    ),
  );
}
