// PlannerView.swift
// Dive profile + gas input form

import SwiftUI

struct PlannerView: View {
    @EnvironmentObject private var vm: DivePlannerViewModel
    @State private var showCCRSettings = false

    var body: some View {
        NavigationStack {
            Form {
                // Circuit type
                Section("Circuit") {
                    Picker("Circuit", selection: $vm.circuitType) {
                        Text("Open Circuit").tag(CircuitType.oc)
                        Text("CCR (Closed Circuit)").tag(CircuitType.ccr)
                    }
                    .pickerStyle(.segmented)

                    if vm.circuitType == .ccr {
                        Button("CCR Settings…") { showCCRSettings = true }
                    }
                }

                // Dive levels
                Section {
                    ForEach($vm.levels) { $level in
                        LevelRow(level: $level)
                    }
                    .onDelete(perform: vm.removeLevel)
                    Button(action: vm.addLevel) {
                        Label("Add Level", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Dive Profile (m / min)")
                } footer: {
                    Text("Levels are processed top-to-bottom. Transit between levels uses descent/ascent rates from Settings.")
                }

                // Bottom gas
                Section(vm.circuitType == .ccr ? "Diluent Gas" : "Bottom Gas") {
                    GasPickerRow(gas: $vm.bottomGas, showSwitch: false)
                }

                // Deco gases (OC only)
                if vm.circuitType == .oc {
                    Section {
                        ForEach($vm.decoGases) { $g in
                            GasPickerRow(gas: $g, showSwitch: true)
                        }
                        .onDelete(perform: vm.removeDecoGas)
                        Button(action: vm.addDecoGas) {
                            Label("Add Deco Gas", systemImage: "plus.circle")
                        }
                    } header: {
                        Text("Deco Gases")
                    } footer: {
                        Text("Leave switch depth empty to auto-calculate from ppO₂ 1.6.")
                    }
                }

                // Repetitive dive
                Section {
                    Toggle("Enable Repetitive Dive", isOn: $vm.enableRepetitive)
                    if vm.enableRepetitive {
                        RepetitiveDiveView()
                    }
                } header: {
                    Text("Repetitive Dive")
                }

                // Calculate button
                Section {
                    Button(action: {
                        vm.selectedTab = .schedule
                        vm.calculate()
                    }) {
                        HStack {
                            Spacer()
                            if vm.isCalculating {
                                ProgressView().padding(.trailing, 8)
                            }
                            Text(vm.isCalculating ? "Calculating…" : "Calculate Decompression")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(vm.isCalculating)
                }
            }
            .ovmFormBackground()
            .navigationTitle("OVM Dive Planner")
        }
        .sheet(isPresented: $showCCRSettings) {
            CCRSettingsSheet()
                .environmentObject(vm)
        }
    }
}

// MARK: - Level row

struct LevelRow: View {
    @Binding var level: DiveLevel
    var body: some View {
        HStack {
            Text("Depth (m)").foregroundStyle(OVMTheme.textSecondary).frame(width: 80, alignment: .leading)
            TextField("0", value: $level.depth, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Spacer().frame(width: 24)
            Text("Time (min)").foregroundStyle(OVMTheme.textSecondary).frame(width: 80, alignment: .leading)
            TextField("0", value: $level.time, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Gas picker row

struct GasPickerRow: View {
    @Binding var gas: GasMix
    var showSwitch: Bool

    @State private var preset: GasPreset = .custom
    @State private var o2Str = ""
    @State private var heStr = ""
    @State private var swStr = ""
    @State private var isSyncingFromGas = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case oxygen
        case helium
        case switchDepth
    }

    enum GasPreset: String, CaseIterable {
        case air = "Air"
        case ean32 = "EAN32"
        case ean36 = "EAN36"
        case ean50 = "EAN50"
        case o2 = "O₂ 100%"
        case tx2135 = "Tx 21/35"
        case tx1845 = "Tx 18/45"
        case custom = "Custom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Preset", selection: $preset) {
                ForEach(GasPreset.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .onChange(of: preset) { _ in
                guard !isSyncingFromGas else { return }
                applyPreset()
            }

            HStack {
                Group {
                    Text("O₂%").frame(width: 36)
                    TextField("21", text: $o2Str)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .oxygen)
                        .submitLabel(.done)
                        .onChange(of: o2Str) { _ in updateGas() }
                    Text("He%").frame(width: 36)
                    TextField("0", text: $heStr)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .helium)
                        .submitLabel(.done)
                        .onChange(of: heStr) { _ in updateGas() }
                }
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
            }

            if showSwitch {
                HStack {
                    Text("Switch depth (m, blank = auto)").foregroundStyle(OVMTheme.textSecondary).font(.caption)
                    Spacer()
                    TextField("auto", text: $swStr)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .focused($focusedField, equals: .switchDepth)
                        .submitLabel(.done)
                        .onChange(of: swStr) { _ in updateGas() }
                }
            }
        }
        .onAppear { syncFromGas() }
        .onChange(of: gas) { _ in syncFromGas() }
        .onChange(of: focusedField) { field in
            if field == nil {
                updateGas()
            }
        }
        .onSubmit {
            updateGas()
        }
    }

    private func syncFromGas() {
        guard focusedField == nil else { return }

        let nextO2 = String(format: "%.0f", gas.fO2 * 100)
        let nextHe = String(format: "%.0f", gas.fHe * 100)
        let nextSwitchDepth = gas.switchDepth.map { String(format: "%.0f", $0) } ?? ""
        let nextPreset = preset(for: gas)

        guard o2Str != nextO2 || heStr != nextHe || swStr != nextSwitchDepth || preset != nextPreset else {
            return
        }

        isSyncingFromGas = true
        o2Str = nextO2
        heStr = nextHe
        swStr = nextSwitchDepth
        preset = nextPreset
        isSyncingFromGas = false
    }

    private func updateGas() {
        guard !isSyncingFromGas else { return }

        let o2 = (Double(o2Str) ?? gas.fO2 * 100) / 100
        let he = (Double(heStr) ?? gas.fHe * 100) / 100
        let sw = Double(swStr)
        let nextGas = GasMix(id: gas.id, fO2: min(1, max(0, o2)), fHe: min(1 - o2, max(0, he)), switchDepth: sw)

        if gas != nextGas {
            gas = nextGas
        }

        if preset != .custom {
            preset = .custom
        }
    }

    private func applyPreset() {
        switch preset {
        case .air:   gas = GasMix(id: gas.id, fO2: 0.21, fHe: 0.0, switchDepth: nil)
        case .ean32: gas = GasMix(id: gas.id, fO2: 0.32, fHe: 0.0, switchDepth: nil)
        case .ean36: gas = GasMix(id: gas.id, fO2: 0.36, fHe: 0.0, switchDepth: nil)
        case .ean50: gas = GasMix(id: gas.id, fO2: 0.50, fHe: 0.0, switchDepth: nil)
        case .o2:    gas = GasMix(id: gas.id, fO2: 1.00, fHe: 0.0, switchDepth: nil)
        case .tx2135: gas = GasMix(id: gas.id, fO2: 0.21, fHe: 0.35, switchDepth: nil)
        case .tx1845: gas = GasMix(id: gas.id, fO2: 0.18, fHe: 0.45, switchDepth: nil)
        case .custom: return
        }
    }

    private func preset(for gas: GasMix) -> GasPreset {
        switch (gas.fO2, gas.fHe) {
        case (0.21, 0.0): return .air
        case (0.32, 0.0): return .ean32
        case (0.36, 0.0): return .ean36
        case (0.50, 0.0): return .ean50
        case (1.00, 0.0): return .o2
        case (0.21, 0.35): return .tx2135
        case (0.18, 0.45): return .tx1845
        default: return .custom
        }
    }
}

// MARK: - CCR Settings sheet

struct CCRSettingsSheet: View {
    @EnvironmentObject private var vm: DivePlannerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Setpoints (bar ppO₂)") {
                    LabeledSlider(label: "Low setpoint", value: $vm.setpointLow, range: 0.4...1.6, step: 0.05,
                                  format: "%.2f bar")
                    LabeledSlider(label: "High setpoint", value: $vm.setpointHigh, range: 0.4...1.6, step: 0.05,
                                  format: "%.2f bar")
                    LabeledSlider(label: "Deco setpoint", value: $vm.setpointDeco, range: 0.4...1.6, step: 0.05,
                                  format: "%.2f bar")
                    LabeledContent("Switch to high below (m)") {
                        TextField("6", value: $vm.setpointSwitchDepth, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                Section("Deco Gases (bailout)") {
                    ForEach($vm.decoGases) { $g in GasPickerRow(gas: $g, showSwitch: true) }
                        .onDelete(perform: vm.removeDecoGas)
                    Button(action: vm.addDecoGas) { Label("Add Gas", systemImage: "plus.circle") }
                }
            }
            .ovmFormBackground()
            .navigationTitle("CCR Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
