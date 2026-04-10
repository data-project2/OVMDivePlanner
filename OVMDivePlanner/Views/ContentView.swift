
// ContentView.swift
// Root tab container

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DivePlannerViewModel()

    var body: some View {
        TabView(selection: $vm.selectedTab) {
            PlannerView()
                .tag(PlannerTab.plan)
                .tabItem { Label("Plan", systemImage: "arrow.down.to.line") }
            ResultsView()
                .tag(PlannerTab.schedule)
                .tabItem { Label("Schedule", systemImage: "list.bullet.clipboard") }
            SettingsView()
                .tag(PlannerTab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environmentObject(vm)
        .tint(OVMTheme.accent)
        .background(OVMTheme.background)
        .preferredColorScheme(.dark)
    }
}
