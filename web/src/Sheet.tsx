import type { ReactNode } from 'react'

interface Props {
  children: ReactNode
  /** Tapping outside closes the sheet; leave undefined to make it undismissable. */
  onBackdrop?: () => void
  /** Fills the screen, like a full-height page sheet. */
  tall?: boolean
}

/** A bottom sheet over a dimmed backdrop. */
export function Sheet({ children, onBackdrop, tall }: Props) {
  return (
    <div className="backdrop" onClick={onBackdrop}>
      <div className={`sheet ${tall ? 'tall' : ''}`} onClick={(e) => e.stopPropagation()}>{children}</div>
    </div>
  )
}

interface AlertProps {
  title: string
  message: string
  confirm: string
  onConfirm: () => void
  onCancel: () => void
}

/** A destructive confirmation, like the system alert. */
export function Alert({ title, message, confirm, onConfirm, onCancel }: AlertProps) {
  return (
    <div className="backdrop center" role="alertdialog" aria-label={title}>
      <div className="alert">
        <h3>{title}</h3>
        <p>{message}</p>
        <div className="alert-actions">
          <button onClick={onCancel}>Cancel</button>
          <button className="destructive" onClick={onConfirm}>{confirm}</button>
        </div>
      </div>
    </div>
  )
}
