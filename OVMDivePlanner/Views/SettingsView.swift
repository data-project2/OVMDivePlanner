// SettingsView.swift
// GF, rates, SAC, water type, last stop, surface pressure

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var vm: DivePlannerViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case surfacePressure
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ManualView()
                    } label: {
                        Label("User Manual", systemImage: "book.closed")
                    }
                } header: { Text("Help") }

                Section {
                    Picker("Units", selection: $vm.unitSystem) {
                        ForEach(UnitSystem.allCases, id: \.self) { system in
                            Text(system.displayName).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Water type", selection: $vm.waterType) {
                        Text("Salt water").tag(WaterType.salt)
                        Text("Fresh water").tag(WaterType.fresh)
                    }
                    LabeledContent("Surface pressure (bar)") {
                        TextField("1.0", value: $vm.surfacePressure, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .surfacePressure)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                } header: { Text("Environment") }

                Section {
                    LabeledSlider(label: "GF Low", value: $vm.gfLow, range: 10...100, step: 5,
                                  format: "%.0f%%")
                    LabeledSlider(label: "GF High", value: $vm.gfHigh, range: 10...100, step: 5,
                                  format: "%.0f%%")
                } header: {
                    Text("Gradient Factors")
                } footer: {
                    Text("GF Low controls first deco stop depth. GF High controls surface allowable supersaturation. Conservative = lower values.")
                }

                Section {
                    LabeledSlider(label: "Descent rate (\(vm.unitSystem.rateUnit))", value: rateBinding($vm.descentRate), range: rateRange(5...100), step: vm.unitSystem == .metric ? 1 : 5,
                                  format: vm.unitSystem == .metric ? "%.0f m/min" : "%.0f ft/min")
                    LabeledSlider(label: "Ascent rate (\(vm.unitSystem.rateUnit))", value: rateBinding($vm.ascentRate), range: rateRange(3...18), step: vm.unitSystem == .metric ? 1 : 5,
                                  format: vm.unitSystem == .metric ? "%.0f m/min" : "%.0f ft/min")
                } header: { Text("Rates") }

                Section {
                    LabeledSlider(label: "Bottom SAC (\(vm.unitSystem.volumeUnit)/min)", value: volumeBinding($vm.sacBottom), range: volumeRange(5...40), step: vm.unitSystem == .metric ? 1 : 0.5,
                                  format: vm.unitSystem == .metric ? "%.0f L/min" : "%.1f cuft/min")
                    LabeledSlider(label: "Deco SAC (\(vm.unitSystem.volumeUnit)/min)", value: volumeBinding($vm.sacDeco), range: volumeRange(5...40), step: vm.unitSystem == .metric ? 1 : 0.5,
                                  format: vm.unitSystem == .metric ? "%.0f L/min" : "%.1f cuft/min")
                } header: { Text("Surface Air Consumption") }

                Section {
                    LabeledContent("Last stop depth (\(vm.unitSystem.depthUnit))") {
                        Picker("", selection: $vm.lastStopDepth) {
                            Text(vm.unitSystem == .metric ? "3 m" : "10 ft").tag(3.0)
                            Text(vm.unitSystem == .metric ? "6 m" : "20 ft").tag(6.0)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                    Toggle("Descent time included in bottom time", isOn: $vm.transitInclusive)
                } header: { Text("Decompression") }
            }
            .ovmFormBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func rateBinding(_ metricValue: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { vm.unitSystem.rate(metricValue.wrappedValue) },
            set: { metricValue.wrappedValue = vm.unitSystem.metricRate($0) }
        )
    }

    private func volumeBinding(_ metricValue: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { vm.unitSystem.volume(metricValue.wrappedValue) },
            set: { metricValue.wrappedValue = vm.unitSystem.metricVolume($0) }
        )
    }

    private func rateRange(_ metricRange: ClosedRange<Double>) -> ClosedRange<Double> {
        vm.unitSystem.rate(metricRange.lowerBound)...vm.unitSystem.rate(metricRange.upperBound)
    }

    private func volumeRange(_ metricRange: ClosedRange<Double>) -> ClosedRange<Double> {
        vm.unitSystem.volume(metricRange.lowerBound)...vm.unitSystem.volume(metricRange.upperBound)
    }
}
struct ManualView: View {
    private let sections: [ManualSection] = [
        ManualSection(
            title: "1. App Overview",
            icon: "waveform.path.ecg.rectangle",
            summary: "The app is organized into four main tabs:",
            points: [
                "Plan: Create the dive profile, select circuit type, assign bottom gas and deco gases, and calculate the dive.",
                "Schedule: Review the decompression schedule, runtime, gas usage, CNS, OTU, and warnings.",
                "Mixer: Use the gas mixer tools for pressure transfer, top-off blending, and trimix fill calculations.",
                "Settings: Configure units, water type, rates, SAC, gradient factors, last stop depth, and other planner defaults."
            ]
        ),
        ManualSection(
            title: "2. Planning a Dive",
            icon: "point.topleft.down.curvedto.point.bottomright.up",
            summary: "Open the Plan tab and build the dive from the planner controls.",
            points: [
                "Open the Plan tab.",
                "Select Open Circuit or CCR in the Circuit section.",
                "Choose Visual for chart-based waypoint editing or List for discrete depth and time levels.",
                "Enter the dive profile.",
                "Each level time is interpreted according to the Descent Time Included in Bottom Time setting in Settings.",
                "Descent gas uptake is always modeled. The setting only changes whether descent time is counted inside the entered level time or added before it.",
                "Select the bottom gas or diluent.",
                "Add any deco gases if required.",
                "Tap Plan Dive.",
                "The planner supports:",
                "multi-level profiles",
                "trimix and helium-based gases",
                "automatic or manual deco gas switch depths",
                "metric and imperial units",
                "persistent planner settings between launches"
            ]
        ),
        ManualSection(
            title: "3. Using the Visual Planner",
            icon: "chart.xyaxis.line",
            summary: "The visual planner is the default planning mode.",
            points: [
                "The vertical axis represents depth, with the surface at the top.",
                "The horizontal axis represents runtime.",
                "Tap the chart to add a new waypoint.",
                "Drag a waypoint vertically to change depth.",
                "Adjust hold time using the waypoint controls below the chart.",
                "The chart expands automatically as the profile grows in depth or time.",
                "List Planner: If you switch to List mode, each level is entered as a depth and time pair. Both list and visual modes edit the same underlying dive profile."
            ]
        ),
        ManualSection(
            title: "4. Reading the Schedule",
            icon: "lungs.fill",
            summary: "After calculation, the Schedule tab shows:",
            points: [
                "Max Depth",
                "Bottom Runtime",
                "Total Runtime",
                "Total Stop Time",
                "First Stop",
                "Average Depth",
                "CNS%",
                "OTU",
                "Bottom Runtime is the runtime through the planned bottom phase before ascent to deco or surface.",
                "If descent time is included in bottom time, the planner models gas uptake during descent and uses the remaining part of the entered level time at depth.",
                "If descent time is not included in bottom time, the planner adds descent runtime first and then applies the full entered level time at depth.",
                "Bottom Runtime in the summary follows this same rule.",
                "The schedule also includes:",
                "a table of decompression stops",
                "runtime at each stop",
                "planned gas for each stop",
                "estimated gas usage by mix",
                "If the dive does not require decompression, the schedule will explicitly state No decompression required."
            ]
        ),
        ManualSection(
            title: "5. Settings",
            icon: "gearshape.2.fill",
            summary: "The Settings tab controls global planner behavior.",
            points: [
                "Units: Metric or Imperial.",
                "Water Type: Salt or Fresh.",
                "Surface Pressure.",
                "GF Low / GF High.",
                "Descent Rate / Ascent Rate.",
                "Bottom SAC / Deco SAC.",
                "Last Stop Depth.",
                "Descent Time Included in Bottom Time: When enabled, descent time is counted inside the entered level time. Example: a 20 minute level with a 3 minute descent is modeled as 3 minutes descending plus 17 minutes at depth, for 20 minutes runtime through that level.",
                "When disabled, descent is modeled separately and the full entered level time is then spent at depth. Example: a 20 minute level with a 3 minute descent becomes 23 minutes runtime through that level.",
                "CCR Settings: If CCR is selected in the planner, a separate CCR settings sheet is available for:",
                "low setpoint",
                "high setpoint",
                "deco setpoint",
                "switch depth to the high setpoint",
                "CCR bailout/deco gases",
                "Settings are stored between launches."
            ]
        ),
        ManualSection(
            title: "6. Repetitive Dives",
            icon: "arrow.triangle.2.circlepath",
            summary: "The planner can model a second dive after a surface interval.",
            points: [
                "Expand the Repetitive Dive section in the planner.",
                "Enable repetitive-dive mode.",
                "Enter the surface interval.",
                "Define the second dive profile and gases.",
                "Calculate the plan.",
                "The app carries tissue loading, CNS, and OTU from the first dive into the second dive calculation."
            ]
        ),
        ManualSection(
            title: "7. Gas Mixer",
            icon: "flask.fill",
            summary: "The Mixer tab contains three calculators.",
            points: [
                "Tank Fill (Boost): Calculates the final pressure after transferring gas from a donor tank into a target tank.",
                "Top-Off Blend: Calculates the final mix after topping off a starting mix with a chosen fill gas.",
                "Trimix Mix: Calculates required oxygen, helium, and air pressures to produce a target trimix."
            ]
        ),
        ManualSection(
            title: "8. Warnings and Validation",
            icon: "exclamationmark.triangle.fill",
            summary: "The app displays warnings for conditions that require review before the plan is used.",
            points: [
                "Bottom gas ppO2 above the warning threshold.",
                "Hypoxic bottom mix at the surface.",
                "Deco gas switch depths that exceed the configured ppO2 limit.",
                "Very long stop conditions or unresolved ceilings.",
                "Warnings appear in the schedule view. Adjust your plan accordingly before the dive. Do not dive beyond your training and material limits."
            ]
        ),
        ManualSection(
            title: "9. Practical Tips",
            icon: "checklist",
            summary: "Use the planner conservatively and verify every critical input before diving.",
            points: [
                "Review all gas fractions and switch depths before calculating.",
                "Use the visual planner for quick profile shaping and the list planner for precise level entry.",
                "Check CNS, OTU, and gas usage on every decompression dive.",
                "Verify repetitive-dive settings carefully, especially surface interval and second-dive gases.",
                "Re-check settings after switching between metric and imperial units.",
                "Use the mixer tools separately from the planner when preparing gas fills."
            ]
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                ManualAlertCard(
                    title: "Disclaimer",
                    tint: ManualTheme.disclaimer,
                    background: ManualTheme.disclaimerBackground,
                    border: ManualTheme.disclaimerBorder,
                    points: [
                        "This software is provided on an \"as-is\" basis without warranty of any kind, express or implied.",
                        "The developers and distributors assume no liability for any injuries, damages, or losses resulting from the use of this software.",
                        "This app is a mathematical planning tool based on theoretical decompression models. It does not account for individual variations in physiology, metabolism, or decompression sickness susceptibility.",
                        "The app does not assess your physical fitness, health status, or medical conditions that may affect diving safety.",
                        "The app does not evaluate your mental or psychological state, including fatigue, stress, anxiety, or alertness.",
                        "The app does not account for environmental conditions such as water temperature, visibility, currents, weather, sea state, bottom composition, or other site-specific hazards.",
                        "The app does not consider your experience level, familiarity with your equipment, or your proficiency with the planned dive profile.",
                        "The app does not monitor actual underwater conditions, your real-time physiological state, or equipment performance during the dive.",
                        "Decompression calculations are theoretical approximations. Real-world physiology varies significantly between individuals. Follow conservative dive practices and your dive computer.",
                        "Diving is an inherently dangerous activity that requires proper training, certification, and appropriate equipment.",
                        "You must obtain formal training and certification from qualified instructors before diving.",
                        "You must use appropriate equipment and materials for the specific dive profile you intend to execute.",
                        "A functioning dive computer is mandatory for all dives and must be used as your primary depth and time reference.",
                        "The user assumes all responsibility and risk associated with diving activities and the use of this software."
                    ]
                )
                ManualAlertCard(
                    title: "Safety Notice",
                    tint: ManualTheme.notice,
                    background: ManualTheme.noticeBackground,
                    border: ManualTheme.noticeBorder,
                    message: "OVM Dive Planner is a planning aid only and does not replace professional judgment, formal training, formalized dive procedures, or real-time in-water monitoring with a dive computer. All dive plans must be independently reviewed and verified by qualified, experienced divers before execution."
                )
                contentsCard

                ForEach(sections) { section in
                    ManualSectionCard(section: section)
                }
            }
            .padding(16)
        }
        .background(
            LinearGradient(
                colors: [
                    ManualTheme.bgTop,
                    ManualTheme.bg
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
                .foregroundStyle(ManualTheme.text)

            Text("OVM Dive Planner is an iOS dive-planning app for open-circuit and CCR dives. It calculates decompression schedules using a Bühlmann ZH-L16C model with gradient factors and includes gas planning tools such as deco gas handling, repetitive-dive carry-over, and a gas mixer.")
                .font(.body)
                .foregroundStyle(ManualTheme.muted)

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
                colors: [ManualTheme.panel, ManualTheme.panel2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ManualTheme.border, lineWidth: 1)
        }
    }

    private var contentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contents")
                .font(.headline)
                .foregroundStyle(ManualTheme.text)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(sections.map(\.title), id: \.self) { title in
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(ManualTheme.accent)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ManualTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ManualTheme.border, lineWidth: 1)
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
                    .foregroundStyle(section.isWarning ? ManualTheme.disclaimer : ManualTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(section.isWarning ? ManualTheme.disclaimerBackground : ManualTheme.panel2)
                    )

                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(ManualTheme.text)
            }

