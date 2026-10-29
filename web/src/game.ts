import * as Catalog from './catalog'
import * as Odds from './odds'
import { Store, sleep } from './store'
import { Ticker } from './sounds'

export type Mode = 'features' | 'product'
/** After `won` or `lost` the player chooses: keep gambling or keep what they have. */
export type Phase = 'idle' | 'spinning' | 'won' | 'lost' | 'nothing'

/** What the last pull changed, so the screen can flash it: green for won, orange for lost. */
export interface Change {
  /** Index into `Catalog.upgrades`, won outright or handed out as consolation. */
  upgradeWon?: number
  /** How many upgrades were lost: always the first ones. */
  upgradesLost: number
  /** +1 up an iPad, −1 down. */
  iPad: number
}

export interface GameState {
  mode: Mode
  productIndex: number
  /** How many of `Catalog.upgrades` you hold: always the first ones, in order. */
  upgrades: number
  /** Each reel's symbols, in its own shuffled order. */
  strips: Catalog.ReelSymbol[][]
  /** Reel positions in rows, unbounded; `row % strip.length` is the symbol on the payline. */
  reels: number[]
  spins: number
  phase: Phase
  change?: Change
  /** The beat right after a pull lands, while its colours flash and before the choice appears. */
  isMoment: boolean
  /** Pulls left before the next payment. */
  spinsLeft: number
  /** Paid for extra spins and tries, on top of the iPad. */
  fees: number
  /** Products: what's under the board this round: undefined is Nothing, then indices into `Catalog.products`. */
  bins: (number | undefined)[]
  /** Each bin's chance this round, adding up to 1. */
  odds: number[]
  landedBin?: number
  drops: number
  paidDrops: number
  showsSummary: boolean
}

const shuffled = <T,>(a: T[]) => {
  const r = [...a]
  for (let i = r.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[r[i], r[j]] = [r[j], r[i]]
  }
  return r
}

const mod = (n: number, m: number) => ((n % m) + m) % m

/** cubic-bezier(x1, y1, x2, y2) easing, like CSS: a fast start that slows into the landing row. */
function bezier(x1: number, y1: number, x2: number, y2: number) {
  const at = (t: number, a: number, b: number) => 3 * a * t * (1 - t) ** 2 + 3 * b * t * t * (1 - t) + t ** 3
  return (x: number) => {
    let lo = 0, hi = 1
    for (let i = 0; i < 24; i++) {
      const mid = (lo + hi) / 2
      if (at(mid, x1, x2) < x) lo = mid
      else hi = mid
    }
    return at((lo + hi) / 2, y1, y2)
  }
}
const reelCurve = bezier(0.3, 0.1, 0.1, 1)

/** One iChance session: what you have, the reels, and what you've paid. */
export class Game extends Store<GameState> {
  /** Where the reels rest between pulls; dragging the slider turns them from here. */
  private restingReels: number[] = []

  constructor() {
    super({
      mode: 'features',
      productIndex: Catalog.startProduct,
      upgrades: 0,
      strips: [],
      reels: [],
      spins: 0,
      phase: 'idle',
      isMoment: false,
      spinsLeft: Catalog.spinsPerPayment,
      fees: 0,
      bins: [],
      odds: [],
      drops: 0,
      paidDrops: 0,
      showsSummary: false,
    })
    console.assert(Catalog.products[Catalog.startProduct].storage[0].price === Catalog.paid, 'start configuration must cost what was paid')
    this.play('features')
  }

  // MARK: Derived

  get product() { return Catalog.products[this.s.productIndex] }
  get held() { return Catalog.upgrades.slice(0, this.s.upgrades) }
  /** Pro Storage swaps the base storage for the iPad's largest. */
  get storage() { return this.s.upgrades > Catalog.proStorage ? this.product.storage.at(-1)! : this.product.storage[0] }
  get configuration() { return Catalog.describe(this.storage) }
  /** What an upgrade is worth on the current iPad; Pro Storage is its jump to the largest storage. */
  priceOfUpgrade(i: number) {
    return i === Catalog.proStorage ? this.product.storage.at(-1)!.price - this.product.storage[0].price : Catalog.upgrades[i].price
  }
  get value() { return this.s.phase === 'nothing' ? 0 : this.held.reduce((sum, u) => sum + u.price, this.storage.price) }
  get totalPaid() { return Catalog.paid + this.s.fees }
  get profit() { return this.value - this.totalPaid }
  get needsPayment() { return this.s.spinsLeft === 0 }
  get lostLast() { const c = this.s.change; return c ? c.upgradesLost > 0 || c.iPad < 0 : false }
  /** On the base iPad with nothing else left to take, a loss means receiving nothing. */
  get isLastChance() { return this.s.productIndex === 0 && this.s.upgrades === 0 }
  /** The first drop is free, then each one costs more than the last: 50, 100, 150… */
  get dropPrice() { return this.s.drops * Catalog.dropPriceStep }
  get needsDropPayment() { return this.s.drops > this.s.paidDrops }
  /** Holding the board's best iPad: the place to go on and win its features. */
  get hasBestTierProduct() { return this.s.productIndex === Math.max(...Catalog.boardProducts) }

