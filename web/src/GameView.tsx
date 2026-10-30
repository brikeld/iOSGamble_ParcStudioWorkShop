import { BackButton } from './BackButton'
import { Symbol } from './Symbol'
import { BallLayer } from './BallLayer'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import * as Catalog from './catalog'
import { ApplePaySheet } from './ApplePaySheet'
import { useGame } from './context'
import type { Change, Mode, Phase } from './game'
import { dollars, profitText } from './money'
import { Drop } from './plinko'
import { ProductRow } from './Screens'
import { Alert } from './Sheet'
import { SLIDER_HEIGHT, SlideToSpin } from './SlideToSpin'
import { SlotMachine, type Outcome } from './SlotMachine'
import { Sound, Ticker, haptic } from './sounds'
import { useStore } from './store'
import { TierBoard } from './TierBoard'

/** How a prize capsule looks. `just…` are the flash right after a pull, outlined in their colour. */
type Prize = 'idle' | 'next' | 'won' | 'justWon' | 'justLost'

const prizeLabel: Record<Prize, string> = {
  idle: 'Not won', next: 'Playing for this', won: 'Won', justWon: 'Won', justLost: 'Lost',
}

/** Features is a slot machine; Products drops a ball from the top of the window through a board of toggles. */
export function GameView({ onBack }: { onBack: () => void }) {
  const game = useGame()
  const s = useStore(game)
  const [drop] = useState(() => new Drop())
  const [confirmsLastChance, setConfirmsLastChance] = useState(false)
  const [paysForSpins, setPaysForSpins] = useState(false)
  const [paysForDrop, setPaysForDrop] = useState(false)
  const [menu, setMenu] = useState(false)
  const previous = useRef<Phase>(s.phase)

  useEffect(() => { Ticker.prepare() }, [])
  useEffect(() => { if (s.landedBin === undefined) drop.reset() }, [s.landedBin, drop]) // a new round
  // The choice that follows a landing is taller than the slider, so once it replaces the slider, keep the board's bins in view above it.
  useEffect(() => { if (s.landedBin !== undefined && !s.isMoment) drop.revealBoard('smooth') }, [s.landedBin, s.isMoment, drop])

  useEffect(() => {
    const old = previous.current
    previous.current = s.phase
    if (old === s.phase) return
    if (s.phase === 'won') { Sound.win(); haptic.success() }
    if (s.phase === 'lost' || (s.phase === 'nothing' && old !== 'lost')) { Sound.lose(); haptic.error() } // Nothing has already lost
  }, [s.phase])

  const switchTo = (mode: Mode) => { setMenu(false); game.play(mode) }

  return (
    <div className="game">
      {s.mode === 'product' && <BallLayer drop={drop} />}
      <header className="bar">
        <BackButton onClick={onBack} disabled={s.phase === 'spinning'} />
        <h2>{s.mode === 'features' ? 'Features' : 'Products'}</h2>
        <div className="menu-wrap">
          <button className="glass-circle" aria-label="More" disabled={s.phase === 'spinning'} onClick={() => setMenu(!menu)}>
            <svg width="16" height="4" viewBox="0 0 16 4" fill="currentColor" aria-hidden="true"><circle cx="2" cy="2" r="2" /><circle cx="8" cy="2" r="2" /><circle cx="14" cy="2" r="2" /></svg>
          </button>
          {menu && (
            <div className="menu" onMouseLeave={() => setMenu(false)}>
              <span className="menu-title">Gamble</span>
              <button disabled={s.mode === 'features' || !game.canPlay('features')} onClick={() => switchTo('features')}><Symbol className="menu-icon" icon="/icons/features.svg" /> Features</button>
              <button disabled={s.mode === 'product' || !game.canPlay('product')} onClick={() => switchTo('product')}><Symbol className="menu-icon" icon="/icons/products.svg" /> Products</button>
              <hr />
              <button onClick={() => { setMenu(false); game.showSummary(true) }}>🚪 Leave iChance</button>
            </div>
          )}
        </div>
      </header>

      {s.phase === 'nothing' ? (
        <div className="empty">
          <div className="empty-icon">📦</div>
          <h2>You’ll receive nothing.</h2>
          <p className="secondary">You paid {dollars(game.totalPaid)}. Your {game.device.kind} won’t be delivered.</p>
          <button className="prominent" onClick={() => game.showSummary(true)}>View Summary</button>
        </div>
      ) : (
        <>
          <div className="scroll" style={{ overflow: s.phase === 'spinning' ? 'hidden' : undefined }}>{machine()}</div>
          <div className="controls">{controls()}</div>
        </>
      )}

      {paysForSpins && (
        <ApplePaySheet amount={Catalog.spinPrice} onPaid={() => game.payForSpins()} onClose={() => setPaysForSpins(false)} />
      )}
      {paysForDrop && (
        <ApplePaySheet amount={game.dropPrice} onPaid={() => game.payForDrop()} onClose={() => setPaysForDrop(false)} />
      )}
      {confirmsLastChance && (
        <Alert
          title="Are You Sure?"
          message={`This is your last ${game.device.kind}. If you lose this spin, you lose it: you paid ${dollars(game.totalPaid)} and no ${game.device.kind} will be delivered.`}
          confirm="Spin"
          onCancel={() => { setConfirmsLastChance(false); game.nudge(0) }}
          onConfirm={() => { setConfirmsLastChance(false); void game.pull(0.5) }}
        />
      )}
    </div>
  )

  function machine(): ReactNode {
    const moment = s.isMoment ? s.change : undefined
    // A product below the one you ordered is outlined orange, above it green; the card itself stays white.
    const start = game.device.start
    const tier: Outcome | undefined = s.productIndex < start ? 'lost' : s.productIndex > start ? 'won' : undefined
    const upgrades = game.device.upgrades
    const left = upgrades.length - 1
    const tall = left * 38 + (left - 1) * 8
    const slotOutcome: Outcome | undefined = s.phase === 'won' ? 'won' : s.phase === 'lost' ? 'lost' : undefined
    return (
      <div className="machine">
        <h3 className="header">Your Product</h3>
        <div className={`product-card ${tier ?? ''}`}>
          <ProductRow name={game.product.name} image={Catalog.productImage(game.product)} imageHeight={46} configuration={game.configuration} />
          {/* Products has no winnings header, so the card carries the running total, as in the design. */}
          {s.mode === 'product' && game.profit !== 0 && (
            <strong className={game.profit > 0 ? 'won-text' : 'lost-text'}>{profitText(game.profit)}</strong>
          )}
        </div>

        {s.mode === 'features' ? (
          <>
            <div className="between header-row">
              <h3 className="header">Winnings</h3>
              <span className="footnote secondary">
                Total: <strong className={game.profit > 0 ? 'won-text' : game.profit < 0 ? 'lost-text' : ''}>{profitText(game.profit)}</strong>
              </span>
            </div>
            <div className="winnings">
              {/* Every upgrade but the last on the left; the last, the AirPods, as one tile as tall as the left column. */}
              <div className="col">{upgrades.slice(0, left).map((_, i) => capsule(i, moment, 38, 'left'))}</div>
              <div className="col">{upgrades.slice(left).map((_, i) => capsule(left + i, moment, tall, 'center'))}</div>
            </div>

            <div className="between header-row">
              <h3 className="header">Slot</h3>
              <span className="footnote secondary">{s.spinsLeft === 1 ? '1 spin left' : `${s.spinsLeft} spins left`}</span>
            </div>
            <SlotMachine strips={s.strips} positions={s.reels} outcome={slotOutcome} />
          </>
        ) : (
          <>
            <div className="between header-row">
              <h3 className="header">Board</h3>
              <span className="footnote secondary">{s.drops === 0 ? 'First drop free' : s.drops === 1 ? '1 drop' : `${s.drops} drops`}</span>
            </div>
            {/* Landing on the product you already have shows no colour: nothing gained, nothing lost. */}
            <TierBoard
              bins={s.bins.map((b) => (b === undefined ? undefined : game.device.products[b]))}
              odds={s.odds}
              landed={s.landedBin}
              outcome={s.change?.iPad === 0 ? undefined : s.phase === 'won' ? 'won' : s.phase === 'lost' ? 'lost' : undefined}
              drop={drop}
            />
          </>
        )}
      </div>
    )
  }

  /** Lost beats held beats next: a lost upgrade flashes orange even if it's the one you play for again. */
  function prizeState(i: number, moment?: Change): Prize {
    if (moment && i < moment.upgradesLost) return 'justLost'
    if (i < s.upgrades) return moment?.upgradeWon === i ? 'justWon' : 'won'
    if (i === s.upgrades && s.mode === 'features' && game.canPlay('features')) return 'next'
    return 'idle'
  }

  /** `price` shows during the moment: what was just won or lost, in the outline's colour. */
  function capsule(i: number, moment: Change | undefined, height: number, align: 'left' | 'center'): ReactNode {
    const upgrade = game.device.upgrades[i]
    const state = prizeState(i, moment)
    // The price takes the icon's place for the moment: name, icon and price don't all fit in a short capsule.
    const showsPrice = state === 'justWon' || state === 'justLost'
    return (
      <div key={upgrade.name} className={`capsule ${state} ${align}`} style={{ height }} aria-label={`${upgrade.name}: ${prizeLabel[state]}`}>
        {!showsPrice && <Symbol className="capsule-icon" icon={upgrade.icon} />}
        <span className="capsule-name">{upgrade.name}</span>
        {showsPrice && <strong className="capsule-price">{(state === 'justWon' ? '+' : '−') + dollars(game.priceOfUpgrade(i))}</strong>}
      </div>
    )
  }

  /** Products: swipe to drop, then pay more each time for another try, or take what you have. */
  function tierControls(): ReactNode {
    // Also when a drop is owed: coming back from Features after a drop, the next one must be paid for first.
    if (!s.isMoment && (s.phase === 'won' || s.phase === 'lost' || (s.phase === 'idle' && game.needsDropPayment))) {
      return (
        // The same pair as the Features page: the main action in blue on top, the quieter one below.
        <div className="choices">
          {/* On the best product another drop can only go down; offer to win its features instead. */}
          {game.hasBestTierProduct && game.canPlay('features') ? (
            <button className="prominent" data-testid="gambleFeatures" onClick={() => game.play('features')}>Gamble for features</button>
          ) : (
            <button className="prominent" data-testid="anotherTry" onClick={() => setPaysForDrop(true)}>{dollars(game.dropPrice)} for another try</button>
          )}
          <button className="glass" data-testid="keep" onClick={() => game.showSummary(true)}>Take winnings</button>
        </div>
      )
    }
    return (
      <SlideToSpin
        label="Swipe to win"
        disabled={s.phase !== 'idle'}
        onDrag={(progress) => {
          if (progress > 0 && drop.s.notch === 0) drop.revealBoard('smooth') // the board's bins must be in view for the fall
          drop.setNotch(progress)
        }}
        onAction={() => {
          const bin = game.startDrop()
          if (bin === undefined) { drop.setNotch(0); return }
          void drop.play(bin, game.s.odds).then((landed) => game.land(landed))
        }}
      />
    )
  }

  function controls(): ReactNode {
    if (s.mode === 'product') return tierControls()
    if (!s.isMoment && (s.phase === 'won' || s.phase === 'lost' || !game.canPlay(s.mode))) {
      return (
        <div className="choices">
          {(game.canPlay('features') || game.canPlay('product')) && (
            <button className="prominent" data-testid="keepGambling" onClick={() => game.keepGambling()}>
              {game.lostLast ? 'Win it back' : 'Spin for more'}
            </button>
          )}
          <button className="glass" data-testid="keep" onClick={() => game.showSummary(true)}>
            {game.lostLast ? 'Keep this' : 'Take winnings'}
          </button>
        </div>
      )
    }
    if (game.needsPayment && s.phase === 'idle') {
      return (
        <button className="prominent black" style={{ height: SLIDER_HEIGHT }} data-testid="payForSpins" onClick={() => setPaysForSpins(true)}>
           Pay {dollars(Catalog.spinPrice)} for more spins
        </button>
      )
    }
    return (
      <SlideToSpin
        label={game.lostLast ? 'Swipe to win it back' : 'Swipe to win'}
        disabled={s.phase !== 'idle'}
        onDrag={game.nudge}
        onAction={(power) => {
          if (game.isLastChance) setConfirmsLastChance(true)
          else void game.pull(power)
        }}
      />
    )
  }
}
