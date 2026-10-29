import { createContext, useContext } from 'react'
import type { Game } from './game'

export const GameContext = createContext<Game | null>(null)

export function useGame(): Game {
  const game = useContext(GameContext)
  if (!game) throw new Error('useGame needs a GameContext')
  return game
}
