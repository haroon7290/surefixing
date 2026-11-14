import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// SureFix design tokens and Material theme.
///
/// Identity: ink + safety orange on warm paper. Headings and numbers use
/// Bricolage Grotesque; everything else Plus Jakarta Sans.

const kDisplayFont = 'Bricolage';
const kBodyFont = 'Jakarta';

/// Corner radii.
abstract final class R {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

/// Fixed spacers: `Gap.h12`, `Gap.w8`.
abstract final class Gap {
  static const h2 = SizedBox(height: 2);
  static const h4 = SizedBox(height: 4);
  static const h6 = SizedBox(height: 6);
  static const h8 = SizedBox(height: 8);
  static const h12 = SizedBox(height: 12);
  static const h16 = SizedBox(height: 16);
  static const h20 = SizedBox(height: 20);
  static const h24 = SizedBox(height: 24);
  static const h32 = SizedBox(height: 32);
  static const h48 = SizedBox(height: 48);
  static const w4 = SizedBox(width: 4);
  static const w6 = SizedBox(width: 6);
  static const w8 = SizedBox(width: 8);
  static const w12 = SizedBox(width: 12);
  static const w16 = SizedBox(width: 16);
  static const w24 = SizedBox(width: 24);
}

/// Semantic colour families used by pills, notices and stat tiles.
enum Tone { neutral, brand, success, warning, danger, info }

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color canvas; // page background
  final Color surface; // cards, sheets, inputs
  final Color sunken; // wells, skeletons, quiet buttons
  final Color line; // hairline borders
  final Color ink; // primary text
  final Color body; // secondary text
  final Color muted; // captions, placeholders
  final Color brand;
  final Color onBrand;
  final Color brandSoft;
  final Color brandDeep; // brand-coloured text on light surfaces
  final Color hero; // dark feature cards
  final Color onHero;
  final Color onHeroMuted;
  final Color heroLine;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  const AppColors({
    required this.canvas,
    required this.surface,
    required this.sunken,
    required this.line,
    required this.ink,
    required this.body,
    required this.muted,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.brandDeep,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroLine,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
  });

  static const light = AppColors(
    canvas: Color(0xFFF6F3EE),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFEEEAE2),
    line: Color(0xFFE4DFD6),
    ink: Color(0xFF14161B),
    body: Color(0xFF4A4E59),
    muted: Color(0xFF82868F),
    brand: Color(0xFFFF5A1F),
    onBrand: Color(0xFF14161B),
    brandSoft: Color(0xFFFFE7DB),
    brandDeep: Color(0xFFB8380B),
    hero: Color(0xFF14161B),
    onHero: Color(0xFFF6F3EE),
    onHeroMuted: Color(0xFFA3A6B0),
    heroLine: Color(0xFF2B2E37),
    success: Color(0xFF0C8559),
    successSoft: Color(0xFFDCF2E8),
    warning: Color(0xFFA86200),
    warningSoft: Color(0xFFFBEDCD),
    danger: Color(0xFFCC363B),
    dangerSoft: Color(0xFFFBE2E1),
    info: Color(0xFF2456D6),
    infoSoft: Color(0xFFE0E8FC),
  );

  static const dark = AppColors(
    canvas: Color(0xFF0D0E11),
    surface: Color(0xFF16181D),
    sunken: Color(0xFF1E2127),
    line: Color(0xFF282B33),
    ink: Color(0xFFF4F1EC),
    body: Color(0xFFB6B9C2),
    muted: Color(0xFF7D818C),
    brand: Color(0xFFFF6A33),
    onBrand: Color(0xFF14161B),
    brandSoft: Color(0xFF3B1D10),
    brandDeep: Color(0xFFFF9A70),
    hero: Color(0xFF1B1E24),
    onHero: Color(0xFFF4F1EC),
    onHeroMuted: Color(0xFF9EA1AB),
    heroLine: Color(0xFF30343D),
    success: Color(0xFF3FD4A0),
    successSoft: Color(0xFF0F2E24),
    warning: Color(0xFFF2B84B),
    warningSoft: Color(0xFF33270D),
    danger: Color(0xFFFF7B7B),
    dangerSoft: Color(0xFF3B1719),
    info: Color(0xFF8AABFF),
    infoSoft: Color(0xFF15224A),
  );

  /// Foreground (text/icon) colour of a tone.
  Color fg(Tone t) => switch (t) {
        Tone.neutral => body,
        Tone.brand => brandDeep,
        Tone.success => success,
        Tone.warning => warning,
        Tone.danger => danger,
        Tone.info => info,
      };

  /// Soft background colour of a tone.
  Color bg(Tone t) => switch (t) {
        Tone.neutral => sunken,
        Tone.brand => brandSoft,
        Tone.success => successSoft,
        Tone.warning => warningSoft,
        Tone.danger => dangerSoft,
        Tone.info => infoSoft,
      };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      sunken: l(sunken, other.sunken),
      line: l(line, other.line),
      ink: l(ink, other.ink),
      body: l(body, other.body),
      muted: l(muted, other.muted),
      brand: l(brand, other.brand),
      onBrand: l(onBrand, other.onBrand),
      brandSoft: l(brandSoft, other.brandSoft),
      brandDeep: l(brandDeep, other.brandDeep),
      hero: l(hero, other.hero),
      onHero: l(onHero, other.onHero),
      onHeroMuted: l(onHeroMuted, other.onHeroMuted),
      heroLine: l(heroLine, other.heroLine),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
    );
  }
}

