import { useEffect, useMemo, useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Download } from 'lucide-react'
import { cn } from '@/lib/utils'
import { api, type DashboardData, type PointMeta, type DynamicsSeries } from '@/api'
import { filterPoints } from '@/state/useRunData'
import { Sparkline } from '@/components/Sparkline'

interface Props {
  data: DashboardData | null
  runFilter: string
}

type SortDir = 'asc' | 'desc'
type Stat = 'mean' | 'min' | 'max' | 'std'

export function DataTable({ data, runFilter }: Props) {
  const [sortKey, setSortKey] = useState<string>('index')
  const [sortDir, setSortDir] = useState<SortDir>('asc')

  const pts = useMemo(() => filterPoints(data, runFilter), [data, runFilter])
  const mValues = useMemo(() => pts[0]?.m_values ?? [], [pts])
  const scanKeys = data?.scan_keys ?? []
  const series = useDynamicsSeriesMap(data?.run ?? null, pts)

  const allNumericKeys = useMemo(
    () => ['energy', 'mz_actual', 'duration_seconds', ...scanKeys],
    [scanKeys],
  )

  const sorted = useMemo(() => {
    const arr = [...pts]
    arr.sort((a, b) => {
      const av = getValue(a, sortKey)
      const bv = getValue(b, sortKey)
      const cmp = compare(av, bv)
      return sortDir === 'asc' ? cmp : -cmp
    })
    return arr
  }, [pts, sortKey, sortDir])

  const stats = useMemo(() => {
    const out: Record<string, Record<Stat, number>> = {}
    for (const k of allNumericKeys) {
      const vals = pts
        .map((p) => getValue(p, k))
        .filter((v): v is number => typeof v === 'number' && Number.isFinite(v))
      if (vals.length === 0) continue
      const mean = vals.reduce((s, v) => s + v, 0) / vals.length
      const variance = vals.reduce((s, v) => s + (v - mean) ** 2, 0) / vals.length
      out[k] = {
        mean,
        min: Math.min(...vals),
        max: Math.max(...vals),
        std: Math.sqrt(variance),
      }
    }
    return out
  }, [pts, allNumericKeys])

  const toggle = (k: string) => {
    if (k === sortKey) setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    else {
      setSortKey(k)
      setSortDir('asc')
    }
  }

  const exportCsv = () => {
    const headers = [
      'index',
      'file',
      'run_name',
      'energy',
      'mz_actual',
      'converged',
      ...scanKeys,
      ...mValues.map((m) => `pop_m${m >= 0 ? '+' + m : m}`),
      'duration_seconds',
      'started_at',
      'finished_at',
    ]
    const rows = sorted.map((p) =>
      [
        p.index,
        p.file,
        p.run_name || '',
        p.energy,
        p.mz_actual,
        p.converged ? 1 : 0,
        ...scanKeys.map((k) => p.override?.[k] ?? ''),
        ...mValues.map((_, i) => p.populations?.[i] ?? ''),
        p.duration_seconds,
        p.started_at || '',
        p.finished_at || '',
      ]
        .map(csvCell)
        .join(','),
    )
    const blob = new Blob([[headers.join(','), ...rows].join('\n')], { type: 'text/csv' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `${data?.run ?? 'points'}.csv`
    a.click()
    URL.revokeObjectURL(url)
  }

  if (!data || pts.length === 0) return null

  const convCount = pts.filter((p) => p.converged).length

  return (
    <Card>
      <CardContent className="p-0">
        <div className="flex items-center justify-between px-3 py-2 border-b">
          <div className="text-xs text-muted-foreground">
            {pts.length} points ·{' '}
            <span className={convCount === pts.length ? 'text-emerald-500' : 'text-amber-500'}>
              {convCount} converged
            </span>
            {scanKeys.length > 0 && (
              <> · scan: <span className="font-mono">{scanKeys.join(', ')}</span></>
            )}
          </div>
          <Button variant="outline" size="sm" onClick={exportCsv}>
            <Download className="size-3" /> CSV
          </Button>
        </div>

        <div className="max-h-[600px] overflow-auto">
          <table className="w-full text-xs">
            <thead className="bg-card sticky top-0 z-10">
              <tr className="border-b">
                <Th k="index" sortKey={sortKey} sortDir={sortDir} onClick={toggle}>
                  #
                </Th>
                <Th align="left">file</Th>
                <Th k="run_name" sortKey={sortKey} sortDir={sortDir} onClick={toggle} align="left">
                  run
                </Th>
                {scanKeys.map((k) => (
                  <Th key={k} k={k} sortKey={sortKey} sortDir={sortDir} onClick={toggle}>
                    <span className="font-mono text-[10px]">{k.replace(/^pipeline\.\d+\./, '')}</span>
                  </Th>
                ))}
                <Th k="energy" sortKey={sortKey} sortDir={sortDir} onClick={toggle}>
                  energy
                </Th>
                <Th k="mz_actual" sortKey={sortKey} sortDir={sortDir} onClick={toggle}>
                  Mz
                </Th>
                <th className="px-2 py-2 text-right">conv</th>
                <th className="px-2 py-2 text-center min-w-[90px]">Mz(t)</th>
                <th className="px-2 py-2 text-center min-w-[90px]">E(t)</th>
                <th className="px-2 py-2 text-center min-w-[130px]">populations (m=+F..−F)</th>
                <Th
                  k="duration_seconds"
                  sortKey={sortKey}
                  sortDir={sortDir}
                  onClick={toggle}
                >
                  t (s)
                </Th>
              </tr>
              <tr className="border-b bg-muted/30 text-[10px] text-muted-foreground">
                <td className="px-2 py-1 text-right font-medium">stats →</td>
                <td />
                <td />
                {scanKeys.map((k) => (
                  <StatCell key={k} s={stats[k]} />
                ))}
                <StatCell s={stats['energy']} />
                <StatCell s={stats['mz_actual']} />
                <td />
                <td />
                <td />
                <td />
                <StatCell s={stats['duration_seconds']} digits={1} />
              </tr>
            </thead>
            <tbody>
              {sorted.map((p, i) => (
                <tr key={i} className="border-b last:border-0 hover:bg-muted/40">
                  <td className="px-2 py-1.5 text-right tabular-nums">{p.index}</td>
                  <td className="px-2 py-1.5 font-mono text-muted-foreground">{p.file}</td>
                  <td className="px-2 py-1.5">{p.run_name || '—'}</td>
                  {scanKeys.map((k) => (
                    <td key={k} className="px-2 py-1.5 text-right tabular-nums">
                      {fmtAny(p.override?.[k])}
                    </td>
                  ))}
                  <td className="px-2 py-1.5 text-right tabular-nums">{fmt(p.energy, 3)}</td>
                  <td className="px-2 py-1.5 text-right tabular-nums">{fmt(p.mz_actual, 3)}</td>
                  <td className="px-2 py-1.5 text-right">
                    <span className={p.converged ? 'text-emerald-500' : 'text-destructive'}>
                      {p.converged ? '✓' : '✗'}
                    </span>
                  </td>
                  <td className="px-2 py-1.5 text-center">
                    <Sparkline ys={series[p.file]?.magnetizations ?? []} color="#a277ff" />
                  </td>
                  <td className="px-2 py-1.5 text-center">
                    <Sparkline ys={series[p.file]?.energies ?? []} color="#00d9ff" />
                  </td>
                  <td className="px-2 py-1.5">
                    <PopulationBar populations={p.populations ?? []} />
                  </td>
                  <td className="px-2 py-1.5 text-right tabular-nums text-muted-foreground">
                    {fmt(p.duration_seconds, 1)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  )
}

// Fetch dynamics/* time series for every row in the table. Hits the new
// /api/dynamics_series endpoint in parallel; returns a file → series map.
// Results are cached by (run, file) and survive panel re-renders.
function useDynamicsSeriesMap(run: string | null, pts: PointMeta[]) {
  const [map, setMap] = useState<Record<string, DynamicsSeries>>({})

  useEffect(() => {
    if (!run || pts.length === 0) {
      setMap({})
      return
    }
    let cancelled = false
    Promise.all(
      pts.map((p) =>
        api
          .getDynamicsSeries(run, p.file)
          .then((s): [string, DynamicsSeries] => [p.file, s])
          .catch((): [string, DynamicsSeries] => [p.file, { has_dynamics: false }]),
      ),
    ).then((entries) => {
      if (cancelled) return
      setMap(Object.fromEntries(entries))
    })
    return () => {
      cancelled = true
    }
  }, [run, pts])

  return map
}

function StatCell({ s, digits = 3 }: { s?: Record<Stat, number>; digits?: number }) {
  if (!s) return <td />
  return (
    <td
      className="px-2 py-1 text-right tabular-nums"
      title={`mean ${s.mean.toFixed(digits)}  min ${s.min.toFixed(digits)}  max ${s.max.toFixed(digits)}  σ ${s.std.toFixed(digits)}`}
    >
      {s.mean.toFixed(digits)}
      <span className="text-muted-foreground/60"> ± {s.std.toFixed(digits)}</span>
    </td>
  )
}

// Stacked horizontal bar showing population per m. Colored by relative
// weight with a visible baseline so 0-pop columns stay readable.
function PopulationBar({ populations }: { populations: number[] }) {
  if (populations.length === 0) return null
  const maxPop = Math.max(...populations, 1e-300)
  return (
    <div className="flex h-4 gap-[1px] items-center min-w-[130px]">
      {populations.map((p, i) => {
        const h = Math.max(2, (p / maxPop) * 16)
        const hue = 220 - (i / Math.max(1, populations.length - 1)) * 220
        return (
          <div
            key={i}
            className="flex-1"
            title={`m=${i === 0 ? '+F' : i - Math.floor(populations.length / 2)}  pop=${p.toExponential(2)}`}
            style={{
              height: `${h}px`,
              background: `hsl(${hue}, 70%, 55%)`,
              opacity: p / maxPop > 0.01 ? 1 : 0.2,
              borderRadius: 1,
            }}
          />
        )
      })}
    </div>
  )
}

interface ThProps {
  k?: string
  sortKey?: string
  sortDir?: SortDir
  onClick?: (k: string) => void
  align?: 'left' | 'right'
  children: React.ReactNode
}

function Th({ k, sortKey, sortDir, onClick, align = 'right', children }: ThProps) {
  const active = k !== undefined && k === sortKey
  const arrow = active ? (sortDir === 'asc' ? ' ▲' : ' ▼') : ''
  return (
    <th
      className={cn(
        'px-2 py-2 font-medium text-primary whitespace-nowrap',
        align === 'right' ? 'text-right' : 'text-left',
        k && 'cursor-pointer select-none hover:text-foreground',
      )}
      onClick={() => k && onClick?.(k)}
    >
      {children}
      {arrow}
    </th>
  )
}

function getValue(p: PointMeta, key: string): unknown {
  if (key === 'index' || key === 'energy' || key === 'mz_actual' || key === 'duration_seconds') {
    return (p as unknown as Record<string, unknown>)[key]
  }
  if (key === 'run_name') return p.run_name
  return p.override?.[key]
}

function fmt(v: unknown, digits: number): string {
  if (typeof v !== 'number' || !Number.isFinite(v)) return '—'
  const abs = Math.abs(v)
  if (abs !== 0 && (abs < 1e-3 || abs >= 1e5)) return v.toExponential(digits - 1)
  return v.toFixed(digits)
}

function fmtAny(v: unknown): string {
  if (typeof v === 'number') return fmt(v, 3)
  if (v === null || v === undefined) return '—'
  return String(v)
}

function csvCell(v: unknown): string {
  if (v === null || v === undefined) return ''
  const s = String(v)
  return /[,"\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s
}

function compare(a: unknown, b: unknown): number {
  if (typeof a === 'number' && typeof b === 'number') {
    if (!Number.isFinite(a) && !Number.isFinite(b)) return 0
    if (!Number.isFinite(a)) return 1
    if (!Number.isFinite(b)) return -1
    return a - b
  }
  return String(a ?? '').localeCompare(String(b ?? ''))
}
