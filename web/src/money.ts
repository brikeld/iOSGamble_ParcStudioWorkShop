export const dollars = (n: number) => '$' + Math.round(n).toLocaleString('en-US')

export const profitText = (profit: number) =>
  profit === 0 ? dollars(0) : (profit > 0 ? '+' : '−') + dollars(Math.abs(profit))

export const profitColor = (profit: number) =>
  profit > 0 ? 'var(--won)' : profit < 0 ? 'var(--lost)' : 'var(--secondary)'
