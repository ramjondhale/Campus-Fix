import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';

/// The standard body of a console page (design contract 4.2): scrolls
/// vertically, is centred with a maximum width of [AppLayout.contentMaxWidth]
/// and has the admin content padding of [AppLayout.screenPaddingAdmin].
///
/// Screens (dashboard, list, detail) put their content in an [AdminPage] so
/// every page gets the same gutters and the scrollbar sits at the window edge.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.child});

  /// The page content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppLayout.contentMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppLayout.screenPaddingAdmin),
            child: child,
          ),
        ),
      ),
    );
  }
}
