//
//  ContentView.swift
//  app1
//
//  Created by 1111 on 2026/5/19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = PathMateStore()
    @StateObject private var mateViewModel = MateViewModel()
    @StateObject private var mateEventBus = MateEventBus()
    @State private var mateRoute: MateRoute?

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                MateOverlayContainer(viewModel: mateViewModel, actions: mateActions) {
                    MainTabView(store: store)
                        .environmentObject(mateEventBus)
                        .environmentObject(mateViewModel)
                        .environment(\.mateActions, mateActions)
                }
            } else {
                OnboardingFlow(store: store)
            }
        }
        .preferredColorScheme(store.profile.appearanceMode.colorScheme)
        .onAppear {
            mateEventBus.bind(mateViewModel)
        }
        .sheet(item: $mateRoute) { route in
            NavigationStack {
                routeView(route)
                    .navigationTitle(route.title)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("完成") { mateRoute = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var mateActions: MateActions {
        MateActions(
            openChat: {
                mateRoute = .chat
            },
            openSmartPlanner: {
                mateRoute = .smartPlanner
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    await MainActor.run {
                        mateViewModel.handle(event: .schedulePlanningCompleted)
                    }
                }
            },
            minimize: {}
        )
    }

    @ViewBuilder
    private func routeView(_ route: MateRoute) -> some View {
        switch route {
        case .chat:
            VStack(alignment: .leading, spacing: 14) {
                Label("Mate 聊天", systemImage: "message.fill")
                    .font(.system(size: 22, weight: .semibold))
                Text("这里是聊天入口示例。接入真实聊天页面时，把 MateActions.openChat 绑定到现有路由即可。")
                    .foregroundStyle(PMColor.slate)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
            .background(PMColor.softCanvas)

        case .smartPlanner:
            VStack(alignment: .leading, spacing: 14) {
                Label("智能日程规划", systemImage: "calendar.badge.clock")
                    .font(.system(size: 22, weight: .semibold))
                Text("Mate 正在模拟 1.5 秒异步规划。真实项目中可以在业务规划完成后调用 mateViewModel.handle(event: .schedulePlanningCompleted)。")
                    .foregroundStyle(PMColor.slate)
                ProgressView()
                    .tint(PMColor.primary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(20)
            .background(PMColor.softCanvas)
        }
    }
}

private enum MateRoute: Identifiable {
    case chat
    case smartPlanner

    var id: String { title }

    var title: String {
        switch self {
        case .chat: return "Mate 聊天"
        case .smartPlanner: return "智能规划"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
