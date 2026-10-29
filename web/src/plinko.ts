import { Store, sleep } from './store'
import { Sound, Ticker } from './sounds'

interface Point { x: number; y: number }

/**
 * The Products board, in units of the design's frame (370 wide); drawn scaled to the screen's width.
 * Rows are 56 apart, closer than the iPhone app's 78, so the whole board, bins included, fits above the slider on a laptop window.
 */
export const Board = {
  width: 370,
  height: 379,
  /** Five rows of toggles, alternating four and five, like the design. */
  toggles: ([
    [24, [57, 129, 201, 273]], [80, [21, 93, 165, 237, 309]], [136, [57, 129, 201, 273]],
    [192, [21, 93, 165, 237, 309]], [248, [57, 129, 201, 273]],
  ] as [number, number[]][]).flatMap(([y, xs]) => xs.map((x) => ({ x, y, w: 40, h: 17 }))),
  /** The bins run flush along the card's bottom, 54 tall, 60 below the last toggles. */
  binTop: 325,
  binHeight: 379 - 325,
  ballRadius: 11,
  /**
   * The bins' edges across the board, from 0 to its width. Each bin grows with its chance from a floor,
   * so the long shots still fit a name; the odds themselves are drawn elsewhere.
   */
  edges(odds: number[]) {
    const floor = 30, spare = Board.width - floor * odds.length
    return odds.reduce((e, o) => [...e, e[e.length - 1] + floor + o * spare], [0])
  },
}

/**
 * The drop that hangs from the top edge of the window as the slider moves, in window pixels: the ball appears
 * where its bulb ends up. The island is the black bar it stretches from, kept just above the edge.
 */
export const Notch = {
  island: { w: 124, h: 35 },
  reach: 40,
  maxRadius: 21,
  spawnY: -21 * 0.6 + 40,
}

/** A toggle as the ball sees it: a capsule, i.e. a segment with a radius. */
const capsule = (t: (typeof Board.toggles)[number]) => {
  const r = t.h / 2
  return { a: { x: t.x + r, y: t.y + t.h / 2 }, b: { x: t.x + t.w - r, y: t.y + t.h / 2 }, r }
}

export interface Hit { time: number; toggle: number; speed: number }
export interface Run { points: Point[]; hits: Hit[]; bin: number; duration: number }

export const dt = 1 / 240
const gravity = 1500
const bounciness = 0.55
/** Paths slower than this have dawdled on a toggle; they're thrown away. */
const maxDuration = 4.5

const rand = (lo: number, hi: number) => lo + Math.random() * (hi - lo)

/** Pushes the ball out of a capsule and bounces it off. Returns the impact speed if it struck. */
function collide(p: Point, v: Point, a: Point, b: Point, radius: number): number | undefined {
  const abx = b.x - a.x, aby = b.y - a.y
  const length2 = abx * abx + aby * aby
  const u = length2 === 0 ? 0 : Math.min(Math.max(((p.x - a.x) * abx + (p.y - a.y) * aby) / length2, 0), 1)
  const qx = a.x + abx * u, qy = a.y + aby * u
  const dx = p.x - qx, dy = p.y - qy
  const distance = Math.hypot(dx, dy)
  const reach = Board.ballRadius + radius
  if (distance >= reach) return undefined
  const nx = distance > 0 ? dx / distance : 0
  const ny = distance > 0 ? dy / distance : -1
  p.x = qx + nx * reach
  p.y = qy + ny * reach
  const vn = v.x * nx + v.y * ny
  if (vn >= 0) return undefined
  v.x -= (1 + bounciness) * vn * nx
  v.y -= (1 + bounciness) * vn * ny
  // Settling on a toggle's flat top: nudge it off sideways, as a real ball would roll.
  if (-vn < 120 && ny < -0.9) v.x += Math.random() < 0.5 ? 90 : -90
  // A little scatter, so no two drops bounce alike and the ball never balances on a toggle.
  const angle = rand(-0.25, 0.25)
  const vx = v.x * Math.cos(angle) - v.y * Math.sin(angle)
  v.y = v.x * Math.sin(angle) + v.y * Math.cos(angle)
  v.x = vx
  return -vn
}

