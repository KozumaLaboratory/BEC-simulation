import { useMemo } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import type { DashboardData } from '@/api'
import { filterPoints } from '@/state/useRunData'

interface Props {
  data: DashboardData | null
  runFilter: string
}

export function Stats({ data, runFilter }: Props) {
  const stats = useMemo(() => {
    const pts = filterPoints(data, runFilter)
    if (pts.length === 0) return null
    const nConv = pts.filter((p) => p.converged).length
    const energies = pts.map((p) => p.energy).filter((e) => Number.isFinite(e))
    const eMin = energies.length ? Math.min(...energies).toFixed(2) : '—'
    const eMax = energies.length ? Math.max(...energies).toFixed(2) : '—'
    const totalTime = pts.reduce((s, p) => s + (p.duration_seconds || 0), 0)
    return {
      total: pts.length,
      converged: `${nConv}/${pts.length}`,
      energyRange: `${eMin} .. ${eMax}`,
      totalTime: formatTime(totalTime),
      nonConv: pts.length - nConv,
    }
  }, [data, runFilter])

  if (!stats) return null

  const items: Array<[string, string]> = [
    ['Points', String(stats.total)],
    ['Converged', stats.converged],
    ['Energy range', stats.energyRange],
    ['Total time', stats.totalTime],
  ]

  return (
    <>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
        {items.map(([label, value]) => (
          <Card key={label} className="border-l-4 border-l-primary py-3">
            <CardContent className="px-4 py-0">
              <div className="text-xs text-muted-foreground">{label}</div>
              <div className="text-lg font-semibold text-primary">{value}</div>
            </CardContent>
          </Card>
        ))}
      </div>
      {stats.nonConv > 0 && (
        <div className="mb-4 rounded-md border border-destructive/50 bg-destructive/10 px-4 py-2 text-sm text-destructive">
          {stats.nonConv}/{stats.total} points did NOT converge.
        </div>
      )}
    </>
  )
}

function formatTime(s: number): string {
  if (s < 60) return `${s.toFixed(1)}s`
  if (s < 3600) return `${Math.floor(s / 60)}m ${Math.floor(s % 60)}s`
  return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`
}
