# PathMate DESIGN.md

## Product Positioning

PathMate is a SwiftUI iOS prototype for university students who need to connect long-term development goals, course learning, assignments, review tasks, personal events, and Agent-based schedule adjustment. The UI direction is a warm, restrained, task-dense learning workspace: readable like a knowledge tool, efficient like a schedule dashboard, and expressive enough to make the Mate Agent feel present.

The visual reference is Notion-style warm neutral workspace design, adapted for iOS and PathMate's own learning-agent semantics. Do not copy Notion brand assets, logos, proprietary illustrations, or exact visual identity. Use the reference only for warmth, card hierarchy, reading comfort, and low-distraction information density.

## Design Principles

- Make the schedule the operational home base: users should immediately understand what is happening now, what comes next, and what needs attention.
- Make learning structure visible: course details and study-aid flows should show how materials, knowledge points, practice, and review records connect.
- Keep Agent decisions inspectable: every recommendation must expose its reason, affected task, proposed time, and human choices.
- Keep human control explicit: Agent suggestions always provide accept, modify, and reject pathways.
- Keep Mate useful, not decorative: Mate signals Agent presence and feedback, but must not block core navigation or primary actions.
- Preserve iOS familiarity: use SwiftUI-native controls, SF Symbols, system typography, clear tap targets, and predictable sheets/navigation.

## Color System

Use semantic tokens in `PMColor` instead of raw colors in view code.

### Neutral Surfaces

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `canvas` | `#FFFFFF` | `#050506` | Highest-contrast blank surfaces and graph interiors |
| `softCanvas` | `#FAFAF9` | `#000000` | App/page background |
| `surface` | `#F6F5F4` | `#1C1C1E` | Inner grouped areas, subtle bands |
| `surfaceRaised` | `#FFFFFF` | `#242426` | Cards, sheets, floating panels |
| `hairline` | `#E5E3DF` | `#343438` | Default 1 pt borders and dividers |
| `strongHairline` | `#C8C4BE` | `#4A4A50` | Inputs, selected/hover-equivalent boundaries |

### Text

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `ink` | `#1A1A1A` | `#F7F7F8` | Main titles and primary text |
| `charcoal` | `#37352F` | `#F1F1F3` | Card titles and body emphasis |
| `slate` | `#5D5B54` | `#C7C7CC` | Secondary body text |
| `steel` | `#787671` | `#9B9BA1` | Metadata and tertiary labels |
| `muted` | `#BBB8B1` | `#6C6C72` | Disabled controls and quiet icons |

### Action and Status

| Token | Hex | Use |
| --- | --- | --- |
| `primary` | `#2488FF` | Primary action, selected date, selected graph node, Agent action |
| `primaryPressed` | `#0B66D8` | Pressed primary state |
| `linkBlue` | `#2488FF` | Inline links and secondary navigation actions |
| `course` | `#FF453A` | Course blocks and course task dots |
| `assignment` | `#FFCC00` | Assignments and deadlines |
| `review` | `#8EE84F` | Review tasks and practice completion |
| `personal` | `#2488FF` | Personal events |
| `goal` | `#32D6D3` | Goal-driven tasks and long-term milestones |
| `conflict` | `#FF453A` | Conflicts, rejection, destructive states |
| `warning` | `#FF9F0A` | Warnings, near-start tasks, postponement |
| `success` | `#30D158` | Completion, accepted suggestions, successful imports |

Rules:

- Blue is the only dominant CTA color.
- `sparkles` and blue glow are reserved for Agent/Mate/intelligent planning.
- Red is for conflict/destructive states, not general emphasis.
- Yellow and green should remain status accents, not large background themes.
- Every new color must have a light and dark-mode treatment unless it is a fixed semantic accent.

## Typography

Use SwiftUI system typography / SF Pro. Keep letter spacing at `0`; do not use negative tracking in the app UI.

| Role | Size | Weight | Use |
| --- | --- | --- | --- |
| Page title | 28-30 | semibold/bold | Main headers such as `接下来`, `日程`, `课程与辅学` |
| Section title | 22-26 | bold/semibold | `正在进行`, `之后的安排`, day agenda, major page groups |
| Card title | 17-18 | semibold | Task, course, suggestion, material and knowledge cards |
| Body | 14-15 | regular | Course summaries, explanations, Agent reasons |
| Metadata | 12-13 | regular/semibold | Time ranges, terms, tags, status labels |
| Button | 14-15 | semibold | Primary and secondary actions |

