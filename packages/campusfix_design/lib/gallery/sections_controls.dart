import 'package:campusfix_core/campusfix_core.dart';
import 'package:flutter/material.dart';

import '../widgets/app_button.dart';
import '../widgets/app_filter_chip.dart';
import '../widgets/app_search_field.dart';
import '../widgets/app_segmented.dart';
import '../widgets/app_select.dart';
import '../widgets/app_switch.dart';
import '../widgets/app_text_field.dart';
import '../widgets/select_tile.dart';
import 'gallery_parts.dart';

/// 8.1 AppButton.
class ButtonsSection extends StatelessWidget {
  /// Creates the section.
  const ButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(AppButtonVariant variant, String label) {
      return GalleryLabel(
        variant.name,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            AppButton(
              label: label,
              variant: variant,
              size: AppButtonSize.lg,
              onPressed: () {},
            ),
            AppButton(label: label, variant: variant, onPressed: () {}),
            AppButton(
              label: label,
              variant: variant,
              size: AppButtonSize.sm,
              onPressed: () {},
            ),
            AppButton(
              label: label,
              variant: variant,
              leadingIcon: Icons.add,
              onPressed: () {},
            ),
            AppButton(label: 'Disabled', variant: variant, onPressed: null),
            AppButton(
              label: label,
              variant: variant,
              loading: true,
              onPressed: () {},
            ),
          ],
        ),
      );
    }

    return GallerySection(
      id: '8.1',
      title: 'AppButton',
      description:
          'Sizes lg 48, md 40, sm 32. Row order: lg, md, sm, with icon, '
          'disabled, loading. Hover, pressed and focus are interactive: '
          'hover or press a button, or tab to it for the focus ring.',
      children: <Widget>[
        row(AppButtonVariant.primary, 'Submit'),
        const SizedBox(height: 16),
        row(AppButtonVariant.secondary, 'Save draft'),
        const SizedBox(height: 16),
        row(AppButtonVariant.tertiary, 'Cancel'),
        const SizedBox(height: 16),
        row(AppButtonVariant.destructive, 'Reject'),
        const SizedBox(height: 16),
        row(AppButtonVariant.destructiveOutlined, 'Discard'),
        const SizedBox(height: 16),
        GalleryLabel(
          'Full width lg (mobile primary action)',
          width: GalleryPhone.width,
          child: AppButton(
            label: 'Next',
            size: AppButtonSize.lg,
            expand: true,
            onPressed: () {},
          ),
        ),
        const SizedBox(height: 16),
        GalleryLabel(
          'AppIconButton (48 hit area, tooltip, badge)',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AppIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Notifications',
                badgeCount: 3,
                onPressed: () {},
              ),
              AppIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Notifications',
                badgeCount: 120,
                onPressed: () {},
              ),
              AppIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Notifications',
                showDot: true,
                onPressed: () {},
              ),
              const AppIconButton(
                icon: Icons.search,
                tooltip: 'Search',
                onPressed: null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 8.2 to 8.4: text fields, selects and the search field.
class FieldsSection extends StatefulWidget {
  /// Creates the section.
  const FieldsSection({super.key});

  @override
  State<FieldsSection> createState() => _FieldsSectionState();
}

class _FieldsSectionState extends State<FieldsSection> {
  String? _building = 'Academic Block A';
  String? _department;
  String? _room;
  final TextEditingController _description = TextEditingController(
    text: 'Ceiling lights flicker all day.',
  );
  final TextEditingController _building0 = TextEditingController(
    text: 'Academic Block A',
  );
  final TextEditingController _query = TextEditingController(
    text: 'CF-2026-0004',
  );

  @override
  void dispose() {
    _description.dispose();
    _building0.dispose();
    _query.dispose();
    super.dispose();
  }

  static const List<String> _rooms = <String>[
    'Classroom 101',
    'Classroom 102',
    'Classroom 103',
    'Classroom 104',
    'Classroom 201',
    'Classroom 202',
    'Classroom 203',
    'Electronics Lab 204',
    'Seminar Room 303',
    'Staff Room',
  ];

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<String>> buildings = <AppSelectOption<String>>[
      for (final String b in CampusDirectory.standard.buildingNames)
        AppSelectOption<String>(value: b, label: b),
    ];
    return GallerySection(
      id: '8.2-8.4',
      title: 'TextField, Select, SearchField',
      description:
          'Label above the control, 1 px outline, 2 px primary focus, 2 px '
          'error. Select opens a bottom sheet on mobile and an anchored menu '
          'on wide windows; more than 8 options adds search.',
      children: <Widget>[
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'Default with helper',
              width: 320,
              child: const AppTextField(
                label: 'Location detail',
                hintText: 'e.g. near the back door',
                helperText: AppTextField.visibilityHelper,
              ),
            ),
            GalleryLabel(
              'Required',
              width: 320,
              child: const AppTextField(
                label: 'Complaint ID',
                hintText: 'CF-2026-00042',
                required: true,
              ),
            ),
            GalleryLabel(
              'Error',
              width: 320,
              child: const AppTextField(
                label: 'Complaint ID',
                required: true,
                errorText: 'Enter an ID like CF-2026-00042.',
              ),
            ),
            GalleryLabel(
              'Disabled',
              width: 320,
              child: const AppTextField(
                label: 'Department',
                hintText: 'Assigned automatically',
                enabled: false,
              ),
            ),
            GalleryLabel(
              'Read-only',
              width: 320,
              child: AppTextField(
                label: 'Building',
                controller: _building0,
                readOnly: true,
              ),
            ),
            GalleryLabel(
              'Password',
              width: 320,
              child: const AppTextField.password(
                label: 'Password',
                required: true,
              ),
            ),
            GalleryLabel(
              'Numeric, dense (admin)',
              width: 320,
              child: const AppTextField.numeric(
                label: 'People affected',
                hintText: '0',
                dense: true,
                maxLength: 4,
              ),
            ),
            GalleryLabel(
              'Multiline with counter',
              width: 320,
              child: AppTextField.multiline(
                label: 'Describe the problem',
                required: true,
                controller: _description,
                maxLength: 500,
                helperText: AppTextField.visibilityHelper,
              ),
            ),
          ],
        ),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'Select (12 options: opens a list)',
              width: 320,
              child: AppSelect<String>(
                label: 'Building',
                required: true,
                options: buildings,
                value: _building,
                onChanged: (String v) => setState(() => _building = v),
              ),
            ),
            GalleryLabel(
              'Select, empty',
              width: 320,
              child: AppSelect<String>(
                label: 'Department',
                hintText: 'Choose a department',
                options: <AppSelectOption<String>>[
                  for (final Department d in Department.values)
                    AppSelectOption<String>(value: d.name, label: d.label),
                ],
                value: _department,
                onChanged: (String v) => setState(() => _department = v),
              ),
            ),
            GalleryLabel(
              'Select, searchable (10 options)',
              width: 320,
              child: AppSelect<String>(
                label: 'Room',
                options: <AppSelectOption<String>>[
                  for (final String r in _rooms)
                    AppSelectOption<String>(value: r, label: r),
                ],
                value: _room,
                dense: true,
                onChanged: (String v) => setState(() => _room = v),
              ),
            ),
            GalleryLabel(
              'Select, error',
              width: 320,
              child: AppSelect<String>(
                label: 'Floor',
                options: const <AppSelectOption<String>>[
                  AppSelectOption<String>(value: '1', label: 'Floor 1'),
                ],
                value: null,
                errorText: 'Choose a floor.',
                onChanged: (String v) {},
              ),
            ),
            GalleryLabel(
              'Select, disabled',
              width: 320,
              child: AppSelect<String>(
                label: 'Floor',
                options: const <AppSelectOption<String>>[
                  AppSelectOption<String>(value: '1', label: 'Floor 1'),
                ],
                value: '1',
                onChanged: null,
              ),
            ),
          ],
        ),
        GalleryWrap(
          children: <Widget>[
            const GalleryLabel(
              'SearchField (hover for outline, focus for 2 px primary)',
              width: 320,
              child: AppSearchField(),
            ),
            GalleryLabel(
              'SearchField with text',
              width: 320,
              child: AppSearchField(controller: _query),
            ),
            const GalleryLabel(
              'SearchField, disabled',
              width: 320,
              child: AppSearchField(enabled: false),
            ),
          ],
        ),
      ],
    );
  }
}

