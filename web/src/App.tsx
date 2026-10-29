import { useState } from 'react'
import { GameContext } from './context'
import { Game } from './game'
import { GameView } from './GameView'
import { ChooseGameView, OrderView, SummaryView } from './Screens'
import { Sheet } from './Sheet'
import { useStore } from './store'

type Screen = 'order' | 'choose' | 'game'

export function App() {
  const [game, setGame] = useState(() => new Game())
  const [screen, setScreen] = useState<Screen>('order')
  const s = useStore(game)

  return (
    <GameContext.Provider value={game}>
      <div className="app">
        {screen === 'order' && <OrderView onTry={() => setScreen('choose')} />}
        {screen === 'choose' && (
          <>
            <header className="bar"><button className="link" onClick={() => setScreen('order')}>‹ Back</button></header>
            <ChooseGameView onChoose={(mode) => { game.play(mode); setScreen('game') }} />
          </>
        )}
        {screen === 'game' && <GameView onBack={() => setScreen('choose')} />}

        {/* The summary can only be closed with Done, which ends the session. */}
        {s.showsSummary && (
          <Sheet tall>
            <SummaryView onDone={() => { setGame(new Game()); setScreen('order') }} />
          </Sheet>
        )}
      </div>
    </GameContext.Provider>
  )
}
