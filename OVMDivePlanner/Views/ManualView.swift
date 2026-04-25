import SwiftUI

struct ManualView: View {
    private let sections: [ManualSection] = [
        ManualSection(
            title: "Overview",
            icon: "waveform.path.ecg.rectangle",
            summary: "OVM Dive Planner is a native iOS planning tool for open-circuit and CCR dives.",
            points: [
                "The planner uses a Bühlmann ZH-L16C decompression model with configurable gradient factors.",
                "You can build plans in either the visual planner or the list planner.",
                "The app also includes repetitive dive handling, gas planning, and a built-in mixer."
            ]
        ),
        ManualSection(
            title: "Planner Workflow",
            icon: "point.topleft.down.curvedto.point.bottomright.up",
            summary: "A normal planning cycle is profile setup, gas selection, calculation, then schedule review.",
            points: [
                "Choose Open Circuit or CCR.",
                "Build the profile in Visual or List mode.",
                "Set bottom gas or diluent, then add deco gases if needed.",
                "Run the planner and review the generated schedule, runtime, gas use, CNS, and OTU output."
            ]
        ),
        ManualSection(
            title: "Visual Planner",
            icon: "chart.xyaxis.line",
            summary: "The visual planner is intended for fast profile shaping directly on a chart.",
            points: [
                "Depth is plotted vertically with 0 m at the top.",
                "Runtime is plotted horizontally.",
                "Tap to add a waypoint, then drag to change depth or hold time.",
                "The chart expands with the profile to preserve editing room.",
                "Calculated decompression segments appear on the profile after planning."
            ]
        ),
        ManualSection(
            title: "List Planner",
            icon: "list.bullet.rectangle",
            summary: "The list planner provides structured depth and time entry by level.",
            points: [
                "Each row represents one planned level.",
                "Transit between levels uses the descent and ascent rates from Settings.",
                "Planner sections can be collapsed to keep the interface manageable on smaller screens."
            ]
        ),
        ManualSection(
            title: "Open Circuit and CCR",
            icon: "gauge.with.dots.needle.50percent",
            summary: "Both major workflows are supported, but they use different gas inputs.",
            points: [
                "Open Circuit uses a bottom gas plus optional deco gases.",
                "CCR uses diluent-style planning with bailout considerations.",
                "Warnings are shown when gas settings are inconsistent or operationally unsafe."
            ]
        ),
        ManualSection(
            title: "Deco Gases and Results",
            icon: "lungs.fill",
            summary: "The results screen summarizes the planned schedule and exposure outputs.",
            points: [
                "Deco gas switch depths can be automatic or manually entered.",
                "Runtime includes level time and inter-level transit time.",
                "Results include decompression schedule, total runtime, gas usage, CNS, and OTU values."
            ]
        ),
        ManualSection(
            title: "Repetitive Dive Planning",
            icon: "arrow.triangle.2.circlepath",
            summary: "The planner can carry tissue load into a follow-up dive.",
            points: [
                "Enable repetitive mode when planning a second dive after a surface interval.",
                "Review the second plan carefully because existing tissue load changes decompression behavior."
            ]
        ),
        ManualSection(
            title: "Settings",
            icon: "gearshape.2.fill",
            summary: "Global settings influence both the planner and the displayed units.",
            points: [
                "You can configure units, water type, surface pressure, gradient factors, rates, SAC values, and last stop depth.",
                "These settings are persisted so they remain available after restarting the app."
            ]
        ),
        ManualSection(
            title: "Gas Mixer",
            icon: "flask.fill",
            summary: "The mixer provides practical blend calculations without leaving the app.",
            points: [
                "Use it for nitrox and trimix blending workflows.",
                "Verify final mixes independently before any actual fill operation."
            ]
        ),
        ManualSection(
            title: "Safety Notice",
            icon: "exclamationmark.triangle.fill",
            summary: "The app is a planning aid, not a substitute for training or in-water procedures.",
            points: [
                "Every plan should be reviewed independently before use.",
                "The diver remains responsible for gas selection, equipment setup, exposure management, and decompression execution."
            ],
            isWarning: true
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard

                ForEach(sections) { section in
                    ManualSectionCard(section: section)
                }
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [
                    OVMTheme.background,
                    Color(red: 13 / 255, green: 24 / 255, blue: 41 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("User Manual")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OVM Dive Planner")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(OVMTheme.textPrimary)

            Text("Technical and recreational dive planning for iPhone, with native support for list-based and visual profile workflows.")
                .font(.body)
                .foregroundStyle(OVMTheme.textSecondary)

            HStack(spacing: 10) {
                ManualBadge(title: "Bühlmann ZH-L16C")
                ManualBadge(title: "OC + CCR")
                ManualBadge(title: "Visual Planner")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [OVMTheme.card, OVMTheme.tableHover],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(OVMTheme.border, lineWidth: 1)
        }
    }
}

private struct ManualSectionCard: View {
    let section: ManualSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: section.icon)
                    .font(.title3)
                    .foregroundStyle(section.isWarning ? OVMTheme.danger : OVMTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(section.isWarning ? OVMTheme.warningBackground : OVMTheme.tableHover)
                    )

                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(OVMTheme.textPrimary)
            }

            Text(section.summary)
                .font(.subheadline)
                .foregroundStyle(OVMTheme.textSecondary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(section.isWarning ? OVMTheme.danger : OVMTheme.accent)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(OVMTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(section.isWarning ? OVMTheme.warningBackground : OVMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(section.isWarning ? OVMTheme.danger.opacity(0.35) : OVMTheme.border, lineWidth: 1)
        }
    }
}

private struct ManualBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(OVMTheme.background)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(OVMTheme.accent)
            .clipShape(Capsule())
    }
}

private struct ManualSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let summary: String
    let points: [String]
    var isWarning = false
}

