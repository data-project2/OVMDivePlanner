// MixerEngine.swift
// Gas mixer calculator functions

import Foundation

// MARK: - Boost (Tank Fill)

func calculateBoost(vDonor: Double, pDonor: Double, vTarget: Double, pTarget: Double) -> Double? {
    guard vDonor > 0, pDonor >= 0, vTarget > 0, pTarget >= 0 else { return nil }
    return ((vDonor * pDonor) + (vTarget * pTarget)) / (vDonor + vTarget)
}

// MARK: - Blend (Top-off)

struct BlendResult {
    let o2Percent: Double
    let hePercent: Double
    let n2Percent: Double
    let finalPressure: Double
}

func calculateBlend(o2Start: Double, heStart: Double, pStart: Double,
                    o2Fill: Double, heFill: Double, pResult: Double) -> BlendResult? {
    guard pResult > pStart, o2Start >= 0, heStart >= 0, o2Fill >= 0, heFill >= 0 else { return nil }
    guard (o2Start + heStart) <= 100, (o2Fill + heFill) <= 100 else { return nil }

    let o2Out = ((pStart * o2Start) + ((pResult - pStart) * o2Fill)) / pResult
    let heOut = ((pStart * heStart) + ((pResult - pStart) * heFill)) / pResult
    let n2Out = 100.0 - o2Out - heOut

    return BlendResult(
        o2Percent: (o2Out * 10).rounded() / 10,
        hePercent: (heOut * 10).rounded() / 10,
        n2Percent: (n2Out * 10).rounded() / 10,
        finalPressure: pResult
    )
}

// MARK: - Mix (Trimix)

struct MixResult {
    let requiredO2Pressure: Double
    let requiredHePressure: Double
    let requiredAirPressure: Double
    let o2Total: Double
    let heTotal: Double
    let airTotal: Double
}

func calculateMix(o2Target: Double, heTarget: Double, pTarget: Double,
                  pStart: Double, o2Start: Double, heStart: Double) -> MixResult? {
    guard o2Target >= 0, heTarget >= 0, pTarget > 0, pStart >= 0, o2Start >= 0, heStart >= 0 else { return nil }

    let n2Target = 100.0 - o2Target - heTarget
    guard n2Target >= 0 else { return nil }
    guard (o2Start + heStart) <= 100 else { return nil }

    let startO2Pressure = (o2Start / 100.0) * pStart
    let startHePressure = (heStart / 100.0) * pStart
    let startN2Pressure = ((100.0 - o2Start - heStart) / 100.0) * pStart

    let targetO2Pressure = (o2Target / 100.0) * pTarget
    let targetHePressure = (heTarget / 100.0) * pTarget
    let targetN2Pressure = (n2Target / 100.0) * pTarget

    let requiredHe = targetHePressure - startHePressure
    let requiredAir = (targetN2Pressure - startN2Pressure) / 0.79
    let requiredO2 = targetO2Pressure - startO2Pressure - (requiredAir * 0.21)

    guard requiredO2 >= 0, requiredHe >= 0, requiredAir >= 0 else { return nil }
    guard requiredO2 + requiredHe + requiredAir <= (pTarget - pStart + 0.0001) else { return nil }

    return MixResult(
        requiredO2Pressure: requiredO2,
        requiredHePressure: requiredHe,
        requiredAirPressure: requiredAir,
        o2Total: pStart + requiredO2,
        heTotal: pStart + requiredO2 + requiredHe,
        airTotal: pTarget
    )
}
