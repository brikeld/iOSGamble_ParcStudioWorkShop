import { useEffect, useRef, useState } from 'react'
import { Board, type Drop } from './plinko'
import { useStore } from './store'
import type { Outcome } from './SlotMachine'

interface Props {
  bins: string[]
  odds: number[]
  landed?: number
  outcome?: Outcome
  drop: Drop
}

/** Room above the board for the notch and the ball's first fall, in board units. */
const STAGE = 110

/**
 * The toggles over a grey well, and the iPads underneath, each box as wide as its chance. The bin the ball
 * fell in takes the outcome's colour, and its light rises up the board.
 */
export function TierBoard({ bins, odds, landed, outcome, drop }: Props) {
  const d = useStore(drop)
  const outer = useRef<HTMLDivElement>(null)
  const ball = useRef<HTMLDivElement>(null)
  const [scale, setScale] = useState(1)
  const edges = Board.edges(odds)

  useEffect(() => {
    const el = outer.current
    if (!el) return
    const measure = () => setScale(el.clientWidth / Board.width)
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => observer.disconnect()
  }, [])

  // The ball follows its precomputed path, one frame at a time, without re-rendering.
  useEffect(() => {
    if (!d.run) return
    let frame = 0
    const tick = (now: number) => {
      const p = drop.ballPosition(now)
      if (p && ball.current) ball.current.style.transform = `translate(${p.x - Board.ballRadius}px, ${p.y - Board.ballRadius}px)`
      frame = requestAnimationFrame(tick)
    }
    frame = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame)
  }, [d.run, drop])

  return (
    <div ref={outer} className="tier" style={{ height: Board.height * scale, marginTop: STAGE * scale }}>
      <div className="tier-inner" style={{ width: Board.width, height: Board.height, transform: `scale(${scale})` }}>
        <Notch progress={d.notch} />
        <div className="well">
          {landed !== undefined && outcome && (
            <Bloom outcome={outcome} width={edges[landed + 1] - edges[landed]} x={(edges[landed] + edges[landed + 1]) / 2} />
          )}
          {Board.toggles.map((t, i) => (
            <div
              key={i}
              className={`toggle ${d.toggles[i] ? 'on' : ''}`}
              style={{ left: t.x, top: t.y, width: t.w, height: t.h }}
            />
          ))}
          <div className="bins" style={{ top: Board.binTop, height: Board.binHeight }}>
            {bins.map((name, i) => {
              const hit = landed === i ? outcome : undefined
              // The long shots are narrow boxes: there each word gets its own line.
              const narrow = odds[i] * Board.width < 70
              return (
                <div key={i} className={`bin ${hit ?? ''}`} style={{ width: odds[i] * Board.width }}>
                  <div className={`bin-name ${narrow ? 'narrow' : ''}`}>
                    {narrow ? name.split(' ').map((w) => <span key={w}>{w}</span>) : name}
                  </div>
                  <div className="bin-odds">{Math.round(odds[i] * 100)}%</div>
                </div>
              )
            })}
          </div>
        </div>
        {d.run && (
          <div
            ref={ball}
            className="ball"
            style={{
              width: Board.ballRadius * 2,
              height: Board.ballRadius * 2,
              opacity: d.eaten ? 0 : 1,
              scale: d.eaten ? '0.05' : '1',
              left: 0,
              top: 0,
              transform: `translate(${Board.width / 2 - Board.ballRadius}px, ${Board.spawnY - Board.ballRadius}px)`,
            }}
          />
        )}
      </div>
    </div>
  )
}

/**
 * The notch stretching into a drop, like liquid, as the slider moves: black shapes run through a
 * blur-and-threshold filter merge into one blob.
 */
function Notch({ progress }: { progress: number }) {
  const island = { w: 124, h: 35, top: 12 }
  const reach = 40, maxRadius = 21
  const r = 8 + (maxRadius - 8) * progress
  const shoulder = r * 0.9
  const neck = r * (1 - 0.45 * progress)
  const bulbY = island.top + island.h - r * 0.6 + reach * progress
  const midY = island.top + island.h / 2
  const cx = Board.width / 2
  return (
    <div className="notch" style={{ top: -STAGE, opacity: progress > 0.001 ? 1 : 0 }}>
      <svg width="0" height="0" style={{ position: 'absolute' }}>
        <filter id="goo">
          <feGaussianBlur stdDeviation="5" />
          <feColorMatrix values="1 0 0 0 0  0 1 0 0 0  0 0 1 0 0  0 0 0 24 -10" />
        </filter>
      </svg>
      <div className="goo">
        <div className="blob" style={{ left: cx - island.w / 2, top: island.top, width: island.w, height: island.h, borderRadius: island.h }} />
        <div className="blob" style={{ left: cx - shoulder, top: island.top + island.h - shoulder * 1.2, width: shoulder * 2, height: shoulder * 2, borderRadius: '50%' }} />
        <div className="blob" style={{ left: cx - neck / 2, top: midY, width: neck, height: Math.max(bulbY - midY, 0), borderRadius: neck }} />
        <div className="blob" style={{ left: cx - r - 2, top: bulbY - r - 2, width: r * 2 + 4, height: r * 2 + 4, borderRadius: '50%' }} />
      </div>
    </div>
  )
}

/**
 * The light out of the bin the ball fell in: a soft bloom spreading up the board from a bright rim,
 * breathing slowly while the result stands. Centred on the bin's top edge; the bin hides its lower half.
 */
function Bloom({ outcome, width, x }: { outcome: Outcome; width: number; x: number }) {
  const spread = Math.max(width, 60)
  return (
    <div className={`bloom ${outcome}`} style={{ left: x, top: Board.binTop }}>
      <div className="bloom-glow" style={{ width: spread * 2.4, height: 300 }} />
      <div className="bloom-rim" style={{ width: width * 0.9 }} />
    </div>
  )
}
