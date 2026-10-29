import { useEffect, useRef, useState } from 'react'
import { Ticker } from './sounds'

/** The knob fills the track's height, as in the design. */
export const SLIDER_HEIGHT = 58
const KNOB = 58

interface Props {
  label: string
  disabled?: boolean
  /** How far the knob is, 0…1, so the reels can follow it. */
  onDrag?: (progress: number) => void
  /** Called with the swipe's speed, 0…1. */
  onAction: (power: number) => void
}

/** The "slide to power off" control: drag the knob all the way right, or flick it, to spin. */
export function SlideToSpin({ label, disabled = false, onDrag, onAction }: Props) {
  const track = useRef<HTMLDivElement>(null)
  const [offset, setOffset] = useState(0)
  const [glide, setGlide] = useState<'none' | 'out' | 'back'>('none')
  const drag = useRef<{ startX: number; samples: { x: number; t: number }[]; fired: boolean } | null>(null)

  const travel = () => Math.max((track.current?.clientWidth ?? 0) - KNOB, 1)

  // Disabling the slider mid-swipe must not leave it stuck.
  useEffect(() => {
    drag.current = null
    setGlide('none')
    setOffset(0)
  }, [disabled])

  /** Px per second over the last 100 ms of the drag. */
  const velocity = () => {
    const samples = drag.current?.samples ?? []
    const last = samples.at(-1)
    const first = samples.find((s) => last && last.t - s.t <= 100)
    return last && first && last.t > first.t ? ((last.x - first.x) / (last.t - first.t)) * 1000 : 0
  }

  const fire = () => {
    drag.current!.fired = true
    onAction(Math.min(Math.max(velocity() / 2500, 0), 1))
  }

  const down = (e: React.PointerEvent) => {
    if (disabled) return
    Ticker.prepare()
    e.currentTarget.setPointerCapture(e.pointerId)
    drag.current = { startX: e.clientX - offset, samples: [], fired: false }
    setGlide('none')
  }

  const move = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d || d.fired || disabled) return
    const max = travel()
    const x = Math.min(Math.max(e.clientX - d.startX, 0), max)
    d.samples.push({ x, t: performance.now() })
    if (d.samples.length > 20) d.samples.shift()
    setOffset(x)
    onDrag?.(x / max)
    if (x === max) {
      fire()
      setGlide('back')
      setOffset(0)
    }
  }

  const up = () => {
    const d = drag.current
    drag.current = null
    if (!d || d.fired || disabled) return
    const max = travel()
    const v = velocity()
    d.fired = false
    if (offset + v * 0.2 >= max) {
      // Inertia: a flick carries the knob the rest of the way at its own speed.
      drag.current = d
      fire()
      drag.current = null
      setGlide('out')
      setOffset(max)
      setTimeout(() => { setGlide('back'); setOffset(0) }, Math.min(Math.max(((max - offset) / Math.max(v, 1)) * 1000, 80), 300))
    } else {
      setGlide('back')
      onDrag?.(0)
      setOffset(0)
    }
  }

  const progress = offset / travel()
  return (
    <div
      ref={track}
      className="slider"
      style={{ height: SLIDER_HEIGHT, opacity: disabled ? 0.4 : 1 }}
      role="button"
      tabIndex={disabled ? -1 : 0}
      aria-label={label}
      aria-disabled={disabled}
      onKeyDown={(e) => { if (!disabled && (e.key === 'Enter' || e.key === ' ')) onAction(0.5) }}
    >
      <div className="slider-label shimmer" style={{ opacity: 1 - progress * 2, paddingLeft: KNOB }}>{label}</div>
      <div
        className="slider-knob"
        style={{
          width: KNOB,
          height: KNOB,
          transform: `translateX(${offset}px)`,
          transition: glide === 'none' ? 'none' : glide === 'out' ? 'transform .2s ease-out' : 'transform .5s cubic-bezier(.34,1.56,.64,1)',
        }}
        onPointerDown={down}
        onPointerMove={move}
        onPointerUp={up}
        onPointerCancel={up}
      >
        →
      </div>
    </div>
  )
}
