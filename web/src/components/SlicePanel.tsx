import { useEffect, useState, useMemo } from 'react'
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
import { useColumnDensityAtlas } from '@/state/useColumnDensityAtlas'
import { useColumnPhase } from '@/state/useColumnPhase'
import { useSnapshots } from '@/state/useSnapshots'
import { useDashboardURL } from '@/state/useDashboardURL'
import { TimeScrubber } from '@/components/TimeScrubber'
import { HeatmapGrid, type HeatmapPanelSpec } from '@/components/HeatmapGrid'

interface Props {
  run: string | null
  data: DashboardData | null
}

type Axis = 1 | 2 | 3
type Mode = 'density' | 'phase'
type PanelMode = 'total' | 'total_selected' | 'all'

const AXIS_LABEL: Record<Axis, string> = {
  3: 'xy plane (z integrate/slice)',
  2: 'xz plane (y integrate/slice)',
  1: 'yz plane (x integrate/slice)',
}

function maxF32(a: Float32Array): number {
  let m = 0
  for (let i = 0; i < a.length; i++) {
    if (a[i] > m) m = a[i]
  }
  return m
}

// Unified per-m 2D grid — switches between column density and phase slice.
// Hot path is time-scrubber playback: keep a single (Total + selected m)
// pair on screen by default so each snap only repaints two heatmaps; the
// "All" mode is opt-in for inspecting every spinor component side by side.
export function SlicePanel({ run, data }: Props) {
  const points = data?.points ?? []
  const [pointIdx, setPointIdx] = useState(0)
  const [axis, setAxis] = useState<Axis>(3)
  const [mode, setMode] = useState<Mode>('density')
  const [scaleMode, setScaleMode] = useState<'shared' | 'individual'>('shared')
  const [densityMaskFrac, setDensityMaskFrac] = useState<number>(0.01)
  const [panelMode, setPanelMode] = useState<PanelMode>('total_selected')
  const [selectedM, setSelectedM] = useState<number>(0)

  const currentPoint = points[Math.min(pointIdx, points.length - 1)] ?? null

  // Time-scrubber state. snap lives on the URL (shared with View3D and the
  // global ←/→ hotkeys); for non-snapshot runs snap stays undefined and the
  // backend serves the final state, matching pre-scrubber behaviour.
  const [url, setUrl] = useDashboardURL()
  const { data: snapMeta } = useSnapshots(run, currentPoint?.file ?? null)
  const snapIdx = url.snap ?? 1
  const setSnapIdx = (n: number) => setUrl({ snap: n })
  useEffect(() => {
    if (snapMeta && snapMeta.n_snapshots > 0 && url.snap === null) {
      setUrl({ snap: 1 })
    }
  }, [snapMeta, url.snap, setUrl])
  const snap = snapMeta && snapMeta.n_snapshots > 0 ? snapIdx : undefined

  // Density atlas: when the run has snapshots, bulk-fetch every snap up
  // front so the scrubber becomes a pure GPU uniform write — no HTTP, no
  // decode, no React re-render. The single-snap useColumnDensity stays as
  // a fallback for snapshot-less runs (and phase mode below).
  const useAtlas =
    mode === 'density' && (snapMeta?.n_snapshots ?? 0) > 0
  const atlas = useColumnDensityAtlas(
    useAtlas ? run : null,
    useAtlas ? currentPoint?.file ?? null : null,
    axis,
    useAtlas ? snapMeta!.n_snapshots : 0,
  )

  const {
    data: colDens,
    loading: densLoading,
    error: densError,
  } = useColumnDensity(
    mode === 'density' && !useAtlas ? run : null,
    mode === 'density' && !useAtlas ? currentPoint?.file ?? null : null,
    axis,
    snap,
  )
  const {
    data: phaseData,
    loading: phaseLoading,
    error: phaseError,
  } = useColumnPhase(
    mode === 'phase' ? run : null,
    mode === 'phase' ? currentPoint?.file ?? null : null,
    axis,
    undefined,
    snap,
  )

  const loading = mode === 'density'
    ? useAtlas
      ? !atlas.ready
      : densLoading
    : phaseLoading
  const error = mode === 'density' ? densError : phaseError

  // Heatmap2D doesn't need explicit x/y coordinate arrays — it renders a
  // textured plane that fills its container — so we only need the axis
  // labels for the corner annotations.
  const axisLabels =
    mode === 'density'
      ? useAtlas && atlas.ready
        ? atlas.axisLabels
        : colDens?.axis_labels ?? ['x', 'y']
      : mode === 'phase' && phaseData
        ? phaseData.axis_labels
        : ['x', 'y']

  type PanelData = {
    title: string
    z: Float32Array
    nx: number
    ny: number
    /** When > 1, `z` is an atlas of this many frames stacked; the
     * HeatmapGrid shader picks the active slab via `atlasFrame`. */
    atlasFrames?: number
    atlasFrame?: number
    zmin: number
    zmax: number
    colormap: 'viridis' | 'phase'
    /** Density mask for phase panels — Heatmap2D shader discards cells
     * where mask.data < threshold. */
    mask?: { data: Float32Array; threshold: number }
  }

  const allPanels = useMemo<PanelData[]>(() => {
    // Atlas mode: every snap pre-loaded; per-frame change is a single
    // GPU uniform write. Allocations (max scan, panels array) happen
    // ONCE per (run, file, axis), not per scrub frame.
    if (mode === 'density' && useAtlas && atlas.ready && atlas.totalAtlas) {
      const { nx, ny, m_values, totalAtlas, componentAtlases, total } = atlas
      // Compute per-component maxima from the entire atlas — the
      // colourbar otherwise jumps as the user scrubs into a frame with
      // a hotter peak.
      const perMax = componentAtlases.map(maxF32)
      const totalMax = maxF32(totalAtlas)
      const sharedMax =
        scaleMode === 'shared'
          ? Math.max(totalMax, perMax.reduce((a, b) => (a > b ? a : b), 0))
          : null
      const frame = Math.max(0, snapIdx - 1)
      const out: PanelData[] = []
      out.push({
        title: 'Total',
        z: totalAtlas,
        nx,
        ny,
        atlasFrames: total,
        atlasFrame: frame,
        zmin: 0,
        zmax: sharedMax ?? totalMax,
        colormap: 'viridis',
      })
      m_values.forEach((m, i) => {
        out.push({
          title: `m=${m}`,
          z: componentAtlases[i],
          nx,
          ny,
          atlasFrames: total,
          atlasFrame: frame,
          zmin: 0,
          zmax: sharedMax ?? perMax[i],
          colormap: 'viridis',
        })
      })
      return out
    }
    // Single-frame mode (no snapshots, or phase) — per-scrub HTTP fetch
    // path retained for backward compatibility.
    if (mode === 'density' && colDens) {
      const [nx, ny] = colDens.shape
      const perMax = colDens.densities.map(maxF32)
      const totalMax = maxF32(colDens.total_density)
      const sharedMax =
        scaleMode === 'shared'
          ? Math.max(totalMax, perMax.reduce((a, b) => (a > b ? a : b), 0))
          : null
      const out: PanelData[] = []
      out.push({
        title: 'Total',
        z: colDens.total_density,
        nx,
        ny,
        zmin: 0,
        zmax: sharedMax ?? totalMax,
        colormap: 'viridis',
      })
      colDens.m_values.forEach((m, i) => {
        out.push({
          title: `m=${m}`,
          z: colDens.densities[i],
          nx,
          ny,
          zmin: 0,
          zmax: sharedMax ?? perMax[i],
          colormap: 'viridis',
        })
      })
      return out
    }
    if (mode === 'phase' && phaseData) {
      const [nx, ny] = phaseData.shape
      const globalMaxN = Math.max(
        ...phaseData.densities.map(maxF32),
        1e-300,
      )
      const threshold = densityMaskFrac * globalMaxN
      return phaseData.m_values.map((m, i) => ({
        title: `m=${m}`,
        z: phaseData.phases[i],
        nx,
        ny,
        zmin: -Math.PI,
        zmax: Math.PI,
        colormap: 'phase' as const,
        mask: { data: phaseData.densities[i], threshold },
      }))
    }
    return []
  }, [mode, colDens, phaseData, scaleMode, densityMaskFrac, useAtlas, atlas, snapIdx])

  // Filter to the requested panel count. The filtering is cheap and lives
  // in its own useMemo so changing panelMode doesn't recompute reshape().
  const panels = useMemo<PanelData[]>(() => {
    if (panelMode === 'all') return allPanels
    if (panelMode === 'total' || mode === 'phase') {
      // phase has no Total; just show the first m when in 'total' mode
      return allPanels.slice(0, 1)
    }
    // total_selected: Total + selected m (density only)
    const total = allPanels[0]
    if (!total) return []
    const idx = Math.min(Math.max(0, selectedM), Math.max(0, allPanels.length - 2))
    const sel = allPanels[idx + 1]
    return sel ? [total, sel] : [total]
  }, [allPanels, panelMode, selectedM, mode])

  const sizeInfo =
    mode === 'density'
      ? colDens && `${colDens.shape[0]}×${colDens.shape[1]}`
      : phaseData && `slice #${phaseData.slice_index} / ${phaseData.shape.join('×')}`

  const m_values =
    mode === 'density'
      ? colDens?.m_values ?? []
      : phaseData?.m_values ?? []

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
          <LabelledSelect
            label="Panels"
            value={panelMode}
            onChange={(v) => setPanelMode(v as PanelMode)}
            options={[
              { value: 'total', label: 'Total only' },
              { value: 'total_selected', label: 'Total + selected m' },
              { value: 'all', label: 'All components' },
            ]}
            width="min-w-[200px]"
          />
          {panelMode === 'total_selected' && m_values.length > 0 && (
            <LabelledSelect
              label="m"
              value={String(selectedM)}
              onChange={(v) => setSelectedM(Number(v))}
              options={m_values.map((m, i) => ({ value: String(i), label: `m=${m}` }))}
              width="min-w-[120px]"
            />
          )}
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

        {snapMeta && snapMeta.n_snapshots > 0 && (
          <TimeScrubber
            meta={snapMeta}
            snapIdx={snapIdx}
            onChange={setSnapIdx}
            loading={loading}
          />
        )}

        {(() => {
          // Total (spin-summed) is conceptually different from per-m
          // panels: it's the physical mass density, the m's are its
          // breakdown. Render Total full-width on top so it doesn't get
          // visually lumped into the per-m grid (which previously made it
          // look like Total had "moved" when switching panel modes).
          const totalIsFirst =
            panels.length > 0 && panels[0].title === 'Total'
          const specs: HeatmapPanelSpec[] = panels.map((p) => ({
            id: p.title,
            title: p.title,
            atlasFrames: p.atlasFrames,
            atlasFrame: p.atlasFrame,
            data: p.z,
            nx: p.nx,
            ny: p.ny,
            zmin: p.zmin,
            zmax: p.zmax,
            colormap: p.colormap,
            mask: p.mask,
          }))
          const mCount = specs.length - (totalIsFirst ? 1 : 0)
          const cols: 1 | 2 | 4 = mCount <= 1 ? 1 : mCount <= 2 ? 2 : 4
          const rowHeight = mCount > 4 ? 180 : 220
          return (
            <HeatmapGrid
              panels={specs}
              cols={cols}
              rowHeight={rowHeight}
              firstFull={totalIsFirst}
              totalHeight={280}
              axisLabels={[axisLabels[0] ?? 'x', axisLabels[1] ?? 'y']}
            />
          )
        })()}
      </CardContent>
    </Card>
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

