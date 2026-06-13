import SwiftUI

struct MateDemoView: View {
    @StateObject private var viewModel = MateViewModel(profileStore: UserDefaultsMateProfileStore(key: "PathMate.MateDemoProfile.v1"))
    @State private var message = "选择一个事件观察 Mate 反馈"

    var body: some View {
        MateOverlayContainer(viewModel: viewModel, actions: demoActions) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        InfoBox(title: "Mate Demo", message: message, icon: "sparkles", tint: PMColor.primary)
                        controls
                        debugPanel
                    }
                    .padding(16)
                }
                .background(PMColor.softCanvas)
                .navigationTitle("Mate Demo")
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("事件")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PMColor.steel)
            demoButton("普通任务完成", icon: "checkmark.circle.fill") {
                message = "普通任务完成"
                viewModel.handle(event: .taskCompleted)
            }
            demoButton("重要任务完成", icon: "star.circle.fill") {
                message = "重要任务完成"
                viewModel.handle(event: .importantTaskCompleted)
            }
            demoButton("开始智能规划", icon: "calendar.badge.clock") {
                message = "正在智能规划"
                viewModel.handle(event: .schedulePlanningStarted)
            }
            demoButton("智能规划完成", icon: "checkmark.seal.fill") {
                message = "智能规划完成"
                viewModel.handle(event: .schedulePlanningCompleted)
            }
            demoButton("今日计划完成", icon: "party.popper.fill") {
                message = "今日计划完成"
                viewModel.handle(event: .dailyPlanCompleted)
            }
            demoButton("增加成长经验", icon: "plus.circle.fill") {
                message = "成长经验 +10"
                viewModel.addGrowth(points: 10)
            }
            demoButton("切换幼年", icon: "figure.child") {
                message = "切换为幼年"
                viewModel.setGrowthStage(.child)
            }
            demoButton("切换成年", icon: "figure.stand") {
                message = "切换为成年"
                viewModel.setGrowthStage(.adult)
            }
            demoButton("重置 Mate", icon: "arrow.counterclockwise") {
                message = "已重置 Mate"
                viewModel.resetProfile()
            }
            demoButton("展开菜单", icon: "circle.grid.3x3.fill") {
                message = "菜单已展开"
                viewModel.toggleMenu()
            }
            demoButton("最小化", icon: "chevron.up") {
                message = "Mate 已最小化"
                viewModel.minimize()
            }
        }
        .padding(16)
        .pathCardStyle()
    }

    @ViewBuilder
    private var debugPanel: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            debugRow("growthStage", viewModel.growthStage.rawValue)
            debugRow("mood", viewModel.mood.rawValue)
            debugRow("displayState", "\(viewModel.displayState)")
            debugRow("growthProgress", String(format: "%.2f", viewModel.growthProgress))
            debugRow("completedTaskCount", "\(viewModel.completedTaskCount)")
            debugRow("streakDays", "\(viewModel.streakDays)")
            debugRow("currentAsset", viewModel.currentAssetName)
        }
        .padding(16)
        .pathCardStyle()
        #endif
    }

    private var demoActions: MateActions {
        MateActions(
            openChat: { message = "点击了聊天按钮" },
            openSmartPlanner: {
                message = "点击了智能规划按钮"
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    await MainActor.run {
                        viewModel.handle(event: .schedulePlanningCompleted)
                    }
                }
            },
            minimize: { message = "点击了最小化按钮" }
        )
    }

    private func demoButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        PathButton(title: title, systemImage: icon, style: .secondary, action: action)
    }

    private func debugRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .foregroundStyle(PMColor.steel)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(PMColor.charcoal)
        }
        .font(.system(size: 13))
    }
}

struct MateDemoView_Previews: PreviewProvider {
    static var previews: some View {
        MateDemoView()
    }
}
