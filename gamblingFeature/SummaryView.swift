import SwiftUI

/// What each device's game ends with, then the whole order's money: both devices added together.
struct SummaryView: View {
    let games: [Game]
    var onDone: () -> Void

    var body: some View {
        let paid = games.reduce(0) { $0 + $1.device.paid }
        let fees = games.reduce(0) { $0 + $1.fees }
        let value = games.reduce(0) { $0 + $1.value }
        let profit = games.reduce(0) { $0 + $1.profit }
        NavigationStack {
            List {
                ForEach(games, id: \.device) { game in
                    Section("Your \(game.device.kind)") {
                        if game.phase == .nothing {
                            Label("Nothing", systemImage: "shippingbox")
                        } else {
                            HStack(spacing: 16) {
                                Image(game.product.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 64)
                                VStack(alignment: .leading) {
                                    Text(game.product.name)
                                        .font(.headline)
                                    Text(game.configuration)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ForEach(game.held, id: \.self) { upgrade in
                                UpgradeRow(upgrade: upgrade)
                            }
                        }
                    }
                }
                Section {
                    LabeledContent("Paid", value: paid.dollars)
                    if fees > 0 {
                        LabeledContent("Extra spins", value: fees.dollars)
                    }
                    LabeledContent("Value", value: value.dollars)
                    LabeledContent("Profit or Loss") {
                        Text(profitText(profit)).foregroundStyle(profitColor(profit))
                    }
                    // Slot spins and ball drops, on both devices.
                    LabeledContent("Bets", value: games.reduce(0) { $0 + $1.spins + $1.drops }.formatted())
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
