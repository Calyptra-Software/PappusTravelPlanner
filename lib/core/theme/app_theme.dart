import 'package:flutter/material.dart';

/// Central Material 3 theme. A single teal seed drives the whole colour scheme
/// in both light and dark, following the system setting.
class AppTheme {
  const AppTheme._();

  /// Travel-friendly teal seed.
  static const Color seed = Color(0xFF00695C);

  /// Preset accent colours offered when creating a trip.
  static const List<Color> tripAccents = [
    Color(0xFF00695C), // teal
    Color(0xFF1565C0), // blue
    Color(0xFF6A1B9A), // purple
    Color(0xFFAD1457), // pink
    Color(0xFFEF6C00), // orange
    Color(0xFF2E7D32), // green
    Color(0xFF37474F), // slate
  ];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 2,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}
