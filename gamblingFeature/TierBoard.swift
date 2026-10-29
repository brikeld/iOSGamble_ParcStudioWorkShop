import SwiftUI

/// The Products board, in points of the Figma frame (370 wide); drawn scaled to the screen's width.
/// Rows are spaced further apart than in the frame, so the board fills the screen down to the slider.
/// shortcut: the height is tuned to fill a 6.3″ iPhone (402×874 pt); smaller ones scroll, larger ones leave a gap.
enum Board {
    static let size = CGSize(width: 370, height: 467)
    /// Five rows of toggles, alternating four and five, like the design.
    static let toggles: [CGRect] = [
        (24.0, [57.0, 129, 201, 273]), (102, [21, 93, 165, 237, 309]), (180, [57, 129, 201, 273]),
        (258, [21, 93, 165, 237, 309]), (336, [57, 129, 201, 273]),
    ].flatMap { row in row.1.map { CGRect(x: $0, y: row.0, width: 40, height: 17) } }
    /// The bins run flush along the card's bottom, 54 tall, 60 below the last toggles.
    static let binTop = 413.0
    static let binHeight = size.height - binTop
    static let ballRadius = 11.0

    /// The bins' edges across the board, from 0 to its width. Each bin grows with its chance from a floor,
    /// so the long shots still fit a name; the odds themselves are drawn elsewhere.
    static func edges(_ odds: [Double]) -> [Double] {
        let floor = 30.0, spare = size.width - floor * Double(odds.count)
        return odds.reduce(into: [0]) { $0.append($0.last! + floor + $1 * spare) }
    }

    /// A toggle as the ball sees it: a capsule, i.e. a segment with a radius.
    static func capsule(_ toggle: CGRect) -> (CGPoint, CGPoint, radius: Double) {
        let r = toggle.height / 2
        return (CGPoint(x: toggle.minX + r, y: toggle.midY), CGPoint(x: toggle.maxX - r, y: toggle.midY), r)
    }
}

/// Plain 2D physics for the ball: gravity, bounces off the toggles, the board's sides and the bin walls.
enum Plinko {
    struct Hit { let time: Double; let toggle: Int; let speed: Double }
    struct Run {
        let points: [CGPoint]
        let hits: [Hit]
        let bin: Int
        var duration: Double { Double(points.count) * Plinko.dt }
    }

    static let dt = 1.0 / 240
    private static let gravity = 1500.0
    private static let bounciness = 0.55
    /// Paths slower than this have dawdled on a toggle; they're thrown away.
    private static let maxDuration = 4.5

    /// A real bounce path that ends in `bin`. The bin is drawn by its odds beforehand, so physics alone
    /// doesn't decide them (it would favour the middle); this tries fresh paths until one lands there.
    static func run(from start: CGPoint, into bin: Int, edges: [Double]) -> Run {
        var fallback: Run?
        for _ in 0..<2000 {
            guard let run = simulate(from: start, edges: edges) else { continue }
            if run.bin == bin { return run }
            fallback = fallback ?? run
        }
        return fallback!  // even a ~10% bin is reached naturally every few dozen paths, so 2000 misses don't happen
    }

    /// One path, or nil if the ball got stuck and never reached the bins in time.
    private static func simulate(from start: CGPoint, edges: [Double]) -> Run? {
        let r = Board.ballRadius, width = Board.size.width
        let pegs = Board.toggles.map { Board.capsule($0) }
        var p = start
        var v = CGVector(dx: .random(in: -45...45), dy: 0)
        var points: [CGPoint] = [], hits: [Hit] = []
        var lastHit = [Double](repeating: -1, count: pegs.count)
        var t = 0.0
        while t < maxDuration {
            t += dt
            v.dy += gravity * dt
            p.x += v.dx * dt
            p.y += v.dy * dt
            for (i, peg) in pegs.enumerated() {
                guard let speed = collide(&p, &v, peg.0, peg.1, radius: peg.radius) else { continue }
                if t - lastHit[i] > 0.15 { hits.append(Hit(time: t, toggle: i, speed: speed)) }
                lastHit[i] = t
            }
            if p.y > 0 {  // the board's sides; above it the ball is still falling from the notch
                if p.x < r { p.x = r; v.dx = abs(v.dx) * bounciness }
                if p.x > width - r { p.x = width - r; v.dx = -abs(v.dx) * bounciness }
            }
            for x in edges.dropFirst().dropLast() {
                _ = collide(&p, &v, CGPoint(x: x, y: Board.binTop), CGPoint(x: x, y: Board.size.height), radius: 0.5)
            }
            points.append(p)
            if p.y > Board.binTop + 21 {  // swallowed halfway into the capsule
                return Run(points: points, hits: hits, bin: max((edges.dropFirst().firstIndex { p.x < $0 } ?? edges.count - 1) - 1, 0))
            }
        }
        return nil
    }

