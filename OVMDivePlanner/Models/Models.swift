// Models.swift
// All data structures for OVM Dive Planner iOS

import Foundation

// MARK: - Gas Mix

struct GasMix: Identifiable, Equatable, Codable {
    var id: UUID
    var fO2: Double   // 0..1
    var fHe: Double   // 0..1
    var switchDepth: Double? // nil = auto from MOD

    init(id: UUID = UUID(), fO2: Double, fHe: Double, switchDepth: Double? = nil) {
        self.id = id
        self.fO2 = fO2
        self.fHe = fHe
        self.switchDepth = switchDepth
    }

    var fN2: Double { 1.0 - fO2 - fHe }

    var label: String { gasLabel(fO2: fO2, fHe: fHe) }

    static var air: GasMix { GasMix(fO2: 0.21, fHe: 0.0) }
    static var ean32: GasMix { GasMix(fO2: 0.32, fHe: 0.0) }
    static var ean50: GasMix { GasMix(fO2: 0.50, fHe: 0.0) }
    static var oxygen: GasMix { GasMix(fO2: 1.00, fHe: 0.0) }
}

func gasLabel(fO2: Double, fHe: Double) -> String {
    let o2 = Int((fO2 * 100).rounded())
    let he = Int((fHe * 100).rounded())
    if he > 0 { return "Tx \(o2)/\(he)" }
    if o2 == 21 { return "Air" }
    if o2 == 100 { return "O₂" }
    return "EAN\(o2)"
}

// MARK: - Dive Level

struct DiveLevel: Identifiable, Codable {
    var id = UUID()
    var depth: Double      // meters
    var time: Double       // minutes at depth
}

// MARK: - Enums

enum CircuitType: String, CaseIterable, Codable {
    case oc  = "OC"
    case ccr = "CCR"
    var displayName: String { rawValue == "OC" ? "Open Circuit (OC)" : "Closed Circuit (CCR)" }
}

enum WaterType: String, CaseIterable, Codable {
    case salt  = "salt"
    case fresh = "fresh"
    var displayName: String { rawValue == "salt" ? "Salt Water" : "Fresh Water" }
    var densityFactor: Double { rawValue == "salt" ? 1.025 : 1.0 }
}

// MARK: - Plan Input

struct DivePlanInput: Codable {
    // Circuit
    var circuitType: CircuitType = .oc

    // Profile
    var levels: [DiveLevel] = [DiveLevel(depth: 40, time: 25)]
    var descentRate: Double = 20
    var ascentRate: Double  = 10
    var transitInclusive: Bool = true

    // Gas
    var bottomGas: GasMix = .air
    var decoGases: [GasMix] = []

    // Settings
    var waterType: WaterType = .salt
    var surfacePressure: Double = 1.013
    var gfLow: Double  = 30   // %
    var gfHigh: Double = 70   // %
    var lastStopDepth: Double = 3
    var sacBottom: Double = 20
    var sacDeco:   Double = 15

    // CCR
    var setpointLow:         Double = 0.7
    var setpointHigh:        Double = 1.3
    var setpointSwitchDepth: Double = 6
    var setpointDeco:        Double = 1.3
    var diluent:             GasMix = .air
}

// MARK: - Results

struct DecoStop: Identifiable {
    let id = UUID()
    var depth: Double
    var stopTime: Double
    var runtime: Double
    var gas: String
}

struct GasUsageEntry: Identifiable {
    let id = UUID()
    var label: String
    var litres: Double
}

struct DiveResultData {
    var schedule: [DecoStop]
    var maxDepth: Double
    var totalStopTime: Double
    var totalRuntime: Double
    var bottomRuntime: Double
    var firstStopDepth: Double
    var averageDepth: Double
    var cnsPct: Double
    var otuTotal: Double
    var gasUsage: [GasUsageEntry]
    var bailout: BailoutResultData?
    var warnings: [String]
    var finalTissues: TissueState
    var finalCNS: Double
    var finalOTU: Double
}

struct BailoutResultData {
    var schedule: [DecoStop]
    var totalStopTime: Double
    var totalRuntime: Double
    var firstStopDepth: Double
    var averageDepth: Double
    var cnsPct: Double
    var otuTotal: Double
    var gasUsage: [GasUsageEntry]
    var warnings: [String]
}
