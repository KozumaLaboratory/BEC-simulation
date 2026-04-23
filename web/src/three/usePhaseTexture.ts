import { useEffect, useState } from 'react'
import * as THREE from 'three'
import { api, type Phase3D } from '@/api'

export interface PhaseTexture {
  meta: Phase3D
  texture: THREE.Data3DTexture
}

export function usePhaseTexture(
  run: string | null,
  file: string | null,
  component: number,
  enabled: boolean,
) {
  const [state, setState] = useState<{
    data: PhaseTexture | null
    loading: boolean
    error: string | null
  }>({ data: null, loading: false, error: null })

  useEffect(() => {
    // Phase only defined per-m; skip when disabled or component is Total (0).
    if (!enabled || !run || !file || component < 1) {
      setState({ data: null, loading: false, error: null })
      return
    }
    let cancelled = false
    setState((s) => ({ ...s, loading: true, error: null }))
    api
      .getPhase3d(run, file, component)
      .then((p) => {
        if (cancelled) return
        const tex = new THREE.Data3DTexture(p.phase, p.nx, p.ny, p.nz)
        tex.format = THREE.RedFormat
        tex.type = THREE.FloatType
        tex.minFilter = THREE.LinearFilter
        tex.magFilter = THREE.LinearFilter
        tex.wrapS = THREE.ClampToEdgeWrapping
        tex.wrapT = THREE.ClampToEdgeWrapping
        tex.wrapR = THREE.ClampToEdgeWrapping
        tex.unpackAlignment = 1
        tex.needsUpdate = true
        setState({ data: { meta: p, texture: tex }, loading: false, error: null })
      })
      .catch((e: Error) => {
        if (!cancelled) setState({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [run, file, component, enabled])

  return state
}