    /// Pushes the ball out of a capsule and bounces it off. Returns the impact speed if it struck.
    private static func collide(_ p: inout CGPoint, _ v: inout CGVector, _ a: CGPoint, _ b: CGPoint, radius: Double) -> Double? {
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let length2 = ab.dx * ab.dx + ab.dy * ab.dy
        let u = length2 == 0 ? 0 : min(max(((p.x - a.x) * ab.dx + (p.y - a.y) * ab.dy) / length2, 0), 1)
        let q = CGPoint(x: a.x + ab.dx * u, y: a.y + ab.dy * u)
        let d = CGVector(dx: p.x - q.x, dy: p.y - q.y)
        let distance = (d.dx * d.dx + d.dy * d.dy).squareRoot()
        let reach = Board.ballRadius + radius
        guard distance < reach else { return nil }
        let n = distance > 0 ? CGVector(dx: d.dx / distance, dy: d.dy / distance) : CGVector(dx: 0, dy: -1)
        p = CGPoint(x: q.x + n.dx * reach, y: q.y + n.dy * reach)
        let vn = v.dx * n.dx + v.dy * n.dy
        guard vn < 0 else { return nil }
        v.dx -= (1 + bounciness) * vn * n.dx
        v.dy -= (1 + bounciness) * vn * n.dy
        // Settling on a toggle's flat top: nudge it off sideways, as a real ball would roll.
        if -vn < 120 && n.dy < -0.9 { v.dx += Bool.random() ? 90 : -90 }
        // A little scatter, so no two drops bounce alike and the ball never balances on a toggle.
        let angle = Double.random(in: -0.25...0.25)
        v = CGVector(dx: v.dx * cos(angle) - v.dy * sin(angle), dy: v.dx * sin(angle) + v.dy * cos(angle))
        return -vn
    }
}

/// One drop's live state: the toggles, the notch stretching, and the ball's path on screen.
@Observable final class Drop {
    var toggles = [Bool](repeating: false, count: Board.toggles.count)
    /// The slider's progress, 0…1: the notch stretches into a drop as you swipe.
    var notch = 0.0
    /// The board on screen, in window coordinates.
    var boardFrame = CGRect.zero
    private(set) var run: Plinko.Run?
    private(set) var started = Date.now
    private(set) var eaten = false
    /// The bin giving way under the ball for a moment, like a key taking a press.
    private(set) var pressed: Int?

    var scale: Double { boardFrame.width / Board.size.width }

    func reset() {
        toggles = toggles.map { _ in false }
        run = nil
        eaten = false
        pressed = nil
    }

    /// Releases the ball from the notch and plays its fall into `bin`: toggles flip, click and tap as it hits them.
    /// Returns the bin it really fell in, which is `bin` unless no path there could be found.
    func play(into bin: Int, odds: [Double]) async -> Int {
        let spawn = CGPoint(x: boardFrame.midX, y: NotchDrop.spawnY)
        let start = CGPoint(x: (spawn.x - boardFrame.minX) / scale, y: (spawn.y - boardFrame.minY) / scale)
        let run = Plinko.run(from: start, into: bin, edges: Board.edges(odds))
        Sound.spawn.play()
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) { notch = 0 }  // the notch draws back in
        eaten = false
        started = .now
        self.run = run

        let clock = ContinuousClock()
        let t0 = clock.now
        for hit in run.hits {
            try? await clock.sleep(until: t0 + .seconds(hit.time))
            let wasOn = toggles[hit.toggle]
            withAnimation(.snappy(duration: 0.25)) { toggles[hit.toggle].toggle() }
            Ticker.bounce(offToggle: !wasOn, strength: hit.speed / 500)
        }
        try? await clock.sleep(until: t0 + .seconds(run.duration))
        // The ball fades into the bin, which dips a little and springs back before it grows.
        withAnimation(.easeOut(duration: 0.22)) { eaten = true }
        withAnimation(.easeOut(duration: 0.12)) { pressed = run.bin }
        try? await Task.sleep(for: .seconds(0.12))
        withAnimation(.spring(duration: 0.35, bounce: 0.35)) { pressed = nil }
        try? await Task.sleep(for: .seconds(0.13))
        return run.bin
    }

    /// Where the ball is at `date`, in window coordinates.
    func ballPosition(at date: Date) -> CGPoint? {
        guard let run, let last = run.points.indices.last else { return nil }
        let p = run.points[min(Int(date.timeIntervalSince(started) / Plinko.dt), last)]
        return CGPoint(x: boardFrame.minX + p.x * scale, y: boardFrame.minY + p.y * scale)
    }
}

