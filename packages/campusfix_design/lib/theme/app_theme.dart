import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'extensions/campus_colors.dart';
import 'extensions/category_palette.dart';
import 'extensions/priority_palette.dart';
import 'extensions/status_palette.dart';
import 'tokens/color_tokens.dart';
import 'tokens/elevation_tokens.dart';
import 'tokens/motion_tokens.dart';
import 'tokens/radius_tokens.dart';
import 'tokens/spacing_tokens.dart';

/// Builds the CampusFix [ThemeData] (contract 10.3).
///
/// `AppTheme.light()` and `AppTheme.dark()` wire the section 2 colour tokens
/// into a `ColorScheme` role by role, the section 3 [TextTheme], the theme
/// extensions ([CampusColors], [CategoryPalette], [PriorityPalette],
/// [StatusPalette]) and the component themes listed in contract 10.3.
///
/// Component themes carry the parts of the section 8 specs that Material
/// widgets can express. Parts that need custom widgets (the 2 px focus ring
/// with a 2 px offset, the 1 px scrolled-under app bar edge, exact switch
/// geometry) belong to the S3.2 widgets.
abstract final class AppTheme {
  /// Light theme (contract 2.2, 2.3 light columns).
  static ThemeData light() => _build(AppColors.light);

  /// Dark theme (contract 2.2, 2.3 dark columns).
  static ThemeData dark() => _build(AppColors.dark);

  /// Theme for [brightness].
  static ThemeData of(Brightness brightness) =>
      brightness == Brightness.dark ? dark() : light();

  static const Color _clear = Color(0x00000000);

