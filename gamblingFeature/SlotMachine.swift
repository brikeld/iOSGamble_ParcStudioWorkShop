import SwiftUI

/// Three slot reels, each a curved drum like the picker wheel, behind one payline.
/// Positions are in rows and animate continuously, so a spin is one smooth, slowing motion.
struct SlotMachine: View {
    var strips: [[ReelSymbol]]
    var positions: [Double]
    /// Colours the payline after a pull.
    var outcome: Outcome?

    static let rowHeight = 60.0

    var body: some View {
        ZStack {
            // The band the three symbols must match on: a lighter tint than the pills, so they stand out on it.
            Capsule()
                .fill(outcome?.fill.opacity(0.5) ?? Color(.systemGray5))
                .frame(height: Self.rowHeight)

            HStack(spacing: 0) {
                ForEach(strips.indices, id: \.self) { c in
                    Reel(strip: strips[c], position: positions[c], fill: outcome?.fill)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)  // room for the arrows at each end

            arrows
        }
        .padding(8)
        // The container, in the same light fill as the capsules still to win.
        .background(Color(.secondarySystemGroupedBackground).opacity(0.5), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("Slot")
        .accessibilityValue(strips.indices.map { Reel.symbol(strips[$0], at: positions[$0]).text }.joined(separator: ", "))
    }

    /// The payline's markers, drawn above the pills so they're never covered.
    private var arrows: some View {
        HStack(spacing: 0) {
            Image(systemName: "arrowtriangle.right.fill")
            Spacer()
            Image(systemName: "arrowtriangle.left.fill")
        }
        .font(.caption2)
        .foregroundStyle(outcome?.color ?? Color(.systemGray2))
        .padding(.horizontal, 4)
    }
}

/// One reel. Animatable, so SwiftUI redraws only these few symbols on every frame of a spin,
/// and ticks — a click and a haptic — each time a row passes the payline.
private struct Reel: View, Animatable {
    let strip: [ReelSymbol]
    var position: Double
    /// The payline's colour after a pull, for the pill sitting on it.
    let fill: Color?

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    /// The drum's radius: rows one `rowHeight` apart on the payline, curving away above and below.
    private static let radius = 120.0
    private static let step = SlotMachine.rowHeight / radius

    static func symbol(_ strip: [ReelSymbol], at position: Double) -> ReelSymbol {
        let count = strip.count
        return strip[(Int(position.rounded()) % count + count) % count]
    }

    var body: some View {
        let base = Int(position.rounded(.down))
        ZStack {
            ForEach(base - 4...base + 4, id: \.self) { row in
                // Rows below the payline have higher positions, so spinning moves the symbols down.
                let angle = (position - Double(row)) * Self.step
                if abs(angle) < .pi / 2 {
                    // Like the picker wheel: the row on the payline is solid with its pill, the rest fade back.
                    // 1 on the payline, 0 a row away, so a row brightens smoothly as it rolls in.
                    let emphasis = max(0, 1 - abs(position - Double(row)))
                    Self.face(Self.symbol(strip, at: Double(row)), pill: fill ?? Color(.secondarySystemGroupedBackground), emphasis: emphasis)
                        .scaleEffect(x: 1, y: cos(angle))
                        .offset(y: sin(angle) * Self.radius)
                        .opacity(cos(angle))
                }
            }
        }
        .frame(height: Self.radius * 2)
        .frame(maxWidth: .infinity)
        .clipped()
        .onChange(of: Int(position.rounded())) { Ticker.tick() }
    }

    /// An icon for the Features reels, the iPad's name for the Product reels; one type size for both.
    private static func face(_ symbol: ReelSymbol, pill: Color, emphasis: Double) -> some View {
        Group {
            if let icon = symbol.icon {
                Image(systemName: icon)
            } else {
                Text(symbol.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .font(.title3.weight(.medium))
        .opacity(0.3 + 0.7 * emphasis)
        .frame(maxWidth: .infinity)
        .frame(height: SlotMachine.rowHeight - 16)
        .background(pill.opacity(emphasis), in: .capsule)
        .padding(.horizontal, 8)
    }
}
