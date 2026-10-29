import { useState } from 'react'
import { Sheet } from './Sheet'
import { dollars } from './money'
import { sleep } from './store'
import { Sound, haptic } from './sounds'

type Step = 'ready' | 'faceID' | 'done'

/** The symbols' drawn sizes: 0.34 of their SVG units, which is how SF Symbols sit at the large-title size. */
const glyphSize = { 'side-button': [120.737, 119.242], faceid: [95.5544, 95.7001], done: [99.5986, 99.6092] } as const

function Glyph({ icon, className }: { icon: keyof typeof glyphSize; className: string }) {
  const [w, h] = glyphSize[icon]
  const url = `url(/icons/${icon}.svg)`
  return <span className={`pay-icon ${className}`} style={{ width: w * 0.34, height: h * 0.34, maskImage: url, WebkitMaskImage: url }} aria-hidden="true" />
}

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
    <Sheet floating onBackdrop={step === 'ready' ? onClose : undefined}>
      <div
        className="pay"
        tabIndex={0}
        role="dialog"
        aria-label={`Apple Pay, ${dollars(amount)}`}
        onDoubleClick={pay}
        onKeyDown={(e) => { if (e.key === 'Enter') void pay() }}
      >
        <div className="pay-head">
          {/* The logo is a glyph of the SF Pro font, set tight against the word like the wordmark. */}
          <span className="pay-word" aria-label="Apple Pay"><span aria-hidden="true">{'\uF8FF'}</span>Pay</span>
          <button className="glass-circle pay-close" aria-label="Cancel" disabled={step !== 'ready'} onClick={onClose}>
            <svg width="11" height="11" viewBox="0 0 11 11" fill="none" aria-hidden="true">
              <path d="M1 1l9 9M10 1l-9 9" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
            </svg>
          </button>
        </div>
        <div className="pay-card">
          <div className="card-art"><span>PARC</span></div>
          <div className="card-text">
            <strong>Parc Card</strong>
            <span>•••• 2026</span>
          </div>
          <svg className="pay-chev" width="7" height="12" viewBox="0 0 8 14" fill="none" aria-hidden="true">
            <path d="M1 1l6 6-6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
        <hr />
        <div className="pay-total">
          <span>Pay iChance</span>
          <strong>{dollars(amount)}</strong>
        </div>
        <div className="pay-confirm">
          {step === 'ready' && <><Glyph icon="side-button" className="pulse" />Double-Tap to Pay</>}
          {step === 'faceID' && <><Glyph icon="faceid" className="pulse" />Face ID</>}
          {step === 'done' && <><Glyph icon="done" className="done" />Done</>}
        </div>
      </div>
    </Sheet>
  )
}
