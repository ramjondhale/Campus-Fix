# CampusFix AI - Design System (contract)

**Chunk:** S1.1 design foundations. **Status:** v1.0, ready for S1.2 to S1.6 (screens, handoff) and S3 (`campusfix_design`).
**Companion:** `docs/design/design-system.html` is the viewable style guide and a live component gallery. It is generated from the same token values as this file. If the two ever disagree, this file wins and the HTML is a bug.
**Traceability:** R5 (privacy), R6 (board), R7 (priority), R9 (status flow), R12 (dashboard), R13 (screens); `screens-spec.md` G-8, G-9, G-12, G-13; `data-model-spec.md` section 1 (enums).

## How to read this document

* **Units.** Every size is a Flutter logical pixel (`double`). Colours are sRGB hex (`0xFFRRGGBB` in Dart; drop the `#`). Opacities are percentages.
* **Themes.** Every colour token has a **light** and a **dark** value. Both ship in S3. Dark was designed, not inverted, and passes the same contrast checks.
* **Keys.** Semantic-set keys are exactly the Dart enum `.name` values (`electrical`, `inProgress`, `critical`, ...). Do not introduce a second naming scheme.
* **Where used.** Component sections list the screen IDs from `screens-spec.md` (`M-xx` mobile, `A-xx` admin).
* **Privacy rule for every component.** A component that appears on the board, in a list, or on a maintenance screen takes `PublicComplaintView` fields only. There is no parameter, slot or style for reporter identity (R5). The one exception is the admin-only `IdentityRevealPanel` (8.25).

## 1. Principles

1. **Operational and calm.** This is a facilities tool. Information density and legibility win over decoration. No gradients, no illustration-led screens, no hero imagery.
2. **Text always names the state.** Status, priority and category always render their label (G-8). Colour, shape and glyph reinforce the label and never replace it.
3. **Shape encodes the dimension, colour encodes the value.** Status = pill with a progress ring. Priority = rectangle with signal bars. Category = rounded-square icon chip. A status and a priority are never confusable even where hues overlap.
4. **Flat first.** Cards and rows use a 1 px outline and no shadow. Shadows exist only for things that float (menu, dialog, sheet, toast).
5. **Visual weight follows urgency.** Critical is a solid red block; closed is a solid graphite block; everything between is tonal. Low priority is the quietest element on a card.
6. **Reuse before invention (G-13).** New screens compose the components in section 8. A new component needs an entry in this file first.
7. **Identity stays out.** See the privacy rule above.

## 2. Color

### 2.1 How the sets work

Three layers, all with light and dark values:

1. **Brand and Material 3 roles** (2.2) feed `ColorScheme`.
2. **Neutrals and surfaces** (2.3) feed `ColorScheme` surfaces and the page background.
3. **Semantic sets** (2.4 to 2.7). Each set has three values per theme:
   * `fg`: text and icon colour. Guaranteed 4.5:1 or better **only on its own `bg`**.
   * `bg`: container fill (badge, tag, chip, banner).
   * `accent`: non-text mark such as a ring, signal bar, dot, timeline node or chart fill. Guaranteed 3:1 or better against both the `card` surface and its own `bg`. Never use `accent` for text.

The semantic sets were generated in OKLCH at fixed lightness per theme (light: bg L 0.95, fg L 0.38, accent L 0.57; dark: bg L 0.30, fg L 0.88, accent L 0.70) so all 19 sets carry the same visual weight. Critical priority and closed status are the two deliberate solid exceptions.

### 2.2 Brand and Material 3 roles

Primary is a deep petrol teal: grounded and institutional. It is darker and less saturated than every semantic accent, so a brand action never reads as a status.

| Token | Light | Dark | Flutter role | Use |
| --- | --- | --- | --- | --- |
| `primary` | `#0F5A6A` | `#7FCBDC` | `ColorScheme.primary` | Main actions, selection, links, active states |
| `onPrimary` | `#FFFFFF` | `#00323C` | `ColorScheme.onPrimary` | Text and icons on primary |
| `primaryContainer` | `#CFEAF1` | `#0F4B59` | `ColorScheme.primaryContainer` | Selected tile tint, active nav pill, Admin role pill |
| `onPrimaryContainer` | `#00313B` | `#C9EBF3` | `ColorScheme.onPrimaryContainer` | Text and icons on primaryContainer |
| `primaryHover` | `#0B4957` | `#9AD8E6` | (custom) | Filled primary button hover background |
| `primaryPressed` | `#083A46` | `#B4E3EE` | (custom) | Filled primary button pressed background |
| `inversePrimary` | `#7FCBDC` | `#0F5A6A` | `ColorScheme.inversePrimary` | Action text and success icon on toasts |
| `secondary` | `#475B67` | `#B2C6D1` | `ColorScheme.secondary` | Neutral emphasis (secondary icons, chart baseline) |
| `onSecondary` | `#FFFFFF` | `#1B2F39` | `ColorScheme.onSecondary` | Text and icons on secondary |
| `secondaryContainer` | `#DCE6EC` | `#2F4350` | `ColorScheme.secondaryContainer` | Selected filter chip, segmented selection, avatar, PrivacyNote |
| `onSecondaryContainer` | `#122630` | `#D3E3EC` | `ColorScheme.onSecondaryContainer` | Text and icons on secondaryContainer |
| `tertiary` | `#54559A` | `#BFC0F5` | `ColorScheme.tertiary` | Reserved for the M3 contract; not used in app UI |
| `onTertiary` | `#FFFFFF` | `#26276B` | `ColorScheme.onTertiary` | Reserved |
| `tertiaryContainer` | `#E4E3FB` | `#3C3D82` | `ColorScheme.tertiaryContainer` | Reserved |
| `onTertiaryContainer` | `#1B1C5A` | `#E2E1FF` | `ColorScheme.onTertiaryContainer` | Reserved |
| `error` | `#B3261E` | `#FFB4AB` | `ColorScheme.error` | Destructive button fill, error text and borders, nav badge |
| `onError` | `#FFFFFF` | `#690005` | `ColorScheme.onError` | Text and icons on error |
| `errorContainer` | `#FEE9E6` | `#511815` | `ColorScheme.errorContainer` | Error empty-state tile, error tint |
| `onErrorContainer` | `#810109` | `#FEC9C1` | `ColorScheme.onErrorContainer` | Text and icons on errorContainer |
| `inverseError` | `#FFB4AB` | `#B3261E` | (custom) | Error icon on toast |
| `focusRing` | `#0F5A6A` | `#7FCBDC` | (custom) | Focus ring (2 px, 2 px offset); equal to primary |

`tertiary*` is part of the Material 3 contract only. Do not use it in app UI.
`primaryHover` and `primaryPressed` are custom: the filled primary button darkens on hover and press in light theme and lightens in dark theme.

### 2.3 Neutrals and surfaces

Cool-biased (hue about 230 degrees, chroma under 0.015). The page background is `canvas`; cards sit on it using `card` plus a 1 px `outlineVariant` border (no shadow).

| Token | Light | Dark | Flutter role | Use |
| --- | --- | --- | --- | --- |
| `canvas` | `#F2F5F7` | `#0D1418` | `ColorScheme.surface` | Page background; Scaffold background colour |
| `card` | `#FFFFFF` | `#131C21` | `ColorScheme.surfaceContainerLow` | Cards, list rows, panels, table body, nav bars |
| `cardSubtle` | `#EAEFF2` | `#1A252B` | `ColorScheme.surfaceContainer` | Table header, skeleton base, search fill, note blocks, disabled fill |
| `raised` | `#FFFFFF` | `#1F2B32` | `ColorScheme.surfaceContainerHigh` | Menus, dialogs, bottom sheets (floating) |
| `pressedFill` | `#DDE4E9` | `#2A3943` | `ColorScheme.surfaceContainerHighest` | Pressed rows, selected table row |
| `surfaceContainerLowest` | `#FFFFFF` | `#090F12` | `ColorScheme.surfaceContainerLowest` | Inset wells (rarely used) |
| `surfaceDim` | `#D3DBE0` | `#0D1418` | `ColorScheme.surfaceDim` | Dimmed surface (rarely used) |
| `surfaceBright` | `#FFFFFF` | `#2E3E47` | `ColorScheme.surfaceBright` | Bright surface (rarely used) |
| `onSurface` | `#121C23` | `#E3EAEE` | `ColorScheme.onSurface` | Primary text and icons |
| `onSurfaceVariant` | `#44525D` | `#AEBDC6` | `ColorScheme.onSurfaceVariant` | Secondary text, helper text, inactive icons |
| `outline` | `#6A7984` | `#80929D` | `ColorScheme.outline` | Input borders and control outlines (3:1 or better) |
| `outlineVariant` | `#C4CDD4` | `#33444E` | `ColorScheme.outlineVariant` | Dividers and card borders (decorative) |
| `inverseSurface` | `#26323A` | `#E3EAEE` | `ColorScheme.inverseSurface` | Toast and snackbar fill |
| `onInverseSurface` | `#EAF0F3` | `#1A252B` | `ColorScheme.onInverseSurface` | Text on toast |

Surface roles used by components:

| Role | Token | Examples |
|---|---|---|
| Page background | `canvas` | Scaffold, screen background, admin content area |
| Raised content | `card` | ComplaintCard, MetricCard, panels, table body, SideNav, TopBar, BottomNav |
| Recessed or secondary fill | `cardSubtle` | Table header, skeleton base, search field fill, note blocks, disabled fill |
| Floating | `raised` | Menu, dialog, bottom sheet |
| Pressed or selected row | `pressedFill` | Pressed list row, selected table row |
| Inverse | `inverseSurface` | Toast |

### 2.4 Feedback (4)

Used by InlineBanner, Toast and form validation. `error` also fills `ColorScheme.error`; the solid error fill is in the brand table.

| Key | Label | L fg | L bg | L accent | D fg | D bg | D accent | Ratio L / D |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `success` | Success | `#005121` | `#DDF6E1` | `#158F44` | `#B1E7BB` | `#0F371B` | `#58B670` | 8.3 / 9.5 |
| `warning` | Warning | `#583D00` | `#FDECD2` | `#9B6E00` | `#F4D299` | `#3E2A01` | `#CA9423` | 8.7 / 9.5 |
| `error` | Error | `#810109` | `#FEE9E6` | `#D03833` | `#FEC9C1` | `#511815` | `#F66D62` | 9.3 / 9.6 |
| `info` | Info | `#024671` | `#E1F1FF` | `#057DC5` | `#B6DDFF` | `#08304D` | `#4BA6EC` | 8.6 / 9.6 |

### 2.5 Category (8) - `ProblemCategory`

Muted on purpose. Category colour appears **only** as an icon chip (`bg` fill, `fg` icon) or a chart fill, never as a coloured text badge, so it cannot be mistaken for priority. Keys are `ProblemCategory.name`; labels are `ProblemCategory.label`.

