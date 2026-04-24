import { useState, useMemo, useEffect } from 'react'
import { useControls } from 'leva'
import * as THREE from 'three'
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
import type { DashboardData, VectorFieldKind } from '@/api'
import { useDensityTexture } from '@/three/useDensityTexture'
import { usePhaseTexture } from '@/three/usePhaseTexture'
import { useVorticityTexture } from '@/three/useVorticityTexture'
import { useVectorField } from '@/three/useVectorField'
import { useSnapshots } from '@/state/useSnapshots'
import { TimeScrubber } from '@/components/TimeScrubber'
import { VolumeCanvas } from '@/three/VolumeCanvas'
import type { VolumeParams, ColorMode } from '@/three/DensityVolume'
import type { VectorFieldParams } from '@/three/VectorField'
import type { ParticleParams } from '@/three/ParticleField'

interface Props {
  run: string | null
  data: DashboardData | null
}

export function View3D({ run, data }: Props) {
  const points = data?.points ?? []
  const [pointIdx, setPointIdx] = useState(0)
  const [comp, setComp] = useState<number>(0) // 0 = total, 1..n = m-component

  const currentPoint = points[Math.min(pointIdx, points.length - 1)] ?? null

  // Snapshot scrubbing. snap === undefined means "render the final state"
  // (the pre-time-scrubber behaviour, used for non-snapshot runs).
  const { data: snapMeta } = useSnapshots(run, currentPoint?.file ?? null)
  const [snapIdx, setSnapIdx] = useState<number>(1)
  useEffect(() => {
    // Reset to the first frame when switching points or entering a run with snapshots.
    if (snapMeta && snapMeta.n_snapshots > 0) {
      setSnapIdx((prev) => Math.min(Math.max(prev, 1), snapMeta.n_snapshots))
    }
  }, [snapMeta, pointIdx])
  const snap =
    snapMeta && snapMeta.n_snapshots > 0 ? snapIdx : undefined

  const controls = useControls('Volume', {
    source: {
      value: 'density' as 'density' | 'vorticity',
      options: {
        'Density |ψ|²': 'density' as const,
        'Vorticity |∇×v_s| (渦度)': 'vorticity' as const,
      },
      label: 'Volume source',
    },
    isoMin: { value: 0.05, min: 0, max: 1, step: 0.01 },
    isoMax: { value: 0.8, min: 0, max: 1, step: 0.01 },
    stepCount: { value: 128, min: 16, max: 512, step: 8 },
    opacity: { value: 0.6, min: 0, max: 1.5, step: 0.02 },
    colorMode: {
      value: 'density' as ColorMode,
      options: {
        'Density (iso color ramp)': 'density' as ColorMode,
        'Phase arg(ψ_m) hue (needs m≥1)': 'phase' as ColorMode,
      },
      label: 'Color by',
    },
    colorLow: '#3d2d7a',
    colorHigh: '#fde725',
    phaseSaturation: { value: 1.0, min: 0, max: 1, step: 0.02 },
    tiltDeg: {
      value: 0,
      min: 0,
      max: 180,
      step: 1,
      label: 'q-axis tilt (deg)',
    },
  })

  const vectorControls = useControls('Vectors', {
    show: true,
    field: {
      value: 'current' as VectorFieldKind,
      options: {
        'Mass current j (質量流)': 'current' as VectorFieldKind,
        'Spin density ⟨F⟩ (磁化)': 'spin_density' as VectorFieldKind,
        'Superfluid velocity v=j/n': 'velocity' as VectorFieldKind,
      },
    },
    stride: { value: 8, min: 2, max: 16, step: 1 },
    arrowScale: { value: 0.9, min: 0.1, max: 4, step: 0.05 },
    densityThreshold: { value: 0.005, min: 0, max: 0.5, step: 0.005 },
    colorLow: '#0d0887',
    colorHigh: '#f0f921',
  })

  const particleControls = useControls('Particles', {
    show: false,
    field: {
      value: 'current' as VectorFieldKind,
      options: {
        'Mass current j (質量流)': 'current' as VectorFieldKind,
        'Superfluid velocity v=j/n': 'velocity' as VectorFieldKind,
      },
      label: 'Advect on',
    },
    stride: { value: 4, min: 1, max: 8, step: 1 },
    count: { value: 150, min: 10, max: 20000, step: 10 },
    trailLength: { value: 420, min: 2, max: 1200, step: 4 },
    speed: {
      value: 0.12,
      min: 0.01,
      max: 2.0,
      step: 0.005,
      label: 'speed (box/sec at peak |v|)',
    },
    lifespan: { value: 20.0, min: 0.5, max: 60, step: 0.5 },
    densityThreshold: { value: 0.005, min: 0, max: 0.5, step: 0.005 },
    color: '#ffffff',
  })

  const params = useMemo<VolumeParams>(
    () => ({
      isoMin: controls.isoMin,
      isoMax: controls.isoMax,
      stepCount: Math.round(controls.stepCount),
      opacity: controls.opacity,
      colorA: new THREE.Color(controls.colorLow),
      colorB: new THREE.Color(controls.colorHigh),
      colorMode: controls.colorMode,
      phaseSaturation: controls.phaseSaturation,
    }),
    [controls],
  )

  const vParams = useMemo<VectorFieldParams>(
    () => ({
      arrowScale: vectorControls.arrowScale,
      densityThreshold: vectorControls.densityThreshold,
      colorLow: vectorControls.colorLow,
      colorHigh: vectorControls.colorHigh,
    }),
    [vectorControls],
  )

  const { data: density, loading, error } = useDensityTexture(
    run,
    currentPoint?.file ?? null,
    comp,
    controls.tiltDeg,
    snap,
  )

  const { data: vorticity, loading: vortLoading, error: vortError } = useVorticityTexture(
    run,
    currentPoint?.file ?? null,
    controls.source === 'vorticity',
    snap,
  )

  const volumeTex = controls.source === 'vorticity' ? vorticity : density
  const volumeLoading = controls.source === 'vorticity' ? vortLoading : loading
  const volumeError = controls.source === 'vorticity' ? vortError : error

  // When the user flips to phase color mode while Component is still "Total"
  // (comp=0), auto-advance to the spinor component with the largest
  // population so they see something immediately. Don't touch their choice
  // otherwise.
  useEffect(() => {
    if (controls.colorMode !== 'phase' || comp !== 0 || !currentPoint?.populations) return
    const pops = currentPoint.populations
    let bestIdx = 0
    let bestPop = -1
    for (let i = 0; i < pops.length; i++) {
      if (pops[i] > bestPop) {
        bestPop = pops[i]
        bestIdx = i
      }
    }
    setComp(bestIdx + 1) // populations is 0-indexed per m; selector is 1-indexed (0=Total)
  }, [controls.colorMode, comp, currentPoint])

  const phaseEnabled = controls.colorMode === 'phase' && comp >= 1
  const { data: phase, error: phaseError } = usePhaseTexture(
    run,
    currentPoint?.file ?? null,
    comp,
    phaseEnabled,
    snap,
  )

  const { data: vectorData, error: vectorError } = useVectorField(
    run,
    currentPoint?.file ?? null,
    vectorControls.field,
    Math.round(vectorControls.stride),
    vectorControls.show,
    snap,
  )

  const { data: particleFieldData, error: particleError } = useVectorField(
    run,
    currentPoint?.file ?? null,
    particleControls.field,
    Math.round(particleControls.stride),
    particleControls.show,
    snap,
  )

  // Peak magnitude of whichever field is currently driving advection (or
  // showing arrows). Tells the user at a glance whether there's real flow
  // or whether they're staring at numerical noise from a stationary GS.
  const peakMag = useMemo(() => {
    const src = particleControls.show
      ? particleFieldData
      : vectorControls.show
      ? vectorData
      : null
    if (!src) return null
    let m = 0
    const n = src.nx * src.ny * src.nz
    for (let i = 0; i < n; i++) {
      const v = src.data[i * 4 + 3]
      if (v > m) m = v
    }
    return m
  }, [particleControls.show, vectorControls.show, particleFieldData, vectorData])

  const pParams = useMemo<ParticleParams>(
    () => ({
      count: Math.round(particleControls.count),
      trailLength: Math.round(particleControls.trailLength),
      speed: particleControls.speed,
      lifespan: particleControls.lifespan,
      color: particleControls.color,
      densityThreshold: particleControls.densityThreshold,
    }),
    [particleControls],
  )

  const componentOptions = useMemo(() => {
    const opts = [{ value: '0', label: 'Total' }]
    if (currentPoint?.m_values) {
      currentPoint.m_values.forEach((m, i) => {
        opts.push({ value: String(i + 1), label: `m=${m}` })
      })
    }
    return opts
  }, [currentPoint])

  if (!run) {
    return <Placeholder text="Select a run." />
  }
  if (points.length === 0) {
    return <Placeholder text="No points in run." />
  }

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
            <Select
              value={String(pointIdx)}
              onValueChange={(v) => setPointIdx(Number(v))}
            >
              <SelectTrigger className="min-w-[220px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {points.map((p, i) => (
                  <SelectItem key={i} value={String(i)}>
                    #{i + 1} — {p.file} (Mz={p.mz_actual?.toFixed?.(2) ?? '—'})
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="flex flex-col gap-1">
            <span className="text-xs text-muted-foreground">Component</span>
            <Select value={String(comp)} onValueChange={(v) => setComp(Number(v))}>
              <SelectTrigger className="min-w-[140px]">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {componentOptions.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <div className="ml-auto text-xs text-muted-foreground text-right">
            {volumeLoading &&
              (controls.source === 'vorticity' ? 'Loading vorticity…' : 'Loading density…')}
            {volumeTex && !volumeLoading && (
              <>
                <div>
                  {volumeTex.meta.nx}×{volumeTex.meta.ny}×{volumeTex.meta.nz} ·{' '}
                  {controls.source === 'vorticity' ? '|ω|' : 'n'}
                  <sub>max</sub>={volumeTex.maxValue.toExponential(2)}
                </div>
                {peakMag !== null && (
                  <div className={peakMag < 1e-10 ? 'text-amber-500' : ''}>
                    |v|<sub>peak</sub>={peakMag.toExponential(2)}
                    {peakMag < 1e-10 && ' (≈ 0, stationary state)'}
                  </div>
                )}
              </>
            )}
          </div>
        </div>

        {volumeError && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            {volumeError}
          </div>
        )}

        <div className="h-[600px] rounded-md overflow-hidden bg-[#0a0e14] border border-border">
          {volumeTex ? (
            <VolumeCanvas
              density={volumeTex}
              phase={controls.source === 'density' ? phase ?? undefined : undefined}
              params={params}
              vector={
                vectorControls.show && vectorData
                  ? { field: vectorData, params: vParams }
                  : undefined
              }
              particles={
                particleControls.show && particleFieldData
                  ? { field: particleFieldData, params: pParams }
                  : undefined
              }
            />
          ) : (
            <div className="h-full flex items-center justify-center text-muted-foreground text-sm">
              {volumeLoading ? 'Loading…' : 'No data.'}
            </div>
          )}
        </div>

        {vectorError && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            Vector field: {vectorError}
          </div>
        )}

        {particleError && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            Particles: {particleError}
          </div>
        )}

        {phaseError && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            Phase: {phaseError}
          </div>
        )}

        {controls.colorMode === 'phase' && comp === 0 && (
          <div className="rounded-md border border-amber-500/40 bg-amber-500/10 px-3 py-2 text-xs text-amber-600 dark:text-amber-400">
            Phase mode needs a specific m-component (not Total). Switch the
            Component selector above.
          </div>
        )}

        <TimeScrubber meta={snapMeta} snapIdx={snapIdx} onChange={setSnapIdx} fps={30} />
      </CardContent>
    </Card>
  )
}

function Placeholder({ text }: { text: string }) {
  return (
    <Card>
      <CardContent className="h-[600px] flex items-center justify-center text-muted-foreground">
        {text}
      </CardContent>
    </Card>
  )
}
