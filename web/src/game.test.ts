import { describe, expect, it } from 'vitest'
import { Game, selfCheck } from './game'
import * as Catalog from './catalog'
import * as Odds from './odds'
import { Board, run } from './plinko'

describe('rules', () => {
  it('replays the ladders from the brief', () => {
    expect(selfCheck()).toEqual([])
  })

  it('never shows three of a kind on a fresh machine', () => {
    for (let i = 0; i < 200; i++) {
      const game = new Game()
      expect(new Set(game.s.strips.map((s) => s[0])).size).toBeGreaterThan(1)
    }
  })

  it('starts at what was paid, on both devices', () => {
    for (const device of Catalog.devices) {
      const game = new Game(device)
      expect(game.value).toBe(Catalog.paid(device))
      expect(game.profit).toBe(0)
    }
  })

  it('keeps each device in its own game', () => {
    const [pad, phone] = Catalog.devices.map((d) => new Game(d))
    pad.settle(true)
    expect(pad.s.upgrades).toBe(1)
    expect(phone.s.upgrades).toBe(0)
  })

  it('never shows three of a kind on a fresh iPhone machine', () => {
    for (let i = 0; i < 200; i++) {
      expect(new Set(new Game(Catalog.iPhone).s.strips.map((s) => s[0])).size).toBeGreaterThan(1)
    }
  })

  it('never lets a losing stop pattern show three of a kind', () => {
    for (let i = 0; i < 1000; i++) {
      const [, b, c] = Odds.stops(false)
      expect(b !== 0 || c !== 0).toBe(true)
    }
  })

  it('has bin odds that add up to 1', () => {
    for (const device of Catalog.devices) {
      const game = new Game(device)
      game.play('product')
      expect(game.s.odds.reduce((a, b) => a + b, 0)).toBeCloseTo(1)
    }
  })
})

describe('plinko', () => {
  it('gives every bin at least its floor width and fills the board', () => {
    const edges = Board.edges([0.02, 0.18, 0.3, 0.5])
    expect(edges.at(-1)).toBeCloseTo(Board.width)
    for (let i = 1; i < edges.length; i++) expect(edges[i] - edges[i - 1]).toBeGreaterThanOrEqual(30)
  })

  it('lands the ball in the bin it was drawn for', () => {
    const odds = [0.1, 0.2, 0.3, 0.25, 0.15]
    for (let bin = 0; bin < odds.length; bin++) {
      // From well above the board, as when the ball falls in from the top of the window.
      const path = run({ x: Board.width / 2, y: -400 }, bin, Board.edges(odds))
      expect(path.bin).toBe(bin)
    }
  })
})
