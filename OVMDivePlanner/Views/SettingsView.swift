// SettingsView.swift
// GF, rates, SAC, water type, last stop, surface pressure

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: DivePlannerViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case surfacePressure
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Units", selection: $vm.unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.displayName).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Water type", selection: $vm.waterType) {
                        Text("Salt water").tag(WaterType.salt)
                        Text("Fresh water").tag(WaterType.fresh)
                    }
                    LabeledContent("Surface pressure (bar)") {
                        TextField("1.0", value: $vm.surfacePressure, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .surfacePressure)
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
                    LabeledSlider(label: "Descent rate (\(vm.unitSystem.rateUnit))", value: rateBinding($vm.descentRate), range: rateRange(5...30), step: vm.unitSystem == .metric ? 1 : 5,
                                  format: vm.unitSystem == .metric ? "%.0f m/min" : "%.0f ft/min")
                    LabeledSlider(label: "Ascent rate (\(vm.unitSystem.rateUnit))", value: rateBinding($vm.ascentRate), range: rateRange(3...18), step: vm.unitSystem == .metric ? 1 : 5,
                                  format: vm.unitSystem == .metric ? "%.0f m/min" : "%.0f ft/min")
                } header: { Text("Rates") }

                Section {
                    LabeledSlider(label: "Bottom SAC (\(vm.unitSystem.volumeUnit)/min)", value: volumeBinding($vm.sacBottom), range: volumeRange(5...40), step: vm.unitSystem == .metric ? 1 : 0.5,
                                  format: vm.unitSystem == .metric ? "%.0f L/min" : "%.1f cuft/min")
                    LabeledSlider(label: "Deco SAC (\(vm.unitSystem.volumeUnit)/min)", value: volumeBinding($vm.sacDeco), range: volumeRange(5...40), step: vm.unitSystem == .metric ? 1 : 0.5,
                                  format: vm.unitSystem == .metric ? "%.0f L/min" : "%.1f cuft/min")
                } header: { Text("Surface Air Consumption") }

                Section {
                    LabeledContent("Last stop depth (\(vm.unitSystem.depthUnit))") {
                        Picker("", selection: $vm.lastStopDepth) {
                            Text(vm.unitSystem == .metric ? "3 m" : "10 ft").tag(3.0)
                            Text(vm.unitSystem == .metric ? "6 m" : "20 ft").tag(6.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    Toggle("Descent time included in bottom time", isOn: $vm.transitInclusive)
                } header: { Text("Decompression") }
            }
            .ovmFormBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func rateBinding(_ metricValue: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { vm.unitSystem.rate(metricValue.wrappedValue) },
            set: { metricValue.wrappedValue = vm.unitSystem.metricRate($0) }
        )
    }

    private func volumeBinding(_ metricValue: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { vm.unitSystem.volume(metricValue.wrappedValue) },
            set: { metricValue.wrappedValue = vm.unitSystem.metricVolume($0) }
        )
    }

    private func rateRange(_ metricRange: ClosedRange<Double>) -> ClosedRange<Double> {
        vm.unitSystem.rate(metricRange.lowerBound)...vm.unitSystem.rate(metricRange.upperBound)
    }

    private func volumeRange(_ metricRange: ClosedRange<Double>) -> ClosedRange<Double> {
        vm.unitSystem.volume(metricRange.lowerBound)...vm.unitSystem.volume(metricRange.upperBound)
    }
}
