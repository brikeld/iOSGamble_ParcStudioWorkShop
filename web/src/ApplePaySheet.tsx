import { useState } from 'react'
import { Sheet } from './Sheet'
import { dollars } from './money'
import { sleep } from './store'
import { Sound, haptic } from './sounds'

type Step = 'ready' | 'faceID' | 'done'

interface Props {
  amount: number
  onPaid: () => void
  onClose: () => void
}

/**
 * A recreation of the Apple Pay sheet with a fictional card. Nothing is charged.
 * Double-tap (or double-click, or Enter) stands in for double-clicking the side button.
 */
export function ApplePaySheet({ amount, onPaid, onClose }: Props) {
  const [step, setStep] = useState<Step>('ready')

  const pay = async () => {
    if (step !== 'ready') return
    setStep('faceID')
    await sleep(1)
    setStep('done')
    Sound.win() // the Apple Pay success chime
    haptic.success()
    await sleep(1)
    onPaid()
    onClose()
  }

  return (
    <Sheet onBackdrop={step === 'ready' ? onClose : undefined}>
      <div
        className="pay"
        tabIndex={0}
        role="dialog"
        aria-label={`Apple Pay, ${dollars(amount)}`}
        onDoubleClick={pay}
        onKeyDown={(e) => { if (e.key === 'Enter') void pay() }}
      >
        <div className="pay-head">
          <span className="pay-word"> Pay</span>
          <button className="round" aria-label="Cancel" disabled={step !== 'ready'} onClick={onClose}>✕</button>
        </div>
        <div className="pay-card">
          <div className="card-art"><span>PARC</span></div>
          <div className="card-text">
            <strong>Parc Card</strong>
            <span>•••• 2026</span>
          </div>
          <span className="chev">›</span>
        </div>
        <hr />
        <div className="pay-total">
          <span>Pay iChance</span>
          <strong>{dollars(amount)}</strong>
        </div>
        <div className="pay-confirm">
          {step === 'ready' && <><div className="pay-icon pulse">⏻</div>Double-Tap to Pay</>}
          {step === 'faceID' && <><div className="pay-icon pulse">🙂</div>Face ID</>}
          {step === 'done' && <><div className="pay-icon done">✓</div>Done</>}
        </div>
      </div>
    </Sheet>
  )
}
