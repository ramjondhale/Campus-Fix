import 'dart:ui' show Brightness, Color;

import 'package:flutter/foundation.dart' show immutable;

/// One semantic colour set (contract 2.1): the three values every category,
/// priority, status and feedback key carries in each theme.
///
/// * [fg] text and icon colour; 4.5:1 or better only on its own [bg].
/// * [bg] container fill (badge, tag, chip, banner).
/// * [accent] non-text mark (ring, signal bar, dot, node, chart fill); 3:1 or
///   better against `card` and its own [bg]. Never use it for text.
@immutable
final class SemanticStyle {
  /// Creates a style from its three colours.
  const SemanticStyle({
    required this.fg,
    required this.bg,
    required this.accent,
  });

  /// Text and icon colour (on [bg]).
  final Color fg;

  /// Container fill.
  final Color bg;

  /// Non-text mark colour. Never for text.
  final Color accent;

  /// True for the two deliberate solid sets (`Priority.critical`,
  /// `ComplaintStatus.closed`), where [accent] equals [bg].
  bool get isSolid => accent == bg;

  /// Colour for rings, checks and signal bars drawn inside the container:
  /// [accent] in tonal sets, [fg] in solid sets (contract 2.6, 2.7).
  Color get markColor => isSolid ? fg : accent;

  /// Copy with the given colours replaced.
  SemanticStyle copyWith({Color? fg, Color? bg, Color? accent}) =>
      SemanticStyle(
        fg: fg ?? this.fg,
        bg: bg ?? this.bg,
        accent: accent ?? this.accent,
      );

