/**
 * Plays the green "detecting" animation from FaceIDDetecting.json (the "Face Unlock" Lottie, 440 x 370 at 60 fps,
 * with its black container layer removed), drawn on a canvas. A port of the iOS app's FaceIDAnimation.swift, so
 * both draw exactly the same frames. It supports only what that file uses: shape layers whose bezier paths,
 * position, rotation, opacity, stroke width and blur are keyframed with cubic easing.
 */

export const frameRate = 60
const canvasSize = { width: 440, height: 370 }
const green = 'rgb(166, 248, 151)'

type Json = Record<string, unknown>
type Vec = [number, number]

const numbers = (value: unknown): number[] =>
  typeof value === 'number' ? [value] : Array.isArray(value) ? value.filter((v): v is number => typeof v === 'number') : []

interface Key { time: number; value: number[]; out: Vec; into: Vec; hold: boolean }

/** The y of a cubic bezier from (0, 0) to (1, 1) with these handles, at x. */
function ease(x: number, out: Vec, into: Vec) {
  const bezier = (u: number, a: number, b: number) => 3 * (1 - u) * (1 - u) * u * a + 3 * (1 - u) * u * u * b + u * u * u
  let low = 0, high = 1
  for (let i = 0; i < 24; i++) {
    const middle = (low + high) / 2
    if (bezier(middle, out[0], into[0]) < x) low = middle
    else high = middle
  }
  return bezier((low + high) / 2, out[1], into[1])
}

/** A keyframed (or constant) value: a vector, such as `[x, y]` for a position or `[degrees]` for a rotation. */
class Track {
  keys: Key[]

  constructor(keys: Key[]) { this.keys = keys }

  static constant(value: number[]) {
    return new Track([{ time: 0, value, out: [0, 0], into: [0, 0], hold: true }])
  }

  static of(property: unknown) {
    const p = (property ?? {}) as Json
    if (p.a === 1 && Array.isArray(p.k)) return new Track(Track.keysOf(p.k as Json[], (s) => (numbers(s).length ? numbers(s) : undefined)))
    return Track.constant(numbers(p.k))
  }

  static keysOf(frames: Json[], convert: (s: unknown) => number[] | undefined): Key[] {
    const keys: Key[] = []
    for (const frame of frames) {
      // A key with no value (the file has `[null]` after the checkmark) keeps the previous one.
      const value = convert(frame.s) ?? keys[keys.length - 1]?.value
      if (!value) continue
      const handle = (name: string): Vec => {
        const h = (frame[name] ?? {}) as Json
        return [numbers(h.x)[0] ?? 0, numbers(h.y)[0] ?? 0]
      }
      keys.push({ time: (frame.t as number) ?? 0, value, out: handle('o'), into: handle('i'), hold: frame.h === 1 })
    }
    return keys
  }

  scalar(frame: number) { return this.value(frame)[0] ?? 0 }

  value(frame: number): number[] {
    const { keys } = this
    const first = keys[0], last = keys[keys.length - 1]
    if (!first || frame <= first.time) return first?.value ?? [0, 0]
    let index = -1
    for (let i = keys.length - 1; i >= 0; i--) if (keys[i].time <= frame) { index = i; break }
    if (frame >= last.time || index < 0) return last.value
    const from = keys[index], to = keys[index + 1]
    if (from.hold) return from.value
    const progress = ease((frame - from.time) / (to.time - from.time), from.out, to.into)
    return from.value.map((v, i) => v + ((to.value[i] ?? v) - v) * progress)
  }
}

/**
 * A bezier path. Its vertices and tangents are flattened into one vector so they interpolate like any other value:
 * all the vertices, then all the in-tangents, then all the out-tangents, each as x, y pairs relative to the vertex.
 */
class ShapePath {
  track: Track
  count: number
  closed: boolean

  constructor(json: Json) {
    const flatten = (shape: unknown) => {
      // Keyframed paths wrap the shape in an array.
      const s = (Array.isArray(shape) ? shape[0] : shape) as Json | undefined
      const v = s?.v as number[][] | undefined, i = s?.i as number[][] | undefined, o = s?.o as number[][] | undefined
      if (!v || !i || !o) return undefined
      return { values: [...v, ...i, ...o].flat(), count: v.length, closed: (s?.c as boolean) ?? false }
    }
    const ks = (json.ks ?? {}) as Json
    let first: ReturnType<typeof flatten>
    if (ks.a === 1 && Array.isArray(ks.k)) {
      const frames = ks.k as Json[]
      first = flatten(frames[0]?.s)
      this.track = new Track(Track.keysOf(frames, (s) => flatten(s)?.values))
    } else {
      first = flatten(ks.k)
      this.track = Track.constant(first?.values ?? [])
    }
    this.count = first?.count ?? 0
    this.closed = first?.closed ?? false
  }

