import SwiftUI

/// The "slide to power off" control: drag the knob all the way right, or flick it, to spin.
struct SlideToSpin: View {
    var label: String
    /// How far the knob is, 0…1, so the reels can follow it.
    var onDrag: (Double) -> Void = { _ in }
    /// Called with the swipe's speed, 0…1.
    var action: (Double) -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var offset = 0.0
    @State private var fired = false

    /// The knob fills the track's height, as in the design.
    static let height = 58.0
    private let knob = 58.0
    private let inset = 0.0

    var body: some View {
        GeometryReader { geometry in
            let travel = geometry.size.width - knob - inset * 2
            ZStack(alignment: .leading) {
                ShimmerText(text: label)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, knob)
                    .opacity(1 - offset / travel * 2)
                Image(systemName: "arrow.right")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: knob, height: knob)
                    .background(.tint, in: .circle)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(inset)
                    .offset(x: offset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                guard isEnabled, !fired else { return }
                                offset = min(max(drag.translation.width, 0), travel)
                                onDrag(offset / travel)
                                if offset == travel {
                                    fire(drag.velocity.width)
                                    withAnimation(.bouncy) { offset = 0 }
                                }
                            }
                            .onEnded { drag in
                                defer { fired = false }
                                guard isEnabled, !fired else { return }
                                if drag.predictedEndTranslation.width >= travel {
                                    // Inertia: a flick carries the knob the rest of the way at its own speed.
                                    let glide = min(max((travel - offset) / max(drag.velocity.width, 1), 0.08), 0.3)
                                    fire(drag.velocity.width)
                                    withAnimation(.easeOut(duration: glide)) { offset = travel } completion: {
                                        withAnimation(.bouncy) { offset = 0 }
                                    }
                                } else {
                                    withAnimation(.bouncy) {
                                        onDrag(0)
                                        offset = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: Self.height)
        .glassEffect(in: .capsule)
        .opacity(isEnabled ? 1 : 0.4)
        // Disabling the slider mid-swipe cancels the drag without calling onEnded, which would leave it stuck.
        .onChange(of: isEnabled) {
            fired = false
            offset = 0
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if isEnabled { action(0.5) } }
    }

    /// Faster swipes spin the reels longer.
    private func fire(_ velocity: Double) {
        fired = true
        action(min(max(velocity / 2500, 0), 1))
    }
}

/// "slide to unlock" shimmer.
private struct ShimmerText: View {
    let text: String
    @State private var phase = 0.0

    var body: some View {
        Text(text)
            .font(.title3)
            .foregroundStyle(.secondary)
            .overlay {
                Text(text)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .mask {
                        GeometryReader { geometry in
                            LinearGradient(colors: [.clear, .black, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: geometry.size.width / 2)
                                .offset(x: (phase * 1.5 - 0.5) * geometry.size.width)
                        }
                    }
            }
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}
