import XCTest
@testable import OVMDivePlanner

final class DivePlannerTests: XCTestCase {
    func testDepthPressureRoundTrip() {
        let pressure = depthToPressure(30, 1.0, 1.025)
        XCTAssertEqual(pressureToDepth(pressure, 1.0, 1.025), 30, accuracy: 0.0001)
    }

    func testBestGasChoosesHighestSafeOxygenAtDepth() {
        let gases = [
            PreparedGas(fO2: 0.50, fHe: 0, fN2: 0.50, mod: 21, label: "EAN50"),
            PreparedGas(fO2: 1.00, fHe: 0, fN2: 0.00, mod: 6, label: "O2")
        ]

        let gasAt21 = bestGasAtDepth(gases, 21, (fO2: 0.21, fHe: 0))
        let gasAt6 = bestGasAtDepth(gases, 6, (fO2: 0.21, fHe: 0))

        XCTAssertEqual(gasAt21.fO2, 0.50, accuracy: 0.0001)
        XCTAssertEqual(gasAt6.fO2, 1.00, accuracy: 0.0001)
    }

    func testNoDecoRecreationalDiveProducesFiniteRuntime() {
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

        XCTAssertTrue(result.totalRuntime > 0)
        XCTAssertFalse(result.warnings.contains { $0.contains("exceeded 999") })
    }

    func testCCRBailoutDoesNotRunAwayAtLastStop() {
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

        XCTAssertFalse(result.bailout?.warnings.contains { $0.contains("exceeded 999") } ?? true)
        XCTAssertLessThan(result.bailout?.totalRuntime ?? 1_000, 1_000)
    }

    func testImperialProfileDepthNormalizationPreservesDisplayedStep() {
        let metricDepth = UnitSystem.imperial.normalizeMetricProfileDepth(UnitSystem.imperial.metricDepth(100))
        XCTAssertEqual(UnitSystem.imperial.depth(metricDepth), 100, accuracy: 0.0001)
    }

    func testImperialSwitchDepthNormalizationPreservesDisplayedValue() {
        let metricDepth = UnitSystem.imperial.normalizeMetricSwitchDepth(UnitSystem.imperial.metricDepth(101))
        XCTAssertEqual(UnitSystem.imperial.depth(metricDepth), 101, accuracy: 0.0001)
    }

    func testImperialRateAndVolumeNormalizationPreserveDisplayedSteps() {
        let metricRate = UnitSystem.imperial.normalizeMetricRate(UnitSystem.imperial.metricRate(35))
        let metricVolume = UnitSystem.imperial.normalizeMetricVolume(UnitSystem.imperial.metricVolume(0.5))

        XCTAssertEqual(UnitSystem.imperial.rate(metricRate), 35, accuracy: 0.0001)
        XCTAssertEqual(UnitSystem.imperial.volume(metricVolume), 0.5, accuracy: 0.0001)
    }

    func testManualDecoExtensionIncreasesSelectedStopAndRuntime() throws {
        let baseInput = DivePlanInput(
            circuitType: .oc,
            levels: [DiveLevel(depth: 45, time: 25)],
            descentRate: 20,
            ascentRate: 9,
            transitInclusive: true,
            bottomGas: GasMix(fO2: 0.18, fHe: 0.35),
            decoGases: [
                GasMix(fO2: 0.50, fHe: 0),
                GasMix(fO2: 1.00, fHe: 0)
            ],
            waterType: .salt,
            surfacePressure: 1.013,
            gfLow: 35,
            gfHigh: 70,
            lastStopDepth: 3,
            sacBottom: 20,
            sacDeco: 15
        )

        let autoResult = planDive(input: baseInput)
        let stopToExtend = try XCTUnwrap(autoResult.schedule.first)

        var extendedInput = baseInput
        extendedInput.manualDecoStopExtensions = [String(Int(stopToExtend.depth.rounded())): 3]

        let extendedResult = planDive(input: extendedInput)
        let extendedStop = try XCTUnwrap(extendedResult.schedule.first(where: {
            abs($0.depth - stopToExtend.depth) < 0.0001
        }))

        XCTAssertEqual(extendedStop.autoStopTime, stopToExtend.stopTime, accuracy: 0.0001)
        XCTAssertEqual(extendedStop.extraTime, 3, accuracy: 0.0001)
        XCTAssertEqual(extendedStop.stopTime, stopToExtend.stopTime + 3, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(extendedResult.totalRuntime, autoResult.totalRuntime + 3)
    }

    func testZeroManualDecoExtensionMatchesAutoSchedule() {
        let baseInput = DivePlanInput(
            circuitType: .oc,
            levels: [DiveLevel(depth: 45, time: 25)],
            descentRate: 20,
            ascentRate: 9,
            transitInclusive: true,
            bottomGas: GasMix(fO2: 0.18, fHe: 0.35),
            decoGases: [
                GasMix(fO2: 0.50, fHe: 0),
                GasMix(fO2: 1.00, fHe: 0)
            ],
            waterType: .salt,
            surfacePressure: 1.013,
            gfLow: 35,
            gfHigh: 70,
            lastStopDepth: 3,
            sacBottom: 20,
            sacDeco: 15
        )

        let autoResult = planDive(input: baseInput)

        var resetInput = baseInput
        resetInput.manualDecoStopExtensions = ["6": 0]

        let resetResult = planDive(input: resetInput)

        XCTAssertEqual(resetResult.schedule.count, autoResult.schedule.count)
        XCTAssertEqual(resetResult.totalRuntime, autoResult.totalRuntime, accuracy: 0.0001)

        for (resetStop, autoStop) in zip(resetResult.schedule, autoResult.schedule) {
            XCTAssertEqual(resetStop.depth, autoStop.depth, accuracy: 0.0001)
            XCTAssertEqual(resetStop.stopTime, autoStop.stopTime, accuracy: 0.0001)
            XCTAssertEqual(resetStop.autoStopTime, autoStop.autoStopTime, accuracy: 0.0001)
            XCTAssertEqual(resetStop.extraTime, autoStop.extraTime, accuracy: 0.0001)
        }
    }
}