| Key | Label | Icon | L fg | L bg | L accent | D fg | D bg | D accent | Ratio L / D |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `electrical` | Electrical | `Icons.bolt_outlined` | `#4A4401` | `#F2F0D6` | `#847A01` | `#DFDAA4` | `#332F05` | `#ABA242` | 8.6 / 9.5 |
| `plumbing` | Plumbing / Water / Washroom | `Icons.water_drop_outlined` | `#044B5A` | `#DAF4FB` | `#02859F` | `#ABE2F2` | `#07343E` | `#4AADC7` | 8.5 / 9.5 |
| `civil` | Civil / Building | `Icons.apartment_outlined` | `#543D2B` | `#F5EDE7` | `#8C715D` | `#E5D4C8` | `#362B24` | `#B29986` | 8.7 / 9.5 |
| `furniture` | Furniture | `Icons.chair_alt_outlined` | `#2C4D01` | `#E7F3DF` | `#5F853C` | `#C9E0B7` | `#243318` | `#87AC6A` | 8.4 / 9.5 |
| `cleanliness` | Cleanliness / Sanitation | `Icons.cleaning_services_outlined` | `#004F38` | `#DCF6E9` | `#098D66` | `#AFE6CD` | `#0C3627` | `#54B48E` | 8.5 / 9.6 |
| `it` | IT / Network / Projector / Computer | `Icons.computer_outlined` | `#32348C` | `#EAEEFE` | `#616CCE` | `#CCD5FF` | `#252A4F` | `#8896F1` | 9.1 / 9.5 |
| `safety` | Safety | `Icons.health_and_safety_outlined` | `#7A014B` | `#FEE8F0` | `#C13D82` | `#FFC4DC` | `#4B1932` | `#E86FA9` | 9.3 / 9.6 |
| `other` | Other | `Icons.more_horiz` | `#39444C` | `#EBEFF2` | `#6D7982` | `#D1D9DE` | `#2A2E32` | `#95A0A9` | 8.6 / 9.6 |

### 2.6 Priority (4) - `Priority`

Keys are `Priority.name`. `PriorityTag` always renders `effectivePriority`.

| Key | Label | Bars filled | Style | L fg | L bg | L accent | D fg | D bg | D accent | Ratio L / D |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `critical` | Critical | 4 | solid | `#FFFFFF` | `#B7191C` | `#B7191C` | `#3D0A08` | `#FDA297` | `#FDA297` | 6.6 / 8.7 |
| `high` | High | 3 | tonal | `#663301` | `#FFEADC` | `#B35D04` | `#FECCA9` | `#482201` | `#E18438` | 8.9 / 9.6 |
| `medium` | Medium | 2 | tonal | `#583D02` | `#FDECD1` | `#9B6E04` | `#F5D297` | `#3E2A00` | `#CB9318` | 8.7 / 9.5 |
| `low` | Low | 1 | tonal | `#2E4654` | `#E8F0F5` | `#617C8C` | `#CADAE4` | `#252F36` | `#89A3B2` | 8.6 / 9.5 |

`critical` is a solid block: `bg` is the strong red, `fg` is the on-colour. Its `accent` equals its `bg` and signal bars use `fg`.

### 2.7 Status (7) - `ComplaintStatus`

Keys are `ComplaintStatus.name`. The ring fraction is `ComplaintStatus.order / 6`.

| Key | Label | Ring | Style | L fg | L bg | L accent | D fg | D bg | D accent | Ratio L / D |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `reported` | Reported | 0/6 | tonal | `#3B434C` | `#ECEFF2` | `#6F7983` | `#D2D8DF` | `#2A2E32` | `#96A0A9` | 8.7 / 9.5 |
| `reviewed` | Reviewed | 1/6 | tonal | `#23388D` | `#E8EEFF` | `#5270CF` | `#C7D7FE` | `#1F2C50` | `#7A9AF2` | 9.0 / 9.5 |
| `assigned` | Assigned | 2/6 | tonal | `#53297A` | `#F3EAFE` | `#8B5FB9` | `#E2CCFF` | `#352547` | `#B189DD` | 9.2 / 9.5 |
| `inProgress` | In Progress | 3/6 | tonal | `#024964` | `#DCF3FF` | `#0182B0` | `#A9E0FE` | `#023246` | `#23ACE3` | 8.6 / 9.6 |
| `resolved` | Resolved | 4/6 | tonal | `#004E45` | `#D9F6F0` | `#018B7C` | `#A7E6DB` | `#033630` | `#3CB4A3` | 8.5 / 9.5 |
| `verified` | Verified | 5/6 | tonal | `#02511D` | `#DEF6E0` | `#228E40` | `#B3E7B9` | `#113719` | `#5DB56D` | 8.4 / 9.5 |
| `closed` | Closed | 6/6 | solid | `#FFFFFF` | `#373E45` | `#373E45` | `#13161A` | `#CCD2D7` | `#CCD2D7` | 10.8 / 11.9 |

`closed` is a solid graphite stamp (light) or a pale solid (dark). In a solid set the ring and check use `fg`.
Status and priority intentionally share no pair of identical values except the neutral baseline (`reported` and `low` are both quiet slate); shape and glyph separate them.

### 2.8 Chart colour rules (A-02)

* Fill bars and segments with the set `accent` for the item they represent. Order: status by `ComplaintStatus.order`; priority by `Priority.weight` descending; category by count descending.
* Every mark has a direct text label and a value. No legend-only encoding.
* Grid and axis lines use `outlineVariant`; chart text uses `onSurface` or `onSurfaceVariant`.
* A chart never mixes sets (no priority colours on a status chart).

### 2.9 Contrast audit

Method: WCAG 2.x relative luminance contrast, computed for every pair below in **both themes**. Requirements: text 4.5:1 (7:1 for primary body text and container pairs); non-text marks and control outlines 3:1.
Result: **200 pairs checked, 0 failures.** Minimum achieved ratio per group:

| Group | Pairs (both themes) | Required | Min light | Min dark |
| --- | --- | --- | --- | --- |
| Primary text on app surfaces (onSurface, 7:1) | 10 | 7.0:1 | 13.44 | 9.79 |
| Secondary text on app surfaces (onSurfaceVariant) | 12 | 4.5:1 | 6.26 | 6.17 |
| Brand and role pairs (on-colour on container, primary text) | 32 | 4.5:1 | 5.97 | 5.29 |
| Semantic fg on bg, all 19 sets | 46 | 4.5:1 | 6.63 | 8.67 |
| Semantic accent against card and its own bg (non-text) | 88 | 3.0:1 | 3.64 | 4.88 |
| Control outline, focus ring, inverse icons (non-text) | 10 | 3.0:1 | 4.10 | 5.36 |

Photo overlays (kind labels and remove buttons over photos) are theme-independent constants: `#FFFFFF` on `#0F1920` at 82%. Even over a pure white photo the effective background is about `#3A4248`, a contrast of about 10.2:1.

## 3. Typography

### 3.1 Families

| Role | Family | Weights to load | Fallback stack |
|---|---|---|---|
| Headings, titles, labels, buttons, metrics | **Archivo** | 500, 600, 700 | Helvetica Neue, Arial, sans-serif |
| Body, helper text, captions, tables | **Public Sans** | 400, 500, 600 | system-ui, Segoe UI, Roboto, sans-serif |
| Complaint IDs, code, mono data | **JetBrains Mono** | 400, 500, 600 | ui-monospace, Menlo, Consolas, monospace |

All three are on Google Fonts and available through the `google_fonts` package. Pre-load them at app start so the first frame does not flash a fallback.

### 3.2 Scale

Sizes are logical pixels; letter spacing is in pixels. "Flutter slot" is the `TextTheme` field the style is assigned to; custom styles live on `CfTypography`.

| Name | Family | Size | Line | Weight | Tracking | Flutter slot | Use |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| `display-lg` | Archivo | 44 | 52 | 700 | -0.5 | displayLarge | Reserved: marketing / empty hero |
| `display-md` | Archivo | 36 | 44 | 700 | -0.25 | displayMedium | Admin page hero number (rare) |
| `display-sm` | Archivo | 30 | 38 | 700 | 0 | displaySmall | MetricCard value |
| `headline-lg` | Archivo | 26 | 34 | 700 | 0 | headlineLarge | Admin page title, M-08 heading |
| `headline-md` | Archivo | 22 | 30 | 600 | 0 | headlineMedium | Section heading, empty-state title (large) |
| `headline-sm` | Archivo | 20 | 28 | 600 | 0 | headlineSmall | Dialog title, TopBar title |
| `title-lg` | Archivo | 18 | 26 | 600 | 0 | titleLarge | Mobile AppBar title, card group title |
| `title-md` | Archivo | 16 | 24 | 600 | 0.1 | titleMedium | List item title, sheet title |
| `title-sm` | Archivo | 14 | 20 | 600 | 0.1 | titleSmall | CategoryTile label, tile titles |
| `body-lg` | Public Sans | 16 | 24 | 400 | 0.1 | bodyLarge | Mobile reading text, input text |
| `body-md` | Public Sans | 14 | 20 | 400 | 0.1 | bodyMedium | Admin body, tables, card description |
| `body-sm` | Public Sans | 12 | 16 | 400 | 0.2 | bodySmall | Helper text, secondary metadata |
| `caption` | Public Sans | 12 | 16 | 400 | 0.2 | bodySmall (alias) | Alias of body-sm for timestamps and counters |
| `label-lg` | Archivo | 14 | 20 | 600 | 0.1 | labelLarge | Buttons (lg, md), nav labels |
| `label-md` | Archivo | 12 | 16 | 600 | 0.3 | labelMedium | StatusBadge, PriorityTag, field labels, small buttons |
| `label-sm` | Archivo | 11 | 16 | 600 | 0.5 | labelSmall | Small badges, bottom-nav labels |
| `overline` | Archivo | 11 | 16 | 700 | 1 | custom TextStyle | Table headers, group eyebrows (uppercase) |
| `mono-lg` | JetBrains Mono | 24 | 32 | 600 | -0.2 | custom (monoLarge) | M-08 confirmation Complaint ID |
| `mono-md` | JetBrains Mono | 14 | 20 | 500 | 0 | custom (monoMedium) | ID in detail headers, table cells |
| `mono-sm` | JetBrains Mono | 12 | 16 | 500 | 0 | custom (monoSmall) | ID on cards and dense rows |

Rules:

