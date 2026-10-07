// The in-progress Report-a-Problem draft (screens-spec "Report draft").
//
// UI state only, kept in memory across the steps M-03..M-07 and cleared by a
// successful submit or a confirmed discard. It holds nothing about the
// reporter: the identity is attached by the submit controller
// (`report_submit.dart`), the only place allowed to know who is reporting.

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'complaints.dart';

/// Limits of the report form (screens-spec M-04, M-05, M-06).
abstract final class ReportLimits {
  static const int minPhotos = 1;
  static const int maxPhotos = 5;
  static const int captionMax = 80;
  static const int locationMax = 60;
  static const int descriptionMin = 10;
  static const int descriptionMax = 1000;
}

/// Floor choices for a building that is not on the campus list ("Other...").
const List<String> kOtherBuildingFloors = <String>[
  'Basement',
  'Ground',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  'Terrace',
  CampusDirectory.outdoor,
];

/// The report form's state. Strings are stored as typed; [trimmedDescription]
/// and friends give the trimmed values the validation uses (screens-spec G-7).
@immutable
class ReportDraft {
  const ReportDraft({
    this.category,
    this.building = '',
    this.otherBuilding = false,
    this.floor,
    this.room = '',
    this.photos = const <Attachment>[],
    this.description = '',
    this.severity = Severity.moderate,
    this.peopleAffected = PeopleAffected.individual,
    this.safetyFlag = false,
  });

  final ProblemCategory? category;

  /// The building: a campus building name, or free text when [otherBuilding].
  final String building;

  /// Whether the reporter chose "Other..." and typed the building.
  final bool otherBuilding;

  final String? floor;
  final String room;

  /// The before-repair photos (`AttachmentKind.beforePhoto`), 1 to 5.
  final List<Attachment> photos;
  final String description;
  final Severity severity;
  final PeopleAffected peopleAffected;
  final bool safetyFlag;

  /// The safety category forces and locks the safety flag (PE-OI-4).
  bool get safetyLocked => category == ProblemCategory.safety;

  String get trimmedBuilding => building.trim();
  String get trimmedRoom => room.trim();
  String get trimmedDescription => description.trim();

  bool get categoryValid => category != null;

  bool get locationValid =>
      trimmedBuilding.isNotEmpty &&
      trimmedBuilding.length <= ReportLimits.locationMax &&
      (floor?.trim().isNotEmpty ?? false) &&
      trimmedRoom.isNotEmpty &&
      trimmedRoom.length <= ReportLimits.locationMax;

  bool get photosValid =>
      photos.length >= ReportLimits.minPhotos &&
      photos.length <= ReportLimits.maxPhotos;

  bool get descriptionValid =>
      trimmedDescription.length >= ReportLimits.descriptionMin &&
      trimmedDescription.length <= ReportLimits.descriptionMax;

  /// Whether every step is valid, i.e. the draft may be submitted.
  bool get isComplete =>
      categoryValid && locationValid && photosValid && descriptionValid;

  /// Whether the reporter has entered anything worth a "Discard report?"
  /// prompt (screens-spec M-03 Close).
  bool get hasInput =>
      category != null ||
      trimmedBuilding.isNotEmpty ||
      floor != null ||
      trimmedRoom.isNotEmpty ||
      photos.isNotEmpty ||
      trimmedDescription.isNotEmpty ||
      severity != Severity.moderate ||
      peopleAffected != PeopleAffected.individual ||
      safetyFlag;

  ReportDraft copyWith({
    ProblemCategory? category,
    String? building,
    bool? otherBuilding,
    String? floor,
    bool clearFloor = false,
    String? room,
    List<Attachment>? photos,
    String? description,
    Severity? severity,
    PeopleAffected? peopleAffected,
    bool? safetyFlag,
  }) => ReportDraft(
    category: category ?? this.category,
    building: building ?? this.building,
    otherBuilding: otherBuilding ?? this.otherBuilding,
    floor: clearFloor ? null : (floor ?? this.floor),
    room: room ?? this.room,
    photos: photos ?? this.photos,
    description: description ?? this.description,
    severity: severity ?? this.severity,
    peopleAffected: peopleAffected ?? this.peopleAffected,
    safetyFlag: safetyFlag ?? this.safetyFlag,
  );
}

/// Owner of the [ReportDraft]: every edit of the form goes through here.
class ReportDraftNotifier extends Notifier<ReportDraft> {
  int _photoSeq = 0;

  @override
  ReportDraft build() => const ReportDraft();

  /// Chooses the category. `safety` forces the safety flag on; switching away
  /// from it clears the auto-set flag (screens-spec M-03, AC-09).
  void setCategory(ProblemCategory category) {
    final bool wasSafety = state.category == ProblemCategory.safety;
    state = state.copyWith(
      category: category,
      safetyFlag: category == ProblemCategory.safety
          ? true
          : (wasSafety ? false : state.safetyFlag),
    );
  }

