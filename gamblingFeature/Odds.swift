import Foundation

/// Tune the game here. The user is never shown these numbers.
enum Odds {
    /// Every pull is a fair coin flip.
    static let winChance = 0.5
    /// Share of losses where only the last reel misses, by one row.
    static let nearMissShare = 0.8

    /// Where each reel stops, in rows away from the jackpot symbol. All zero is a win.
    /// A loss keeps the first reel on the jackpot, so it can never show three of a kind.
    static func stops(win: Bool) -> [Int] {
        guard !win else { return [0, 0, 0] }
        if Double.random(in: 0..<1) < nearMissShare {
            return [0, 0, Bool.random() ? 1 : -1]
        }
        return [0, Int.random(in: 2...3) * (Bool.random() ? 1 : -1), Int.random(in: 1...3) * (Bool.random() ? 1 : -1)]
    }
}
