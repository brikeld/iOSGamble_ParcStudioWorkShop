import { useEffect, useRef } from 'react'
import { Board, Notch, type Drop } from './plinko'
import { useStore } from './store'

/**
 * The drop and the ball over the whole window: a black drop stretches down from the top edge of the
 * window as the slider moves, then falls into the board as if it came in from outside the page.
 */
export function BallLayer({ drop }: { drop: Drop }) {
  const d = useStore(drop)
  const ball = useRef<HTMLDivElement>(null)
  const rect = drop.board?.getBoundingClientRect()
  const scale = d.frame?.scale ?? (rect ? rect.width / Board.width : 1)
  // Straight above the board's middle, which is where the physics starts the ball.
  const cx = (d.frame?.x ?? rect?.left ?? 0) + (Board.width / 2) * scale
  const size = Board.ballRadius * 2 * scale
  const clip = d.frame ? hideBehindBins(d.frame) : undefined

  // The ball follows its precomputed path, one frame at a time, without re-rendering.
  useEffect(() => {
    if (!d.run || !d.frame) return
    const { x, y, scale } = d.frame
    let frame = 0
    const tick = (now: number) => {
      const p = drop.ballPosition(now)
      if (p && ball.current) {
        ball.current.style.transform = `translate(${x + (p.x - Board.ballRadius) * scale}px, ${y + (p.y - Board.ballRadius) * scale}px)`
      }
      frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [d.run, d.frame, drop])

  return (
    <div className="ball-layer" aria-hidden="true">
      <Drip progress={d.notch} cx={cx} />
      {/* The ball is clipped by the bins' strip, so it drops in behind them, then fades. */}
      {d.run && (
        <div className="ball-clip" style={{ clipPath: clip }}>
          <div
            ref={ball}
            className="ball-track"
            style={{ width: size, height: size, transform: `translate(${cx - size / 2}px, ${Notch.spawnY - size / 2}px)` }}
          >
            <div className="ball" style={{ opacity: d.eaten ? 0 : 1 }} />
          </div>
        </div>
      )}
    </div>
  )
}

/**
 * A clip path covering the whole window except the bins' strip along the board's bottom, in window pixels:
 * whatever is drawn through it disappears behind the bins.
 */
function hideBehindBins({ x, y, scale }: { x: number; y: number; scale: number }) {
  const big = 100000
  const left = x, right = x + Board.width * scale
  const top = y + Board.binTop * scale, bottom = y + Board.height * scale
  return `path(evenodd, "M ${-big} ${-big} H ${big} V ${big} H ${-big} Z M ${left} ${top} H ${right} V ${bottom} H ${left} Z")`
}

/**
 * A drop stretching out of the top edge of the window as the slider moves: a flare at the edge narrowing
 * into a neck that ends in a round bulb. One filled path, so its edges stay crisp in every browser
 * (a blur-and-threshold filter looked ragged in Safari).
 */
function Drip({ progress, cx }: { progress: number; cx: number }) {
  const { reach, maxRadius } = Notch
  const r = 8 + (maxRadius - 8) * progress
  const neck = r * (1 - 0.45 * progress)
  const flare = 20 + 18 * progress // half-width where it leaves the edge
  const bulbY = -r * 0.6 + reach * progress // the bulb's centre; the window's top edge is y = 0
  const necktop = Math.min(10 + 14 * progress, Math.max(bulbY - r, 4))
  const neckBottom = bulbY - r * 0.9
  const left = cx - neck / 2, right = cx + neck / 2
  const d = [
    `M ${cx - flare} -6`,
    `C ${cx - flare * 0.35} -2, ${left} ${necktop * 0.3}, ${left} ${necktop}`,
    `L ${left} ${neckBottom}`,
    `C ${left} ${bulbY - r * 0.5}, ${cx - r} ${bulbY - r * 0.55}, ${cx - r} ${bulbY}`,
    `A ${r} ${r} 0 0 0 ${cx + r} ${bulbY}`,
    `C ${cx + r} ${bulbY - r * 0.55}, ${right} ${bulbY - r * 0.5}, ${right} ${neckBottom}`,
    `L ${right} ${necktop}`,
    `C ${right} ${necktop * 0.3}, ${cx + flare * 0.35} -2, ${cx + flare} -6`,
    'Z',
  ].join(' ')
  return (
    <svg className="notch" style={{ opacity: progress > 0.001 ? 1 : 0 }} width="100%" height="120">
      <path d={d} fill="#000" />
    </svg>
  )
}
