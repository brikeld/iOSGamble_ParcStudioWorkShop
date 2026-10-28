import AVFoundation
import UIKit

/// The longer sounds, from the files in Sounds/.
/// They play with the ring switch on silent too, so the prototype is always heard during a demo.
enum Sound: String {
    case win, lose, spawn

    func play() {
        guard let player = Self.players[self] else { return }
        player.currentTime = 0
        player.play()
    }

    private static let players: [Sound: AVAudioPlayer] = {
        _ = Ticker.session
        var players: [Sound: AVAudioPlayer] = [:]
        for sound in [Sound.win, .lose, .spawn] {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "m4a")
                    ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sound] = player
        }
        return players
    }()
}

/// The short, frequent clicks: the reels' tick and the ball's bounces off the toggles.
/// Restarting an AVAudioPlayer and firing a haptic per row, about 60 times a second, blocked the
/// main thread and made spins stutter. These schedule preloaded buffers instead, reuse warmed-up
/// haptic generators, and are capped at 25 a second.
enum Ticker {
    static let session: Void = {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    }()

    private static let minInterval = 0.04
    private static var lastTick = 0.0
    private static var lastBounce = 0.0
    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    private static let engine = AVAudioEngine()
    /// One player per click, so a tink can ring over a tock.
    private static let clicks: [String: (player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer)] = {
        _ = session
        var clicks: [String: (AVAudioPlayerNode, AVAudioPCMBuffer)] = [:]
        for name in ["reel-tick", "tock", "tink"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "m4a"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil else { continue }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
            clicks[name] = (player, buffer)
        }
        selection.prepare()
        impact.prepare()
        return clicks
    }()

    /// Loads the clicks and starts the engine ahead of time, so the first spin doesn't hitch.
    /// Also restarts it after interruptions such as a call or a route change, which stop it.
    static func prepare() {
        guard !clicks.isEmpty, !engine.isRunning else { return }
        try? engine.start()
        for click in clicks.values { click.player.play() }
    }

    static func tick() {
        let now = CACurrentMediaTime()
        guard now - lastTick >= minInterval else { return }
        lastTick = now
        play("reel-tick")
        selection.selectionChanged()
    }

    /// The ball hitting a toggle: a tink if it was on, a tock if it was off, and a tap as hard as the hit.
    static func bounce(offToggle: Bool, strength: Double) {
        let now = CACurrentMediaTime()
        guard now - lastBounce >= minInterval else { return }
        lastBounce = now
        play(offToggle ? "tock" : "tink")
        impact.impactOccurred(intensity: min(max(strength, 0.3), 1))
    }

    private static func play(_ name: String) {
        prepare()
        guard let click = clicks[name] else { return }
        click.player.scheduleBuffer(click.buffer, at: nil, options: .interrupts)
    }
}
