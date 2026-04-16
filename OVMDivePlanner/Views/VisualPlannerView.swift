import SwiftUI

struct VisualPlannerView: View {
    @Binding var levels: [DiveLevel]
    let descentRate: Double
    let ascentRate: Double
    let unitSystem: UnitSystem

    private let chartHeight: CGFloat = 260
    private let leftInset: CGFloat = 42
    private let rightInset: CGFloat = 12
    private let topInset: CGFloat = 12
    private let bottomInset: CGFloat = 30
    private let defaultHoldTime: Double = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chart

            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, waypoint in
                HStack(spacing: 12) {
                    Text("WP \(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 42, alignment: .leading)

                    Text(depthLabel(for: waypoint.depth))
                        .foregroundStyle(OVMTheme.textSecondary)
                        .frame(width: 72, alignment: .leading)

                    Stepper(value: holdTimeBinding(for: waypoint.id), in: 0...300, step: 1) {
                        Text("Hold \(Int(waypoint.time)) min")
                    }

                    Button(role: .destructive) {
                        deleteWaypoint(id: waypoint.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(levels.count <= 1)
                }
            }

            Button {
                appendWaypoint()
            } label: {
                Label("Add Waypoint", systemImage: "plus.circle")
            }
        }
    }

    private var chart: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let plotWidth = max(1, width - leftInset - rightInset)
            let plotHeight = max(1, chartHeight - topInset - bottomInset)
            let profile = profilePoints
            let runtime = max(totalRuntime, 1)
            let maxDepthMetric = max(max(levels.map(\.depth).max() ?? 0, 6), 6)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(OVMTheme.card)

                grid(plotWidth: plotWidth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric, runtime: runtime)

                profilePath(profile, plotWidth: plotWidth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric, runtime: runtime)

