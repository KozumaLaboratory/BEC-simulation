import { useMemo } from 'react'
import { LineChartSVG, type LineChartTrace } from './LineChartSVG'
import { CHART_COLORS } from './chartColors'
import type { PointMeta, DashboardData } from '@/api'
import { getX, useGroupedPoints } from '@/state/useRunData'

interface Props {
  data: DashboardData | null
  xKey: string
  runFilter: string
  yLabel: string
  yAccessor: (p: PointMeta) => number | null
  yRange?: [number, number]
  title?: string
  height?: number
}

export function MetricLineChart({
  data,
  xKey,
  runFilter,
  yLabel,
  yAccessor,
  yRange,
  title,
  height = 320,
}: Props) {
  const groups = useGroupedPoints(data, runFilter)

  const traces = useMemo<LineChartTrace[]>(() => {
    return Object.entries(groups).map(([rn, grp], i) => ({
      name: rn || yLabel,
      color: CHART_COLORS[i % CHART_COLORS.length],
      x: grp.map((p) => getX(p, xKey)),
      y: grp.map((p) => {
        const v = yAccessor(p)
        return v !== null && Number.isFinite(v) ? v : null
      }),
    }))
  }, [groups, xKey, yLabel, yAccessor])

  return (
    <LineChartSVG
      traces={traces}
      title={title}
      xLabel={xAxisLabel(xKey)}
      yLabel={yLabel}
      yRange={yRange}
      height={height}
    />
  )
}

function xAxisLabel(xKey: string): string {
  return xKey === 'index' ? 'Point index' : xKey.replace(/^pipeline\.\d+\./, '')
}
