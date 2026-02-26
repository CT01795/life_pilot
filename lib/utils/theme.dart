import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    primaryColor: const Color(0xFF0066CC),
    scaffoldBackgroundColor: Colors.white,
    textTheme: const TextTheme().apply(
      fontSizeFactor: 1.5,
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xFF0066CC),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF0066CC),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF00BFA6),
        side: const BorderSide(color: Color(0xFF00BFA6)),
      ),
    ),
    iconTheme: const IconThemeData(size: 36),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0066CC),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(color: Colors.white),
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      floatingLabelStyle: const TextStyle(color: Color(0xFF0066CC)),
      labelStyle: TextStyle(color: Colors.grey[700]),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueGrey),
      ),
    ),
  );
}
