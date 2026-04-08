// SharedComponents.swift
// Reusable SwiftUI helpers used across views

import SwiftUI

/// A labelled slider showing value in a badge on the right.
struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text(String(format: format, value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.cyan)
                    .frame(minWidth: 70, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: step)
                .tint(.cyan)
        }
    }
}