            Text(section.summary)
                .font(.subheadline)
                .foregroundStyle(ManualTheme.muted)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.points, id: \.self) { point in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(section.isWarning ? ManualTheme.disclaimer : ManualTheme.accent)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(point)
                            .font(.subheadline)
                            .foregroundStyle(ManualTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(section.isWarning ? ManualTheme.disclaimerBackground : ManualTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(section.isWarning ? ManualTheme.disclaimerBorder : ManualTheme.border, lineWidth: 1)
        }
    }
}

private struct ManualAlertCard: View {
    let title: String
    let tint: Color
    let background: Color
    let border: Color
    var message: String? = nil
    var points: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(ManualTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(points, id: \.self) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(tint)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)

                            Text(point)
                                .font(.subheadline)
                                .foregroundStyle(ManualTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(border, lineWidth: 1)
        }
    }
}

private struct ManualBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ManualTheme.bg)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ManualTheme.accent)
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

private enum ManualTheme {
    static let bgTop = Color(red: 11 / 255, green: 22 / 255, blue: 40 / 255)
    static let bg = Color(red: 15 / 255, green: 28 / 255, blue: 48 / 255)
    static let panel = Color(red: 24 / 255, green: 39 / 255, blue: 66 / 255).opacity(0.92)
    static let panel2 = Color(red: 32 / 255, green: 53 / 255, blue: 86 / 255)
    static let text = Color(red: 227 / 255, green: 235 / 255, blue: 245 / 255)
    static let muted = Color(red: 174 / 255, green: 192 / 255, blue: 214 / 255)
    static let accent = Color(red: 91 / 255, green: 206 / 255, blue: 250 / 255)
    static let border = Color(red: 53 / 255, green: 82 / 255, blue: 123 / 255)
    static let notice = Color(red: 1.0, green: 209 / 255, blue: 102 / 255)
    static let noticeBackground = Color(red: 1.0, green: 209 / 255, blue: 102 / 255).opacity(0.08)
    static let noticeBorder = Color(red: 1.0, green: 209 / 255, blue: 102 / 255).opacity(0.35)
    static let disclaimer = Color(red: 1.0, green: 66 / 255, blue: 66 / 255)
    static let disclaimerBackground = Color(red: 1.0, green: 66 / 255, blue: 66 / 255).opacity(0.08)
    static let disclaimerBorder = Color(red: 1.0, green: 66 / 255, blue: 66 / 255).opacity(0.35)
}
