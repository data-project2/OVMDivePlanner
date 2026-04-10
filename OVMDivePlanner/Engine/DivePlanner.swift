// DivePlanner.swift
// Full dive planning engine — direct Swift port of planner.js
// Supports OC & CCR, multi-level, trimix, repetitive dives, CNS/OTU

import Foundation

private let STOP_INCREMENT = 3.0

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
    let fN2 = inertTotal > 0 ? (dilN2/inertTotal) * (ppInert/ambient) : 0.0
    let fHe = inertTotal > 0 ? (dilHe/inertTotal) * (ppInert/ambient) : 0.0
    return (fO2: ppO2/ambient, fN2: fN2, fHe: fHe)
}

struct PreparedGas {
    let fO2: Double; let fHe: Double; let fN2: Double
    let mod: Double; let label: String
}

func bestGasAtDepth(_ gases: [PreparedGas], _ depth: Double, _ bottom: (fO2: Double, fHe: Double)) -> (fO2: Double, fHe: Double) {
    var best = bottom
    for g in gases {
        if depth <= g.mod && g.fO2 >= best.fO2 { best = (g.fO2, g.fHe) }
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

    // Prepare deco gases
    let preparedDeco: [PreparedGas] = input.decoGases.map { g in
        let mod = g.switchDepth ?? floor(computeMOD(g.fO2, ppO2DecoLimit, wdf))
        let pSwitch = depthToPressure(mod, surfP, wdf)
        let pp = pSwitch * g.fO2
        if pp > ppO2DecoLimit {
            warnings.append("\(gasLabel(fO2: g.fO2, fHe: g.fHe)) at \(Int(mod))m: ppO₂ \(String(format:"%.2f",pp)) exceeds \(ppO2DecoLimit)!")
        }
        return PreparedGas(fO2: g.fO2, fHe: g.fHe, fN2: g.fN2, mod: mod, label: gasLabel(fO2: g.fO2, fHe: g.fHe))
    }.sorted { $0.mod > $1.mod }

    let maxDepth = input.levels.map(\.depth).max() ?? 0

    // Bottom gas ppO2 warnings
    if input.circuitType == .oc {
        let ppBot = depthToPressure(maxDepth, surfP, wdf) * input.bottomGas.fO2
        if ppBot > ppO2BottomWarn {
            warnings.append("Bottom mix ppO₂ at \(Int(maxDepth))m is \(String(format:"%.2f",ppBot)) bar (limit \(ppO2BottomWarn)).")
        }
        if input.bottomGas.fO2 < 0.16 {
            warnings.append("Bottom mix is hypoxic at surface (\(Int(input.bottomGas.fO2*100))% O₂).")
        }
    }

    let tissues = initialTissues?.clone() ?? TissueState(surfacePressure: surfP)
    var runtime = 0.0
    var schedule: [DecoStop] = []

    // --- Gas helpers ---
    func getGas(_ ambient: Double, _ depth: Double, _ phase: String) -> (fO2: Double, fN2: Double, fHe: Double) {
        if input.circuitType == .ccr {
            let sp: Double
            if phase == "deco" || phase == "ascent_deco" {
                sp = input.setpointDeco
            } else {
                sp = depth >= input.setpointSwitchDepth ? input.setpointHigh : input.setpointLow
            }
            let r = ccrGasFractions(setpoint: sp, dilO2: input.diluent.fO2, dilHe: input.diluent.fHe, ambient: ambient)
            return (r.fO2, r.fN2, r.fHe)
        }
        if phase == "deco" || phase == "ascent_deco" {
            let b = bestGasAtDepth(preparedDeco, depth, (input.bottomGas.fO2, input.bottomGas.fHe))
            return (b.fO2, 1.0 - b.fO2 - b.fHe, b.fHe)
        }
        return (input.bottomGas.fO2, input.bottomGas.fN2, input.bottomGas.fHe)
    }

    func gasLabelFor(_ fO2: Double, _ fHe: Double, _ depth: Double) -> String {
        if input.circuitType == .ccr {
            let amb = depthToPressure(depth, surfP, wdf)
            return String(format: "ppO₂ %.2f", min(amb * fO2, amb))
        }
        return gasLabel(fO2: fO2, fHe: fHe)
    }

    func ppO2At(_ depth: Double, _ phase: String) -> Double {
        let amb = depthToPressure(depth, surfP, wdf)
        let g = getGas(amb, depth, phase)
        return amb * g.fO2
    }

    func addUsage(_ label: String, _ avgDepth: Double, _ time: Double, _ sac: Double) {
        guard input.circuitType == .oc, time > 0 else { return }
        let p = depthToPressure(avgDepth, surfP, wdf)
        gasUsageDict[label, default: 0] += sac * p * time
    }

    func trackSeg(_ avgDepth: Double, _ time: Double, _ ppO2: Double) {
        guard time > 0 else { return }
        let lim = cnsLimit(ppO2)
        if lim.isFinite { cnsPct += (time / lim) * 100 }
        otuTotal += otuDose(ppO2, time)
        depthTimeProduct += avgDepth * time
    }

    func applySegDepthChange(_ d1: Double, _ d2: Double, _ rate: Double, _ phase: String) {
        let steps = input.circuitType == .ccr ? max(1, Int(abs(d1 - d2).rounded())) : 1
        let dStep = (d2 - d1) / Double(steps)
        let tStep = abs(dStep) / rate
        for s in 0..<steps {
            let sd = d1 + Double(s) * dStep
            let ed = d1 + Double(s+1) * dStep
            let p1 = depthToPressure(sd, surfP, wdf)
            let p2 = depthToPressure(ed, surfP, wdf)
            let g = getGas(p1, sd, phase)
            tissues.applyDepthChange(pStart: p1, pEnd: p2, time: tStep, fN2: g.fN2, fHe: g.fHe)
        }
    }

    // --- 1 & 2. Process levels ---
    var currentDepth = 0.0
    let botLabel = gasLabel(fO2: input.bottomGas.fO2, fHe: input.bottomGas.fHe)

    for level in input.levels {
        let diff = abs(level.depth - currentDepth)
        var transitTime = 0.0
        if diff > 0 {
            let rate = level.depth > currentDepth ? input.descentRate : input.ascentRate
            transitTime = diff / rate
            applySegDepthChange(currentDepth, level.depth, rate, "bottom")
            runtime += transitTime
            let midD = (currentDepth + level.depth) / 2
            addUsage(botLabel, midD, transitTime, input.sacBottom)
            trackSeg(midD, transitTime, ppO2At(midD, "bottom"))
        }
        let bottomTime = input.transitInclusive ? max(0, level.time - transitTime) : level.time
        if input.transitInclusive && level.time > 0 && transitTime >= level.time {
            warnings.append("Level \(Int(level.depth))m: transit (\(String(format:"%.1f",transitTime)) min) exceeds level time (\(Int(level.time)) min).")
        }
        if bottomTime > 0 {
            let pL = depthToPressure(level.depth, surfP, wdf)
            let g = getGas(pL, level.depth, "bottom")
            tissues.applyConstant(ambient: pL, fN2: g.fN2, fHe: g.fHe, time: bottomTime)
            runtime += bottomTime
            addUsage(botLabel, level.depth, bottomTime, input.sacBottom)
            trackSeg(level.depth, bottomTime, ppO2At(level.depth, "bottom"))
        }
        currentDepth = level.depth
    }

    let bottomRuntime = runtime
    let bailoutTissues = input.circuitType == .ccr ? tissues.clone() : nil
    let ascentStartDepth = currentDepth

    // --- 3. Find first stop using gfLow ---
    var firstStopDepth = 0.0

    while currentDepth > 0 {
        let ceilingBar = tissues.ceiling(gf: gfL)
        let ceilM = pressureToDepth(ceilingBar, surfP, wdf)
        let ceilStop = ceilToStop(max(0, ceilM))

        if ceilStop >= currentDepth {
            firstStopDepth = ceilToStop(currentDepth)
            break
        }
        // Step up to previous 3m boundary
        let snapped = max(0.0, (ceil((currentDepth - 0.001) / STOP_INCREMENT) - 1) * STOP_INCREMENT)
        let stepEnd = max(0.0, snapped)
        let stepDist = currentDepth - stepEnd
        if stepDist <= 0 { break }
        let stepTime = stepDist / input.ascentRate
        applySegDepthChange(currentDepth, stepEnd, input.ascentRate, "ascent_deco")
        runtime += stepTime
        let midD = (currentDepth + stepEnd) / 2
        let ascentGas = getGas(depthToPressure(midD, surfP, wdf), midD, "ascent_deco")

        addUsage(gasLabelFor(ascentGas.fO2, ascentGas.fHe, midD), midD, stepTime, input.sacDeco)
        trackSeg(midD, stepTime, ppO2At(midD, "ascent_deco"))
        currentDepth = stepEnd
    }

    // GF interpolation
    func gfAtDepth(_ stop: Double) -> Double {
        if firstStopDepth <= 0 { return gfH }
        if stop >= firstStopDepth { return gfL }
        if stop <= 0 { return gfH }
        return gfH - (gfH - gfL) * (stop / firstStopDepth)
    }

    // --- 4. Process deco stops ---
    if firstStopDepth > 0 {
        var sd = firstStopDepth
        while sd >= lastStop {
            let pStop = depthToPressure(sd, surfP, wdf)
            let gf = gfAtDepth(sd)
            let g = getGas(pStop, sd, "deco")
            let glabel = gasLabelFor(g.fO2, g.fHe, sd)
            let isLast = sd == lastStop
            var stopTime = 0.0

            while true {
                let clearanceGF = isLast ? gfH : gf

                let ceilBar = tissues.ceiling(gf: clearanceGF)
                let ceilD = pressureToDepth(ceilBar, surfP, wdf)
                let reqStop = ceilToStop(max(0, ceilD))
                if isLast ? reqStop <= 0 : reqStop < sd { break }
                tissues.applyConstant(ambient: pStop, fN2: g.fN2, fHe: g.fHe, time: 1)
                stopTime += 1; runtime += 1
                if stopTime > 999 { warnings.append("Stop at \(Int(sd))m exceeded 999 min."); break }
            }

            if stopTime > 0 {
                schedule.append(DecoStop(depth: sd, stopTime: stopTime, runtime: ceil(runtime), gas: glabel))
                addUsage(glabel, sd, stopTime, input.sacDeco)
                trackSeg(sd, stopTime, ppO2At(sd, "deco"))
            }

            if sd > lastStop {
                let nextD = sd - STOP_INCREMENT
                let travelTime = STOP_INCREMENT / input.ascentRate
                applySegDepthChange(sd, nextD, input.ascentRate, "deco")
                runtime += travelTime
                let ascentG = getGas(pStop, sd, "deco")
                addUsage(gasLabelFor(ascentG.fO2, ascentG.fHe, sd), (sd+nextD)/2, travelTime, input.sacDeco)
                trackSeg((sd+nextD)/2, travelTime, ppO2At((sd+nextD)/2, "deco"))
                currentDepth = nextD
            }
            sd -= STOP_INCREMENT
        }
    }

    // Final ascent to surface
    if currentDepth > 0 {
        let travelTime = currentDepth / input.ascentRate
        applySegDepthChange(currentDepth, 0, input.ascentRate, "deco")
        runtime += travelTime
        let fG = getGas(depthToPressure(currentDepth, surfP, wdf), currentDepth, "deco")
        addUsage(gasLabelFor(fG.fO2, fG.fHe, currentDepth), currentDepth/2, travelTime, input.sacDeco)
        trackSeg(currentDepth/2, travelTime, ppO2At(currentDepth/2, "deco"))
    }

    // Surface ceiling check
    let surfCeil = tissues.ceiling(gf: gfH)
    if surfCeil > surfP + 0.01 {
        warnings.append("Ceiling at surface is \(String(format:"%.1f",pressureToDepth(surfCeil, surfP, wdf)))m — tissues still supersaturated!")
    }

    let totalStopTime = schedule.reduce(0) { $0 + $1.stopTime }
    let gasEntries = gasUsageDict.map { GasUsageEntry(label: $0.key, litres: $0.value) }
        .sorted { $0.label < $1.label }
    let averageDepth = runtime > 0 ? (depthTimeProduct / runtime * 10).rounded() / 10 : 0

    // Bailout (CCR only)
    var bailout: BailoutResultData? = nil
    if input.circuitType == .ccr, let bt = bailoutTissues {
        bailout = computeBailout(
            tissues: bt, depth: ascentStartDepth,
            preparedDeco: preparedDeco, diluent: input.diluent,
            surfP: surfP, wdf: wdf,
            ascentRate: input.ascentRate,
            gfL: gfL, gfH: gfH,
            sacBottom: input.sacBottom, sacDeco: input.sacDeco,
            lastStop: lastStop
        )
    }

    return DiveResultData(
        schedule: schedule,
        maxDepth: maxDepth,
        totalStopTime: totalStopTime,
        totalRuntime: ceil(runtime),
        bottomRuntime: (bottomRuntime * 10).rounded() / 10,
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
    let t = tissues.clone()
    if interval > 0 { t.applyConstant(ambient: surfP, fN2: 0.7902, fHe: 0, time: interval) }
    return t
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

    func getGas(_ d: Double, _ phase: String) -> (fO2: Double, fN2: Double, fHe: Double, label: String) {
        if phase == "deco" || phase == "ascent_deco" {
            let b = bestGasAtDepth(preparedDeco, d, bottom)
            return (b.fO2, 1-b.fO2-b.fHe, b.fHe, gasLabel(fO2: b.fO2, fHe: b.fHe))
        }
        return (bottom.fO2, botFN2, bottom.fHe, gasLabel(fO2: bottom.fO2, fHe: bottom.fHe))
    }

    func addUsage(_ label: String, _ d: Double, _ t: Double, _ sac: Double) {
        guard t > 0 else { return }
        gasUsageDict[label, default: 0] += sac * depthToPressure(d, surfP, wdf) * t
    }

    func trackSeg(_ d: Double, _ t: Double, _ fO2: Double) {
        guard t > 0 else { return }
        let pp = depthToPressure(d, surfP, wdf) * fO2
        let lim = cnsLimit(pp)
        if lim.isFinite { cnsPct += (t / lim) * 100 }
        otuTotal += otuDose(pp, t)
        depthTP += d * t
    }

    func applyChange(_ d1: Double, _ d2: Double, _ rate: Double, _ phase: String) -> (time: Double, label: String) {
        let steps = max(1, Int((abs(d1-d2) / STOP_INCREMENT).rounded()))
        let dStep = (d2 - d1) / Double(steps)
        let tTotal = abs(d1-d2) / rate
        let tStep = tTotal / Double(steps)
        var lastLabel = ""
        for s in 0..<steps {
            let sd = d1 + Double(s) * dStep
            let ed = d1 + Double(s+1) * dStep
            let p1 = depthToPressure(sd, surfP, wdf)
            let p2 = depthToPressure(ed, surfP, wdf)
            let g = getGas(sd, phase)
            tissues.applyDepthChange(pStart: p1, pEnd: p2, time: tStep, fN2: g.fN2, fHe: g.fHe)
            lastLabel = g.label
        }
        return (tTotal, lastLabel)
    }

    var firstStopDepth = 0.0
    var currentDepth = depth

    while currentDepth > 0 {
        let ceilBar = tissues.ceiling(gf: gfL)
        let ceilM = pressureToDepth(ceilBar, surfP, wdf)
        let ceilStop = ceilToStop(max(0, ceilM))
        if ceilStop >= currentDepth { firstStopDepth = ceilToStop(currentDepth); break }
        let nextD = max(0.0, ceil((currentDepth - 0.001) / STOP_INCREMENT - 1) * STOP_INCREMENT)
        let dist = currentDepth - nextD
        if dist <= 0 { break }
        let (t, lbl) = applyChange(currentDepth, nextD, ascentRate, "ascent_deco")
        runtime += t
        addUsage(lbl, (currentDepth+nextD)/2, t, sacDeco)
        trackSeg((currentDepth+nextD)/2, t, getGas(currentDepth, "ascent_deco").fO2)
        currentDepth = nextD
    }

    func gfAtDepth(_ sd: Double) -> Double {
        if firstStopDepth <= 0 { return gfH }
        if sd >= firstStopDepth { return gfL }
        if sd <= 0 { return gfH }
        return gfH - (gfH - gfL) * (sd / firstStopDepth)
    }

    if firstStopDepth > 0 {
        var sd = firstStopDepth
        while sd >= lastStop {
            let pStop = depthToPressure(sd, surfP, wdf)
            let gf = gfAtDepth(sd)
            let g = getGas(sd, "deco")
            let isLast = sd == lastStop
            var stopTime = 0.0

            while true {
                let clearanceGF = isLast ? gfH : gf

                let ceilD = pressureToDepth(tissues.ceiling(gf: clearanceGF), surfP, wdf)
                let req = ceilToStop(max(0, ceilD))
                if isLast ? req <= 0 : req < sd { break }
                tissues.applyConstant(ambient: pStop, fN2: g.fN2, fHe: g.fHe, time: 1)
                stopTime += 1; runtime += 1
                if stopTime > 999 { warnings.append("Bailout stop at \(Int(sd))m exceeded 999 min."); break }
            }

            if stopTime > 0 {
                schedule.append(DecoStop(depth: sd, stopTime: stopTime, runtime: ceil(runtime), gas: g.label))
                addUsage(g.label, sd, stopTime, sacDeco)
                trackSeg(sd, stopTime, g.fO2)
            }

            if sd > lastStop {
                let nextD = sd - STOP_INCREMENT
                let (tt, al) = applyChange(sd, nextD, ascentRate, "deco")
                runtime += tt
                addUsage(al, (sd+nextD)/2, tt, sacDeco)
                trackSeg((sd+nextD)/2, tt, getGas(sd, "deco").fO2)
                currentDepth = nextD
            }
            sd -= STOP_INCREMENT
        }
    }

    if currentDepth > 0 {
        let (t, lbl) = applyChange(currentDepth, 0, ascentRate, "deco")
        runtime += t
        addUsage(lbl, currentDepth/2, t, sacDeco)
        trackSeg(currentDepth/2, t, getGas(currentDepth, "deco").fO2)
    }

    let gasEntries = gasUsageDict.map { GasUsageEntry(label: $0.key, litres: $0.value) }.sorted { $0.label < $1.label }
    let avgD = runtime > 0 ? (depthTP / runtime * 10).rounded() / 10 : 0

    return BailoutResultData(
        schedule: schedule,
        totalStopTime: schedule.reduce(0) { $0 + $1.stopTime },
        totalRuntime: ceil(runtime),
        firstStopDepth: firstStopDepth,
        averageDepth: avgD,
        cnsPct: (cnsPct * 10).rounded() / 10,
        otuTotal: otuTotal.rounded(),
        gasUsage: gasEntries,
        warnings: warnings
    )
}
