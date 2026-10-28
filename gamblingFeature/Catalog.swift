import Foundation

/// All product and price data. Edit here.
enum Catalog {
    /// Cheapest to most expensive. A loss drops you one step down this line.
    static let products = [
        Product(name: "iPad", storage: [.init("128GB", 449), .init("256GB", 549), .init("512GB", 749)]),
        Product(name: "iPad mini", storage: [.init("128GB", 599), .init("256GB", 699), .init("512GB", 899)]),
        Product(name: "iPad Air 11″", storage: [.init("128GB", 749), .init("256GB", 849), .init("512GB", 1049), .init("1TB", 1349)]),
        Product(name: "iPad Air 13″", storage: [.init("128GB", 949), .init("256GB", 1049), .init("512GB", 1249), .init("1TB", 1549)]),
        Product(name: "iPad Pro 11″", storage: [.init("256GB", 1199), .init("512GB", 1399), .init("1TB", 1799), .init("2TB", 2299)]),
        Product(name: "iPad Pro 13″", storage: [.init("256GB", 1499), .init("512GB", 1699), .init("1TB", 2099), .init("2TB", 2599)]),
    ]

    /// What the user just bought: iPad Air 11″, 128GB, Wi‑Fi.
    static let startProduct = 2
    static let paid = 749

    /// Every this many pulls, more spins have to be bought.
    static let spinsPerPayment = 4
    static let spinPrice = 50
    /// Product Tier: the first drop is free, then 50, 100, 150…
    static let dropPriceStep = 50
    /// The iPads the Products board can land on: iPad, iPad mini, iPad Air 11″, iPad Pro 11″ and 13″.
    /// Each round shows the ones you don't already have, plus Nothing.
    static let boardProducts = [0, 1, 2, 4, 5]

    /// Features hands these out one by one, in this order. Holding all of them, the next win is the iPad above.
    static let upgrades = [
        Upgrade(name: "Apple Pencil", icon: "pencil", price: 129, image: "apple-pencil"),
        Upgrade(name: "Magic Keyboard", icon: "keyboard", price: 269, image: "magic-keyboard"),
        Upgrade(name: "Pro Storage", icon: "internaldrive", price: 0),  // priced by the iPad's own storage tiers
        Upgrade(name: "Nano Texture", icon: "sun.dust", price: 300),  // no SF Symbol for it; a diffused sun reads as anti-glare
        Upgrade(name: "AirPods Pro 4", icon: "airpods.gen4.chargingcase.wireless", price: 249, image: "airpods-pro"),
    ]
    /// Index of Pro Storage in `upgrades`: holding it gives the iPad its largest storage.
    static let proStorage = 2

    /// Icons only: every upgrade, then the next iPad. A jackpot shows the one you win three times.
    static let featureSymbols = upgrades.map { ReelSymbol($0.name, icon: $0.icon) } + [ReelSymbol("Next iPad", icon: "ipad")]
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

    /// Asset catalog image: "iPad Air 11″" → "ipad-air-11".
    var image: String { name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "″", with: "") }

    /// "128GB · Wi‑Fi". Every iPad here is Wi‑Fi.
    func describe(_ storage: Option) -> String { "\(storage.label) · Wi‑Fi" }
}
