import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_context.dart';
import '../theme/tokens/spacing_tokens.dart';
import '../widgets/app_segmented.dart';
import '../theme/tokens/semantic_tokens.dart';
import '../widgets/inline_banner.dart';
import '../widgets/support/context_ext.dart';
import 'sections_chrome.dart';
import 'sections_complaint.dart';
import 'sections_controls.dart';
import 'sections_status.dart';
import 'tokens_section.dart';

/// The CampusFix widget gallery (design contract section 10.4, S3.2): every
/// component of section 8 in all its variants and states, with realistic
/// campus-maintenance content and a light / dark toggle.
///
/// It is the visual-QA surface for the design system and the in-app
/// counterpart of `docs/design/design-system.html`. All complaint content is
/// built from `PublicComplaintView`; no reporter identity appears anywhere.
///
/// The gallery themes itself (it wraps its content in `AppTheme.light()` or
/// `AppTheme.dark()` according to the toggle), so it works under any host
/// `MaterialApp`.
class WidgetGalleryScreen extends StatefulWidget {
  /// Creates the gallery. It opens in [initialBrightness], or in the
  /// brightness of the ambient theme when that is null.
  const WidgetGalleryScreen({super.key, this.initialBrightness});

  /// Theme the gallery opens in; null follows the ambient `Theme`.
  final Brightness? initialBrightness;

  @override
  State<WidgetGalleryScreen> createState() => _WidgetGalleryScreenState();
}

class _WidgetGalleryScreenState extends State<WidgetGalleryScreen> {
  static final ThemeData _light = AppTheme.light();
  static final ThemeData _dark = AppTheme.dark();

  Brightness? _brightness;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = _brightness ??=
        widget.initialBrightness ?? Theme.of(context).brightness;
    return Theme(
      data: brightness == Brightness.dark ? _dark : _light,
      child: Builder(
        builder: (BuildContext context) => _GalleryBody(
          brightness: brightness,
          onBrightness: (Brightness b) => setState(() => _brightness = b),
        ),
      ),
    );
  }
}

class _GalleryBody extends StatelessWidget {
  const _GalleryBody({required this.brightness, required this.onBrightness});

  final Brightness brightness;
  final ValueChanged<Brightness> onBrightness;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final double gutter = context.spacing.screenPadding;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: gutter,
            vertical: AppSpace.s6,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Header(brightness: brightness, onBrightness: onBrightness),
                  const SizedBox(height: AppSpace.s6),
                  const _PrivacyCallout(),
                  const SizedBox(height: AppSpace.s10),
                  const TokensSection(),
                  const ButtonsSection(),
                  const FieldsSection(),
                  const SelectionSection(),
                  const IndicatorsSection(),
                  const ComplaintCardSection(),
                  const ComplaintTableSection(),
                  const PhotosSection(),
                  const TimelineSection(),
                  const MetricsSection(),
                  const NavigationSection(),
                  const FeedbackSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.brightness, required this.onBrightness});

  final Brightness brightness;
  final ValueChanged<Brightness> onBrightness;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: AppSpace.s4,
      spacing: AppSpace.s4,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                'CampusFix widget gallery',
                style: context.textTheme.headlineLarge,
              ),
            ),
            const SizedBox(height: AppSpace.s1),
            Text(
              'Every component of design contract section 8, in every '
              'variant and state.',
              style: context.textTheme.bodyMedium!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        AppSegmented<Brightness>(
          semanticLabel: 'Theme',
          segments: const <AppSegment<Brightness>>[
            AppSegment<Brightness>(
              value: Brightness.light,
              label: 'Light',
              icon: Icons.light_mode_outlined,
            ),
            AppSegment<Brightness>(
              value: Brightness.dark,
              label: 'Dark',
              icon: Icons.dark_mode_outlined,
            ),
          ],
          selected: brightness,
          onChanged: onBrightness,
        ),
      ],
    );
  }
}

/// The privacy callout at the top of the gallery.
class _PrivacyCallout extends StatelessWidget {
  const _PrivacyCallout();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InlineBanner(
          kind: FeedbackKind.info,
          title: 'Privacy: this package is PII-free',
          message:
              'Every complaint widget here is built from PublicComplaintView '
              'and the public timeline only. None has a parameter, slot or '
              'style for a reporter name, ID number, email or phone, and the '
              'admin-only identity reveal panel is not part of this package. '
              'Photos are drawn placeholders, not real images.',
        ),
        SizedBox(height: AppSpace.s3),
        PrivacyNote.identity(),
      ],
    );
  }
}
