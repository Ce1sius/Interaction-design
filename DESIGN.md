# PathMate DESIGN.md

## Current UI Refresh Direction

PathMate is now a real course-learning companion for ZJU students: schedule planning, course pages, imported courseware, dynamic mind maps, practice resources, and the floating Mate agent must feel like one coherent learning workspace. The active visual direction is **Cool Focused Study System**: Linear-inspired blue-gray precision, Apple-native iOS controls, and compact academic information density.

Use this section as the current source of truth for UI beautification. Older sections below remain useful for schedule/product context, but this section supersedes them when there is a conflict.

### Design Intent

- Make learning feel calm and inspectable: courseware, mind-map nodes, generated examples, and Mate suggestions should show where they came from and what the next action is.
- Keep the app operational, not promotional: every screen opens directly into usable study, schedule, or course functions.
- Treat Mate as a helpful ambient presence: visible, lightweight, never blocking core controls, and visually tied to AI assistance rather than generic decoration.
- Preserve student workflow continuity: importing courseware, previewing material, expanding a mind map, and entering practice should feel like one continuous path.
- Support real backend features safely: API keys stay backend-only, local/network errors are visible, and failed generation never silently falls back to fake success.

### Visual Mood

- Cool, focused, precise, and quietly helpful.
- Prefer pale blue-gray canvas, white or frosted raised surfaces, crisp hairlines, and restrained shadows.
- Use indigo-blue for primary actions and AI/Mate moments; use cyan sparingly for generated insights and learning progress.
- Keep warmth only in small semantic states such as warnings or assignment deadlines.
- Avoid heavy glassmorphism, purple gradients, beige/cream-heavy pages, oversized marketing heroes, and decorative blobs.

### Active Palette

- Canvas: `#F8FAFC`
- Soft Canvas: `#EFF4F8`
- Surface: `#FFFFFF`
- Surface Soft: `#E8EEF5`
- Raised Surface: `#FFFFFF`
- Hairline: `#D8E0EA`
- Strong Hairline: `#B8C4D2`
- Ink: `#111827`
- Charcoal: `#1F2937`
- Slate: `#536170`
- Steel: `#7B8794`
- Primary Blue: `#2563EB`
- Primary Pressed: `#1D4ED8`
- Study Indigo: `#5E6AD2`
- Study Indigo Pressed: `#4651B8`
- Agent Cyan: `#0EA5E9`
- Agent Cyan Pressed: `#0284C7`
- Course Red: `#FF453A`
- Assignment Yellow: `#FFCC00`
- Review Green: `#22C55E`
- Goal Cyan: `#06B6D4`
- Warning Orange: `#FF9F0A`
- Success Green: `#30D158`

Dark mode should stay native and practical: near-black blue canvas, raised charcoal cards, visible separators, and the same semantic accents at slightly reduced saturation.

### Typography

Use SF Pro / SwiftUI system fonts throughout. Do not introduce web display fonts into the iOS app.

- Screen title: 26-30 pt, semibold.
- Section title: 17-20 pt, semibold.
- Card title: 16-18 pt, semibold.
- Body: 15-16 pt, regular.
- Dense body and metadata: 12-14 pt, regular or medium.
- Buttons: 14-16 pt, semibold.
- Letter spacing: `0`.

Chinese text should prefer readable line height and wrapping over truncation. Truncate only metadata, course locations, or labels where the destination is still obvious.

### Layout And Density

- Root pages use full-width backgrounds, not a stack of floating outer cards.
- Use cards for repeated objects, modals, previews, and framed tools. Avoid nested decorative cards.
- Main horizontal padding: 16 pt.
- Dense dashboards: 10-14 pt vertical gaps.
- Course detail and study pages: 14-18 pt vertical gaps.
- Card radius: 10-14 pt. Use 16 pt only for major preview panels or Mate surfaces.
- Hairlines should do most separation work; shadows stay subtle.
- Minimum tap target: 44 pt, except the minimized Mate affordance may be visually smaller while retaining a tappable frame.

### Navigation

Bottom tabs are currently:

- `接下来`: next 24 hours and active/near-start items.
- `日程`: calendar, selected-day agenda, add schedule, timetable.
- `学业`: course list, course detail, courseware, and the only entry to mind-map learning through `辅学`.
- `设置`: profile, preferences, appearance, and data controls.

