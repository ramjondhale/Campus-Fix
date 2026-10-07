import 'package:flutter/material.dart';

import '../shared/coming_soon_screen.dart';

/// Stub for the Report-a-problem flow (M-03..M-08, built in S4.2): every step
/// route (`/report/category`, `/location`, `/photos`, `/details`, `/review`
/// and `/done/:id`) shows this "Coming soon" screen with its own title.
class ReportStubScreen extends StatelessWidget {
  const ReportStubScreen({super.key, this.title = 'Report a problem'});

  final String title;

  @override
  Widget build(BuildContext context) =>
      ComingSoonScreen(title: title, icon: Icons.add_a_photo_outlined);
}
