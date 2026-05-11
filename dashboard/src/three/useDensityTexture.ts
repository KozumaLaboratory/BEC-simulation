import { useEffect, useState } from 'react'
import * as THREE from 'three'
import { api, type Density3D } from '@/api'

export interface DensityTexture {
  meta: Density3D
  texture: THREE.Data3DTexture
  maxValue: number
}

export function useDensityTexture(
  run: string | null,
  file: string | null,
  component: number,
  angleDeg: number = 0,
  snap?: number,
) {
  const [state, setState] = useState<{
    data: DensityTexture | null
    loading: boolean
    error: string | null
  }>({ data: null, loading: false, error: null })

  useEffect(() => {
    if (!run || !file) {
      setState({ data: null, loading: false, error: null })
      return
    }
    let cancelled = false
    setState((s) => ({ ...s, loading: true, error: null }))
    api
      .getDensity3d(run, file, component, angleDeg, snap)
      .then((d) => {
        if (cancelled) return
        const tex = new THREE.Data3DTexture(d.density, d.nx, d.ny, d.nz)
        tex.format = THREE.RedFormat
        tex.type = THREE.FloatType
        tex.minFilter = THREE.LinearFilter
        tex.magFilter = THREE.LinearFilter
        tex.wrapS = THREE.ClampToEdgeWrapping
        tex.wrapT = THREE.ClampToEdgeWrapping
        tex.wrapR = THREE.ClampToEdgeWrapping
        tex.unpackAlignment = 1
        tex.needsUpdate = true
        let maxValue = 0
        for (let i = 0; i < d.density.length; i++) {
          if (d.density[i] > maxValue) maxValue = d.density[i]
        }
        setState({
          data: { meta: d, texture: tex, maxValue },
          loading: false,
          error: null,
        })
      })
      .catch((e: Error) => {
        if (!cancelled) setState({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [run, file, component, angleDeg, snap])

  return state
}
