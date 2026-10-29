/**
 * The longer sounds (win, lose, spawn) and the short, frequent clicks (reel tick, ball bounces).
 * Everything goes through one AudioContext with preloaded buffers; clicks are capped at 25 a second.
 * Browsers only start audio after a gesture, so `prepare()` is called from the first pointer event.
 */
const files = {
  win: '/sounds/win.m4a',
  lose: '/sounds/lose.m4a',
  spawn: '/sounds/spawn.mp3',
  'reel-tick': '/sounds/reel-tick.m4a',
  tock: '/sounds/tock.m4a',
  tink: '/sounds/tink.m4a',
} as const
type Name = keyof typeof files

let context: AudioContext | undefined
const buffers = new Map<Name, AudioBuffer>()
let loading: Promise<void> | undefined

/** Creates the context and decodes the files. Safe to call often; call it from a user gesture. */
export function prepare() {
  if (!context) {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext
    if (!Ctx) return
    context = new Ctx()
  }
  if (context.state === 'suspended') void context.resume()
  loading ??= Promise.all(
    (Object.keys(files) as Name[]).map(async (name) => {
      try {
        const data = await (await fetch(files[name])).arrayBuffer()
        buffers.set(name, await context!.decodeAudioData(data))
      } catch {
        // a missing or undecodable sound just stays silent
      }
    }),
  ).then(() => undefined)
}

function play(name: Name) {
  const buffer = buffers.get(name)
  if (!context || !buffer) return
  const source = context.createBufferSource()
  source.buffer = buffer
  source.connect(context.destination)
  source.start()
}

export const Sound = {
  win: () => play('win'),
  lose: () => play('lose'),
  spawn: () => play('spawn'),
}

const minInterval = 40
let lastTick = 0
let lastBounce = 0

const buzz = (ms: number) => navigator.vibrate?.(ms)

export const Ticker = {
  prepare,
  tick() {
    const now = performance.now()
    if (now - lastTick < minInterval) return
    lastTick = now
    play('reel-tick')
    buzz(4)
  },
  /** The ball hitting a toggle: a tink if it was on, a tock if it was off, and a tap as hard as the hit. */
  bounce(offToggle: boolean, strength: number) {
    const now = performance.now()
    if (now - lastBounce < minInterval) return
    lastBounce = now
    play(offToggle ? 'tock' : 'tink')
    buzz(Math.round(8 * Math.min(Math.max(strength, 0.3), 1)))
  },
}

export const haptic = {
  success: () => buzz(30),
  error: () => buzz(50),
  impact: () => buzz(12),
}
