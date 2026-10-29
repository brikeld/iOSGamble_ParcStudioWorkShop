import SwiftUI

/// One device's iChance game: what you have, the reels, and what you've paid. The iPad and the iPhone each have one.
@Observable final class Game {
    enum Mode: Hashable { case features, product }
    /// After `won` or `lost` the player chooses: keep gambling or keep what they have.
    enum Phase { case idle, spinning, won, lost, nothing }
    /// What the last pull changed, so the screen can flash it: green for won, orange for lost.
    struct Change: Equatable {
        /// Index into the device's upgrades, won outright or handed out as consolation.
        var upgradeWon: Int?
        var upgradesLost = 0..<0
        /// +1 up a product, −1 down.
        var iPad = 0
    }

    private(set) var mode = Mode.features
    /// The iPad or the iPhone.
    let device: Device
    private(set) var productIndex: Int
    /// How many of the device's upgrades you hold: always the first ones, in order.
    private(set) var upgrades = 0
    /// Each reel's symbols, in its own shuffled order.
    private(set) var strips: [[ReelSymbol]] = []
    /// Reel positions in rows, unbounded; `row % strip.count` is the symbol on the payline.
    private(set) var reels: [Double] = []
    /// Where the reels rest between pulls; dragging the slider turns them from here.
    private var restingReels: [Double] = []
    /// Counts reels coming to a stop, for the haptic clunk.
    private(set) var reelStops = 0
    private(set) var spins = 0
    private(set) var phase = Phase.idle
    private(set) var change: Change?
    /// The beat right after a pull lands, while its colours flash and before the choice appears.
    private(set) var isMoment = false
    /// Pulls left before the next payment; at 0 the slider gives way to the Apple Pay button.
    private(set) var spinsLeft = Catalog.spinsPerPayment
    /// Paid for extra spins and tries, on top of the device.
    private(set) var fees = 0
    /// Products: what's under the board this round, cheapest first: nil is Nothing, then indices into the device's products.
    private(set) var bins: [Int?] = []
    /// Each bin's chance this round, adding up to 1.
    private(set) var odds: [Double] = []
    /// The bin the last ball fell into, until the next round.
    private(set) var landedBin: Int?
    private(set) var drops = 0
    private(set) var paidDrops = 0
    var showsSummary = false

    init(device: Device = Catalog.iPad) {
        self.device = device
        productIndex = device.start
        play(.features)
    }

    var product: Product { device.products[productIndex] }
    var held: ArraySlice<Upgrade> { device.upgrades.prefix(upgrades) }
    /// Pro Storage swaps the base storage for the product's largest.
    var storage: Option { device.proStorage.map { upgrades > $0 } == true ? product.storage.last! : product.storage[0] }
    var configuration: String { product.describe(storage) }
    /// What an upgrade is worth on the current product; Pro Storage is its jump to the largest storage.
    func price(ofUpgrade i: Int) -> Int {
        i == device.proStorage ? product.storage.last!.price - product.storage[0].price : device.upgrades[i].price
    }
    var value: Int { phase == .nothing ? 0 : held.reduce(storage.price) { $0 + $1.price } }
    var totalPaid: Int { device.paid + fees }
    var profit: Int { value - totalPaid }
    var needsPayment: Bool { spinsLeft == 0 }
    var lostLast: Bool { change.map { !$0.upgradesLost.isEmpty || $0.iPad < 0 } ?? false }
    /// On the cheapest product with nothing else left to take, a loss means receiving nothing.
    var isLastChance: Bool { productIndex == 0 && upgrades == 0 }
    /// The first drop is free, then each one costs more than the last: 50, 100, 150…
    var dropPrice: Int { drops * Catalog.dropPriceStep }
    var needsDropPayment: Bool { drops > paidDrops }

    /// Holding the board's best product: the place to go on and win its features.
    var hasBestTierProduct: Bool { productIndex == device.board.max() }

