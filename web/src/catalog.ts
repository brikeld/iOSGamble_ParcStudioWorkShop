/** All product and price data. Edit here. */

export interface Option { label: string; price: number }
export interface Upgrade { name: string; icon: string; price: number; image?: string }
export interface ReelSymbol { text: string; icon?: string }
export interface Product { name: string; storage: Option[] }

const o = (label: string, price: number): Option => ({ label, price })

/** Cheapest to most expensive. A loss drops you one step down this line. */
export const products: Product[] = [
  { name: 'iPad', storage: [o('128GB', 449), o('256GB', 549), o('512GB', 749)] },
  { name: 'iPad mini', storage: [o('128GB', 599), o('256GB', 699), o('512GB', 899)] },
  { name: 'iPad Air 11″', storage: [o('128GB', 749), o('256GB', 849), o('512GB', 1049), o('1TB', 1349)] },
  { name: 'iPad Air 13″', storage: [o('128GB', 949), o('256GB', 1049), o('512GB', 1249), o('1TB', 1549)] },
  { name: 'iPad Pro 11″', storage: [o('256GB', 1199), o('512GB', 1399), o('1TB', 1799), o('2TB', 2299)] },
  { name: 'iPad Pro 13″', storage: [o('256GB', 1499), o('512GB', 1699), o('1TB', 2099), o('2TB', 2599)] },
]

/** What the user just bought: iPad Air 11″, 128GB, Wi‑Fi. */
export const startProduct = 2
export const paid = 749

/** Every this many pulls, more spins have to be bought. */
export const spinsPerPayment = 4
export const spinPrice = 50
/** Product Tier: the first drop is free, then 50, 100, 150… */
export const dropPriceStep = 50
/** The iPads the Products board can land on. Each round shows the ones you don't already have, plus Nothing. */
export const boardProducts = [0, 1, 2, 4, 5]

/** Features hands these out one by one, in this order. Holding all of them, the next win is the iPad above. */
export const upgrades: Upgrade[] = [
  { name: 'Apple Pencil', icon: '✏️', price: 129, image: 'apple-pencil' },
  { name: 'Magic Keyboard', icon: '⌨️', price: 269, image: 'magic-keyboard' },
  { name: 'Pro Storage', icon: '💾', price: 0 }, // priced by the iPad's own storage tiers
  { name: 'Nano Texture', icon: '🔆', price: 300 },
  { name: 'AirPods Pro 4', icon: '🎧', price: 249, image: 'airpods-pro' },
]
/** Index of Pro Storage in `upgrades`: holding it gives the iPad its largest storage. */
export const proStorage = 2

/** Icons only: every upgrade, then the next iPad. A jackpot shows the one you win three times. */
export const featureSymbols: ReelSymbol[] = [
  ...upgrades.map((u) => ({ text: u.name, icon: u.icon })),
  { text: 'Next iPad', icon: '📱' },
]

/** Asset image: "iPad Air 11″" → "ipad-air-11". */
export const productImage = (p: Product) => `/images/${p.name.toLowerCase().replaceAll(' ', '-').replaceAll('″', '')}.png`
export const upgradeImage = (u: Upgrade) => (u.image ? `/images/${u.image}.png` : undefined)

/** "128GB · Wi‑Fi". Every iPad here is Wi‑Fi. */
export const describe = (storage: Option) => `${storage.label} · Wi‑Fi`
