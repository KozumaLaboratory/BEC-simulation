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
import { useColumnDensity } from '@/state/useColumnDensity'
import { BASE_CONFIG, BASE_LAYOUT, Plot } from '@/components/charts/Plot'

interface Props {
  run: string | null
  data: DashboardData | null
}

type Axis = 1 | 2 | 3

const AXIS_LABEL: Record<Axis, string> = {
  3: 'xy (integrated z)',
  2: 'xz (integrated y)',
  1: 'yz (integrated x)',
}

export function SliceGrid({ run, data }: Props) {
  const points = data?.points ?? []
  const [pointIdx, setPointIdx] = useState(0)
  const [axis, setAxis] = useState<Axis>(3)
  const [scaleMode, setScaleMode] = useState<'shared' | 'individual'>('shared')

  const currentPoint = points[Math.min(pointIdx, points.length - 1)] ?? null
  const { data: col, loading, error } = useColumnDensity(run, currentPoint?.file ?? null, axis)

  const heatmaps = useMemo(() => {
    if (!col) return []
    const [nx, ny] = col.shape
    const [xRange, yRange] = col.axis_ranges
    const xs = linspace(xRange[0], xRange[1], nx)
    const ys = linspace(yRange[0], yRange[1], ny)

    // Per-component max for scaling.
    const perMax = col.densities.map((d) => d.reduce((m, v) => (v > m ? v : m), 0))
    const globalMax = Math.max(...perMax, 0)

    type Panel = {
      title: string
      z: number[][]
      zmax: number
    }
    const panels: Panel[] = []

    panels.push({
      title: 'Total',
      z: reshape(col.total_density, nx, ny),
      zmax: col.total_density.reduce((m, v) => (v > m ? v : m), 0),
    })

    col.m_values.forEach((m, i) => {
      panels.push({
        title: `m=${m}`,
        z: reshape(col.densities[i], nx, ny),
        zmax: perMax[i],
      })
    })

    const sharedMax =
      scaleMode === 'shared'
        ? Math.max(globalMax, panels[0].zmax)
        : null

    return panels.map((p) => ({ ...p, xs, ys, zmax: sharedMax ?? p.zmax }))
  }, [col, scaleMode])

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
          <div className="flex flex-col gap-1">
            <span className="text-xs text-muted-foreground">Color scale</span>
            <Select
              value={scaleMode}
              onValueChange={(v) => setScaleMode(v as 'shared' | 'individual')}
            >
              <SelectTrigger className="min-w-[160px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="shared">Shared</SelectItem>
                <SelectItem value="individual">Individual</SelectItem>
              </SelectContent>
            </Select>
          </div>
          <div className="ml-auto text-xs text-muted-foreground">
            {loading && 'Loading…'}
            {col && !loading && `${col.shape[0]}×${col.shape[1]}`}
          </div>
        </div>

        {error && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            {error}
          </div>
        )}

        <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
          {heatmaps.map((h) => (
            <HeatmapPanel key={h.title} {...h} axisLabels={col?.axis_labels ?? ['x', 'y']} />
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

interface HeatmapProps {
  title: string
  z: number[][]
  xs: number[]
  ys: number[]
  zmax: number
  axisLabels: string[]
}

function HeatmapPanel({ title, z, xs, ys, zmax, axisLabels }: HeatmapProps) {
  const traces: Data[] = [
    {
      type: 'heatmap',
      z,
      x: xs,
      y: ys,
      colorscale: 'Viridis',
      zmin: 0,
      zmax: zmax > 0 ? zmax : 1,
      showscale: false,
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
  }
  return <Plot data={traces} layout={layout} config={BASE_CONFIG} style={{ width: '100%', height: 220 }} />
}

function linspace(a: number, b: number, n: number): number[] {
  if (n <= 1) return [a]
  const step = (b - a) / (n - 1)
  const out = new Array<number>(n)
  for (let i = 0; i < n; i++) out[i] = a + step * i
  return out
}

function reshape(flat: number[], nx: number, ny: number): number[][] {
  // JSON ordering from Julia: column-major flatten. Dashboard expects z[row=y][col=x].
  // Julia `densities` is `vec(col_density)` where col_density is Array{Float64,2}
  // of shape (n_remaining_1, n_remaining_2) iterated column-major. To form
  // Plotly's heatmap (z[iy][ix]), read ix along fast axis.
  const out: number[][] = new Array(ny)
  for (let iy = 0; iy < ny; iy++) {
    const row = new Array<number>(nx)
    for (let ix = 0; ix < nx; ix++) {
      row[ix] = flat[ix + iy * nx]
    }
    out[iy] = row
  }
  return out
}
