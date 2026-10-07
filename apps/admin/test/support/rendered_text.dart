import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// Every string the current frame renders or announces inside [within] (the
/// whole tree by default): all `Text` content, their semantics labels and every
/// `Semantics` label (including what is scrolled off screen). Used by the
/// privacy sweeps.
String allRenderedText(WidgetTester tester, {Finder? within}) {
  Finder inScope(Finder f) =>
      within == null ? f : find.descendant(of: within, matching: f);
  final StringBuffer out = StringBuffer();
  for (final Text t in tester.widgetList<Text>(
    inScope(find.byType(Text, skipOffstage: false)),
  )) {
    out.writeln(t.data ?? t.textSpan?.toPlainText() ?? '');
    if (t.semanticsLabel != null) out.writeln(t.semanticsLabel);
  }
  for (final Semantics s in tester.widgetList<Semantics>(
    inScope(find.byType(Semantics, skipOffstage: false)),
  )) {
    final String? label = s.properties.label;
    if (label != null) out.writeln(label);
  }
  return out.toString();
}

/// Identity strings of the deterministic seed that the dashboard may never
/// show: every user's name, ID number, e-mail and id (reporters, maintenance
/// staff, verifiers and the admin) and every reporter's name, ID number,
/// e-mail, phone and user id (privacy-spec section 2).
Set<String> identitySentinels() {
  final Set<String> out = <String>{};
  for (final AppUser u in testSeed.users) {
    out.addAll(<String>[u.displayName, u.idNumber, u.email, u.id]);
  }
  for (final Complaint c in testSeed.complaints) {
    final ReporterIdentity r = c.reporter;
    out.addAll(<String>[r.fullName, r.idNumber, r.email, r.userId]);
    final String? phone = r.phone;
    if (phone != null) out.add(phone);
  }
  out.removeWhere((String s) => s.isEmpty);
  return out;
}

/// The sentinels that appear in [text] (case-insensitive); empty when clean.
List<String> identityLeaks(String text) {
  final String hay = text.toLowerCase();
  return <String>[
    for (final String s in identitySentinels())
      if (hay.contains(s.toLowerCase())) s,
  ];
}
