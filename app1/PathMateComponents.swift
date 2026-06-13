import SwiftUI

struct PathButton: View {
    enum Style {
        case primary
        case secondary
        case ghost
        case destructive
    }

    var title: String
    var systemImage: String?
    var style: Style = .primary
    var isLoading = false
    var action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor, lineWidth: borderColor == .clear ? 0 : 1)
            }
            .shadow(color: shadowColor, radius: style == .primary ? 12 : 0, x: 0, y: style == .primary ? 6 : 0)
            .scaleEffect(isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.75), value: isPressed)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .white
        case .secondary, .ghost: return PMColor.ink
        case .destructive: return PMColor.conflict
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return PMColor.primary
        case .secondary: return PMColor.surfaceRaised
        case .ghost, .destructive: return .clear
        }
    }

    @ViewBuilder
    private var background: some View {
        if style == .primary {
            LinearGradient(
                colors: [PMColor.primary, PMColor.primaryPressed],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            backgroundColor
        }
    }

    private var shadowColor: Color {
        style == .primary ? PMColor.primary.opacity(0.2) : .clear
    }

    private var borderColor: Color {
        switch style {
        case .secondary: return PMColor.strongHairline
        default: return .clear
        }
    }
}

struct IconButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.primary)
                .frame(width: 42, height: 42)
                .background(PMColor.parchment)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(PMColor.hairline, lineWidth: 1)
                }
                .shadow(color: PMColor.agent.opacity(0.11), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct TagChip: View {
    var title: String
    var systemImage: String?
    var tint: Color

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay {
                    Capsule().stroke(tint.opacity(0.2), lineWidth: 1)
                }
        )
        .clipShape(Capsule())
    }
}

struct InfoBox: View {
    var title: String
    var message: String
    var icon: String = "info.circle.fill"
    var tint: Color = PMColor.primary

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PMColor.charcoal)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(PMColor.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.7))
                        .frame(width: 3)
                        .padding(.vertical, 10)
                }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct TaskCard: View {
    var task: PlanTask
    var courseName: String?
    var compact = false
    var onComplete: () -> Void
    var onPostpone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PMColor.task(task.kind))
                    .frame(width: compact ? 5 : 6, height: compact ? 48 : 58)
                    .shadow(color: PMColor.task(task.kind).opacity(0.28), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .font(.system(size: compact ? 16 : 18, weight: .semibold))
                        .foregroundStyle(task.status == .completed ? PMColor.steel : PMColor.charcoal)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(PathMateTime.rangeString(start: task.startMinute, duration: task.durationMinutes), systemImage: "clock.fill")
                        if let courseName {
                            Text(courseName)
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(PMColor.steel)
                    .lineLimit(1)

                    if !task.note.isEmpty && !compact {
                        Text(task.note)
                            .font(.system(size: 13))
                            .foregroundStyle(PMColor.slate)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    if task.isAgentGenerated {
                        Image(systemName: "sparkles")
                            .foregroundStyle(PMColor.agent)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(PMColor.muted)
                }
            }

            HStack(spacing: 8) {
                TagChip(title: task.kind.rawValue, systemImage: nil, tint: PMColor.task(task.kind))
                TagChip(title: "P\(task.priority)", systemImage: "flag.fill", tint: task.priority >= 4 ? PMColor.warning : PMColor.steel)
                if task.status != .pending {
                    TagChip(title: task.status.rawValue, systemImage: task.status == .completed ? "checkmark" : "clock", tint: task.status == .completed ? PMColor.success : PMColor.warning)
                }
                Spacer(minLength: 0)
            }

            if let conflictSource = task.conflictSource, !compact {
                InfoBox(title: "冲突记录", message: conflictSource, icon: "exclamationmark.triangle.fill", tint: PMColor.warning)
            }

            if !compact {
                HStack(spacing: 10) {
                    Button(action: onComplete) {
                        Label(task.status == .completed ? "已完成" : "完成", systemImage: "checkmark")
                    }
                    .buttonStyle(.bordered)
                    .tint(PMColor.success)
                    .disabled(task.status == .completed)

                    Button(action: onPostpone) {
                        Label("延后", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .tint(PMColor.warning)
                    .disabled(!task.isMovable)

                    Spacer()
                }
                .font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(compact ? 14 : 16)
        .pathPremiumCard(cornerRadius: compact ? 13 : 16)
        .opacity(task.status == .completed ? 0.68 : 1)
        .accessibilityElement(children: .combine)
    }
}

struct CourseCard: View {
    var course: Course
    var onStudyAid: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [PMColor.agent.opacity(0.95), PMColor.primary.opacity(0.84)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)
                .shadow(color: PMColor.agent.opacity(0.18), radius: 12, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PMColor.charcoal)
                    Text("\(course.teacher) · \(course.location)")
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.steel)
                    Text("\(PathMateTime.weekdayName(course.weekday)) \(PathMateTime.rangeString(start: course.startMinute, duration: course.durationMinutes))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(PMColor.ink)
                }

                Spacer()

                if let onStudyAid {
                    Button(action: onStudyAid) {
                        Label("辅学", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [PMColor.agent, PMColor.agentPressed],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: PMColor.agent.opacity(0.24), radius: 10, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("进入课程辅学")
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(PMColor.muted)
                        .padding(.top, 4)
                }
            }

            Text(course.goalRelation)
                .font(.system(size: 13))
                .foregroundStyle(PMColor.slate)
                .lineLimit(2)

            FlowTags(tags: Array(Set([course.academicTerm?.shortName].compactMap { $0 } + course.tags)).sorted(), tint: PMColor.primary)
        }
        .padding(16)
        .pathPremiumCard()
    }
}

struct FlowTags: View {
    var tags: [String]
    var tint: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                TagChip(title: tag, systemImage: nil, tint: tint)
            }
        }
    }
}