  static ThemeData _build(AppColorTokens c) {
    final Brightness brightness = c.brightness;
    final bool dark = brightness == Brightness.dark;
    final ColorScheme scheme = c.colorScheme;
    final TextTheme text = AppTypography.textTheme(color: c.onSurface);
    final Color shadow = AppElevation.materialShadowColor(brightness);
    final Color scrim = AppColors.scrim(brightness);

    final Color disabledContent = c.onSurface.withValues(
      alpha: AppStateLayer.disabledContent,
    );
    final Color disabledContainer = c.onSurface.withValues(
      alpha: AppStateLayer.disabledContainer,
    );

    // State-layer overlay for a control whose content colour is [content].
    WidgetStateProperty<Color?> stateOverlay(Color content) =>
        WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.pressed)) {
            return content.withValues(alpha: AppStateLayer.pressed);
          }
          if (states.contains(WidgetState.focused)) {
            return content.withValues(alpha: AppStateLayer.focus);
          }
          if (states.contains(WidgetState.hovered)) {
            return content.withValues(alpha: AppStateLayer.hover);
          }
          return null;
        });

    // Focus is a visible 2 px ring in `focusRing`, never removed (7.2). A
    // themed ButtonStyle cannot offset the ring, so it is drawn as the border
    // while focused.
    BorderSide focusSide(Set<WidgetState> states, BorderSide otherwise) =>
        states.contains(WidgetState.focused)
        ? BorderSide(color: c.focusRing, width: AppStateLayer.focusRingWidth)
        : otherwise;

    final OutlineInputBorder inputBorderBase = const OutlineInputBorder(
      borderRadius: AppRadius.br4,
    );
    final WidgetStateInputBorder inputBorder =
        WidgetStateInputBorder.resolveWith((Set<WidgetState> states) {
          final BorderSide side;
          if (states.contains(WidgetState.error)) {
            side = BorderSide(color: c.error, width: 2);
          } else if (states.contains(WidgetState.disabled)) {
            side = BorderSide(color: c.outlineVariant);
          } else if (states.contains(WidgetState.focused)) {
            side = BorderSide(color: c.primary, width: 2);
          } else if (states.contains(WidgetState.hovered)) {
            side = BorderSide(color: c.onSurface);
          } else {
            side = BorderSide(color: c.outline);
          }
          return inputBorderBase.copyWith(borderSide: side);
        });

    final InputDecorationThemeData inputTheme = InputDecorationThemeData(
      filled: true,
      fillColor: c.card,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s3,
        vertical: AppSpace.s3,
      ),
      constraints: const BoxConstraints(
        minHeight: AppLayout.controlHeightMobile,
      ),
      border: inputBorder,
      hintStyle: text.bodyLarge?.copyWith(color: c.onSurfaceVariant),
      helperStyle: text.bodySmall?.copyWith(color: c.onSurfaceVariant),
      errorStyle: text.bodySmall?.copyWith(color: c.error),
      prefixIconColor: c.onSurfaceVariant,
      suffixIconColor: c.onSurfaceVariant,
    );

    const RoundedRectangleBorder r4Shape = RoundedRectangleBorder(
      borderRadius: AppRadius.br4,
    );
    final RoundedRectangleBorder cardShape = RoundedRectangleBorder(
      borderRadius: AppRadius.br4,
      side: BorderSide(color: c.outlineVariant),
    );

    // Properties shared by the three AppButton variants.
    ButtonStyle buttonBase({
      required Color foreground,
      required double horizontalPadding,
    }) => ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? disabledContent
            : foreground,
      ),
      elevation: const WidgetStatePropertyAll<double>(0),
      shadowColor: const WidgetStatePropertyAll<Color?>(_clear),
      surfaceTintColor: const WidgetStatePropertyAll<Color?>(_clear),
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(64, AppLayout.controlHeightAdmin),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: horizontalPadding),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
      iconSize: const WidgetStatePropertyAll<double>(20),
    );

    final ButtonStyle filledStyle =
        buttonBase(
          foreground: c.onPrimary,
          horizontalPadding: AppSpace.s5,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) return disabledContainer;
            if (states.contains(WidgetState.pressed)) return c.primaryPressed;
            if (states.contains(WidgetState.hovered)) return c.primaryHover;
            return c.primary;
          }),
          // The filled button changes its background instead of using an overlay.
          overlayColor: const WidgetStatePropertyAll<Color?>(_clear),
          shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
            (Set<WidgetState> states) => RoundedRectangleBorder(
              borderRadius: AppRadius.br4,
              side: focusSide(states, BorderSide.none),
            ),
          ),
        );

    final ButtonStyle outlinedStyle =
        buttonBase(
          foreground: c.primary,
          horizontalPadding: AppSpace.s5,
        ).copyWith(
          backgroundColor: const WidgetStatePropertyAll<Color?>(_clear),
          overlayColor: stateOverlay(c.primary),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(r4Shape),
          side: WidgetStateProperty.resolveWith<BorderSide?>(
            (Set<WidgetState> states) => states.contains(WidgetState.disabled)
                ? BorderSide(color: disabledContainer)
                : focusSide(states, BorderSide(color: c.outline)),
          ),
        );

    final ButtonStyle textButtonStyle =
        buttonBase(
          foreground: c.primary,
          horizontalPadding: AppSpace.s3,
        ).copyWith(
          backgroundColor: const WidgetStatePropertyAll<Color?>(_clear),
          overlayColor: stateOverlay(c.primary),
          shape: WidgetStateProperty.resolveWith<OutlinedBorder?>(
            (Set<WidgetState> states) => RoundedRectangleBorder(
              borderRadius: AppRadius.br4,
              side: focusSide(states, BorderSide.none),
            ),
          ),
        );

    final MenuStyle menuStyle = MenuStyle(
      backgroundColor: WidgetStatePropertyAll<Color?>(c.raised),
      surfaceTintColor: const WidgetStatePropertyAll<Color?>(_clear),
      shadowColor: WidgetStatePropertyAll<Color?>(shadow),
      elevation: const WidgetStatePropertyAll<double>(2),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.all(AppSpace.s1),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: AppRadius.br4,
          side: BorderSide(color: c.outlineVariant),
        ),
      ),
    );

    final ButtonStyle menuItemStyle = ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) => states.contains(WidgetState.disabled)
            ? disabledContent
            : c.onSurface,
      ),
      overlayColor: stateOverlay(c.onSurface),
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(0, AppLayout.minTouchTarget),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: AppRadius.br3),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle?>(text.bodyLarge),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      visualDensity: VisualDensity.standard,
      focusColor: c.onSurface.withValues(alpha: AppStateLayer.focus),
      hoverColor: c.onSurface.withValues(alpha: AppStateLayer.hover),
      highlightColor: c.onSurface.withValues(alpha: AppStateLayer.pressed),
      splashColor: c.onSurface.withValues(alpha: AppStateLayer.pressed),
      dividerColor: c.outlineVariant,
      iconTheme: IconThemeData(color: c.onSurface, size: 24),
      extensions: <ThemeExtension<dynamic>>[
        CampusColors.of(brightness),
        dark ? CategoryPalette.dark : CategoryPalette.light,
        dark ? PriorityPalette.dark : PriorityPalette.light,
        dark ? StatusPalette.dark : StatusPalette.light,
      ],

      // AppButton (8.1)
      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),

      // TextField, Select, SearchField (8.2 to 8.4)
      inputDecorationTheme: inputTheme,
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyLarge,
        inputDecorationTheme: inputTheme,
        menuStyle: menuStyle,
      ),
      menuTheme: MenuThemeData(style: menuStyle),
      menuButtonTheme: MenuButtonThemeData(style: menuItemStyle),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll<double>(0),
        backgroundColor: WidgetStatePropertyAll<Color?>(c.cardSubtle),
        surfaceTintColor: const WidgetStatePropertyAll<Color?>(_clear),
        overlayColor: const WidgetStatePropertyAll<Color?>(_clear),
        shape: WidgetStateProperty.resolveWith<OutlinedBorder?>((
          Set<WidgetState> states,
        ) {
          BorderSide side = BorderSide.none;
          if (states.contains(WidgetState.focused)) {
            side = BorderSide(color: c.primary, width: 2);
          } else if (states.contains(WidgetState.hovered)) {
            side = BorderSide(color: c.outline);
          }
          return RoundedRectangleBorder(
            borderRadius: AppRadius.br4,
            side: side,
          );
        }),
        constraints: const BoxConstraints(
          minHeight: AppLayout.controlHeightAdmin,
        ),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.symmetric(horizontal: AppSpace.s3),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle?>(text.bodyMedium),
        hintStyle: WidgetStatePropertyAll<TextStyle?>(
          text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        ),
      ),

      // Toggle, SegmentedControl, selection controls (8.5, 8.6)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) return disabledContent;
          return states.contains(WidgetState.selected)
              ? c.onPrimary
              : c.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          if (states.contains(WidgetState.disabled)) {
            return selected ? disabledContainer : _clear;
          }
          return selected ? c.primary : c.cardSubtle;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.selected)) return _clear;
          return states.contains(WidgetState.disabled)
              ? disabledContainer
              : c.outline;
        }),
        trackOutlineWidth: const WidgetStatePropertyAll<double>(2),
        overlayColor: stateOverlay(c.primary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) => states.contains(WidgetState.selected)
                ? c.secondaryContainer
                : _clear,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.disabled)) {
              return disabledContent;
            }
            return states.contains(WidgetState.selected)
                ? c.onSecondaryContainer
                : c.onSurface;
          }),
          overlayColor: stateOverlay(c.onSurface),
          side: WidgetStatePropertyAll<BorderSide?>(
            BorderSide(color: c.outline),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(r4Shape),
          textStyle: WidgetStatePropertyAll<TextStyle?>(text.labelLarge),
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(0, AppLayout.controlHeightAdmin),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: AppSpace.s4),
          ),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          if (states.contains(WidgetState.disabled)) return disabledContent;
          return states.contains(WidgetState.selected) ? c.primary : c.outline;
        }),
        overlayColor: stateOverlay(c.primary),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color?>((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          if (states.contains(WidgetState.disabled)) {
            return selected ? disabledContainer : null;
          }
          return selected ? c.primary : null;
        }),
        checkColor: WidgetStatePropertyAll<Color?>(c.onPrimary),
        side: WidgetStateBorderSide.resolveWith((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) return BorderSide.none;
          return BorderSide(
            color: states.contains(WidgetState.disabled)
                ? disabledContent
                : c.outline,
            width: 2,
          );
        }),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br1),
        overlayColor: stateOverlay(c.primary),
      ),

      // FilterChip (8.16)
      chipTheme: ChipThemeData(
        color: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? c.secondaryContainer
              : _clear,
        ),
        backgroundColor: _clear,
        selectedColor: c.secondaryContainer,
        disabledColor: _clear,
        checkmarkColor: c.onSecondaryContainer,
        labelStyle: text.labelLarge?.copyWith(color: c.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(
          color: c.onSecondaryContainer,
        ),
        iconTheme: IconThemeData(color: c.onSurfaceVariant, size: 16),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br4),
        side: WidgetStateBorderSide.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected)
              ? BorderSide.none
              : BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? disabledContainer
                      : c.outline,
                ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        labelPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: _clear,
      ),

      // ComplaintCard, MetricCard (8.10, 8.15)
      cardTheme: CardThemeData(
        elevation: 0,
        color: c.card,
        shadowColor: _clear,
        surfaceTintColor: _clear,
        margin: EdgeInsets.zero,
        shape: cardShape,
        clipBehavior: Clip.antiAlias,
      ),

      // AppBar (8.18)
      appBarTheme: AppBarThemeData(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.canvas,
        foregroundColor: c.onSurface,
        surfaceTintColor: _clear,
        shadowColor: _clear,
        centerTitle: false,
        toolbarHeight: AppLayout.appBarHeightMobile,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: c.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: c.onSurface, size: 24),
      ),

      // BottomNav, SideNav (8.19)
      navigationBarTheme: NavigationBarThemeData(
        height: AppLayout.bottomNavHeight,
        elevation: 0,
        backgroundColor: c.card,
        surfaceTintColor: _clear,
        shadowColor: _clear,
        indicatorColor: c.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? c.onPrimaryContainer
                : c.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => text.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.onSurface
                : c.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.card,
        elevation: 0,
        minWidth: AppLayout.sideNavWidthRail,
        indicatorColor: c.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.br4,
        ),
        selectedIconTheme: IconThemeData(color: c.onPrimaryContainer, size: 20),
        unselectedIconTheme: IconThemeData(color: c.onSurfaceVariant, size: 20),
        selectedLabelTextStyle: text.labelLarge?.copyWith(
          color: c.onPrimaryContainer,
        ),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(
          color: c.onSurfaceVariant,
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: c.card,
        surfaceTintColor: _clear,
        shadowColor: _clear,
        elevation: 0,
        tileHeight: 44,
        indicatorColor: c.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.br4,
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (Set<WidgetState> states) => IconThemeData(
            size: 20,
            color: states.contains(WidgetState.selected)
                ? c.onPrimaryContainer
                : c.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) => text.labelLarge?.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.onPrimaryContainer
                : c.onSurfaceVariant,
          ),
        ),
      ),

      // Dialog, BottomSheet (8.20)
      dialogTheme: DialogThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: _clear,
        shadowColor: shadow,
        elevation: 3,
        barrierColor: scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br5),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpace.s6,
          0,
          AppSpace.s6,
          AppSpace.s6,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.raised,
        surfaceTintColor: _clear,
        shadowColor: shadow,
        elevation: 3,
        modalBarrierColor: scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: c.outlineVariant,
        dragHandleSize: const Size(32, 4),
      ),

      // Toast (8.21)
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInverseSurface),
        actionTextColor: c.inversePrimary,
        closeIconColor: c.onInverseSurface,
        disabledActionTextColor: c.onInverseSurface.withValues(
          alpha: AppStateLayer.disabledContent,
        ),
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br4),
      ),

      // Table (8.11)
      dataTableTheme: DataTableThemeData(
        decoration: BoxDecoration(color: c.card),
        headingRowColor: WidgetStatePropertyAll<Color?>(c.cardSubtle),
        headingRowHeight: 40,
        headingTextStyle: AppTypography.overline.copyWith(
          color: c.onSurfaceVariant,
        ),
        dataRowColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? c.pressedFill : null,
        ),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 52,
        dataTextStyle: AppTypography.tabular(
          text.bodyMedium ?? const TextStyle(),
        ),
        horizontalMargin: 10,
        columnSpacing: AppSpace.s5,
        dividerThickness: 1,
      ),

      // Dividers, progress, FAB
      dividerTheme: DividerThemeData(
        color: c.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.cardSubtle,
        circularTrackColor: _clear,
        strokeWidth: 2,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 2,
        highlightElevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.br5),
      ),
    );
  }
}