* Mobile reads at `body-lg` (16). The admin console works at `body-md` (14). Input text is 16 on mobile so iOS does not zoom on focus.
* Tables, counters and timestamps use tabular figures (`FontFeature.tabularFigures()`). Complaint IDs use the mono family exactly as stored (`CF-YYYY-NNNNN`).
* Support OS text scaling to 200 percent without clipping: containers grow in height; IDs never truncate; descriptions clamp to 2 lines only where the card spec says so.
* Headings do not exceed 2 lines on mobile; use balanced wrapping where available.
* Line length for running text on admin detail pages is 65 to 75 characters.
* No text below 11 px. 11 px is only used for `label-sm` (bottom-nav labels, small badges, overline).

## 4. Spacing and layout

### 4.1 Spacing scale (4 px base)

| Token | Value | Typical use |
| --- | ---: | --- |
| `space-0` | 0 | Reset |
| `space-1` | 4 | Icon-to-text in badges, tight stacks |
| `space-2` | 8 | Gap inside controls, chip gap |
| `space-3` | 12 | Card padding (dense), gap between cards |
| `space-4` | 16 | Screen gutter (mobile), card padding, field gap |
| `space-5` | 20 | Dialog inner gap |
| `space-6` | 24 | Section gap, dialog padding, admin gutter |
| `space-8` | 32 | Admin page gutter, large section gap |
| `space-10` | 40 | Page section break |
| `space-12` | 48 | Hero spacing, touch target |
| `space-16` | 64 | Empty-state vertical spacing |

### 4.2 Layout constants

| Constant | Value |
|---|---|
| Window class compact (mobile apps) | 0 to 599: 4 columns, gutter 16, bottom nav |
| Window class medium (tablet, narrow admin) | 600 to 1023: 8 columns, gutter 24, nav rail 72 |
| Window class expanded (admin console) | 1024 and up: 12 columns, gutter 24, side nav 240, content max width 1280 |
| Minimum touch target (mobile) | 48 x 48 (visible control may be smaller; extend the hit area) |
| Minimum pointer target (admin) | 32 x 32 |
| Control height | mobile 48, admin 40, dense admin 32 |
| App bar | mobile 56, admin top bar 64 |
| Bottom nav | 64 plus bottom safe area |
| Between cards in a list | 12 |
| Screen padding | mobile 16; admin content 24 |
| Dialog max width | mobile `min(420, width - 32)`; admin 560 |

The admin console targets expanded windows. Below 1024 it shows the rail; below 600 it shows a drawer and a single-column layout (SC-OI-2 keeps admin off mobile, so this is a graceful fallback only).

## 5. Radii and elevation

### 5.1 Radii

| Token | Value | Use |
| --- | ---: | --- |
| `r0` | 0 | Table cells, full-bleed images |
| `r1` | 2 | Progress segments, tiny marks |
| `r2` | 4 | PriorityTag, role pill, banner tag |
| `r3` | 6 | Small buttons, menu items |
| `r4` | 8 | Buttons, fields, cards, chips, thumbnails |
| `r5` | 12 | Dialogs, tiles, CategoryTile |
| `r6` | 16 | Bottom sheet top corners |
| `full` | 999 | StatusBadge, avatar, switch, badge |

Shape rule: status = pill (`full`), priority = rectangle (`r2`), category = rounded square (`r3` or `r4` by size), cards and fields = `r4`, dialogs and tiles = `r5`.

### 5.2 Elevation

Level 0 is the default for cards, rows and panels (1 px `outlineVariant` border, no shadow). Shadows are offset (0, dy), blur, spread 0. In dark theme shadows are black at higher opacity and floating surfaces are also lighter than the canvas (`raised`).

| Level | Light shadow | Dark shadow | Use |
| --- | --- | --- | --- |
| `e0` | none | none | Cards, list rows, panels, app bars |
| `e1` | 0 1 2 0 rgb(15 30 40 / .08) | 0 1 2 0 rgb(0 0 0 / .40) | Hovered card, sticky header, scrolled app bar |
| `e2` | 0 2 6 0 rgb(15 30 40 / .12); 0 1 2 0 rgb(15 30 40 / .08) | 0 2 6 0 rgb(0 0 0 / .45); 0 1 2 0 rgb(0 0 0 / .30) | Menu, dropdown, FAB |
| `e3` | 0 8 24 0 rgb(15 30 40 / .16); 0 2 6 0 rgb(15 30 40 / .10) | 0 8 24 0 rgb(0 0 0 / .55); 0 2 6 0 rgb(0 0 0 / .35) | Dialog, bottom sheet, toast |
| `e4` | 0 12 32 0 rgb(15 30 40 / .22); 0 4 10 0 rgb(15 30 40 / .12) | 0 12 32 0 rgb(0 0 0 / .65); 0 4 10 0 rgb(0 0 0 / .40) | Dragged item, popover |

Scrim behind dialogs and sheets: black at 40% (light) or 60% (dark).

## 6. Iconography

### 6.1 Library and sizes

* **Library.** Material Symbols Outlined through Flutter's built-in `Icons.*_outlined` set (weight 400, grade 0). One outlined style throughout; no filled icons except the status ring check and the switch thumb.
* **Sizes.** 16 inline with text and inside badges; 20 in buttons, fields and dense admin rows; 24 default; 32 empty-state glyph; 40 and 48 reserved for large empty states.
* **Colour.** Icons inherit the text colour of their context. Decorative icons are excluded from semantics.
* **Category icon chips.** Icon 24 in a 40 x 40 chip (tile), 20 in 32 (default), 16 in 24 (card and table), 24 in 48 (large).

### 6.2 Category glyphs

| Category key | Icon |
| --- | --- |
| `electrical` | `Icons.bolt_outlined` |
| `plumbing` | `Icons.water_drop_outlined` |
| `civil` | `Icons.apartment_outlined` |
| `furniture` | `Icons.chair_alt_outlined` |
| `cleanliness` | `Icons.cleaning_services_outlined` |
| `it` | `Icons.computer_outlined` |
| `safety` | `Icons.health_and_safety_outlined` |
| `other` | `Icons.more_horiz` |

### 6.3 Shared glyphs

Flutter `Icons.*` names: search `search`; close `close`; confirm `check`; chevrons `expand_more`, `chevron_right`, `chevron_left`; add `add`; photo `photo_camera_outlined`, `image_outlined`; home `home_outlined`; my complaints `list_alt_outlined`; board `view_kanban_outlined`; notifications `notifications_none`; person `person_outline`; time `schedule`; copy `content_copy`; warning `warning_amber`; info `info_outline`; dashboard `space_dashboard_outlined`; location `place_outlined`; privacy `verified_user_outlined`; lock `lock_outline`; show/hide `visibility_outlined`, `visibility_off_outlined`; filter `filter_list`; sort ascending `arrow_upward`; rework `undo`; upload `upload_outlined`; remove `delete_outline`; sign out `logout`; maintenance `build_outlined`; empty `inbox_outlined`; not found `search_off`; admin `admin_panel_settings_outlined`.

## 7. Motion and interaction

### 7.1 Durations and easing

| Token | Milliseconds | Use |
| --- | ---: | --- |
| `instant` | 0 | Reduced motion |
| `fast` | 100 | State layers (hover, press), opacity fades |
| `base` | 150 | Chip select, toggle, tile select, dialog exit |
| `moderate` | 250 | Dialog / sheet / toast enter, expand |
| `slow` | 350 | Page transitions, large element moves |
| `deliberate` | 500 | Progress ring fill, onboarding only |
| `shimmer` | 1400 | Skeleton loop (linear) |

| Token | Cubic Bezier (x1, y1, x2, y2) | Flutter | Use |
| --- | --- | --- | --- |
| `standard` | 0.2, 0.0, 0.0, 1.0 | `Cubic(0.2, 0.0, 0.0, 1.0)` | Most transitions |
| `enter` | 0.05, 0.7, 0.1, 1.0 | `Cubic(0.05, 0.7, 0.1, 1.0)` | Elements entering the screen |
| `exit` | 0.3, 0.0, 0.8, 0.15 | `Cubic(0.3, 0.0, 0.8, 0.15)` | Elements leaving the screen |
| `linear` | 0.0, 0.0, 1.0, 1.0 | `Cubic(0.0, 0.0, 1.0, 1.0)` | Shimmer, spinners |

Reduced motion (`MediaQuery.disableAnimations` or the OS setting): all durations become `instant`, except opacity fades which stay at `fast`. Skeletons render static. The progress ring and BeforeAfter slider do not animate.
Direct manipulation (dragging the BeforeAfter handle, scrolling) is never animated.

### 7.2 State layers and focus

| State | Rule |
|---|---|
| Hover (pointer) | overlay of the content colour at 8% |
| Focus (keyboard) | 2 px ring, 2 px offset, `focusRing` colour; never removed |
| Pressed | overlay at 12% |
| Dragged | overlay at 16% and elevation `e4` |
| Disabled | content `onSurface` at 38%, container `onSurface` at 12%; no hover or press feedback |
| Selected | `primaryContainer` fill or 2 px `primary` outline, plus a check or filled indicator (never colour alone) |
| Error | 2 px `error` outline, error icon, message in `error` colour below the control |
| Loading | control keeps its size, label hidden, 18 px spinner (`strokeWidth` 2), taps ignored (G-3) |

Overlay values are in Appendix A (`stateLayers`).

## 8. Components

Conventions for the sections below: **Used in** lists screens; **Specs** gives dimensions in logical pixels; **Variants** and **States** list what S3 must implement; **Flutter** names the Material 3 widget or theme to extend. Class names are the proposed `campusfix_design` widgets.

### 8.1 AppButton (`AppButton`)

**Used in:** M-01, M-03 to M-07, M-08, M-14 to M-17, A-01, A-04, dialogs, empty states.
**Specs:** sizes `lg` 48 high (mobile primary action, may be full width), `md` 40 (default), `sm` 32 (dense admin toolbars). Horizontal padding 24 / 20 / 12 (`tertiary` always 12). Radius `r4` (`r3` for `sm`). Label `label-lg` (`sm`: `label-md`). Leading icon 20 (`sm`: 16), gap 8. Minimum width 64.

| Variant | Fill | Label / icon | Border |
|---|---|---|---|
| `primary` | `primary` | `onPrimary` | none |
| `secondary` | transparent | `primary` | 1 px `outline` |
| `tertiary` | transparent | `primary` | none |
| `destructive` | `error` | `onError` | none |
| `destructiveOutlined` | transparent | `error` | 1 px `error` |

**States:** default; hover (`primary`: `primaryHover`; others: overlay 8% of the label colour; destructive: 12% of `onError` blended into `error`); pressed (`primary`: `primaryPressed`; others overlay 12%; destructive 22%); focus (ring); disabled (container `onSurface` 12%, label 38%, outlined border `onSurface` 12%); loading (spinner in the label colour, width preserved).
**Rules:** one `primary` per screen region. Destructive buttons are only for rejecting, discarding or deleting, and always sit behind a confirm dialog. Button labels are verbs ("Submit", "Mark as resolved"), never "OK".
**Flutter:** `primary` = `FilledButton`; `secondary` = `OutlinedButton`; `tertiary` = `TextButton`; `destructive` = `FilledButton` with `error` colours. Wire through `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`.

