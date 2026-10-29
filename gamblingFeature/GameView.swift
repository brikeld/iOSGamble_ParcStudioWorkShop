import SwiftUI

/// Features is a slot machine; Products drops a ball from the notch through a board of toggles.
struct GameView: View {
    @Environment(Game.self) private var game
    @State private var confirmsLastChance = false
    @State private var paysForSpins = false
    @State private var paysForDrop = false
    @State private var drop = Drop()

    var body: some View {
        Group {
            if game.phase == .nothing {
                ContentUnavailableView {
                    Label("You’ll receive nothing.", systemImage: "shippingbox")
                } description: {
                    Text("You paid \(game.totalPaid.dollars). Your \(game.device.kind) won’t be delivered.")
                } actions: {
                    Button("View Summary") { game.showsSummary = true }
                        .buttonStyle(.glassProminent)
                }
            } else {
                machine
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Ticker.prepare() }
        .toolbar {
            // The title sits next to the back button, not centred.
            ToolbarItem(placement: .topBarLeading) {
                Text(game.mode == .features ? "Features" : "Products")
                    .font(.headline)
                    .fixedSize()  // toolbar items are otherwise squeezed to "Fea…"
                    .accessibilityAddTraits(.isHeader)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Gamble") {
                        Button("Features", systemImage: "gauge.with.dots.needle.67percent") {
                            withAnimation { game.play(.features) }
                        }
                        .disabled(game.mode == .features || !game.canPlay(.features))
                        Button("Products", systemImage: "arrow.turn.up.forward.iphone") {
                            withAnimation { game.play(.product) }
                        }
                        .disabled(game.mode == .product || !game.canPlay(.product))
                    }
                    Button("Leave iChance", systemImage: "rectangle.portrait.and.arrow.right") {
                        game.showsSummary = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .disabled(game.phase == .spinning)
            }
        }
    }

    /// A plain stack, not a List: List rows clip the capsules' strokes and squeeze their icons.
    private var machine: some View {
        let moment = game.isMoment ? game.change : nil
        // A product below the one you ordered is outlined orange, above it green; the card itself stays white.
        let start = game.device.start
        let tier: Outcome? = game.productIndex < start ? .lost : game.productIndex > start ? .won : nil

        return ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    header("Your Product")
                    HStack {
                        ProductRow(product: game.product, configuration: game.configuration)
                            .id(game.product)
                            .transition(.blurReplace)
                        Spacer()
                        // Products has no winnings header, so the card carries the running total, as in the design.
                        if game.mode == .product && game.profit != 0 {
                            Text(profitText(game.profit))
                                .font(.headline)
                                .foregroundStyle(game.profit > 0 ? Outcome.won.color : Outcome.lost.color)
                                .contentTransition(.numericText(value: Double(game.profit)))
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(fill: Color(.secondarySystemGroupedBackground), outline: tier?.color, lineWidth: 2)
                }

                if game.mode == .features {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            header("Winnings")
                            Spacer()
                            total
                        }
                        winnings(moment)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            header("Slot")
                            Spacer()
                            Text(game.spinsLeft == 1 ? "1 spin left" : "\(game.spinsLeft) spins left")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText(value: Double(game.spinsLeft)))
                        }
                        slot
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            header("Board")
                            Spacer()
                            Text(game.drops == 0 ? "First drop free" : game.drops == 1 ? "1 drop" : "\(game.drops) drops")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText(value: Double(game.drops)))
                        }
                        // Landing on the product you already have shows no colour: nothing gained, nothing lost.
                        TierBoard(bins: game.bins.map { $0.map { game.device.products[$0] } }, odds: game.odds, landed: game.landedBin,
                                  outcome: game.change?.iPad == 0 ? nil : game.phase == .won ? .won : game.phase == .lost ? .lost : nil,
                                  drop: drop)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)  // below the navigation bar, as on the other screens
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDisabled(game.phase == .spinning)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if game.mode == .product { BallLayer(drop: drop) }
        }
        .onChange(of: game.landedBin) { _, bin in if bin == nil { drop.reset() } }  // a new round
        .sensoryFeedback(trigger: game.phase) { (_, phase: Game.Phase) -> SensoryFeedback? in
            switch phase {
            case .won: .success
            case .lost, .nothing: .error
            case .idle, .spinning: nil
            }
        }
        .onChange(of: game.phase) { old, phase in
            if phase == .won { Sound.win.play() }
            if phase == .lost || (phase == .nothing && old != .lost) { Sound.lose.play() }  // Nothing has already lost
        }
        // Pinned, so the slider is in reach on every iPhone.
        .safeAreaBar(edge: .bottom) {
            controls
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .animation(.spring(duration: 0.5, bounce: 0.2), value: game.isMoment)
        .animation(.spring(duration: 0.5, bounce: 0.2), value: game.phase)
    }

    private var total: some View {
        let amount = Text(profitText(game.profit))
            .foregroundStyle(game.profit > 0 ? Outcome.won.color : game.profit < 0 ? Outcome.lost.color : .primary)
            .fontWeight(.semibold)
        return Text("Total: \(amount)")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText(value: Double(game.profit)))
    }

    private var slot: some View {
        let outcome: Outcome? = game.phase == .won ? .won : game.phase == .lost ? .lost : nil
        return SlotMachine(strips: game.strips, positions: game.reels, outcome: outcome)
            .sensoryFeedback(.impact(weight: .medium), trigger: game.reelStops)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .textCase(.uppercase)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    /// Two columns of two pills, in the order the upgrades are won: the first two on the left, then the
    /// next two on the right, so Pro Storage sits above the AirPods.
    private func winnings(_ moment: Game.Change?) -> some View {
        let upgrades = game.device.upgrades
        let half = (upgrades.count + 1) / 2
        return HStack(alignment: .top, spacing: 8) {
            ForEach([0..<half, half..<upgrades.count], id: \.self) { column in
                VStack(spacing: 8) {
                    ForEach(column, id: \.self) { i in
                        capsule(upgrades[i].name, icon: upgrades[i].icon, state: state(i, moment),
                                price: game.price(ofUpgrade: i))
                            .frame(height: 38)
                    }
                }
            }
        }
    }

    /// Lost beats held beats next: a lost upgrade flashes orange even if it's the one you play for again.
    private func state(_ i: Int, _ moment: Game.Change?) -> Prize {
        if moment?.upgradesLost.contains(i) == true { return .justLost }
        if i < game.upgrades { return moment?.upgradeWon == i ? .justWon : .won }
        if i == game.upgrades && game.mode == .features && game.canPlay(.features) { return .next }
        return .idle
    }

    /// `price` shows during the moment: what was just won or lost, in the outline's colour.
    private func capsule(_ name: String, icon: String, state: Prize, price: Int) -> some View {
        // The price takes the icon's place for the moment: name, icon and price don't all fit in a short capsule.
        let showsPrice = state == .justWon || state == .justLost
        return HStack(spacing: 6) {
            Label(name, systemImage: icon)
                .labelStyle(PriceSwapLabelStyle(showsIcon: !showsPrice))
            if showsPrice {
                Text((state == .justWon ? "+" : "−") + price.dollars)
                    .fontWeight(.semibold)
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .font(.footnote.weight(.medium))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .foregroundStyle(state.foreground)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .card(fill: state.fill, outline: state.outline)
        .symbolEffect(.bounce, value: state == .justWon)
        .accessibilityElement(children: .combine)
        .accessibilityValue(state.description)
    }

    /// Products: swipe to drop, then pay more each time for another try, or take what you have.
    @ViewBuilder private var tierControls: some View {
        // Also when a drop is owed: coming back from Features after a drop, the next one must be paid for first.
        if !game.isMoment && (game.phase == .won || game.phase == .lost || (game.phase == .idle && game.needsDropPayment)) {
            // Side by side, in the slider's height, so the board above never has to make room.
            HStack(spacing: 8) {
                Button { game.showsSummary = true } label: {
                    Text("Take winnings").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("keep")
                // On the best product another drop can only go down; offer to win its features instead.
                if game.hasBestTierProduct && game.canPlay(.features) {
                    Button { withAnimation { game.play(.features) } } label: {
                        Text("Gamble for features").frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("gambleFeatures")
                } else {
                    Button { paysForDrop = true } label: {
                        Text("\(game.dropPrice.dollars) for another try").frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("anotherTry")
                }
            }
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .controlSize(.large)
            .frame(height: SlideToSpin.height)
            .transition(.blurReplace)
            .sheet(isPresented: $paysForDrop) {
                ApplePaySheet(amount: game.dropPrice) { withAnimation { game.payForDrop() } }
            }
        } else {
            SlideToSpin(label: "Swipe to win", onDrag: { drop.notch = $0 }) { _ in
                guard let bin = game.startDrop() else {
                    withAnimation(.spring(duration: 0.4, bounce: 0.35)) { drop.notch = 0 }
                    return
                }
                Task {
                    let landed = await drop.play(into: bin, odds: game.odds)
                    await game.land(in: landed)
                }
            }
            .disabled(game.phase != .idle)
        }
    }

    @ViewBuilder private var controls: some View {
        if game.mode == .product {
            tierControls
        } else if !game.isMoment && (game.phase == .won || game.phase == .lost || !game.canPlay(game.mode)) {
            VStack(spacing: 8) {
                if game.canPlay(.features) || game.canPlay(.product) {
                    Button { withAnimation { game.keepGambling() } } label: {
                        Text(game.lostLast ? "Win it back" : "Spin for more").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("keepGambling")
                }
                Button { game.showsSummary = true } label: {
                    Text(game.lostLast ? "Keep this" : "Take winnings").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("keep")
            }
            .controlSize(.large)
            .padding(.bottom, -8)  // the pair is taller than the slider; let it use the bar's bottom margin
            .transition(.blurReplace)
        } else if game.needsPayment && game.phase == .idle {
            Button { paysForSpins = true } label: {
                Label("Pay \(Catalog.spinPrice.dollars) for more spins", systemImage: "apple.logo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.black)
            .controlSize(.large)
            .frame(height: SlideToSpin.height)
            .accessibilityIdentifier("payForSpins")
            .transition(.blurReplace)
            .sheet(isPresented: $paysForSpins) {
                ApplePaySheet(amount: Catalog.spinPrice) { withAnimation { game.payForSpins() } }
            }
        } else {
            SlideToSpin(label: game.lostLast ? "Swipe to win it back" : "Swipe to win", onDrag: game.nudge) { power in
                if game.isLastChance { confirmsLastChance = true } else { Task { await game.pull(power: power) } }
            }
            .disabled(game.phase != .idle)
            .alert("Are You Sure?", isPresented: $confirmsLastChance) {
                Button("Spin", role: .destructive) { Task { await game.pull(power: 0.5) } }
                Button("Cancel", role: .cancel) { game.nudge(0) }
            } message: {
                Text("This is your last \(game.device.kind). If you lose this spin, you lose it: you paid \(game.totalPaid.dollars) and no \(game.device.kind) will be delivered.")
            }
        }
    }
}

/// The design's win and loss colours, with the hex values from the Figma file.
enum Outcome {
    case won, lost

    /// Text, outlines and payline arrows.
    var color: Color { self == .won ? Color(red: 0x00 / 255, green: 0x89 / 255, blue: 0x32 / 255) : .orange }
    var fill: Color { self == .won ? .green.opacity(0.2) : Color(red: 0xFF / 255, green: 0xBC / 255, blue: 0x7F / 255) }
}

/// How a prize capsule looks. `just…` are the flash right after a pull, outlined in their colour.
private enum Prize: Equatable {
    case idle, next, won, justWon, justLost

    var outcome: Outcome? {
        switch self {
        case .won, .justWon: .won
        case .justLost: .lost
        case .idle, .next: nil
        }
    }
    var fill: Color { outcome?.fill ?? Color(.secondarySystemGroupedBackground).opacity(self == .idle ? 0.5 : 1) }
    var outline: Color? {
        switch self {
        case .next: Color(.systemGray3)
        case .justWon, .justLost: outcome?.color
        case .idle, .won: nil
        }
    }
    var foreground: Color { outcome?.color ?? (self == .idle ? Color(.tertiaryLabel) : .primary) }
    var description: String {
        switch self {
        case .idle: "Not won"
        case .next: "Playing for this"
        case .won, .justWon: "Won"
        case .justLost: "Lost"
        }
    }
}

/// Title and icon, with the icon fading out while a capsule shows its price.
private struct PriceSwapLabelStyle: LabelStyle {
    var showsIcon: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            if showsIcon {
                configuration.icon
                    .transition(.opacity.combined(with: .scale(scale: 0.6)))
            }
            configuration.title
        }
    }
}

private extension View {
    /// The card and capsule shape. The radius clamps to a full capsule on the short ones.
    func card(fill: Color, outline: Color? = nil, lineWidth: Double = 1) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return background(fill, in: shape)
            .overlay { shape.strokeBorder(outline ?? .clear, lineWidth: lineWidth) }
    }
}

/// The product you'll receive: picture, name, configuration.
struct ProductRow: View {
    let product: Product
    let configuration: String

    var body: some View {
        HStack(spacing: 32) {
            Image(product.image)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .fontWeight(.semibold)
                Text(configuration)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }
}

#Preview("Features: winnings") {
    let game = Game(device: Catalog.devices[0])
    game.play(.features)
    return NavigationStack { GameView() }
        .environment(game)
        .frame(width: 402, height: 660)  // an iPhone 17 Pro's width; shorter than the phone so the canvas doesn't crop the top
}

#Preview("Features: winnings, iPhone") {
    let game = Game(device: Catalog.devices[1])
    game.play(.features)
    return NavigationStack { GameView() }
        .environment(game)
        .frame(width: 402, height: 660)
}
