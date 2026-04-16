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
                        LevelRow(level: $level, unitSystem: vm.unitSystem)
                    }
                    .onDelete(perform: vm.removeLevel)
                    Button(action: vm.addLevel) {
                        Label("Add Level", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Dive Profile (\(vm.unitSystem.depthUnit) / min)")
                } footer: {
                    Text("Levels are processed top-to-bottom. Transit between levels uses descent/ascent rates from Settings.")
                }

                // Bottom gas
                Section(vm.circuitType == .ccr ? "Diluent Gas" : "Bottom Gas") {
                    GasPickerRow(gas: $vm.bottomGas, showSwitch: false, unitSystem: vm.unitSystem)
                }

                // Deco gases (OC only)
                if vm.circuitType == .oc {
                    Section {
                        ForEach($vm.decoGases) { $g in
                            GasPickerRow(gas: $g, showSwitch: true, unitSystem: vm.unitSystem)
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
                            Text(vm.isCalculating ? "Calculating…" : "Plan Dive")
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
    let unitSystem: UnitSystem

    private var depthChoices: [Int] {
        unitSystem == .metric ? Array(0...150) : Array(stride(from: 0, through: 500, by: 10))
    }

    private var displayedDepth: Binding<Double> {
        Binding(
            get: {
                let displayDepth = unitSystem.depth(level.depth)
                let nearest = depthChoices.min { abs(Double($0) - displayDepth) < abs(Double($1) - displayDepth) } ?? 0
                return Double(nearest)
            },
            set: { level.depth = unitSystem.normalizeMetricProfileDepth(unitSystem.metricDepth($0)) }
        )
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Depth (\(unitSystem.depthUnit))")
                    .foregroundStyle(OVMTheme.textSecondary)

                Picker("Depth (\(unitSystem.depthUnit))", selection: displayedDepth) {
                    ForEach(depthChoices, id: \.self) { depth in
                        Text("\(depth)").tag(Double(depth))
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 96, height: 100)
                .clipped()
            }

            Spacer().frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Time (min)")
                    .foregroundStyle(OVMTheme.textSecondary)

                Picker("Time (min)", selection: $level.time) {
                    ForEach(0...300, id: \.self) { minute in
                        Text("\(minute)").tag(Double(minute))
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 96, height: 100)
                .clipped()
            }
        }
    }
}

// MARK: - Gas picker row

struct GasPickerRow: View {
    @Binding var gas: GasMix
    var showSwitch: Bool
    let unitSystem: UnitSystem

    @State private var preset: GasPreset = .custom
    @State private var swStr = ""
    @State private var isSyncingFromGas = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
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
                gasPercentWheel(
                    title: "O₂%",
                    selection: Binding(
                        get: { Int((gas.fO2 * 100).rounded()) },
                        set: { newValue in
                            let o2 = min(100, max(0, newValue))
                            let he = min(Int((gas.fHe * 100).rounded()), 100 - o2)
                            gas = GasMix(
                                id: gas.id,
                                fO2: Double(o2) / 100,
                                fHe: Double(he) / 100,
                                switchDepth: gas.switchDepth
                            )
                            if preset != .custom {
                                preset = .custom
                            }
                        }
                    )
                )

                gasPercentWheel(
                    title: "He%",
                    selection: Binding(
                        get: { Int((gas.fHe * 100).rounded()) },
                        set: { newValue in
                            let o2 = Int((gas.fO2 * 100).rounded())
                            let he = min(max(0, newValue), 100 - o2)
                            gas = GasMix(
                                id: gas.id,
                                fO2: Double(o2) / 100,
                                fHe: Double(he) / 100,
                                switchDepth: gas.switchDepth
                            )
                            if preset != .custom {
                                preset = .custom
                            }
                        }
                    )
                )
            }

            if showSwitch {
                HStack {
                    Text("Switch depth (\(unitSystem.depthUnit), blank = auto)").foregroundStyle(OVMTheme.textSecondary).font(.caption)
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

        let nextSwitchDepth = gas.switchDepth.map { String(format: "%.0f", unitSystem.depth($0)) } ?? ""
        let nextPreset = preset(for: gas)

        guard swStr != nextSwitchDepth || preset != nextPreset else {
            return
        }

        isSyncingFromGas = true
        swStr = nextSwitchDepth
        preset = nextPreset
        isSyncingFromGas = false
    }

    private func updateGas() {
        guard !isSyncingFromGas else { return }

        let sw = Double(swStr).map { unitSystem.normalizeMetricSwitchDepth(unitSystem.metricDepth($0)) }
        let nextGas = GasMix(id: gas.id, fO2: gas.fO2, fHe: gas.fHe, switchDepth: sw)

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

    @ViewBuilder
    private func gasPercentWheel(title: String, selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(title, selection: selection) {
                ForEach(0...100, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.wheel)
            .frame(width: 96)
            .frame(height: 110)
            .clipped()
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
                    LabeledContent("Switch to high below (\(vm.unitSystem.depthUnit))") {
                        TextField(
                            "6",
                            value: Binding(
                                get: { vm.unitSystem.depth(vm.setpointSwitchDepth) },
                                set: { vm.setpointSwitchDepth = vm.unitSystem.normalizeMetricSwitchDepth(vm.unitSystem.metricDepth($0)) }
                            ),
                            format: .number
                        )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
                Section("Deco Gases (bailout)") {
                    ForEach($vm.decoGases) { $g in GasPickerRow(gas: $g, showSwitch: true, unitSystem: vm.unitSystem) }
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
