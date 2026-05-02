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
          primary: AppColors.violet,
          secondary: AppColors.cyan,
          surface: AppColors.surfaceGlass,
          error: AppColors.red,
          onPrimary: AppColors.textBright,
          onSecondary: AppColors.bgRoot,
          onSurface: AppColors.textBright,
          onError: AppColors.textBright,
        ),
        scaffoldBackgroundColor: AppColors.bgRoot,
        cardColor: AppColors.surfaceGlass,
        dividerColor: AppColors.borderSubtle,
        textTheme: const TextTheme(
          displayLarge: AppTypography.displayV2,
          displayMedium: AppTypography.displayV2,
          headlineLarge: AppTypography.h1,
          headlineMedium: AppTypography.h2,
          headlineSmall: AppTypography.h2,
          bodyLarge: AppTypography.body,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.bodySmall,
          labelLarge: AppTypography.eyebrow,
          labelSmall: AppTypography.captionV2,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceGlass,
          foregroundColor: AppColors.textBright,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTypography.h2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.violet,
            foregroundColor: AppColors.textBright,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSizes.radiusMd),
              ),
            ),
            textStyle: AppTypography.eyebrow,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s4,
              vertical: AppSizes.s3,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textMutedV2,
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSizes.radiusMd),
              ),
            ),
            textStyle: AppTypography.eyebrow,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.s4,
              vertical: AppSizes.s3,
            ),
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.surfaceGlass,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(AppSizes.radiusLg),
            ),
          ),
          margin: EdgeInsets.zero,
        ),
        iconTheme: const IconThemeData(color: AppColors.textMutedV2),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.violet,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.surfaceGlass,
          contentTextStyle: AppTypography.body,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: AppColors.sidebarGlass,
          selectedIconTheme: IconThemeData(color: AppColors.violet),
          unselectedIconTheme: IconThemeData(color: AppColors.textMutedV2),
          selectedLabelTextStyle: TextStyle(
            color: AppColors.violet,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: TextStyle(
            color: AppColors.textMutedV2,
            fontSize: 12,
          ),
          indicatorColor: AppColors.pillBgPurple,
          elevation: 0,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderSubtle,
          thickness: 1,
          space: 0,
        ),
      );
}
