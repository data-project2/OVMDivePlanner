// DivePlanner.swift
// Full dive planning engine — direct Swift port of planner.js
// Supports OC & CCR, multi-level, trimix, repetitive dives, CNS/OTU

import Foundation

private let STOP_INCREMENT = 3.0
private let DECO_CHECK_STEP = 20.0 / 60.0

// MARK: - Helper functions

func depthToPressure(_ depth: Double, _ surfP: Double, _ wdf: Double) -> Double {
    surfP + depth * wdf / 10.0
}

func pressureToDepth(_ pressure: Double, _ surfP: Double, _ wdf: Double) -> Double {
    (pressure - surfP) * 10.0 / wdf
}

func ceilToStop(_ depth: Double) -> Double {
    (depth / STOP_INCREMENT).rounded(.up) * STOP_INCREMENT
}

func ccrGasFractions(setpoint: Double, dilO2: Double, dilHe: Double, ambient: Double) -> (fO2: Double, fN2: Double, fHe: Double) {
    let ppO2 = min(setpoint, ambient)
    let dilN2 = 1.0 - dilO2 - dilHe
    let inertTotal = dilN2 + dilHe
    let ppInert = ambient - ppO2
    let fN2 = inertTotal > 0 ? (dilN2 / inertTotal) * (ppInert / ambient) : 0.0
    let fHe = inertTotal > 0 ? (dilHe / inertTotal) * (ppInert / ambient) : 0.0
    return (fO2: ppO2 / ambient, fN2: fN2, fHe: fHe)
}

struct PreparedGas {
    let fO2: Double
    let fHe: Double
    let fN2: Double
    let mod: Double
    let label: String
}

func bestGasAtDepth(_ gases: [PreparedGas], _ depth: Double, _ bottom: (fO2: Double, fHe: Double)) -> (fO2: Double, fHe: Double) {
    var best = bottom
    for gas in gases {
        if depth <= gas.mod && gas.fO2 >= best.fO2 {
            best = (gas.fO2, gas.fHe)
        }
    }
    return best
}

func computeMOD(_ fO2: Double, _ ppO2Max: Double, _ wdf: Double) -> Double {
    ((ppO2Max / fO2) - 1.0) * 10.0 / wdf
}

func cnsLimit(_ ppO2: Double) -> Double {
    if ppO2 <= 0.60 { return .infinity }
    if ppO2 <= 0.70 { return 150 }
    if ppO2 <= 0.80 { return 120 }
    if ppO2 <= 0.90 { return 90 }
    if ppO2 <= 1.00 { return 75 }
    if ppO2 <= 1.10 { return 65 }
    if ppO2 <= 1.20 { return 51 }
    if ppO2 <= 1.30 { return 45 }
    if ppO2 <= 1.40 { return 36 }
    if ppO2 <= 1.50 { return 24 }
    return 15
}

func otuDose(_ ppO2: Double, _ time: Double) -> Double {
    guard ppO2 > 0.5 else { return 0 }
    return time * pow((ppO2 - 0.5) / 0.5, 0.83)
}

// MARK: - planDive

