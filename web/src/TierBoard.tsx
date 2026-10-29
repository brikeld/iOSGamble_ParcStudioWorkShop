import { useEffect, useRef, useState } from 'react'
import { productImage, type Product } from './catalog'
import { Board, type Drop } from './plinko'
import { useStore } from './store'
import type { Outcome } from './SlotMachine'

interface Props {
  /** Undefined is Nothing. */
  bins: (Product | undefined)[]
  odds: number[]
  landed?: number
  outcome?: Outcome
  drop: Drop
}

/**
 * The toggles on a card, and the products in capsules along its bottom, each wider the likelier it is.
 * The capsule the ball fell in takes the outcome's colour, and its light rises up the board.
 */
export function TierBoard({ bins, odds, landed, outcome, drop }: Props) {
  const d = useStore(drop)
  const outer = useRef<HTMLDivElement>(null)
  const [scale, setScale] = useState(1)
  const edges = Board.edges(odds)

  useEffect(() => {
    const el = outer.current
    if (!el) return
    drop.board = el
    const measure = () => setScale(el.clientWidth / Board.width)
    measure()
    const observer = new ResizeObserver(measure)
    observer.observe(el)
    return () => { observer.disconnect(); if (drop.board === el) drop.board = null }
  }, [drop])

  return (
    <div ref={outer} className="tier" style={{ height: Board.height * scale }}>
      <div className="tier-inner" style={{ width: Board.width, height: Board.height, transform: `scale(${scale})` }}>
        <div className={`well ${landed !== undefined && outcome ? outcome : ''}`}>
          {landed !== undefined && outcome && (
            <Bloom outcome={outcome} width={Board.width} x={Board.width / 2} />
          )}
          {Board.toggles.map((t, i) => (
            <div
              key={i}
              className={`toggle ${d.toggles[i] ? 'on' : ''}`}
              style={{ left: t.x, top: t.y, width: t.w, height: t.h }}
            />
          ))}
          {/* Flush with the card's edges. The one the ball fell in widens to the whole width, over the others as they fade. */}
          <div className="bins" style={{ top: Board.binTop, height: Board.binHeight, width: Board.width }}>
            {bins.map((product, i) => {
              const settled = landed !== undefined
              const expanded = landed === i
              const width = edges[i + 1] - edges[i]
              const name = product?.name ?? 'Nothing'
              const iconOnly = width < 46 && !expanded // too narrow for "Nothing"
              // A narrow bin stacks its words, one per line, so a name shrinks to fit rather than breaking mid-word.
              const stacked = width < 60 && !expanded
              const lines = stacked ? name.split(' ').length : expanded ? 1 : 2
              return (
                <div
                  key={i}
                  className="bin"
                  aria-label={name}
                  aria-hidden={settled && !expanded}
                  style={{ left: expanded ? 0 : edges[i], width: expanded ? Board.width : width, opacity: !settled || expanded ? 1 : 0, zIndex: expanded ? 1 : 0 }}
                >
                  <div className="bin-content" style={{ gap: expanded ? 12 : 0 }}>
                    {product ? (
                      <img className="bin-photo" src={productImage(product)} alt="" style={{ width: expanded ? 34 : 0, opacity: expanded ? 1 : 0 }} />
                    ) : (
                      <span className="bin-none" style={{ width: iconOnly || expanded ? 22 : 0, opacity: iconOnly || expanded ? 1 : 0 }}>🚫</span>
                    )}
                    <span
                      className="bin-name"
                      style={{
                        WebkitLineClamp: lines,
                        width: iconOnly ? 0 : undefined,
                        opacity: iconOnly ? 0 : 1,
                        transform: expanded ? `scale(${13 / 11})` : undefined, // up to footnote size, smoothly
                      }}
                    >
                      {stacked ? name.split(' ').map((w, k) => <span key={k}>{w}<br /></span>) : name}
                    </span>
                  </div>
                  {i > 0 && <span className="bin-sep" style={{ opacity: settled ? 0 : 1 }} />}
                </div>
              )
            })}
            {/* The same line as between the bins, along their sides and bottom; its top edge is clipped off. */}
            <div className="bins-outline" style={{ opacity: landed === undefined ? 1 : 0 }} />
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * The light out of the bin the ball fell in: a soft bloom spreading up the board from a bright rim,
 * breathing slowly while the result stands. Centred on the bin's top edge; the bin itself hides its lower half.
 */
function Bloom({ outcome, width, x }: { outcome: Outcome; width: number; x: number }) {
  const spread = Math.min(Math.max(width, 60), 160) // a full-width bin glows wide, not over the whole board
  return (
    <div className={`bloom-in`} style={{ left: x, top: Board.binTop }}>
      <div className={`bloom ${outcome}`}>
        <div className="bloom-glow" style={{ width: spread * 2.4, height: 300, ['--reach' as string]: `${spread * 1.2}px` }} />
        <div className="bloom-rim" style={{ width: width * 0.9 }} />
      </div>
    </div>
  )
}
