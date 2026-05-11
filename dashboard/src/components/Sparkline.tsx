import { memo } from 'react'

interface Props {
  ys: Array<number | null | undefined>
  w?: number
  h?: number
  color?: string
  strokeWidth?: number
}

// Hand-rolled inline SVG sparkline. No external dep, zero bundle cost,
// and runs fine for hundreds of rows because React memoises the rendered
// path element. Downsample before calling for very long series.
export const Sparkline = memo(function Sparkline({
  ys,
  w = 80,
  h = 20,
  color = 'currentColor',
  strokeWidth = 1,
}: Props) {
  const valid = ys
    .map((v) => (typeof v === 'number' && Number.isFinite(v) ? v : null))
    .filter((v): v is number => v !== null)
  if (valid.length < 2) {
    return <svg width={w} height={h} />
  }
  const min = Math.min(...valid)
  const max = Math.max(...valid)
  const span = max - min || 1
  let d = ''
  const n = ys.length
  for (let i = 0; i < n; i++) {
    const y = ys[i]
    if (typeof y !== 'number' || !Number.isFinite(y)) continue
    const cx = (i / (n - 1)) * w
    const cy = h - ((y - min) / span) * h
    d += d === '' ? `M${cx},${cy}` : `L${cx},${cy}`
  }
  return (
    <svg width={w} height={h} style={{ color }}>
      <path d={d} fill="none" stroke="currentColor" strokeWidth={strokeWidth} />
    </svg>
  )
})
