import Foundation
import Testing
@testable import OVMDivePlanner

@Suite("OVM Dive Planner Validation")
struct OVMDivePlannerTests {
    @Test("Depth and pressure conversions round-trip")
    func depthPressureRoundTrip() {
        let pressure = depthToPressure(30, 1.0, 1.025)
        #expect(abs(pressureToDepth(pressure, 1.0, 1.025) - 30) < 0.0001)
    }

    @Test("Open-circuit recreational profile produces a finite runtime")
    func noDecoRuntimeIsFinite() {
        let input = DivePlanInput(
            levels: [DiveLevel(depth: 18, time: 20)],
            ascentRate: 9,
            transitInclusive: false,
            bottomGas: .air,
            surfacePressure: 1.0,
            gfLow: 35,
            gfHigh: 70,
            lastStopDepth: 6
        )

        let result = planDive(input: input)

        #expect(result.totalRuntime > 0)
        #expect(!result.warnings.contains { $0.contains("exceeded 999") })
    }

    @Test("Hypoxic open-circuit bottom gas raises a warning")
    func hypoxicBottomGasWarning() {
        let input = DivePlanInput(
            levels: [DiveLevel(depth: 30, time: 20)],
            bottomGas: GasMix(fO2: 0.12, fHe: 0.45),
            surfacePressure: 1.0
        )

        let result = planDive(input: input)

        #expect(result.warnings.contains { $0.localizedCaseInsensitiveContains("hypoxic") })
    }

    @Test("Unsafe manual deco switch depth raises a ppO2 warning")
    func manualSwitchDepthWarning() {
        let input = DivePlanInput(
            levels: [DiveLevel(depth: 45, time: 25)],
            decoGases: [GasMix(fO2: 1.0, fHe: 0, switchDepth: 9)],
            surfacePressure: 1.0
        )

        let result = planDive(input: input)

        #expect(result.warnings.contains { $0.contains("ppO₂") && $0.contains("exceeds 1.6") })
    }

    @Test("CCR bailout schedule remains bounded")
    func ccrBailoutRuntimeIsBounded() {
        let input = DivePlanInput(
            circuitType: .ccr,
            levels: [DiveLevel(depth: 40, time: 25)],
            ascentRate: 9,
            transitInclusive: false,
            bottomGas: .air,
            decoGases: [
                GasMix(fO2: 0.50, fHe: 0),
                GasMix(fO2: 1.00, fHe: 0)
            ],
            surfacePressure: 1.0,
            gfLow: 35,
            gfHigh: 70,
            lastStopDepth: 6,
            setpointHigh: 1.3,
            setpointSwitchDepth: 6,
            setpointDeco: 1.6,
            diluent: .air
        )

        let result = planDive(input: input)

        #expect(result.bailout != nil)
        #expect(!(result.bailout?.warnings.contains { $0.contains("exceeded 999") } ?? true))
        #expect((result.bailout?.totalRuntime ?? 1_000) < 1_000)
    }

    @Test("Imperial normalization preserves displayed values")
    func imperialNormalizationPreservesDisplayedValues() {
        let metricDepth = UnitSystem.imperial.normalizeMetricProfileDepth(UnitSystem.imperial.metricDepth(100))
        let metricSwitchDepth = UnitSystem.imperial.normalizeMetricSwitchDepth(UnitSystem.imperial.metricDepth(101))
        let metricRate = UnitSystem.imperial.normalizeMetricRate(UnitSystem.imperial.metricRate(35))
        let metricVolume = UnitSystem.imperial.normalizeMetricVolume(UnitSystem.imperial.metricVolume(0.5))

        #expect(abs(UnitSystem.imperial.depth(metricDepth) - 100) < 0.0001)
        #expect(abs(UnitSystem.imperial.depth(metricSwitchDepth) - 101) < 0.0001)
        #expect(abs(UnitSystem.imperial.rate(metricRate) - 35) < 0.0001)
        #expect(abs(UnitSystem.imperial.volume(metricVolume) - 0.5) < 0.0001)
    }
}
