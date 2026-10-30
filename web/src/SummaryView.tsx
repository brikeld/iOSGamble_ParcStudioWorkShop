import { useState, type ReactNode } from 'react'
import * as Catalog from './catalog'
import type { Upgrade } from './catalog'
import type { Game } from './game'
import { dollars, profitText } from './money'
import { Symbol } from './Symbol'

type Result = 'won' | 'lost' | undefined

/** Upgraded, downgraded, lost or kept, and the money it made or cost: the words, symbol and colour for one device. */
interface Change { word: string; symbol: 'up' | 'down' | 'plus' | 'equal'; outcome: Result; delta: number }

const outcomeOf = (delta: number): Result => (delta > 0 ? 'won' : delta < 0 ? 'lost' : undefined)

function changeOf(game: Game): Change {
  const delta = game.value - game.paid
  const start = game.device.start
  const { phase, productIndex, upgrades } = game.s
  if (phase === 'nothing') return { word: 'Lost', symbol: 'down', outcome: 'lost', delta }
  if (productIndex > start) return { word: 'Upgraded', symbol: 'up', outcome: 'won', delta }
  if (productIndex < start) return { word: 'Downgraded', symbol: 'down', outcome: 'lost', delta }
  if (upgrades > 0) return { word: `Same ${game.device.kind}, more inside`, symbol: 'plus', outcome: 'won', delta }
  return { word: 'Unchanged', symbol: 'equal', outcome: undefined, delta }
}

/**
 * What each device's game ends with, then the whole order's money: both devices added together.
 * Each device shows what was ordered, faded, above what you'll receive, joined by what changed.
 * As in the iOS app's SummaryView.
 */
export function SummaryView({ games, onClose, onDone }: { games: Game[]; onClose: () => void; onDone: () => void }) {
  // The money card shows only the profit or loss until it's tapped open.
  const [showsDetails, setShowsDetails] = useState(false)
  const sum = (f: (g: Game) => number) => games.reduce((total, g) => total + f(g), 0)
  const paid = sum((g) => g.paid), fees = sum((g) => g.s.fees), value = sum((g) => g.value), profit = sum((g) => g.profit)
  const bets = sum((g) => g.s.spins + g.s.drops)

  return (
    <div className="summary">
      <header className="sum-bar">
        <button className="glass-circle" aria-label="Close" onClick={onClose}>
          <svg width="11" height="11" viewBox="0 0 11 11" fill="none" aria-hidden="true">
            <path d="M1 1l9 9M10 1l-9 9" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
        </button>
        <button className="glass-pill" onClick={onDone}>Done</button>
      </header>
      <h1 className="sum-title">Summary</h1>
      <div className="sum-content">
        {games.map((game) => (
          <div key={game.device.kind} className="sum-device">
            <h3 className="sum-header">Your {game.device.kind}</h3>
            <DeviceResult game={game} />
          </div>
        ))}
        <section className="sum-card sum-money">
          <button className="sum-profit" aria-expanded={showsDetails} onClick={() => setShowsDetails(!showsDetails)}>
            <span>{profit > 0 ? 'Profit' : profit < 0 ? 'Loss' : 'Break Even'}</span>
            <span className="sum-profit-value" style={{ color: outcomeColor(outcomeOf(profit)) }}>{profitText(profit)}</span>
            <svg className={`sum-chev ${showsDetails ? 'open' : ''}`} width="7" height="12" viewBox="0 0 8 14" fill="none" aria-hidden="true">
              <path d="M1 1l6 6-6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
          <div className={`sum-details ${showsDetails ? 'open' : ''}`}>
            <div>
              <Total label="Paid" value={dollars(paid)} />
              {fees > 0 && <Total label="Extra spins" value={dollars(fees)} />}
              <Total label="Value" value={dollars(value)} />
              {/* Slot spins and ball drops, on both devices. */}
              <Total label="Bets" value={bets.toLocaleString('en-US')} />
            </div>
          </div>
        </section>
      </div>
    </div>
  )
}

const outcomeColor = (outcome: Result) => (outcome === 'won' ? 'var(--won)' : outcome === 'lost' ? 'var(--lost)' : 'var(--secondary)')