    /// Features ends once you hold every upgrade on a product above the one you ordered;
    /// Products can always be played again.
    func canPlay(_ mode: Mode) -> Bool {
        phase != .nothing && (mode == .product || !(upgrades == device.upgrades.count && productIndex > device.start))
    }

    func play(_ mode: Mode) {
        self.mode = mode
        if mode == .features {
            // A fresh machine must not already show three of a kind.
            repeat {
                strips = (0..<3).map { _ in device.featureSymbols.shuffled() }
            } while Set(strips.map { $0[0] }).count == 1
            reels = strips.map { _ in 0 }
            restingReels = reels
        } else {
            newRound()
        }
        if phase == .won || phase == .lost { phase = .idle }
    }

    /// Nothing, then every board product but yours. The closer a bin's price to your iPad's, the likelier the ball
    /// lands in it: odds go as one over the price gap, so a long shot is a narrow box. Nothing is priced at $0.
    private func newRound() {
        let price = { (i: Int?) in i.map { self.device.products[$0].storage[0].price } ?? 0 }
        bins = [nil] + device.board.filter { $0 != productIndex }
        let weights = bins.map { 1 / Double(abs(price($0) - price(productIndex))) }
        odds = weights.map { $0 / weights.reduce(0, +) }
        landedBin = nil
    }

    /// Starts a drop and draws its bin by the odds. Nil if it isn't allowed now.
    func startDrop() -> Int? {
        guard mode == .product, phase == .idle, !needsDropPayment else { return nil }
        phase = .spinning
        drops += 1
        var draw = Double.random(in: 0..<1)
        for (bin, chance) in odds.enumerated() {
            draw -= chance
            if draw < 0 { return bin }
        }
        return odds.indices.last
    }