  /// Linear interpolation between two styles.
  static SemanticStyle lerp(SemanticStyle a, SemanticStyle b, double t) =>
      SemanticStyle(
        fg: Color.lerp(a.fg, b.fg, t)!,
        bg: Color.lerp(a.bg, b.bg, t)!,
        accent: Color.lerp(a.accent, b.accent, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is SemanticStyle &&
      other.fg == fg &&
      other.bg == bg &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(fg, bg, accent);

  @override
  String toString() => 'SemanticStyle(fg: $fg, bg: $bg, accent: $accent)';
}

/// Style resolved for a `ProblemCategory`.
typedef CategoryStyle = SemanticStyle;

/// Style resolved for a `Priority`.
typedef PriorityStyle = SemanticStyle;

/// Style resolved for a `ComplaintStatus`.
typedef StatusStyle = SemanticStyle;

/// Style resolved for a [FeedbackKind].
typedef FeedbackStyle = SemanticStyle;

/// The four feedback sets (contract 2.4) used by banners, toasts and form
/// validation. [name] is the key in Appendix A.
enum FeedbackKind {
  /// Operation succeeded.
  success('Success'),

  /// Needs attention but not blocking.
  warning('Warning'),

  /// Failed or invalid.
  error('Error'),

  /// Neutral information.
  info('Info');

  const FeedbackKind(this.label);

  /// Human-readable name for UI.
  final String label;
}

/// Semantic colour sets keyed by Dart enum `.name` (contract 2.4 to 2.7).
///
/// Keys are exactly `ProblemCategory.name`, `Priority.name`,
/// `ComplaintStatus.name` and [FeedbackKind.name]; there is no second naming
/// scheme. The typed lookups live on the theme extensions.
abstract final class SemanticTokens {
  static const Map<String, SemanticStyle> _feedbackLight =
      <String, SemanticStyle>{
        'success': SemanticStyle(
          fg: Color(0xFF005121),
          bg: Color(0xFFDDF6E1),
          accent: Color(0xFF158F44),
        ),
        'warning': SemanticStyle(
          fg: Color(0xFF583D00),
          bg: Color(0xFFFDECD2),
          accent: Color(0xFF9B6E00),
        ),
        'error': SemanticStyle(
          fg: Color(0xFF810109),
          bg: Color(0xFFFEE9E6),
          accent: Color(0xFFD03833),
        ),
        'info': SemanticStyle(
          fg: Color(0xFF024671),
          bg: Color(0xFFE1F1FF),
          accent: Color(0xFF057DC5),
        ),
      };

  static const Map<String, SemanticStyle> _feedbackDark =
      <String, SemanticStyle>{
        'success': SemanticStyle(
          fg: Color(0xFFB1E7BB),
          bg: Color(0xFF0F371B),
          accent: Color(0xFF58B670),
        ),
        'warning': SemanticStyle(
          fg: Color(0xFFF4D299),
          bg: Color(0xFF3E2A01),
          accent: Color(0xFFCA9423),
        ),
        'error': SemanticStyle(
          fg: Color(0xFFFEC9C1),
          bg: Color(0xFF511815),
          accent: Color(0xFFF66D62),
        ),
        'info': SemanticStyle(
          fg: Color(0xFFB6DDFF),
          bg: Color(0xFF08304D),
          accent: Color(0xFF4BA6EC),
        ),
      };

  static const Map<String, SemanticStyle> _categoryLight =
      <String, SemanticStyle>{
        'electrical': SemanticStyle(
          fg: Color(0xFF4A4401),
          bg: Color(0xFFF2F0D6),
          accent: Color(0xFF847A01),
        ),
        'plumbing': SemanticStyle(
          fg: Color(0xFF044B5A),
          bg: Color(0xFFDAF4FB),
          accent: Color(0xFF02859F),
        ),
        'civil': SemanticStyle(
          fg: Color(0xFF543D2B),
          bg: Color(0xFFF5EDE7),
          accent: Color(0xFF8C715D),
        ),
        'furniture': SemanticStyle(
          fg: Color(0xFF2C4D01),
          bg: Color(0xFFE7F3DF),
          accent: Color(0xFF5F853C),
        ),
        'cleanliness': SemanticStyle(
          fg: Color(0xFF004F38),
          bg: Color(0xFFDCF6E9),
          accent: Color(0xFF098D66),
        ),
        'it': SemanticStyle(
          fg: Color(0xFF32348C),
          bg: Color(0xFFEAEEFE),
          accent: Color(0xFF616CCE),
        ),
        'safety': SemanticStyle(
          fg: Color(0xFF7A014B),
          bg: Color(0xFFFEE8F0),
          accent: Color(0xFFC13D82),
        ),
        'other': SemanticStyle(
          fg: Color(0xFF39444C),
          bg: Color(0xFFEBEFF2),
          accent: Color(0xFF6D7982),
        ),
      };

  static const Map<String, SemanticStyle> _categoryDark =
      <String, SemanticStyle>{
        'electrical': SemanticStyle(
          fg: Color(0xFFDFDAA4),
          bg: Color(0xFF332F05),
          accent: Color(0xFFABA242),
        ),
        'plumbing': SemanticStyle(
          fg: Color(0xFFABE2F2),
          bg: Color(0xFF07343E),
          accent: Color(0xFF4AADC7),
        ),
        'civil': SemanticStyle(
          fg: Color(0xFFE5D4C8),
          bg: Color(0xFF362B24),
          accent: Color(0xFFB29986),
        ),
        'furniture': SemanticStyle(
          fg: Color(0xFFC9E0B7),
          bg: Color(0xFF243318),
          accent: Color(0xFF87AC6A),
        ),
        'cleanliness': SemanticStyle(
          fg: Color(0xFFAFE6CD),
          bg: Color(0xFF0C3627),
          accent: Color(0xFF54B48E),
        ),
        'it': SemanticStyle(
          fg: Color(0xFFCCD5FF),
          bg: Color(0xFF252A4F),
          accent: Color(0xFF8896F1),
        ),
        'safety': SemanticStyle(
          fg: Color(0xFFFFC4DC),
          bg: Color(0xFF4B1932),
          accent: Color(0xFFE86FA9),
        ),
        'other': SemanticStyle(
          fg: Color(0xFFD1D9DE),
          bg: Color(0xFF2A2E32),
          accent: Color(0xFF95A0A9),
        ),
      };

  static const Map<String, SemanticStyle> _priorityLight =
      <String, SemanticStyle>{
        'critical': SemanticStyle(
          fg: Color(0xFFFFFFFF),
          bg: Color(0xFFB7191C),
          accent: Color(0xFFB7191C),
        ),
        'high': SemanticStyle(
          fg: Color(0xFF663301),
          bg: Color(0xFFFFEADC),
          accent: Color(0xFFB35D04),
        ),
        'medium': SemanticStyle(
          fg: Color(0xFF583D02),
          bg: Color(0xFFFDECD1),
          accent: Color(0xFF9B6E04),
        ),
        'low': SemanticStyle(
          fg: Color(0xFF2E4654),
          bg: Color(0xFFE8F0F5),
          accent: Color(0xFF617C8C),
        ),
      };

  static const Map<String, SemanticStyle> _priorityDark =
      <String, SemanticStyle>{
        'critical': SemanticStyle(
          fg: Color(0xFF3D0A08),
          bg: Color(0xFFFDA297),
          accent: Color(0xFFFDA297),
        ),
        'high': SemanticStyle(
          fg: Color(0xFFFECCA9),
          bg: Color(0xFF482201),
          accent: Color(0xFFE18438),
        ),
        'medium': SemanticStyle(
          fg: Color(0xFFF5D297),
          bg: Color(0xFF3E2A00),
          accent: Color(0xFFCB9318),
        ),
        'low': SemanticStyle(
          fg: Color(0xFFCADAE4),
          bg: Color(0xFF252F36),
          accent: Color(0xFF89A3B2),
        ),
      };

  static const Map<String, SemanticStyle> _statusLight =
      <String, SemanticStyle>{
        'reported': SemanticStyle(
          fg: Color(0xFF3B434C),
          bg: Color(0xFFECEFF2),
          accent: Color(0xFF6F7983),
        ),
        'reviewed': SemanticStyle(
          fg: Color(0xFF23388D),
          bg: Color(0xFFE8EEFF),
          accent: Color(0xFF5270CF),
        ),
        'assigned': SemanticStyle(
          fg: Color(0xFF53297A),
          bg: Color(0xFFF3EAFE),
          accent: Color(0xFF8B5FB9),
        ),
        'inProgress': SemanticStyle(
          fg: Color(0xFF024964),
          bg: Color(0xFFDCF3FF),
          accent: Color(0xFF0182B0),
        ),
        'resolved': SemanticStyle(
          fg: Color(0xFF004E45),
          bg: Color(0xFFD9F6F0),
          accent: Color(0xFF018B7C),
        ),
        'verified': SemanticStyle(
          fg: Color(0xFF02511D),
          bg: Color(0xFFDEF6E0),
          accent: Color(0xFF228E40),
        ),
        'closed': SemanticStyle(
          fg: Color(0xFFFFFFFF),
          bg: Color(0xFF373E45),
          accent: Color(0xFF373E45),
        ),
      };

  static const Map<String, SemanticStyle> _statusDark = <String, SemanticStyle>{
    'reported': SemanticStyle(
      fg: Color(0xFFD2D8DF),
      bg: Color(0xFF2A2E32),
      accent: Color(0xFF96A0A9),
    ),
    'reviewed': SemanticStyle(
      fg: Color(0xFFC7D7FE),
      bg: Color(0xFF1F2C50),
      accent: Color(0xFF7A9AF2),
    ),
    'assigned': SemanticStyle(
      fg: Color(0xFFE2CCFF),
      bg: Color(0xFF352547),
      accent: Color(0xFFB189DD),
    ),
    'inProgress': SemanticStyle(
      fg: Color(0xFFA9E0FE),
      bg: Color(0xFF023246),
      accent: Color(0xFF23ACE3),
    ),
    'resolved': SemanticStyle(
      fg: Color(0xFFA7E6DB),
      bg: Color(0xFF033630),
      accent: Color(0xFF3CB4A3),
    ),
    'verified': SemanticStyle(
      fg: Color(0xFFB3E7B9),
      bg: Color(0xFF113719),
      accent: Color(0xFF5DB56D),
    ),
    'closed': SemanticStyle(
      fg: Color(0xFF13161A),
      bg: Color(0xFFCCD2D7),
      accent: Color(0xFFCCD2D7),
    ),
  };

  /// Feedback sets (contract) for [brightness], keyed by enum `.name`.
  static Map<String, SemanticStyle> feedback(Brightness brightness) =>
      brightness == Brightness.dark ? _feedbackDark : _feedbackLight;

  /// Category sets (contract) for [brightness], keyed by enum `.name`.
  static Map<String, SemanticStyle> category(Brightness brightness) =>
      brightness == Brightness.dark ? _categoryDark : _categoryLight;

  /// Priority sets (contract) for [brightness], keyed by enum `.name`.
  static Map<String, SemanticStyle> priority(Brightness brightness) =>
      brightness == Brightness.dark ? _priorityDark : _priorityLight;

  /// Status sets (contract) for [brightness], keyed by enum `.name`.
  static Map<String, SemanticStyle> status(Brightness brightness) =>
      brightness == Brightness.dark ? _statusDark : _statusLight;
}
