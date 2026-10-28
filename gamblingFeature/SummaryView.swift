import SwiftUI

struct SummaryView: View {
    var onDone: () -> Void

    @Environment(Game.self) private var game

    var body: some View {
        NavigationStack {
            List {
                Section("You’ll Receive") {
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
                Section {
                    LabeledContent("Paid", value: Catalog.paid.dollars)
                    if game.fees > 0 {
                        LabeledContent("Extra spins", value: game.fees.dollars)
                    }
                    LabeledContent("Value", value: game.value.dollars)
                    LabeledContent("Profit or Loss") {
                        Text(profitText(game.profit)).foregroundStyle(profitColor(game.profit))
                    }
                    LabeledContent("Spins", value: game.spins.formatted())
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
