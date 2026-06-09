//
//  ContentView.swift
//  app1
//
//  Created by 1111 on 2026/5/19.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = PathMateStore()

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                MainTabView(store: store)
            } else {
                OnboardingFlow(store: store)
            }
        }
        .preferredColorScheme(store.profile.appearanceMode.colorScheme)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
