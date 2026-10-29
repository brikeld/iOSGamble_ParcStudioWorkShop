/** An upgrade's icon: an SF Symbol exported as SVG (a path) drawn in the surrounding text colour, or an emoji. */
export function Symbol({ icon, className }: { icon: string; className?: string }) {
  if (!icon.startsWith('/')) return <span className={className}>{icon}</span>
  return (
    <span
      className={`symbol ${className ?? ''}`}
      style={{ maskImage: `url(${icon})`, WebkitMaskImage: `url(${icon})` }}
      aria-hidden="true"
    />
  )
}