### 8.2 TextField (`AppTextField`)

**Used in:** M-01, M-04, M-05 (caption), M-06, M-14, M-15, M-17 (notes), A-01, A-04 (reasons, notes), search and filters.
**Specs:** label sits **above** the control (`label-md`, `onSurfaceVariant`); required fields append a red asterisk. Control min height 48 (mobile) / 40 (admin dense), radius `r4`, 1 px `outline` border, fill `card`, horizontal padding 12, text `body-lg` (mobile) / `body-md` (admin). Helper text `body-sm` `onSurfaceVariant` below; character counter right-aligned, tabular. Leading and trailing icons 20; a trailing action keeps a 48 hit area. Multiline: min 3 lines (96), counter required.

**States:** default; hover (border `onSurface`); focus (2 px `primary` border); error (2 px `error` border, message in `error`, optional leading error icon); disabled (fill `cardSubtle`, border `outlineVariant`, text 38%); read-only (fill `cardSubtle`, normal text).
**Variants:** text, password (trailing show/hide toggle), multiline, numeric.
**Rules:** validate on blur and on attempted submit (G-7); free text is trimmed; fields that take free text show the privacy helper "Visible to people involved" where privacy-spec section 6 requires it.
**Flutter:** `InputDecorationTheme` (outlined, `floatingLabelBehavior: never`); the label is rendered by `AppTextField` above the control.

### 8.3 Select and dropdown (`AppSelect`)

**Used in:** M-04 (building, floor), A-03 filters, A-04 (department, staff).
**Specs:** same shell as TextField with a trailing `expand_more` icon 20. Menu: `raised`, 1 px `outlineVariant`, radius `r4`, `e2`, padding 4, item min height 48 (40 dense); selected item `primaryContainer` with `onPrimaryContainer` text, a check, and `label-lg` weight; hover overlay 8%.
**Behaviour:** mobile opens a BottomSheet list (8.20); admin opens the anchored menu. More than 8 options adds an inline search field.
**Flutter:** `DropdownMenu` / `MenuAnchor` with `dropdownMenuTheme` and `menuTheme`.

### 8.4 SearchField (`AppSearchField`)

**Used in:** M-09, M-11, A-03.
**Specs:** height 40 (hit area 48 on mobile), radius `r4`, fill `cardSubtle`, no border until hover (`outline`) or focus (2 px `primary`). Leading `search` 20, trailing clear 28 visible. Text `body-md`. Placeholder names only public searchable fields: "Search by ID, description or location". No reporter-based search (PV-5).
**Flutter:** `SearchBar` with a custom `SearchBarThemeData`, or `AppTextField` variant.

### 8.5 SelectTile and CategoryTile (`SelectTile`, `CategoryTile`)

**Used in:** M-03 (category), M-06 (severity, people affected).
**SelectTile specs:** min height 56, padding 12 x 16, radius `r5`, 1 px `outlineVariant`, fill `card`; leading radio 20 (2 px `outline`, selected 2 px `primary` with a 10 px dot); title `title-sm`; hint `body-sm` `onSurfaceVariant`; 8 between tiles. Selected: 2 px `primary` outline and `primaryContainer` at 45% over `card`.
**CategoryTile specs:** min height 96, padding 12, radius `r5`, 2 per row on a 360 wide phone, 12 gap. Icon chip 40 x 40 (`r4`, category `bg`/`fg`, icon 24), label `title-sm` below, optional helper `body-sm`. Selected: 2 px `primary` outline, `primaryContainer` 55% tint, 20 px check badge top-right (`primary` fill). The 8 tiles come from `ProblemCategory.values` with `label`.
**States:** default, hover (overlay 4% `onSurface`), pressed (8%), focus (ring), selected, disabled (50% opacity).
**Content:** `safety` shows "For immediate danger contact campus security directly"; `other` shows "Will be reviewed manually".
**Flutter:** custom widgets over `InkWell` and `Semantics(selected: ..., inMutuallyExclusiveGroup: true)`. Not `ChoiceChip`.

### 8.6 Toggle and SegmentedControl (`AppSwitchRow`, `AppSegmented`)

**Used in:** M-06 safety flag; M-09 All / Active / Closed; A-03 toggles ("Unresolved only", "Needs manual triage"); M-11 "Include closed".
**Toggle specs:** track 48 x 28, off: `cardSubtle` with 2 px `outline` border and a 16 px `outline` thumb; on: `primary` track with a 20 px `onPrimary` thumb. Row min height 56: title `title-sm`, helper `body-sm`. Locked state (M-06 safety category): control disabled at 55%, lock icon 16 before the title, helper explains why.
**Segmented specs:** height 40, radius `r4`, 1 px `outline`; segment padding 0 16, label `label-lg`; selected `secondaryContainer` with `onSecondaryContainer` and a leading check 16; segments are separated by 1 px `outlineVariant`.
**Flutter:** `Switch` with `switchTheme` inside a custom row; `SegmentedButton` with `segmentedButtonTheme`.

### 8.7 StatusBadge (`StatusBadge`)

**Used in:** every place a status is shown (G-8): cards, tables, headers, dashboard lists.
**Specs:** pill (`full`), height 24 (`sm` 20), padding left 7 / right 10 (`sm` 6 / 8), gap 6 (`sm` 5). Leading ring 14 (`sm` 12): circle radius 5, stroke 2, track at `accent` 28%, progress arc from 12 o'clock clockwise by `order/6`. `reported` is the empty track only; `closed` is a filled disc (radius 6.5) with a check. Label `label-md` (`sm`: `label-sm`) from `ComplaintStatus.label`, never abbreviated. Colours from the status set (`bg`, `fg`, ring `accent`; `closed` ring `fg`).
**States:** non-interactive. If wrapped in a tap target (filter chip), use the chip's states.
**Flutter:** `StatusBadge(status: ComplaintStatus)`; ring is a small `CustomPainter`. Semantics label: "Status: In Progress".

### 8.8 PriorityTag (`PriorityTag`)

**Used in:** every place a priority is shown (G-8). Always pass `effectivePriority`.
**Specs:** rectangle, radius `r2`, height 22 (`sm` 18), padding left 6 / right 8 (`sm` 5 / 6), gap 6 (`sm` 4). Signal-bar glyph: 4 bars, 2.5 wide, 1.5 gap, heights 4, 6, 8, 10; the first `Priority.weight` bars are full colour, the rest at 28% opacity. Label `label-md` weight 700 (`sm`: `label-sm` 700) from `Priority.label`. Colours from the priority set; `critical` is solid with `fg` bars.
**Overridden marker (A-04 only):** a separate chip next to the tag: height 22, 1 px `outline`, radius `r2`, `undo` icon 12, label `label-sm` "Overridden". Not shown anywhere else (screens-spec A-03).
**Flutter:** `PriorityTag(priority: Priority)`. Semantics label: "Priority: Critical".

### 8.9 ComplaintId (`ComplaintIdText`)

**Used in:** M-08, M-10, M-14, M-17, A-04 headers, every card and row.
**Specs:** JetBrains Mono, text exactly as stored. `sm` = `mono-sm` (cards, rows, `onSurfaceVariant`), `md` = `mono-md` (detail headers, `onSurface`), `lg` = `mono-lg` (M-08 confirmation, `onSurface`). Never wraps or truncates.
**Copy:** `lg` and `md` in detail headers are tappable with a trailing `content_copy` 20 and a 48 hit area; copying shows the toast "Copied CF-2026-00042" (8.21).

### 8.10 ComplaintCard (`ComplaintCard`)

**Used in:** M-02, M-09, M-11 (+ M-07 duplicates), M-13, M-16, A-02 lists.
**Input:** a `PublicComplaintView` only. The constructor has no reporter, assignee, actor or "mine" parameter.
**Shared specs:** container `card`, 1 px `outlineVariant`, radius `r4`, padding 12, gap 12 between thumbnail and body, body gap 6. Row 1: `ComplaintId` `sm` left, `PriorityTag` right. Row 2: category chip `sm` (24) plus label `title-sm`. Location line: `place_outlined` 14 plus `body-sm` `onSurfaceVariant`, up to 2 lines, formatted "Building · Floor · Room". Last row: `StatusBadge` left, time right (`body-sm`, `schedule` 14; relative under 24 h, otherwise absolute date and time, G-8). The whole card is one focusable button; its semantics label reads "CF-2026-00042, Electrical, Critical priority, In Progress".

| Variant | Used in | Thumbnail | Extra content |
|---|---|---|---|
| `board` | M-11, M-02 highlights, M-07 duplicates | 80 x 80 first before-photo | description clamped to 2 lines; submitted time |
| `mine` | M-09, M-02 active | 72 x 72 | "Updated 3 h ago" instead of description |
| `work` | M-13 | 72 x 72 | "Waiting 5 h" (clock icon) |
| `verify` | M-16 | two 56 x 56 (Before, After) with kind labels | "Resolved 3 h ago", `sm` badge |
| `row` | A-02 lists | none | single line: ID, category chip, "Category · Building · wait", PriorityTag, 40 high |
| `skeleton` | all loading (G-3) | `cardSubtle` block | shimmering bars mirroring the layout |

**States:** default; hover (border `outline`, overlay 3%); pressed (`pressedFill`); focus (ring); selected (2 px `primary` outline, `primaryContainer` 40% tint; admin multi-select contexts); loading skeleton.
**Privacy:** there is no way to show identity. A "mine" marker is not allowed on the board (M-11).
**Flutter:** `Card` (flat, `cardTheme`) with `InkWell`.

### 8.11 Complaint table (`ComplaintTable`)

**Used in:** A-03.
**Specs:** header 40 high, fill `cardSubtle`, `overline` labels, sticky; rows 52 high (44 dense), cell padding 0 x 10, bottom border `outlineVariant`; ID in `mono-md`; numbers tabular. Columns in order: ID, Category (chip `sm` + label), Location (building · floor · room, wraps to 2 lines), Priority (`sm` tag), Status (`sm` badge), Department (label or "Unassigned" in `onSurfaceVariant`), Waiting (unresolved only, "-" otherwise), Updated. **No reporter column. No reporter-based search, sort or filter.** Sort indicator `arrow_upward` 12 in the active header. Footer: range and rows-per-page (25 / 50).
**States:** row hover overlay 4%, selected `pressedFill`, focus ring; loading skeleton rows; empty and filtered-empty via EmptyState (left-aligned).
**Flutter:** `PaginatedDataTable` styled via `dataTableTheme`, or a custom sliver table for sticky header.

