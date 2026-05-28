import { useEffect, useState } from 'react'
import { api, type DynamicsSeries } from '@/api'

// Fetch dynamics/* scalar + per-m time series for a single run/point.
// Returns has_dynamics=false for ground-state-only runs (no dynamics
// block), which the Overview uses to decide between the time-series view
// and the per-point scan view.
export function useDynamicsSeries(run: string | null, file: string | null) {
  const [state, setState] = useState<{
    data: DynamicsSeries | null
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
      .getDynamicsSeries(run, file)
      .then((d) => {
        if (!cancelled) setState({ data: d, loading: false, error: null })
      })
      .catch((e: Error) => {
        if (!cancelled)
          setState({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [run, file])

  return state
}
