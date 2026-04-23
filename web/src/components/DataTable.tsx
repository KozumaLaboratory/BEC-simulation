import { useMemo, useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { cn } from '@/lib/utils'
import type { DashboardData, PointMeta } from '@/api'
import { filterPoints } from '@/state/useRunData'

interface Props {
  data: DashboardData | null
  runFilter: string
}

type SortKey = 'index' | 'energy' | 'mz_actual' | 'duration_seconds' | 'run_name'
type SortDir = 'asc' | 'desc'

export function DataTable({ data, runFilter }: Props) {
  const [sortKey, setSortKey] = useState<SortKey>('index')
  const [sortDir, setSortDir] = useState<SortDir>('asc')

  const pts = useMemo(() => filterPoints(data, runFilter), [data, runFilter])
  const mValues = useMemo(() => pts[0]?.m_values ?? [], [pts])

  const sorted = useMemo(() => {
    const arr = [...pts]
    arr.sort((a, b) => {
      const av = (a as unknown as Record<string, unknown>)[sortKey]
      const bv = (b as unknown as Record<string, unknown>)[sortKey]
      const cmp = compare(av, bv)
      return sortDir === 'asc' ? cmp : -cmp
    })
    return arr
  }, [pts, sortKey, sortDir])

  const toggle = (k: SortKey) => {
    if (k === sortKey) setSortDir(sortDir === 'asc' ? 'desc' : 'asc')
    else {
      setSortKey(k)
      setSortDir('asc')
    }
  }

  if (!data || pts.length === 0) {
    return null
  }

  return (
    <Card>
      <CardContent className="p-0">
        <div className="max-h-[500px] overflow-auto">
          <table className="w-full text-xs">
            <thead className="bg-card sticky top-0 z-10">
              <tr className="border-b">
                <Th k="index" sortKey={sortKey} sortDir={sortDir} onClick={toggle}>#</Th>
                <Th align="left">file</Th>
                <Th k="run_name" sortKey={sortKey} sortDir={sortDir} onClick={toggle} align="left">run</Th>
                <Th k="energy" sortKey={sortKey} sortDir={sortDir} onClick={toggle}>energy</Th>
                <Th k="mz_actual" sortKey={sortKey} sortDir={sortDir} onClick={toggle}>Mz</Th>
                <th className="px-2 py-2 text-right">conv</th>
                {mValues.map((m) => (
                  <th key={m} className="px-2 py-2 text-right font-medium text-primary">
                    m={m}
                  </th>
                ))}
                <Th
                  k="duration_seconds"
                  sortKey={sortKey}
                  sortDir={sortDir}
                  onClick={toggle}
                >
                  t (s)
                </Th>
              </tr>
            </thead>
            <tbody>
              {sorted.map((p, i) => (
                <tr key={i} className="border-b last:border-0 hover:bg-muted/40">
                  <td className="px-2 py-1.5 text-right tabular-nums">{p.index}</td>
                  <td className="px-2 py-1.5 font-mono text-muted-foreground">{p.file}</td>
                  <td className="px-2 py-1.5">{p.run_name || '—'}</td>
                  <td className="px-2 py-1.5 text-right tabular-nums">
                    {fmt(p.energy, 3)}
                  </td>
                  <td className="px-2 py-1.5 text-right tabular-nums">
                    {fmt(p.mz_actual, 3)}
                  </td>
                  <td className="px-2 py-1.5 text-right">
                    <span className={p.converged ? 'text-emerald-500' : 'text-destructive'}>
                      {p.converged ? '✓' : '✗'}
                    </span>
                  </td>
                  {mValues.map((_, mi) => (
                    <td key={mi} className="px-2 py-1.5 text-right tabular-nums">
                      {fmt(p.populations?.[mi], 2)}
                    </td>
                  ))}
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

interface ThProps {
  k?: SortKey
  sortKey?: SortKey
  sortDir?: SortDir
  onClick?: (k: SortKey) => void
  align?: 'left' | 'right'
  children: React.ReactNode
}

function Th({ k, sortKey, sortDir, onClick, align = 'right', children }: ThProps) {
  const active = k !== undefined && k === sortKey
  const arrow = active ? (sortDir === 'asc' ? ' ▲' : ' ▼') : ''
  return (
    <th
      className={cn(
        'px-2 py-2 font-medium text-primary',
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

function fmt(v: unknown, digits: number): string {
  if (typeof v !== 'number' || !Number.isFinite(v)) return '—'
  return v.toFixed(digits)
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

function _extractPopulation(p: PointMeta, i: number): number {
  return p.populations?.[i] ?? 0
}
// Ensure helper is tree-shakable without triggering unused warning.
void _extractPopulation
