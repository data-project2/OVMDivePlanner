// MixerViewModel.swift
// State management for gas mixer calculator

import Foundation
import Combine

@MainActor
class MixerViewModel: ObservableObject {

    // MARK: - Boost inputs

    @Published var boost_vDonor: Double = 10
    @Published var boost_pDonor: Double = 200
    @Published var boost_vTarget: Double = 10
    @Published var boost_pTarget: Double = 50
    @Published var boost_result: Double? = nil
    @Published var boost_error: String? = nil

    // MARK: - Blend inputs

    @Published var blend_o2Start: Double = 21
    @Published var blend_heStart: Double = 0
    @Published var blend_pStart: Double = 100
    @Published var blend_o2Fill: Double = 32
    @Published var blend_heFill: Double = 0
    @Published var blend_pResult: Double = 200
    @Published var blend_result: BlendResult? = nil
    @Published var blend_error: String? = nil

    // MARK: - Mix inputs

    @Published var mix_o2Target: Double = 18
    @Published var mix_heTarget: Double = 35
    @Published var mix_pTarget: Double = 200
    @Published var mix_pStart: Double = 1
    @Published var mix_o2Start: Double = 21
    @Published var mix_heStart: Double = 0
    @Published var mix_result: MixResult? = nil
    @Published var mix_error: String? = nil

    // MARK: - Boost calculator

    func calculateBoost() {
        boost_error = nil
        boost_result = nil

        if let r = OVMDivePlanner.calculateBoost(
            vDonor: boost_vDonor,
            pDonor: boost_pDonor,
            vTarget: boost_vTarget,
            pTarget: boost_pTarget
        ) {
            boost_result = r
        } else {
            boost_error = "Invalid input. Check all values are non-negative."
        }
    }

    // MARK: - Blend calculator

    func calculateBlend() {
        blend_error = nil
        blend_result = nil

        if blend_pResult <= blend_pStart {
            blend_error = "Final pressure must be > starting pressure"
            return
        }

        if let r = OVMDivePlanner.calculateBlend(
            o2Start: blend_o2Start,
            heStart: blend_heStart,
            pStart: blend_pStart,
            o2Fill: blend_o2Fill,
            heFill: blend_heFill,
            pResult: blend_pResult
        ) {
            blend_result = r
        } else {
            blend_error = "Invalid input. Check all values are non-negative and O₂+He ≤ 100%."
        }
    }

    // MARK: - Mix calculator

    func calculateMix() {
        mix_error = nil
        mix_result = nil

        if let r = OVMDivePlanner.calculateMix(
            o2Target: mix_o2Target,
            heTarget: mix_heTarget,
            pTarget: mix_pTarget,
            pStart: mix_pStart,
            o2Start: mix_o2Start,
            heStart: mix_heStart
        ) {
            mix_result = r
        } else {
            mix_error = "Invalid input. Check O₂+He ≤ 100% and pressures are non-negative."
        }
    }
}
