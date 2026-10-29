import SwiftUI

struct ChooseGameView: View {
    /// Index into `Catalog.devices` of the device being played.
    @Binding var current: Int

    @Environment(Game.self) private var game

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iChance")
                        .font(.largeTitle.bold())
                    Text("Try your luck at upgrading your \(game.device.kind)’s technical configuration, or swap your product for another league altogether.")
                        .font(.footnote)
                }
                .padding(.vertical, 8)
                .environment(\.colorScheme, .dark)
                .listRowBackground(Color(.secondarySystemGroupedBackground).environment(\.colorScheme, .dark))
            }
            // Which of the two ordered devices to play with. Each keeps its own game, so switching loses nothing.
            Section {
                Picker("Gamble With", selection: $current) {
                    ForEach(Catalog.devices.indices, id: \.self) { i in
                        Text(Catalog.devices[i].products[Catalog.devices[i].start].name).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                header("Gamble With")
            }
            // What you'd receive right now, kept up to date as you win and lose.
            Section {
                if game.phase == .nothing {
                    Label("Nothing", systemImage: "shippingbox")
                } else {
                    ProductRow(product: game.product, configuration: game.configuration)
                        .padding(.vertical, 4)
                    // Only the accessories that come in a box: Pro Storage and AppleCare+ aren't.
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
                           detail: "Max out your \(game.device.kind)’s technical configuration and experience.")
                }
                .navigationLinkIndicatorVisibility(.hidden)
            } header: {
                header("Betting Options")
            }
            Section {
                NavigationLink(value: Screen.game(.product)) {
                    choice(symbol: "arrow.turn.up.forward.iphone", title: "Products",
                           detail: "Upgrade your product to another tier.")
                }
                .navigationLinkIndicatorVisibility(.hidden)
            }
        }
        .listSectionSpacing(.compact)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(.footnote)
    }

    /// The row's own chevron, 20 × 20 and black at 35%, in place of the list's small grey one.
    private func choice(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.footnote)
                }
                .padding(.trailing, 16)
            } icon: {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.black.opacity(0.35))
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
