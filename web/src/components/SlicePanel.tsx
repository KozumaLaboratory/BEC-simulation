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
import { useColumnPhase } from '@/state/useColumnPhase'
import { BASE_CONFIG, BASE_LAYOUT, Plot } from '@/components/charts/Plot'

interface Props {
  run: string | null
  data: DashboardData | null
}

type Axis = 1 | 2 | 3
type Mode = 'density' | 'phase'

const AXIS_LABEL: Record<Axis, string> = {
  3: 'xy plane (z integrate/slice)',
  2: 'xz plane (y integrate/slice)',
  1: 'yz plane (x integrate/slice)',
}

// Cyclic HSL colormap for phase ∈ [-π, π].
const PHASE_COLORSCALE: Array<[number, string]> = (() => {
  const stops: Array<[number, string]> = []
  const N = 12
  for (let i = 0; i <= N; i++) {
    const t = i / N
    stops.push([t, `hsl(${t * 360}, 80%, 55%)`])
  }
  return stops
})()

// Unified per-m 2D grid — one component switches between column-integrated
// density (viridis, |ψ_m|²) and phase-at-a-plane (cyclic hue, arg(ψ_m)).
// Previously these lived in two tabs (SliceGrid, PhaseGrid) with 90 % of
// the same scaffolding around them; keeping them in sync was annoying.
export function SlicePanel({ run, data }: Props) {
  const points = data?.points ?? []
  const [pointIdx, setPointIdx] = useState(0)
  const [axis, setAxis] = useState<Axis>(3)
  const [mode, setMode] = useState<Mode>('density')
  const [scaleMode, setScaleMode] = useState<'shared' | 'individual'>('shared')
  const [densityMaskFrac, setDensityMaskFrac] = useState<number>(0.01)

  const currentPoint = points[Math.min(pointIdx, points.length - 1)] ?? null
  const {
    data: colDens,
    loading: densLoading,
    error: densError,
  } = useColumnDensity(
    mode === 'density' ? run : null,
    mode === 'density' ? currentPoint?.file ?? null : null,
    axis,
  )
  const {
    data: phaseData,
    loading: phaseLoading,
    error: phaseError,
  } = useColumnPhase(
    mode === 'phase' ? run : null,
    mode === 'phase' ? currentPoint?.file ?? null : null,
    axis,
  )

  const loading = mode === 'density' ? densLoading : phaseLoading
  const error = mode === 'density' ? densError : phaseError

  const { panels, xs, ys, axisLabels } = useMemo(() => {
    if (mode === 'density' && colDens) {
      const [nx, ny] = colDens.shape
      const [xRange, yRange] = colDens.axis_ranges
      const xsArr = linspace(xRange[0], xRange[1], nx)
      const ysArr = linspace(yRange[0], yRange[1], ny)
      const perMax = colDens.densities.map((d) => d.reduce((m, v) => (v > m ? v : m), 0))
      const globalMax = Math.max(...perMax, 0)
      const sharedMax =
        scaleMode === 'shared' ? Math.max(globalMax, colDens.total_density.reduce((m, v) => (v > m ? v : m), 0)) : null
      const out: Array<{ title: string; z: (number | null)[][]; zmin: number; zmax: number }> = []
      out.push({
        title: 'Total',
        z: reshape(colDens.total_density, nx, ny),
        zmin: 0,
        zmax: sharedMax ?? colDens.total_density.reduce((m, v) => (v > m ? v : m), 0),
      })
      colDens.m_values.forEach((m, i) => {
        out.push({
          title: `m=${m}`,
          z: reshape(colDens.densities[i], nx, ny),
          zmin: 0,
          zmax: sharedMax ?? perMax[i],
        })
      })
      return { panels: out, xs: xsArr, ys: ysArr, axisLabels: colDens.axis_labels }
    }
    if (mode === 'phase' && phaseData) {
      const [nx, ny] = phaseData.shape
      const [xRange, yRange] = phaseData.axis_ranges
      const xsArr = linspace(xRange[0], xRange[1], nx)
      const ysArr = linspace(yRange[0], yRange[1], ny)
      const globalMaxN = Math.max(
        ...phaseData.densities.map((d) => d.reduce((m, v) => (v > m ? v : m), 0)),
        1e-300,
      )
      const mask = densityMaskFrac * globalMaxN
      const out = phaseData.m_values.map((m, i) => {
        const ph = phaseData.phases[i]
        const dens = phaseData.densities[i]
        const z: (number | null)[][] = new Array(ny)
        for (let iy = 0; iy < ny; iy++) {
          const row: (number | null)[] = new Array(nx)
          for (let ix = 0; ix < nx; ix++) {
            const k = ix + iy * nx
            row[ix] = dens[k] < mask ? null : ph[k]
          }
          z[iy] = row
        }
        return { title: `m=${m}`, z, zmin: -Math.PI, zmax: Math.PI }
      })
      return { panels: out, xs: xsArr, ys: ysArr, axisLabels: phaseData.axis_labels }
    }
    return { panels: [], xs: [] as number[], ys: [] as number[], axisLabels: ['x', 'y'] }
  }, [mode, colDens, phaseData, scaleMode, densityMaskFrac])

  const sizeInfo =
    mode === 'density'
      ? colDens && `${colDens.shape[0]}×${colDens.shape[1]}`
      : phaseData && `slice #${phaseData.slice_index} / ${phaseData.shape.join('×')}`

  return (
    <Card>
      <CardContent className="p-3 space-y-3">
        <div className="flex flex-wrap items-end gap-3">
          <LabelledSelect label="Mode" value={mode} onChange={(v) => setMode(v as Mode)} options={[
            { value: 'density', label: 'Density |ψ_m|² (column-integrated)' },
            { value: 'phase', label: 'Phase arg(ψ_m) (midplane slice)' },
          ]} width="min-w-[280px]" />
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
          <LabelledSelect
            label="Point"
            value={String(pointIdx)}
            onChange={(v) => setPointIdx(Number(v))}
            options={points.map((p, i) => ({ value: String(i), label: `#${i + 1} — ${p.file}` }))}
            width="min-w-[220px]"
          />
          <LabelledSelect
            label="Axis"
            value={String(axis)}
            onChange={(v) => setAxis(Number(v) as Axis)}
            options={(Object.entries(AXIS_LABEL) as [string, string][]).map(([k, lbl]) => ({
              value: k,
              label: lbl,
            }))}
            width="min-w-[200px]"
          />
          {mode === 'density' && (
            <LabelledSelect
              label="Color scale"
              value={scaleMode}
              onChange={(v) => setScaleMode(v as 'shared' | 'individual')}
              options={[
                { value: 'shared', label: 'Shared' },
                { value: 'individual', label: 'Individual' },
              ]}
            />
          )}
          {mode === 'phase' && (
            <label className="flex flex-col gap-1">
              <span className="text-xs text-muted-foreground">
                Density mask ({(densityMaskFrac * 100).toFixed(1)}%)
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
            </label>
          )}
          <div className="ml-auto text-xs text-muted-foreground">
            {loading && 'Loading…'}
            {!loading && sizeInfo}
          </div>
        </div>

        {error && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            {error}
          </div>
        )}

        <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
          {panels.map((p) => (
            <Panel
              key={p.title}
              mode={mode}
              title={p.title}
              z={p.z}
              xs={xs}
              ys={ys}
              zmin={p.zmin}
              zmax={p.zmax}
              axisLabels={axisLabels}
            />
          ))}
        </div>
      </CardContent>
    </Card>
  )
}

