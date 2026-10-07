// The in-progress After-Repair Upload form (screens-spec M-15).
//
// UI state only: the after-photos and the resolution note of one complaint,
// kept in memory while the screen is open and discarded when it closes (Cancel
// asks "Discard?"). It holds nothing about who is working: the actor is
// attached by the write controller (`work_actions.dart`).

import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Limits of the after-repair form (screens-spec M-15).
abstract final class ResolveLimits {
  static const int minPhotos = 1;
  static const int maxPhotos = 5;
  static const int captionMax = 80;
  static const int noteMax = 500;
}

/// Limit of the optional note of Start work (screens-spec M-14).
abstract final class StartWorkLimits {
  static const int noteMax = 500;
}

/// The form's state. The note is stored as typed; [trimmedNote] is what the
/// validation and the submit use (screens-spec G-7).
@immutable
class AfterRepairDraft {
  const AfterRepairDraft({this.photos = const <Attachment>[], this.note = ''});

  /// The after-repair photos (`AttachmentKind.afterPhoto`), 1 to 5.
  final List<Attachment> photos;

  /// The resolution note.
  final String note;

  String get trimmedNote => note.trim();

  bool get photosValid =>
      photos.length >= ResolveLimits.minPhotos &&
      photos.length <= ResolveLimits.maxPhotos;

  /// A non-empty note of at most 500 characters.
  bool get noteValid =>
      trimmedNote.isNotEmpty && trimmedNote.length <= ResolveLimits.noteMax;

  /// Whether "Mark resolved" is enabled: at least one after-photo and a
  /// non-empty note (AC-37).
  bool get canSubmit => photosValid && noteValid;

  /// Whether anything was entered worth a "Discard?" prompt.
  bool get hasInput => photos.isNotEmpty || trimmedNote.isNotEmpty;

  AfterRepairDraft copyWith({List<Attachment>? photos, String? note}) =>
      AfterRepairDraft(photos: photos ?? this.photos, note: note ?? this.note);
}

/// Owner of the [AfterRepairDraft] of one complaint: every edit goes through
/// here.
class AfterRepairDraftNotifier extends Notifier<AfterRepairDraft> {
  AfterRepairDraftNotifier(this.complaintId);

  /// The complaint being resolved (keeps drafts of different complaints
  /// apart).
  final String complaintId;

  int _photoSeq = 0;

  @override
  AfterRepairDraft build() => const AfterRepairDraft();

  /// Adds an after photo (the prototype picks a bundled sample, assumption
  /// A4). Ignored at the maximum. Returns whether it was added.
  ///
  /// The photo is stamped with the current time, so it counts as fresh
  /// evidence (P1, AC-38): after a reject only photos taken after it count.
  bool addPhoto({DateTime? now}) {
    if (state.photos.length >= ResolveLimits.maxPhotos) return false;
    final DateTime at = now ?? DateTime.now();
    final int n = ++_photoSeq;
    final Attachment photo = Attachment(
      id: 'after-${at.microsecondsSinceEpoch}-$n',
      kind: AttachmentKind.afterPhoto,
      ref: 'assets/samples/after_sample_${(n - 1) % 6 + 1}.jpg',
      createdAt: at,
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

  /// Sets or clears (blank) a photo's caption, at most 80 characters.
  void setCaption(String attachmentId, String caption) {
    final String text = caption.trim();
    final String clipped = text.length > ResolveLimits.captionMax
        ? text.substring(0, ResolveLimits.captionMax)
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

  void setNote(String note) => state = state.copyWith(note: note);

  /// Starts over with an empty form (confirmed discard, successful submit).
  void reset() => state = const AfterRepairDraft();
}

/// The after-repair form of a complaint. Auto-disposed: closing the screen
/// discards the draft.
final afterRepairDraftProvider = NotifierProvider.autoDispose
    .family<AfterRepairDraftNotifier, AfterRepairDraft, String>(
      AfterRepairDraftNotifier.new,
    );
