import SwiftUI

/// DPI stage slider without AppKit tick marks.
/// Snaps to `step` in the binding so values stay identical to the previous stepped Slider.
struct DpiSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 100...16000
    var step: Double = 50

    var body: some View {
        Slider(
            value: Binding(
                get: { value },
                set: { raw in
                    let clamped = min(max(raw, range.lowerBound), range.upperBound)
                    value = (clamped / step).rounded() * step
                }
            ),
            in: range
        )
        .controlSize(.regular)
        .tint(Theme.accent)
        .accessibilityValue("\(Int(value))")
    }
}