### 8.12 PhotoUploader and PhotoThumbnail (`PhotoUploader`, `PhotoThumbnail`)

**Used in:** M-05 (before, 1 to 5), M-15 (after, 1 to 5); thumbnails in cards, galleries, M-17.
**Uploader specs:** square tiles, min 100 (3 per row on a 360 phone), gap 8, radius `r4`, 1 px `outlineVariant`. Counter "n of 5" above (`label-md`). Add tile: 1.5 px dashed `outline`, `primary` label `label-md` with `add` icon 20, `primary` 6% hover overlay. Empty state: one full-width add tile (min height 152, `cardSubtle`, camera icon 32, "Add a photo"). Maximum reached: hide the add tile and show helper "Maximum 5 photos". Helper under the uploader: "Avoid including people's faces or documents."
**Tile specs:** remove button is a 24 px circle (black 80%, white icon 14) inside a 44 x 44 hit area, top-right. Optional caption field below the selected tile (80 characters).
**Tile states:** ready; uploading (black 62% overlay, upload icon, 4 px progress bar); failed (1 px `error` outline plus inset 1 px, deep red overlay, "Upload failed" and a small Retry button); removed with undo toast.
**PhotoThumbnail sizes:** 56, 72, 80, 100, and 4:3 for galleries. Radius `r4`, 1 px `outlineVariant`. Kind label chip (Before / After): `label-sm` uppercase, white on black 82%, bottom-left.
**Flutter:** custom widgets; image picking is mocked (A4). Placeholder while loading: `cardSubtle`.

### 8.13 BeforeAfter comparator (`BeforeAfter`)

**Used in:** M-10, M-17, A-04.
**Specs:** 4:3 frame, max width 520 (full width on mobile), radius `r4`, 1 px `outlineVariant`.
**`slider` variant:** the after photo is clipped from the divider to the right edge. Divider 2 px white with a 1 px dark halo; handle knob 40 px white circle with two chevrons 16; corner tags "Before" (left) and "After" (right), `label-md` uppercase on black 82%. Pointer drag anywhere moves the divider. Keyboard: left and right 5%, with Shift 20%, Home 2%, End 98%; semantics `slider`, value 0 to 100.
**`split` variant:** two 4:3 panes side by side with 8 gap; falls back to one column below 320 px container width. Captions under each pane (`body-sm`): "Added with the report", "Added when resolved".
**Rules:** multiple after photos show as a thumbnail strip under the comparator; tapping one swaps it in. Zoom opens the full-screen viewer.
**Flutter:** custom `CustomPainter` or `ClipRect` with a `GestureDetector`; expose `Semantics(slider: true)`.

### 8.14 Timeline item and StatusStepper (`TimelineItem`, `StatusStepper`)

**Used in:** M-10, M-14, M-17, A-04.
**Timeline item specs:** chronological, oldest first. Node 16 px circle; past = status `accent` fill with a 3 px `card` ring and 1.5 px accent halo; current = `card` fill with a 4 px `primary` ring; rework (T7) = `error` (current rework: `card` fill with a 4 px `error` ring). Connector 2 px `outlineVariant`, 12 gap between node and content, 20 between items. Header row: status label `title-sm`, `RolePill` (actor **role label only**), time `body-sm` tabular. Optional note in a `cardSubtle` block, radius `r3`, padding 8 x 12, `body-md`.
**Admin form (A-04 only):** adds an actor line in `mono-sm` `onSurfaceVariant` ("actor id · name") and the "Admin only" tag. The public form never has this line.
**StatusStepper `compact` (mobile M-10):** header "In Progress" (`title-sm`) and "Step 4 of 7" (`body-sm`); 7 segments, 6 high, `r1`, 3 gap: done `primary`, current `primary` with a 2 px `card` gap and 1.5 px `primary` ring, upcoming `outlineVariant`. A Rework marker row (`undo` 14, `label-sm`, `error`) appears when T7 occurred.
**StatusStepper `full` (admin and tablets):** 7 dots 14 px with 2 px connectors and `label-sm` captions; minimum width 560 (scrolls inside its container below that).
**Flutter:** custom widgets; no stock `Stepper`.

### 8.15 MetricCard (`MetricCard`)

**Used in:** A-02.
**Specs:** container `card`, 1 px `outlineVariant`, radius `r4`, padding 16, gap 4. Label `label-md` `onSurfaceVariant`; value `display-sm` (Archivo 30/38, tabular); definition `body-sm` `onSurfaceVariant`. Grid: auto-fit, min 190, gap 12. Cards: Total, Pending, Critical / High, Assigned, In progress, Resolved, Closed, Awaiting verification (definitions in screens-spec A-02; Pending + Assigned + In progress + Resolved + Closed = Total).
**Attention variant (Critical / High):** a 20 px square flag (`r2`) in the critical set `bg`/`fg` with an `warning_amber` icon 14, right of the label. No accent rail.
**States:** default; clickable (hover border `outline` and overlay 3%, focus ring, pressed `pressedFill`; opens A-03 with the preset filter); loading (skeleton value 30 high and 60% wide, caption 12 high and 80% wide); error ("Could not load." in `error`, plus a small tertiary Retry).
**Charts inside A-02:** horizontal bar rows, grid 96 label / flexible track / 32 value; track 12 high `cardSubtle` `r2`, fill set `accent`; value `body-sm` weight 600 tabular, right-aligned.
**Flutter:** `Card` plus `Column`; charts drawn with simple `Container` bars (no chart package needed for v1).

### 8.16 FilterBar and FilterChip (`FilterBar`, `AppFilterChip`)

**Used in:** M-09 (segmented only), M-11, A-03.
**FilterChip specs:** height 32, radius `r4`, padding 0 x 12, 1 px `outline`, label `label-lg`, icons 16. Menu chips show a trailing `expand_more`. A chip with active values is selected: `secondaryContainer` fill, `onSecondaryContainer` text, no border, plus a count pill (18 high, inverse colours). Toggle chips ("Include closed", "Unresolved only") show a leading check when on.
**States:** default; hover (overlay 8%); pressed (12%); focus (ring); selected; disabled (40% opacity).
**Mobile bar:** one horizontally scrolling row (gap 8) directly under the app bar; trailing tertiary "Clear" appears when any filter is active. **Admin toolbar:** wrapping row (gap 8 x 12), SearchField first (width 280), then chips, then "Reset filters".
**Flutter:** `FilterChip` with `chipTheme`; multi-select menus use `MenuAnchor` (desktop) or a BottomSheet checklist (mobile).

### 8.17 EmptyState (`EmptyState`)

**Used in:** every list (G-5), E-403, E-404, load errors (G-4).
**Specs:** vertical stack, gap 8, padding 32 x 16, max width 360. Icon tile 64 (`r5`, `cardSubtle`, icon 32 `onSurfaceVariant`); title `title-lg`; body `body-md` `onSurfaceVariant`, max 34 characters per line; one action `AppButton`. Centred on mobile, left-aligned inside admin tables.

| Variant | Icon | Title (example) | Action |
|---|---|---|---|
| `nothing` | `inbox_outlined` | You haven't reported anything yet | `primary` with a clear next step |
| `filtered` | `filter_list` | No matching complaints | `secondary` Clear filters |
| `error` | `warning_amber` on `errorContainer` | Couldn't load complaints | `secondary` Retry |
| `notFound` / `forbidden` | `search_off` | We couldn't find that complaint / You don't have access to this page | `primary` Go home |

E-404 never reveals whether an ID exists (G-6).

### 8.18 AppBar and TopBar (`AppTopBar`, `AdminTopBar`)

**Used in:** all screens.
**Mobile app bar:** 56 high, fill `canvas`, title `title-lg` left-aligned, icon buttons 48 hit area. A 1 px `outlineVariant` bottom edge appears when content scrolls under it (no shadow). Variants: `home` (greeting small `body-sm` plus name `title-md`, notification bell with badge, user avatar 32), `page` (back arrow, title, optional trailing actions; fill `card` with bottom border on detail pages), `flow` (close `X`, title "Report a problem", then a row "Step 2 of 5 · Location" in `label-md` and a 5-segment progress bar: segments 4 high, `r1`, 4 gap, done `primary`, upcoming `outlineVariant`).
**Admin top bar:** 64 high, fill `card`, bottom border `outlineVariant`, page title `headline-sm`, right side: optional range control (`AppSegmented`), role pill and avatar.
**Flutter:** `AppBar` with `appBarTheme` (elevation 0, `scrolledUnderElevation` 0, surface tint transparent).

### 8.19 BottomNav and SideNav (`AppBottomNav`, `AdminSideNav`)

**Used in:** mobile (G-9), admin A-02 to A-04.
**BottomNav specs:** 64 high plus safe area, fill `card`, top border 1 px `outlineVariant`; 3 or 4 equal destinations by role (Reporter: Home, My Complaints, Board, Notifications; Maintenance: Work, Board, Notifications; Verifier: Verify, Board, Notifications). Icon 24 inside a 56 x 28 pill; label `label-sm`. Active: pill `primaryContainer`, icon `onPrimaryContainer`, label `onSurface`; inactive: `onSurfaceVariant`. Badge: `error` fill, `onError` text `label-sm` 700, min 16 high, "99+" cap; a bare 8 px dot for unread-without-count.
**SideNav specs:** expanded 240 wide, rail 72 (600 to 1023), drawer below 600. Fill `card`, right border 1 px `outlineVariant`, padding 16 x 12. Brand block on top (28 px `primary` square mark and wordmark). Items 44 high, radius `r4`, icon 20 plus `label-lg`; active `primaryContainer` / `onPrimaryContainer`; hover overlay 6%. Footer: avatar 32 plus role label. Destinations: Dashboard, Complaints.
**Flutter:** `NavigationBar` with `navigationBarTheme` (indicator `primaryContainer`); `NavigationRail` / `NavigationDrawer` for admin.

### 8.20 Dialog and BottomSheet (`AppDialog`, `AppBottomSheet`)

**Used in:** M-03 and M-04 discard confirms, M-15 resolve confirm, M-17 verify and reject (note required), A-04 action confirms, M-05 photo source sheet, M-04 pickers, mobile filter checklists.
**Dialog specs:** fill `raised`, radius `r5`, padding 24, content gap 12, `e3`, max width per section 4.2. Title `headline-sm`; body `body-md` `onSurfaceVariant`; optional form field (note); actions right-aligned, gap 8, the primary action last (`tertiary` Cancel + `primary` or `destructive`). Scrim section 5.2. Enter: 250 ms `enter` (fade plus scale from 0.96); exit 150 ms `exit`. Focus is trapped; Escape and scrim tap dismiss unless a destructive write is in flight.
**BottomSheet specs:** fill `raised`, top radius `r6`, padding 8 x 16 x 24, grab handle 32 x 4 `outlineVariant`, title `title-md`, rows 56 high with 24 leading icon and `body-lg` label, max height 90%, drag to dismiss, `e3`.
**Copy rules:** titles are questions or actions ("Reject and request rework?"); the destructive button repeats the verb ("Reject").
**Flutter:** `showDialog` + `AlertDialog` with `dialogTheme`; `showModalBottomSheet` with `bottomSheetTheme`.

