/** The iOS 26 navigation back button: a glass circle holding a chevron. */
export function BackButton({ onClick, disabled }: { onClick: () => void; disabled?: boolean }) {
  return (
    <button className="glass-circle" aria-label="Back" onClick={onClick} disabled={disabled}>
      <svg width="8" height="13" viewBox="0 0 12 20" fill="none" aria-hidden="true">
        <path d="M10 2 2 10l8 8" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    </button>
  )
}
