import 'package:flutter/material.dart';

/// Identidad visual «Elegant Social Time»: fondos neutros y luminosos,
/// superficies blancas bien delimitadas, tipografía de alto contraste y
/// colores de identidad que solo aparecen como acentos.
abstract final class AppTheme {
  // ------------------------------------------------------------ neutros
  static const background = Color(0xFFF7F8FA);
  static const surface = Colors.white;

  /// Negro cálido: horas, títulos, acciones principales y navegación activa.
  static const ink = Color(0xFF16151B);
  static const inkSecondary = Color(0xFF6B6E78);
  static const inkTertiary = Color(0xFFA3A6AF);
  static const border = Color(0xFFE7E9ED);

  // ------------------------------------------------- colores de identidad
  static const cyan = Color(0xFF0BA5C4);
  static const violet = Color(0xFF7C3AED);
  static const orange = Color(0xFFF2711C);
  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF16A34A);
  static const pink = Color(0xFFE5488A);

  // ------------------------------------------------------------ estados
  static const success = green;
  static const warning = Color(0xFFE59A0B);
  static const danger = Color(0xFFDC2626);

  /// Alarmas recurrentes (rutinas, clases).
  static const recurring = blue;

  /// Compatibilidad: acento principal de la marca.
  static const seed = violet;

  /// Degradado violeta del objeto de creación y del logotipo del asistente.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9F7AEA), violet, Color(0xFF5B21B6)],
  );

  /// Sombra suave para separar capas (no para "hacer flotar").
  static List<BoxShadow> softShadow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const []
          : [
              BoxShadow(color: const Color(0xFF1B1D2A).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
              BoxShadow(color: const Color(0xFF1B1D2A).withValues(alpha: 0.03), blurRadius: 2, offset: const Offset(0, 1)),
            ];

  /// Hora como imagen tipográfica: peso medio, tracking negativo y números
  /// tabulares.
  static TextStyle time(double size, {Color? color}) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -size * 0.045,
        height: 1.0,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Etiqueta de categoría: mayúsculas pequeñas con espaciado amplio.
  static TextStyle eyebrow(BuildContext context, {Color? color}) => TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
      );

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFF4F4F6) : AppTheme.ink;
    final secondaryInk = isDark ? const Color(0xFFA0A3AD) : inkSecondary;
    final line = isDark ? const Color(0xFF2B2B33) : border;
    final card = isDark ? const Color(0xFF17171C) : surface;
    final bg = isDark ? const Color(0xFF0D0D10) : background;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: isDark ? AppTheme.ink : Colors.white,
      primaryContainer: isDark ? const Color(0xFF26262E) : const Color(0xFFEFEFF3),
      onPrimaryContainer: ink,
      secondary: violet,
      onSecondary: Colors.white,
      secondaryContainer: isDark ? const Color(0xFF2A2140) : const Color(0xFFF1EAFE),
      onSecondaryContainer: isDark ? const Color(0xFFD9C8FB) : const Color(0xFF4C1D95),
      tertiary: cyan,
      onTertiary: Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF13313A) : const Color(0xFFE3F6FA),
      onTertiaryContainer: isDark ? const Color(0xFFA5E6F3) : const Color(0xFF0B5566),
      error: danger,
      onError: Colors.white,
      surface: card,
      onSurface: ink,
      onSurfaceVariant: secondaryInk,
      surfaceContainerLowest: card,
      surfaceContainerLow: bg,
      surfaceContainer: isDark ? const Color(0xFF1C1C22) : const Color(0xFFF2F3F6),
      surfaceContainerHigh: isDark ? const Color(0xFF222229) : const Color(0xFFEDEEF2),
      surfaceContainerHighest: isDark ? const Color(0xFF26262E) : const Color(0xFFEDEEF2),
      outline: isDark ? const Color(0xFF6E717B) : inkTertiary,
      outlineVariant: line,
      shadow: Colors.black,
      inverseSurface: isDark ? const Color(0xFFF4F4F6) : AppTheme.ink,
      onInverseSurface: isDark ? AppTheme.ink : Colors.white,
    );
    final radius = BorderRadius.circular(16);
    final textTheme = _textTheme(ink, secondaryInk);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: line)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: isDark ? const Color(0xFF6E717B) : inkTertiary, fontWeight: FontWeight.w500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: ink, width: 1.4)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: line,
          minimumSize: const Size(64, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          backgroundColor: card,
          minimumSize: const Size(64, 52),
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ink,
          textStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: ink,
        showCheckmark: false,
        side: BorderSide(color: line),
        labelStyle: TextStyle(fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : card),
          foregroundColor:
              WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? scheme.onPrimary : ink),
          side: WidgetStateProperty.all(BorderSide(color: line)),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : line),
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: radius),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
        iconColor: secondaryInk,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: line,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFFF4F4F6) : AppTheme.ink,
        contentTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.ink : Colors.white,
        ),
        elevation: 6,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ink, linearTrackColor: line),
      dividerTheme: DividerThemeData(color: line, space: 1),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? ink : Colors.transparent),
        side: BorderSide(color: isDark ? const Color(0xFF6E717B) : inkTertiary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }

  static TextTheme _textTheme(Color ink, Color secondary) {
    TextStyle s(double size, FontWeight w, {double spacing = 0, double? height, Color? color}) => TextStyle(
          fontFamily: 'Manrope',
          fontSize: size,
          fontWeight: w,
          letterSpacing: spacing,
          height: height,
          color: color ?? ink,
        );
    return TextTheme(
      displayLarge: s(64, FontWeight.w500, spacing: -3, height: 1),
      displayMedium: s(52, FontWeight.w500, spacing: -2.4, height: 1),
      displaySmall: s(40, FontWeight.w500, spacing: -1.6, height: 1.05),
      headlineLarge: s(32, FontWeight.w700, spacing: -1),
      headlineMedium: s(28, FontWeight.w700, spacing: -0.8),
      headlineSmall: s(22, FontWeight.w700, spacing: -0.5),
      titleLarge: s(18, FontWeight.w700, spacing: -0.3),
      titleMedium: s(15.5, FontWeight.w700, spacing: -0.2),
      titleSmall: s(14, FontWeight.w700),
      bodyLarge: s(16, FontWeight.w500, height: 1.45),
      bodyMedium: s(14, FontWeight.w500, height: 1.4),
      bodySmall: s(12.5, FontWeight.w500, height: 1.35, color: secondary),
      labelLarge: s(14, FontWeight.w700),
      labelMedium: s(12, FontWeight.w700),
      labelSmall: s(11, FontWeight.w700, spacing: 0.4, color: secondary),
    );
  }
}
