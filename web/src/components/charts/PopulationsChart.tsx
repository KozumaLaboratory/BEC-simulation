import { useMemo } from 'react'
import type { Data, Layout } from 'plotly.js-dist-min'
import { BASE_CONFIG, BASE_LAYOUT, CHART_COLORS, Plot } from './Plot'
import type { DashboardData } from '@/api'
import { filterPoints, getX } from '@/state/useRunData'

interface Props {
  data: DashboardData | null
  xKey: string
  runFilter: string
  height?: number
}

export function PopulationsChart({ data, xKey, runFilter, height = 360 }: Props) {
  const traces = useMemo<Data[]>(() => {
    if (!data) return []
    const pts = filterPoints(data, runFilter)
    if (pts.length === 0) return []
    const m_values = pts[0].m_values ?? []
    const x = pts.map((p) => getX(p, xKey))
    return m_values.map((m, ci) => ({
      x,
      y: pts.map((p) => p.populations?.[ci] ?? 0),
      type: 'scatter',
      mode: 'lines+markers',
      marker: { color: CHART_COLORS[ci % CHART_COLORS.length], size: 5 },
      line: { color: CHART_COLORS[ci % CHART_COLORS.length], width: 1.5 },
      name: `m=${m}`,
    }))
  }, [data, xKey, runFilter])

  const layout = useMemo<Partial<Layout>>(
    () => ({
      ...BASE_LAYOUT,
      title: { text: 'Populations per m', font: { size: 13, color: '#00d9ff' } },
      xaxis: { ...BASE_LAYOUT.xaxis, title: { text: xLabel(xKey) } },
      yaxis: { ...BASE_LAYOUT.yaxis, title: { text: 'Population' }, range: [0, 1] },
      height,
    }),
    [xKey, height],
  )

  return (
    <Plot data={traces} layout={layout} config={BASE_CONFIG} style={{ width: '100%', height }} />
  )
}

export function PopulationsHeatmap({ data, xKey, runFilter, height = 360 }: Props) {
  const { traces, layout } = useMemo(() => {
    if (!data || data.points.length === 0) return { traces: [] as Data[], layout: BASE_LAYOUT }
    const pts = filterPoints(data, runFilter)
    const m_values = pts[0]?.m_values ?? []
    const x = pts.map((p) => getX(p, xKey))
    const z = m_values.map((_, ci) => pts.map((p) => p.populations?.[ci] ?? 0))
    return {
      traces: [
        {
          type: 'heatmap',
          x,
          y: m_values,
          z,
          colorscale: 'Viridis',
          zmin: 0,
          zmax: 1,
          colorbar: { title: { text: 'pop' } },
        } as Data,
      ],
      layout: {
        ...BASE_LAYOUT,
        title: { text: 'Population heatmap', font: { size: 13, color: '#00d9ff' } },
        xaxis: { ...BASE_LAYOUT.xaxis, title: { text: xLabel(xKey) } },
        yaxis: { ...BASE_LAYOUT.yaxis, title: { text: 'm' }, dtick: 1 },
        height,
      } as Partial<Layout>,
    }
  }, [data, xKey, runFilter, height])

  return (
    <Plot data={traces} layout={layout} config={BASE_CONFIG} style={{ width: '100%', height }} />
  )
}

function xLabel(xKey: string): string {
  return xKey === 'index' ? 'Point index' : xKey.replace(/^pipeline\.\d+\./, '')
}
