import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from './App'
import { selfCheck } from './game'
import './styles.css'

if (import.meta.env.DEV) {
  const failures = selfCheck()
  if (failures.length) console.error('Game rules broke:', failures)
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
