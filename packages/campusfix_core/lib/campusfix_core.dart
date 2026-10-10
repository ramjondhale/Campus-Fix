/// CampusFix AI shared domain: enums, models, business logic, repository
/// interfaces and the in-memory mock layer with seed data. Pure Dart - no
/// Flutter or Firebase dependency.
library;

// Enums
export 'enums/attachment_kind.dart';
export 'enums/complaint_status.dart';
export 'enums/department.dart';
export 'enums/notification_type.dart';
export 'enums/people_affected.dart';
export 'enums/priority.dart';
export 'enums/problem_category.dart';
export 'enums/severity.dart';
export 'enums/user_role.dart';

// Models
export 'models/app_notification.dart';
export 'models/app_user.dart';
export 'models/assignment.dart';
export 'models/attachment.dart';
export 'models/complaint.dart';
export 'models/complaint_views.dart';
export 'models/reporter_identity.dart';
export 'models/status_event.dart';

// Domain logic (pure)
export 'logic/assignment_router.dart';
export 'logic/priority_engine.dart';
export 'logic/privacy.dart';
export 'logic/status_machine.dart';

// Repository interfaces
export 'repositories/auth_repository.dart';
export 'repositories/complaint_repository.dart';
export 'repositories/notification_repository.dart';
export 'repositories/reporter_identity_revealer.dart';
export 'repositories/user_repository.dart';

// Services: the L3 transition executor and in-app notifications.
export 'services/complaint_service.dart';
export 'services/notification_service.dart';

// Mock layer: Complaint ID generation, campus directory, in-memory
// repositories and seed data (prototype only; Phase 2 swaps in Firebase).
export 'mock/campus_directory.dart';
export 'mock/id_generator.dart';
export 'mock/mock_account.dart';
export 'mock/mock_auth_repository.dart';
export 'mock/mock_complaint_repository.dart';
export 'mock/mock_notification_repository.dart';
export 'mock/mock_user_repository.dart';
export 'mock/seed_data.dart';
