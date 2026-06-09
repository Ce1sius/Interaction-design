# PathMate DESIGN.md

## Project-Specific Overrides

PathMate is a SwiftUI iOS prototype for university students who need to connect career goals, course learning, assignments, review tasks, personal events, and Agent-based schedule adjustment. The second prototype revision shifts the product from a generic task dashboard into a schedule-first student workspace inspired by Celechron's page structure: calendar at the center, daily agenda below, course learning details one tap away.

Celechron is used only as an interaction and layout reference. Do not copy its brand assets, code, or exact visual identity.

## Product Principles

- Make the schedule the home base: users should immediately see the month/week context and the selected day's courses/tasks.
- Keep Agent decisions inspectable: every adjustment must show what conflicted, which item had lower priority, and what the proposed new time is.
- Keep human control: Agent suggestions always provide accept, manual edit, and reject actions.
- Use local simulated data only: real school systems, OCR, AI, and courseware downloads are represented with realistic mock interactions.
- Support a unified app-wide appearance: follow system, light, and dark modes apply to every screen, not only the calendar.

## Information Architecture

Bottom tabs:

- `接下来`: only the next 24 hours of courses, DDLs, review tasks, personal events, and a concise Agent reminder. Content is split into `正在进行` and `之后的安排`.
- `日程`: selected-day schedule home. It contains a collapsible calendar, selected-day agenda, add-event action, today action, and a navigation entry to the independent weekly timetable page.
- `任务`: all tasks and Agent suggestions. Accept, modify, reject, complete, postpone, edit, and delete are managed here.
- `学业`: course list, quick course todo creation, course detail, materials, homework, and study aid.
- `设置`: personal information, school, goal/habit settings, appearance mode, and local data controls.

## Themes

### Light Theme

- Canvas: `#ffffff`
- Soft Canvas: `#fafaf9`
- Surface: `#f6f5f4`
- Raised Surface: `#ffffff`
- Hairline: `#e5e3df`
- Strong Hairline: `#c8c4be`
- Ink: `#1a1a1a`
- Charcoal: `#37352f`
- Slate: `#5d5b54`
- Steel: `#787671`

### Dark Theme

- Canvas: `#050506`
- Soft Canvas: `#000000`
- Surface: `#1c1c1e`
- Raised Surface: `#242426`
- Hairline: `#343438`
- Strong Hairline: `#4a4a50`
- Ink: `#f7f7f8`
- Charcoal: `#f1f1f3`
- Slate: `#c7c7cc`
- Steel: `#9b9ba1`

### Shared Accents

- Primary Blue: `#2488ff`
- Course Red: `#ff453a`
- Assignment Yellow: `#ffcc00`
- Review Green: `#8ee84f`
- Personal Blue: `#2488ff`
- Goal Cyan: `#32d6d3`
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
- Do not implement real school login, real AI calls, real OCR, or real downloads in this prototype.
