import { useMemo, useEffect } from 'react'
import { useDashboardURL } from '@/state/useDashboardURL'
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
import { useRef } from 'react'
import type CameraControlsImpl from 'camera-controls'
import { CAMERA_PRESETS } from '@/three/CameraRig'
import { CameraPresetBar } from '@/components/CameraPresetBar'
import { useDensityTexture } from '@/three/useDensityTexture'
import { usePhaseTexture } from '@/three/usePhaseTexture'
import { useVorticityTexture } from '@/three/useVorticityTexture'
import { useVectorField } from '@/three/useVectorField'
import { useVortexLines } from '@/three/useVortexLines'
import { useSnapshots } from '@/state/useSnapshots'
import { useDensityMax } from '@/state/useDensityMax'
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
  const [url, setUrl] = useDashboardURL()
  const pointIdx = Math.min(Math.max(url.point, 0), Math.max(0, points.length - 1))
  const setPointIdx = (updater: number | ((n: number) => number)) => {
    const next = typeof updater === 'function' ? updater(pointIdx) : updater
    setUrl({ point: next, snap: null })
  }
  const comp = Math.max(0, url.comp)
  const setComp = (n: number) => setUrl({ comp: n })

  const currentPoint = points[Math.min(pointIdx, points.length - 1)] ?? null

  // Snapshot scrubbing. snap === undefined means "render the final state"
  // (the pre-time-scrubber behaviour, used for non-snapshot runs).
  const { data: snapMeta } = useSnapshots(run, currentPoint?.file ?? null)
  // density_max moved to its own lazy endpoint so /api/snapshots stays
  // instant; the value lands a few hundred ms later and the volume
  // renderer falls back to its sticky-max in the meantime.
  const densityMax = useDensityMax(run, currentPoint?.file ?? null)
  const snapIdx = url.snap ?? 1
  const setSnapIdx = (n: number) => setUrl({ snap: n })
  useEffect(() => {
    if (snapMeta && snapMeta.n_snapshots > 0 && url.snap === null) {
      setUrl({ snap: 1 })
    }
  }, [snapMeta, url.snap, setUrl])
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
    // Default isoMin is small (0.5% of peak) so frames whose peak density
    // is well below the run-global maximum — e.g. the t=0 GS in a run that
    // later sharpens via dipolar self-focusing — still render visibly.
    // The full bulk of a TF cloud sits between ~5% and ~50% of its
    // own peak; with global normalisation a 30× peak ratio across the
    // run would otherwise hide every "early" frame at the legacy 5%
    // default. User can still raise it to highlight just the dense core.
    isoMin: { value: 0.005, min: 0, max: 1, step: 0.005 },
    isoMax: { value: 0.5, min: 0, max: 1, step: 0.01 },
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

  const vortexControls = useControls('Vortex lines', {
    // Off by default — extract_vortex_lines_per_m runs on every snap
    // change (cached server-side after the first hit, but still adds
    // ~100-300 ms latency per fresh frame). Toggle on after the time
    // scrubber feels responsive.
    show: false,
    mask: { value: 0.01, min: 0, max: 0.5, step: 0.005, label: 'density mask' },
    thickness: { value: 0.012, min: 0.001, max: 0.1, step: 0.001 },
    colorByCharge: { value: false, label: 'color by charge (vs m)' },
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
    count: { value: 120, min: 10, max: 5000, step: 20 },
    trailLength: { value: 300, min: 2, max: 1000, step: 10 },
    speed: {
      value: 0.18,
      min: 0.01,
      max: 2.0,
      step: 0.005,
      label: 'speed (box/sec at peak |v|)',
    },
    lifespan: { value: 12.0, min: 0.5, max: 60, step: 0.5 },
    densityThreshold: { value: 0.005, min: 0, max: 0.5, step: 0.005 },
    color: '#ffe0a0',
    seedMode: {
      value: 'vortex_shell' as 'density' | 'vortex_shell',
      options: {
        'Density-weighted (whole cloud)': 'density' as const,
        'Vortex-line shell (orbit cores)': 'vortex_shell' as const,
      },
      label: 'seed location',
    },
    vortexShellRadius: {
      value: 0.1,
      min: 0.005,
      max: 0.3,
      step: 0.005,
      label: 'shell radius (box units)',
    },
    azimuthalOnly: {
      value: false,
      label: 'orbit only (drops radial/axial — cheat toggle)',
    },
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

  const rawVolumeTex = controls.source === 'vorticity' ? vorticity : density
  const volumeLoading = controls.source === 'vorticity' ? vortLoading : loading
  const volumeError = controls.source === 'vorticity' ? vortError : error

  // --- Stable normalisation -------------------------------------------------
  //
  // Per-frame max changes through dynamics (spin redistribution, breathing,
  // etc.) so DensityVolume normalising on it makes the visible cloud appear
  // to grow/shrink. Two strategies, in priority order:
  //
  //   1. **Global max from server** (snapMeta.density_max_total): physically
  //      correct for total density — every frame renders against the same
  //      absolute scale, computed once by the dashboard from all snapshots.
  //      Only valid when comp=0 (spin-summed) and source=density.
  //   2. **Sticky max** fallback: track running max across visited frames
  //      for per-component or vorticity views where the server can't
  //      precompute a single scale.
  const stickyMaxRef = useRef<{ key: string; value: number }>({
    key: '',
    value: 0,
  })
  const stickyKey = `${run ?? ''}|${currentPoint?.file ?? ''}|${controls.source}|${comp}`
  if (stickyMaxRef.current.key !== stickyKey) {
    stickyMaxRef.current = { key: stickyKey, value: 0 }
  }
  if (rawVolumeTex && rawVolumeTex.maxValue > stickyMaxRef.current.value) {
    stickyMaxRef.current.value = rawVolumeTex.maxValue
  }
  // Prefer the lazy /api/density_max value once it arrives; the legacy
  // snapMeta.density_max_total field is kept for backward compat with
  // older dashboards that still emit it inline.
  const globalMax = densityMax ?? snapMeta?.density_max_total
  const useGlobalMax =
    controls.source === 'density' && comp === 0 && typeof globalMax === 'number'
  const stableMax = useGlobalMax
    ? (globalMax as number)
    : stickyMaxRef.current.value
  const volumeTex =
    rawVolumeTex && stableMax > 0
      ? { ...rawVolumeTex, maxValue: stableMax }
      : rawVolumeTex

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
  const cameraRef = useRef<CameraControlsImpl | null>(null)
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

  const { data: vortexData, error: vortexError } = useVortexLines(
    run,
    currentPoint?.file ?? null,
    vortexControls.show,
    snap,
    vortexControls.mask,
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
      seedMode: particleControls.seedMode,
      vortexShellRadius: particleControls.vortexShellRadius,
      azimuthalOnly: particleControls.azimuthalOnly,
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

        <div className="relative h-[600px] rounded-md overflow-hidden bg-[#0a0e14] border border-border">
          <CameraPresetBar
            controlsRef={cameraRef}
            onReset={() => {
              const p = CAMERA_PRESETS.iso
              cameraRef.current?.setLookAt(p[0], p[1], p[2], 0, 0, 0, true)
            }}
          />
          {volumeTex ? (
            <VolumeCanvas
              ref={cameraRef}
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
                  ? {
                      field: particleFieldData,
                      params: pParams,
                      vortexLines: vortexData ?? undefined,
                    }
                  : undefined
              }
              vortexLines={
                vortexControls.show && vortexData
                  ? {
                      data: vortexData,
                      thickness: vortexControls.thickness,
                      colorByCharge: vortexControls.colorByCharge,
                    }
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

        {vortexError && (
          <div className="rounded-md border border-destructive/50 bg-destructive/10 px-3 py-2 text-xs text-destructive">
            Vortex lines: {vortexError}
          </div>
        )}

        {vortexData && vortexControls.show && (
          <div className="text-xs text-muted-foreground">
            Vortex lines: {vortexData.n_lines} polyline{vortexData.n_lines === 1 ? '' : 's'}
            {vortexData.lines.length > 0 && (
              <span className="ml-2">
                ({Array.from(new Set(vortexData.lines.map((l) => l.m))).sort().join(', ')})
              </span>
            )}
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

        <TimeScrubber
          meta={snapMeta}
          snapIdx={snapIdx}
          onChange={setSnapIdx}
          fps={10}
          loading={loading}
        />
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