/// The toggles on a card, and the products in bins along its bottom, each wider the likelier it is.
/// The bin the ball fell in takes the whole width, outlined in the outcome's colour, and its light rises up the board;
/// the others come back with the next round.
struct TierBoard: View {
    /// nil is Nothing.
    var bins: [Product?]
    var odds: [Double]
    var landed: Int?
    var outcome: Outcome?
    var drop: Drop

    @State private var toggleWidth = 64.0

    var body: some View {
        GeometryReader { geometry in
            let s = geometry.size.width / Board.size.width
            let edges = Board.edges(odds)
            ZStack(alignment: .topLeading) {
                if landed != nil, let outcome {
                    Bloom(color: outcome.color, width: Board.size.width * s, scale: s)
                        .position(x: Board.size.width / 2 * s, y: Board.binTop * s)
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottom)))
                }
                ForEach(Board.toggles.indices, id: \.self) { i in
                    // The real switch, shrunk to the design's 40 pt.
                    Toggle("", isOn: .constant(drop.toggles[i]))
                        .labelsHidden()
                        .fixedSize()
                        .onGeometryChange(for: Double.self, of: { $0.size.width }) { toggleWidth = $0 }
                        .scaleEffect(Board.toggles[i].width * s / toggleWidth)
                        .position(x: Board.toggles[i].midX * s, y: Board.toggles[i].midY * s)
                }
                // Placed by hand rather than in an HStack, so the landed bin can grow out of its own place to the whole
                // width, over the others as they fade.
                ZStack(alignment: .topLeading) {
                    ForEach(bins.indices, id: \.self) { i in
                        let expanded = landed == i
                        bin(i, width: edges[i + 1] - edges[i], scale: s)
                            .frame(width: (expanded ? Board.size.width : edges[i + 1] - edges[i]) * s, height: Board.binHeight * s)
                            .offset(x: (expanded ? 0 : edges[i]) * s, y: drop.pressed == i ? 2.5 * s : 0)
                            .opacity(landed == nil || expanded ? 1 : 0)
                            .zIndex(expanded ? 1 : 0)
                    }
                }
                .frame(width: Board.size.width * s, height: Board.binHeight * s, alignment: .topLeading)
                // The same line as between the bins, along their sides and bottom; its top edge is clipped off.
                .overlay {
                    UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
                        .strokeBorder(Color(.systemGray4), lineWidth: 1)
                        .padding(.top, -1)
                        .opacity(landed == nil ? 1 : 0)
                }
                .clipShape(Rectangle())
                .offset(y: Board.binTop * s)
            }
            // Landing and a new round both glide: the bin widens on one smooth curve, everything else fades along.
            .animation(.smooth(duration: 0.55), value: landed)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 20))
            // Once landed, the whole board is outlined in the result's colour, like the Your Product card.
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder((landed != nil ? outcome?.color : nil) ?? .clear, lineWidth: 2)
                    .animation(.smooth(duration: 0.55), value: landed)
            }
        }
        .aspectRatio(Board.size, contentMode: .fit)
        .allowsHitTesting(false)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { drop.boardFrame = $0 }
    }

    /// A bin in the board's own white, flush with its neighbours and the card's edges, with the product's name. The landed one opens up
    /// its photo beside the name. Black text throughout.
    /// `width` is the bin's resting width, so its layout never swaps mid-animation: everything here only grows or fades.
    private func bin(_ i: Int, width: Double, scale s: Double) -> some View {
        let expanded = landed == i
        let name = bins[i]?.name ?? "Nothing"
        let iconOnly = width < 46 && !expanded  // too narrow for "Nothing"
        // A narrow bin stacks its words, one per line, which then shrink rather than hyphenate ("Noth-ing").
        let words = name.split(separator: " ").count
        let stacked = width < 60 && !expanded
        return HStack(spacing: expanded ? 12 : 0) {
            Group {
                if let product = bins[i] {
                    Image(product.image).resizable().scaledToFit()
                        .frame(width: expanded ? 34 * s : 0, height: 38 * s)
                        .opacity(expanded ? 1 : 0)
                } else {
                    Image(systemName: "nosign").font(.subheadline).foregroundStyle(.secondary)
                        .frame(width: iconOnly || expanded ? 22 : 0)
                        .opacity(iconOnly || expanded ? 1 : 0)
                }
            }
            Text(stacked ? name.replacingOccurrences(of: " ", with: "\n") : name)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(stacked ? words : expanded ? 1 : 2)
                .minimumScaleFactor(0.6)
                .scaleEffect(expanded ? 13 / 11 : 1)  // up to footnote size, smoothly
                .frame(width: iconOnly ? 0 : nil)
                .opacity(iconOnly ? 0 : 1)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground))  // the board's own fill, so the bins read as part of it
        .overlay(alignment: .leading) {
            if i > 0 { Rectangle().fill(Color(.systemGray4)).frame(width: 1).opacity(landed == nil ? 1 : 0) }
        }
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityHidden(landed != nil && !expanded)
    }
}