interface PanelProps {
  mode: Mode
  title: string
  z: (number | null)[][] | number[][]
  xs: number[]
  ys: number[]
  zmin: number
  zmax: number
  axisLabels: string[]
}

function Panel({ mode, title, z, xs, ys, zmin, zmax, axisLabels }: PanelProps) {
  const traces: Data[] = [
    {
      type: 'heatmap',
      z: z as number[][],
      x: xs,
      y: ys,
      colorscale: mode === 'phase' ? PHASE_COLORSCALE : 'Viridis',
      zmin,
      zmax: zmax > 0 ? zmax : 1,
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
    paper_bgcolor: mode === 'phase' ? '#0a0e14' : 'rgba(0,0,0,0)',
  }
  return (
    <Plot data={traces} layout={layout} config={BASE_CONFIG} style={{ width: '100%', height: 220 }} />
  )
}

interface LabelledSelectProps {
  label: string
  value: string
  onChange: (v: string) => void
  options: Array<{ value: string; label: string }>
  width?: string
}

function LabelledSelect({ label, value, onChange, options, width }: LabelledSelectProps) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-xs text-muted-foreground">{label}</span>
      <Select value={value} onValueChange={onChange}>
        <SelectTrigger className={width ?? 'min-w-[160px]'}>
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {options.map((o) => (
            <SelectItem key={o.value} value={o.value}>
              {o.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}

function linspace(a: number, b: number, n: number): number[] {
  if (n <= 1) return [a]
  const step = (b - a) / (n - 1)
  const out = new Array<number>(n)
  for (let i = 0; i < n; i++) out[i] = a + step * i
  return out
}

function reshape(flat: number[], nx: number, ny: number): number[][] {
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
