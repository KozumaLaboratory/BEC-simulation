import { useState, useMemo } from 'react'
import type { Data, Layout } from 'plotly.js-dist-min'
import { Card, CardContent } from '@/components/ui/card'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Button } from '@/components/ui/button'
import { ChevronLeft, ChevronRight } from 'lucide-react'
import type { DashboardData } from '@/api'
import { useColumnPhase } from '@/state/useColumnPhase'
import { BASE_CONFIG, BASE_LAYOUT, Plot } from '@/components/charts/Plot'

interface Props {
  run: string | null
  data: DashboardData | null
}

type Axis = 1 | 2 | 3
const AXIS_LABEL: Record<Axis, string> = {
  3: 'xy plane (z slice)',
  2: 'xz plane (y slice)',
  1: 'yz plane (x slice)',
}

// Cyclic HSL colormap for phase ∈ [-π, π]. Plotly doesn't expose 'HSV' by
// default, so construct one. Returns [[t, color], ...] stops for Plotly.
const PHASE_COLORSCALE: Array<[number, string]> = (() => {
  const stops: Array<[number, string]> = []
  const N = 12
  for (let i = 0; i <= N; i++) {
    const t = i / N
    const hue = t * 360
    stops.push([t, `hsl(${hue}, 80%, 55%)`])
  }
  return stops
})()

export function PhaseGrid({ run, data }: Props) {
  const points = data?.points ?? []
  const [pointIdx, setPointIdx] = useState(0)
  const [axis, setAxis] = useState<Axis>(3)
  const [densityMaskFrac, setDensityMaskFrac] = useState<number>(0.01)

  const currentPoint = points[Math.min(pointIdx, points.length - 1)] ?? null
  const { data: phaseData, loading, error } = useColumnPhase(
    run,
    currentPoint?.file ?? null,
    axis,
  )

  const heatmaps = useMemo(() => {
    if (!phaseData) return []
    const [nx, ny] = phaseData.shape
    const [xRange, yRange] = phaseData.axis_ranges
    const xs = linspace(xRange[0], xRange[1], nx)
    const ys = linspace(yRange[0], yRange[1], ny)

    const globalMaxN = Math.max(
      ...phaseData.densities.map((d) => d.reduce((m, v) => (v > m ? v : m), 0)),
      1e-300,
    )
    const mask = densityMaskFrac * globalMaxN

    return phaseData.m_values.map((m, i) => {
      const phases = phaseData.phases[i]
      const dens = phaseData.densities[i]
      // Null-out phase where |ψ|² is below the mask threshold; Plotly treats
      // null cells as transparent, which is exactly what we want for the
      // "phase is meaningless in empty regions" case.
      const z: (number | null)[][] = new Array(ny)
      for (let iy = 0; iy < ny; iy++) {
        const row: (number | null)[] = new Array(nx)
        for (let ix = 0; ix < nx; ix++) {
          const k = ix + iy * nx
          row[ix] = dens[k] < mask ? null : phases[k]
        }
        z[iy] = row
      }
      return { title: `m=${m}`, z, xs, ys }
    })
  }, [phaseData, densityMaskFrac])

  return (
    <Card>
      <CardContent className="p-3 space-y-3">
        <div className="flex flex-wrap items-end gap-3">
          <div className="flex gap-1">
            <Button
              variant="outline"
              size="icon-sm"
              onClick={() => setPointIdx((i) => Math.max(0, i - 1))}
              disabled={pointIdx <= 0}
            >
              <ChevronLeft />
            </Button>
            <Button
              variant="outline"
              size="icon-sm"
              onClick={() => setPointIdx((i) => Math.min(points.length - 1, i + 1))}
              disabled={pointIdx >= points.length - 1}
            >
              <ChevronRight />
            </Button>
          </div>
          <div className="flex flex-col gap-1">
            <span className="text-xs text-muted-foreground">Point</span>
            <Select value={String(pointIdx)} onValueChange={(v) => setPointIdx(Number(v))}>
              <SelectTrigger className="min-w-[220px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {points.map((p, i) => (
                  <SelectItem key={i} value={String(i)}>
                    #{i + 1} — {p.file}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <span className="text-xs text-muted-foreground">Axis</span>
            <Select value={String(axis)} onValueChange={(v) => setAxis(Number(v) as Axis)}>
              <SelectTrigger className="min-w-[180px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {(Object.entries(AXIS_LABEL) as [string, string][]).map(([k, lbl]) => (
                  <SelectItem key={k} value={k}>
                    {lbl}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <label className="flex flex-col gap-1">
            <span className="text-xs text-muted-foreground">
              Density mask (fraction of max)
            </span>
            <input
              type="range"
              min={0}
              max={0.2}
              step={0.005}
              value={densityMaskFrac}
              onChange={(e) => setDensityMaskFrac(Number(e.target.value))}
              className="w-[160px] accent-primary"
            />
            <span className="text-xs text-muted-foreground tabular-nums">
              {(densityMaskFrac * 100).toFixed(1)}%
            </span>
          </label>
          <div className="ml-auto text-xs text-muted-foreground">
            {loading && 'Loading…'}
            {phaseData &&
              !loading &&
              `slice #${phaseData.slice_index} / ${phaseData.shape.join('×')}`}
          </div>
        </div>

        {error && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            {error}
          </div>
        )}

        <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
          {heatmaps.map((h) => (
            <PhasePanel
              key={h.title}
              {...h}
              axisLabels={phaseData?.axis_labels ?? ['x', 'y']}
            />
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

interface PanelProps {
  title: string
  z: (number | null)[][]
  xs: number[]
  ys: number[]
  axisLabels: string[]
}

function PhasePanel({ title, z, xs, ys, axisLabels }: PanelProps) {
  const traces: Data[] = [
    {
      type: 'heatmap',
      z,
      x: xs,
      y: ys,
      colorscale: PHASE_COLORSCALE,
      zmin: -Math.PI,
      zmax: Math.PI,
      showscale: false,
      hoverongaps: false,
    } as Data,
  ]
  const layout: Partial<Layout> = {
    ...BASE_LAYOUT,
    title: { text: title, font: { size: 11, color: '#00d9ff' } },
    margin: { t: 24, r: 6, b: 28, l: 32 },
    xaxis: {
      ...BASE_LAYOUT.xaxis,
      title: { text: axisLabels[0] ?? 'x', font: { size: 10 } },
      scaleanchor: 'y',
      constrain: 'domain',
    },
    yaxis: {
      ...BASE_LAYOUT.yaxis,
      title: { text: axisLabels[1] ?? 'y', font: { size: 10 } },
    },
    height: 220,
    paper_bgcolor: '#0a0e14',
  }
  return (
    <Plot data={traces} layout={layout} config={BASE_CONFIG} style={{ width: '100%', height: 220 }} />
  )
}

function linspace(a: number, b: number, n: number): number[] {
  if (n <= 1) return [a]
  const step = (b - a) / (n - 1)
  const out = new Array<number>(n)
  for (let i = 0; i < n; i++) out[i] = a + step * i
  return out
}
