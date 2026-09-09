import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic status colors shared across stat cards, chips and tiles.
class AppPalette {
  AppPalette._();
  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFE65100);
  static const danger = Color(0xFFD32F2F);
  static const info = Color(0xFF1565C0);
  static const violet = Color(0xFF6A1B9A);
}

/// The property-brand gradient used by hero surfaces and key accents.
class AppBrand {
  AppBrand._();
  /// Fox-body gradient — bright orange ear tip → deep red-orange tail.
  static const List<Color> gradient = [
    Color(0xFFFF7A2E),
    Color(0xFFE85D1C),
  ];

  /// Navy accent pulled from the logo's building silhouette.
  static const navy = Color(0xFF2D4A7A);

  /// Dark charcoal — the splash background and card header bars.
  static const charcoal = Color(0xFF1E1E2E);

  /// Bottom clearance so scroll content clears the BottomMenuBar.
  static const bottomPad = 100.0;

  /// Teal green — status badges (Occupied, Ready) and accent chips.
  static const teal = Color(0xFF26A69A);

  /// Teal header gradient — hero block and the wide rent-payments card,
  /// matching the UnitFox mockup's deep-teal header.
  static const List<Color> tealGradient = [
    Color(0xFF2AB7A4),
    Color(0xFF1D8A7A),
  ];

  static Widget gradientFab({
    required VoidCallback onPressed,
    required Widget child,
    String? tooltip,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: FloatingActionButton(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        onPressed: onPressed,
        tooltip: tooltip,
        child: child,
      ),
    );
  }

  static PreferredSizeWidget barGradient = PreferredSize(
    preferredSize: const Size.fromHeight(2),
    child: Container(
      height: 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: gradient),
      ),
    ),
  );
}

/// A polished Material 3 design system. Shared by light and dark so the two
/// feel like the same app in different lighting — consistent type, rounded
/// layered surfaces, tonal controls, and a confident primary.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFFF26522); // fox orange-red
  static const _radius = 18.0;
  static const _radiusLg = 24.0;
  static const _radiusSm = 12.0;

  /// Warm off-white canvas from the UnitFox mockup — light mode only.
  static const _warmCanvas = Color(0xFFFAF6F1);

  static ThemeData light() => _build(Brightness.light, _scheme(Brightness.light));
  static ThemeData dark() => _build(Brightness.dark, _scheme(Brightness.dark));

  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
    );
    // Navy blue from the logo's building silhouette — overrides the
    // seed-derived secondary so accent chips and badges feel like the brand.
    return base.copyWith(secondary: AppBrand.navy);
  }

  static ThemeData _build(Brightness brightness, ColorScheme scheme) {
    final base = ThemeData(useMaterial3: true, brightness: brightness);

    final baseText = GoogleFonts.poppinsTextTheme(base.textTheme);

    final textTheme = baseText.copyWith(
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: baseText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: baseText.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseText.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: baseText.bodyMedium?.copyWith(height: 1.4),
      bodySmall: baseText.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? _warmCanvas : scheme.surface,
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),

      appBarTheme: AppBarTheme(
        backgroundColor:
            brightness == Brightness.light ? _warmCanvas : scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        toolbarHeight: 60,
        titleSpacing: 4,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(_radiusLg)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppBrand.charcoal,
        elevation: 0,
        height: 72,
        indicatorColor: AppBrand.gradient[0],
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => states.contains(WidgetState.selected)
              ? const IconThemeData(size: 26, color: Colors.white)
              : IconThemeData(
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TextStyle(
                  color: AppBrand.gradient[0],
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )
              : TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radiusSm),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return scheme.surfaceContainerHighest
                  .withValues(alpha: 0.8);
            }
            return null;
          }),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          )),
          iconSize: const WidgetStatePropertyAll(22),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radiusSm),
        ),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall,
      ),

      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: scheme.surfaceContainerHighest,
        deleteIconColor: scheme.onSurfaceVariant,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.onPrimary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primaryContainer;
          }
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.primaryContainer,
        elevation: 4,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 6,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: TextStyle(color: scheme.onInverseSurface, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 350),
      ),

      dividerColor: scheme.outlineVariant.withValues(alpha: 0.6),
      progressIndicatorTheme: const ProgressIndicatorThemeData(),
    );
  }
}