import { useEffect, useState } from 'react'
import { api, type VortexLinesResponse } from '@/api'

export function useVortexLines(
  run: string | null,
  file: string | null,
  enabled: boolean,
  snap?: number,
  mask = 0.01,
) {
  const [state, setState] = useState<{
    data: VortexLinesResponse | null
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
      .getVortexLines(run, file, snap, mask)
      .then((d) => {
        if (cancelled) return
        const err = (d as unknown as { error?: string }).error
        if (typeof err === 'string') {
          setState({ data: null, loading: false, error: err })
          return
        }
        setState({ data: d, loading: false, error: null })
      })
      .catch((e: Error) => {
        if (!cancelled) setState({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [run, file, enabled, snap, mask])

  return state
}
