import '../enums/department.dart';
import '../enums/problem_category.dart';

/// Department a complaint of [category] is auto-routed to (R8), or `null`
/// when the category needs **manual triage** (only `safety` and `other`).
///
/// Pure and total: it never throws and has no I/O. The mapping lives solely in
/// [ProblemCategory.defaultDepartment] (data-model-spec §1.1); this function
/// deliberately carries no second table so the two can never drift.
///
/// Spec: assignment-routing-spec §1, §2. Signature: data-model-spec §5.
Department? routeToDepartment(ProblemCategory category) =>
    category.defaultDepartment;

/// Whether assigning a complaint of [category] to [chosen] is a **manual**
/// assignment (the `isManual` flag, MA-2).
///
/// `isManual` is derived, never typed: it is `true` exactly when [chosen]
/// differs from [routeToDepartment]. Picking the router's own department is
/// equivalent to auto-routing (`false`); picking any other department - or any
/// department at all for `safety`/`other`, whose route is `null` - is `true`.
///
/// Spec: assignment-routing-spec §4 (MA-2), §6 (RA-8).
bool isManualAssignment(ProblemCategory category, Department chosen) =>
    routeToDepartment(category) != chosen;