struct SuggestionCard: View {
    var suggestion: AgentSuggestion
    var affectedTaskTitle: String?
    var isExpanded: Bool
    var onToggleReason: () -> Void
    var onAccept: () -> Void
    var onModify: () -> Void
    var onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 32, height: 32)
                    .background(statusTint.opacity(0.12))
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(statusTint.opacity(0.2), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PMColor.charcoal)
                        .lineLimit(2)
                    Text(scheduleText)
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.steel)
                }

                Spacer()
                TagChip(title: suggestion.status.rawValue, systemImage: nil, tint: statusTint)
            }

            if let affectedTaskTitle {
                Text("影响任务：\(affectedTaskTitle)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PMColor.slate)
            }

            if isExpanded {
                Text(suggestion.reason)
                    .font(.system(size: 14))
                    .foregroundStyle(PMColor.slate)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 8) {
                Button("查看原因", action: onToggleReason)
                    .buttonStyle(.bordered)
                    .tint(PMColor.primary)

                if suggestion.status == .pending {
                    Button("接受", action: onAccept)
                        .buttonStyle(.borderedProminent)
                        .tint(PMColor.primary)
                    Button("修改", action: onModify)
                        .buttonStyle(.bordered)
                        .tint(PMColor.warning)
                    Button("拒绝", action: onReject)
                        .buttonStyle(.bordered)
                        .tint(PMColor.conflict)
                }
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(16)
        .pathPremiumCard()
    }

    private var statusTint: Color {
        switch suggestion.status {
        case .pending: return PMColor.primary
        case .accepted: return PMColor.success
        case .rejected: return PMColor.conflict
        }
    }

    private var statusIcon: String {
        switch suggestion.status {
        case .pending: return "sparkles"
        case .accepted: return "checkmark"
        case .rejected: return "xmark"
        }
    }

    private var scheduleText: String {
        let title = suggestion.proposedTitle ?? "调整到新时间"
        return "\(title) · \(PathMateTime.weekdayName(suggestion.proposedWeekday)) \(PathMateTime.rangeString(start: suggestion.proposedStartMinute, duration: suggestion.proposedDurationMinutes))"
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(PMColor.agent)
                .frame(width: 56, height: 56)
                .background(PMColor.agent.opacity(0.12))
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text(message)
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundStyle(PMColor.steel)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .pathPremiumCard()
    }
}

struct ToastBanner: View {
    var message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PMColor.success)
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PMColor.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(PMColor.parchment)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PMColor.hairline, lineWidth: 1)
        }
        .shadow(color: PMColor.agent.opacity(0.14), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 16)
    }
}

struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let message {
                ToastBanner(message: message)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation {
                                self.message = nil
                            }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
