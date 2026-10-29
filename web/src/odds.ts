/** Tune the game here. The user is never shown these numbers. */

/** Every pull is a fair coin flip. */
export const winChance = 0.5
/** Share of losses where only the last reel misses, by one row. */
export const nearMissShare = 0.8

const sign = () => (Math.random() < 0.5 ? 1 : -1)
const int = (lo: number, hi: number) => lo + Math.floor(Math.random() * (hi - lo + 1))

/**
 * Where each reel stops, in rows away from the jackpot symbol. All zero is a win.
 * A loss keeps the first reel on the jackpot, so it can never show three of a kind.
 */
export function stops(win: boolean): [number, number, number] {
  if (win) return [0, 0, 0]
  if (Math.random() < nearMissShare) return [0, 0, sign()]
  return [0, int(2, 3) * sign(), int(1, 3) * sign()]
}
