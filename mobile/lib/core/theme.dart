import 'package:flutter/material.dart';

/// SureFix design system: brand colours, semantic palette (light + dark),
/// typography and component themes. Screens read colours through
/// `context.palette` / `context.colors` instead of hard-coding them, so
/// dark mode works everywhere.
class Brand {
  static const primary = Color(0xFF2F54EB); // "Sure" — trustworthy blue
  static const accent = Color(0xFFFF8A00); // "Fix" — tool orange
  static const navy = Color(0xFF0F1B3D);
  static const heroStart = Color(0xFF1D39C4);
  static const heroEnd = Color(0xFF2F54EB);
  static const fontFamily = 'PlusJakartaSans';
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color star;
  final Color muted; // secondary text
  final Color subtle; // tertiary text / icons
  final Color border;
  final Color fill; // inputs, chips, skeletons
  final Color card;
  final Color background;

  const AppPalette({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.star,
    required this.muted,
    required this.subtle,
    required this.border,
    required this.fill,
    required this.card,
    required this.background,
  });

  static const light = AppPalette(
    success: Color(0xFF12B76A),
    warning: Color(0xFFF79009),
    danger: Color(0xFFF04438),
    info: Color(0xFF2E90FA),
    star: Color(0xFFFDB022),
    muted: Color(0xFF475467),
    subtle: Color(0xFF98A2B3),
    border: Color(0xFFE4E7EC),
    fill: Color(0xFFF2F4F7),
    card: Color(0xFFFFFFFF),
    background: Color(0xFFF6F7FB),
  );

  static const dark = AppPalette(
    success: Color(0xFF32D583),
    warning: Color(0xFFFDB022),
    danger: Color(0xFFF97066),
    info: Color(0xFF53B1FD),
    star: Color(0xFFFEC84B),
    muted: Color(0xFFA6B0C3),
    subtle: Color(0xFF6B7690),
    border: Color(0xFF263152),
    fill: Color(0xFF1A2340),
    card: Color(0xFF131A2E),
    background: Color(0xFF0B1020),
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      info: l(info, other.info),
      star: l(star, other.star),
      muted: l(muted, other.muted),
      subtle: l(subtle, other.subtle),
      border: l(border, other.border),
      fill: l(fill, other.fill),
      card: l(card, other.card),
      background: l(background, other.background),
    );
  }
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class AppTheme {
  static const radius = 16.0;

  static ThemeData light() => _build(Brightness.light, AppPalette.light);
  static ThemeData dark() => _build(Brightness.dark, AppPalette.dark);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final isDark = brightness == Brightness.dark;
    final onSurface = isDark ? const Color(0xFFF2F4F7) : const Color(0xFF101828);
    final primary = isDark ? const Color(0xFF5B78FF) : Brand.primary;

    final scheme = ColorScheme.fromSeed(seedColor: Brand.primary, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: Brand.accent,
      onSecondary: Colors.white,
      surface: p.card,
      onSurface: onSurface,
      onSurfaceVariant: p.muted,
      outline: p.border,
      outlineVariant: p.border,
      error: p.danger,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.background,
      surfaceContainer: p.fill,
      surfaceContainerHigh: p.fill,
      surfaceContainerHighest: p.fill,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: Brand.fontFamily,
      scaffoldBackgroundColor: p.background,
      extensions: [p],
    );

    final t = base.textTheme;
    final text = t
        .copyWith(
          displaySmall: t.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          headlineLarge: t.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
          headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          bodyLarge: t.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: t.bodyMedium?.copyWith(height: 1.45),
          bodySmall: t.bodySmall?.copyWith(color: p.muted, height: 1.4),
          labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          labelSmall: t.labelSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);

    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.6,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 20),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: p.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? p.fill : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: border(p.border),
        enabledBorder: border(p.border),
        focusedBorder: border(primary, 1.6),
        errorBorder: border(p.danger),
        focusedErrorBorder: border(p.danger, 1.6),
        disabledBorder: border(p.border.withValues(alpha: 0.5)),
        hintStyle: TextStyle(color: p.subtle, fontWeight: FontWeight.w400),
        labelStyle: TextStyle(color: p.muted),
        floatingLabelStyle: TextStyle(color: primary, fontWeight: FontWeight.w600),
        prefixIconColor: p.subtle,
        suffixIconColor: p.subtle,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: rounded,
          textStyle: const TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: rounded,
          side: BorderSide(color: p.border),
          foregroundColor: onSurface,
          textStyle: const TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: rounded,
          textStyle: const TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: primary.withValues(alpha: 0.12),
        side: BorderSide(color: p.border),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w600, fontSize: 13, color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        checkmarkColor: primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: Brand.fontFamily,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? primary : p.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? primary : p.muted, size: 24),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        extendedTextStyle: const TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF26304F) : Brand.navy,
        contentTextStyle: const TextStyle(fontFamily: Brand.fontFamily, color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: p.muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: p.muted,
        indicatorColor: primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: p.border,
        labelStyle: const TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: primary.withValues(alpha: 0.12),
          selectedForegroundColor: primary,
          side: BorderSide(color: p.border),
          textStyle: const TextStyle(fontFamily: Brand.fontFamily, fontWeight: FontWeight.w600),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary, linearTrackColor: p.fill, circularTrackColor: p.fill),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.success : null),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : null),
      ),
    );
  }
}