  /** The path's points at `frame`: a start, then a [control, control, end] triple per segment. */
  segments(frame: number): { start: Vec; curves: [Vec, Vec, Vec][]; closed: boolean } | undefined {
    const values = this.track.value(frame), n = this.count
    if (n <= 1 || values.length !== n * 6) return undefined
    const point = (block: number, index: number): Vec => [values[block * 2 * n + index * 2], values[block * 2 * n + index * 2 + 1]]
    const curves: [Vec, Vec, Vec][] = []
    for (let index = 0; index < (this.closed ? n : n - 1); index++) {
      const next = (index + 1) % n
      const from = point(0, index), to = point(0, next), out = point(2, index), into = point(1, next)
      curves.push([[from[0] + out[0], from[1] + out[1]], [to[0] + into[0], to[1] + into[1]], to])
    }
    return { start: point(0, 0), curves, closed: this.closed }
  }
}

class Layer {
  start: number
  end: number
  anchor: Track
  position: Track
  scale: Track
  rotation: Track
  opacity: Track
  paths: ShapePath[]
  fills: boolean
  strokeWidth?: Track
  blur?: Track

  constructor(json: Json) {
    this.start = (json.ip as number) ?? 0
    this.end = (json.op as number) ?? 0
    const ks = (json.ks ?? {}) as Json
    this.anchor = Track.of(ks.a)
    this.position = Track.of(ks.p)
    this.scale = Track.of(ks.s)
    this.rotation = Track.of(ks.r)
    this.opacity = Track.of(ks.o)
    const shapes = (json.shapes as Json[]) ?? []
    this.paths = shapes.filter((s) => s.ty === 'sh').map((s) => new ShapePath(s))
    this.fills = shapes.some((s) => s.ty === 'fl')
    const stroke = shapes.find((s) => s.ty === 'st')
    this.strokeWidth = stroke ? Track.of(stroke.w) : undefined
    // The Gaussian Blur effect's first property is its sigma.
    const effect = (json.ef as Json[] | undefined)?.[0]
    const sigma = ((effect?.ef as Json[] | undefined)?.[0] as Json | undefined)?.v
    this.blur = sigma === undefined ? undefined : Track.of(sigma)
  }

  /** Anchor, then scale, then rotation, then position, like After Effects. */
  transform(frame: number): (p: Vec) => Vec {
    const a = this.anchor.value(frame), p = this.position.value(frame), s = this.scale.value(frame)
    const angle = (this.rotation.scalar(frame) * Math.PI) / 180
    const cos = Math.cos(angle), sin = Math.sin(angle)
    return ([x, y]) => {
      const sx = (x - a[0]) * (s[0] / 100), sy = (y - a[1]) * (s[1] / 100)
      return [sx * cos - sy * sin + p[0], sx * sin + sy * cos + p[1]]
    }
  }
}

export class FaceIDAnimation {
  private layers: Layer[]

  private constructor(layers: Layer[]) { this.layers = layers }

  static async load(url: string): Promise<FaceIDAnimation> {
    try {
      const json = (await (await fetch(url)).json()) as Json
      return new FaceIDAnimation(((json.layers as Json[]) ?? []).map((l) => new Layer(l)))
    } catch {
      return new FaceIDAnimation([]) // a missing file just leaves the panel empty
    }
  }

  /** Draws the animation as it looks at `frame`, scaled to fit `width` x `height` (CSS pixels) on a canvas at `dpr`. */
  draw(frame: number, ctx: CanvasRenderingContext2D, width: number, height: number, dpr: number) {
    const fit = Math.min(width / canvasSize.width, height / canvasSize.height)
    const tx = (width - canvasSize.width * fit) / 2, ty = (height - canvasSize.height * fit) / 2
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0)
    ctx.clearRect(0, 0, width, height)
    // Blurred layers are drawn far off the canvas with their shadow offset back, since a shadow's blur works everywhere.
    const away = 4000

    // The first layer is the topmost, so draw back to front.
    for (let i = this.layers.length - 1; i >= 0; i--) {
      const layer = this.layers[i]
      if (frame < layer.start || frame >= layer.end) continue
      const opacity = layer.opacity.scalar(frame) / 100
      if (opacity <= 0) continue
      const apply = layer.transform(frame)
      const sigma = layer.blur ? (layer.blur.scalar(frame) / 3) * fit : 0
      const dx = sigma ? -away : 0

      ctx.save()
      ctx.globalAlpha = Math.min(opacity, 1)
      if (sigma) {
        ctx.globalCompositeOperation = 'lighter' // plus-lighter, so overlapping glows add up
        ctx.shadowColor = green
        ctx.shadowBlur = 2 * sigma * dpr
        ctx.shadowOffsetX = away * dpr
      }
      ctx.beginPath()
      const view = (p: Vec): Vec => { const q = apply(p); return [tx + q[0] * fit + dx, ty + q[1] * fit] }
      for (const path of layer.paths) {
        const seg = path.segments(frame)
        if (!seg) continue
        const s = view(seg.start)
        ctx.moveTo(s[0], s[1])
        for (const [c1, c2, end] of seg.curves) {
          const a = view(c1), b = view(c2), e = view(end)
          ctx.bezierCurveTo(a[0], a[1], b[0], b[1], e[0], e[1])
        }
        if (seg.closed) ctx.closePath()
      }
      if (layer.fills) {
        ctx.fillStyle = green
        ctx.fill()
      } else if (layer.strokeWidth) {
        ctx.strokeStyle = green
        ctx.lineWidth = layer.strokeWidth.scalar(frame) * fit
        ctx.stroke()
      }
      ctx.restore()
    }
  }
}
