import type { ReactNode } from 'react'
import type { ReelSymbol } from './catalog'

export type Outcome = 'won' | 'lost'

const ROW_HEIGHT = 60
/** The drum's radius: rows one `ROW_HEIGHT` apart on the payline, curving away above and below. */
const RADIUS = 120
const STEP = ROW_HEIGHT / RADIUS

const mod = (n: number, m: number) => ((n % m) + m) % m
export const symbolAt = (strip: ReelSymbol[], position: number) => strip[mod(Math.round(position), strip.length)]

interface Props {
  strips: ReelSymbol[][]
  positions: number[]
  /** Colours the payline after a pull. */
  outcome?: Outcome
}

/**
 * Three slot reels, each a curved drum like the picker wheel, behind one payline.
 * Positions are in rows and animate continuously, so a spin is one smooth, slowing motion.
 */
export function SlotMachine({ strips, positions, outcome }: Props) {
  return (
    <div
      className="slot"
      role="img"
      aria-label={`Slot: ${strips.map((s, c) => symbolAt(s, positions[c]).text).join(', ')}`}
    >
      {/* The band the three symbols must match on: a lighter tint than the pills, so they stand out on it. */}
      <div className={`payline ${outcome ?? ''}`} style={{ height: ROW_HEIGHT }} />
      <div className="reels">
        {strips.map((strip, c) => (
          <Reel key={c} strip={strip} position={positions[c]} outcome={outcome} />
        ))}
      </div>
      <div className={`arrows ${outcome ?? ''}`}><span>▶</span><span>◀</span></div>
    </div>
  )
}

function Reel({ strip, position, outcome }: { strip: ReelSymbol[]; position: number; outcome?: Outcome }) {
  const base = Math.floor(position)
  const faces: ReactNode[] = []
  for (let row = base - 4; row <= base + 4; row++) {
    // Rows below the payline have higher positions, so spinning moves the symbols down.
    const angle = (position - row) * STEP
    if (Math.abs(angle) >= Math.PI / 2) continue
    // Like the picker wheel: the row on the payline is solid with its pill, the rest fade back.
    // 1 on the payline, 0 a row away, so a row brightens smoothly as it rolls in.
    const emphasis = Math.max(0, 1 - Math.abs(position - row))
    const symbol = strip[mod(row, strip.length)]
    faces.push(
      <div
        key={row}
        className="face-slot"
        style={{ transform: `translateY(${Math.sin(angle) * RADIUS}px) scaleY(${Math.cos(angle)})`, opacity: Math.cos(angle) }}
      >
        <div
          className={`face ${outcome ?? ''}`}
          style={{ height: ROW_HEIGHT - 16, opacity: 0.3 + 0.7 * emphasis, ['--emphasis' as string]: emphasis }}
        >
          {symbol.icon ?? symbol.text}
        </div>
      </div>,
    )
  }
  return <div className="reel" style={{ height: RADIUS * 2 }}>{faces}</div>
}
