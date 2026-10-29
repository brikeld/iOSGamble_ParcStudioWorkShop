import AVFoundation
import UIKit

/// The longer sounds, from the files in Sounds/.
/// They play with the ring switch on silent too, so the prototype is always heard during a demo.
enum Sound: String {
    case win, lose, spawn

    /// Sets up the audio session and loads the files, off the main thread: creating and preparing players
    /// activates the session, and doing that on the main thread can hang the UI. Otherwise this happens on
    /// the first `play()`, which hitches whatever is on screen at that moment.
    static func prepare() async {
        guard players == nil else { return }
        let loaded = await load()
        if players == nil { players = loaded }
    }

    func play() {
        // Not prepared yet: load now, on the main thread, rather than stay silent.
        if Self.players == nil { Self.players = Self.loadPlayers() }
        guard let player = Self.players?[self] else { return }
        // `AVAudioPlayer.play()` re-activates the audio session every time, which can hang the UI on the main thread.
        Self.playbackQueue.async {
            player.currentTime = 0
            player.play()
        }
    }

    private static var players: [Sound: AVAudioPlayer]?
    private static let playbackQueue = DispatchQueue(label: "ichance.sound", qos: .userInitiated)

    @concurrent private static func load() async -> sending [Sound: AVAudioPlayer] {
        loadPlayers()
    }

    nonisolated private static func loadPlayers() -> [Sound: AVAudioPlayer] {
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
    }
}

/// The short, frequent clicks: the reels' tick and the ball's bounces off the toggles.
/// Restarting an AVAudioPlayer and firing a haptic per row, about 60 times a second, blocked the
/// main thread and made spins stutter. These schedule preloaded buffers instead, reuse warmed-up
/// haptic generators, and are capped at 25 a second.
enum Ticker {
    nonisolated static let session: Void = {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    }()

    private static let minInterval = 0.04
    private static var lastTick = 0.0
    private static var lastBounce = 0.0
    private static let selection = UISelectionFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .light)
    // Not main-actor: the engine is started on a background thread, since starting it activates the audio session,
    // which can hang the UI if done on the main thread. Only that start touches them before the clicks are playing.
    nonisolated private static let engine = AVAudioEngine()
    /// One player per click, so a tink can ring over a tock.
    nonisolated(unsafe) private static let clicks: [String: (player: AVAudioPlayerNode, buffer: AVAudioPCMBuffer)] = {
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
        return clicks
    }()

    private static var isStarting = false

    /// Loads the clicks and starts the engine ahead of time, so the first spin doesn't hitch.
    /// Also restarts it after interruptions such as a call or a route change, which stop it.
    /// The loading and starting happen off the main thread; clicks are skipped until the engine is running.
    static func prepare() {
        selection.prepare()
        impact.prepare()
        guard !isStarting, !engine.isRunning else { return }
        isStarting = true
        Task {
            await start()
            isStarting = false
        }
    }

    @concurrent private static func start() async {
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
        // Not running yet (or stopped by an interruption and restarting): scheduling now would throw.
        guard engine.isRunning, let click = clicks[name] else { return }
        click.player.scheduleBuffer(click.buffer, at: nil, options: .interrupts)
    }
}