    /// The ball has been eaten by a bin: you now have that product, and keep your upgrades.
    /// Nothing takes everything: the bin lights up for the moment, then the screen says so.
    func land(in bin: Int) async {
        guard let product = bins[bin] else {
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                landedBin = bin
                phase = .lost
                change = Change(upgradesLost: 0..<upgrades, iPad: -1)
                isMoment = true
            }
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.smooth) {
                isMoment = false
                phase = .nothing
            }
            return
        }
        var change = Change()
        change.iPad = product > productIndex ? 1 : -1  // the catalogue runs cheapest to dearest
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
            productIndex = product
            landedBin = bin
            phase = change.iPad > 0 ? .won : .lost
            self.change = change
            isMoment = true
        }
        try? await Task.sleep(for: .seconds(1.5))
        withAnimation(.smooth) { isMoment = false }
    }

    func payForDrop() {
        fees += dropPrice
        paidDrops += 1
        newRound()
        phase = .idle
    }

    /// After a win: carry on here, or in the other game once this one is finished.
    func keepGambling() {
        if canPlay(mode) { phase = .idle } else { play(mode == .features ? .product : .features) }
    }

    /// The reels follow the slider's knob, up to two rows, and slide back if it's let go early.
    func nudge(_ progress: Double) {
        guard phase == .idle else { return }
        reels = restingReels.map { $0 + progress * 2 }
    }

    func payForSpins() {
        fees += Catalog.spinPrice
        spinsLeft = Catalog.spinsPerPayment
    }

    /// Three of a kind wins the next prize, anything else costs you. `power`, 0…1, is how hard the slider was swiped.
    func pull(power: Double) async {
        guard mode == .features, phase == .idle, canPlay(mode), !needsPayment else { return }
        phase = .spinning
        spinsLeft -= 1
        let win = Double.random(in: 0..<1) < Odds.winChance
        spins += 1
        // The jackpot shows what this pull is for: the next upgrade, or the next product.
        let jackpot = device.featureSymbols[upgrades]
        let stops = Odds.stops(win: win)

        // Reels start together and stop left to right; a harder swipe keeps them going longer.
        let reelTasks = strips.indices.map { c in
            Task {
                await spinReel(c, to: strips[c].firstIndex(of: jackpot)! + stops[c],
                               rows: 14 + c * 6 + Int(power * 16), duration: 1.6 + Double(c) * 0.45 + power * 0.8)
            }
        }
        for task in reelTasks { await task.value }
        restingReels = reels
        assert(win == (Set(strips.indices.map { strips[$0][(Int(reels[$0]) % strips[$0].count + strips[$0].count) % strips[$0].count] }).count == 1),
               "only a win may show three of a kind")

        if !win { try? await Task.sleep(for: .seconds(1.2)) }  // let the near miss sink in
        withAnimation(.spring(duration: 0.6, bounce: win ? 0.3 : 0)) {
            settle(win: win)
            isMoment = true
        }
        try? await Task.sleep(for: .seconds(1.5))
        withAnimation(.smooth) { isMoment = false }
    }

    /// A win adds the next upgrade, and with all of them the product above. A loss takes every upgrade
    /// but keeps the product; with none left, it drops a product and hands back the first upgrade, and on the
    /// cheapest product it takes the product itself.
    func settle(win: Bool) {
        var change = Change()
        if win {
            phase = .won
            if upgrades < device.upgrades.count {
                change.upgradeWon = upgrades
                upgrades += 1
            } else {
                productIndex += 1
                change.iPad = 1
            }
        } else if isLastChance {
            phase = .nothing
        } else {
            phase = .lost
            if upgrades > 0 {
                change.upgradesLost = 0..<upgrades
                upgrades = 0
            } else {
                change.iPad = -1
                change.upgradeWon = 0
                productIndex -= 1
                upgrades = 1
            }
        }
        self.change = change
    }

    /// One continuous animation: a fast start that slows into the landing row, like a real reel.
    private func spinReel(_ c: Int, to position: Int, rows: Int, duration: Double) async {
        let count = strips[c].count
        let target = (position % count + count) % count
        let start = Int(reels[c].rounded())  // the slider may have left it between rows
        let landing = start + rows + (target - (start + rows) % count + count) % count
        withAnimation(.timingCurve(0.3, 0.1, 0.1, 1, duration: duration)) { reels[c] = Double(landing) }
        try? await Task.sleep(for: .seconds(duration))
        reelStops += 1
    }

    #if DEBUG
    /// The ladders from the brief, replayed at launch so a rule change can't quietly break them.
    static func selfCheck() {
        let down = Game()
        down.settle(win: true)
        down.settle(win: true)
        down.settle(win: false)
        assert(down.productIndex == Catalog.iPad.start && down.upgrades == 0, "a loss on your iPad takes your upgrades")
        down.settle(win: false)
        assert(down.productIndex == 1 && down.upgrades == 1, "with none left, it drops an iPad and hands back the Pencil")
        down.settle(win: true)
        down.settle(win: true)
        down.settle(win: false)
        assert(down.productIndex == 1 && down.upgrades == 0, "below your iPad too, upgrades go before the iPad does")
        down.settle(win: false)
        assert(down.productIndex == 0 && down.upgrades == 1, "then the next iPad down, with the Pencil")
        down.settle(win: false)
        assert(down.productIndex == 0 && down.upgrades == 0, "the last iPad loses its upgrades")
        down.settle(win: false)
        assert(down.phase == .nothing, "then itself")

        let up = Game()
        for _ in 0...Catalog.iPad.upgrades.count { up.settle(win: true) }
        assert(up.productIndex == Catalog.iPad.start + 1 && up.upgrades == Catalog.iPad.upgrades.count && !up.canPlay(.features),
               "every upgrade, then the iPad above ends Features")

        // The iPhone climbs the same way, with no Pro Storage to price.
        let phone = Game(device: Catalog.iPhone)
        assert(phone.value == Catalog.iPhone.paid && phone.profit == 0, "the iPhone starts as ordered")
        for _ in 0...Catalog.iPhone.upgrades.count { phone.settle(win: true) }
        assert(phone.product.name == "iPhone 18 Pro" && phone.value == 1199 + 39 + 49 + 199 + 249, "every iPhone upgrade, then the iPhone above")
    }
    #endif
}
