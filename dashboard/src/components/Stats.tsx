import { useMemo } from 'react'
import type { DashboardData } from '@/api'
import { filterPoints } from '@/state/useRunData'

interface Props {
  data: DashboardData | null
  runFilter: string
}

interface Row {
  label: string
  value: string
  annot?: string
  warn?: boolean
}

/**
 * "Schedule of readouts" — a drafting-paper table.
 * One column on the left (label), dotted leader, one column on the right
 * (value), optional italic annotation. Exactly how a draughtsman lists
 * material quantities or dimensions in a title block.
 */
export function Stats({ data, runFilter }: Props) {
  const rows = useMemo<Row[] | null>(() => {
    const pts = filterPoints(data, runFilter)
    if (pts.length === 0) return null
    const nConv = pts.filter((p) => p.converged).length
    const energies = pts.map((p) => p.energy).filter((e) => Number.isFinite(e))
    const eMin = energies.length ? Math.min(...energies) : NaN
    const eMax = energies.length ? Math.max(...energies) : NaN
    const mzs = pts.map((p) => p.mz_actual).filter((m) => Number.isFinite(m))
    const mzAvg = mzs.length ? mzs.reduce((s, v) => s + v, 0) / mzs.length : NaN
    const mzMin = mzs.length ? Math.min(...mzs) : NaN
    const mzMax = mzs.length ? Math.max(...mzs) : NaN
    const totalTime = pts.reduce((s, p) => s + (p.duration_seconds || 0), 0)

    const fmt = (n: number, d = 3) =>
      Number.isFinite(n) ? n.toFixed(d) : '—'
    const sign = (n: number) => (n >= 0 ? '+' : '')

    return [
      {
        label: 'E_min',
        value: fmt(eMin),
        annot:
          pts.length > 1
            ? `Δ ${fmt(eMax - eMin)} · max ${fmt(eMax)}`
            : 'ℏω_ref',
      },
      {
        label: '⟨Fz⟩',
        value: `${sign(mzAvg)}${fmt(mzAvg)}`,
        annot:
          pts.length > 1
            ? `range ${fmt(mzMin, 2)} … ${fmt(mzMax, 2)}`
            : 'magnetization',
      },
      {
        label: 'τ_total',
        value: formatTime(totalTime),
        annot: `${(totalTime / Math.max(pts.length, 1)).toFixed(1)} s · pt⁻¹`,
      },
      {
        label: 'converged',
        value: `${nConv} / ${pts.length}`,
        annot:
          nConv === pts.length
            ? 'all locked'
            : `${pts.length - nConv} unconverged`,
        warn: nConv !== pts.length,
      },
    ]
  }, [data, runFilter])

  if (!rows) return null

  // Split 4 rows into two columns of 2 each, drafting-table style.
  const left = rows.slice(0, 2)
  const right = rows.slice(2)

  return (
    <section className="border border-[var(--ink-faint)] bg-card">
      <div className="section-head px-5 pt-4 mb-0">
        <span className="num">§00</span>
        <span>Schedule of readouts</span>
        <span className="rule" aria-hidden />
        <span className="unit">aggregated</span>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 divide-x divide-[var(--ink-faint)] border-t border-[var(--ink-faint)]">
        <div className="px-5 py-4 space-y-2">
          {left.map((r) => (
            <Row key={r.label} {...r} />
          ))}
        </div>
        <div className="px-5 py-4 space-y-2">
          {right.map((r) => (
            <Row key={r.label} {...r} />
          ))}
        </div>
      </div>
    </section>
  )
}

function Row({ label, value, annot, warn }: Row) {
  return (
    <div className="leader text-[14px]">
      <span className="label" style={warn ? { color: 'var(--vermillion)' } : undefined}>
        {label}
      </span>
      <span className="fill" aria-hidden />
      <span
        className="value text-[15px]"
        style={warn ? { color: 'var(--vermillion)' } : undefined}
      >
        {value}
      </span>
      {annot && <span className="annot">{annot}</span>}
    </div>
  )
}

function formatTime(s: number): string {
  if (s < 60) return `${s.toFixed(1)}s`
  if (s < 3600) return `${Math.floor(s / 60)}m ${Math.floor(s % 60)}s`
  return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`
}