extension ThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static TextTheme _text(AppColors c) {
    TextStyle display(double size, FontWeight w, {double height = 1.1, double spacing = -0.5}) =>
        TextStyle(fontFamily: kDisplayFont, fontSize: size, fontWeight: w, height: height, letterSpacing: spacing, color: c.ink);
    TextStyle body(double size, FontWeight w, {double height = 1.45, Color? color, double spacing = 0}) =>
        TextStyle(fontFamily: kBodyFont, fontSize: size, fontWeight: w, height: height, letterSpacing: spacing, color: color ?? c.ink);
    return TextTheme(
      displayLarge: display(60, FontWeight.w800, height: 1.0, spacing: -2),
      displayMedium: display(44, FontWeight.w800, height: 1.04, spacing: -1.4),
      displaySmall: display(34, FontWeight.w800, height: 1.08, spacing: -1),
      headlineLarge: display(30, FontWeight.w700, spacing: -0.8),
      headlineMedium: display(26, FontWeight.w700, spacing: -0.6),
      headlineSmall: display(22, FontWeight.w700, height: 1.15, spacing: -0.4),
      titleLarge: display(19, FontWeight.w700, height: 1.2, spacing: -0.3),
      titleMedium: body(16, FontWeight.w700, height: 1.3, spacing: -0.1),
      titleSmall: body(14, FontWeight.w700, height: 1.3),
      bodyLarge: body(16, FontWeight.w500, height: 1.5, color: c.body),
      bodyMedium: body(14, FontWeight.w500, color: c.body),
      bodySmall: body(12.5, FontWeight.w500, height: 1.4, color: c.muted),
      labelLarge: body(14.5, FontWeight.w700, height: 1.2),
      labelMedium: body(12.5, FontWeight.w600, height: 1.2, color: c.body),
      labelSmall: body(11, FontWeight.w700, height: 1.2, color: c.muted, spacing: 0.8),
    );
  }

  static ThemeData _build(AppColors c, Brightness brightness) {
    final text = _text(c);
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.brand,
      onPrimary: c.onBrand,
      primaryContainer: c.brandSoft,
      onPrimaryContainer: c.brandDeep,
      secondary: c.ink,
      onSecondary: c.canvas,
      secondaryContainer: c.sunken,
      onSecondaryContainer: c.ink,
      tertiary: c.info,
      onTertiary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      errorContainer: c.dangerSoft,
      onErrorContainer: c.danger,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.body,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.sunken,
      surfaceContainerHighest: c.sunken,
      outline: c.line,
      outlineVariant: c.line,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: c.hero,
      onInverseSurface: c.onHero,
      inversePrimary: c.brand,
      surfaceTint: Colors.transparent,
    );

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(R.md), borderSide: BorderSide(color: color, width: width));
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: kBodyFont,
      textTheme: text,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      dividerColor: c.line,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: c.ink.withValues(alpha: 0.04),
      splashColor: c.ink.withValues(alpha: 0.06),
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: text.headlineSmall,
        systemOverlayStyle: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.lg), side: BorderSide(color: c.line)),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: text.bodyMedium!.copyWith(color: c.muted, fontSize: 15),
        labelStyle: text.bodyMedium,
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall!.copyWith(color: c.danger),
        errorMaxLines: 3,
        helperMaxLines: 3,
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        border: border(c.line),
        enabledBorder: border(c.line),
        disabledBorder: border(c.line),
        focusedBorder: border(c.ink, 1.5),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: c.onBrand,
          disabledBackgroundColor: c.sunken,
          disabledForegroundColor: c.muted,
          textStyle: text.labelLarge,
          padding: buttonPadding,
          minimumSize: const Size(0, 48),
          shape: buttonShape,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          textStyle: text.labelLarge,
          padding: buttonPadding,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: c.line, width: 1.2),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.ink,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.sm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: c.ink)),
      iconTheme: IconThemeData(color: c.ink, size: 22),
      chipTheme: ChipThemeData(
        backgroundColor: c.surface,
        selectedColor: c.ink,
        side: BorderSide(color: c.line),
        labelStyle: text.labelMedium!.copyWith(color: c.ink),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(R.xl))),
        constraints: const BoxConstraints(maxWidth: 640),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.light.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: AppColors.light.canvas, fontWeight: FontWeight.w600),
        actionTextColor: AppColors.dark.brand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        width: null,
        elevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        textStyle: text.titleSmall!.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md), side: BorderSide(color: c.line)),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          elevation: const WidgetStatePropertyAll(8),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.md), side: BorderSide(color: c.line))),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : c.muted.withValues(alpha: 0.45)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: c.muted, width: 1.5),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : c.muted)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand, linearTrackColor: c.sunken, circularTrackColor: Colors.transparent),
      tabBarTheme: TabBarThemeData(
        labelColor: c.ink,
        unselectedLabelColor: c.muted,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall!.copyWith(fontWeight: FontWeight.w600),
        indicatorColor: c.brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: c.line,
        tabAlignment: TabAlignment.start,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.light.ink, borderRadius: BorderRadius.circular(8)),
        textStyle: text.bodySmall!.copyWith(color: AppColors.light.canvas, fontWeight: FontWeight.w600),
        waitDuration: const Duration(milliseconds: 400),
      ),
      listTileTheme: ListTileThemeData(iconColor: c.ink, titleTextStyle: text.titleSmall, subtitleTextStyle: text.bodySmall),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surface,
        headerBackgroundColor: c.hero,
        headerForegroundColor: c.onHero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.xl)),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.muted.withValues(alpha: 0.45)),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: c.brand, selectionColor: c.brand.withValues(alpha: 0.25), selectionHandleColor: c.brand),
    );
  }
}