/// 8.5, 8.6, 8.16: tiles, toggles, segmented control, checkbox, radio and
/// filter chips.
class SelectionSection extends StatefulWidget {
  /// Creates the section.
  const SelectionSection({super.key});

  @override
  State<SelectionSection> createState() => _SelectionSectionState();
}

class _SelectionSectionState extends State<SelectionSection> {
  ProblemCategory? _category = ProblemCategory.electrical;
  Severity? _severity;
  bool _safety = false;
  bool _anonymous = true;
  String _range = 'active';
  bool _agree = true;
  String _radio = 'a';
  bool _includeClosed = false;
  final Set<String> _status = <String>{'In Progress', 'Assigned'};

  @override
  Widget build(BuildContext context) {
    return GallerySection(
      id: '8.5-8.6',
      title: 'SelectTile, CategoryTile, toggles and filters',
      description:
          'Tiles are radio items (mutually exclusive, selected is a 2 px '
          'primary outline plus a filled indicator). The eight category '
          'tiles come from ProblemCategory.values.',
      children: <Widget>[
        GalleryLabel(
          'CategoryTile: all 8 categories (tap to select; the last tile of '
          'each state shows disabled)',
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final int columns = c.maxWidth >= 900
                  ? 4
                  : (c.maxWidth >= 600 ? 3 : 2);
              final double width = (c.maxWidth - 12 * (columns - 1)) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final ProblemCategory category in ProblemCategory.values)
                    SizedBox(
                      width: width.floorToDouble(),
                      child: CategoryTile(
                        category: category,
                        selected: _category == category,
                        onTap: () => setState(() => _category = category),
                      ),
                    ),
                  SizedBox(
                    width: width.floorToDouble(),
                    child: const CategoryTile(
                      category: ProblemCategory.plumbing,
                      selected: false,
                      onTap: null,
                      enabled: false,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        GalleryWrap(
          children: <Widget>[
            GalleryLabel(
              'SelectTile group',
              width: 360,
              child: Column(
                children: <Widget>[
                  for (final Severity severity in Severity.values) ...<Widget>[
                    SelectTile(
                      title: severity.label,
                      hint: 'Tap to choose how serious this is',
                      selected: _severity == severity,
                      onTap: () => setState(() => _severity = severity),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SelectTile(
                    title: 'Disabled tile',
                    selected: false,
                    onTap: null,
                    enabled: false,
                  ),
                ],
              ),
            ),
            GalleryLabel(
              'AppSwitchRow',
              width: 360,
              child: Column(
                children: <Widget>[
                  AppSwitchRow(
                    title: 'This is a safety issue',
                    helper: 'Safety complaints are flagged to the admin first.',
                    value: _safety,
                    onChanged: (bool v) => setState(() => _safety = v),
                  ),
                  AppSwitchRow(
                    title: 'Hide my name on the board',
                    value: _anonymous,
                    onChanged: (bool v) => setState(() => _anonymous = v),
                  ),
                  const AppSwitchRow(
                    title: 'Safety flag',
                    helper: 'Set automatically for the Safety category.',
                    value: true,
                    onChanged: null,
                    locked: true,
                  ),
                ],
              ),
            ),
            GalleryLabel(
              'AppSegmented, AppCheckboxRow, AppRadioRow',
              width: 360,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppSegmented<String>(
                    semanticLabel: 'Show complaints',
                    segments: const <AppSegment<String>>[
                      AppSegment<String>(value: 'all', label: 'All'),
                      AppSegment<String>(value: 'active', label: 'Active'),
                      AppSegment<String>(value: 'closed', label: 'Closed'),
                    ],
                    selected: _range,
                    onChanged: (String v) => setState(() => _range = v),
                  ),
                  const SizedBox(height: 12),
                  AppSegmented<String>(
                    dense: true,
                    segments: const <AppSegment<String>>[
                      AppSegment<String>(value: '7', label: '7 days'),
                      AppSegment<String>(value: '30', label: '30 days'),
                      AppSegment<String>(value: '90', label: '90 days'),
                    ],
                    selected: '30',
                    onChanged: (String v) {},
                  ),
                  const SizedBox(height: 8),
                  AppCheckboxRow(
                    label: 'I confirm the problem is fixed',
                    value: _agree,
                    onChanged: (bool v) => setState(() => _agree = v),
                  ),
                  const AppCheckboxRow(
                    label: 'Disabled checkbox',
                    value: false,
                    onChanged: null,
                  ),
                  RadioGroup<String>(
                    groupValue: _radio,
                    onChanged: (String? v) => setState(() => _radio = v ?? 'a'),
                    child: const Column(
                      children: <Widget>[
                        AppRadioRow<String>(value: 'a', label: 'Option A'),
                        AppRadioRow<String>(value: 'b', label: 'Option B'),
                        AppRadioRow<String>(
                          value: 'c',
                          label: 'Disabled option',
                          enabled: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        GalleryLabel(
          'AppFilterChip: default, selected with count, toggle off / on, '
          'disabled',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              AppFilterChip(
                label: 'Status',
                selected: _status.isNotEmpty,
                count: _status.length,
                onTap: () => setState(() {
                  if (_status.isEmpty) {
                    _status.addAll(<String>['In Progress', 'Assigned']);
                  } else {
                    _status.clear();
                  }
                }),
              ),
              AppFilterChip(label: 'Priority', selected: false, onTap: () {}),
              AppFilterChip(
                label: 'Include closed',
                kind: AppFilterChipKind.toggle,
                selected: _includeClosed,
                onTap: () => setState(() => _includeClosed = !_includeClosed),
              ),
              AppFilterChip(
                label: 'Unresolved only',
                kind: AppFilterChipKind.toggle,
                selected: true,
                onTap: () {},
              ),
              const AppFilterChip(
                label: 'Department',
                selected: false,
                onTap: null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GalleryLabel(
          'FilterBar, mobile (scrolling row with Clear)',
          child: GalleryPhone(
            padding: false,
            child: FilterBar(
              layout: FilterBarLayout.scroll,
              hasActiveFilters: true,
              onClear: () {},
              chips: <Widget>[
                AppFilterChip(
                  label: 'Status',
                  selected: true,
                  count: 2,
                  onTap: () {},
                ),
                AppFilterChip(label: 'Category', selected: false, onTap: () {}),
                AppFilterChip(
                  label: 'Include closed',
                  kind: AppFilterChipKind.toggle,
                  selected: false,
                  onTap: () {},
                ),
                AppFilterChip(label: 'Priority', selected: false, onTap: () {}),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GalleryLabel(
          'FilterBar, admin (search first, wrapping chips, Reset filters)',
          child: GalleryPanel(
            child: FilterBar(
              layout: FilterBarLayout.wrap,
              hasActiveFilters: true,
              onClear: () {},
              search: const AppSearchField(),
              chips: <Widget>[
                AppFilterChip(
                  label: 'Status',
                  selected: true,
                  count: 2,
                  onTap: () {},
                ),
                AppFilterChip(label: 'Priority', selected: false, onTap: () {}),
                AppFilterChip(label: 'Category', selected: false, onTap: () {}),
                AppFilterChip(
                  label: 'Department',
                  selected: false,
                  onTap: () {},
                ),
                AppFilterChip(
                  label: 'Unresolved only',
                  kind: AppFilterChipKind.toggle,
                  selected: true,
                  onTap: () {},
                ),
                AppFilterChip(
                  label: 'Needs manual triage',
                  kind: AppFilterChipKind.toggle,
                  selected: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
