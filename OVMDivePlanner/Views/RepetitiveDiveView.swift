// RepetitiveDiveView.swift
// Embedded in PlannerView when repetitive dive is toggled on

import SwiftUI

struct RepetitiveDiveView: View {
    @EnvironmentObject private var vm: DivePlannerViewModel

    var body: some View {
        Group {
            // Surface interval
            LabeledContent("Surface interval (min)") {
                TextField("60", value: $vm.surfaceInterval, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
            }

            // Dive 2 levels
            Text("Dive 2 Profile (m / min)").font(.subheadline).foregroundStyle(OVMTheme.textSecondary)
            ForEach($vm.levels2) { $level in
                LevelRow(level: $level)
            }
            .onDelete(perform: vm.removeLevel2)
            Button(action: vm.addLevel2) {
                Label("Add Level", systemImage: "plus.circle")
            }

            // Dive 2 bottom gas
            Text(vm.circuitType == .ccr ? "Dive 2 Diluent Gas" : "Dive 2 Bottom Gas").font(.subheadline).foregroundStyle(OVMTheme.textSecondary)
            GasPickerRow(gas: $vm.bottomGas2, showSwitch: false)

            // Dive 2 deco gases (OC only)
            if vm.circuitType == .oc {
                Text("Dive 2 Deco Gases").font(.subheadline).foregroundStyle(OVMTheme.textSecondary)
                ForEach($vm.decoGases2) { $g in
                    GasPickerRow(gas: $g, showSwitch: true)
                }
                .onDelete(perform: vm.removeDecoGas2)
                Button(action: vm.addDecoGas2) {
                    Label("Add Deco Gas", systemImage: "plus.circle")
                }
            }
        }
    }
}