  /// Picks a campus building; the floor and room belong to the building, so
  /// they are cleared when it changes.
  void setBuilding(String name) {
    if (!state.otherBuilding && state.building == name) return;
    state = ReportDraft(
      category: state.category,
      building: name,
      photos: state.photos,
      description: state.description,
      severity: state.severity,
      peopleAffected: state.peopleAffected,
      safetyFlag: state.safetyFlag,
    );
  }

  /// Chooses "Other..." (a building that is not on the campus list): the
  /// reporter then types the name ([setOtherBuildingName]) and picks any floor.
  void selectOtherBuilding() {
    if (state.otherBuilding) return;
    state = ReportDraft(
      category: state.category,
      otherBuilding: true,
      photos: state.photos,
      description: state.description,
      severity: state.severity,
      peopleAffected: state.peopleAffected,
      safetyFlag: state.safetyFlag,
    );
  }

  /// Sets the typed building name of an "Other..." building.
  void setOtherBuildingName(String name) =>
      state = state.copyWith(building: name, otherBuilding: true);

  void setFloor(String floor) {
    if (state.floor == floor) return;
    state = state.copyWith(floor: floor, room: '');
  }

  void setRoom(String room) => state = state.copyWith(room: room);

  /// Adds a before photo (the prototype picks a bundled sample, A4). Ignored
  /// at the maximum (screens-spec M-05, AC-13). Returns whether it was added.
  bool addPhoto({DateTime? now}) {
    if (state.photos.length >= ReportLimits.maxPhotos) return false;
    final int n = ++_photoSeq;
    final Attachment photo = Attachment(
      id: 'draft-photo-$n',
      kind: AttachmentKind.beforePhoto,
      ref: 'assets/samples/report_sample_${(n - 1) % 6 + 1}.jpg',
      createdAt: now ?? DateTime.now(),
    );
    state = state.copyWith(photos: <Attachment>[...state.photos, photo]);
    return true;
  }

  void removePhoto(String attachmentId) {
    state = state.copyWith(
      photos: <Attachment>[
        for (final Attachment a in state.photos)
          if (a.id != attachmentId) a,
      ],
    );
  }

  /// Sets or clears (blank) a photo's public caption, at most 80 characters.
  void setCaption(String attachmentId, String caption) {
    final String text = caption.trim();
    final String clipped = text.length > ReportLimits.captionMax
        ? text.substring(0, ReportLimits.captionMax)
        : text;
    state = state.copyWith(
      photos: <Attachment>[
        for (final Attachment a in state.photos)
          if (a.id == attachmentId)
            clipped.isEmpty
                ? a.copyWith(clearCaption: true)
                : a.copyWith(caption: clipped)
          else
            a,
      ],
    );
  }

  void setDescription(String description) =>
      state = state.copyWith(description: description);

  void setSeverity(Severity severity) =>
      state = state.copyWith(severity: severity);

  void setPeopleAffected(PeopleAffected people) =>
      state = state.copyWith(peopleAffected: people);

  /// Toggles the safety flag. The `safety` category keeps it on (AC-17).
  void setSafetyFlag(bool value) {
    if (state.safetyLocked) return;
    state = state.copyWith(safetyFlag: value);
  }

  /// Starts over with an empty draft (successful submit, confirmed discard,
  /// "Report another").
  void reset() => state = const ReportDraft();
}

/// The report draft in progress.
final reportDraftProvider = NotifierProvider<ReportDraftNotifier, ReportDraft>(
  ReportDraftNotifier.new,
);

/// "Possible duplicates" on Review (screens-spec M-07): at most three open
/// public views of the draft's category and building, the draft's floor first.
/// Non-critical: while loading or on error it is empty (the panel hides).
final possibleDuplicatesProvider = Provider<List<PublicComplaintView>>((ref) {
  final ReportDraft draft = ref.watch(reportDraftProvider);
  final ProblemCategory? category = draft.category;
  if (category == null || draft.trimmedBuilding.isEmpty) return const [];
  final List<PublicComplaintView> all =
      ref.watch(boardComplaintsProvider).asData?.value ??
      const <PublicComplaintView>[];
  final List<PublicComplaintView> matches = <PublicComplaintView>[
    for (final PublicComplaintView c in all)
      if (c.category == category &&
          c.building == draft.trimmedBuilding &&
          c.status != ComplaintStatus.closed)
        c,
  ];
  // Stable: same floor first, otherwise keep the board order.
  final List<PublicComplaintView> sameFloor = <PublicComplaintView>[
    for (final PublicComplaintView c in matches)
      if (c.floor == draft.floor) c,
  ];
  final List<PublicComplaintView> elsewhere = <PublicComplaintView>[
    for (final PublicComplaintView c in matches)
      if (c.floor != draft.floor) c,
  ];
  return <PublicComplaintView>[...sameFloor, ...elsewhere].take(3).toList();
});