/** One path, or undefined if the ball got stuck and never reached the bins in time. */
function simulate(start: Point, edges: number[]): Run | undefined {
  const r = Board.ballRadius
  const pegs = Board.toggles.map(capsule)
  const p = { ...start }
  const v = { x: rand(-45, 45), y: 0 }
  const points: Point[] = []
  const hits: Hit[] = []
  const lastHit = pegs.map(() => -1)
  const walls = edges.slice(1, -1)
  for (let t = dt; t < maxDuration; t += dt) {
    v.y += gravity * dt
    p.x += v.x * dt
    p.y += v.y * dt
    pegs.forEach((peg, i) => {
      const speed = collide(p, v, peg.a, peg.b, peg.r)
      if (speed === undefined) return
      if (t - lastHit[i] > 0.15) hits.push({ time: t, toggle: i, speed })
      lastHit[i] = t
    })
    if (p.y > 0) { // the board's sides; above it the ball is still falling in from the top of the window
      if (p.x < r) { p.x = r; v.x = Math.abs(v.x) * bounciness }
      if (p.x > Board.width - r) { p.x = Board.width - r; v.x = -Math.abs(v.x) * bounciness }
    }
    for (const x of walls) collide(p, v, { x, y: Board.binTop }, { x, y: Board.height }, 0.5)
    points.push({ x: p.x, y: p.y })
    if (p.y > Board.binTop + 21) { // swallowed halfway into the capsule
      const i = edges.slice(1).findIndex((e) => p.x < e)
      return { points, hits, bin: Math.max((i === -1 ? edges.length - 1 : i + 1) - 1, 0), duration: points.length * dt }
    }
  }
  return undefined
}

/**
 * A real bounce path that ends in `bin`. The bin is drawn by its odds beforehand, so physics alone
 * doesn't decide them (it would favour the middle); this tries fresh paths until one lands there.
 */
export function run(start: Point, bin: number, edges: number[]): Run {
  let fallback: Run | undefined
  for (let i = 0; i < 2000; i++) {
    const r = simulate(start, edges)
    if (!r) continue
    if (r.bin === bin) return r
    fallback ??= r
  }
  return fallback! // even a ~10% bin is reached naturally every few dozen paths, so 2000 misses don't happen
}

interface DropState {
  toggles: boolean[]
  /** The slider's progress, 0…1: the notch stretches into a drop as you swipe. */
  notch: number
  run?: Run
  /** The board on screen when the drop began: its top-left corner in window pixels, and its scale. */
  frame?: { x: number; y: number; scale: number }
  started: number
  eaten: boolean
}

/** One drop's live state: the toggles, the notch stretching, and the ball's path on screen. */
export class Drop extends Store<DropState> {
  /** The board's element, so the ball can start from the top of the window and be placed over the page. */
  board: HTMLElement | null = null

  constructor() {
    super({ toggles: Board.toggles.map(() => false), notch: 0, started: 0, eaten: false })
  }

  setNotch = (notch: number) => this.set({ notch })

  /**
   * Scrolls the page so the whole board, down to its bins, is above the controls: on a short window it would
   * otherwise fall out of sight. Smooth when you start swiping; instant when the ball is released.
   */
  revealBoard(behavior: ScrollBehavior = 'auto') {
    const board = this.board
    const scroller = board?.closest<HTMLElement>('.scroll')
    if (!board || !scroller) return
    const overflow = board.getBoundingClientRect().bottom - (scroller.getBoundingClientRect().bottom - 8)
    if (overflow > 0) scroller.scrollTo({ top: scroller.scrollTop + overflow, behavior })
  }

  reset() {
    this.set({ toggles: Board.toggles.map(() => false), run: undefined, frame: undefined, eaten: false })
  }

  /** Releases the ball from the top of the window and plays its fall into `bin`: toggles flip, click and tap as it hits them. */
  async play(bin: number, odds: number[]): Promise<number> {
    this.revealBoard()
    const rect = this.board?.getBoundingClientRect()
    const scale = rect ? rect.width / Board.width : 1
    const frame = { x: rect?.left ?? 0, y: rect?.top ?? 0, scale }
    // The ball starts above the board, in board units: straight above its middle, at the notch's bulb.
    const path = run({ x: Board.width / 2, y: (Notch.spawnY - frame.y) / scale }, bin, Board.edges(odds))
    Sound.spawn()
    const t0 = performance.now()
    this.set({ notch: 0, eaten: false, started: t0, run: path, frame })
    for (const hit of path.hits) {
      await sleep(Math.max(t0 + hit.time * 1000 - performance.now(), 0) / 1000)
      const toggles = [...this.s.toggles]
      const wasOn = toggles[hit.toggle]
      toggles[hit.toggle] = !wasOn
      this.set({ toggles })
      Ticker.bounce(!wasOn, hit.speed / 500)
    }
    await sleep(Math.max(t0 + path.duration * 1000 - performance.now(), 0) / 1000)
    this.set({ eaten: true }) // swallowed by the bin
    await sleep(0.25)
    return path.bin
  }

  /** Where the ball is at `now`, in board units. */
  ballPosition(now: number): Point | undefined {
    const { run: r, started } = this.s
    if (!r) return undefined
    return r.points[Math.min(Math.floor((now - started) / 1000 / dt), r.points.length - 1)]
  }
}
