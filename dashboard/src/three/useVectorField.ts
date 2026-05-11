import { useEffect, useState } from 'react'
import { api, type VectorField3D, type VectorFieldKind } from '@/api'

export function useVectorField(
  run: string | null,
  file: string | null,
  field: VectorFieldKind,
  stride: number,
  enabled: boolean,
  snap?: number,
) {
  const [state, setState] = useState<{
    data: VectorField3D | null
    loading: boolean
    error: string | null
  }>({ data: null, loading: false, error: null })

  useEffect(() => {
    if (!enabled || !run || !file) {
      setState({ data: null, loading: false, error: null })
      return
    }
    let cancelled = false
    setState((s) => ({ ...s, loading: true, error: null }))
    api
      .getVector3d(run, file, field, stride, snap)
      .then((d) => {
        if (cancelled) return
        setState({ data: d, loading: false, error: null })
      })
      .catch((e: Error) => {
        if (!cancelled) setState({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [run, file, field, stride, enabled, snap])

  return state
}
