import 'dart:io';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum ThemeStyle {
  common, // Flutter默认
  flex, // Flex Style
}

abstract final class SillyChatThemeBuilder {
  static PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(builders: {
    // TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    // TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    // TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
  });

  static _getTextTheme(String? font) =>
      Typography.material2021().englishLike.apply(
            fontFamily: font ?? (Platform.isWindows ? "思源黑体" : null),
            fontFamilyFallback: ['思源黑体', '微软雅黑'],
            fontSizeFactor: 0.95, // 所有字体缩小为原来的 90%
            fontSizeDelta: 0.0, // 在缩放基础上增加/减少固定像素值
          );

  static final _visualDensity = VisualDensity(horizontal: -2, vertical: -2);

  static buildLight(FlexScheme scheme, String? font) {
    return FlexThemeData.light(
        // Using FlexColorScheme built-in FlexScheme enum based colors
        scheme: scheme,
        // Surface color adjustments.
        surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
        blendLevel: 2,
        // textTheme: _getTextTheme(font),

        // Component theme configurations for light mode.
        subThemesData: const FlexSubThemesData(
          cardElevation: 0,
          interactionEffects: true,
          tintedDisabledControls: true,
          blendOnLevel: 10,
          useM2StyleDividerInM3: true,
          outlinedButtonOutlineSchemeColor: SchemeColor.primary,
          outlinedButtonPressedBorderWidth: 2.0,
          toggleButtonsBorderSchemeColor: SchemeColor.primary,
          segmentedButtonSchemeColor: SchemeColor.primary,
          segmentedButtonBorderSchemeColor: SchemeColor.primary,
          unselectedToggleIsColored: true,
          sliderValueTinted: true,
          inputDecoratorSchemeColor: SchemeColor.primary,
          inputDecoratorIsFilled: true,
          inputDecoratorBackgroundAlpha: 21,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 12.0,
          inputDecoratorUnfocusedHasBorder: false,
          inputDecoratorPrefixIconSchemeColor: SchemeColor.primary,
          popupMenuRadius: 6.0,
          popupMenuElevation: 8.0,
          alignedDropdown: true,
          drawerIndicatorSchemeColor: SchemeColor.primary,
          bottomNavigationBarMutedUnselectedLabel: false,
          bottomNavigationBarMutedUnselectedIcon: false,
          menuRadius: 6.0,
          menuElevation: 8.0,
          menuBarRadius: 0.0,
          menuBarElevation: 1.0,
          navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
          navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
          navigationBarIndicatorSchemeColor: SchemeColor.primary,
          navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
          navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
          navigationRailUseIndicator: true,
          navigationRailIndicatorSchemeColor: SchemeColor.primary,
          navigationRailIndicatorOpacity: 1.00,
        ),
        // Direct ThemeData properties.
        visualDensity: _visualDensity,
        cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
        fontFamily: font ?? (Platform.isWindows ? "思源黑体" : null),
        fontFamilyFallback: ['MiSans', '思源黑体', '微软雅黑']);
  }

  static buildNight(FlexScheme scheme, String? font) {
    return FlexThemeData.dark(
        // Using FlexColorScheme built-in FlexScheme enum based colors.
        scheme: scheme,
        // Surface color adjustments.
        surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
        blendLevel: 8,
        // textTheme: _getTextTheme(font),
        // Component theme configurations for dark mode.
        subThemesData: const FlexSubThemesData(
          cardElevation: 0,
          interactionEffects: true,
          tintedDisabledControls: true,
          blendOnLevel: 8,
          blendOnColors: true,
          useM2StyleDividerInM3: true,
          outlinedButtonOutlineSchemeColor: SchemeColor.primary,
          outlinedButtonPressedBorderWidth: 2.0,
          toggleButtonsBorderSchemeColor: SchemeColor.primary,
          segmentedButtonSchemeColor: SchemeColor.primary,
          segmentedButtonBorderSchemeColor: SchemeColor.primary,
          unselectedToggleIsColored: true,
          sliderValueTinted: true,
          inputDecoratorSchemeColor: SchemeColor.primary,
          inputDecoratorIsFilled: true,
          inputDecoratorBackgroundAlpha: 43,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          inputDecoratorRadius: 12.0,
          inputDecoratorUnfocusedHasBorder: false,
          popupMenuRadius: 6.0,
          popupMenuElevation: 8.0,
          alignedDropdown: true,
          drawerIndicatorSchemeColor: SchemeColor.primary,
          // bottomNavigationBarMutedUnselectedLabel: false,
          // bottomNavigationBarMutedUnselectedIcon: false,

          menuRadius: 6.0,
          menuElevation: 8.0,
          menuBarRadius: 0.0,
          menuBarElevation: 1.0,
          navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
          navigationBarSelectedIconSchemeColor: SchemeColor.onPrimary,
          navigationBarIndicatorSchemeColor: SchemeColor.primary,
          navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
          navigationRailSelectedIconSchemeColor: SchemeColor.onPrimary,
          navigationRailUseIndicator: true,
          navigationRailIndicatorSchemeColor: SchemeColor.primary,
          navigationRailIndicatorOpacity: 1.00,
        ),
        // Direct ThemeData properties.
        visualDensity: _visualDensity,
        cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
        fontFamily: font ?? (Platform.isWindows ? "思源黑体" : null),
        fontFamilyFallback: ['思源黑体', '微软雅黑']);
  }

  // The FlexColorScheme defined dark mode ThemeData.
}
