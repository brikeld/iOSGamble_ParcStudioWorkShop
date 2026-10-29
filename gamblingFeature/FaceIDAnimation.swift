import SwiftUI

/// Plays the green "detecting" animation from FaceIDDetecting.json (the "Face Unlock" Lottie, 440 x 370 at 60 fps,
/// with its black container layer removed), drawn natively. It supports only what that file uses:
/// shape layers whose bezier paths, position, rotation, opacity, stroke width and blur are keyframed with cubic easing.
struct FaceIDAnimation {
    static let shared = FaceIDAnimation()

    static let frameRate = 60.0
    private static let canvas = CGSize(width: 440, height: 370)
    private static let green = Color(red: 0.651, green: 0.9726, blue: 0.5922)

    private let layers: [Layer]

    private init() {
        guard let url = Bundle.main.url(forResource: "FaceIDDetecting", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let layers = json["layers"] as? [[String: Any]] else {
            self.layers = []
            return
        }
        self.layers = layers.map(Layer.init)
    }

    /// Draws the animation as it looks at `frame`, scaled to fit `size`.
    func draw(frame: Double, in context: GraphicsContext, size: CGSize) {
        let fit = min(size.width / Self.canvas.width, size.height / Self.canvas.height)
        var context = context
        context.translateBy(x: (size.width - Self.canvas.width * fit) / 2, y: (size.height - Self.canvas.height * fit) / 2)
        context.scaleBy(x: fit, y: fit)

        // The first layer is the topmost, so draw back to front.
        for layer in layers.reversed() where frame >= layer.start && frame < layer.end {
            let opacity = layer.opacity.scalar(at: frame) / 100
            guard opacity > 0 else { continue }
            let transform = layer.transform(at: frame)

            var shape = Path()
            for path in layer.paths { shape.addPath(path.path(at: frame).applying(transform)) }

            context.drawLayer { layerContext in
                layerContext.opacity = opacity
                if let sigma = layer.blur {
                    layerContext.addFilter(.blur(radius: sigma.scalar(at: frame) / 3 * fit))
                    layerContext.blendMode = .plusLighter
                }
                if layer.fills {
                    layerContext.fill(shape, with: .color(Self.green))
                } else if let width = layer.strokeWidth {
                    layerContext.stroke(shape, with: .color(Self.green), style: StrokeStyle(lineWidth: width.scalar(at: frame)))
                }
            }
        }
    }
}

// MARK: - Parsing

nonisolated private struct Layer {
    let start: Double, end: Double
    let anchor: Track, position: Track, scale: Track, rotation: Track, opacity: Track
    let paths: [ShapePath]
    let fills: Bool
    let strokeWidth: Track?
    let blur: Track?

    init(_ json: [String: Any]) {
        start = json["ip"] as? Double ?? 0
        end = json["op"] as? Double ?? 0
        let transform = json["ks"] as? [String: Any] ?? [:]
        anchor = Track(transform["a"])
        position = Track(transform["p"])
        scale = Track(transform["s"])
        rotation = Track(transform["r"])
        opacity = Track(transform["o"])

        let shapes = json["shapes"] as? [[String: Any]] ?? []
        paths = shapes.filter { $0["ty"] as? String == "sh" }.map(ShapePath.init)
        fills = shapes.contains { $0["ty"] as? String == "fl" }
        let stroke = shapes.first { $0["ty"] as? String == "st" }
        strokeWidth = stroke == nil ? nil : Track(stroke?["w"])

        // The Gaussian Blur effect's first property is its sigma.
        let effect = (json["ef"] as? [[String: Any]])?.first
        let sigma = (effect?["ef"] as? [[String: Any]])?.first?["v"]
        blur = sigma == nil ? nil : Track(sigma)
    }

    /// Anchor, then scale, then rotation, then position, like After Effects.
    func transform(at frame: Double) -> CGAffineTransform {
        let anchor = anchor.value(at: frame), position = position.value(at: frame), scale = scale.value(at: frame)
        return CGAffineTransform(translationX: -anchor[0], y: -anchor[1])
            .concatenating(CGAffineTransform(scaleX: scale[0] / 100, y: scale[1] / 100))
            .concatenating(CGAffineTransform(rotationAngle: rotation.scalar(at: frame) * .pi / 180))
            .concatenating(CGAffineTransform(translationX: position[0], y: position[1]))
    }
}

/// A bezier path. Its vertices and tangents are flattened into one vector so they interpolate like any other value:
/// all the vertices, then all the in-tangents, then all the out-tangents, each as x, y pairs relative to the vertex.
nonisolated private struct ShapePath {
    let track: Track
    let count: Int
    let closed: Bool

    init(_ json: [String: Any]) {
        func flatten(_ shape: Any?) -> (values: [Double], count: Int, closed: Bool)? {
            // Keyframed paths wrap the shape in an array.
            guard let shape = (shape as? [[String: Any]])?.first ?? shape as? [String: Any],
                  let vertices = shape["v"] as? [[Double]],
                  let ins = shape["i"] as? [[Double]], let outs = shape["o"] as? [[Double]] else { return nil }
            return ((vertices + ins + outs).flatMap { $0 }, vertices.count, shape["c"] as? Bool ?? false)
        }

        let ks = json["ks"] as? [String: Any] ?? [:]
        let keys = ks["k"]
        var first: (values: [Double], count: Int, closed: Bool)?
        if ks["a"] as? Int == 1, let frames = keys as? [[String: Any]] {
            first = flatten(frames.first?["s"])
            track = Track(keyframes: frames, convert: { flatten($0)?.values })
        } else {
            first = flatten(keys)
            track = Track(constant: first?.values ?? [])
        }
        count = first?.count ?? 0
        closed = first?.closed ?? false
    }

    func path(at frame: Double) -> Path {
        let values = track.value(at: frame)
        func point(_ block: Int, _ index: Int) -> CGPoint {
            CGPoint(x: values[block * 2 * count + index * 2], y: values[block * 2 * count + index * 2 + 1])
        }
        var path = Path()
        guard count > 1, values.count == count * 6 else { return path }
        path.move(to: point(0, 0))
        for index in 0..<(closed ? count : count - 1) {
            let next = (index + 1) % count
            let from = point(0, index), to = point(0, next)
            let out = point(2, index), into = point(1, next)
            path.addCurve(to: to,
                          control1: CGPoint(x: from.x + out.x, y: from.y + out.y),
                          control2: CGPoint(x: to.x + into.x, y: to.y + into.y))
        }
        if closed { path.closeSubpath() }
        return path
    }
}

/// A keyframed (or constant) value: a vector, such as `[x, y]` for a position or `[degrees]` for a rotation.
nonisolated private struct Track {
    struct Key {
        let time: Double
        let value: [Double]
        let out: CGPoint  // easing handle leaving this key
        let into: CGPoint  // easing handle arriving at the next key
        let hold: Bool
    }

    let keys: [Key]

    init(constant: [Double]) {
        keys = [Key(time: 0, value: constant, out: .zero, into: .zero, hold: true)]
    }

    init(_ property: Any?) {
        let property = property as? [String: Any] ?? [:]
        let k = property["k"]
        if property["a"] as? Int == 1, let frames = k as? [[String: Any]] {
            keys = Self.keys(frames, convert: { Self.numbers($0).isEmpty ? nil : Self.numbers($0) })
        } else {
            keys = [Key(time: 0, value: Self.numbers(k), out: .zero, into: .zero, hold: true)]
        }
    }

    init(keyframes frames: [[String: Any]], convert: @escaping (Any?) -> [Double]?) {
        keys = Self.keys(frames, convert: convert)
    }

    private static func keys(_ frames: [[String: Any]], convert: @escaping (Any?) -> [Double]?) -> [Key] {
        var keys: [Key] = []
        for frame in frames {
            // A key with no value (the file has `[null]` after the checkmark) keeps the previous one.
            guard let value = convert(frame["s"]) ?? keys.last?.value else { continue }
            func handle(_ name: String) -> CGPoint {
                let handle = frame[name] as? [String: Any]
                return CGPoint(x: Self.numbers(handle?["x"]).first ?? 0, y: Self.numbers(handle?["y"]).first ?? 0)
            }
            keys.append(Key(time: frame["t"] as? Double ?? 0, value: value, out: handle("o"), into: handle("i"),
                            hold: (frame["h"] as? Int) == 1))
        }
        return keys
    }

    /// The first component, for values that are a single number; 0 if the file left it empty.
    func scalar(at frame: Double) -> Double {
        value(at: frame).first ?? 0
    }

    func value(at frame: Double) -> [Double] {
        guard let first = keys.first, let last = keys.last, frame > first.time else { return keys.first?.value ?? [0, 0] }
        guard frame < last.time, let index = keys.lastIndex(where: { $0.time <= frame }) else { return last.value }
        let from = keys[index], to = keys[index + 1]
        guard !from.hold else { return from.value }
        let progress = Self.ease((frame - from.time) / (to.time - from.time), from.out, to.into)
        return zip(from.value, to.value).map { $0 + ($1 - $0) * progress }
    }

    /// The y of a cubic bezier from (0, 0) to (1, 1) with these handles, at x.
    private static func ease(_ x: Double, _ out: CGPoint, _ into: CGPoint) -> Double {
        func bezier(_ u: Double, _ a: Double, _ b: Double) -> Double {
            3 * (1 - u) * (1 - u) * u * a + 3 * (1 - u) * u * u * b + u * u * u
        }
        var low = 0.0, high = 1.0
        for _ in 0..<24 {
            let middle = (low + high) / 2
            if bezier(middle, out.x, into.x) < x { low = middle } else { high = middle }
        }
        return bezier((low + high) / 2, out.y, into.y)
    }

    private static func numbers(_ value: Any?) -> [Double] {
        if let number = value as? Double { return [number] }
        return (value as? [Any])?.compactMap { $0 as? Double } ?? []
    }
}

// MARK: - View

/// The detecting animation, played once from `firstFrame` and held on `lastFrame`.
struct FaceIDDetectingView: View {
    var firstFrame: Double
    var lastFrame: Double

    @State private var started = Date()
    @State private var finished = false

    var body: some View {
        // The animation was authored at 60 fps, so ProMotion's 120 Hz would only double the blur work;
        // and once it has reached the last frame there's nothing left to redraw.
        TimelineView(.animation(minimumInterval: 1 / FaceIDAnimation.frameRate, paused: finished)) { timeline in
            let frame = min(firstFrame + timeline.date.timeIntervalSince(started) * FaceIDAnimation.frameRate, lastFrame)
            Canvas(rendersAsynchronously: true) { context, size in
                FaceIDAnimation.shared.draw(frame: frame, in: context, size: size)
            }
        }
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .seconds((lastFrame - firstFrame) / FaceIDAnimation.frameRate + 0.1))
            finished = true
        }
    }
}

#Preview("Detecting, frame 45") {
    FaceIDDetectingView(firstFrame: 45, lastFrame: 45)
        .frame(width: 220, height: 185)
        .background(Color(white: 0.12))
}

#Preview("Checkmark, frame 118") {
    FaceIDDetectingView(firstFrame: 118, lastFrame: 118)
        .frame(width: 220, height: 185)
        .background(Color(white: 0.12))
}
