// ResultsView.swift
// Displays decompression schedule and summary for dive 1 (and dive 2 if repetitive)

import SwiftUI

struct ResultsView: View {
    @EnvironmentObject private var vm: DivePlannerViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.isCalculating {
                    VStack(spacing: 16) {
                        ProgressView("Calculating…")
                        Text("Running Bühlmann ZHL-16C").foregroundStyle(OVMTheme.textSecondary).font(.caption)
                    }
                } else if let r = vm.results {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if !r.warnings.isEmpty { WarningsBox(warnings: r.warnings) }
                            DiveResultCard(title: "Dive 1", levels: vm.levels, result: r)
                            if let r2 = vm.results2 {
                                Divider()
                                if !r2.warnings.isEmpty { WarningsBox(warnings: r2.warnings) }
                                DiveResultCard(title: "Dive 2", levels: vm.levels2, result: r2)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.open.water.swim")
                            .font(.system(size: 56))
                            .foregroundStyle(OVMTheme.accent.opacity(0.6))
                        Text("No results yet")
                            .font(.title3).foregroundStyle(OVMTheme.textSecondary)
                        Text("Configure your dive and tap Plan Dive in the Plan tab.")
                            .font(.caption).foregroundStyle(OVMTheme.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Schedule")
            .background(OVMTheme.background)
        }
    }
}

// MARK: - Warning box

struct WarningsBox: View {
    let warnings: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Warnings", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(OVMTheme.danger)
                .font(.headline)
            ForEach(warnings, id: \.self) { w in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                    Text(w).font(.callout)
                }
            }
        }
        .padding()
        .background(OVMTheme.warningBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Card per dive

struct DiveResultCard: View {
    let title: String
    let levels: [DiveLevel]

    let result: DiveResultData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold()).foregroundStyle(OVMTheme.accent)

            // Summary grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                SummaryCell(label: "Max Depth", value: "\(Int(result.maxDepth)) m")
                SummaryCell(label: "Bottom Runtime", value: "\(fmtMin(result.bottomRuntime))")
                SummaryCell(label: "Total Runtime", value: "\(fmtMin(result.totalRuntime))")
                SummaryCell(label: "Total Stop Time", value: "\(fmtMin(result.totalStopTime))")
                SummaryCell(label: "First Stop", value: result.schedule.isEmpty ? "No deco" : "\(Int(result.firstStopDepth)) m")
                SummaryCell(label: "Avg Depth", value: "\(result.averageDepth) m")
                SummaryCell(label: "CNS%", value: String(format: "%.1f%%", result.cnsPct), highlight: result.cnsPct >= 80)
                SummaryCell(label: "OTU", value: String(format: "%.0f", result.otuTotal), highlight: result.otuTotal >= 280)
            }

            if !levels.isEmpty {
                Text("Dive Profile").font(.headline)
                DiveProfileTable(levels: levels)
            }

            // Deco schedule
            if !result.schedule.isEmpty {
                Text("Decompression Schedule").font(.headline)
                DecoTable(stops: result.schedule)
            } else {
                Label("No decompression required", systemImage: "checkmark.circle")
                    .foregroundStyle(OVMTheme.accent)
            }

            // Gas usage
            if !result.gasUsage.isEmpty {
                Text("Gas Usage (litres)").font(.headline)
                ForEach(result.gasUsage, id: \.label) { g in
                    HStack {
                        Text(g.label)
                        Spacer()
                        Text(String(format: "%.0f L", g.litres)).bold()
                    }
                    .padding(.vertical, 2)
                }
            }

            // Bailout (CCR only)
            if let bo = result.bailout {
                BailoutSection(bo: bo)
            }
        }
    }

    func fmtMin(_ m: Double) -> String {
        let total = Int(m)
        let h = total / 60; let mn = total % 60
        return h > 0 ? "\(h)h \(mn)min" : "\(mn) min"
    }
}

struct SummaryCell: View {
    let label: String
    let value: String
    var highlight: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(OVMTheme.textSecondary)
            Text(value).font(.headline).foregroundStyle(highlight ? OVMTheme.danger : OVMTheme.textPrimary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OVMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DiveProfileTable: View {
    let levels: [DiveLevel]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Level").font(.caption.bold()).frame(maxWidth: .infinity)
                Text("Depth").font(.caption.bold()).frame(maxWidth: .infinity)
                Text("Time").font(.caption.bold()).frame(maxWidth: .infinity)
                Text("Runtime").font(.caption.bold()).frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
            .background(OVMTheme.tableHover)

            ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                HStack {
                    Text("\(index + 1)").frame(maxWidth: .infinity)
                    Text("\(Int(level.depth)) m").frame(maxWidth: .infinity)
                    Text("\(Int(level.time)) min").frame(maxWidth: .infinity)
                    Text("\(Int(runtimeThroughLevel(at: index))) min").frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(OVMTheme.border))
    }

    private func runtimeThroughLevel(at index: Int) -> Double {
        levels.prefix(index + 1).reduce(0) { $0 + $1.time }
    }
}

// MARK: - Deco table

struct DecoTable: View {
    let stops: [DecoStop]
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Depth").font(.caption.bold()).frame(maxWidth: .infinity)
                Text("Stop").font(.caption.bold()).frame(maxWidth: .infinity)
                Text("Runtime").font(.caption.bold()).frame(maxWidth: .infinity)
                Text("Gas").font(.caption.bold()).frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
            .background(OVMTheme.tableHover)

            ForEach(stops, id: \.depth) { s in
                HStack {
                    Text("\(Int(s.depth)) m").frame(maxWidth: .infinity)
                    Text("\(Int(s.stopTime)) min").frame(maxWidth: .infinity)
                    Text("\(Int(s.runtime)) min").frame(maxWidth: .infinity)
                    Text(s.gas).frame(maxWidth: .infinity).lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(OVMTheme.border))
    }
}

// MARK: - Bailout section

struct BailoutSection: View {
    let bo: BailoutResultData
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { expanded.toggle() }) {
                HStack {
                    Label("CCR Bailout Schedule", systemImage: "arrow.triangle.2.circlepath")
                        .font(.headline)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if !bo.warnings.isEmpty { WarningsBox(warnings: bo.warnings) }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    SummaryCell(label: "Runtime", value: "\(Int(bo.totalRuntime)) min")
                    SummaryCell(label: "Stop Time", value: "\(Int(bo.totalStopTime)) min")
                    SummaryCell(label: "Avg Depth", value: "\(bo.averageDepth) m")
                    SummaryCell(label: "CNS%", value: String(format: "%.1f%%", bo.cnsPct), highlight: bo.cnsPct >= 80)
                }

                if !bo.schedule.isEmpty { DecoTable(stops: bo.schedule) }
                if !bo.gasUsage.isEmpty {
                    ForEach(bo.gasUsage, id: \.label) { g in
                        HStack { Text(g.label); Spacer(); Text(String(format: "%.0f L", g.litres)).bold() }
                    }
                }
            }
        }
        .padding()
        .background(OVMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