Chinese text should have comfortable vertical rhythm. Long descriptions should wrap naturally and use `.fixedSize(horizontal: false, vertical: true)` where truncation would hide important reasoning.

## Spacing, Shape, and Elevation

Recommended token layer:

- `PMSpacing.xs = 4`
- `PMSpacing.sm = 8`
- `PMSpacing.md = 12`
- `PMSpacing.lg = 16`
- `PMSpacing.xl = 20`
- `PMSpacing.xxl = 24`

Recommended radius layer:

- `PMRadius.button = 10`
- `PMRadius.card = 14`
- `PMRadius.panel = 16`
- `PMRadius.hero = 20`
- `PMRadius.full = 999`

Recommended elevation layer:

- Level 0: no shadow, 1 pt `hairline`; use for dense inner rows.
- Level 1: subtle card shadow, black opacity around `0.04-0.06`, radius `8-10`, y `2-3`.
- Level 2: floating panels and toasts, black opacity around `0.08-0.12`, radius `12-18`, y `6-8`.
- Level 3: Mate/overlay feedback only, used sparingly.

Layout rules:

- Page background is always `PMColor.softCanvas`.
- Standard content cards use `PMColor.surfaceRaised`, 14 pt radius, 1 pt hairline, and Level 1 elevation.
- Main page padding is 16 pt.
- Card inner padding is 14-18 pt.
- Section gaps are 14-18 pt.
- Minimum tap target is 44 pt.
- Avoid cards nested inside decorative cards. Use soft inner bands, dividers, or rows instead.

## Icon and Asset Style

- Use SF Symbols for controls, status, navigation, and content affordances.
- Use icon wells for important actions: 32-44 pt circle or rounded square with a soft tint background.
- Use `sparkles` only for Agent/Mate/AI-generated suggestions.
- Use course/task colors as small dots, chips, or block fills. Do not fill large unrelated surfaces with task colors.
- Mate character assets are the only mascot-like visual assets. Keep them visually distinct from normal UI controls.

## Core Components

### `PathButton`

- Primary: blue background, white text, 44 pt minimum height, 10 pt radius. Use for continue, confirm, generate, enter, accept.
- Secondary: raised surface, strong hairline, charcoal text. Use for import, add, edit, view, optional actions.
- Ghost: transparent, ink text. Use for quiet navigation or inline panel actions.
- Destructive: transparent or outline, conflict red text. Use for delete, reject, clear local data.
- Press feedback should scale to roughly `0.98` with a short spring.

### `IconButton`

- 42-44 pt circular button.
- Raised surface, hairline border, primary icon color.
- Use for compact actions such as add, refresh, timetable, reset view.

### `TagChip`

- Capsule shape.
- 12 pt semibold text.
- Background uses tint at low opacity.
- Tags should communicate type, priority, status, or course metadata; avoid using tags as decorative fillers.

### `InfoBox`

- Use for explanations, Agent reasoning, import results, conflict records, and setup guidance.
- Icon color and background should follow semantic tint.
- Body text must wrap fully when it contains reasoning or errors.

### `TaskCard`

- Must show type color, title, time, course/location when available, priority/status chips, and key actions.
- Completed tasks reduce opacity but stay readable.
- Conflict records use `InfoBox` with warning/conflict treatment.
- Keep complete/postpone/edit/delete feedback visible through buttons, context menus, sheets, or toast.

### `CourseCard`

- Must show course name, teacher/location, schedule, goal relation, tags, and a clear study-aid entry.
- The study-aid action is a primary small action only when it opens intelligent learning support.
- Avoid making the whole card visually compete with the study-aid CTA.

### `SuggestionCard`

- Must show status, title, proposed schedule, affected task, expandable reason, and accept/modify/reject controls.
- Accepted uses success, rejected uses conflict, pending uses primary.
- Reason text should never be hidden permanently; human-in-the-loop review is a core grading requirement.

### `ToastBanner`

- Top overlay, raised surface, hairline border, Level 2 elevation.
- Use after save, import, delete, download, task completion, schedule generation, and appearance changes.
- Auto-dismiss quickly but allow enough time to read short Chinese messages.

## Screen Guidelines

### Onboarding

- Purpose: quickly establish profile and planning preferences.
- Keep the launch page simple: product name, one-sentence value, one start action.
- Progress should be visible and directional.
- Step transitions should slide/fade forward and backward based on navigation direction.
- School, grade, major, goal, habit, and planning detail should feel like setup controls, not marketing copy.
- Explanatory `InfoBox` components should clarify how choices affect Agent planning.

