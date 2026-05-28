import { useMemo, useState } from 'react'
import type { CatalogRow } from '@/api'

// Parallel coordinates over a *cohort* (the faceted-filter result), not
// the whole store — there is no global common axis set, so axes are
// derived per-cohort: numeric fields present in a meaningful fraction of
// these rows. Each run is one polyline; color encodes a chosen observable
// so the winning band surfaces without reading a list. Brushing (drag an
// axis to range-filter) is the next increment; for now filtering lives in
// the facet bar and color/sort does the triage.

const AXIS_CANDIDATES = [
  'F',
  'ndim',
  'energy',
  'Mz',
  'norm',
  'norm_rel_drift',
  'energy_rel_drift',
  'Fz_drift',
]

const VB_W = 1000
const VB_H = 320
const PAD_X = 64
const PAD_TOP = 26
const PAD_BOT = 46
const INNER_W = VB_W - 2 * PAD_X
const INNER_H = VB_H - PAD_TOP - PAD_BOT

function num(r: CatalogRow, k: string): number | null {
  const v = r[k]
  return typeof v === 'number' && Number.isFinite(v) ? v : null
}

// 2-stop lerp cyan → vermillion (matches the dashboard's accent pair).
function colorFor(t: number): string {
  const c0 = [74, 139, 184]
  const c1 = [217, 122, 60]
  const u = Math.max(0, Math.min(1, t))
  const ch = c0.map((a, i) => Math.round(a + (c1[i] - a) * u))
  return `rgb(${ch[0]},${ch[1]},${ch[2]})`
}

export function ParallelCoordinates({ rows }: { rows: CatalogRow[] }) {
  const axes = useMemo(() => {
    const min = Math.max(2, Math.ceil(rows.length * 0.3))
    return AXIS_CANDIDATES.filter(
      (k) => rows.filter((r) => num(r, k) !== null).length >= min,
    )
  }, [rows])

  const [colorBy, setColorBy] = useState<string>('')
  const activeColor = colorBy && axes.includes(colorBy) ? colorBy : (axes[axes.length - 1] ?? '')

  const ranges = useMemo(() => {
    const out: Record<string, [number, number]> = {}
    for (const a of axes) {
      const vals = rows.map((r) => num(r, a)).filter((v): v is number => v !== null)
      const lo = Math.min(...vals)
      const hi = Math.max(...vals)
      out[a] = [lo, hi === lo ? lo + 1 : hi]
    }
    return out
  }, [rows, axes])

  // Complete-case rows only — partial polylines read as broken. Cohort-
  // first filtering means most rows share the axes anyway.
  const complete = useMemo(
    () => rows.filter((r) => axes.every((a) => num(r, a) !== null)),
    [rows, axes],
  )

  if (axes.length < 2) {
    return (
      <div className="px-5 py-6 text-[12px] font-mono text-[var(--ink-faint)] text-center">
        not enough shared numeric axes in this cohort for parallel coordinates
        <br />
        (filter to a comparable family — e.g. one recipe / grid size)
      </div>
    )
  }

  const axisX = (i: number) => PAD_X + (axes.length === 1 ? 0 : i * (INNER_W / (axes.length - 1)))
  const yOf = (a: string, v: number) => {
    const [lo, hi] = ranges[a]
    return PAD_TOP + (1 - (v - lo) / (hi - lo)) * INNER_H
  }
  const [clo, chi] = activeColor ? ranges[activeColor] : [0, 1]

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-3 px-1">
        <span className="font-mono text-[10px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
          color by
        </span>
        <select
          value={activeColor}
          onChange={(e) => setColorBy(e.target.value)}
          className="bg-transparent text-[11px] font-mono border border-[var(--ink-faint)] px-1.5 py-0.5"
          style={{ borderRadius: 0 }}
        >
          {axes.map((a) => (
            <option key={a} value={a}>
              {a}
            </option>
          ))}
        </select>
        <span className="font-mono text-[10px] text-[var(--ink-faint)] ml-auto">
          {complete.length} of {rows.length} rows · {axes.length} axes
        </span>
        {activeColor && (
          <span className="inline-flex items-center gap-1 font-mono text-[10px] text-[var(--ink-soft)]">
            {clo.toExponential(1)}
            <span
              className="inline-block w-16 h-2"
              style={{
                background: `linear-gradient(90deg, ${colorFor(0)}, ${colorFor(1)})`,
              }}
            />
            {chi.toExponential(1)}
          </span>
        )}
      </div>
      <svg
        viewBox={`0 0 ${VB_W} ${VB_H}`}
        className="w-full"
        style={{ maxHeight: 360 }}
        preserveAspectRatio="xMidYMid meet"
      >
        {/* axes */}
        {axes.map((a, i) => {
          const x = axisX(i)
          const [lo, hi] = ranges[a]
          return (
            <g key={a}>
              <line
                x1={x}
                y1={PAD_TOP}
                x2={x}
                y2={PAD_TOP + INNER_H}
                stroke="var(--ink-faint)"
                strokeWidth={1}
              />
              <text
                x={x}
                y={PAD_TOP + INNER_H + 16}
                textAnchor="middle"
                className="fill-[var(--ink-soft)]"
                style={{ fontSize: 11, fontFamily: 'monospace' }}
              >
                {a}
              </text>
              <text
                x={x}
                y={PAD_TOP - 8}
                textAnchor="middle"
                className="fill-[var(--ink-faint)]"
                style={{ fontSize: 9, fontFamily: 'monospace' }}
              >
                {hi.toExponential(1)}
              </text>
              <text
                x={x}
                y={PAD_TOP + INNER_H + 30}
                textAnchor="middle"
                className="fill-[var(--ink-faint)]"
                style={{ fontSize: 9, fontFamily: 'monospace' }}
              >
                {lo.toExponential(1)}
              </text>
            </g>
          )
        })}
        {/* polylines */}
        {complete.map((r) => {
          const pts = axes.map((a, i) => `${axisX(i)},${yOf(a, num(r, a)!)}`).join(' ')
          const cv = activeColor ? num(r, activeColor) : null
          const t = cv !== null && chi !== clo ? (cv - clo) / (chi - clo) : 0.5
          return (
            <polyline
              key={r.name}
              points={pts}
              fill="none"
              stroke={colorFor(t)}
              strokeWidth={1}
              strokeOpacity={0.55}
            >
              <title>{r.name}</title>
            </polyline>
          )
        })}
      </svg>
    </div>
  )
}
