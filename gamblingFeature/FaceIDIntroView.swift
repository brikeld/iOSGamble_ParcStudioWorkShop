import SwiftUI

/// The Face ID sequence that opens the app: the Face ID glyph appears, turns into the green
/// "detecting" animation and finishes on its checkmark with the Apple Pay chime, then
/// `onFinished` reveals the order confirmation. Like the Apple Pay sheet, it's a recreation:
/// nothing is actually authenticated.
///
/// The animation is FaceIDDetecting.json, the "Face Unlock" Lottie with its black container layer
/// removed, played by `FaceIDAnimation`. At 60 fps, frame 27 is where the green dots start and
/// frame 76 is where the checkmark appears.
struct FaceIDIntroView: View {
    var onFinished: () -> Void

    @State private var step = Step.hidden

    private enum Step { case hidden, glyph, detecting, done }

    private static let frameRate = 60.0
    private static let firstFrame = 27.0
    private static let tickAppears = 76.0
    private static let lastFrame = 118.0  // the checkmark fully drawn, before it fades out

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                switch step {
                case .hidden:
                    Color.clear
                case .glyph:
                    Image(systemName: "faceid")
                        .font(.system(size: 64))
                        .symbolEffect(.pulse)
                        .transition(.symbolEffect(.drawOn))
                case .detecting, .done:
                    FaceIDDetectingView(firstFrame: Self.firstFrame, lastFrame: Self.lastFrame)
                        .frame(width: 220, height: 185)
                        .transition(.opacity)
                }
            }
            .frame(height: 100)

            Text(step == .done ? "Done" : "Face ID")
                .font(.subheadline.weight(.medium))
                .transaction { $0.animation = nil }  // "Face ID" becomes "Done" instantly, without the cross-fade
        }
        .foregroundStyle(.white)
        .frame(width: 168, height: 168)
        .background(Color(white: 0.12), in: .rect(cornerRadius: 28, style: .continuous))
        // Pinned to the top, 8 pt below the safe area, which starts under the Dynamic Island.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
        .animation(.smooth, value: step)
        .sensoryFeedback(.success, trigger: step == .done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step == .done ? "Face ID verified" : "Face ID")
        .task {
            // Load the chime and parse the animation while nothing is moving, not when they're first needed.
            Task { await Sound.prepare() }
            _ = FaceIDAnimation.shared
            try? await Task.sleep(for: .seconds(0.3))
            step = .glyph
            try? await Task.sleep(for: .seconds(1.2))  // the glyph, before it turns into the detecting animation
            step = .detecting
            try? await Task.sleep(for: .seconds((Self.tickAppears - Self.firstFrame) / Self.frameRate))
            step = .done
            Sound.win.play()  // the Apple Pay success chime, as the checkmark appears
            try? await Task.sleep(for: .seconds((Self.lastFrame - Self.tickAppears) / Self.frameRate + 0.8))
            onFinished()
        }
    }
}

#Preview {
    FaceIDIntroView {}
}
