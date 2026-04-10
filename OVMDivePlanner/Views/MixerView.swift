// MixerView.swift
// Gas mixer UI with 3 calculator tabs

import SwiftUI

struct MixerView: View {
    @StateObject private var vm = MixerViewModel()
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            Form {
                Picker("Calculator", selection: $selectedTab) {
                    Text("Tank Fill (Boost)").tag(0)
                    Text("Top-Off Blend").tag(1)
                    Text("Trimix Mix").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)

                switch selectedTab {
                case 0:
                    BoostTab()
                case 1:
                    BlendTab()
                case 2:
                    MixTab()
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Gas Mixer")
        }
        .environmentObject(vm)
    }
}

// MARK: - Boost Tab

struct BoostTab: View {
    @EnvironmentObject private var vm: MixerViewModel

    var body: some View {
        Section("Donor Tank") {
            LabeledSlider(label: "Volume (L)", value: $vm.boost_vDonor, range: 0.1...50, step: 0.1, format: "%.1f L")
            LabeledSlider(label: "Pressure (bar)", value: $vm.boost_pDonor, range: 0...300, step: 1, format: "%.0f bar")
        }
        Section("Target Tank") {
            LabeledSlider(label: "Volume (L)", value: $vm.boost_vTarget, range: 0.1...50, step: 0.1, format: "%.1f L")
            LabeledSlider(label: "Starting Pressure (bar)", value: $vm.boost_pTarget, range: 0...300, step: 1, format: "%.0f bar")
        }
        Section {
            Button(action: vm.calculateBoost) {
                HStack {
                    Spacer()
                    Text("Calculate Final Pressure").font(.headline)
                    Spacer()
                }
            }
        }
        if let err = vm.boost_error {
            Section {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }
        if let result = vm.boost_result {
            Section("Result") {
                HStack {
                    Text("Final Pressure").foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.1f bar", result)).bold().foregroundStyle(.cyan)
                }
            }
        }
    }
}

// MARK: - Blend Tab

struct BlendTab: View {
    @EnvironmentObject private var vm: MixerViewModel

    var body: some View {
        Section("Starting Mix") {
            LabeledSlider(label: "O₂ (%)", value: $vm.blend_o2Start, range: 0...100, step: 1, format: "%.0f%%")
            LabeledSlider(label: "He (%)", value: $vm.blend_heStart, range: 0...100, step: 1, format: "%.0f%%")
            LabeledSlider(label: "Starting Pressure (bar)", value: $vm.blend_pStart, range: 0...300, step: 1, format: "%.0f bar")
        }

        Section("Top-Off Gas") {
            LabeledSlider(label: "O₂ (%)", value: $vm.blend_o2Fill, range: 0...100, step: 1, format: "%.0f%%")
            LabeledSlider(label: "He (%)", value: $vm.blend_heFill, range: 0...100, step: 1, format: "%.0f%%")
        }

        Section("Final State") {
            LabeledSlider(label: "Final Pressure (bar)", value: $vm.blend_pResult, range: 0...300, step: 1, format: "%.0f bar")
        }

        Section {
            Button(action: vm.calculateBlend) {
                HStack {
                    Spacer()
                    Text("Calculate Final Mix").font(.headline)
                    Spacer()
                }
            }
        }

        if let err = vm.blend_error {
            Section {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }

        if let result = vm.blend_result {
            Section("Resulting Mix") {
                HStack { Text("O₂").foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1f%%", result.o2Percent)).bold() }
                HStack { Text("He").foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1f%%", result.hePercent)).bold() }
                HStack { Text("N₂").foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1f%%", result.n2Percent)).bold() }
                HStack { Text("Pressure").foregroundStyle(.secondary); Spacer(); Text(String(format: "%.1f bar", result.finalPressure)).bold().foregroundStyle(.cyan) }
            }
        }
    }
}

// MARK: - Mix Tab

struct MixTab: View {
    @EnvironmentObject private var vm: MixerViewModel

    var body: some View {
        Section("Target Mix") {
            LabeledSlider(label: "O₂ (%)", value: $vm.mix_o2Target, range: 0...100, step: 1, format: "%.0f%%")
            LabeledSlider(label: "He (%)", value: $vm.mix_heTarget, range: 0...100, step: 1, format: "%.0f%%")
            LabeledSlider(label: "Target Pressure (bar)", value: $vm.mix_pTarget, range: 0...300, step: 1, format: "%.0f bar")
        }

        Section("Starting Mix") {
            LabeledSlider(label: "Starting Pressure (bar)", value: $vm.mix_pStart, range: 0...300, step: 1, format: "%.0f bar")
            LabeledSlider(label: "Current O₂ (%)", value: $vm.mix_o2Start, range: 0...100, step: 1, format: "%.0f%%")
            LabeledSlider(label: "Current He (%)", value: $vm.mix_heStart, range: 0...100, step: 1, format: "%.0f%%")
        }

        Section {
            Button(action: vm.calculateMix) {
                HStack {
                    Spacer()
                    Text("Calculate Required Pressures").font(.headline)
                    Spacer()
                }
            }
        }

        if let err = vm.mix_error {
            Section {
                Label(err, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }

        if let result = vm.mix_result {
            Section("Required Gas Pressures") {
                HStack { Text("O₂ needed").foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2f bar", result.requiredO2Pressure)).bold() }
                HStack { Text("He needed").foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2f bar", result.requiredHePressure)).bold() }
                HStack { Text("Air needed").foregroundStyle(.secondary); Spacer(); Text(String(format: "%.2f bar", result.requiredAirPressure)).bold() }
            }

            Section("Fill Sequence") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("1. Fill O₂ to").foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f bar", result.o2Total)).bold().foregroundStyle(.cyan)
                    }
                    HStack {
                        Text("2. Add He to").foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f bar", result.heTotal)).bold().foregroundStyle(.cyan)
                    }
                    HStack {
                        Text("3. Top with air to").foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.2f bar", result.airTotal)).bold().foregroundStyle(.cyan)
                    }
                }
            }
        }
    }
}

#Preview {
    MixerView()
}
