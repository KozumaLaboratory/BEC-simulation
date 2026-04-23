import { useMemo } from 'react'
import type { Data, Layout } from 'plotly.js-dist-min'
import { BASE_CONFIG, BASE_LAYOUT, CHART_COLORS, Plot } from './Plot'
import type { PointMeta } from '@/api'
import { getX, useGroupedPoints } from '@/state/useRunData'
import type { DashboardData } from '@/api'

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
  const traces = useMemo<Data[]>(() => {
    return Object.entries(groups).map(([rn, grp], i) => ({
      x: grp.map((p) => getX(p, xKey)),
      y: grp.map((p) => {
        const v = yAccessor(p)
        return v !== null && Number.isFinite(v) ? v : null
      }),
      type: 'scatter',
      mode: 'lines+markers',
      marker: { color: CHART_COLORS[i % CHART_COLORS.length], size: 6 },
      line: { color: CHART_COLORS[i % CHART_COLORS.length], width: 2 },
      name: rn || yLabel,
    }))
  }, [groups, xKey, yLabel, yAccessor])

  const layout = useMemo<Partial<Layout>>(
    () => ({
      ...BASE_LAYOUT,
      title: title ? { text: title, font: { size: 13, color: '#00d9ff' } } : undefined,
      xaxis: { ...BASE_LAYOUT.xaxis, title: { text: xAxisLabel(xKey) } },
      yaxis: {
        ...BASE_LAYOUT.yaxis,
        title: { text: yLabel },
        range: yRange,
      },
      height,
    }),
    [title, xKey, yLabel, yRange, height],
  )

  return (
    <Plot data={traces} layout={layout} config={BASE_CONFIG} style={{ width: '100%', height }} />
  )
}

function xAxisLabel(xKey: string): string {
  return xKey === 'index' ? 'Point index' : xKey.replace(/^pipeline\.\d+\./, '')
}
