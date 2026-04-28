import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_sizes.dart';
import 'package:fluxora_core/constants/app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.background,
          onSurface: AppColors.textPrimary,
          onError: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.background,
        cardColor: AppColors.surface,
        dividerColor: AppColors.surfaceRaised,
        textTheme: const TextTheme(
          displayLarge: AppTypography.displayLg,
          displayMedium: AppTypography.displayMd,
          headlineLarge: AppTypography.headingLg,
          headlineMedium: AppTypography.headingMd,
          headlineSmall: AppTypography.headingSm,
          bodyLarge: AppTypography.bodyLg,
          bodyMedium: AppTypography.bodyMd,
          bodySmall: AppTypography.bodySm,
          labelLarge: AppTypography.label,
          labelSmall: AppTypography.caption,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTypography.headingMd,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSizes.radiusMd),
              ),
            ),
            textStyle: AppTypography.label,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s4,
              vertical: AppSizes.s3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.surfaceRaised),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSizes.radiusMd),
              ),
            ),
            textStyle: AppTypography.label,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s4,
              vertical: AppSizes.s3,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppSizes.radiusLg),
            ),
          ),
          margin: EdgeInsets.zero,
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.surfaceRaised,
          contentTextStyle: AppTypography.bodyMd,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: AppColors.surface,
          selectedIconTheme: IconThemeData(color: AppColors.primary),
          unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
          selectedLabelTextStyle: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
          indicatorColor: Color(0x1A6366F1),
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.surfaceRaised,
          thickness: 1,
          space: 0,
        ),
      );
}