  /** Features ends once you hold every upgrade on an iPad above the one you ordered; Products can always be played again. */
  canPlay(mode: Mode) {
    const { phase, upgrades, productIndex } = this.s
    return phase !== 'nothing' && (mode === 'product' || !(upgrades === Catalog.upgrades.length && productIndex > Catalog.startProduct))
  }

  // MARK: Actions

  play(mode: Mode) {
    if (mode === 'features') {
      // A fresh machine must not already show three of a kind.
      let strips: Catalog.ReelSymbol[][]
      do {
        strips = [0, 1, 2].map(() => shuffled(Catalog.featureSymbols))
      } while (new Set(strips.map((s) => s[0])).size === 1)
      const reels = strips.map(() => 0)
      this.restingReels = reels
      this.set({ mode, strips, reels })
    } else {
      this.set({ mode })
      this.newRound()
    }
    if (this.s.phase === 'won' || this.s.phase === 'lost') this.set({ phase: 'idle' })
  }

  /**
   * Nothing, then every board iPad but yours. The closer a bin's price to your iPad's, the likelier the ball
   * lands in it: odds go as one over the price gap, so a long shot is a narrow box. Nothing is priced at $0.
   */
  private newRound() {
    const price = (i?: number) => (i === undefined ? 0 : Catalog.products[i].storage[0].price)
    const bins = [undefined, ...Catalog.boardProducts.filter((p) => p !== this.s.productIndex)]
    const weights = bins.map((b) => 1 / Math.abs(price(b) - price(this.s.productIndex)))
    const total = weights.reduce((a, b) => a + b, 0)
    this.set({ bins, odds: weights.map((w) => w / total), landedBin: undefined })
  }

  /** Starts a drop and draws its bin by the odds. Undefined if it isn't allowed now. */
  startDrop(): number | undefined {
    const { mode, phase, odds, drops } = this.s
    if (mode !== 'product' || phase !== 'idle' || this.needsDropPayment) return undefined
    this.set({ phase: 'spinning', drops: drops + 1 })
    let draw = Math.random()
    for (let bin = 0; bin < odds.length; bin++) {
      draw -= odds[bin]
      if (draw < 0) return bin
    }
    return odds.length - 1
  }

  /**
   * The ball has been eaten by a bin: you now have that iPad, and keep your upgrades.
   * Nothing takes everything: the bin lights up for the moment, then the screen says so.
   */
  async land(bin: number) {
    const product = this.s.bins[bin]
    if (product === undefined) {
      this.set({ landedBin: bin, phase: 'lost', change: { upgradesLost: this.s.upgrades, iPad: -1 }, isMoment: true })
      await sleep(1.5)
      this.set({ isMoment: false, phase: 'nothing' })
      return
    }
    const iPad = product > this.s.productIndex ? 1 : -1 // the catalogue runs cheapest to dearest
    this.set({ productIndex: product, landedBin: bin, phase: iPad > 0 ? 'won' : 'lost', change: { upgradesLost: 0, iPad }, isMoment: true })
    await sleep(1.5)
    this.set({ isMoment: false })
  }

  payForDrop() {
    this.set({ fees: this.s.fees + this.dropPrice, paidDrops: this.s.paidDrops + 1, phase: 'idle' })
    this.newRound()
  }

  /** After a win: carry on here, or in the other game once this one is finished. */
  keepGambling() {
    if (this.canPlay(this.s.mode)) this.set({ phase: 'idle' })
    else this.play(this.s.mode === 'features' ? 'product' : 'features')
  }

  /** The reels follow the slider's knob, up to two rows, and slide back if it's let go early. */
  nudge = (progress: number) => {
    if (this.s.phase !== 'idle') return
    const reels = this.restingReels.map((r) => r + progress * 2)
    this.tickOnRowChange(this.s.reels, reels)
    this.set({ reels })
  }

  payForSpins() {
    this.set({ fees: this.s.fees + Catalog.spinPrice, spinsLeft: Catalog.spinsPerPayment })
  }

  showSummary(shows: boolean) { this.set({ showsSummary: shows }) }

