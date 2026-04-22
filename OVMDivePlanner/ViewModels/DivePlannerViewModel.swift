// DivePlannerViewModel.swift
// ObservableObject managing all dive planning state

import Foundation
import Combine
import SwiftUI

enum PlannerTab: Hashable {
    case plan
    case schedule
    case mixer
    case settings
}

@MainActor
class DivePlannerViewModel: ObservableObject {
    private static let settingsDefaultsKey = "ovm.settings"
    private var isRestoringSettings = false

    // MARK: – Published inputs

    @Published var circuitType: CircuitType = .oc
    @Published var waterType: WaterType = .salt {
        didSet { persistSettings() }
    }
    @Published var unitSystem: UnitSystem = .metric {
        didSet {
            guard oldValue != unitSystem else { return }
            normalizeValuesForUnitSystem()
            persistSettings()
        }
    }
    @Published var levels: [DiveLevel] = [DiveLevel(depth: 30, time: 20)]
    @Published var bottomGas: GasMix = GasMix.air
    @Published var decoGases: [GasMix] = []
    @Published var manualDecoStopExtensions: [String: Double] = [:]

    // CCR
    @Published var diluent: GasMix = GasMix.air
    @Published var setpointLow: Double = 0.7 {
        didSet { persistSettings() }
    }
    @Published var setpointHigh: Double = 1.3 {
        didSet { persistSettings() }
    }
    @Published var setpointDeco: Double = 1.6 {
        didSet { persistSettings() }
    }
    @Published var setpointSwitchDepth: Double = 6 {
        didSet { persistSettings() }
    }

    // Settings
    @Published var gfLow: Double = 35 {
        didSet { persistSettings() }
    }
    @Published var gfHigh: Double = 70 {
        didSet { persistSettings() }
    }
    @Published var descentRate: Double = 20 {
        didSet { persistSettings() }
    }
    @Published var ascentRate: Double = 9 {
        didSet { persistSettings() }
    }
    @Published var sacBottom: Double = 20 {
        didSet { persistSettings() }
    }
    @Published var sacDeco: Double = 15 {
        didSet { persistSettings() }
    }
    @Published var lastStopDepth: Double = 3 {
        didSet { persistSettings() }
    }
    @Published var surfacePressure: Double = 1.013 {
        didSet { persistSettings() }
    }
    @Published var transitInclusive: Bool = true {
        didSet { persistSettings() }
    }

    // Repetitive dive
    @Published var enableRepetitive: Bool = false
    @Published var surfaceInterval: Double = 60
    @Published var levels2: [DiveLevel] = [DiveLevel(depth: 20, time: 30)]
    @Published var bottomGas2: GasMix = GasMix.air
    @Published var decoGases2: [GasMix] = []

    // MARK: – Published output

    @Published var results: DiveResultData? = nil
    @Published var results2: DiveResultData? = nil
    @Published var isCalculating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedTab: PlannerTab = .plan

    init() {
        restoreSettings()
    }

    // MARK: – Calculate

