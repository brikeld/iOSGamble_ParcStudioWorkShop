import { Fragment } from 'react'
import { Symbol } from './Symbol'
import type { ReactNode } from 'react'
import * as Catalog from './catalog'
import type { Upgrade } from './catalog'
import { useGame } from './context'
import { dollars, profitColor, profitText } from './money'
import { useStore } from './store'
import type { Game, Mode } from './game'

/**
 * A product: its picture in a fixed-size slot (so text lines up across rows whatever the photo's shape),
 * then its name, configuration, any extra `details` lines and an optional `footer`.
 */
export function ProductRow({ name, image, imageHeight = 66, configuration, details = [], muted = true, footer }: {
  name: string
  image: string
  /** Picture height in px; the slot it sits in stays the same width, so text still lines up. */
  imageHeight?: number
  configuration: string
  details?: string[]
  /** Greys the configuration line. */
  muted?: boolean
  footer?: ReactNode
}) {
  return (
    <div className="row product-info">
      <span className="thumb"><img src={image} alt="" height={imageHeight} /></span>
      <div className="stack product-text">
        <strong>{name}</strong>
        <span className={muted ? 'secondary' : undefined}>{configuration}</span>
        {details.map((line) => <span key={line}>{line}</span>)}
        {footer}
      </div>
    </div>
  )
}

/** An accessory you've won: its photo, or its symbol when there's no photo, laid out like `ProductRow`. */
export function UpgradeRow({ upgrade }: { upgrade: Upgrade }) {
  const image = Catalog.upgradeImage(upgrade)
  return (
    <div className="row product-info">
      {image ? <span className="thumb"><img src={image} alt="" height={46} /></span> : <Symbol className="row-icon" icon={upgrade.icon} />}
      <strong className="row-name">{upgrade.name}</strong>
    </div>
  )
}

/** Apple Store-style order confirmation, with the iChance offer underneath. */
export function OrderView({ onTry }: { onTry: () => void }) {
  const delivers = new Date(Date.now() + 2 * 86_400_000).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' })
  return (
    <div className="page order-page">
      <section className="plain">
        <div className="confirmation">
          <h2 className="thanks"><span className="seal" aria-hidden="true" /> Thank you for your order</h2>
          <p className="body">Your order will be delivered by courier. Someone must be present to receive your items.</p>
        </div>
        <div className="order-meta">
          <p>Order Number: <u>W730583904</u></p>
          <p>Ordered on: {new Date().toLocaleDateString('en-US')}</p>
        </div>
      </section>

      <section className="card-list product-list">
        {Catalog.devices.map((device, index) => {
          const product = device.products[device.start]
          return (
            <Fragment key={device.kind}>
              {index > 0 && <hr />}
              <ProductRow
                name={product.name}
                image={Catalog.productImage(product)}
                configuration={Catalog.describe(product, product.storage[0])}
                details={[`Paid · Delivers ${delivers}`]}
                muted={false}
                footer={<><hr /><div className="between"><span>Qty: 1</span><span>{dollars(Catalog.paid(device))}</span></div></>}
              />
            </Fragment>
          )
        })}
      </section>

      <section className="card-list dark offer">
        <span className="new">NEW</span>
        <div className="offer-copy">
          <h1>Upgrade your devices<br />for free!</h1>
          <p>A secure experience where you have a chance of upgrading your device, completely free.</p>
        </div>
        <button className="prominent offer-button" onClick={onTry}>Try iChance</button>
      </section>
      <p className="legal">Participation is restricted to persons who meet the applicable legal age requirements. Gamble responsibly and within your financial means.</p>
    </div>
  )
}

/** A betting option: icon (an SF Symbol exported as SVG, tinted like the app's accent) and title, a one-line description beneath, and a chevron. */
function ChoiceRow({ icon, title, description, onClick }: { icon: string; title: string; description: string; onClick: () => void }) {
  return (
    <section className="card-list choice-card">
      <button className="choice" onClick={onClick}>
        <span className="choice-main">
          <span className="choice-icon" style={{ maskImage: `url(${icon})`, WebkitMaskImage: `url(${icon})` }} aria-hidden="true" />
          <span className="choice-body">
            <strong>{title}</strong>
            <span className="choice-desc">{description}</span>
          </span>
        </span>
        <svg className="choice-chev" width="8" height="14" viewBox="0 0 8 14" fill="none" aria-hidden="true">
          <path d="M1 1l6 6-6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
    </section>
  )
}