Do not restore a bottom `图谱` tab. Mind-map learning is contextual and should be entered from `学业 -> 辅学`.

### Key Screens

#### Next Up

- Use one calm focus card for the current or next item.
- Keep `之后的安排` limited to the next 24 hours.
- Time-sensitive items use small countdown chips and a subtle progress indicator, not large alarm styling.

#### Schedule

- Calendar remains the home base for date selection.
- The add-schedule flow must distinguish temporary schedules from long-term fixed schedules.
- Temporary events only affect the selected day and its calendar dot.
- Long-term fixed events start from the chosen date forward; never rewrite past dates.

#### Academics

- Course cards should be scannable: course name, time/location summary, tags, and a clear `辅学` action.
- The `本周作业` section must align to the same width as neighboring sections.
- Course tags support custom additions up to 10 Chinese characters.
- Course detail should keep materials, homework, knowledge, and review actions visually related but not crowded into one mega-card.

#### Courseware Preview

- Preview stays inline inside the courseware preview window when entered from the course aid page.
- The user must always have an obvious way back to the course aid content.
- Preview/download actions should show real loading/error states, including backend or session-expired messages.

#### Dynamic Mind Map

- The mind map canvas is a working area, not an illustration.
- Generated nodes must communicate state: selected, expandable, loading, generated from courseware, or fallback.
- First-level nodes should invite expansion; second-level and practice content should be discoverable without looking like a separate app.
- Node detail pages should include concept explanation, common mistake, guided example, practice question, answer, and source/courseware context when available.

#### Mate Agent

- Mate should sit above normal app content without duplicating itself across navigation pushes.
- Minimized Mate belongs in the top-left safe area, small enough not to block back buttons or page titles.
- Adult minimized state uses `MateAdultSleep`; child minimized state uses `MateChildSleep`.
- Schedule planning uses the thinking posture (`MateAdultThink` for adult mode).
- Tap state should persist intentionally: tapping Mate can change from tilt to wink while active, instead of flashing wink and immediately returning to tilt.

### Component Rules

- Primary buttons: filled blue or indigo for irreversible/next-step actions; Mate/AI actions use indigo or cyan instead of coral.
- Secondary buttons: soft surface with hairline border.
- Segmented controls: use system style, but place them in compact headers.
- Chips/tags: small radius, light tint, readable text; custom course tags must look editable but not loud.
- Toasts: concise, top or bottom safe-area aware, never covering Mate and critical navigation at the same time.
- Error panels: friendly but specific. Include HTTP status and backend detail when available.

### Motion

- Use short spring transitions for expand/collapse and mind-map focus changes.
- Preserve spatial continuity when moving from mind map to node detail.
- Use reduced-motion fallbacks for Mate idle movement, particles, and large panel transitions.
- Avoid abrupt sheet swaps for inline preview; preview should transform within its existing region.

### Implementation Map

- Global colors and card style: `app1/PathMateTheme.swift`.
- Shared buttons, cards, chips, and toasts: `app1/PathMateComponents.swift`.
- Main navigation and schedule/academics/settings screens: `app1/PathMateScreens.swift`.
- Courseware, mind map, node detail, preview behavior: `app1/AlgorithmMindMapScreen.swift`, `app1/MindMapCanvasView.swift`, `app1/KnowledgeDetailPanel.swift`.
- Mate visual and overlay behavior: `app1/Features/Mate/Views`, `app1/Features/Mate/ViewModels`, `app1/Features/Mate/Rendering`.

### Anti-Patterns For This Revision

- Do not add a separate floating Mate overlay for each pushed page.
- Do not make preview open as a detached window when the user is inside the course aid page.
- Do not hide backend failures behind default mock mind maps.
- Do not place API keys in the iOS app bundle.
- Do not use large dark media placeholders when real courseware previews are available.
- Do not make every section a card; use layout, spacing, and dividers first.
- Do not overuse warm cream, tan, orange, or coral as the dominant learning background.

## Project-Specific Overrides

PathMate is a SwiftUI iOS prototype for university students who need to connect career goals, course learning, assignments, review tasks, personal events, and Agent-based schedule adjustment. The second prototype revision shifts the product from a generic task dashboard into a schedule-first student workspace inspired by Celechron's page structure: calendar at the center, daily agenda below, course learning details one tap away.

