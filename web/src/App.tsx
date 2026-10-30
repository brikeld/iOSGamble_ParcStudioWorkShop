import { useCallback, useState } from 'react'
import { BackButton } from './BackButton'
import { devices } from './catalog'
import { GameContext } from './context'
import { Game } from './game'
import { FaceIDIntro } from './FaceIDIntro'
import { GameView } from './GameView'
import { ChooseGameView, OrderView } from './Screens'
import { SummaryView } from './SummaryView'
import { Sheet } from './Sheet'
import { useStore } from './store'

type Screen = 'order' | 'choose' | 'game'

const newGames = () => devices.map((device) => new Game(device))

export function App() {
  // One game per ordered device, each keeping its own progress; `current` is the one being played.
  const [games, setGames] = useState(newGames)
  const [current, setCurrent] = useState(0)
  const [screen, setScreen] = useState<Screen>('order')
  // Face ID and the payment chime play before the order confirmation is shown: it appears as the intro fades out.
  const [verified, setVerified] = useState(false)
  const [introGone, setIntroGone] = useState(false)
  const finishVerifying = useCallback(() => setVerified(true), [])
  const removeIntro = useCallback(() => setIntroGone(true), [])
  const game = games[current]
  const s = useStore(game)

  return (
    <GameContext.Provider value={game}>
      <div className="app">
        {!introGone && <FaceIDIntro onVerified={finishVerifying} onDone={removeIntro} />}
        {verified && screen === 'order' && <OrderView onTry={() => setScreen('choose')} />}
        {screen === 'choose' && (
          <>
            <header className="bar"><BackButton onClick={() => setScreen('order')} /></header>
            <ChooseGameView current={current} onSelect={setCurrent} onChoose={(mode) => { game.play(mode); setScreen('game') }} />
          </>
        )}
        {screen === 'game' && <GameView key={current} onBack={() => setScreen('choose')} />}

        {/* The summary can only be closed with Done, which ends the session. */}
        {s.showsSummary && (
          <Sheet tall>
            <SummaryView
              games={games}
              onClose={() => game.showSummary(false)}
              onDone={() => { setGames(newGames()); setCurrent(0); setScreen('order') }}
            />
          </Sheet>
        )}
      </div>
    </GameContext.Provider>
  )
}
