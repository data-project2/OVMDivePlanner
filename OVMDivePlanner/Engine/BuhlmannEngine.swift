// BuhlmannEngine.swift
// Bühlmann ZH-L16C Algorithm — direct port from buhlmann.js
// References: Bühlmann "Tauchmedizin" (2002), Erik Baker gradient factor papers

import Foundation

// MARK: - ZH-L16C Constants

private let N2_HT:  [Double] = [4.0,8.0,12.5,18.5,27.0,38.3,54.3,77.0,109.0,146.0,187.0,239.0,305.0,390.0,498.0,635.0]
private let N2_A:   [Double] = [1.2599,1.0000,0.8618,0.7562,0.6200,0.5043,0.4410,0.4000,0.3750,0.3500,0.3295,0.3065,0.2835,0.2610,0.2480,0.2327]
private let N2_B:   [Double] = [0.5050,0.6514,0.7222,0.7725,0.8125,0.8434,0.8693,0.8910,0.9092,0.9222,0.9319,0.9403,0.9477,0.9544,0.9602,0.9653]

private let HE_HT:  [Double] = [1.51,3.02,4.72,6.99,10.21,14.48,20.53,29.11,41.20,55.19,70.69,90.34,115.29,147.42,188.24,240.03]
private let HE_A:   [Double] = [1.7424,1.3830,1.1919,1.0458,0.9220,0.8205,0.7305,0.6502,0.5950,0.5545,0.5333,0.5189,0.5181,0.5176,0.5172,0.5119]
private let HE_B:   [Double] = [0.4245,0.5747,0.6527,0.7223,0.7582,0.7957,0.8279,0.8553,0.8757,0.8903,0.8997,0.9073,0.9122,0.9171,0.9217,0.9267]

let NUM_COMPARTMENTS = 16
let WATER_VAPOR_PRESSURE = 0.0627 // bar at 37°C

// MARK: - Core equations

func inspiredPressure(_ ambient: Double, _ fGas: Double) -> Double {
    (ambient - WATER_VAPOR_PRESSURE) * fGas
}

func schreiner(_ pAlv0: Double, _ pAlv1: Double, _ time: Double, _ ht: Double, _ p0: Double) -> Double {
    let k = log(2.0) / ht
    let r = (pAlv1 - pAlv0) / time
    return pAlv0 + r * (time - 1.0/k) - (pAlv0 - p0 - r/k) * exp(-k * time)
}

func haldane(_ pAlv: Double, _ time: Double, _ ht: Double, _ p0: Double) -> Double {
    p0 + (pAlv - p0) * (1.0 - exp(-log(2.0)/ht * time))
}

func combinedAB(_ i: Int, _ pN2: Double, _ pHe: Double) -> (a: Double, b: Double) {
    let total = pN2 + pHe
    guard total > 0 else { return (N2_A[i], N2_B[i]) }
    return (
        a: (N2_A[i]*pN2 + HE_A[i]*pHe) / total,
        b: (N2_B[i]*pN2 + HE_B[i]*pHe) / total
    )
}

func compartmentCeiling(_ pN2: Double, _ pHe: Double, _ i: Int, _ gf: Double) -> Double {
    let (a, b) = combinedAB(i, pN2, pHe)
    let pTotal = pN2 + pHe
    return (pTotal - a*gf) / (gf/b - gf + 1.0)
}

// MARK: - Tissue State

final class TissueState {
    var pN2: [Double]
    var pHe: [Double]

    init(surfacePressure: Double) {
        let pN2s = inspiredPressure(surfacePressure, 0.7902)
        pN2 = Array(repeating: pN2s, count: NUM_COMPARTMENTS)
        pHe = Array(repeating: 0.0,  count: NUM_COMPARTMENTS)
    }

    private init(pN2: [Double], pHe: [Double]) {
        self.pN2 = pN2
        self.pHe = pHe
    }

    func clone() -> TissueState { TissueState(pN2: pN2, pHe: pHe) }

    func applyConstant(ambient: Double, fN2: Double, fHe: Double, time: Double) {
        guard time > 0 else { return }
        let piN2 = inspiredPressure(ambient, fN2)
        let piHe = inspiredPressure(ambient, fHe)
        for i in 0..<NUM_COMPARTMENTS {
            pN2[i] = haldane(piN2, time, N2_HT[i], pN2[i])
            pHe[i] = haldane(piHe, time, HE_HT[i], pHe[i])
        }
    }

    func applyDepthChange(pStart: Double, pEnd: Double, time: Double, fN2: Double, fHe: Double) {
        guard time > 0 else { return }
        let piN2s = inspiredPressure(pStart, fN2);  let piN2e = inspiredPressure(pEnd, fN2)
        let piHes = inspiredPressure(pStart, fHe);  let piHee = inspiredPressure(pEnd, fHe)
        for i in 0..<NUM_COMPARTMENTS {
            pN2[i] = schreiner(piN2s, piN2e, time, N2_HT[i], pN2[i])
            pHe[i] = schreiner(piHes, piHee, time, HE_HT[i], pHe[i])
        }
    }

    func ceiling(gf: Double) -> Double {
        var max = 0.0
        for i in 0..<NUM_COMPARTMENTS {
            let c = compartmentCeiling(pN2[i], pHe[i], i, gf)
            if c > max { max = c }
        }
        return max
    }
}
