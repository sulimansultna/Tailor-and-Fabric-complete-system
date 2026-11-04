import 'package:flutter/material.dart';

const _lightBackground = Color(0xfff5f7fa);
const _lightSurface = Color(0xffffffff);
const _lightText = Color(0xff102a43);
const _lightSecondaryText = Color(0xff52667a);
const _lightTeal = Color(0xff087f8c);
const _darkBackground = Color(0xff0f172a);
const _darkSurface = Color(0xff1e293b);
const _darkText = Color(0xfff1f5f9);
const _darkSecondaryText = Color(0xffcbd5e1);
const _darkTeal = Color(0xff5eead4);

ThemeData buildAppTheme({bool reduceMotion = false}) =>
    _buildTheme(Brightness.light, reduceMotion: reduceMotion);

ThemeData buildDarkAppTheme({bool reduceMotion = false}) =>
    _buildTheme(Brightness.dark, reduceMotion: reduceMotion);

ThemeData _buildTheme(Brightness brightness, {required bool reduceMotion}) {
  final isDark = brightness == Brightness.dark;
  final background = isDark ? _darkBackground : _lightBackground;
  final surface = isDark ? _darkSurface : _lightSurface;
  final text = isDark ? _darkText : _lightText;
  final secondaryText = isDark ? _darkSecondaryText : _lightSecondaryText;
  final primary = isDark ? _darkTeal : _lightTeal;
  final onPrimary = isDark ? const Color(0xff042f2e) : Colors.white;
  final outline = isDark ? const Color(0xff475569) : const Color(0xffcbd5e1);
  final outlineVariant = isDark
      ? const Color(0xff334155)
      : const Color(0xffe2e8f0);
  final error = isDark ? const Color(0xfffca5a5) : const Color(0xffb42318);
  final colorScheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: primary,
        onPrimary: onPrimary,
        secondary: isDark ? const Color(0xff99f6e4) : const Color(0xff0f766e),
        onSecondary: isDark ? const Color(0xff042f2e) : Colors.white,
        tertiary: isDark ? const Color(0xfffbbf24) : const Color(0xffa76608),
        onTertiary: isDark ? const Color(0xff422006) : Colors.white,
        tertiaryContainer: isDark
            ? const Color(0xff78350f)
            : const Color(0xfffef3c7),
        onTertiaryContainer: isDark
            ? const Color(0xfffef3c7)
            : const Color(0xff78350f),
        surface: surface,
        onSurface: text,
        onSurfaceVariant: secondaryText,
        surfaceContainerLowest: isDark ? const Color(0xff111c30) : Colors.white,
        surfaceContainerLow: isDark
            ? const Color(0xff172338)
            : const Color(0xfff8fafc),
        surfaceContainer: isDark
            ? const Color(0xff1e293b)
            : const Color(0xfff1f5f9),
        surfaceContainerHigh: isDark
            ? const Color(0xff263449)
            : const Color(0xffeaf0f5),
        surfaceContainerHighest: isDark
            ? const Color(0xff334155)
            : const Color(0xffe2e8f0),
        outline: outline,
        outlineVariant: outlineVariant,
        error: error,
        onError: isDark ? const Color(0xff450a0a) : Colors.white,
        errorContainer: isDark
            ? const Color(0xff7f1d1d)
            : const Color(0xfffee4e2),
        onErrorContainer: isDark
            ? const Color(0xfffee2e2)
            : const Color(0xff7a271a),
        shadow: Colors.black,
        scrim: Colors.black,
      );
  final baseTextTheme = ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    useMaterial3: true,
  ).textTheme;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: outline),
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: primary, width: 2),
  );
  final hoverColor = primary.withValues(alpha: isDark ? .10 : .06);
  final selectedColor = primary.withValues(alpha: isDark ? .16 : .10);

  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: 'NotoSansArabic',
    scaffoldBackgroundColor: background,
    canvasColor: surface,
    cardColor: surface,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    splashColor: primary.withValues(alpha: .10),
    hoverColor: hoverColor,
    focusColor: primary.withValues(alpha: .12),
    disabledColor: secondaryText.withValues(alpha: .45),
    dividerColor: outlineVariant,
    textTheme: baseTextTheme.apply(bodyColor: text, displayColor: text),
    primaryTextTheme: baseTextTheme.apply(
      bodyColor: onPrimary,
      displayColor: onPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerLow,
      labelStyle: TextStyle(color: secondaryText),
      hintStyle: TextStyle(color: secondaryText.withValues(alpha: .82)),
      enabledBorder: border,
      border: border,
      focusedBorder: focusedBorder,
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: error, width: 1.4),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(onPrimary),
        backgroundColor: WidgetStatePropertyAll(primary),
        overlayColor: WidgetStatePropertyAll(
          (isDark ? Colors.white : Colors.black).withValues(alpha: .08),
        ),
        animationDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(primary),
        side: WidgetStatePropertyAll(BorderSide(color: outline)),
        overlayColor: WidgetStatePropertyAll(hoverColor),
        animationDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(primary),
        overlayColor: WidgetStatePropertyAll(hoverColor),
        animationDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 180),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(secondaryText),
        overlayColor: WidgetStatePropertyAll(hoverColor),
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: isDark
          ? const Color(0xff111c30)
          : const Color(0xff142238),
      selectedIconTheme: const IconThemeData(color: Color(0xff5eead4)),
      unselectedIconTheme: const IconThemeData(color: Color(0xffb4c0d0)),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelTextStyle: const TextStyle(color: Color(0xffd0d8e2)),
      indicatorColor: isDark
          ? const Color(0xff174447)
          : const Color(0xff29445a),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: selectedColor,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(colorScheme.surfaceContainerLow),
      headingTextStyle: baseTextTheme.labelLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      dataTextStyle: baseTextTheme.bodyMedium?.copyWith(color: text),
      dividerThickness: 1,
      horizontalMargin: 16,
      columnSpacing: 20,
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return selectedColor;
        if (states.contains(WidgetState.hovered)) return hoverColor;
        return null;
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: primary,
      headerForegroundColor: onPrimary,
      todayForegroundColor: WidgetStatePropertyAll(primary),
      todayBorder: BorderSide(color: primary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: WidgetStatePropertyAll(BorderSide(color: outlineVariant)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        enabledBorder: border,
        border: border,
        focusedBorder: focusedBorder,
      ),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12),
      waitDuration: const Duration(milliseconds: 450),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      actionTextColor: isDark ? _darkTeal : const Color(0xff9ee7df),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.dragged)) return primary;
        if (states.contains(WidgetState.hovered)) {
          return primary.withValues(alpha: .8);
        }
        return outline.withValues(alpha: .7);
      }),
      trackColor: WidgetStatePropertyAll(colorScheme.surfaceContainerLow),
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(8),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? onPrimary : secondaryText,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? primary : outlineVariant,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : null,
      ),
      checkColor: WidgetStatePropertyAll(onPrimary),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? primary : secondaryText,
      ),
    ),
    dividerTheme: DividerThemeData(color: outlineVariant, thickness: 1),
    listTileTheme: ListTileThemeData(
      iconColor: secondaryText,
      textColor: text,
      selectedColor: primary,
      selectedTileColor: selectedColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