### 8.21 Toast and Snackbar (`AppToast`)

**Used in:** M-15 "Sent for verification", M-17 results, M-12 "No longer available", copy confirmations, recoverable errors.
**Specs:** fill `inverseSurface`, text `onInverseSurface` `body-md`, radius `r4`, min height 48, padding 8 8 8 16, `e3`, max width 420 (admin 560). Leading icon 20 (success `inversePrimary`, error `inverseError`). Action: `label-lg` in `inversePrimary`, 8 x 12 padding. Position: bottom centre, 16 above the bottom nav or screen edge.
**Timing:** 4 s; 6 s with an action; errors persist until dismissed. Enter 250 ms `enter`, exit 150 ms `exit`. Announced politely (`liveRegion`), errors assertively. A toast never holds the only copy of an error (G-4).
**Flutter:** `SnackBar` with `snackBarTheme` (floating, behaviour `floating`).

### 8.22 InlineBanner and PrivacyNote (`InlineBanner`, `PrivacyNote`)

**Used in:** M-10 closed notice, G-4 and G-6 inline errors, A-04 stale and unmet preconditions, M-07 and field helpers for privacy.
**InlineBanner specs:** radius `r4`, padding 12 x 16, gap 12, fill from a feedback set (`info`, `success`, `warning`, `error`) with `fg` text; leading icon 20 in set `accent`; title `title-sm`, body `body-md`; optional small outlined action (border and text `fg`). No accent rail.
**PrivacyNote specs:** fill `secondaryContainer`, text `onSecondaryContainer` `body-md`, 1 px `outlineVariant`, leading `verified_user_outlined` 20. Fixed strings: "Your name and contact details are never shown on the board or to maintenance staff." (M-07) and "Avoid including people's faces or documents." (M-05).

### 8.23 Avatar and RolePill (`UserAvatar`, `RolePill`)

**Used in:** signed-in user header and menu, A-04 admin-only panels, Timeline (RolePill only).
**Avatar specs:** circle 24 / 32 / 40, `secondaryContainer` fill, `onSecondaryContainer` initials (`label-sm` / `label-md` / `label-lg`). No photos. **Never on a board item, card, list row or maintenance screen.**
**RolePill specs:** height 22, radius `r2`, 1 px `outlineVariant`, role glyph 12 plus `label-sm` `onSurfaceVariant`; `admin` uses `primaryContainer` with `onPrimaryContainer` and no border. Roles: Reporter, Maintenance, Verifier, Admin (from `UserRole`). A RolePill names a role, never a person.

### 8.24 Skeleton (`Skeleton`)

**Used in:** every list and detail load (G-3).
**Specs:** blocks in `cardSubtle`, radius `r2` (`r4` for thumbnails), mirroring the final layout. Shimmer: a highlight of `card` at 70% sweeping left to right every 1400 ms (`linear`). Static when reduced motion is on. Never show a blank screen while loading.
**Flutter:** a small `Shimmer`-style widget built on `AnimationController`; no third-party package required.

### 8.25 IdentityRevealPanel (`IdentityRevealPanel`)

**Used in:** A-04, **admin role only**. Not built into the widget tree for verifiers.
**Specs:** container `card`, 1 px `outline`, radius `r4`. Header: lock icon 20, title `title-sm`, "Admin only" tag (`primaryContainer`, `overline`), and a `secondary` `sm` button "Reveal reporter identity". Collapsed state shows four masked fields (Name, ID number, Email, Phone) as `●●●●` in `mono-sm` with `overline` labels. Revealed state shows values and the button becomes "Hide".
**Rules:** collapsed on load; re-collapses on navigation, sign-out and app background; no copy-all, no export, no identity in the URL or document title (privacy-spec LK-8). Phase 2 writes an audit entry before revealing (privacy-spec section 9). Test PR-T: page text contains no identity until Reveal.

### 8.26 Reference compositions

Three assembled examples in the HTML guide fix inter-component spacing and are the visual acceptance targets for S1.3 and S1.5.

| Composition | Screens | Layout rules |
|---|---|---|
| Campus Problem Board | M-11 | App bar, scrolling FilterBar (16 side padding), list of `board` ComplaintCards with 12 gap, BottomNav, FAB for reporters |
| Report step | M-03 to M-07 | `flow` app bar with step progress; fields stacked with 16 gap; one `lg` primary "Next" fixed at the bottom with 16 padding |
| Admin dashboard | A-02 | SideNav 240, TopBar 64 with range control, content padding 24, MetricCard grid, then charts and lists in a 2-column grid with 16 gap |

## 9. Accessibility rules

1. Text 4.5:1 or better on its surface in both themes; icons, accents and control outlines 3:1 or better (section 2.9).
2. Status, priority and category are always printed as text (G-8, G-12). Colour is never the only signal.
3. Mobile touch targets are at least 48 x 48; pointer targets at least 32 x 32.
4. Focus is a visible 2 px ring with 2 px offset on every interactive element, both themes, never removed.
5. Every control has a semantic label. Icon-only buttons carry a tooltip and a label. Tiles use radio or toggle semantics (`inMutuallyExclusiveGroup`, `selected`).
6. BeforeAfter is a keyboard slider; `split` is the no-drag alternative.
7. Text scales with the OS up to 200 percent without clipping or overlap.
8. Reduced motion removes slide, scale and shimmer animation (7.1).
9. Toasts announce politely and never hold the only copy of an error. Dialogs trap focus and restore it on close.
10. Form errors name the problem and the fix, are linked to the field, and are not colour-only (icon plus text).

## 10. Flutter package mapping (`campusfix_design`)

### 10.1 File layout

```
packages/campusfix_design/lib/
  theme/
    cf_colors.dart        // CfColors.light / .dark (ColorScheme + extension), CfSemanticSet
    cf_typography.dart    // CfTypography.textTheme, mono styles
    cf_spacing.dart       // CfSpace, CfRadius, CfElevation, CfIconSize, CfLayout
    cf_motion.dart        // CfMotion durations and curves
    cf_theme.dart         // CfTheme.light(), CfTheme.dark() -> ThemeData
  widgets/                // one file per component in section 8
  campusfix_design.dart   // barrel export
```

### 10.2 Token to Dart

| Contract | Dart | Notes |
|---|---|---|
| Colour roles (2.2, 2.3) | `ColorScheme(brightness: ..., primary: ..., ...)` inside `CfColors.light` / `CfColors.dark` | Use `ColorScheme(...)` directly, not `fromSeed`. Map each role by name; custom tokens (`card`, `cardSubtle`, `raised`, `pressedFill`, `primaryHover`, `primaryPressed`, `inverseError`, `focusRing`) live on `ThemeExtension<CfColorsExtension>` |
| Surface roles | `canvas` -> `surface`; `card` -> `surfaceContainerLow`; `cardSubtle` -> `surfaceContainer`; `raised` -> `surfaceContainerHigh`; `pressedFill` -> `surfaceContainerHighest` | `scaffoldBackgroundColor = canvas` |
| Semantic sets (2.4 to 2.7) | `final class CfSet { final Color fg, bg, accent; }` and `ThemeExtension<CfSemanticColors>` with `CfSet category(ProblemCategory c)`, `CfSet priority(Priority p)`, `CfSet status(ComplaintStatus s)`, `CfSet feedback(CfFeedback f)` | Look up by enum `.name`; a missing key throws in debug |
| Type scale (3.2) | `CfTypography.textTheme` assigns the 15 Material slots; extra `overline`, `monoLg`, `monoMd`, `monoSm` as `static TextStyle` | Archivo / Public Sans via `GoogleFonts`; apply `FontFeature.tabularFigures()` to table and counter styles |
| Spacing (4.1) | `abstract final class CfSpace { static const double s1 = 4, s2 = 8, ...; }` | Names `space-4` -> `s4` |
| Radii (5.1) | `abstract final class CfRadius { static const BorderRadius r4 = BorderRadius.all(Radius.circular(8)); ... }` | also `double` values |
| Elevation (5.2) | `CfElevation.e1(Brightness b)` -> `List<BoxShadow>` | cards use `BoxDecoration(border: ...)` not `Material.elevation` |
| Icon sizes (6) | `abstract final class CfIconSize { static const double s16 = 16, ...; }` | |
| Motion (7.1) | `CfMotion.fast = Duration(milliseconds: 100)` ...; `CfMotion.standard = Cubic(0.2, 0, 0, 1)`; `CfMotion.reduced(context)` returns `Duration.zero` when `MediaQuery.disableAnimationsOf` | |
| State layers (7.2) | `CfStateLayer.hover = 0.08` ... applied through `WidgetStateProperty` | |

### 10.3 ThemeData wiring

`CfTheme.light()` and `CfTheme.dark()` return `ThemeData(useMaterial3: true, colorScheme: ..., textTheme: ..., scaffoldBackgroundColor: canvas, extensions: [CfColorsExtension, CfSemanticColors], visualDensity: VisualDensity.standard)` plus these component themes:

| Component (section 8) | ThemeData slot |
|---|---|
| AppButton | `filledButtonTheme`, `outlinedButtonTheme`, `textButtonTheme` |
| TextField, Select, SearchField | `inputDecorationTheme`, `dropdownMenuTheme`, `searchBarTheme` |
| Toggle, SegmentedControl | `switchTheme`, `segmentedButtonTheme` |
| FilterChip | `chipTheme` |
| ComplaintCard, MetricCard | `cardTheme` (elevation 0, `outlineVariant` side, radius `r4`) |
| AppBar | `appBarTheme` (elevation 0, scrolledUnder 0, tint transparent) |
| BottomNav, SideNav | `navigationBarTheme`, `navigationRailTheme`, `navigationDrawerTheme` |
| Dialog, BottomSheet | `dialogTheme`, `bottomSheetTheme` |
| Toast | `snackBarTheme` |
| Table | `dataTableTheme` |
| Dividers, focus | `dividerTheme` (`outlineVariant`, 1 px), `focusColor` / custom focus decoration |
| Progress | `progressIndicatorTheme` (`primary`, 2 px) |

### 10.4 Rules for S3

