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

    // MARK: – Published inputs

    @Published var circuitType: CircuitType = .oc
    @Published var waterType: WaterType = .salt
    @Published var levels: [DiveLevel] = [DiveLevel(depth: 30, time: 20)]
    @Published var bottomGas: GasMix = GasMix.air
    @Published var decoGases: [GasMix] = []

    // CCR
    @Published var diluent: GasMix = GasMix.air
    @Published var setpointLow: Double = 0.7
    @Published var setpointHigh: Double = 1.3
    @Published var setpointDeco: Double = 1.6
    @Published var setpointSwitchDepth: Double = 6

    // Settings
    @Published var gfLow: Double = 35
    @Published var gfHigh: Double = 70
    @Published var descentRate: Double = 20
    @Published var ascentRate: Double = 9
    @Published var sacBottom: Double = 20
    @Published var sacDeco: Double = 15
    @Published var lastStopDepth: Double = 3
    @Published var surfacePressure: Double = 1.0
    @Published var transitInclusive: Bool = true

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

    // MARK: – Calculate

    func calculate() {
        isCalculating = true
        errorMessage = nil
        results = nil
        results2 = nil

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
}