  /** Three of a kind wins the next prize, anything else costs you. `power`, 0…1, is how hard the slider was swiped. */
  async pull(power: number) {
    const s = this.s
    if (s.mode !== 'features' || s.phase !== 'idle' || !this.canPlay('features') || this.needsPayment) return
    this.set({ phase: 'spinning', spinsLeft: s.spinsLeft - 1, spins: s.spins + 1 })
    const win = Math.random() < Odds.winChance
    // The jackpot shows what this pull is for: the next upgrade, or the next iPad.
    const jackpot = Catalog.featureSymbols[s.upgrades]
    const stops = Odds.stops(win)

    // Reels start together and stop left to right; a harder swipe keeps them going longer.
    await Promise.all(
      s.strips.map((strip, c) =>
        this.spinReel(c, strip.indexOf(jackpot) + stops[c], 14 + c * 6 + Math.floor(power * 16), 1.6 + c * 0.45 + power * 0.8),
      ),
    )
    this.restingReels = this.s.reels

    if (!win) await sleep(1.2) // let the near miss sink in
    this.settle(win)
    this.set({ isMoment: true })
    await sleep(1.5)
    this.set({ isMoment: false })
  }

  /**
   * A win adds the next upgrade, and with all of them the iPad above. A loss takes every upgrade
   * but keeps the iPad; with none left, it drops an iPad and hands back an Apple Pencil, and on the last iPad
   * it takes the iPad itself.
   */
  settle(win: boolean) {
    const { upgrades, productIndex } = this.s
    const change: Change = { upgradesLost: 0, iPad: 0 }
    let patch: Partial<GameState>
    if (win) {
      if (upgrades < Catalog.upgrades.length) {
        change.upgradeWon = upgrades
        patch = { phase: 'won', upgrades: upgrades + 1 }
      } else {
        change.iPad = 1
        patch = { phase: 'won', productIndex: productIndex + 1 }
      }
    } else if (this.isLastChance) {
      patch = { phase: 'nothing' }
    } else if (upgrades > 0) {
      change.upgradesLost = upgrades
      patch = { phase: 'lost', upgrades: 0 }
    } else {
      change.iPad = -1
      change.upgradeWon = 0
      patch = { phase: 'lost', productIndex: productIndex - 1, upgrades: 1 }
    }
    this.set({ ...patch, change })
  }

  private tickOnRowChange(before: number[], after: number[]) {
    if (after.some((p, c) => Math.round(p) !== Math.round(before[c]))) Ticker.tick()
  }

  /** One continuous animation: a fast start that slows into the landing row, like a real reel. */
  private spinReel(c: number, position: number, rows: number, duration: number) {
    const count = this.s.strips[c].length
    const target = mod(position, count)
    const start = Math.round(this.s.reels[c]) // the slider may have left it between rows
    const landing = start + rows + mod(target - mod(start + rows, count), count)
    const from = this.s.reels[c]
    const t0 = performance.now()
    return new Promise<void>((resolve) => {
      const frame = (now: number) => {
        const t = Math.min((now - t0) / (duration * 1000), 1)
        const reels = [...this.s.reels]
        const before = reels[c]
        reels[c] = from + (landing - from) * reelCurve(t)
        if (Math.round(reels[c]) !== Math.round(before)) Ticker.tick()
        this.set({ reels })
        if (t < 1) requestAnimationFrame(frame)
        else resolve()
      }
      requestAnimationFrame(frame)
    })
  }

  /** The symbol on the payline of reel `c`. */
  symbolAt(c: number) {
    const strip = this.s.strips[c]
    return strip[mod(Math.round(this.s.reels[c]), strip.length)]
  }
}

/** The ladders from the brief, replayed so a rule change can't quietly break them. Returns the failures. */
export function selfCheck(): string[] {
  const failures: string[] = []
  const check = (ok: boolean, message: string) => { if (!ok) failures.push(message) }

  const down = new Game()
  down.settle(true)
  down.settle(true)
  down.settle(false)
  check(down.s.productIndex === Catalog.startProduct && down.s.upgrades === 0, 'a loss on your iPad takes your upgrades')
  down.settle(false)
  check(down.s.productIndex === 1 && down.s.upgrades === 1, 'with none left, it drops an iPad and hands back the Pencil')
  down.settle(true)
  down.settle(true)
  down.settle(false)
  check(down.s.productIndex === 1 && down.s.upgrades === 0, 'below your iPad too, upgrades go before the iPad does')
  down.settle(false)
  check(down.s.productIndex === 0 && down.s.upgrades === 1, 'then the next iPad down, with the Pencil')
  down.settle(false)
  check(down.s.productIndex === 0 && down.s.upgrades === 0, 'the last iPad loses its upgrades')
  down.settle(false)
  check(down.s.phase === 'nothing', 'then itself')

  const up = new Game()
  for (let i = 0; i <= Catalog.upgrades.length; i++) up.settle(true)
  check(up.s.productIndex === Catalog.startProduct + 1 && up.s.upgrades === Catalog.upgrades.length && !up.canPlay('features'),
    'every upgrade, then the iPad above ends Features')
  return failures
}
