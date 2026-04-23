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
import { useVectorField } from '@/three/useVectorField'
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

  const controls = useControls('Volume', {
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
    densityThreshold: { value: 0.05, min: 0, max: 0.5, step: 0.01 },
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
    count: { value: 3000, min: 300, max: 20000, step: 100 },
    trailLength: { value: 18, min: 2, max: 60, step: 1 },
    speed: { value: 0.08, min: 0.005, max: 0.5, step: 0.005 },
    lifespan: { value: 4.0, min: 0.5, max: 15, step: 0.1 },
    densityThreshold: { value: 0.05, min: 0, max: 0.5, step: 0.01 },
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
  )

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
  )

  const { data: vectorData, error: vectorError } = useVectorField(
    run,
    currentPoint?.file ?? null,
    vectorControls.field,
    Math.round(vectorControls.stride),
    vectorControls.show,
  )

  const { data: particleFieldData, error: particleError } = useVectorField(
    run,
    currentPoint?.file ?? null,
    particleControls.field,
    Math.round(particleControls.stride),
    particleControls.show,
  )

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
          <div className="ml-auto text-xs text-muted-foreground">
            {loading && 'Loading density…'}
            {density && !loading &&
              `${density.meta.nx}×${density.meta.ny}×${density.meta.nz} · max=${density.maxValue.toExponential(2)}`}
          </div>
        </div>

        {error && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            {error}
          </div>
        )}

        <div className="h-[600px] rounded-md overflow-hidden bg-[#0a0e14] border border-border">
          {density ? (
            <VolumeCanvas
              density={density}
              phase={phase ?? undefined}
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
              {loading ? 'Loading…' : 'No data.'}
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