Celechron is used only as an interaction and layout reference. Do not copy its brand assets, code, or exact visual identity.

## Product Principles

- Make the schedule the home base: users should immediately see the month/week context and the selected day's courses/tasks.
- Keep Agent decisions inspectable: every adjustment must show what conflicted, which item had lower priority, and what the proposed new time is.
- Keep human control: Agent suggestions always provide accept, manual edit, and reject actions.
- Prefer realistic, inspectable data states: real school sessions, AI calls, and courseware downloads must show loading/error/session-expired states clearly; sample data remains acceptable only as fallback or demo content.
- Support a unified app-wide appearance: follow system, light, and dark modes apply to every screen, not only the calendar.

## Legacy Information Architecture Notes

Historical bottom-tab notes from the earlier schedule-first prototype:

- `接下来`: only the next 24 hours of courses, DDLs, review tasks, personal events, and a concise Agent reminder. Content is split into `正在进行` and `之后的安排`.
- `日程`: selected-day schedule home. It contains a collapsible calendar, selected-day agenda, add-event action, today action, and a navigation entry to the independent weekly timetable page.
- `任务`: all tasks and Agent suggestions. Accept, modify, reject, complete, postpone, edit, and delete are managed here.
- `学业`: course list, quick course todo creation, course detail, materials, homework, and study aid.
- `设置`: personal information, school, goal/habit settings, appearance mode, and local data controls.

## Themes

### Light Theme

- Canvas: `#ffffff`
- Soft Canvas: `#f8fafc`
- Surface: `#eef4f8`
- Raised Surface: `#ffffff`
- Hairline: `#d8e0ea`
- Strong Hairline: `#b8c4d2`
- Ink: `#111827`
- Charcoal: `#1f2937`
- Slate: `#536170`
- Steel: `#7b8794`

### Dark Theme

- Canvas: `#020617`
- Soft Canvas: `#050a18`
- Surface: `#0f172a`
- Raised Surface: `#111827`
- Hairline: `#1e293b`
- Strong Hairline: `#334155`
- Ink: `#f8fafc`
- Charcoal: `#e5edf6`
- Slate: `#cbd5e1`
- Steel: `#94a3b8`

### Shared Accents

- Primary Blue: `#2563eb`
- Study Indigo: `#5e6ad2`
- Agent Cyan: `#0ea5e9`
- Course Red: `#ff453a`
- Assignment Yellow: `#ffcc00`
- Review Green: `#22c55e`
- Personal Blue: `#2563eb`
- Goal Cyan: `#06b6d4`
- Conflict Red: `#ff453a`
- Warning Orange: `#ff9f0a`
- Success Green: `#30d158`

## Typography

Use SwiftUI system typography:

- Large screen title: 28-30 pt, bold or semibold.
- Major card title: 22-24 pt, semibold.
- Card title: 17-19 pt, semibold/bold.
- Body: 15-16 pt, regular.
- Metadata: 13-14 pt, regular or medium.
- Button: 14-15 pt, semibold.

Letter spacing remains `0`. Avoid viewport-scaled text.

## Layout Rules

- Page background: `PMColor.softCanvas`.
- Cards: `PMColor.surfaceRaised`, 14-18 pt radius, 1 pt hairline, subtle shadow.
- Main content padding: 16 pt.
- Card inner padding: 14-18 pt.
- Section gap: 14-18 pt.
- Minimum tap target: 44 pt.
- Do not nest cards inside decorative cards. Use soft bands or dividers for inner grouping.

## Key Screens

### Onboarding

- Launch page is independent from setup steps.
- Setup flow: user profile, learning preferences, course import, completion.
- Grade is selected from fixed options.
- School uses text input plus search suggestions, not a static dropdown. Typing a keyword such as `浙江` shows local mock candidates including `浙江大学`, `浙江工业大学`, `浙江理工大学`, and similar schools. Tapping a candidate fills the field.
- Development goal has exactly three options: `考研`, `保研`, `就业`. 科研和竞赛只作为后续任务或实现手段，不作为长期目标分类。
- Learning habit and planning detail must show explanatory info boxes.
- Import page shows real future methods: school system authorization, iCal subscription, table/screenshot recognition, manual entry.
- Completion page confirms setup state instead of re-explaining the whole product.
- Step transitions are directional: tapping continue advances with a forward slide/fade, while tapping previous returns with the opposite slide/fade.