func planDive(input: DivePlanInput, initialTissues: TissueState? = nil,
              initialCNS: Double = 0, initialOTU: Double = 0) -> DiveResultData {
    let wdf = input.waterType.densityFactor
    let surfP = input.surfacePressure
    let gfL = input.gfLow / 100.0
    let gfH = input.gfHigh / 100.0
    let lastStop = input.lastStopDepth
    let ppO2DecoLimit = 1.6
    let ppO2BottomWarn = 1.4

    var warnings: [String] = []
    var cnsPct = initialCNS
    var otuTotal = initialOTU
    var depthTimeProduct = 0.0
    var gasUsageDict: [String: Double] = [:]

    let preparedDeco: [PreparedGas] = input.decoGases.map { gas in
        let mod = gas.switchDepth ?? floor(computeMOD(gas.fO2, ppO2DecoLimit, wdf))
        let pSwitch = depthToPressure(mod, surfP, wdf)
        let pp = pSwitch * gas.fO2
        if pp > ppO2DecoLimit {
            warnings.append("\(gasLabel(fO2: gas.fO2, fHe: gas.fHe)) at \(Int(mod))m: ppO₂ \(String(format: "%.2f", pp)) exceeds \(ppO2DecoLimit)!")
        }
        return PreparedGas(fO2: gas.fO2, fHe: gas.fHe, fN2: gas.fN2, mod: mod, label: gasLabel(fO2: gas.fO2, fHe: gas.fHe))
    }.sorted { $0.mod > $1.mod }

    let maxDepth = input.levels.map(\.depth).max() ?? 0

    if input.circuitType == .oc {
        let ppBot = depthToPressure(maxDepth, surfP, wdf) * input.bottomGas.fO2
        if ppBot > ppO2BottomWarn {
            warnings.append("Bottom mix ppO₂ at \(Int(maxDepth))m is \(String(format: "%.2f", ppBot)) bar (limit \(ppO2BottomWarn)).")
        }
        if input.bottomGas.fO2 < 0.16 {
            warnings.append("Bottom mix is hypoxic at surface (\(Int(input.bottomGas.fO2 * 100))% O₂).")
        }
    }

    let tissues = initialTissues?.clone() ?? TissueState(surfacePressure: surfP)
    var runtime = 0.0
    var bottomRuntime = 0.0
    var schedule: [DecoStop] = []

    func getGas(_ ambient: Double, _ depth: Double, _ phase: String) -> (fO2: Double, fN2: Double, fHe: Double) {
        if input.circuitType == .ccr {
            let setpoint: Double
            if phase == "deco" || phase == "ascent_deco" {
                setpoint = input.setpointDeco
            } else {
                setpoint = depth >= input.setpointSwitchDepth ? input.setpointHigh : input.setpointLow
            }
            let gas = ccrGasFractions(setpoint: setpoint, dilO2: input.diluent.fO2, dilHe: input.diluent.fHe, ambient: ambient)
            return (gas.fO2, gas.fN2, gas.fHe)
        }

        if phase == "deco" || phase == "ascent_deco" {
            let best = bestGasAtDepth(preparedDeco, depth, (input.bottomGas.fO2, input.bottomGas.fHe))
            return (best.fO2, 1.0 - best.fO2 - best.fHe, best.fHe)
        }

        return (input.bottomGas.fO2, input.bottomGas.fN2, input.bottomGas.fHe)
    }

    func gasLabelFor(_ fO2: Double, _ fHe: Double, _ depth: Double) -> String {
        if input.circuitType == .ccr {
            let ambient = depthToPressure(depth, surfP, wdf)
            return String(format: "ppO₂ %.2f", min(ambient * fO2, ambient))
        }
        return gasLabel(fO2: fO2, fHe: fHe)
    }

    func ppO2At(_ depth: Double, _ phase: String) -> Double {
        let ambient = depthToPressure(depth, surfP, wdf)
        let gas = getGas(ambient, depth, phase)
        return ambient * gas.fO2
    }

    func addUsage(_ label: String, _ avgDepth: Double, _ time: Double, _ sac: Double) {
        guard input.circuitType == .oc, time > 0 else { return }
        let ambient = depthToPressure(avgDepth, surfP, wdf)
        gasUsageDict[label, default: 0] += sac * ambient * time
    }

    func trackSeg(_ avgDepth: Double, _ time: Double, _ ppO2: Double) {
        guard time > 0 else { return }
        let limit = cnsLimit(ppO2)
        if limit.isFinite { cnsPct += (time / limit) * 100 }
        otuTotal += otuDose(ppO2, time)
        depthTimeProduct += avgDepth * time
    }

    func applySegDepthChange(_ d1: Double, _ d2: Double, _ rate: Double, _ phase: String) {
        let steps = input.circuitType == .ccr ? max(1, Int(abs(d1 - d2).rounded())) : 1
        let dStep = (d2 - d1) / Double(steps)
        let tStep = abs(dStep) / rate

        for step in 0..<steps {
            let startDepth = d1 + Double(step) * dStep
            let endDepth = d1 + Double(step + 1) * dStep
            let p1 = depthToPressure(startDepth, surfP, wdf)
            let p2 = depthToPressure(endDepth, surfP, wdf)
            let gas = getGas(p1, startDepth, phase)
            tissues.applyDepthChange(pStart: p1, pEnd: p2, time: tStep, fN2: gas.fN2, fHe: gas.fHe)
        }
    }

    var currentDepth = 0.0
    let bottomLabel = gasLabel(fO2: input.bottomGas.fO2, fHe: input.bottomGas.fHe)

    for level in input.levels {

        let diff = abs(level.depth - currentDepth)

        let isDescent = level.depth > currentDepth

        var remainingLevelTime = level.time

        if diff > 0 {

            let rate = isDescent ? input.descentRate : input.ascentRate

            let transitTime = diff / rate

            applySegDepthChange(currentDepth, level.depth, rate, "bottom")

            runtime += transitTime

            let midDepth = (currentDepth + level.depth) / 2

            addUsage(bottomLabel, midDepth, transitTime, input.sacBottom)

            trackSeg(midDepth, transitTime, ppO2At(midDepth, "bottom"))

            if isDescent && input.transitInclusive {

                remainingLevelTime = max(0, level.time - transitTime)

                if transitTime > level.time {

                    warnings.append("Transit to \(Int(level.depth))m (\(String(format: "%.1f", transitTime)) min) exceeds level time (\(String(format: "%.1f", level.time)) min).")

                }

            }

        }

        if remainingLevelTime > 0 {

            let ambient = depthToPressure(level.depth, surfP, wdf)

            let gas = getGas(ambient, level.depth, "bottom")

            tissues.applyConstant(ambient: ambient, fN2: gas.fN2, fHe: gas.fHe, time: remainingLevelTime)

            runtime += remainingLevelTime

            addUsage(bottomLabel, level.depth, remainingLevelTime, input.sacBottom)

            trackSeg(level.depth, remainingLevelTime, ppO2At(level.depth, "bottom"))

        }

        currentDepth = level.depth

    }

    bottomRuntime = runtime

    let bailoutTissues = input.circuitType == .ccr ? tissues.clone() : nil

    let ascentStartDepth = currentDepth

    var firstStopDepth = 0.0
    while currentDepth > 0 {
        let ceilingBar = tissues.ceiling(gf: gfL)
        let ceilM = pressureToDepth(ceilingBar, surfP, wdf)
        let ceilStop = ceilToStop(max(0, ceilM))
        if ceilStop >= currentDepth {
            firstStopDepth = ceilToStop(currentDepth)
            break
        }

        let snapped = max(0.0, (ceil((currentDepth - 0.001) / STOP_INCREMENT) - 1) * STOP_INCREMENT)
        let stepEnd = max(0.0, snapped)
        let stepDist = currentDepth - stepEnd
        if stepDist <= 0 { break }
        let stepTime = stepDist / input.ascentRate
        applySegDepthChange(currentDepth, stepEnd, input.ascentRate, "ascent_deco")
        runtime += stepTime
        let midDepth = (currentDepth + stepEnd) / 2
        let ascentGas = getGas(depthToPressure(midDepth, surfP, wdf), midDepth, "ascent_deco")
        addUsage(gasLabelFor(ascentGas.fO2, ascentGas.fHe, midDepth), midDepth, stepTime, input.sacDeco)
        trackSeg(midDepth, stepTime, ppO2At(midDepth, "ascent_deco"))
        currentDepth = stepEnd
    }

    func gfAtDepth(_ stopDepth: Double) -> Double {
        if firstStopDepth <= 0 { return gfH }
        if stopDepth >= firstStopDepth { return gfL }
        if stopDepth <= 0 { return gfH }
        return gfH - (gfH - gfL) * (stopDepth / firstStopDepth)
    }

    if firstStopDepth > 0 {
        var stopDepth = firstStopDepth
        while stopDepth >= lastStop {
            let stopAmbient = depthToPressure(stopDepth, surfP, wdf)
            let gf = gfAtDepth(stopDepth)
            let gas = getGas(stopAmbient, stopDepth, "deco")
            let gasName = gasLabelFor(gas.fO2, gas.fHe, stopDepth)
            let isLast = stopDepth == lastStop
            var stopTime = 0.0

            while true {
                let clearanceGF = isLast ? gfH : gf
                let ceilingBar = tissues.ceiling(gf: clearanceGF)
                let ceilingDepth = pressureToDepth(ceilingBar, surfP, wdf)
                let nextAllowedDepth = isLast ? 0.0 : stopDepth - STOP_INCREMENT
                if ceilingDepth <= nextAllowedDepth { break }
                tissues.applyConstant(ambient: stopAmbient, fN2: gas.fN2, fHe: gas.fHe, time: DECO_CHECK_STEP)
                stopTime += DECO_CHECK_STEP
                runtime += DECO_CHECK_STEP
                if stopTime > 999 {
                    warnings.append("Stop at \(Int(stopDepth))m exceeded 999 min.")
                    break
                }
            }

            if stopTime > 0 {
                schedule.append(DecoStop(depth: stopDepth, stopTime: ceil(stopTime), runtime: ceil(runtime), gas: gasName))
                addUsage(gasName, stopDepth, stopTime, input.sacDeco)
                trackSeg(stopDepth, stopTime, ppO2At(stopDepth, "deco"))
            }

            if stopDepth > lastStop {
                let nextDepth = stopDepth - STOP_INCREMENT
                let travelTime = STOP_INCREMENT / input.ascentRate
                applySegDepthChange(stopDepth, nextDepth, input.ascentRate, "deco")
                runtime += travelTime
                let ascentGas = getGas(stopAmbient, stopDepth, "deco")
                addUsage(gasLabelFor(ascentGas.fO2, ascentGas.fHe, stopDepth), (stopDepth + nextDepth) / 2, travelTime, input.sacDeco)
                trackSeg((stopDepth + nextDepth) / 2, travelTime, ppO2At((stopDepth + nextDepth) / 2, "deco"))
                currentDepth = nextDepth
            }

            stopDepth -= STOP_INCREMENT
        }
    }

    if currentDepth > 0 {
        let travelTime = currentDepth / input.ascentRate
        applySegDepthChange(currentDepth, 0, input.ascentRate, "deco")
        runtime += travelTime
        let finalGas = getGas(depthToPressure(currentDepth, surfP, wdf), currentDepth, "deco")
        addUsage(gasLabelFor(finalGas.fO2, finalGas.fHe, currentDepth), currentDepth / 2, travelTime, input.sacDeco)
        trackSeg(currentDepth / 2, travelTime, ppO2At(currentDepth / 2, "deco"))
    }

    let surfaceCeiling = tissues.ceiling(gf: gfH)
    if surfaceCeiling > surfP + 0.01 {
        warnings.append("Ceiling at surface is \(String(format: "%.1f", pressureToDepth(surfaceCeiling, surfP, wdf)))m — tissues still supersaturated!")
    }

    let totalStopTime = schedule.reduce(0) { $0 + $1.stopTime }
    let gasEntries = gasUsageDict.map { GasUsageEntry(label: $0.key, litres: $0.value) }
        .sorted { $0.label < $1.label }
    let averageDepth = runtime > 0 ? (depthTimeProduct / runtime * 10).rounded() / 10 : 0

    var bailout: BailoutResultData? = nil
    if input.circuitType == .ccr, let bailoutSource = bailoutTissues {
        bailout = computeBailout(
            tissues: bailoutSource,
            depth: ascentStartDepth,
            preparedDeco: preparedDeco,
            diluent: input.diluent,
            surfP: surfP,
            wdf: wdf,
            ascentRate: input.ascentRate,
            gfL: gfL,
            gfH: gfH,
            sacBottom: input.sacBottom,
            sacDeco: input.sacDeco,
            lastStop: lastStop
        )
    }

    return DiveResultData(
        schedule: schedule,
        maxDepth: maxDepth,
        totalStopTime: totalStopTime,
        totalRuntime: ceil(runtime),
        bottomRuntime: ceil(bottomRuntime),
        firstStopDepth: schedule.first?.depth ?? 0,
        averageDepth: averageDepth,
        cnsPct: (cnsPct * 10).rounded() / 10,
        otuTotal: otuTotal.rounded(),
        gasUsage: gasEntries,
        bailout: bailout,
        warnings: warnings,
        finalTissues: tissues,
        finalCNS: (cnsPct * 10).rounded() / 10,
        finalOTU: otuTotal.rounded()
    )
}

