import { useEffect, useMemo, useRef, useState } from 'react'
import * as THREE from 'three'
import { api, type Density3D } from '@/api'

export interface DensityTexture {
  meta: Density3D
  texture: THREE.Data3DTexture
  maxValue: number
}

interface AtlasState {
  run: string
  file: string
  component: number
  nx: number
  ny: number
  nz: number
  n_snaps: number
  n_comp: number
  F: number
  snaps: Float32Array[]
  maxValues: number[]   // per-snap max for normalisation
}

/**
 * 3D density texture for the volume renderer.
 *
 * Two paths share the same return shape:
 *   - angleDeg = 0 + snap defined → **atlas mode**: one
 *     /api/density3d_atlas fetch per (run, file, component); per-snap
 *     scrub reuses a single Data3DTexture (just rewrites image.data +
 *     needsUpdate). Cuts a 502-frame play loop from ~90 s of HTTP
 *     waits to a one-time ~1-2 s atlas fetch + GPU-only swaps.
 *   - angleDeg ≠ 0 or snap undefined → fall back to per-snap
 *     /api/density3d_bin. Rotation is not pre-baked into the atlas.
 *
 * Returned `loading` is true only during the initial atlas fetch (or
 * per-snap fetch in fallback mode), so the TimeScrubber's
 * loading-skip gate doesn't pause playback after the atlas is warm.
 */
export function useDensityTexture(
  run: string | null,
  file: string | null,
  component: number,
  angleDeg: number = 0,
  snap?: number,
) {
  const useAtlas = angleDeg === 0 && snap !== undefined

  const [atlas, setAtlas] = useState<{
    data: AtlasState | null
    loading: boolean
    error: string | null
  }>({ data: null, loading: false, error: null })

  const [perSnap, setPerSnap] = useState<{
    data: DensityTexture | null
    loading: boolean
    error: string | null
  }>({ data: null, loading: false, error: null })

  // Atlas fetch — fires once per (run, file, component).
  useEffect(() => {
    if (!useAtlas || !run || !file) {
      setAtlas({ data: null, loading: false, error: null })
      return
    }
    let cancelled = false
    setAtlas((s) => ({ ...s, loading: true, error: null }))
    api
      .getDensity3dAtlas(run, file, component)
      .then((d) => {
        if (cancelled) return
        // `d === null` ⇒ backend has no wavefunction atlas for this
        // run (e.g. M1 scan export). Silent "no data" — no toast.
        if (d === null) {
          setAtlas({ data: null, loading: false, error: null })
          return
        }
        const maxValues = d.snaps.map((slab) => {
          let m = 0
          for (let i = 0; i < slab.length; i++) {
            if (slab[i] > m) m = slab[i]
          }
          return m
        })
        setAtlas({
          data: {
            run,
            file,
            component: d.component,
            nx: d.nx,
            ny: d.ny,
            nz: d.nz,
            n_snaps: d.n_snaps,
            n_comp: d.n_comp,
            F: d.F,
            snaps: d.snaps,
            maxValues,
          },
          loading: false,
          error: null,
        })
      })
      .catch((e: Error) => {
        if (!cancelled) setAtlas({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [useAtlas, run, file, component])

  // Per-snap fetch — only fires in fallback mode (rotation or no snap).
  useEffect(() => {
    if (useAtlas || !run || !file) {
      setPerSnap({ data: null, loading: false, error: null })
      return
    }
    let cancelled = false
    setPerSnap((s) => ({ ...s, loading: true, error: null }))
    api
      .getDensity3d(run, file, component, angleDeg, snap)
      .then((d) => {
        if (cancelled) return
        // `d === null` ⇒ backend has no wavefunction data for this run
        // (e.g. M1 scan export). Silent "no data" — no error toast.
        if (d === null) {
          setPerSnap({ data: null, loading: false, error: null })
          return
        }
        const tex = makeTexture(d.density, d.nx, d.ny, d.nz)
        let maxValue = 0
        for (let i = 0; i < d.density.length; i++) {
          if (d.density[i] > maxValue) maxValue = d.density[i]
        }
        setPerSnap({
          data: { meta: d, texture: tex, maxValue },
          loading: false,
          error: null,
        })
      })
      .catch((e: Error) => {
        if (!cancelled) setPerSnap({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [useAtlas, run, file, component, angleDeg, snap])

  // Atlas-derived per-snap texture. Reuse a single Data3DTexture object
  // across snap changes — recreating one per frame allocates a fresh
  // GPU resource and triggers Three.js's upload path again, defeating
  // the point of preloading.
  const atlasTexRef = useRef<THREE.Data3DTexture | null>(null)
  const atlasKeyRef = useRef<string>('')

  const atlasState = useMemo<DensityTexture | null>(() => {
    if (!useAtlas) return null
    const a = atlas.data
    if (!a) return null
    const s = (snap ?? 1) - 1                // 1-indexed → 0-indexed
    if (s < 0 || s >= a.n_snaps) return null
    const slab = a.snaps[s]
    if (!slab) return null

    const key = `${a.run}|${a.file}|${a.component}|${a.nx}x${a.ny}x${a.nz}`
    let tex = atlasTexRef.current
    if (!tex || atlasKeyRef.current !== key) {
      tex = makeTexture(slab, a.nx, a.ny, a.nz)
      atlasTexRef.current = tex
      atlasKeyRef.current = key
    } else {
      // Reuse: rewrite the texture's source data and bump the version.
      // Cast through the shared `image` field — Three.js's Data3DTexture
      // typing names this `.image.data` even though the underlying value
      // is a typed array.
      ;(tex.image as { data: Float32Array }).data = slab
      tex.needsUpdate = true
    }
    return {
      meta: {
        nx: a.nx,
        ny: a.ny,
        nz: a.nz,
        n_comp: a.n_comp,
        F: a.F,
        component: a.component,
        // populations: not provided by the atlas endpoint. Caller paths
        // that depend on this field (sticky-max, color-by-phase) still
        // work because they read maxValue and component instead.
        populations: new Float32Array(0),
        density: slab,
      } as Density3D,
      texture: tex,
      maxValue: a.maxValues[s],
    }
  }, [useAtlas, atlas.data, snap])

  if (useAtlas) {
    return { data: atlasState, loading: atlas.loading, error: atlas.error }
  }
  return perSnap
}

function makeTexture(
  data: Float32Array, nx: number, ny: number, nz: number,
): THREE.Data3DTexture {
  const tex = new THREE.Data3DTexture(data, nx, ny, nz)
  tex.format = THREE.RedFormat
  tex.type = THREE.FloatType
  tex.minFilter = THREE.LinearFilter
  tex.magFilter = THREE.LinearFilter
  tex.wrapS = THREE.ClampToEdgeWrapping
  tex.wrapT = THREE.ClampToEdgeWrapping
  tex.wrapR = THREE.ClampToEdgeWrapping
  tex.unpackAlignment = 1
  tex.needsUpdate = true
  return tex
}
