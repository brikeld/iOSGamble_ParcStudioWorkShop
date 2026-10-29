import { useEffect, useRef, useState } from 'react'
import { FaceIDAnimation, frameRate } from './faceIDAnimation'
import { sleep } from './store'
import { Sound, haptic, prepare } from './sounds'

type Step = 'hidden' | 'glyph' | 'detecting' | 'done' | 'leave'

// At 60 fps, frame 27 is where the green dots start and frame 76 is where the checkmark appears.
const firstFrame = 27
const tickAppears = 76
const lastFrame = 118 // the checkmark fully drawn, before it fades out
const animationSize = { width: 220, height: 185 }

/**
 * The Face ID sequence that opens the app, as in the iOS app's FaceIDIntroView: the Face ID glyph appears,
 * turns into the green "detecting" animation and finishes on its checkmark with the Apple Pay chime, then
 * the order confirmation is revealed. Like the Apple Pay sheet, it's a recreation: nothing is authenticated.
 */
export function FaceIDIntro({ onVerified, onDone }: { onVerified: () => void; onDone: () => void }) {
  const [step, setStep] = useState<Step>('hidden')
  const canvas = useRef<HTMLCanvasElement>(null)
  const animation = useRef<Promise<FaceIDAnimation>>(undefined)
  animation.current ??= FaceIDAnimation.load('/face-id-detecting.json') // parsed while nothing is moving

  useEffect(() => {
    let cancelled = false
    prepare() // the chime only sounds if the browser already allows audio; the first tap also unlocks it
    void (async () => {
      await sleep(0.3)
      if (cancelled) return
      setStep('glyph')
      await sleep(1.2) // the glyph, before it turns into the detecting animation
      if (cancelled) return
      setStep('detecting')
      await sleep((tickAppears - firstFrame) / frameRate)
      if (cancelled) return
      setStep('done')
      Sound.win() // the Apple Pay success chime, as the checkmark appears
      haptic.success()
      await sleep((lastFrame - tickAppears) / frameRate + 0.8)
      if (cancelled) return
      setStep('leave') // the order confirmation shows through as this fades away
      onVerified()
      await sleep(0.5)
      if (!cancelled) onDone()
    })()
    return () => { cancelled = true }
  }, [onVerified, onDone])

  // The animation plays once from its first frame when detecting begins, and holds on the last.
  const playing = step === 'detecting' || step === 'done' || step === 'leave'
  useEffect(() => {
    const el = canvas.current
    if (!playing || !el) return
    let frame = 0, stopped = false
    const dpr = window.devicePixelRatio || 1
    el.width = animationSize.width * dpr
    el.height = animationSize.height * dpr
    const ctx = el.getContext('2d')
    void animation.current?.then((anim) => {
      if (stopped || !ctx) return
      const started = performance.now()
      const tick = (now: number) => {
        const at = Math.min(firstFrame + ((now - started) / 1000) * frameRate, lastFrame)
        anim.draw(at, ctx, animationSize.width, animationSize.height, dpr)
        if (at < lastFrame) frame = requestAnimationFrame(tick)
      }
      frame = requestAnimationFrame(tick)
    })
    return () => { stopped = true; cancelAnimationFrame(frame) }
  }, [playing])

  const verified = step === 'done' || step === 'leave'
  return (
    <div className={`faceid ${step}`} role="status" aria-label={verified ? 'Face ID verified' : 'Face ID'}>
      <div className="faceid-hud">
        <div className="faceid-art">
          {step !== 'hidden' && <span className={`faceid-glyph ${playing ? 'gone' : ''}`} aria-hidden="true" />}
          <canvas ref={canvas} className={`faceid-detecting ${playing ? 'shown' : ''}`} style={animationSize} aria-hidden="true" />
        </div>
        <span className="faceid-label">{verified ? 'Done' : 'Face ID'}</span>
      </div>
    </div>
  )
}
