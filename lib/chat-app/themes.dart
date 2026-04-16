import 'dart:io';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum ThemeStyle {
  common, // Flutter默认
  flex, // Flex Style
}

abstract final class SillyChatThemeBuilder {

  static final _visualDensity = VisualDensity(horizontal: -2, vertical: -2);

  static buildLight(FlexScheme scheme, String? font) {
    return FlexThemeData.light(
        // Using FlexColorScheme built-in FlexScheme enum based colors
        scheme: scheme,
        // Surface color adjustments.
        surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
        blendLevel: 2,

        //textTheme: _getTextTheme(font),

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
          popupMenuRadius: 12.0,
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
        fontFamily: font ?? 'LexendDeca',
        fontFamilyFallback: ['Noto Sans SC']);
  }

  static buildNight(FlexScheme scheme, String? font) {
    return FlexThemeData.dark(
        // Using FlexColorScheme built-in FlexScheme enum based colors.
        scheme: scheme,
        // Surface color adjustments.
        surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
        blendLevel: 8,
        //textTheme: _getTextTheme(font),
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

          popupMenuRadius: 12.0,
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
        fontFamily: font ?? ('LexendDeca'),
        fontFamilyFallback: ['Noto Sans SC']);
  }

    static buildStandardLight(Color seedColor, String? font) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // 使用 seedColor 可以快速生成符合 M3 标准的一套配色
      colorSchemeSeed: seedColor,
      
      // 保持字体配置一致
      fontFamily: font ?? 'LexendDeca',
      fontFamilyFallback: const ['MiSans','Noto Sans SC'],
      
      // 保持基础布局配置一致
      visualDensity: _visualDensity,
      cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
      
      // 注意：这里不配置 subThemesData，将使用 Material 3 官方默认样式
    );
  }

  /// 默认暗色主题 (原生 Flutter)
  static buildStandardNight(Color seedColor, String? font) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: seedColor,
      
      // 保持字体配置一致
      fontFamily: font ?? 'LexendDeca',
      fontFamilyFallback: const ['MiSans','Noto Sans SC'],
      
      // 保持基础布局配置一致
      visualDensity: _visualDensity,
      cupertinoOverrideTheme: const CupertinoThemeData(applyThemeToAll: true),
    );
  }

  // The FlexColorScheme defined dark mode ThemeData.
}
