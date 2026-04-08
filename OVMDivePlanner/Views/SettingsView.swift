// SettingsView.swift
// GF, rates, SAC, water type, last stop, surface pressure

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: DivePlannerViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Water type", selection: $vm.waterType) {
                        Text("Salt water").tag(WaterType.salt)
                        Text("Fresh water").tag(WaterType.fresh)
                    }
                    LabeledContent("Surface pressure (bar)") {
                        TextField("1.0", value: $vm.surfacePressure, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                } header: { Text("Environment") }

                Section {
                    LabeledSlider(label: "GF Low", value: $vm.gfLow, range: 10...100, step: 5,
                                  format: "%.0f%%")
                    LabeledSlider(label: "GF High", value: $vm.gfHigh, range: 10...100, step: 5,
                                  format: "%.0f%%")
                } header: {
                    Text("Gradient Factors")
                } footer: {
                    Text("GF Low controls first deco stop depth. GF High controls surface allowable supersaturation. Conservative = lower values.")
                }

                Section {
                    LabeledSlider(label: "Descent rate (m/min)", value: $vm.descentRate, range: 5...30, step: 1,
                                  format: "%.0f m/min")
                    LabeledSlider(label: "Ascent rate (m/min)", value: $vm.ascentRate, range: 3...18, step: 1,
                                  format: "%.0f m/min")
                } header: { Text("Rates") }

                Section {
                    LabeledSlider(label: "Bottom SAC (L/min)", value: $vm.sacBottom, range: 5...40, step: 1,
                                  format: "%.0f L/min")
                    LabeledSlider(label: "Deco SAC (L/min)", value: $vm.sacDeco, range: 5...40, step: 1,
                                  format: "%.0f L/min")
                } header: { Text("Surface Air Consumption") }

                Section {
                    LabeledContent("Last stop depth (m)") {
                        Picker("", selection: $vm.lastStopDepth) {
                            Text("3 m").tag(3.0)
                            Text("6 m").tag(6.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    Toggle("Transit time counts toward level time", isOn: $vm.transitInclusive)
                } header: { Text("Decompression") }
            }
            .navigationTitle("Settings")
        }
    }
}