### Next Up

- Show only tasks within the next 24 hours, plus the current in-progress task if one exists.
- `正在进行`: when local time is inside an item start/end range, show that item with remaining-time countdown and a progress bar.
- If nothing is currently in progress, the first upcoming item becomes the focus card and shows time until start.
- `之后的安排`: list the rest of the next-24-hour items in chronological order.
- Items beginning within 20 minutes show a countdown and near-start progress indicator.

### Schedule

- Header shows current month, selected weekday, and a compact right-side action group: `+`, `今天`, and timetable icon.
- Do not include duplicate large `今天 / 月历` buttons below the header.
- Calendar defaults to the current selected week as a single row.
- Tapping the calendar handle or dragging down expands to the full month calendar; tapping again or dragging up collapses back to the selected week row.
- Full month and week row both use seven columns and colored dots under each date to represent task categories.
- Selected date uses primary blue circular highlight.
- Agenda cards show colored type dot, title, time, location, and a chevron.
- Tapping a course or course assignment opens course detail. Assignments highlight the homework section.
- Tapping a non-course event opens a generic event detail page.
- The timetable icon pushes a new `CourseTimetableView` page instead of toggling an inline schedule.

### Weekly Timetable

- Independent page title: `25-26春夏 夏学期`.
- Layout uses a horizontal scrollable grid: left time axis for class periods 1-13 and seven weekday columns from Monday to Sunday.
- Course blocks are placed by existing course weekday/start/end time, use blue-toned filled rectangles, and show course name plus location.
- Tapping a course block opens the same course detail route used by schedule agenda cards.
- The timetable is a view of imported/manual course data, not a separate task list editor.

### Task Hub

- Agent suggestions appear above the task list.
- Suggestion cards must show status, reason toggle, proposed schedule, and accept/modify/reject controls.
- Task cards support complete, postpone, long-press edit, context delete, and visible conflict records.

### Academics

- Course card includes a plus action for course-related todo creation.
- Course detail includes tags, course note, expandable material summary, materials list entry, weekly homework, knowledge grid, and review task generation.
- Materials page displays mock materials and supports simulated preview/download feedback.
- Study aid page shows concept explanation, typical example, review advice, and mock resource recommendation.

### Settings

- Personal information includes school, grade, major, and development goal.
- Goal is visible as stable profile information, with edits placed in the settings controls.
- Appearance selector supports follow system, light, and dark.
- Data controls include restore sample data, restart onboarding, and clear local data.

## Motion and Feedback

- Onboarding transitions slide/fade between steps, with next and previous moving in opposite directions.
- Date selection and view switching use spring animation.
- Calendar expansion/collapse uses a spring animation and supports tap plus vertical drag gestures.
- Agent regeneration uses a loading indicator.
- Toast feedback appears after saves, downloads, deletions, task changes, and appearance changes.
- Conflict suggestions appear as a sheet immediately after adding an overlapping event.

## Data Concepts

- `UserProfile`: grade, school, major, career goal, learning habit, planning detail, appearance mode.
- `CareerGoal`: exactly `考研`, `保研`, `就业`.
- `Course`: base schedule, tags, goal relation, note, summary, homework, materials, and study topics.
- `PlanTask`: task type, associated course/homework, schedule, priority, Agent flag, movable flag, status, note, conflict source.
- `PersonalEvent`: custom non-course schedule item linked to a task.
- `AgentSuggestion`: proposed task/time change, reason, affected task, and status.
- `CourseMaterial`: mock courseware item with preview/download status.
- `CourseHomework`: weekly homework shown in course detail.
- `StudyAidTopic`: mock study aid content.
- `ClassPeriod`: fixed period table for rendering the weekly timetable, covering periods 1-13.

## Anti-Patterns

- Do not return to separate Today and Week Plan tabs.
- Do not make Agent a chat-only surface.
- Do not let theme choice affect only one page.
- Do not hide conflict reasoning.
- Do not put credentials or API keys in the iOS app bundle; real school login, AI calls, and downloads must go through safe backend/session boundaries.
