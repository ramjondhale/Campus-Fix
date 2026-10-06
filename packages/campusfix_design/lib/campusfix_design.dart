/// CampusFix AI design system: theme, tokens, and reusable Flutter widgets.
///
/// The theme API (`AppTheme`, token classes, `ThemeExtension`s and
/// `BuildContext` helpers), the reusable widget library (design contract
/// section 8) and the `WidgetGalleryScreen` are exported here.
///
/// The package is PII-free: widgets that show a complaint take
/// `PublicComplaintView` only. The admin-only identity reveal panel is not
/// part of this package.
library;

// Theme
export 'theme/app_theme.dart';
export 'theme/app_typography.dart';
export 'theme/theme_context.dart';

// Theme extensions
export 'theme/extensions/campus_colors.dart';
export 'theme/extensions/category_palette.dart';
export 'theme/extensions/priority_palette.dart';
export 'theme/extensions/status_palette.dart';

// Tokens
export 'theme/tokens/color_tokens.dart';
export 'theme/tokens/elevation_tokens.dart';
export 'theme/tokens/icon_tokens.dart';
export 'theme/tokens/motion_tokens.dart';
export 'theme/tokens/radius_tokens.dart';
export 'theme/tokens/semantic_tokens.dart';
export 'theme/tokens/spacing_tokens.dart';
export 'theme/tokens/type_tokens.dart';

// Widgets: buttons, fields and controls
export 'widgets/app_button.dart';
export 'widgets/app_filter_chip.dart';
export 'widgets/app_search_field.dart';
export 'widgets/app_segmented.dart';
export 'widgets/app_select.dart';
export 'widgets/app_switch.dart';
export 'widgets/app_text_field.dart';
export 'widgets/select_tile.dart';

// Widgets: complaint building blocks
export 'widgets/app_tag_size.dart';
export 'widgets/before_after.dart';
export 'widgets/category_chip.dart';
export 'widgets/complaint_card.dart';
export 'widgets/complaint_id_text.dart';
export 'widgets/complaint_photo.dart';
export 'widgets/complaint_table.dart';
export 'widgets/photo_uploader.dart';
export 'widgets/priority_tag.dart';
export 'widgets/status_badge.dart';
export 'widgets/timeline.dart';

// Widgets: dashboard, navigation and feedback
export 'widgets/app_bottom_sheet.dart';
export 'widgets/app_dialog.dart';
export 'widgets/app_nav.dart';
export 'widgets/app_toast.dart';
export 'widgets/app_top_bar.dart';
export 'widgets/empty_state.dart';
export 'widgets/inline_banner.dart';
export 'widgets/metric_card.dart';
export 'widgets/skeleton.dart';
export 'widgets/user_avatar.dart';

// Widget support used by consuming apps (focus ring, state layers)
export 'widgets/support/app_pressable.dart';
export 'widgets/support/time_format.dart';

// Gallery
export 'gallery/widget_gallery_screen.dart';
