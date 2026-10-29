import SwiftUI

struct ChooseGameView: View {
    /// Index into `Catalog.devices` of the device being played.
    @Binding var current: Int

    @Environment(Game.self) private var game
    /// The Features card hugs its text; the Products card is held to this height so the two cards match.
    @State private var featuresHeight: CGFloat?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iChance")
                        .font(.largeTitle.bold())
                    Text("Try your luck at upgrading your \(game.device.kind)’s technical configuration, or swap your product for another league altogether.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)  // as the offer's subtitle on the order screen
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
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { featuresHeight = $0 }
                }
                .listRowInsets(.vertical, 0)
                .navigationLinkIndicatorVisibility(.hidden)
            } header: {
                header("Betting Options")
            }
            Section {
                NavigationLink(value: Screen.game(.product)) {
                    choice(symbol: "arrow.turn.up.forward.iphone", title: "Products",
                           detail: "Upgrade your product to another tier.")
                        .frame(height: featuresHeight)  // as tall as the Features card, content centred
                }
                .listRowInsets(.vertical, 0)
                .navigationLinkIndicatorVisibility(.hidden)
            }
        }
        .listSectionSpacing(.compact)
        // 24 pt between the back button and the iChance card: the list adds about 10 pt of its own below the bar.
        .contentMargins(.top, 14, for: .scrollContent)
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
        .padding(.vertical, 16)  // the whole gap above and below: the row's own vertical insets are zeroed
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

#Preview("Choose, pushed under the back button") {
    @Previewable @State var path = [Screen.choose]
    NavigationStack(path: $path) {
        Color.clear.navigationDestination(for: Screen.self) { _ in
            ChooseGameView(current: .constant(0))
        }
    }
    .environment(Game(device: Catalog.devices[0]))
    .frame(width: 402, height: 874)  // an iPhone 17 Pro's screen, so the text wraps as it does there
}