* Widgets read colours only from `Theme.of(context)` and the extensions. No `Color(0x...)` outside `cf_colors.dart`.
* Every component widget accepts view types from `campusfix_core` (`PublicComplaintView`, enums), never `Complaint`. This is how the privacy rule in section 8 is enforced by the type system.
* `StatusBadge`, `PriorityTag` and `CategoryTile` take the enum and build their own label, colours and glyph. Screens never pass colours or label strings.
* Token drift test: copy Appendix A to `test/fixtures/tokens.json` and assert every `CfColors`, `CfSet`, spacing, radius and motion constant equals it.
* Contrast test: for each semantic set and theme, assert `fg` on `bg` is at least 4.5:1 using the same luminance formula as section 2.9.
* Golden tests: one golden per component state in section 8 in light and dark.
* A gallery screen (S3.2) renders section 8 so it can be compared against the HTML guide.

## 11. Open design questions for the orchestrator

1. **Dark theme scope.** PLAN S3.1 says "light theme (dark optional)". Dark tokens are specified and verified here; confirm whether S3 ships dark in v1 or defers it (only `CfColors.dark` and goldens are affected).
2. **No college brand colours were provided.** The petrol teal primary is a placeholder-quality decision made for legibility and distinctness. If the college has a logo or brand colour, only the `primary*` tokens and `focusRing` need to change; semantic sets are independent.
3. **Notifications nav label.** G-9 says "Notifications"; on a 4-item bottom nav the guide shows "Alerts" so labels do not truncate at 360 wide. Confirm the short label.
4. **Photo assets.** Mock photos (A4) need roughly 8 bundled before/after sample images. The style guide uses drawn placeholders; S2.6 or S3 needs real sample assets.
5. **Icon source.** Built-in `Icons.*_outlined` (no extra dependency) is specified. A custom set or `material_symbols_icons` would change section 6 only.
6. **Admin below 1024.** SC-OI-2 keeps admin off mobile, so the rail and drawer in 8.19 are fallback only. Confirm that tablet use of the admin console is not a requirement.
7. **Status for rework.** T7 returns a complaint to `inProgress`; the design shows "Rework" as a marker (stepper, timeline node, work tab) rather than an eighth status. Confirm there is no need for a distinct `StatusBadge` variant.
8. **Claude Design project.** PLAN S1.1 mentions a Claude Design project. This chunk delivered the contract and the HTML guide; a Claude Design import (if wanted) is a follow-up using these values.
9. **Solid critical and solid closed.** These two are intentionally louder than every other tag. Confirm this hierarchy against any stakeholder preference for uniform tags.
10. **`SelectTile` vs `CategoryTile`.** Both are specified (PLAN S1.2 lists SelectTile; the screens need CategoryTile). S3 can implement `CategoryTile` as a `SelectTile` with an icon chip.

## Appendix A - machine-readable tokens

Copy into `packages/campusfix_design/test/fixtures/tokens.json` for the drift test (section 10.4).

