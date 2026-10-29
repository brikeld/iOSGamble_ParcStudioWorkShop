import Foundation

/// All product and price data. Edit here.
enum Catalog {
    static let iPad = Device(
        kind: "iPad",
        products: [
            Product(name: "iPad", storage: [.init("128GB", 449), .init("256GB", 549), .init("512GB", 749)]),
            Product(name: "iPad mini", storage: [.init("128GB", 599), .init("256GB", 699), .init("512GB", 899)]),
            Product(name: "iPad Air 11″", storage: [.init("128GB", 749), .init("256GB", 849), .init("512GB", 1049), .init("1TB", 1349)]),
            Product(name: "iPad Air 13″", storage: [.init("128GB", 949), .init("256GB", 1049), .init("512GB", 1249), .init("1TB", 1549)]),
            Product(name: "iPad Pro 11″", storage: [.init("256GB", 1199), .init("512GB", 1399), .init("1TB", 1799), .init("2TB", 2299)]),
            Product(name: "iPad Pro 13″", storage: [.init("256GB", 1499), .init("512GB", 1699), .init("1TB", 2099), .init("2TB", 2599)]),
        ],
        // What the user bought: iPad Air 11″, 128GB, Wi‑Fi.
        start: 2,
        upgrades: [
            Upgrade(name: "Apple Pencil", icon: "pencil", price: 129, image: "apple-pencil"),
            Upgrade(name: "Magic Keyboard", icon: "keyboard", price: 269, image: "magic-keyboard"),
            Upgrade(name: "Pro Storage", icon: "internaldrive", price: 0),  // priced by the iPad's own storage tiers
            airPods,
        ],
        proStorage: 2,
        // iPad, iPad mini, iPad Air 11″ and iPad Pro 11″.
        board: [0, 1, 2, 4]
    )

    /// Prices from apple.com (US), October 2026. The finishes match the photos.
    static let iPhone = Device(
        kind: "iPhone",
        products: [
            Product(name: "iPhone 17e", storage: [.init("256GB", 699), .init("512GB", 899)], finish: "Soft Pink"),
            Product(name: "iPhone 17", storage: [.init("256GB", 899), .init("512GB", 1099)], finish: "Lavender"),
            Product(name: "iPhone Air", storage: [.init("256GB", 1099), .init("512GB", 1299), .init("1TB", 1699)], finish: "Sky Blue"),
            Product(name: "iPhone 18 Pro", storage: [.init("256GB", 1199), .init("512GB", 1399), .init("1TB", 1799), .init("2TB", 2399)],
                    finish: "Burgundy"),
            Product(name: "iPhone 18 Pro Max", storage: [.init("256GB", 1299), .init("512GB", 1499), .init("1TB", 1899), .init("2TB", 2499)],
                    finish: "Silver"),
        ],
        // What the user bought: iPhone Air, 256GB, Sky Blue.
        start: 2,
        upgrades: [
            Upgrade(name: "MagSafe Charger", icon: "magsafe.batterypack", price: 39, image: "magsafe-charger"),  // no charger symbol; the MagSafe one
            Upgrade(name: "Silicone Case", icon: "iphone.case", price: 49, image: "silicone-case"),
            Upgrade(name: "AppleCare+", icon: "checkmark.shield", price: 199),
            airPods,
        ],
        proStorage: nil,
        board: [0, 1, 2, 3, 4]
    )

    /// The order holds both; iChance is played with one of them.
    static let devices = [iPad, iPhone]

    private static let airPods = Upgrade(name: "AirPods Pro 4", icon: "airpods.gen4.chargingcase.wireless", price: 249, image: "airpods-pro")

    /// Every this many pulls, more spins have to be bought.
    static let spinsPerPayment = 3
    static let spinPrice = 50
    /// Products: the first drop is free, then 50, 100, 150…
    static let dropPriceStep = 50
}

/// One device in the order, with everything its games need.
struct Device: Hashable {
    /// "iPad", "iPhone": for copy such as "your last iPhone".
    let kind: String
    /// Cheapest to most expensive. A loss drops you one step down this line.
    let products: [Product]
    /// Index into `products` of what was bought, in its base storage.
    let start: Int
    /// Features hands these out one by one, in this order. It never changes the product upward.
    let upgrades: [Upgrade]
    /// Index of Pro Storage in `upgrades`: holding it gives the product its largest storage.
    let proStorage: Int?
    /// The products the Products board can land on. Each round shows the ones you don't already have, plus Nothing.
    let board: [Int]

    var paid: Int { products[start].storage[0].price }
    /// Icons only, one per upgrade. A jackpot shows the one you win three times.
    var featureSymbols: [ReelSymbol] { upgrades.map { ReelSymbol($0.name, icon: $0.icon) } }
}

struct Option: Hashable {
    let label: String
    let price: Int
    init(_ label: String, _ price: Int) { self.label = label; self.price = price }
}

struct Upgrade: Hashable {
    let name: String
    let icon: String
    let price: Int
    /// A product photo in the asset catalogue; the ones without fall back to the icon.
    var image: String? = nil
}

struct ReelSymbol: Hashable {
    let text: String
    let icon: String?
    init(_ text: String, icon: String? = nil) { self.text = text; self.icon = icon }
}

struct Product: Hashable {
    let name: String
    let storage: [Option]
    /// Every iPad here is Wi‑Fi; an iPhone shows its colour.
    var finish = "Wi‑Fi"

    /// Asset catalog image: "iPad Air 11″" → "ipad-air-11".
    var image: String { name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "″", with: "") }

    /// "128GB · Wi‑Fi", "256GB · Lavender".
    func describe(_ storage: Option) -> String { "\(storage.label) · \(finish)" }
}
