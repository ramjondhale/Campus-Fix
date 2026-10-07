import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

import '../../shell/admin_page.dart';

/// Placeholder body of a console screen that a later chunk builds: the design
/// system's `EmptyState` saying "Coming soon", inside the standard
/// [AdminPage] so it sits in the shell like the real screen will.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    this.icon = Icons.construction_outlined,
  });

  /// The screen's name, used in the message ("Dashboard arrives in a later
  /// release.").
  final String title;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AdminPage(
      child: EmptyState(
        icon: icon,
        title: 'Coming soon',
        message: '$title arrives in a later release.',
        alignment: CrossAxisAlignment.start,
      ),
    );
  }
}
