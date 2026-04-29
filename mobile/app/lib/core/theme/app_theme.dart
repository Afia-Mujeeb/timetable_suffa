import "package:flutter/material.dart";

class AppTheme {
  static const Color _pine = Color(0xFF174A41);
  static const Color _mint = Color(0xFF6BB89A);
  static const Color _sand = Color(0xFFF5F1E8);
  static const Color _ink = Color(0xFF14211D);
  static const Color _fog = Color(0xFFE1E6DF);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _pine,
      brightness: Brightness.light,
    ).copyWith(
      primary: _pine,
      secondary: _mint,
      surface: Colors.white,
      error: const Color(0xFFB42318),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _sand,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: _fog),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFEAF2EE),
        selectedColor: _pine,
        secondarySelectedColor: _pine,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFEAF2EE),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? _pine
                : const Color(0xFF53645C),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAF7),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _fog),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _fog),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _pine, width: 1.5),
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 34,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: _ink,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.5,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: Color(0xFF46564F),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _pine,
        ),
      ),
    );
  }
}