function Total({ label, value }: { label: string; value: string }) {
  return (
    <>
      <hr className="sum-rule" />
      <div className="sum-total"><span>{label}</span><span>{value}</span></div>
    </>
  )
}

/**
 * One device: the ordered product faded with its price struck through, a short coloured line with what changed,
 * then what you'll receive and the accessories won. Outlined in the result's colour, like the Your Product card.
 */
function DeviceResult({ game }: { game: Game }) {
  const change = changeOf(game)
  const ordered = game.device.products[game.device.start]
  return (
    <div className={`sum-card sum-result ${change.outcome ?? ''}`}>
      <Row image={Catalog.productImage(ordered)} title={ordered.name} subtitle={`Ordered · ${Catalog.describe(ordered, ordered.storage[0])}`} faded>
        <s>{dollars(game.paid)}</s>
      </Row>
      <div className="sum-change">
        <span className={`sum-bar-line ${change.outcome ?? ''}`} />
        <Chip outcome={change.outcome}><Arrow kind={change.symbol} />{change.word}</Chip>
        <Chip outcome={outcomeOf(change.delta)}>{profitText(change.delta)}</Chip>
      </div>
      {game.s.phase === 'nothing' ? (
        <Row symbol={<BoxIcon />} title="Nothing" subtitle="Won’t be delivered" />
      ) : (
        <>
          <Row image={Catalog.productImage(game.product)} title={game.product.name} subtitle={game.configuration}>
            {dollars(game.storage.price)}
          </Row>
          {game.held.map((upgrade, i) => (
            <div key={upgrade.name}>
              <hr className="sum-rule inset" />
              <Accessory game={game} upgrade={upgrade} index={i} />
            </div>
          ))}
        </>
      )}
    </div>
  )
}

/** Pro Storage is already in the configuration and its price above, so it isn't counted again. */
function Accessory({ game, upgrade, index }: { game: Game; upgrade: Upgrade; index: number }) {
  const included = index === game.device.proStorage
  const price = (
    <span className={included ? '' : 'won-text'}>{included ? 'Included' : '+' + dollars(game.priceOfUpgrade(index))}</span>
  )
  const image = Catalog.upgradeImage(upgrade)
  return image
    ? <Row image={image} title={upgrade.name} small>{price}</Row>
    : <Row symbol={<Symbol icon={upgrade.icon} className="sum-symbol" />} title={upgrade.name}>{price}</Row>
}

function Row({ image, symbol, title, subtitle, small, faded, children }: {
  image?: string
  symbol?: ReactNode
  title: string
  subtitle?: string
  small?: boolean
  faded?: boolean
  children?: ReactNode
}) {
  return (
    <div className={`sum-row ${faded ? 'faded' : ''}`}>
      <span className="sum-thumb">
        {image ? <img src={image} alt="" style={small ? { maxWidth: 36, maxHeight: 36 } : undefined} /> : symbol}
      </span>
      <span className="sum-text">
        <strong>{title}</strong>
        {subtitle && <span>{subtitle}</span>}
      </span>
      <span className="sum-trailing">{children}</span>
    </div>
  )
}

function Chip({ outcome, children }: { outcome: Result; children: ReactNode }) {
  return <span className={`sum-chip ${outcome ?? ''}`}>{children}</span>
}

/** The change's arrow, plus or equals sign. */
function Arrow({ kind }: { kind: Change['symbol'] }) {
  const d = { up: 'M5 9V1M1.5 4.5L5 1l3.5 3.5', down: 'M5 1v8M1.5 5.5L5 9l3.5-3.5', plus: 'M5 1v8M1 5h8', equal: 'M1 3h8M1 7h8' }[kind]
  return (
    <svg width="10" height="10" viewBox="0 0 10 10" fill="none" aria-hidden="true">
      <path d={d} stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

/** shippingbox */
function BoxIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" aria-hidden="true">
      <path d="M3 8l9-5 9 5v8l-9 5-9-5V8zM3 8l9 5 9-5M12 13v8M7.5 5.5l9 5" />
    </svg>
  )
}
