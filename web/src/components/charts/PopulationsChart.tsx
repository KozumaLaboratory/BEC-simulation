import { useMemo } from 'react'
import { LineChartSVG, type LineChartTrace } from './LineChartSVG'
import { HeatmapGrid, type HeatmapPanelSpec } from '@/components/HeatmapGrid'
import { CHART_COLORS } from './chartColors'
import type { DashboardData } from '@/api'
import { filterPoints, getX } from '@/state/useRunData'

interface Props {
  data: DashboardData | null
  xKey: string
  runFilter: string
  height?: number
}

export function PopulationsChart({ data, xKey, runFilter, height = 360 }: Props) {
  const traces = useMemo<LineChartTrace[]>(() => {
    if (!data) return []
    const pts = filterPoints(data, runFilter)
    if (pts.length === 0) return []
    const m_values = pts[0].m_values ?? []
    const x = pts.map((p) => getX(p, xKey))
    return m_values.map((m, ci) => ({
      name: `m=${m}`,
      color: CHART_COLORS[ci % CHART_COLORS.length],
      x,
      y: pts.map((p) => p.populations?.[ci] ?? 0),
    }))
  }, [data, xKey, runFilter])

  return (
    <LineChartSVG
      title="Populations per m"
      traces={traces}
      xLabel={xLabel(xKey)}
      yLabel="Population"
      yRange={[0, 1]}
      height={height}
    />
  )
}

export function PopulationsHeatmap({ data, xKey, runFilter, height = 360 }: Props) {
  const spec = useMemo<HeatmapPanelSpec | null>(() => {
    if (!data || data.points.length === 0) return null
    const pts = filterPoints(data, runFilter)
    const m_values = pts[0]?.m_values ?? []
    if (m_values.length === 0 || pts.length === 0) return null
    // Pack populations as flat row-major Float32 [pt_idx + m_idx * nx]
    // (m on the y axis, point index on the x axis).
    const nx = pts.length
    const ny = m_values.length
    const flat = new Float32Array(nx * ny)
    for (let m = 0; m < ny; m++) {
      for (let i = 0; i < nx; i++) {
        flat[i + m * nx] = pts[i].populations?.[m] ?? 0
      }
    }
    return {
      id: 'populations_heatmap',
      title: 'Population heatmap',
      data: flat,
      nx,
      ny,
      zmin: 0,
      zmax: 1,
      colormap: 'viridis',
    }
  }, [data, xKey, runFilter])

  if (!spec) return null
  return (
    <HeatmapGrid
      panels={[spec]}
      cols={1}
      rowHeight={height}
      axisLabels={[xLabel(xKey), 'm']}
    />
  )
}

function xLabel(xKey: string): string {
  return xKey === 'index' ? 'Point index' : xKey.replace(/^pipeline\.\d+\./, '')
}