    func calculate() {
        isCalculating = true
        errorMessage = nil
        results = nil
        results2 = nil
        manualDecoStopExtensions = [:]

        let input = buildInput()
        let input2: DivePlanInput? = enableRepetitive ? buildInput(isSecond: true) : nil
        let surfaceInterval = self.surfaceInterval

        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let (r1, r2) = Self.runCalculation(input: input, input2: input2, surfaceInterval: surfaceInterval)
            self.results = r1
            self.results2 = r2
            self.isCalculating = false
        }
    }

    // MARK: – Level helpers

    func addLevel() { levels.append(DiveLevel(depth: levels.last?.depth ?? 30, time: 0)) }
    func removeLevel(at offsets: IndexSet) { if levels.count > 1 { levels.remove(atOffsets: offsets) } }

    func addLevel2() { levels2.append(DiveLevel(depth: levels2.last?.depth ?? 20, time: 0)) }
    func removeLevel2(at offsets: IndexSet) { if levels2.count > 1 { levels2.remove(atOffsets: offsets) } }

    func addDecoGas() { decoGases.append(GasMix(fO2: 0.32, fHe: 0)) }
    func removeDecoGas(at offsets: IndexSet) { decoGases.remove(atOffsets: offsets) }

    func addDecoGas2() { decoGases2.append(GasMix(fO2: 0.32, fHe: 0)) }
    func removeDecoGas2(at offsets: IndexSet) { decoGases2.remove(atOffsets: offsets) }

    func resetManualDeco() {
        guard !manualDecoStopExtensions.isEmpty else { return }
        manualDecoStopExtensions = [:]
        recalculateManualDeco()
    }

    func setManualDecoExtension(depth: Double, extraTime: Double) {
        let key = String(Int(depth.rounded()))
        let normalized = max(0, extraTime.rounded())
        let existing = manualDecoStopExtensions[key] ?? 0

        guard existing != normalized else { return }

        if normalized == 0 {
            manualDecoStopExtensions.removeValue(forKey: key)
        } else {
            manualDecoStopExtensions[key] = normalized
        }

        recalculateManualDeco()
    }

    // MARK: – Private helpers

    @MainActor
    private static func runCalculation(
        input: DivePlanInput,
        input2: DivePlanInput?,
        surfaceInterval: Double
    ) -> (DiveResultData, DiveResultData?) {
        let r1 = planDive(input: input)
        var r2: DiveResultData? = nil

        if let inp2 = input2 {
            let tissues = applySurfaceInterval(
                tissues: r1.finalTissues,
                interval: surfaceInterval,
                surfP: input.surfacePressure
            )
            r2 = planDive(
                input: inp2,
                initialTissues: tissues,
                initialCNS: r1.finalCNS,
                initialOTU: r1.finalOTU
            )
        }

        return (r1, r2)
    }

    private func buildInput(isSecond: Bool = false) -> DivePlanInput {
        DivePlanInput(
            circuitType: circuitType,
            levels: isSecond ? levels2 : levels,
            descentRate: descentRate,
            ascentRate: ascentRate,
            transitInclusive: transitInclusive,
            bottomGas: isSecond ? bottomGas2 : bottomGas,
            decoGases: isSecond ? decoGases2 : decoGases,
            manualDecoStopExtensions: isSecond ? [:] : manualDecoStopExtensions,
            waterType: waterType,
            surfacePressure: surfacePressure,
            gfLow: gfLow,
            gfHigh: gfHigh,
            lastStopDepth: lastStopDepth,
            sacBottom: sacBottom,
            sacDeco: sacDeco,
            setpointLow: setpointLow,
            setpointHigh: setpointHigh,
            setpointSwitchDepth: setpointSwitchDepth,
            setpointDeco: setpointDeco,
            diluent: isSecond ? bottomGas2 : bottomGas
        )
    }

    private func normalizeValuesForUnitSystem() {
        levels = levels.map(normalize)
        levels2 = levels2.map(normalize)
        decoGases = decoGases.map(normalize)
        decoGases2 = decoGases2.map(normalize)
        setpointSwitchDepth = unitSystem.normalizeMetricSwitchDepth(setpointSwitchDepth)
        descentRate = unitSystem.normalizeMetricRate(descentRate)
        ascentRate = unitSystem.normalizeMetricRate(ascentRate)
        sacBottom = unitSystem.normalizeMetricVolume(sacBottom)
        sacDeco = unitSystem.normalizeMetricVolume(sacDeco)
    }

    private func normalize(_ level: DiveLevel) -> DiveLevel {
        var normalizedLevel = level
        normalizedLevel.depth = unitSystem.normalizeMetricProfileDepth(level.depth)
        return normalizedLevel
    }

    private func normalize(_ gas: GasMix) -> GasMix {
        guard let switchDepth = gas.switchDepth else { return gas }
        return GasMix(
            id: gas.id,
            fO2: gas.fO2,
            fHe: gas.fHe,
            switchDepth: unitSystem.normalizeMetricSwitchDepth(switchDepth)
        )
    }

    private func recalculateManualDeco() {
        guard results != nil else { return }

        isCalculating = true
        let input = buildInput()

        Task(priority: .userInitiated) { [weak self] in
            let recalculated = planDive(input: input)
            await MainActor.run {
                guard let self else { return }
                self.results = recalculated
                self.isCalculating = false
            }
        }
    }

    private func persistSettings() {
        guard !isRestoringSettings else { return }

        let snapshot = PlannerSettingsSnapshot(
            waterType: waterType,
            unitSystem: unitSystem,
            setpointLow: setpointLow,
            setpointHigh: setpointHigh,
            setpointDeco: setpointDeco,
            setpointSwitchDepth: setpointSwitchDepth,
            gfLow: gfLow,
            gfHigh: gfHigh,
            descentRate: descentRate,
            ascentRate: ascentRate,
            sacBottom: sacBottom,
            sacDeco: sacDeco,
            lastStopDepth: lastStopDepth,
            surfacePressure: surfacePressure,
            transitInclusive: transitInclusive
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsDefaultsKey)
    }

    private func restoreSettings() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.settingsDefaultsKey),
            let snapshot = try? JSONDecoder().decode(PlannerSettingsSnapshot.self, from: data)
        else {
            return
        }

        isRestoringSettings = true
        waterType = snapshot.waterType
        unitSystem = snapshot.unitSystem
        setpointLow = snapshot.setpointLow
        setpointHigh = snapshot.setpointHigh
        setpointDeco = snapshot.setpointDeco
        setpointSwitchDepth = snapshot.setpointSwitchDepth
        gfLow = snapshot.gfLow
        gfHigh = snapshot.gfHigh
        descentRate = snapshot.descentRate
        ascentRate = snapshot.ascentRate
        sacBottom = snapshot.sacBottom
        sacDeco = snapshot.sacDeco
        lastStopDepth = snapshot.lastStopDepth
        surfacePressure = snapshot.surfacePressure
        transitInclusive = snapshot.transitInclusive
        isRestoringSettings = false

        normalizeValuesForUnitSystem()
    }
}

private struct PlannerSettingsSnapshot: Codable {
    let waterType: WaterType
    let unitSystem: UnitSystem
    let setpointLow: Double
    let setpointHigh: Double
    let setpointDeco: Double
    let setpointSwitchDepth: Double
    let gfLow: Double
    let gfHigh: Double
    let descentRate: Double
    let ascentRate: Double
    let sacBottom: Double
    let sacDeco: Double
    let lastStopDepth: Double
    let surfacePressure: Double
    let transitInclusive: Bool
}