interface ChooseProps {
  /** Index into `Catalog.devices` of the device being played. */
  current: number
  onSelect: (device: number) => void
  onChoose: (mode: Mode) => void
}

export function ChooseGameView({ current, onSelect, onChoose }: ChooseProps) {
  const game = useGame()
  const s = useStore(game)
  const { kind } = game.device
  return (
    <div className="page choose-page">
      <section className="card-list dark choose-intro">
        <h1 className="large">iChance</h1>
        <p className="footnote">Try your luck at upgrading your {kind}’s technical configuration, or swap your product for another league altogether.</p>
      </section>

      {/* Which of the two ordered devices to play with. Each keeps its own game, so switching loses nothing. */}
      <div className="segmented" role="tablist">
        {Catalog.devices.map((device, i) => (
          <button key={device.kind} role="tab" aria-selected={i === current} className={i === current ? 'selected' : ''} onClick={() => onSelect(i)}>
            {device.products[device.start].name}
          </button>
        ))}
      </div>

      {/* What you'd receive right now, kept up to date as you win and lose. */}
      <h3 className="header">Your Product</h3>
      <section className="card-list product-list">
        {s.phase === 'nothing' ? (
          <div className="row">📦 Nothing</div>
        ) : (
          <>
            <ProductRow name={game.product.name} image={Catalog.productImage(game.product)} imageHeight={46} configuration={game.configuration} />
            {/* Only the accessories that come in a box: Pro Storage and AppleCare+ aren't. */}
            {game.held.filter((u) => u.image).map((u) => <UpgradeRow key={u.name} upgrade={u} />)}
          </>
        )}
      </section>

      <h3 className="header">Betting Options</h3>
      <div className="choice-group">
        <ChoiceRow icon="/icons/features.svg" title="Features" description={`Max out your ${kind}’s technical configuration and experience.`} onClick={() => onChoose('features')} />
        <ChoiceRow icon="/icons/products.svg" title="Products" description="Upgrade your product to another tier." onClick={() => onChoose('product')} />
      </div>
    </div>
  )
}

/** What each device's game ends with, then the whole order's money: both devices added together. */
export function SummaryView({ games, onDone }: { games: Game[]; onDone: () => void }) {
  const sum = (f: (g: Game) => number) => games.reduce((total, g) => total + f(g), 0)
  const profit = sum((g) => g.profit)
  return (
    <div className="summary">
      <header className="bar">
        <h2>Summary</h2>
        <button className="link" onClick={onDone}>Done</button>
      </header>
      {games.map((game) => (
        <div key={game.device.kind} className="summary-device">
          <h3 className="header">Your {game.device.kind}</h3>
          <section className="card-list product-list">
            {game.s.phase === 'nothing' ? (
              <div className="row">📦 Nothing</div>
            ) : (
              <>
                <ProductRow name={game.product.name} image={Catalog.productImage(game.product)} configuration={game.configuration} />
                {game.held.map((u) => <UpgradeRow key={u.name} upgrade={u} />)}
              </>
            )}
          </section>
        </div>
      ))}
      <section className="card-list">
        <div className="between"><span>Paid</span><span>{dollars(sum((g) => g.paid))}</span></div>
        {sum((g) => g.s.fees) > 0 && <div className="between"><span>Extra spins</span><span>{dollars(sum((g) => g.s.fees))}</span></div>}
        <div className="between"><span>Value</span><span>{dollars(sum((g) => g.value))}</span></div>
        <div className="between"><span>Profit or Loss</span><span style={{ color: profitColor(profit) }}>{profitText(profit)}</span></div>
        {/* Slot spins and ball drops, on both devices. */}
        <div className="between"><span>Bets</span><span>{sum((g) => g.s.spins + g.s.drops).toLocaleString('en-US')}</span></div>
      </section>
    </div>
  )
}