```json
{
  "version": "1.0.0",
  "note": "Generated with design-system.html from the same source. Keys of semantic sets equal the Dart enum .name values.",
  "colors": {
    "light": {
      "canvas": "#F2F5F7",
      "card": "#FFFFFF",
      "cardSubtle": "#EAEFF2",
      "raised": "#FFFFFF",
      "pressedFill": "#DDE4E9",
      "surfaceContainerLowest": "#FFFFFF",
      "surfaceDim": "#D3DBE0",
      "surfaceBright": "#FFFFFF",
      "onSurface": "#121C23",
      "onSurfaceVariant": "#44525D",
      "outline": "#6A7984",
      "outlineVariant": "#C4CDD4",
      "inverseSurface": "#26323A",
      "onInverseSurface": "#EAF0F3",
      "primary": "#0F5A6A",
      "onPrimary": "#FFFFFF",
      "primaryContainer": "#CFEAF1",
      "onPrimaryContainer": "#00313B",
      "primaryHover": "#0B4957",
      "primaryPressed": "#083A46",
      "inversePrimary": "#7FCBDC",
      "secondary": "#475B67",
      "onSecondary": "#FFFFFF",
      "secondaryContainer": "#DCE6EC",
      "onSecondaryContainer": "#122630",
      "tertiary": "#54559A",
      "onTertiary": "#FFFFFF",
      "tertiaryContainer": "#E4E3FB",
      "onTertiaryContainer": "#1B1C5A",
      "error": "#B3261E",
      "onError": "#FFFFFF",
      "errorContainer": "#FEE9E6",
      "onErrorContainer": "#810109",
      "inverseError": "#FFB4AB",
      "focusRing": "#0F5A6A"
    },
    "dark": {
      "canvas": "#0D1418",
      "card": "#131C21",
      "cardSubtle": "#1A252B",
      "raised": "#1F2B32",
      "pressedFill": "#2A3943",
      "surfaceContainerLowest": "#090F12",
      "surfaceDim": "#0D1418",
      "surfaceBright": "#2E3E47",
      "onSurface": "#E3EAEE",
      "onSurfaceVariant": "#AEBDC6",
      "outline": "#80929D",
      "outlineVariant": "#33444E",
      "inverseSurface": "#E3EAEE",
      "onInverseSurface": "#1A252B",
      "primary": "#7FCBDC",
      "onPrimary": "#00323C",
      "primaryContainer": "#0F4B59",
      "onPrimaryContainer": "#C9EBF3",
      "primaryHover": "#9AD8E6",
      "primaryPressed": "#B4E3EE",
      "inversePrimary": "#0F5A6A",
      "secondary": "#B2C6D1",
      "onSecondary": "#1B2F39",
      "secondaryContainer": "#2F4350",
      "onSecondaryContainer": "#D3E3EC",
      "tertiary": "#BFC0F5",
      "onTertiary": "#26276B",
      "tertiaryContainer": "#3C3D82",
      "onTertiaryContainer": "#E2E1FF",
      "error": "#FFB4AB",
      "onError": "#690005",
      "errorContainer": "#511815",
      "onErrorContainer": "#FEC9C1",
      "inverseError": "#B3261E",
      "focusRing": "#7FCBDC"
    }
  },
  "semantic": {
    "feedback": {
      "success": {
        "label": "Success",
        "light": {
          "fg": "#005121",
          "bg": "#DDF6E1",
          "accent": "#158F44"
        },
        "dark": {
          "fg": "#B1E7BB",
          "bg": "#0F371B",
          "accent": "#58B670"
        }
      },
      "warning": {
        "label": "Warning",
        "light": {
          "fg": "#583D00",
          "bg": "#FDECD2",
          "accent": "#9B6E00"
        },
        "dark": {
          "fg": "#F4D299",
          "bg": "#3E2A01",
          "accent": "#CA9423"
        }
      },
      "error": {
        "label": "Error",
        "light": {
          "fg": "#810109",
          "bg": "#FEE9E6",
          "accent": "#D03833"
        },
        "dark": {
          "fg": "#FEC9C1",
          "bg": "#511815",
          "accent": "#F66D62"
        }
      },
      "info": {
        "label": "Info",
        "light": {
          "fg": "#024671",
          "bg": "#E1F1FF",
          "accent": "#057DC5"
        },
        "dark": {
          "fg": "#B6DDFF",
          "bg": "#08304D",
          "accent": "#4BA6EC"
        }
      }
    },
    "category": {
      "electrical": {
        "label": "Electrical",
        "light": {
          "fg": "#4A4401",
          "bg": "#F2F0D6",
          "accent": "#847A01"
        },
        "dark": {
          "fg": "#DFDAA4",
          "bg": "#332F05",
          "accent": "#ABA242"
        }
      },
      "plumbing": {
        "label": "Plumbing / Water / Washroom",
        "light": {
          "fg": "#044B5A",
          "bg": "#DAF4FB",
          "accent": "#02859F"
        },
        "dark": {
          "fg": "#ABE2F2",
          "bg": "#07343E",
          "accent": "#4AADC7"
        }
      },
      "civil": {
        "label": "Civil / Building",
        "light": {
          "fg": "#543D2B",
          "bg": "#F5EDE7",
          "accent": "#8C715D"
        },
        "dark": {
          "fg": "#E5D4C8",
          "bg": "#362B24",
          "accent": "#B29986"
        }
      },
      "furniture": {
        "label": "Furniture",
        "light": {
          "fg": "#2C4D01",
          "bg": "#E7F3DF",
          "accent": "#5F853C"
        },
        "dark": {
          "fg": "#C9E0B7",
          "bg": "#243318",
          "accent": "#87AC6A"
        }
      },
      "cleanliness": {
        "label": "Cleanliness / Sanitation",
        "light": {
          "fg": "#004F38",
          "bg": "#DCF6E9",
          "accent": "#098D66"
        },
        "dark": {
          "fg": "#AFE6CD",
          "bg": "#0C3627",
          "accent": "#54B48E"
        }
      },
      "it": {
        "label": "IT / Network / Projector / Computer",
        "light": {
          "fg": "#32348C",
          "bg": "#EAEEFE",
          "accent": "#616CCE"
        },
        "dark": {
          "fg": "#CCD5FF",
          "bg": "#252A4F",
          "accent": "#8896F1"
        }
      },
      "safety": {
        "label": "Safety",
        "light": {
          "fg": "#7A014B",
          "bg": "#FEE8F0",
          "accent": "#C13D82"
        },
        "dark": {
          "fg": "#FFC4DC",
          "bg": "#4B1932",
          "accent": "#E86FA9"
        }
      },
      "other": {
        "label": "Other",
        "light": {
          "fg": "#39444C",
          "bg": "#EBEFF2",
          "accent": "#6D7982"
        },
        "dark": {
          "fg": "#D1D9DE",
          "bg": "#2A2E32",
          "accent": "#95A0A9"
        }
      }
    },
    "priority": {
      "critical": {
        "label": "Critical",
        "light": {
          "fg": "#FFFFFF",
          "bg": "#B7191C",
          "accent": "#B7191C"
        },
        "dark": {
          "fg": "#3D0A08",
          "bg": "#FDA297",
          "accent": "#FDA297"
        }
      },
      "high": {
        "label": "High",
        "light": {
          "fg": "#663301",
          "bg": "#FFEADC",
          "accent": "#B35D04"
        },
        "dark": {
          "fg": "#FECCA9",
          "bg": "#482201",
          "accent": "#E18438"
        }
      },
      "medium": {
        "label": "Medium",
        "light": {
          "fg": "#583D02",
          "bg": "#FDECD1",
          "accent": "#9B6E04"
        },
        "dark": {
          "fg": "#F5D297",
          "bg": "#3E2A00",
          "accent": "#CB9318"
        }
      },
      "low": {
        "label": "Low",
        "light": {
          "fg": "#2E4654",
          "bg": "#E8F0F5",
          "accent": "#617C8C"
        },
        "dark": {
          "fg": "#CADAE4",
          "bg": "#252F36",
          "accent": "#89A3B2"
        }
      }
    },
    "status": {
      "reported": {
        "label": "Reported",
        "light": {
          "fg": "#3B434C",
          "bg": "#ECEFF2",
          "accent": "#6F7983"
        },
        "dark": {
          "fg": "#D2D8DF",
          "bg": "#2A2E32",
          "accent": "#96A0A9"
        }
      },
      "reviewed": {
        "label": "Reviewed",
        "light": {
          "fg": "#23388D",
          "bg": "#E8EEFF",
          "accent": "#5270CF"
        },
        "dark": {
          "fg": "#C7D7FE",
          "bg": "#1F2C50",
          "accent": "#7A9AF2"
        }
      },
      "assigned": {
        "label": "Assigned",
        "light": {
          "fg": "#53297A",
          "bg": "#F3EAFE",
          "accent": "#8B5FB9"
        },
        "dark": {
          "fg": "#E2CCFF",
          "bg": "#352547",
          "accent": "#B189DD"
        }
      },
      "inProgress": {
        "label": "In Progress",
        "light": {
          "fg": "#024964",
          "bg": "#DCF3FF",
          "accent": "#0182B0"
        },
        "dark": {
          "fg": "#A9E0FE",
          "bg": "#023246",
          "accent": "#23ACE3"
        }
      },
      "resolved": {
        "label": "Resolved",
        "light": {
          "fg": "#004E45",
          "bg": "#D9F6F0",
          "accent": "#018B7C"
        },
        "dark": {
          "fg": "#A7E6DB",
          "bg": "#033630",
          "accent": "#3CB4A3"
        }
      },
      "verified": {
        "label": "Verified",
        "light": {
          "fg": "#02511D",
          "bg": "#DEF6E0",
          "accent": "#228E40"
        },
        "dark": {
          "fg": "#B3E7B9",
          "bg": "#113719",
          "accent": "#5DB56D"
        }
      },
      "closed": {
        "label": "Closed",
        "light": {
          "fg": "#FFFFFF",
          "bg": "#373E45",
          "accent": "#373E45"
        },
        "dark": {
          "fg": "#13161A",
          "bg": "#CCD2D7",
          "accent": "#CCD2D7"
        }
      }
    }
  },
  "typography": {
    "display-lg": {
      "family": "Archivo",
      "size": 44,
      "lineHeight": 52,
      "weight": 700,
      "letterSpacing": -0.5,
      "flutterSlot": "displayLarge"
    },
    "display-md": {
      "family": "Archivo",
      "size": 36,
      "lineHeight": 44,
      "weight": 700,
      "letterSpacing": -0.25,
      "flutterSlot": "displayMedium"
    },
    "display-sm": {
      "family": "Archivo",
      "size": 30,
      "lineHeight": 38,
      "weight": 700,
      "letterSpacing": 0,
      "flutterSlot": "displaySmall"
    },
    "headline-lg": {
      "family": "Archivo",
      "size": 26,
      "lineHeight": 34,
      "weight": 700,
      "letterSpacing": 0,
      "flutterSlot": "headlineLarge"
    },
    "headline-md": {
      "family": "Archivo",
      "size": 22,
      "lineHeight": 30,
      "weight": 600,
      "letterSpacing": 0,
      "flutterSlot": "headlineMedium"
    },
    "headline-sm": {
      "family": "Archivo",
      "size": 20,
      "lineHeight": 28,
      "weight": 600,
      "letterSpacing": 0,
      "flutterSlot": "headlineSmall"
    },
    "title-lg": {
      "family": "Archivo",
      "size": 18,
      "lineHeight": 26,
      "weight": 600,
      "letterSpacing": 0,
      "flutterSlot": "titleLarge"
    },
    "title-md": {
      "family": "Archivo",
      "size": 16,
      "lineHeight": 24,
      "weight": 600,
      "letterSpacing": 0.1,
      "flutterSlot": "titleMedium"
    },
    "title-sm": {
      "family": "Archivo",
      "size": 14,
      "lineHeight": 20,
      "weight": 600,
      "letterSpacing": 0.1,
      "flutterSlot": "titleSmall"
    },
    "body-lg": {
      "family": "Public Sans",
      "size": 16,
      "lineHeight": 24,
      "weight": 400,
      "letterSpacing": 0.1,
      "flutterSlot": "bodyLarge"
    },
    "body-md": {
      "family": "Public Sans",
      "size": 14,
      "lineHeight": 20,
      "weight": 400,
      "letterSpacing": 0.1,
      "flutterSlot": "bodyMedium"
    },
    "body-sm": {
      "family": "Public Sans",
      "size": 12,
      "lineHeight": 16,
      "weight": 400,
      "letterSpacing": 0.2,
      "flutterSlot": "bodySmall"
    },
    "caption": {
      "family": "Public Sans",
      "size": 12,
      "lineHeight": 16,
      "weight": 400,
      "letterSpacing": 0.2,
      "flutterSlot": "bodySmall (alias)"
    },
    "label-lg": {
      "family": "Archivo",
      "size": 14,
      "lineHeight": 20,
      "weight": 600,
      "letterSpacing": 0.1,
      "flutterSlot": "labelLarge"
    },
    "label-md": {
      "family": "Archivo",
      "size": 12,
      "lineHeight": 16,
      "weight": 600,
      "letterSpacing": 0.3,
      "flutterSlot": "labelMedium"
    },
    "label-sm": {
      "family": "Archivo",
      "size": 11,
      "lineHeight": 16,
      "weight": 600,
      "letterSpacing": 0.5,
      "flutterSlot": "labelSmall"
    },
    "overline": {
      "family": "Archivo",
      "size": 11,
      "lineHeight": 16,
      "weight": 700,
      "letterSpacing": 1.0,
      "flutterSlot": "custom TextStyle",
      "uppercase": true
    },
    "mono-lg": {
      "family": "JetBrains Mono",
      "size": 24,
      "lineHeight": 32,
      "weight": 600,
      "letterSpacing": -0.2,
      "flutterSlot": "custom (monoLarge)"
    },
    "mono-md": {
      "family": "JetBrains Mono",
      "size": 14,
      "lineHeight": 20,
      "weight": 500,
      "letterSpacing": 0,
      "flutterSlot": "custom (monoMedium)"
    },
    "mono-sm": {
      "family": "JetBrains Mono",
      "size": 12,
      "lineHeight": 16,
      "weight": 500,
      "letterSpacing": 0,
      "flutterSlot": "custom (monoSmall)"
    }
  },
  "spacing": {
    "space-0": 0,
    "space-1": 4,
    "space-2": 8,
    "space-3": 12,
    "space-4": 16,
    "space-5": 20,
    "space-6": 24,
    "space-8": 32,
    "space-10": 40,
    "space-12": 48,
    "space-16": 64
  },
  "radii": {
    "r0": 0,
    "r1": 2,
    "r2": 4,
    "r3": 6,
    "r4": 8,
    "r5": 12,
    "r6": 16,
    "full": 999
  },
  "elevation": {
    "light": {
      "e1": [
        {
          "dy": 1,
          "blur": 2,
          "spread": 0,
          "color": "rgb(15 30 40 / .08)"
        }
      ],
      "e2": [
        {
          "dy": 2,
          "blur": 6,
          "spread": 0,
          "color": "rgb(15 30 40 / .12)"
        },
        {
          "dy": 1,
          "blur": 2,
          "spread": 0,
          "color": "rgb(15 30 40 / .08)"
        }
      ],
      "e3": [
        {
          "dy": 8,
          "blur": 24,
          "spread": 0,
          "color": "rgb(15 30 40 / .16)"
        },
        {
          "dy": 2,
          "blur": 6,
          "spread": 0,
          "color": "rgb(15 30 40 / .10)"
        }
      ],
      "e4": [
        {
          "dy": 12,
          "blur": 32,
          "spread": 0,
          "color": "rgb(15 30 40 / .22)"
        },
        {
          "dy": 4,
          "blur": 10,
          "spread": 0,
          "color": "rgb(15 30 40 / .12)"
        }
      ]
    },
    "dark": {
      "e1": [
        {
          "dy": 1,
          "blur": 2,
          "spread": 0,
          "color": "rgb(0 0 0 / .40)"
        }
      ],
      "e2": [
        {
          "dy": 2,
          "blur": 6,
          "spread": 0,
          "color": "rgb(0 0 0 / .45)"
        },
        {
          "dy": 1,
          "blur": 2,
          "spread": 0,
          "color": "rgb(0 0 0 / .30)"
        }
      ],
      "e3": [
        {
          "dy": 8,
          "blur": 24,
          "spread": 0,
          "color": "rgb(0 0 0 / .55)"
        },
        {
          "dy": 2,
          "blur": 6,
          "spread": 0,
          "color": "rgb(0 0 0 / .35)"
        }
      ],
      "e4": [
        {
          "dy": 12,
          "blur": 32,
          "spread": 0,
          "color": "rgb(0 0 0 / .65)"
        },
        {
          "dy": 4,
          "blur": 10,
          "spread": 0,
          "color": "rgb(0 0 0 / .40)"
        }
      ]
    }
  },
  "scrim": {
    "light": "#000000 @ 40%",
    "dark": "#000000 @ 60%"
  },
  "motion": {
    "durationsMs": {
      "instant": 0,
      "fast": 100,
      "base": 150,
      "moderate": 250,
      "slow": 350,
      "deliberate": 500,
      "shimmer": 1400
    },
    "easings": {
      "standard": [
        0.2,
        0.0,
        0.0,
        1.0
      ],
      "enter": [
        0.05,
        0.7,
        0.1,
        1.0
      ],
      "exit": [
        0.3,
        0.0,
        0.8,
        0.15
      ],
      "linear": [
        0.0,
        0.0,
        1.0,
        1.0
      ]
    }
  },
  "stateLayers": {
    "hover": 0.08,
    "focus": 0.1,
    "pressed": 0.12,
    "dragged": 0.16,
    "disabledContent": 0.38,
    "disabledContainer": 0.12
  },
  "focusRing": {
    "width": 2,
    "offset": 2
  },
  "iconSizes": [
    16,
    20,
    24,
    32,
    40,
    48
  ],
  "layout": {
    "minTouchTarget": 48,
    "minPointerTarget": 32,
    "controlHeight": {
      "mobile": 48,
      "admin": 40,
      "dense": 32
    },
    "appBarHeight": {
      "mobile": 56,
      "admin": 64
    },
    "bottomNavHeight": 64,
    "sideNavWidth": {
      "expanded": 240,
      "rail": 72
    },
    "gutter": {
      "compact": 16,
      "medium": 24,
      "expanded": 24
    },
    "contentMaxWidth": 1280,
    "dialogMaxWidth": {
      "mobile": 420,
      "admin": 560
    },
    "photoTile": 100,
    "maxPhotos": 5,
    "breakpoints": {
      "compact": 0,
      "medium": 600,
      "expanded": 1024
    }
  }
}
```
