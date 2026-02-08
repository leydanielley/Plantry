import 'package:flutter/material.dart';

class AppConstants {
  // Colors
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF388E3C);
  static const Color lightGreen = Color(0xFF81C784);
  static const Color darkModePrimary = Color(0xFF2C2C2C);
  static const Color lightModePrimary = Colors.white;
  static const Color darkModeSecondary = Color(0xFF3C3C3C);
  static const Color lightModeSecondary = Color(0xFFF5F5F5);

  // ✅ PHASE 2 FIX: Comprehensive spacing constants (for SizedBox)
  static const double spacingXs = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingNormal = 12.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 20.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // Common SizedBox Widgets (for convenience)
  static const SizedBox gapXs = SizedBox(height: spacingXs, width: spacingXs);
  static const SizedBox gapSmall = SizedBox(
    height: spacingSmall,
    width: spacingSmall,
  );
  static const SizedBox gapNormal = SizedBox(
    height: spacingNormal,
    width: spacingNormal,
  );
  static const SizedBox gapMedium = SizedBox(
    height: spacingMedium,
    width: spacingMedium,
  );
  static const SizedBox gapLarge = SizedBox(
    height: spacingLarge,
    width: spacingLarge,
  );
  static const SizedBox gapXl = SizedBox(height: spacingXl, width: spacingXl);
  static const SizedBox gapXxl = SizedBox(
    height: spacingXxl,
    width: spacingXxl,
  );

  // Vertical Gaps (height only)
  static const SizedBox gapVerticalXs = SizedBox(height: spacingXs);
  static const SizedBox gapVerticalSmall = SizedBox(height: spacingSmall);
  static const SizedBox gapVerticalNormal = SizedBox(height: spacingNormal);
  static const SizedBox gapVerticalMedium = SizedBox(height: spacingMedium);
  static const SizedBox gapVerticalLarge = SizedBox(height: spacingLarge);
  static const SizedBox gapVerticalXl = SizedBox(height: spacingXl);
  static const SizedBox gapVerticalXxl = SizedBox(height: spacingXxl);

  // Horizontal Gaps (width only)
  static const SizedBox gapHorizontalXs = SizedBox(width: spacingXs);
  static const SizedBox gapHorizontalSmall = SizedBox(width: spacingSmall);
  static const SizedBox gapHorizontalNormal = SizedBox(width: spacingNormal);
  static const SizedBox gapHorizontalMedium = SizedBox(width: spacingMedium);
  static const SizedBox gapHorizontalLarge = SizedBox(width: spacingLarge);
  static const SizedBox gapHorizontalXl = SizedBox(width: spacingXl);
  static const SizedBox gapHorizontalXxl = SizedBox(width: spacingXxl);

  // Font Sizes
  static const double fontSizeSmall = 12.0;
  static const double fontSizeBody = 14.0;
  static const double fontSizeMedium = 16.0;
  static const double fontSizeLarge = 20.0;
  static const double fontSizeXLarge = 24.0;

  // Icon Sizes
  static const double iconSizeSmall = 20.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;

  // ✅ PHASE 2 FIX: Comprehensive padding constants to eliminate magic numbers
  // Base Padding Values (EdgeInsets.all)
  static const EdgeInsets paddingXs = EdgeInsets.all(4.0);
  static const EdgeInsets paddingSmall = EdgeInsets.all(8.0);
  static const EdgeInsets paddingNormal = EdgeInsets.all(12.0);
  static const EdgeInsets paddingMedium = EdgeInsets.all(16.0);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20.0);
  static const EdgeInsets paddingXl = EdgeInsets.all(24.0);
  static const EdgeInsets paddingXxl = EdgeInsets.all(32.0);

  // Horizontal Padding (EdgeInsets.symmetric)
  static const EdgeInsets paddingHorizontalXs = EdgeInsets.symmetric(
    horizontal: 4.0,
  );
  static const EdgeInsets paddingHorizontalSmall = EdgeInsets.symmetric(
    horizontal: 8.0,
  );
  static const EdgeInsets paddingHorizontalNormal = EdgeInsets.symmetric(
    horizontal: 12.0,
  );
  static const EdgeInsets paddingHorizontalMedium = EdgeInsets.symmetric(
    horizontal: 16.0,
  );
  static const EdgeInsets paddingHorizontalLarge = EdgeInsets.symmetric(
    horizontal: 20.0,
  );
  static const EdgeInsets paddingHorizontalXl = EdgeInsets.symmetric(
    horizontal: 24.0,
  );

  // Vertical Padding (EdgeInsets.symmetric)
  static const EdgeInsets paddingVerticalXs = EdgeInsets.symmetric(
    vertical: 4.0,
  );
  static const EdgeInsets paddingVerticalSmall = EdgeInsets.symmetric(
    vertical: 8.0,
  );
  static const EdgeInsets paddingVerticalNormal = EdgeInsets.symmetric(
    vertical: 12.0,
  );
  static const EdgeInsets paddingVerticalMedium = EdgeInsets.symmetric(
    vertical: 16.0,
  );
  static const EdgeInsets paddingVerticalLarge = EdgeInsets.symmetric(
    vertical: 20.0,
  );
  static const EdgeInsets paddingVerticalXl = EdgeInsets.symmetric(
    vertical: 24.0,
  );

  // Common Chip/Badge Padding
  static const EdgeInsets paddingChip = EdgeInsets.symmetric(
    horizontal: 8.0,
    vertical: 4.0,
  );
  static const EdgeInsets paddingChipLarge = EdgeInsets.symmetric(
    horizontal: 12.0,
    vertical: 6.0,
  );

  // List Padding
  static const EdgeInsets listPadding = EdgeInsets.all(8.0);
  static const EdgeInsets screenPadding = EdgeInsets.all(16.0);

  // Card Margins
  static const EdgeInsets cardMarginVertical = EdgeInsets.only(bottom: 8.0);

  // Empty State
  static const double emptyStateSpacingTop = 24.0;
  static const double emptyStateSpacingMiddle = 16.0;
  static const double emptyStateIconSize = 64.0;
  static const double emptyStateTitleFontSize = 20.0;
  static const double emptyStateSubtitleFontSize = 16.0;

  // Room Dimensions
  static const double roomDimensionsFontSize = 12.0;

  // Popup Menu
  static const double popupMenuIconSize = 20.0;

  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const BorderRadius borderRadiusMediumAll = BorderRadius.all(
    Radius.circular(12.0),
  );

  // Badge
  static const double badgeBorderRadius = 12.0;
  static const double badgeFontSize = 11.0;
  static const double badgeFontSizeMedium = 11.0;
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(
    horizontal: 8.0,
    vertical: 4.0,
  );

  // Chip
  static const double chipPaddingHorizontal = 8.0;
  static const double chipPaddingVertical = 4.0;

  // FAB
  static const double fabBottomPaddingSmall = 80.0;
  static const double fabBottomPaddingLarge = 16.0;

  // Grow Header
  static const double growHeaderPaddingHorizontal = 16.0;
  static const double growHeaderPaddingVertical = 12.0;
  static const double growHeaderBorderRadius = 12.0;
  static const double growHeaderEmojiSize = 24.0;
  static const double growHeaderSpacing = 12.0;

  // Plant Card
  static const double plantCardArrowPadding = 8.0;
  static const double plantCardArrowSize = 20.0;
  static const double plantCardBorderRadius = 12.0;
  static const double plantCardPadding = 12.0;
  static const double plantCardEmojiBgPadding = 12.0;
  static const double plantCardEmojiBgRadius = 12.0;
  static const double plantCardEmojiSize = 32.0;

  // List Items
  static const double listItemIconSize = 20.0;
  static const double listItemIconSpacing = 8.0;
  static const double listItemSpacingMedium = 12.0;

  // Stats
  static const EdgeInsets statsCardMargin = EdgeInsets.only(bottom: 16.0);
  static const EdgeInsets statsCardPadding = EdgeInsets.all(16.0);
  static const double statsIconSize = 32.0;
  static const double statsValueFontSize = 24.0;
  static const double statsLabelFontSize = 14.0;
}
