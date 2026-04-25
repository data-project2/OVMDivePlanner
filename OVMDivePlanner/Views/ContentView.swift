// ContentView.swift
// Root tab container

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DivePlannerViewModel()
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

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
        .fullScreenCover(
            isPresented: Binding(
                get: { !hasAcceptedDisclaimer },
                set: { _ in }
            )
        ) {
            DisclaimerAcceptanceView {
                hasAcceptedDisclaimer = true
            }
            .interactiveDismissDisabled()
        }
    }
}

private struct DisclaimerAcceptanceView: View {
    let onAccept: () -> Void

    private let disclaimerPoints = [
        "This software is provided on an \"as-is\" basis without warranty of any kind, express or implied.",
        "The developers and distributors assume no liability for any injuries, damages, or losses resulting from the use of this software.",
        "This app is a mathematical planning tool based on theoretical decompression models. It does not account for individual variations in physiology, metabolism, or decompression sickness susceptibility.",
        "The app does not assess your physical fitness, health status, or medical conditions that may affect diving safety.",
        "The app does not evaluate your mental or psychological state, including fatigue, stress, anxiety, or alertness.",
        "The app does not account for environmental conditions such as water temperature, visibility, currents, weather, sea state, bottom composition, or other site-specific hazards.",
        "The app does not consider your experience level, familiarity with your equipment, or your proficiency with the planned dive profile.",
        "The app does not monitor actual underwater conditions, your real-time physiological state, or equipment performance during the dive.",
        "Decompression calculations are theoretical approximations. Real-world physiology varies significantly between individuals. Follow conservative dive practices and your dive computer.",
        "Diving is an inherently dangerous activity that requires proper training, certification, and appropriate equipment.",
        "You must obtain formal training and certification from qualified instructors before diving.",
        "You must use appropriate equipment and materials for the specific dive profile you intend to execute.",
        "A functioning dive computer is mandatory for all dives and must be used as your primary depth and time reference.",
        "The user assumes all responsibility and risk associated with diving activities and the use of this software."
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Before You Continue")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(OVMTheme.textPrimary)

                        Text("You must review and accept this disclaimer before using OVM Dive Planner.")
                            .font(.body)
                            .foregroundStyle(OVMTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Disclaimer")
                            .font(.headline)
                            .foregroundStyle(Color(red: 1.0, green: 66 / 255, blue: 66 / 255))

                        ForEach(disclaimerPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color(red: 1.0, green: 66 / 255, blue: 66 / 255))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 7)

                                Text(point)
                                    .font(.subheadline)
                                    .foregroundStyle(OVMTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(18)
                    .background(Color(red: 1.0, green: 66 / 255, blue: 66 / 255).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 1.0, green: 66 / 255, blue: 66 / 255).opacity(0.35), lineWidth: 1)
                    }

                    Button(action: onAccept) {
                        Text("I Accept and Understand")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(OVMTheme.accent)
                    .foregroundStyle(OVMTheme.background)
                }
                .padding(16)
            }
            .background(OVMTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Disclaimer")
                        .foregroundStyle(OVMTheme.textPrimary)
                        .font(.headline)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
