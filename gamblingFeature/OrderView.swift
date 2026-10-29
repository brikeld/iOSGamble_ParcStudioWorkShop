import SwiftUI

/// Apple Store-style order confirmation, with the iChance offer underneath.
struct OrderView: View {
    var onTry: () -> Void


    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 8) {
                        // An HStack, not a Label: List rows squeeze a Label's icon and cut the checkmark.
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .green)
                            Text("Thank you for your order")
                        }
                        // The design's type scale: 32 pt headline, 24 pt title, 14 pt body.
                        .font(.system(size: 24, weight: .semibold))
                        Text("Your order will be delivered by courier. Someone must be present to receive your items.")
                            .font(.system(size: 14))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Order Number: \(Text("W730583904").foregroundStyle(.tint).underline())")
                        Text("Ordered on: \(Date.now.formatted(date: .numeric, time: .omitted))")
                    }
                    .font(.footnote)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
            }

            Section {
                ForEach(Catalog.devices, id: \.self) { device in
                    let product = device.products[device.start]
                    HStack(spacing: 32) {
                        Image(product.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 66, height: 66)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(product.name)
                                .fontWeight(.semibold)
                            Text(product.describe(product.storage[0]))
                            Text("Paid · Delivers \(Date.now.addingTimeInterval(2 * 86_400).formatted(.dateTime.weekday().day().month()))")
                            Divider()
                            LabeledContent("Qty: 1", value: device.paid.dollars)
                                .foregroundStyle(.primary)
                        }
                        .font(.footnote)
                    }
                    .padding(.vertical, 8)
                }
            }

            Section {
                offer
                    .environment(\.colorScheme, .dark)
                    .listRowBackground(Color(.secondarySystemGroupedBackground).environment(\.colorScheme, .dark))
            } footer: {
                Text("Participation is restricted to persons who meet the applicable legal age requirements. Gamble responsibly and within your financial means.")
            }
        }
        .listSectionSpacing(16)
        .contentMargins(.top, 24, for: .scrollContent)  // 24 pt below the status bar
        .scrollBounceBehavior(.basedOnSize)
    }

    /// Spacing follows the Apple Store card: tight inside a group, 12–20 pt between groups.
    private var offer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NEW")
                .font(.footnote.bold())
                .foregroundStyle(.orange)
                .padding(.bottom, 12)
            Text("Upgrade your iPad or iPhone for free!")
                .font(.system(size: 32, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 8)
            Text("A secure experience where you have a chance of upgrading your device, completely free.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 20)
            Button(action: onTry) {
                Text("Try iChance").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    OrderView {}
        .frame(width: 402, height: 874)  // an iPhone 17 Pro's screen, so the text wraps as it does there
}
