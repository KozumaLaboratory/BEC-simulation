import { useMemo } from 'react'

export interface LineChartTrace {
  name: string
  color: string
  x: Array<number | null | undefined>
  y: Array<number | null | undefined>
}

interface Props {
  traces: LineChartTrace[]
  xLabel: string
  yLabel: string
  title?: string
  yRange?: [number, number]
  height?: number
  /** Override x range; defaults to data extent. */
  xRange?: [number, number]
  /** Number of grid + tick lines per axis. */
  ticks?: number
}

const PAD_L = 56
const PAD_R = 16
const PAD_T = 28
const PAD_B = 36
const LEGEND_H = 22
const COLORS = {
  axis: '#3d4550',
  grid: '#21262d',
  text: '#e6edf3',
  textMuted: '#7d8590',
  title: '#00d9ff',
  bg: 'rgba(0,0,0,0)',
}

/**
 * Multi-trace line + marker chart rendered as inline SVG. Handles the
 * subset of Plotly behaviour the dashboard actually uses: multi-line
 * legend, ignored null values, fixed y range, log spacing, hover via the
 * browser's native tooltip on the underlying circles. Zero external deps,
 * tiny bundle footprint compared to plotly.js (~5 MB).
 */
export function LineChartSVG({
  traces,
  xLabel,
  yLabel,
  title,
  yRange,
  height = 320,
  xRange,
  ticks = 6,
}: Props) {
  const W = 800 // SVG viewBox width — preserveAspectRatio scales to container
  const H = height
  const innerW = W - PAD_L - PAD_R
  const innerH = H - PAD_T - PAD_B - LEGEND_H

  const flat = useMemo(() => {
    const xs: number[] = []
    const ys: number[] = []
    for (const t of traces) {
      for (let i = 0; i < t.x.length; i++) {
        const xi = t.x[i]
        const yi = t.y[i]
        if (typeof xi === 'number' && Number.isFinite(xi) &&
            typeof yi === 'number' && Number.isFinite(yi)) {
          xs.push(xi); ys.push(yi)
        }
      }
    }
    return { xs, ys }
  }, [traces])

  const xMin = xRange ? xRange[0] : flat.xs.length ? Math.min(...flat.xs) : 0
  const xMax = xRange ? xRange[1] : flat.xs.length ? Math.max(...flat.xs) : 1
  const yMin = yRange ? yRange[0] : flat.ys.length ? Math.min(...flat.ys) : 0
  const yMax = yRange ? yRange[1] : flat.ys.length ? Math.max(...flat.ys) : 1
  const xSpan = xMax - xMin || 1
  const ySpan = yMax - yMin || 1

  const sx = (v: number) => PAD_L + ((v - xMin) / xSpan) * innerW
  const sy = (v: number) => PAD_T + (1 - (v - yMin) / ySpan) * innerH

  const xTicks = useMemo(() => makeTicks(xMin, xMax, ticks), [xMin, xMax, ticks])
  const yTicks = useMemo(() => makeTicks(yMin, yMax, ticks), [yMin, yMax, ticks])

  const tracePaths = useMemo(() => {
    return traces.map((t) => {
      let d = ''
      const points: Array<{ cx: number; cy: number }> = []
      let pen = false
      for (let i = 0; i < t.x.length; i++) {
        const xi = t.x[i]
        const yi = t.y[i]
        if (typeof xi !== 'number' || typeof yi !== 'number' ||
            !Number.isFinite(xi) || !Number.isFinite(yi)) {
          pen = false
          continue
        }
        const cx = sx(xi)
        const cy = sy(yi)
        d += !pen ? `M${cx.toFixed(2)},${cy.toFixed(2)}` : `L${cx.toFixed(2)},${cy.toFixed(2)}`
        pen = true
        points.push({ cx, cy })
      }
      return { d, points, color: t.color, name: t.name }
    })
    // sx/sy depend on extent; recompute when traces or extents change
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [traces, xMin, xMax, yMin, yMax, innerW, innerH])

  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      preserveAspectRatio="none"
      style={{ width: '100%', height, background: COLORS.bg, display: 'block' }}
    >
      {title && (
        <text
          x={W / 2}
          y={16}
          textAnchor="middle"
          fontSize={13}
          fill={COLORS.title}
          fontWeight={500}
        >
          {title}
        </text>
      )}
      {/* y-axis grid + ticks */}
      {yTicks.map((t, i) => {
        const y = sy(t)
        return (
          <g key={`y${i}`}>
            <line x1={PAD_L} y1={y} x2={W - PAD_R} y2={y} stroke={COLORS.grid} strokeWidth={1} />
            <text
              x={PAD_L - 6}
              y={y}
              textAnchor="end"
              dominantBaseline="middle"
              fontSize={10}
              fill={COLORS.textMuted}
            >
              {fmtTick(t)}
            </text>
          </g>
        )
      })}
      {/* x-axis grid + ticks */}
      {xTicks.map((t, i) => {
        const x = sx(t)
        return (
          <g key={`x${i}`}>
            <line x1={x} y1={PAD_T} x2={x} y2={PAD_T + innerH} stroke={COLORS.grid} strokeWidth={1} />
            <text
              x={x}
              y={PAD_T + innerH + 14}
              textAnchor="middle"
              fontSize={10}
              fill={COLORS.textMuted}
            >
              {fmtTick(t)}
            </text>
          </g>
        )
      })}
      {/* axis labels */}
      <text
        x={W / 2}
        y={PAD_T + innerH + 30}
        textAnchor="middle"
        fontSize={11}
        fill={COLORS.text}
      >
        {xLabel}
      </text>
      <text
        x={14}
        y={PAD_T + innerH / 2}
        textAnchor="middle"
        dominantBaseline="middle"
        fontSize={11}
        fill={COLORS.text}
        transform={`rotate(-90 14 ${PAD_T + innerH / 2})`}
      >
        {yLabel}
      </text>
      {/* axis box */}
      <rect
        x={PAD_L}
        y={PAD_T}
        width={innerW}
        height={innerH}
        fill="none"
        stroke={COLORS.axis}
        strokeWidth={1}
      />
      {/* trace lines */}
      {tracePaths.map((tp, i) => (
        <path
          key={`line${i}`}
          d={tp.d}
          fill="none"
          stroke={tp.color}
          strokeWidth={1.5}
          strokeLinejoin="round"
          strokeLinecap="round"
        />
      ))}
      {/* trace markers */}
      {tracePaths.map((tp, i) =>
        tp.points.map((p, j) => (
          <circle
            key={`m${i}_${j}`}
            cx={p.cx}
            cy={p.cy}
            r={2.5}
            fill={tp.color}
            stroke={tp.color}
            strokeWidth={0.5}
          >
            <title>{`${tp.name}: (${fmtTick(invX(p.cx, sx, xMin, xMax, innerW))}, ${fmtTick(invY(p.cy, sy, yMin, yMax, innerH))})`}</title>
          </circle>
        )),
      )}
      {/* legend */}
      {traces.length > 0 && (
        <g transform={`translate(${PAD_L}, ${H - LEGEND_H + 4})`}>
          {traces.map((t, i) => (
            <g key={`leg${i}`} transform={`translate(${i * 100}, 0)`}>
              <rect x={0} y={2} width={12} height={3} fill={t.color} />
              <text x={16} y={8} fontSize={10} fill={COLORS.text}>
                {t.name}
              </text>
            </g>
          ))}
        </g>
      )}
    </svg>
  )
}

