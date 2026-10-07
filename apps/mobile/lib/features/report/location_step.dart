import 'package:campusfix_core/campusfix_core.dart';
import 'package:campusfix_design/campusfix_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../router/routes.dart';
import 'report_flow.dart';

/// The building picker's "not on the list" choice.
const String _otherBuilding = '__other__';

/// M-04 Report: Location (step 2 of 5). Building, then floor, then room, from
/// the campus directory; "Other..." lets the reporter type a building that is
/// not listed.
class LocationStep extends ConsumerStatefulWidget {
  const LocationStep({super.key, this.edit = false});

  final bool edit;

  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<LocationStep> {
  static const CampusDirectory _campus = CampusDirectory.standard;

  late final TextEditingController _room;
  late final TextEditingController _other;
  final FocusNode _roomFocus = FocusNode();
  final FocusNode _otherFocus = FocusNode();
  bool _roomTouched = false;
  bool _otherTouched = false;

  @override
  void initState() {
    super.initState();
    final ReportDraft draft = ref.read(reportDraftProvider);
    _room = TextEditingController(text: draft.room);
    _other = TextEditingController(
      text: draft.otherBuilding ? draft.building : '',
    );
    // Inline validation on blur (screens-spec G-7).
    _roomFocus.addListener(() {
      if (!_roomFocus.hasFocus) setState(() => _roomTouched = true);
    });
    _otherFocus.addListener(() {
      if (!_otherFocus.hasFocus) setState(() => _otherTouched = true);
    });
  }

  @override
  void dispose() {
    _room.dispose();
    _other.dispose();
    _roomFocus.dispose();
    _otherFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ReportDraft draft = ref.watch(reportDraftProvider);
    final ReportDraftNotifier notifier = ref.read(reportDraftProvider.notifier);
    // The draft owns the values (a floor change clears the room, a suggestion
    // fills it); keep the text field in step.
    ref.listen<String>(reportDraftProvider.select((d) => d.room), (_, room) {
      if (_room.text != room) {
        _room.value = TextEditingValue(
          text: room,
          selection: TextSelection.collapsed(offset: room.length),
        );
      }
    });

    final String? buildingValue = draft.otherBuilding
        ? _otherBuilding
        : (draft.building.isEmpty ? null : draft.building);
    final List<String> floors = draft.otherBuilding
        ? kOtherBuildingFloors
        : _campus.floorsOf(draft.building);
    final List<String> suggestions = draft.otherBuilding || draft.floor == null
        ? const <String>[]
        : _campus.roomsOf(draft.building, draft.floor!);

    final String? otherError =
        _otherTouched && draft.otherBuilding && draft.trimmedBuilding.isEmpty
        ? 'Building name is required'
        : null;
    final String? roomError = _roomTouched && draft.trimmedRoom.isEmpty
        ? 'Room or location is required'
        : null;

    return ReportStepScaffold(
      step: 2,
      stepLabel: 'Location',
      edit: widget.edit,
      primaryLabel: widget.edit ? 'Done' : 'Next',
      onPrimary: draft.locationValid
          ? () => continueFrom(
              context,
              edit: widget.edit,
              next: AppRoutes.reportPhotos,
            )
          : null,
      children: <Widget>[
        const StepHeading(
          title: 'Where is it?',
          subtitle: 'Location is visible to everyone on the campus board.',
        ),
        AppSelect<String>(
          label: 'Building',
          required: true,
          hintText: 'Select a building',
          sheetTitle: 'Building',
          value: buildingValue,
          options: <AppSelectOption<String>>[
            for (final String name in _campus.buildingNames)
              AppSelectOption<String>(value: name, label: name),
            const AppSelectOption<String>(
              value: _otherBuilding,
              label: 'Other...',
            ),
          ],
          onChanged: (String value) {
            if (value == _otherBuilding) {
              notifier.selectOtherBuilding();
              _other.clear();
            } else {
              notifier.setBuilding(value);
            }
          },
        ),
        if (draft.otherBuilding) ...<Widget>[
          const SizedBox(height: AppSpace.s4),
          AppTextField(
            label: 'Building name',
            required: true,
            controller: _other,
            focusNode: _otherFocus,
            maxLength: ReportLimits.locationMax,
            errorText: otherError,
            onChanged: notifier.setOtherBuildingName,
          ),
        ],
        const SizedBox(height: AppSpace.s4),
        AppSelect<String>(
          label: 'Floor',
          required: true,
          hintText: draft.trimmedBuilding.isEmpty
              ? 'Choose a building first'
              : 'Select a floor',
          sheetTitle: 'Floor',
          enabled: floors.isNotEmpty,
          value: draft.floor,
          options: <AppSelectOption<String>>[
            for (final String f in floors)
              AppSelectOption<String>(value: f, label: f),
          ],
          onChanged: notifier.setFloor,
        ),
        const SizedBox(height: AppSpace.s4),
        AppTextField(
          label: 'Room or location',
          required: true,
          hintText: 'e.g. Lab 204, Washroom near stairs',
          controller: _room,
          focusNode: _roomFocus,
          maxLength: ReportLimits.locationMax,
          errorText: roomError,
          onChanged: notifier.setRoom,
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.s3),
          Text('Suggestions', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: AppSpace.s2),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: <Widget>[
              for (final String room in suggestions)
                AppFilterChip(
                  label: room,
                  kind: AppFilterChipKind.toggle,
                  selected: draft.trimmedRoom == room,
                  onTap: () => notifier.setRoom(room),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
