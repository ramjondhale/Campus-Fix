/// CampusFix AI shared domain: enums, models, Complaint ID generation and
/// repository interfaces. Pure Dart - no Flutter or Firebase dependency.
library;

// Enums
export 'enums/attachment_kind.dart';
export 'enums/complaint_status.dart';
export 'enums/department.dart';
export 'enums/people_affected.dart';
export 'enums/priority.dart';
export 'enums/problem_category.dart';
export 'enums/severity.dart';
export 'enums/user_role.dart';

// Models
export 'models/app_user.dart';
export 'models/assignment.dart';
export 'models/attachment.dart';
export 'models/complaint.dart';
export 'models/reporter_identity.dart';
export 'models/status_event.dart';

// Complaint ID generation
export 'mock/id_generator.dart';

// Repository interfaces
export 'repositories/auth_repository.dart';
export 'repositories/complaint_repository.dart';
