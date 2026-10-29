import * as Catalog from './catalog'
import type { Upgrade } from './catalog'
import { useGame } from './context'
import { dollars, profitColor, profitText } from './money'
import { useStore } from './store'
import type { Mode } from './game'

/** The iPad you'll receive: picture, name, configuration. */
export function ProductRow({ name, image, configuration }: { name: string; image: string; configuration: string }) {
  return (
    <div className="row">
      <img src={image} alt="" width={46} height={46} />
      <div className="row-text">
        <strong>{name}</strong>
        <span className="secondary">{configuration}</span>
      </div>
    </div>
  )
}

/** An accessory you've won: its photo, or its symbol when there's no photo, laid out like `ProductRow`. */
export function UpgradeRow({ upgrade }: { upgrade: Upgrade }) {
  const image = Catalog.upgradeImage(upgrade)
  return (
    <div className="row">
      {image ? <img src={image} alt="" width={46} height={46} /> : <span className="row-icon">{upgrade.icon}</span>}
      <strong className="row-name">{upgrade.name}</strong>
    </div>
  )
}

/** Apple Store-style order confirmation, with the iChance offer underneath. */
export function OrderView({ onTry }: { onTry: () => void }) {
  const product = Catalog.products[Catalog.startProduct]
  const delivers = new Date(Date.now() + 2 * 86_400_000).toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short' })
  return (
    <div className="page">
      <section className="plain">
        <h2 className="thanks"><span className="seal">✓</span> Thank you for your order</h2>
        <p className="body">Your order will be delivered by courier. Someone must be present to receive your items.</p>
        <p className="footnote">Order Number: <u className="tint">W730583904</u><br />Ordered on: {new Date().toLocaleDateString('en-US')}</p>
      </section>

      <section className="card-list">
        <div className="row spaced">
          <img src={Catalog.productImage(product)} alt="" width={66} height={66} />
          <div className="footnote stack">
            <strong>{product.name}</strong>
            <span>{Catalog.describe(product.storage[0])}</span>
            <span>Paid · Delivers {delivers}</span>
            <hr />
            <div className="between"><span>Qty: 1</span><span>{dollars(Catalog.paid)}</span></div>
          </div>
        </div>
      </section>

      <section className="card-list dark offer">
        <span className="new">NEW</span>
        <h1>Upgrade your iPad Air for free!</h1>
        <p>A secure experience where you have a chance of upgrading your device, completely free.</p>
        <button className="prominent" onClick={onTry}>Try iChance</button>
      </section>
      <p className="legal">Participation is restricted to persons who meet the applicable legal age requirements. Gamble responsibly and within your financial means.</p>
    </div>
  )
}

export function ChooseGameView({ onChoose }: { onChoose: (mode: Mode) => void }) {
  const game = useGame()
  const s = useStore(game)
  return (
    <div className="page">
      <section className="card-list dark">
        <h1 className="large">iChance</h1>
        <p className="footnote">Try your luck at upgrading your iPad’s technical configuration, or swap your product for another league altogether.</p>
      </section>

      {/* What you'd receive right now, kept up to date as you win and lose. */}
      <h3 className="header">Your Product</h3>
      <section className="card-list">
        {s.phase === 'nothing' ? (
          <div className="row">📦 Nothing</div>
        ) : (
          <>
            <ProductRow name={game.product.name} image={Catalog.productImage(game.product)} configuration={game.configuration} />
            {/* Only the accessories that come in a box; Pro Storage and Nano Texture are part of the iPad. */}
            {game.held.filter((u) => u.image).map((u) => <UpgradeRow key={u.name} upgrade={u} />)}
          </>
        )}
      </section>

      <h3 className="header">Betting Options</h3>
      <section className="card-list">
        <button className="choice" onClick={() => onChoose('features')}>
          <span className="choice-icon">🎰</span>
          <span><strong>Features</strong><span className="footnote block">Max out your iPad’s technical configuration and experience.</span></span>
          <span className="chev">›</span>
        </button>
      </section>
      <section className="card-list">
        <button className="choice" onClick={() => onChoose('product')}>
          <span className="choice-icon">🔀</span>
          <span><strong>Products</strong><span className="footnote block">Upgrade your product to another tier.</span></span>
          <span className="chev">›</span>
        </button>
      </section>
    </div>
  )
}

export function SummaryView({ onDone }: { onDone: () => void }) {
  const game = useGame()
  const s = useStore(game)
  return (
    <div className="summary">
      <header className="bar">
        <h2>Summary</h2>
        <button className="link" onClick={onDone}>Done</button>
      </header>
      <h3 className="header">You’ll Receive</h3>
      <section className="card-list">
        {s.phase === 'nothing' ? (
          <div className="row">📦 Nothing</div>
        ) : (
          <>
            <ProductRow name={game.product.name} image={Catalog.productImage(game.product)} configuration={game.configuration} />
            {game.held.map((u) => <UpgradeRow key={u.name} upgrade={u} />)}
          </>
        )}
      </section>
      <section className="card-list">
        <div className="between"><span>Paid</span><span>{dollars(Catalog.paid)}</span></div>
        {s.fees > 0 && <div className="between"><span>Extra spins</span><span>{dollars(s.fees)}</span></div>}
        <div className="between"><span>Value</span><span>{dollars(game.value)}</span></div>
        <div className="between"><span>Profit or Loss</span><span style={{ color: profitColor(game.profit) }}>{profitText(game.profit)}</span></div>
        <div className="between"><span>Spins</span><span>{s.spins.toLocaleString('en-US')}</span></div>
      </section>
    </div>
  )
}
