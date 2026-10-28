import SwiftUI

struct ChooseGameView: View {
    @Environment(Game.self) private var game

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iChance")
                        .font(.largeTitle.bold())
                    Text("Try your luck at upgrading your iPad’s technical configuration, or swap your product for another league altogether.")
                        .font(.footnote)
                }
                .padding(.vertical, 8)
                .environment(\.colorScheme, .dark)
                .listRowBackground(Color(.secondarySystemGroupedBackground).environment(\.colorScheme, .dark))
            }
            // What you'd receive right now, kept up to date as you win and lose.
            Section {
                if game.phase == .nothing {
                    Label("Nothing", systemImage: "shippingbox")
                } else {
                    ProductRow(product: game.product, configuration: game.configuration)
                        .padding(.vertical, 4)
                    // Only the accessories that come in a box; Pro Storage and Nano Texture are part of the iPad.
                    ForEach(game.held.filter { $0.image != nil }, id: \.self) { upgrade in
                        UpgradeRow(upgrade: upgrade)
                    }
                }
            } header: {
                header("Your Product")
            }
            Section {
                NavigationLink(value: Screen.game(.features)) {
                    choice(symbol: "gauge.with.dots.needle.67percent", title: "Features",
                           detail: "Max out your iPad’s technical configuration and experience.")
                }
            } header: {
                header("Betting Options")
            }
            Section {
                NavigationLink(value: Screen.game(.product)) {
                    choice(symbol: "arrow.turn.up.forward.iphone", title: "Products",
                           detail: "Upgrade your product to another tier.")
                }
            }
        }
        .listSectionSpacing(.compact)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(.footnote)
    }

    private func choice(symbol: String, title: String, detail: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.footnote)
            }
        } icon: {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 12)
    }
}

/// An accessory you've won: its photo, or its symbol when there's no photo, laid out like `ProductRow`.
struct UpgradeRow: View {
    let upgrade: Upgrade

    var body: some View {
        HStack(spacing: 32) {
            Group {
                if let image = upgrade.image {
                    Image(image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: upgrade.icon)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 46, height: 46)
            Text(upgrade.name)
                .font(.subheadline.weight(.semibold))
        }
    }
}
