// ContentView.swift
// Root tab container

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DivePlannerViewModel()

    var body: some View {
        TabView(selection: $vm.selectedTab) {
            PlannerView()
                .tabItem { Label("Plan", systemImage: "arrow.down.to.line") }
                .tag(PlannerTab.plan)
            ResultsView()
                .tabItem { Label("Schedule", systemImage: "list.bullet.clipboard") }
                .tag(PlannerTab.schedule)
            MixerView()
                .tabItem { Label("Mixer", systemImage: "flask.fill") }
                .tag(PlannerTab.mixer)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(PlannerTab.settings)
        }
        .environmentObject(vm)
        .tint(OVMTheme.accent)
        .background(OVMTheme.background)
        .preferredColorScheme(.dark)
    }
}