/// The light out of the bin the ball fell in: a soft bloom spreading up the board from a bright rim,
/// breathing slowly while the result stands. Centred on the bin's top edge; the bin itself hides its lower half.
private struct Bloom: View {
    var color: Color
    var width: Double
    var scale: Double

    var body: some View {
        let spread = min(max(width, 60 * scale), 160 * scale)  // a full-width bin glows wide, not over the whole board
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [color.opacity(0.45), color.opacity(0.14), color.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: spread * 1.2))
                .frame(width: spread * 2.4, height: 300 * scale)
                .blur(radius: 30)
            Capsule()
                .fill(color.opacity(0.55))
                .frame(width: width * 0.9, height: 8 * scale)
                .blur(radius: 9)
        }
        .phaseAnimator([0.85, 1.0]) { bloom, phase in
            bloom.scaleEffect(phase, anchor: .center).opacity(0.55 + 0.45 * phase)
        } animation: { _ in .easeInOut(duration: 1.6) }
    }
}

/// The ball and the notch drop, over the whole window: the ball falls from the Dynamic Island onto the board.
struct BallLayer: View {
    var drop: Drop

    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            ZStack(alignment: .topLeading) {
                NotchDrop(progress: drop.notch)
                if drop.run != nil {
                    TimelineView(.animation(paused: drop.eaten)) { context in
                        if let p = drop.ballPosition(at: context.date) {
                            // Black, like the notch it drops from, with glass's light on its edge.
                            Circle()
                                .fill(.black)
                                .glassEffect(.regular.tint(.black), in: .circle)
                                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
                                .frame(width: Board.ballRadius * 2 * drop.scale, height: Board.ballRadius * 2 * drop.scale)
                                .scaleEffect(drop.eaten ? 0.7 : 1)
                                .opacity(drop.eaten ? 0 : 1)
                                .position(x: p.x - origin.x, y: p.y - origin.y)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// The Dynamic Island stretching into a drop, like liquid, as the slider moves: blurred black shapes,
/// cut back to solid, merge into one blob. Animatable so it can spring back smoothly.
/// shortcut: island geometry is the iPhone 14 Pro–17 Pro one (126×37 pt, 11 pt from the top); other iPhones differ.
struct NotchDrop: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private static let island = CGSize(width: 124, height: 35)  // a touch inside the real island, so it hides behind it
    private static let islandTop = 12.0
    private static let reach = 40.0
    private static let maxRadius = 21.0
    /// The bulb's centre at the end of the swipe, where the ball appears.
    static let spawnY = islandTop + island.height - maxRadius * 0.6 + reach

    var body: some View {
        Canvas { context, size in
            let island = CGRect(x: size.width / 2 - Self.island.width / 2, y: Self.islandTop, width: Self.island.width, height: Self.island.height)
            let r = 8 + (Self.maxRadius - 8) * progress
            let y = island.maxY - r * 0.6 + Self.reach * progress
            // The proportions of a hanging drop: a soft shoulder off the island, a neck that pinches as it
            // stretches, and a round bulb. Tuned by rendering them side by side.
            let shoulder = r * 0.9
            let neck = r * (1 - 0.45 * progress)
            context.addFilter(.alphaThreshold(min: 0.5, color: .black))
            context.addFilter(.blur(radius: 9))
            context.drawLayer { layer in
                layer.fill(Capsule().path(in: island), with: .color(.black))
                layer.fill(Circle().path(in: CGRect(x: size.width / 2 - shoulder, y: island.maxY - shoulder * 1.2, width: shoulder * 2, height: shoulder * 2)),
                           with: .color(.black))
                layer.fill(Capsule().path(in: CGRect(x: size.width / 2 - neck / 2, y: island.midY, width: neck, height: max(y - island.midY, 0))),
                           with: .color(.black))
                layer.fill(Circle().path(in: CGRect(x: size.width / 2 - r - 2, y: y - r - 2, width: r * 2 + 4, height: r * 2 + 4)), with: .color(.black))
            }
        }
        .frame(height: 130)
        .opacity(progress > 0.001 ? 1 : 0)
    }
}
