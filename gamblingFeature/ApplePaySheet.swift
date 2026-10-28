import SwiftUI

/// A recreation of the Apple Pay sheet with a fictional card. Nothing is charged:
/// the real sheet needs a merchant ID, which a free developer account can't have.
/// Double-tap stands in for double-clicking the side button.
struct ApplePaySheet: View {
    var amount: Int
    var onPaid: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step = Step.ready

    private enum Step { case ready, faceID, done }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Pay", systemImage: "apple.logo")
                    .labelStyle(WordmarkLabelStyle())
                    .font(.title2.weight(.semibold))
                    .accessibilityLabel("Apple Pay")
                Spacer()
                Button("Cancel", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(step != .ready)
            }
            .padding(.bottom, 20)

            card
            Divider().padding(.vertical, 16)

            HStack(alignment: .firstTextBaseline) {
                Text("Pay iChance")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(amount.dollars)
                    .font(.title2.weight(.semibold))
            }
            Spacer(minLength: 16)
            confirmation
        }
        .padding(24)
        .contentShape(.rect)
        .onTapGesture(count: 2, perform: pay)
        .accessibilityAction(named: "Pay", pay)
        .sensoryFeedback(.success, trigger: step == .done)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(.systemBackground))  // opaque, like the real sheet; glass let the pay button show through
        .interactiveDismissDisabled(step != .ready)
    }

    private var card: some View {
        HStack(spacing: 14) {
            // Fictional card art.
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 30)
                .overlay(alignment: .bottomTrailing) {
                    Text("PARC").font(.system(size: 6, weight: .bold)).foregroundStyle(.white).padding(3)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text("Parc Card")
                    .font(.body.weight(.medium))
                Text("•••• 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    /// The bottom of the sheet: the side-button prompt, then Face ID, then Done.
    @ViewBuilder private var confirmation: some View {
        VStack(spacing: 8) {
            switch step {
            case .ready:
                Image(systemName: "button.vertical.right.press")
                    .font(.largeTitle)
                    .symbolEffect(.pulse)
                Text("Double-Tap to Pay")
            case .faceID:
                Image(systemName: "faceid")
                    .font(.largeTitle)
                    .symbolEffect(.pulse)
                Text("Face ID")
            case .done:
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .transition(.symbolEffect(.drawOn))
                Text("Done")
            }
        }
        .font(.subheadline.weight(.medium))
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: step)
    }

    private func pay() {
        guard step == .ready else { return }
        Task {
            step = .faceID
            try? await Task.sleep(for: .seconds(1))
            step = .done
            Sound.win.play()  // the Apple Pay success chime
            try? await Task.sleep(for: .seconds(1))
            onPaid()
            dismiss()
        }
    }
}

/// " Pay": the Apple logo set tight against the word, like the wordmark.
private struct WordmarkLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 1) {
            configuration.icon
            configuration.title
        }
    }
}