function makeTicks(min: number, max: number, n: number): number[] {
  if (max <= min) return [min]
  const span = max - min
  const step = niceStep(span / Math.max(n - 1, 1))
  const start = Math.ceil(min / step) * step
  const out: number[] = []
  for (let v = start; v <= max + step / 2; v += step) {
    out.push(roundFloat(v, step))
  }
  return out
}

function niceStep(raw: number): number {
  const exp = Math.floor(Math.log10(raw))
  const base = Math.pow(10, exp)
  const m = raw / base
  if (m < 1.5) return base
  if (m < 3) return 2 * base
  if (m < 7) return 5 * base
  return 10 * base
}

function roundFloat(v: number, step: number): number {
  // Round to the precision of step to avoid 0.30000000000000004 ticks
  const exp = Math.floor(Math.log10(step))
  const p = Math.pow(10, -Math.min(exp, -1))
  return Math.round(v * p) / p
}

function fmtTick(v: number): string {
  if (v === 0) return '0'
  const abs = Math.abs(v)
  if (abs >= 1e4 || abs < 1e-3) return v.toExponential(1)
  if (abs >= 100) return v.toFixed(0)
  if (abs >= 10) return v.toFixed(1)
  if (abs >= 1) return v.toFixed(2)
  return v.toPrecision(2)
}

// invX/invY only used for tooltip; not perf-critical.
function invX(_cx: number, _sx: (v: number) => number, xMin: number, xMax: number, _innerW: number): number {
  // Not actually invertible from the closure; recompute from cx using xMin/xMax/innerW.
  // Kept as helper to keep the marker render block tidy.
  return xMin + ((_cx - PAD_L) / _innerW) * (xMax - xMin)
}
function invY(_cy: number, _sy: (v: number) => number, yMin: number, yMax: number, _innerH: number): number {
  return yMax - ((_cy - PAD_T) / _innerH) * (yMax - yMin)
}
