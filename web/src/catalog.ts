/** All product and price data. Edit here. */

export interface Option { label: string; price: number }
export interface Upgrade { name: string; icon: string; price: number; image?: string }
export interface ReelSymbol { text: string; icon?: string }
export interface Product {
  name: string
  storage: Option[]
  /** Every iPad here is Wi‑Fi; an iPhone shows its colour. */
  finish: string
}

/** One device in the order, with everything its games need. */
export interface Device {
  /** "iPad", "iPhone": for copy such as "your last iPhone". */
  kind: string
  /** Cheapest to most expensive. A loss drops you one step down this line. */
  products: Product[]
  /** Index into `products` of what was bought, in its base storage. */
  start: number
  /** Features hands these out one by one, in this order. It never changes the product upward. */
  upgrades: Upgrade[]
  /** Index of Pro Storage in `upgrades`: holding it gives the product its largest storage. */
  proStorage?: number
  /** The products the Products board can land on. Each round shows the ones you don't already have, plus Nothing. */
  board: number[]
}

const o = (label: string, price: number): Option => ({ label, price })
const p = (name: string, storage: Option[], finish = 'Wi‑Fi'): Product => ({ name, storage, finish })

const airPods: Upgrade = { name: 'AirPods Pro 4', icon: '/icons/airpods-case.svg', price: 249, image: 'airpods-pro' }

export const iPad: Device = {
  kind: 'iPad',
  products: [
    p('iPad', [o('128GB', 449), o('256GB', 549), o('512GB', 749)]),
    p('iPad mini', [o('128GB', 599), o('256GB', 699), o('512GB', 899)]),
    p('iPad Air 11″', [o('128GB', 749), o('256GB', 849), o('512GB', 1049), o('1TB', 1349)]),
    p('iPad Air 13″', [o('128GB', 949), o('256GB', 1049), o('512GB', 1249), o('1TB', 1549)]),
    p('iPad Pro 11″', [o('256GB', 1199), o('512GB', 1399), o('1TB', 1799), o('2TB', 2299)]),
    p('iPad Pro 13″', [o('256GB', 1499), o('512GB', 1699), o('1TB', 2099), o('2TB', 2599)]),
  ],
  // What the user bought: iPad Air 11″, 128GB, Wi‑Fi.
  start: 2,
  upgrades: [
    { name: 'Apple Pencil', icon: '/icons/pencil.svg', price: 129, image: 'apple-pencil' },
    { name: 'Magic Keyboard', icon: '/icons/keyboard.svg', price: 269, image: 'magic-keyboard' },
    { name: 'Pro Storage', icon: '/icons/internaldrive.svg', price: 0 }, // priced by the iPad's own storage tiers
    airPods,
  ],
  proStorage: 2,
  // iPad, iPad mini, iPad Air 11″ and iPad Pro 11″.
  board: [0, 1, 2, 4],
}

/** Prices from apple.com (US), October 2026. The finishes match the photos. */
export const iPhone: Device = {
  kind: 'iPhone',
  products: [
    p('iPhone 17e', [o('256GB', 699), o('512GB', 899)], 'Soft Pink'),
    p('iPhone 17', [o('256GB', 899), o('512GB', 1099)], 'Lavender'),
    p('iPhone Air', [o('256GB', 1099), o('512GB', 1299), o('1TB', 1699)], 'Sky Blue'),
    p('iPhone 18 Pro', [o('256GB', 1199), o('512GB', 1399), o('1TB', 1799), o('2TB', 2399)], 'Burgundy'),
    p('iPhone 18 Pro Max', [o('256GB', 1299), o('512GB', 1499), o('1TB', 1899), o('2TB', 2499)], 'Silver'),
  ],
  // What the user bought: iPhone Air, 256GB, Sky Blue.
  start: 2,
  upgrades: [
    { name: 'MagSafe Charger', icon: '/icons/magsafe.svg', price: 39, image: 'magsafe-charger' },
    { name: 'Silicone Case', icon: '/icons/iphone-case.svg', price: 49, image: 'silicone-case' },
    { name: 'AppleCare+', icon: '/icons/checkmark-shield.svg', price: 199 },
    airPods,
  ],
  board: [0, 1, 2, 3, 4],
}

/** The order holds both; iChance is played with one of them. */
export const devices = [iPad, iPhone]

/** What the user paid for the device itself. */
export const paid = (d: Device) => d.products[d.start].storage[0].price

/** Icons only, one per upgrade. A jackpot shows the one you win three times. */
export const featureSymbols = (d: Device): ReelSymbol[] => d.upgrades.map((u) => ({ text: u.name, icon: u.icon }))

/** Every this many pulls, more spins have to be bought. */
export const spinsPerPayment = 4
export const spinPrice = 50
/** Products: the first drop is free, then 50, 100, 150… */
export const dropPriceStep = 50

/** Asset image: "iPad Air 11″" → "ipad-air-11". */
export const productImage = (product: Product) => `/images/${product.name.toLowerCase().replaceAll(' ', '-').replaceAll('″', '')}.png`
export const upgradeImage = (u: Upgrade) => (u.image ? `/images/${u.image}.png` : undefined)

/** "128GB · Wi‑Fi", "256GB · Lavender". */
export const describe = (product: Product, storage: Option) => `${storage.label} · ${product.finish}`