### Next Up

- Treat this as a high-density execution dashboard.
- Header shows school, strategy, and term context.
- Focus section shows either current task or first upcoming task.
- Later section is chronological and compact.
- Agent reminder/suggestion surfaces should be close to the tasks they affect.
- Near-start and in-progress tasks must show time/progress feedback.

### Schedule

- Schedule is the daily command center.
- Header shows month, selected weekday, count of arrangements, term, plus compact actions.
- Calendar selection uses primary blue.
- Task category dots below dates use the fixed status palette.
- Day agenda cards must make time, type, title, and destination obvious.
- Adding personal events should surface conflict suggestions when relevant.

### Academics and Course Detail

- Treat `学业` as the course library.
- Course list cards should be scannable, with study-aid access and course todo creation.
- Course detail should group tags, summary, materials, homework, knowledge points, and review actions.
- Course materials and homework states should provide simulated but clear feedback.
- Knowledge grids should look like learning pathways, not generic feature tiles.

### Study Aid and Mind Map

- The study-aid flow is: choose knowledge point -> confirm learning -> read explanation/practice/record.
- Resource header should distinguish `课件` and `回放` without visually overwhelming the graph.
- The mind map canvas should feel like an interactive learning tool:
  - Subtle grid on raised surface.
  - Focused branch remains strong.
  - Unfocused branches fade but remain locatable.
  - Selected node uses primary blue and elevated emphasis.
  - Reset view and confirm-learning actions are always clear.
- Knowledge detail cards should prioritize comprehension: overview, core concepts, dynamic diagram entry, practice, FAQ/Agent, and learning record.

### Mate Agent

- Mate represents Agent presence, planning state, and reward feedback.
- Mate should snap to safe edges and avoid the tab bar, primary CTA areas, and sheet content.
- Mate menu actions should stay compact and icon-first: chat, smart planning, minimize.
- Thinking, celebration, growth, and completion states may animate, but motion should respect Reduce Motion.
- Mate should never be the only way to access a core function.

### Settings

- Settings should remain quiet and form-like.
- Profile info, goal, learning habits, appearance, data controls, and backend configuration should be grouped clearly.
- Destructive data actions must use conflict/destructive styling and confirmation where appropriate.

## Gestures and Motion

Required gesture coverage:

- Mind map drag for panning.
- Mind map pinch for zooming.
- Mate drag for floating/snap positioning.
- Long press/context menu on task/course cards for edit/delete operations.
- Calendar drag or tap for expand/collapse when available.

Required animation coverage:

- Onboarding directional page transitions.
- Button press scale feedback.
- Toast move/fade transition.
- Calendar expansion/collapse spring.
- Mind map node insertion/selection transitions.
- Mate snap, idle, thinking, and particle/reward feedback.

Motion rules:

- Prefer spring animations around `0.24-0.42` response and `0.7-0.86` damping.
- Use ease transitions for subtle focus or glow changes.
- Every async action should show loading or disabled state: import, download, preview, Agent generation, backend mind map generation.
- Respect `accessibilityReduceMotion` for Mate idle and celebration effects.

## Accessibility and Responsiveness

- Keep all actionable controls at least 44 pt.
- Text in buttons and cards must not clip on small iPhones; use line limits, wrapping, or minimum scale only for short labels.
- Important reasoning, errors, and summaries should not be permanently truncated.
- Use accessible labels for icon-only buttons.
- Color should not be the only status signal; pair with labels, icons, or chips.
- Verify light/dark mode for every screen.
- Verify iPhone SE, standard iPhone, and large iPhone layouts.

## Submission Rubric Mapping

- Innovation and uniqueness: highlight PathMate's goal-course-time-understanding model, dynamic mind map, and Mate Agent as a perceivable learning companion.
- Value: keep the target user clear: university students with course overload and long-term academic/career goals.
- Basic product parameters: preserve usable CRUD, navigation, persistence, gestures, animations, feedback, and stable SwiftUI flows.
- Submission quality: include this `DESIGN.md`, runnable app source, screen recording/screenshots, task assignment statement, and brief written summary.

## Implementation Notes

- Implement UI improvements incrementally: design tokens first, shared components second, major screens third, visual QA last.
- Do not rewrite backend APIs, course import logic, persistence, or mind map data models for visual polish.
- Do not add real login, real chat, real OCR, real-time collaboration, or App Store publishing requirements for this prototype.
- Do not turn the app into a landing page or marketing surface; the first screen after onboarding should remain the usable product experience.
