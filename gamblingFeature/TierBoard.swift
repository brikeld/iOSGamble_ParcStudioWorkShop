import SwiftUI

/// The Products board, in points of the Figma frame (370 wide); drawn scaled to the screen's width.
/// Rows are spaced further apart than in the frame, so the board fills the screen down to the slider.
enum Board {
    static let size = CGSize(width: 370, height: 434)
    /// Five rows of toggles, alternating four and five, like the design.
    static let toggles: [CGRect] = [
        (24.0, [57.0, 129, 201, 273]), (96, [21, 93, 165, 237, 309]), (168, [57, 129, 201, 273]),
        (240, [21, 93, 165, 237, 309]), (312, [57, 129, 201, 273]),
    ].flatMap { row in row.1.map { CGRect(x: $0, y: row.0, width: 40, height: 17) } }
    static let binTop = 370.0
    static let binHeight = 64.0
    static let ballRadius = 11.0

    /// The bins' edges across the board, from 0 to its width: each bin as wide as its chance.
    static func edges(_ odds: [Double]) -> [Double] {
        odds.reduce(into: [0]) { $0.append($0.last! + $1 * size.width) }
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
        let pegs = Board.toggles.map(Board.capsule)
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
            if p.y > Board.binTop + Board.binHeight / 2 {
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

    var scale: Double { boardFrame.width / Board.size.width }

    func reset() {
        toggles = toggles.map { _ in false }
        run = nil
        eaten = false
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
        withAnimation(.spring(duration: 0.35, bounce: 0.2)) { eaten = true }  // swallowed by the bin
        try? await Task.sleep(for: .seconds(0.25))
        return run.bin
    }

    /// Where the ball is at `date`, in window coordinates.
    func ballPosition(at date: Date) -> CGPoint? {
        guard let run, let last = run.points.indices.last else { return nil }
        let p = run.points[min(Int(date.timeIntervalSince(started) / Plinko.dt), last)]
        return CGPoint(x: boardFrame.minX + p.x * scale, y: boardFrame.minY + p.y * scale)
    }
}

/// The toggles over a grey well, and the iPads underneath, each box as wide as its chance. The bin the ball
/// fell in takes the outcome's colour, and its light rises up the board.
struct TierBoard: View {
    var bins: [String]
    var odds: [Double]
    var landed: Int?
    var outcome: Outcome?
    var drop: Drop

    @State private var toggleWidth = 64.0

    var body: some View {
        GeometryReader { geometry in
            let s = geometry.size.width / Board.size.width
            let edges = Board.edges(odds)
            let shape = UnevenRoundedRectangle(bottomLeadingRadius: 20, bottomTrailingRadius: 20, style: .continuous)
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Color(.systemGray5)
                    if let landed, let outcome {
                        Bloom(color: outcome.color, width: (edges[landed + 1] - edges[landed]) * s, scale: s)
                            .position(x: (edges[landed] + edges[landed + 1]) / 2 * s, y: Board.binTop * s)
                            .transition(.scale(scale: 0.3, anchor: .bottom).combined(with: .opacity))
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
                    bins(s: s)
                        .frame(height: Board.binHeight * s)
                        .offset(y: Board.binTop * s)
                }
                .clipShape(shape)
                .overlay { shape.stroke(Color(.systemGray4), lineWidth: 1) }
            }
        }
        .aspectRatio(Board.size, contentMode: .fit)
        .allowsHitTesting(false)
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { drop.boardFrame = $0 }
    }

    private func bins(s: Double) -> some View {
        HStack(spacing: 0) {
            ForEach(bins.indices, id: \.self) { i in
                let hit = landed == i ? outcome : nil
                // The long shots are narrow boxes: there each word gets its own line and shrinks to fit,
                // rather than breaking mid-word.
                let narrow = odds[i] * Board.size.width < 70
                VStack(spacing: 2) {
                    if narrow {
                        // One single-line Text per word: a Text allowed to wrap hyphenates ("Noth-ing") before it shrinks.
                        VStack(spacing: 0) {
                            ForEach(bins[i].split(separator: " ").map(String.init), id: \.self) { word in
                                Text(word).lineLimit(1).minimumScaleFactor(0.4)
                            }
                        }
                        .font(.footnote)
                    } else {
                        Text(bins[i])
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.5)
                    }
                    Text(odds[i].formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.6)
                }
                .foregroundStyle(.primary)  // black on the tint too, so it stays readable
                .padding(.horizontal, 2)
                .frame(width: odds[i] * Board.size.width * s)
                .frame(maxHeight: .infinity)
                .background(hit?.fill ?? Color(.secondarySystemGroupedBackground))
                    .overlay(alignment: .leading) {
                        if i > 0 { Rectangle().fill(Color(.systemGray4)).frame(width: 1) }
                    }
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Color(.systemGray4)).frame(height: 1) }
    }

}

/// The light out of the bin the ball fell in: a soft bloom spreading up the board from a bright rim,
/// breathing slowly while the result stands. Centred on the bin's top edge; the bin itself hides its lower half.
private struct Bloom: View {
    var color: Color
    var width: Double
    var scale: Double

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [color.opacity(0.75), color.opacity(0.25), color.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: max(width, 60 * scale) * 1.2))
                .frame(width: max(width, 60 * scale) * 2.4, height: 300 * scale)
                .blur(radius: 24)
            Capsule()
                .fill(color)
                .frame(width: width * 0.9, height: 8 * scale)
                .blur(radius: 7)
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
                                .scaleEffect(drop.eaten ? 0.05 : 1)
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