                ForEach(waypointLayouts) { waypoint in
                    Circle()
                        .fill(OVMTheme.accent)
                        .frame(width: 14, height: 14)
                        .position(
                            x: xPosition(for: waypoint.handleRuntime, plotWidth: plotWidth, runtime: runtime),
                            y: yPosition(for: waypoint.depth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric)
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    updateDepth(
                                        for: waypoint.id,
                                        yLocation: value.location.y,
                                        plotHeight: plotHeight,
                                        maxDepthMetric: maxDepthMetric
                                    )
                                }
                        )
                }
            }
            .frame(height: chartHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard abs(value.translation.width) < 6, abs(value.translation.height) < 6 else { return }
                        addWaypoint(at: value.location, plotHeight: plotHeight, runtime: runtime, maxDepthMetric: maxDepthMetric)
                    }
            )
        }
        .frame(height: chartHeight)
    }

    private func grid(plotWidth: CGFloat, plotHeight: CGFloat, maxDepthMetric: Double, runtime: Double) -> some View {
        let horizontalTicks = 5
        let verticalTicks = 5

        return ZStack(alignment: .topLeading) {
            ForEach(0...horizontalTicks, id: \.self) { tick in
                let fraction = CGFloat(tick) / CGFloat(horizontalTicks)
                let y = topInset + fraction * plotHeight

                Path { path in
                    path.move(to: CGPoint(x: leftInset, y: y))
                    path.addLine(to: CGPoint(x: leftInset + plotWidth, y: y))
                }
                .stroke(OVMTheme.border.opacity(0.35), lineWidth: 1)

                let metricDepth = (1 - Double(fraction)) * maxDepthMetric
                Text(depthLabel(for: metricDepth))
                    .font(.caption2)
                    .foregroundStyle(OVMTheme.textTertiary)
                    .position(x: 20, y: y)
            }

            ForEach(0...verticalTicks, id: \.self) { tick in
                let fraction = CGFloat(tick) / CGFloat(verticalTicks)
                let x = leftInset + fraction * plotWidth

                Path { path in
                    path.move(to: CGPoint(x: x, y: topInset))
                    path.addLine(to: CGPoint(x: x, y: topInset + plotHeight))
                }
                .stroke(OVMTheme.border.opacity(0.35), lineWidth: 1)

                let timeValue = Double(fraction) * runtime
                Text("\(Int(timeValue.rounded())) min")
                    .font(.caption2)
                    .foregroundStyle(OVMTheme.textTertiary)
                    .position(x: x, y: topInset + plotHeight + 12)
            }
        }
    }

    private func profilePath(_ points: [RuntimeDepthPoint], plotWidth: CGFloat, plotHeight: CGFloat, maxDepthMetric: Double, runtime: Double) -> some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(
                x: xPosition(for: first.runtime, plotWidth: plotWidth, runtime: runtime),
                y: yPosition(for: first.depth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric)
            ))

            for point in points.dropFirst() {
                path.addLine(to: CGPoint(
                    x: xPosition(for: point.runtime, plotWidth: plotWidth, runtime: runtime),
                    y: yPosition(for: point.depth, plotHeight: plotHeight, maxDepthMetric: maxDepthMetric)
                ))
            }
        }
        .stroke(OVMTheme.accent, style: StrokeStyle(lineWidth: 3, lineJoin: .round))
    }

    private func xPosition(for runtimeValue: Double, plotWidth: CGFloat, runtime: Double) -> CGFloat {
        leftInset + CGFloat(runtimeValue / max(runtime, 1)) * plotWidth
    }

    private func yPosition(for depth: Double, plotHeight: CGFloat, maxDepthMetric: Double) -> CGFloat {
        topInset + CGFloat(depth / max(maxDepthMetric, 1)) * plotHeight
    }

    private func updateDepth(for id: UUID, yLocation: CGFloat, plotHeight: CGFloat, maxDepthMetric: Double) {
        guard let index = levels.firstIndex(where: { $0.id == id }) else { return }
        let clampedY = min(max(yLocation, topInset), topInset + plotHeight)
        let depthFraction = Double((clampedY - topInset) / plotHeight)
        let metricDepth = depthFraction * maxDepthMetric
        levels[index].depth = unitSystem.normalizeMetricProfileDepth(metricDepth)
    }

    private func addWaypoint(at location: CGPoint, plotHeight: CGFloat, runtime: Double, maxDepthMetric: Double) {
        let clampedY = min(max(location.y, topInset), topInset + plotHeight)
        let depthFraction = Double((clampedY - topInset) / plotHeight)
        let metricDepth = unitSystem.normalizeMetricProfileDepth(depthFraction * maxDepthMetric)
        let insertIndex = insertionIndex(for: location.x, runtime: runtime)
        let waypoint = DiveLevel(depth: metricDepth, time: defaultHoldTime)
        levels.insert(waypoint, at: insertIndex)
    }

    private func insertionIndex(for xLocation: CGFloat, runtime: Double) -> Int {
        let tappedFraction = min(max((xLocation - leftInset) / max(1, UIScreen.main.bounds.width - leftInset - rightInset), 0), 1)
        let tappedRuntime = Double(tappedFraction) * runtime
        return waypointLayouts.firstIndex(where: { $0.endRuntime > tappedRuntime }) ?? levels.count
    }

    private func appendWaypoint() {
        let lastDepth = levels.last?.depth ?? 0
        levels.append(DiveLevel(depth: lastDepth, time: defaultHoldTime))
    }

    private func deleteWaypoint(id: UUID) {
        guard levels.count > 1, let index = levels.firstIndex(where: { $0.id == id }) else { return }
        levels.remove(at: index)
    }

    private func holdTimeBinding(for id: UUID) -> Binding<Double> {
        Binding(
            get: { levels.first(where: { $0.id == id })?.time ?? 0 },
            set: { newValue in
                guard let index = levels.firstIndex(where: { $0.id == id }) else { return }
                levels[index].time = max(0, newValue)
            }
        )
    }

    private func depthLabel(for metricDepth: Double) -> String {
        let displayDepth = unitSystem.depth(metricDepth)
        return unitSystem == .metric
            ? "\(Int(displayDepth.rounded())) m"
            : "\(Int(displayDepth.rounded())) ft"
    }

    private var totalRuntime: Double {
        profilePoints.last?.runtime ?? 0
    }

    private var waypoints: [DiveLevel] { levels }

    private var waypointLayouts: [WaypointLayout] {
        var currentDepth = 0.0
        var currentRuntime = 0.0
        var layouts: [WaypointLayout] = []

        for level in levels {
            let rate = level.depth >= currentDepth ? descentRate : ascentRate
            let transit = abs(level.depth - currentDepth) / max(rate, 0.1)
            let arrival = currentRuntime + transit
            let end = arrival + max(level.time, 0)
            let handle = arrival + max(level.time, 0) / 2

            layouts.append(
                WaypointLayout(
                    id: level.id,
                    depth: level.depth,
                    arrivalRuntime: arrival,
                    endRuntime: end,
                    handleRuntime: handle
                )
            )

            currentDepth = level.depth
            currentRuntime = end
        }

        return layouts
    }

    private var profilePoints: [RuntimeDepthPoint] {
        var points: [RuntimeDepthPoint] = [RuntimeDepthPoint(runtime: 0, depth: 0)]
        var currentDepth = 0.0
        var currentRuntime = 0.0

        for level in levels {
            let rate = level.depth >= currentDepth ? descentRate : ascentRate
            let transit = abs(level.depth - currentDepth) / max(rate, 0.1)
            let arrival = currentRuntime + transit
            points.append(RuntimeDepthPoint(runtime: arrival, depth: level.depth))

            let end = arrival + max(level.time, 0)
            points.append(RuntimeDepthPoint(runtime: end, depth: level.depth))

            currentDepth = level.depth
            currentRuntime = end
        }

        if currentDepth > 0 {
            let ascent = currentDepth / max(ascentRate, 0.1)
            points.append(RuntimeDepthPoint(runtime: currentRuntime + ascent, depth: 0))
        }

        return deduplicated(points)
    }

    private func deduplicated(_ points: [RuntimeDepthPoint]) -> [RuntimeDepthPoint] {
        var result: [RuntimeDepthPoint] = []
        for point in points {
            if let last = result.last, abs(last.runtime - point.runtime) < 0.0001, abs(last.depth - point.depth) < 0.0001 {
                continue
            }
            result.append(point)
        }
        return result
    }
}

private struct RuntimeDepthPoint: Equatable {
    let runtime: Double
    let depth: Double
}

private struct WaypointLayout: Identifiable {
    let id: UUID
    let depth: Double
    let arrivalRuntime: Double
    let endRuntime: Double
    let handleRuntime: Double
}
