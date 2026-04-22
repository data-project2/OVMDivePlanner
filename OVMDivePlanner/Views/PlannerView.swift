// PlannerView.swift
// Dive profile + gas input form

import SwiftUI

enum PlannerEditorMode: String, CaseIterable {
    case list = "List"
    case visual = "Visual"
}

private let plannerMaxDepthMetric = 200.0

struct PlannerView: View {
    @EnvironmentObject private var vm: DivePlannerViewModel
    @State private var showCCRSettings = false
    @State private var plannerMode: PlannerEditorMode = .visual
    @State private var isCircuitExpanded = true
    @State private var isPlannerModeExpanded = false
    @State private var isProfileExpanded = true
    @State private var isBottomGasExpanded = true
    @State private var isDecoGasesExpanded = true
    @State private var isRepetitiveExpanded = false

    var body: some View {
        NavigationStack {
            Form {
                // Circuit type
                Section {
                    if isCircuitExpanded {
                        Picker("Circuit", selection: $vm.circuitType) {
                            Text("Open Circuit").tag(CircuitType.oc)
                            Text("CCR (Closed Circuit)").tag(CircuitType.ccr)
                        }
                        .pickerStyle(.segmented)

                        if vm.circuitType == .ccr {
                            Button("CCR Settings…") { showCCRSettings = true }
                        }
                    }
                } header: {
                    collapsibleHeader("Circuit", isExpanded: $isCircuitExpanded)
                }

                Section {
                    if isPlannerModeExpanded {
                        Picker("Planner Mode", selection: $plannerMode) {
                            ForEach(PlannerEditorMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    collapsibleHeader("Planner Mode", isExpanded: $isPlannerModeExpanded)
                }

                // Dive levels
                Section {
                    if isProfileExpanded {
                        if plannerMode == .list {
                            ForEach($vm.levels) { $level in
                                LevelRow(level: $level, unitSystem: vm.unitSystem)
                            }
                            .onDelete(perform: vm.removeLevel)
                            Button(action: vm.addLevel) {
                                Label("Add Level", systemImage: "plus.circle")
                            }
                        } else {
                            VisualPlannerView(
                                levels: $vm.levels,
                                descentRate: vm.descentRate,
                                ascentRate: vm.ascentRate,
                                unitSystem: vm.unitSystem,
                                result: vm.results
                            )
                        }
                    }
                } header: {
                    collapsibleHeader("Dive Profile (\(vm.unitSystem.depthUnit) / min)", isExpanded: $isProfileExpanded)
                } footer: {
                    if isProfileExpanded {
                        Text(plannerMode == .list
                             ? "Levels are processed top-to-bottom. Transit between levels uses descent/ascent rates from Settings."
                             : "Tap the chart to add a waypoint. Drag waypoint handles vertically to change depth. Hold time is edited below the chart.")
                    }
                }

                // Bottom gas
                Section {
                    if isBottomGasExpanded {
                        GasPickerRow(gas: $vm.bottomGas, showSwitch: false, unitSystem: vm.unitSystem)
                    }
                } header: {
                    collapsibleHeader(vm.circuitType == .ccr ? "Diluent Gas" : "Bottom Gas", isExpanded: $isBottomGasExpanded)
                }

                // Deco gases (OC only)
                if vm.circuitType == .oc {
                    Section {
                        if isDecoGasesExpanded {
                            ForEach($vm.decoGases) { $g in
                                GasPickerRow(gas: $g, showSwitch: true, unitSystem: vm.unitSystem)
                            }
                            .onDelete(perform: vm.removeDecoGas)
                            Button(action: vm.addDecoGas) {
                                Label("Add Deco Gas", systemImage: "plus.circle")
                            }
                        }
                    } header: {
                        collapsibleHeader("Deco Gases", isExpanded: $isDecoGasesExpanded)
                    } footer: {
                        if isDecoGasesExpanded {
                            Text("Leave switch depth empty to auto-calculate from ppO₂ 1.6.")
                        }
                    }
                }

                // Repetitive dive
                Section {
                    if isRepetitiveExpanded {
                        Toggle("Enable Repetitive Dive", isOn: $vm.enableRepetitive)
                        if vm.enableRepetitive {
                            RepetitiveDiveView()
                        }
                    }
                } header: {
                    collapsibleHeader("Repetitive Dive", isExpanded: $isRepetitiveExpanded)
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

    @ViewBuilder
    private func collapsibleHeader(_ title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            isExpanded.wrappedValue.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded.wrappedValue ? "chevron.down.circle.fill" : "chevron.right.circle")
                    .foregroundStyle(OVMTheme.accent)
                Text(title)
                    .foregroundStyle(OVMTheme.textPrimary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
    }
}

// MARK: - Level row

struct LevelRow: View {
    @Binding var level: DiveLevel
    let unitSystem: UnitSystem

    private var depthChoices: [Int] {
        if unitSystem == .metric {
            return Array(0...Int(plannerMaxDepthMetric))
        }

        let maxImperialDepth = Int((plannerMaxDepthMetric * 3.28084).rounded())
        return Array(stride(from: 0, through: maxImperialDepth, by: 10))
    }

    private var displayedDepth: Binding<Double> {
        Binding(
            get: {
                let displayDepth = unitSystem.depth(level.depth)
                let nearest = depthChoices.min { abs(Double($0) - displayDepth) < abs(Double($1) - displayDepth) } ?? 0
                return Double(nearest)
            },
            set: { level.depth = unitSystem.normalizeMetricProfileDepth(min(unitSystem.metricDepth($0), plannerMaxDepthMetric)) }
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
        .toolbar {
            if focusedField == .switchDepth {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        updateGas()
                        focusedField = nil
                    }
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


import SwiftUI

struct VisualPlannerView: View {
    @Binding var levels: [DiveLevel]
    let descentRate: Double
    let ascentRate: Double
    let unitSystem: UnitSystem
    let result: DiveResultData?

    private let chartHeight: CGFloat = 260
    private let leftInset: CGFloat = 42
    private let rightInset: CGFloat = 12
    private let topInset: CGFloat = 12
    private let bottomInset: CGFloat = 30
    private let defaultHoldTime: Double = 10
    private let minimumMetricChartDepth: Double = 30
    private let minimumChartRuntime: Double = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chart

            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                HStack(spacing: 12) {
                    Text("WP \(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 42, alignment: .leading)

                    Text(depthLabel(for: waypoint.depth))
                        .foregroundStyle(OVMTheme.textSecondary)
                        .frame(width: 72, alignment: .leading)

                    Stepper(value: holdTimeBinding(for: waypoint.id), in: 0...300, step: 1) {
                        Text("Hold \(Int(waypoint.time)) min")
                    }

                    Button(role: .destructive) {
                        deleteWaypoint(id: waypoint.id)
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .disabled(levels.count <= 1)
                }
            }

            Button {
                appendWaypoint()
            } label: {
                Label("Add Waypoint", systemImage: "plus.circle")
            }
        }
    }

    private var chart: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let plotWidth = max(1, width - leftInset - rightInset)
            let plotHeight = max(1, chartHeight - topInset - bottomInset)
            let profile = profilePoints
            let decoOverlay = decoOverlayPoints
            let runtime = chartRuntime
            let maxDepthMetric = chartMaxDepthMetric

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(OVMTheme.card)

                grid(plotWidth: plotWidth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric, runtime: runtime)

                profilePath(profile, plotWidth: plotWidth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric, runtime: runtime)

                decoPath(decoOverlay, plotWidth: plotWidth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric, runtime: runtime)

                ForEach(waypointLayouts) { waypoint in
                    Circle()
                        .fill(OVMTheme.accent)
                        .frame(width: 14, height: 14)
                        .position(
                            x: xPosition(for: waypoint.endRuntime, plotWidth: plotWidth, runtime: runtime),
                            y: yPosition(for: waypoint.depth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric)
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateWaypoint(
                                        for: waypoint.id,
                                        location: value.location,
                                        plotWidth: plotWidth,
                                        plotHeight: plotHeight,
                                        maxDepthMetric: maxDepthMetric,
                                        runtime: runtime
                                    )
                                }
                        )
                }
            }
            .frame(height: chartHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard abs(value.translation.width) < 6, abs(value.translation.height) < 6 else { return }
                        addWaypoint(
                            at: value.location,
                            plotWidth: plotWidth,
                            plotHeight: plotHeight,
                            runtime: runtime,
                            maxDepthMetric: maxDepthMetric
                        )
                    }
            )
        }
        .frame(height: chartHeight)
    }

    private func grid(plotWidth: CGFloat, plotHeight: CGFloat, maxDepthMetric: Double, runtime: Double) -> some View {
        let horizontalTicks = 5
        let verticalTicks = 5

        return ZStack(alignment: .topLeading) {
            ForEach(0...horizontalTicks, id: \.self) { tick in
                let fraction = CGFloat(tick) / CGFloat(horizontalTicks)
                let y = topInset + fraction * plotHeight

                Path { path in
                    path.move(to: CGPoint(x: leftInset, y: y))
                    path.addLine(to: CGPoint(x: leftInset + plotWidth, y: y))
                }
                .stroke(OVMTheme.border.opacity(0.35), lineWidth: 1)

                let metricDepth = Double(fraction) * maxDepthMetric
                Text(depthLabel(for: metricDepth))
                    .font(.caption2)
                    .foregroundStyle(OVMTheme.textTertiary)
                    .position(x: 20, y: y)
            }

            ForEach(0...verticalTicks, id: \.self) { tick in
                let fraction = CGFloat(tick) / CGFloat(verticalTicks)
                let x = leftInset + fraction * plotWidth

                Path { path in
                    path.move(to: CGPoint(x: x, y: topInset))
                    path.addLine(to: CGPoint(x: x, y: topInset + plotHeight))
                }
                .stroke(OVMTheme.border.opacity(0.35), lineWidth: 1)

                let timeValue = Double(fraction) * runtime
                Text("\(Int(timeValue.rounded())) min")
                    .font(.caption2)
                    .foregroundStyle(OVMTheme.textTertiary)
                    .position(x: x, y: topInset + plotHeight + 12)
            }
        }
    }

    private func profilePath(_ points: [RuntimeDepthPoint], plotWidth: CGFloat, plotHeight: CGFloat, maxDepthMetric: Double, runtime: Double) -> some View {
        chartPath(points, plotWidth: plotWidth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric, runtime: runtime)
            .stroke(OVMTheme.accent, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
    }

    private func decoPath(_ points: [RuntimeDepthPoint], plotWidth: CGFloat, plotHeight: CGFloat, maxDepthMetric: Double, runtime: Double) -> some View {
        chartPath(points, plotWidth: plotWidth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric, runtime: runtime)
            .stroke(OVMTheme.danger, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
    }

    private func chartPath(_ points: [RuntimeDepthPoint], plotWidth: CGFloat, plotHeight: CGFloat, maxDepthMetric: Double, runtime: Double) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(
                x: xPosition(for: first.runtime, plotWidth: plotWidth, runtime: runtime),
                y: yPosition(for: first.depth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric)
            ))

            for point in points.dropFirst() {
                path.addLine(to: CGPoint(
                    x: xPosition(for: point.runtime, plotWidth: plotWidth, runtime: runtime),
                    y: yPosition(for: point.depth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric)
                ))
            }
        }
    }

    private func xPosition(for runtimeValue: Double, plotWidth: CGFloat, runtime: Double) -> CGFloat {
        leftInset + CGFloat(runtimeValue / max(runtime, 1)) * plotWidth
    }

    private func yPosition(for depth: Double, plotHeight: CGFloat, maxDepthMetric: Double) -> CGFloat {
        topInset + CGFloat(depth / max(maxDepthMetric, 1)) * plotHeight
    }

    private func updateWaypoint(
        for id: UUID,
        location: CGPoint,
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        maxDepthMetric: Double,
        runtime: Double
    ) {
        guard
            let index = levels.firstIndex(where: { $0.id == id }),
            let layout = waypointLayouts.first(where: { $0.id == id })
        else { return }

        let clampedX = min(max(location.x, leftInset), leftInset + plotWidth)
        let draggedRuntime = Double((clampedX - leftInset) / plotWidth) * runtime
        let holdTime = max(0, draggedRuntime - layout.arrivalRuntime)

        let clampedY = min(max(location.y, topInset), topInset + plotHeight)
        let depthFraction = Double((clampedY - topInset) / plotHeight)
        let metricDepth = depthFraction * maxDepthMetric

        levels[index].depth = unitSystem.normalizeMetricProfileDepth(min(metricDepth, plannerMaxDepthMetric))
        levels[index].time = holdTime.rounded()
    }

    private func addWaypoint(at location: CGPoint, plotWidth: CGFloat, plotHeight: CGFloat, runtime: Double, maxDepthMetric: Double) {
        let clampedY = min(max(location.y, topInset), topInset + plotHeight)
        let depthFraction = Double((clampedY - topInset) / plotHeight)
        let metricDepth = unitSystem.normalizeMetricProfileDepth(min(depthFraction * maxDepthMetric, plannerMaxDepthMetric))
        let insertIndex = insertionIndex(for: location.x, plotWidth: plotWidth, runtime: runtime)
        let waypoint = DiveLevel(depth: metricDepth, time: defaultHoldTime)
        levels.insert(waypoint, at: insertIndex)
    }

    private func insertionIndex(for xLocation: CGFloat, plotWidth: CGFloat, runtime: Double) -> Int {
        let tappedFraction = min(max((xLocation - leftInset) / max(1, plotWidth), 0), 1)
        let tappedRuntime = Double(tappedFraction) * runtime
        return waypointLayouts.firstIndex(where: { $0.endRuntime > tappedRuntime }) ?? levels.count
    }

    private func appendWaypoint() {
        let lastDepth = min(levels.last?.depth ?? 0, plannerMaxDepthMetric)
        levels.append(DiveLevel(depth: lastDepth, time: defaultHoldTime))
    }

    private func deleteWaypoint(id: UUID) {
        guard levels.count > 1, let index = levels.firstIndex(where: { $0.id == id }) else { return }
        levels.remove(at: index)
    }

    private func holdTimeBinding(for id: UUID) -> Binding<Double> {
        Binding(
            get: { levels.first(where: { $0.id == id })?.time ?? 0 },
            set: { newValue in
                guard let index = levels.firstIndex(where: { $0.id == id }) else { return }
                levels[index].time = max(0, newValue)
            }
        )
    }

    private func depthLabel(for metricDepth: Double) -> String {
        let displayDepth = unitSystem.depth(metricDepth)
        return unitSystem == .metric
            ? "\(Int(displayDepth.rounded())) m"
            : "\(Int(displayDepth.rounded())) ft"
    }

    private var chartMaxDepthMetric: Double {
        let deepestWaypoint = levels.map(\.depth).max() ?? 0
        let deepestOverlay = decoOverlayPoints.map(\.depth).max() ?? 0
        return min(plannerMaxDepthMetric, max(minimumMetricChartDepth, max(deepestWaypoint, deepestOverlay) + 30))
    }

    private var totalRuntime: Double {
        profilePoints.last?.runtime ?? 0
    }

    private var chartRuntime: Double {
        let overlayRuntime = decoOverlayPoints.last?.runtime ?? 0
        return max(minimumChartRuntime, max(totalRuntime, overlayRuntime) + 30)
    }

    private var waypoints: [DiveLevel] { levels }

    private var waypointLayouts: [WaypointLayout] {
        var currentDepth = 0.0
        var currentRuntime = 0.0
        var layouts: [WaypointLayout] = []

        for level in levels {
            let rate = level.depth >= currentDepth ? descentRate : ascentRate
            let transit = abs(level.depth - currentDepth) / max(rate, 0.1)
            let arrival = currentRuntime + transit
            let end = arrival + max(level.time, 0)
            let handle = arrival + max(level.time, 0) / 2

            layouts.append(
                WaypointLayout(
                    id: level.id,
                    depth: level.depth,
                    arrivalRuntime: arrival,
                    endRuntime: end,
                    handleRuntime: handle
                )
            )

            currentDepth = level.depth
            currentRuntime = end
        }

        return layouts
    }

    private var profilePoints: [RuntimeDepthPoint] {
        var points: [RuntimeDepthPoint] = [RuntimeDepthPoint(runtime: 0, depth: 0)]
        var currentDepth = 0.0
        var currentRuntime = 0.0

        for level in levels {
            let rate = level.depth >= currentDepth ? descentRate : ascentRate
            let transit = abs(level.depth - currentDepth) / max(rate, 0.1)
            let arrival = currentRuntime + transit
            points.append(RuntimeDepthPoint(runtime: arrival, depth: level.depth))

            let end = arrival + max(level.time, 0)
            points.append(RuntimeDepthPoint(runtime: end, depth: level.depth))

            currentDepth = level.depth
            currentRuntime = end
        }

        return deduplicated(points)
    }

    private var decoOverlayPoints: [RuntimeDepthPoint] {
        guard
            let result,
            !result.schedule.isEmpty
        else { return [] }

        var points: [RuntimeDepthPoint] = []
        let ascentStartRuntime = max(profilePoints.last?.runtime ?? 0, result.bottomRuntime)
        let ascentStartDepth = levels.last?.depth ?? 0
        points.append(RuntimeDepthPoint(runtime: ascentStartRuntime, depth: ascentStartDepth))

        for stop in result.schedule {
            let arrivalRuntime = max(ascentStartRuntime, stop.runtime - stop.stopTime)
            points.append(RuntimeDepthPoint(runtime: arrivalRuntime, depth: stop.depth))
            points.append(RuntimeDepthPoint(runtime: stop.runtime, depth: stop.depth))
        }

        if let lastStop = result.schedule.last, result.totalRuntime > lastStop.runtime {
            points.append(RuntimeDepthPoint(runtime: result.totalRuntime, depth: 0))
        }

        return deduplicated(points)
    }

    private func deduplicated(_ points: [RuntimeDepthPoint]) -> [RuntimeDepthPoint] {
        var result: [RuntimeDepthPoint] = []
        for point in points {
            if let last = result.last, abs(last.runtime - point.runtime) < 0.0001, abs(last.depth - point.depth) < 0.0001 {
                continue
            }
            result.append(point)
        }
        return result
    }
}

private struct RuntimeDepthPoint: Equatable {
    let runtime: Double
    let depth: Double
}

private struct WaypointLayout: Identifiable {
    let id: UUID
    let depth: Double
    let arrivalRuntime: Double
    let endRuntime: Double
    let handleRuntime: Double
}
