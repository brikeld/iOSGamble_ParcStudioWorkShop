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

  it('starts at what was paid', () => {
    const game = new Game()
    expect(game.value).toBe(Catalog.paid)
    expect(game.profit).toBe(0)
  })

  it('never lets a losing stop pattern show three of a kind', () => {
    for (let i = 0; i < 1000; i++) {
      const [, b, c] = Odds.stops(false)
      expect(b !== 0 || c !== 0).toBe(true)
    }
  })

  it('has bin odds that add up to 1', () => {
    const game = new Game()
    game.play('product')
    expect(game.s.odds.reduce((a, b) => a + b, 0)).toBeCloseTo(1)
  })
})

describe('plinko', () => {
  it('lands the ball in the bin it was drawn for', () => {
    const odds = [0.1, 0.2, 0.3, 0.25, 0.15]
    for (let bin = 0; bin < odds.length; bin++) {
      const path = run({ x: Board.width / 2, y: Board.spawnY }, bin, Board.edges(odds))
      expect(path.bin).toBe(bin)
    }
  })
})