// MARK: - Surface interval

func applySurfaceInterval(tissues: TissueState, interval: Double, surfP: Double) -> TissueState {
    let copy = tissues.clone()
    if interval > 0 {
        copy.applyConstant(ambient: surfP, fN2: 0.7902, fHe: 0, time: interval)
    }
    return copy
}

// MARK: - Bailout

func computeBailout(tissues: TissueState, depth: Double, preparedDeco: [PreparedGas],
                    diluent: GasMix, surfP: Double, wdf: Double, ascentRate: Double,
                    gfL: Double, gfH: Double, sacBottom: Double, sacDeco: Double,
                    lastStop: Double) -> BailoutResultData {
    let bottom = (fO2: diluent.fO2, fHe: diluent.fHe)
    let botFN2 = 1.0 - bottom.fO2 - bottom.fHe

    var schedule: [DecoStop] = []
    var warnings: [String] = []
    var gasUsageDict: [String: Double] = [:]
    var runtime = 0.0
    var cnsPct = 0.0
    var otuTotal = 0.0
    var depthTP = 0.0

    func getGas(_ depth: Double, _ phase: String) -> (fO2: Double, fN2: Double, fHe: Double, label: String) {
        if phase == "deco" || phase == "ascent_deco" {
            let best = bestGasAtDepth(preparedDeco, depth, bottom)
            return (best.fO2, 1 - best.fO2 - best.fHe, best.fHe, gasLabel(fO2: best.fO2, fHe: best.fHe))
        }
        return (bottom.fO2, botFN2, bottom.fHe, gasLabel(fO2: bottom.fO2, fHe: bottom.fHe))
    }

    func addUsage(_ label: String, _ depth: Double, _ time: Double, _ sac: Double) {
        guard time > 0 else { return }
        gasUsageDict[label, default: 0] += sac * depthToPressure(depth, surfP, wdf) * time
    }

    func trackSeg(_ depth: Double, _ time: Double, _ fO2: Double) {
        guard time > 0 else { return }
        let pp = depthToPressure(depth, surfP, wdf) * fO2
        let limit = cnsLimit(pp)
        if limit.isFinite { cnsPct += (time / limit) * 100 }
        otuTotal += otuDose(pp, time)
        depthTP += depth * time
    }

    func applyChange(_ d1: Double, _ d2: Double, _ rate: Double, _ phase: String) -> (time: Double, label: String) {
        let steps = max(1, Int((abs(d1 - d2) / STOP_INCREMENT).rounded()))
        let dStep = (d2 - d1) / Double(steps)
        let totalTime = abs(d1 - d2) / rate
        let tStep = totalTime / Double(steps)
        var lastLabel = ""

        for step in 0..<steps {
            let startDepth = d1 + Double(step) * dStep
            let endDepth = d1 + Double(step + 1) * dStep
            let p1 = depthToPressure(startDepth, surfP, wdf)
            let p2 = depthToPressure(endDepth, surfP, wdf)
            let gas = getGas(startDepth, phase)
            tissues.applyDepthChange(pStart: p1, pEnd: p2, time: tStep, fN2: gas.fN2, fHe: gas.fHe)
            lastLabel = gas.label
        }

        return (totalTime, lastLabel)
    }

    var firstStopDepth = 0.0
    var currentDepth = depth

    while currentDepth > 0 {
        let ceilBar = tissues.ceiling(gf: gfL)
        let ceilM = pressureToDepth(ceilBar, surfP, wdf)
        let ceilStop = ceilToStop(max(0, ceilM))
        if ceilStop >= currentDepth {
            firstStopDepth = ceilToStop(currentDepth)
            break
        }

        let nextDepth = max(0.0, ceil((currentDepth - 0.001) / STOP_INCREMENT - 1) * STOP_INCREMENT)
        let dist = currentDepth - nextDepth
        if dist <= 0 { break }
        let (travelTime, label) = applyChange(currentDepth, nextDepth, ascentRate, "ascent_deco")
        runtime += travelTime
        addUsage(label, (currentDepth + nextDepth) / 2, travelTime, sacDeco)
        trackSeg((currentDepth + nextDepth) / 2, travelTime, getGas(currentDepth, "ascent_deco").fO2)
        currentDepth = nextDepth
    }

    func gfAtDepth(_ stopDepth: Double) -> Double {
        if firstStopDepth <= 0 { return gfH }
        if stopDepth >= firstStopDepth { return gfL }
        if stopDepth <= 0 { return gfH }
        return gfH - (gfH - gfL) * (stopDepth / firstStopDepth)
    }

    if firstStopDepth > 0 {
        var stopDepth = firstStopDepth
        while stopDepth >= lastStop {
            let stopAmbient = depthToPressure(stopDepth, surfP, wdf)
            let gf = gfAtDepth(stopDepth)
            let gas = getGas(stopDepth, "deco")
            let isLast = stopDepth == lastStop
            var stopTime = 0.0

            while true {
                let clearanceGF = isLast ? gfH : gf
                let ceilDepth = pressureToDepth(tissues.ceiling(gf: clearanceGF), surfP, wdf)
                let nextAllowedDepth = isLast ? 0.0 : stopDepth - STOP_INCREMENT
                if ceilDepth <= nextAllowedDepth { break }
                tissues.applyConstant(ambient: stopAmbient, fN2: gas.fN2, fHe: gas.fHe, time: DECO_CHECK_STEP)
                stopTime += DECO_CHECK_STEP
                runtime += DECO_CHECK_STEP
                if stopTime > 999 {
                    warnings.append("Bailout stop at \(Int(stopDepth))m exceeded 999 min.")
                    break
                }
            }

            if stopTime > 0 {
                schedule.append(DecoStop(depth: stopDepth, stopTime: ceil(stopTime), runtime: ceil(runtime), gas: gas.label))
                addUsage(gas.label, stopDepth, stopTime, sacDeco)
                trackSeg(stopDepth, stopTime, gas.fO2)
            }

            if stopDepth > lastStop {
                let nextDepth = stopDepth - STOP_INCREMENT
                let (travelTime, label) = applyChange(stopDepth, nextDepth, ascentRate, "deco")
                runtime += travelTime
                addUsage(label, (stopDepth + nextDepth) / 2, travelTime, sacDeco)
                trackSeg((stopDepth + nextDepth) / 2, travelTime, getGas(stopDepth, "deco").fO2)
                currentDepth = nextDepth
            }

            stopDepth -= STOP_INCREMENT
        }
    }

    if currentDepth > 0 {
        let (travelTime, label) = applyChange(currentDepth, 0, ascentRate, "deco")
        runtime += travelTime
        addUsage(label, currentDepth / 2, travelTime, sacDeco)
        trackSeg(currentDepth / 2, travelTime, getGas(currentDepth, "deco").fO2)
    }

    let gasEntries = gasUsageDict.map { GasUsageEntry(label: $0.key, litres: $0.value) }.sorted { $0.label < $1.label }
    let averageDepth = runtime > 0 ? (depthTP / runtime * 10).rounded() / 10 : 0

    return BailoutResultData(
        schedule: schedule,
        totalStopTime: schedule.reduce(0) { $0 + $1.stopTime },
        totalRuntime: ceil(runtime),
        firstStopDepth: firstStopDepth,
        averageDepth: averageDepth,
        cnsPct: (cnsPct * 10).rounded() / 10,
        otuTotal: otuTotal.rounded(),
        gasUsage: gasEntries,
        warnings: warnings
    )
}
