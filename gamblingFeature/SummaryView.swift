import SwiftUI

/// What each device's game ends with, then the whole order's money: both devices added together.
/// Each device shows what was ordered, faded, above what you'll receive, joined by what changed.
struct SummaryView: View {
    let games: [Game]
    /// Hides the summary and goes back to the game, keeping everything as it was.
    var onClose: () -> Void
    /// Ends the session.
    var onDone: () -> Void

    /// The money card shows only the profit or loss until it's tapped open.
    @State private var showsDetails = false

    var body: some View {
        let paid = games.reduce(0) { $0 + $1.device.paid }
        let fees = games.reduce(0) { $0 + $1.fees }
        let value = games.reduce(0) { $0 + $1.value }
        let profit = games.reduce(0) { $0 + $1.profit }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(games, id: \.device) { game in
                        header("Your \(game.device.kind)")
                        DeviceResult(game: game)
                    }
                    VStack(spacing: 0) {
                        Button {
                            withAnimation(.smooth(duration: 0.35)) { showsDetails.toggle() }
                        } label: {
                            HStack(spacing: 10) {
                                Text(profit > 0 ? "Profit" : profit < 0 ? "Loss" : "Break Even")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(profitText(profit))
                                    .foregroundStyle(Change(delta: profit).color)
                                    .monospacedDigit()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .rotationEffect(.degrees(showsDetails ? 90 : 0))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(showsDetails ? "Hides the details" : "Shows what was paid and what it's worth")
                        if showsDetails {
                            Group {
                                Divider().padding(.leading, 16)
                                total("Paid", paid.dollars)
                                if fees > 0 {
                                    Divider().padding(.leading, 16)
                                    total("Extra spins", fees.dollars)
                                }
                                Divider().padding(.leading, 16)
                                total("Value", value.dollars)
                                Divider().padding(.leading, 16)
                                // Slot spins and ball drops, on both devices.
                                total("Bets", games.reduce(0) { $0 + $1.spins + $1.drops }.formatted())
                            }
                            .transition(.opacity)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
                    .padding(.top, 14)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)  // plus the first header's own 14 pt: 24 pt below the navigation bar
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", role: .cancel, action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
    }

    private func total(_ label: String, _ value: String, color: Color = .secondary) -> some View {
        LabeledContent(label) {
            Text(value).foregroundStyle(color).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// Upgraded, downgraded, lost or kept, and the money it made or cost: the words, symbol and colour for one device.
private struct Change {
    var word = ""
    var symbol = ""
    var outcome: Outcome?
    var delta: Int

    var color: Color { outcome?.color ?? .secondary }

    init(delta: Int) {
        self.delta = delta
        outcome = delta > 0 ? .won : delta < 0 ? .lost : nil
    }

    init(_ game: Game) {
        self.init(delta: game.value - game.device.paid)
        let start = game.device.start
        if game.phase == .nothing {
            (word, symbol, outcome) = ("Lost", "arrow.down", .lost)
        } else if game.productIndex > start {
            (word, symbol, outcome) = ("Upgraded", "arrow.up", .won)
        } else if game.productIndex < start {
            (word, symbol, outcome) = ("Downgraded", "arrow.down", .lost)
        } else if game.upgrades > 0 {
            (word, symbol, outcome) = ("Same \(game.device.kind), more inside", "plus", .won)
        } else {
            (word, symbol, outcome) = ("Unchanged", "equal", nil)
        }
    }
}

/// One device: the ordered product faded with its price struck through, a short coloured line with what changed,
/// then what you'll receive and the accessories won. Outlined in the result's colour, like the Your Product card.
private struct DeviceResult: View {
    let game: Game

    var body: some View {
        let change = Change(game)
        let ordered = game.device.products[game.device.start]
        VStack(spacing: 0) {
            row(image: ordered.image, title: ordered.name, subtitle: "Ordered · \(ordered.describe(ordered.storage[0]))") {
                Text(game.device.paid.dollars).strikethrough(color: Color(.tertiaryLabel))
            }
            .opacity(0.5)
            HStack(spacing: 8) {
                Capsule().fill(change.outcome?.color ?? Color(.tertiaryLabel)).frame(width: 2, height: 22)
                chip(Label(change.word, systemImage: change.symbol), outcome: change.outcome)
                chip(Text(profitText(change.delta)), outcome: Change(delta: change.delta).outcome)
            }
            .padding(.leading, 37)  // the line sits under the middle of the photo
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            if game.phase == .nothing {
                row(symbol: "shippingbox", title: "Nothing", subtitle: "Won’t be delivered") { EmptyView() }
            } else {
                row(image: game.product.image, title: game.product.name, subtitle: game.configuration) {
                    Text(game.storage.price.dollars)
                }
                ForEach(Array(game.held.enumerated()), id: \.offset) { i, upgrade in
                    Divider().padding(.leading, 74)
                    accessory(upgrade, i)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 26))
        .overlay {
            if let outcome = change.outcome {
                RoundedRectangle(cornerRadius: 26).strokeBorder(outcome.color, lineWidth: 2)
            }
        }
    }

    /// Pro Storage is already in the configuration and its price above, so it isn't counted again.
    private func accessory(_ upgrade: Upgrade, _ i: Int) -> some View {
        let included = i == game.device.proStorage
        return Group {
            if let image = upgrade.image {
                row(image: image, title: upgrade.name, small: true) { price(upgrade, i, included) }
            } else {
                row(symbol: upgrade.icon, title: upgrade.name) { price(upgrade, i, included) }
            }
        }
    }

    private func price(_ upgrade: Upgrade, _ i: Int, _ included: Bool) -> some View {
        Text(included ? "Included" : "+" + game.price(ofUpgrade: i).dollars)
            .foregroundStyle(included ? Color.secondary : Outcome.won.color)
    }

    private func row(image: String? = nil, symbol: String? = nil, title: String, subtitle: String? = nil, small: Bool = false,
                     @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 14) {
            Group {
                if let image {
                    Image(image).resizable().scaledToFit().frame(width: small ? 36 : 44, height: small ? 36 : 48)
                } else if let symbol {
                    Image(systemName: symbol).font(.title3).foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing()
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func chip(_ content: some View, outcome: Outcome?) -> some View {
        content
            .font(.footnote.weight(.semibold))
            .foregroundStyle(outcome?.color ?? .secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(outcome.map { $0 == .won ? Color.green.opacity(0.2) : Color.orange.opacity(0.16) } ?? Color(.tertiarySystemFill),
                        in: .capsule)
    }
}

#Preview {
    SummaryView(games: Catalog.devices.map { Game(device: $0) }, onClose: {}, onDone: {})
        .frame(width: 402, height: 660)  // an iPhone 17 Pro's width; shorter than the phone so the canvas doesn't crop the nav bar
}
