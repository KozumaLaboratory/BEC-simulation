import { useEffect, useState } from 'react'
import { api, type SnapshotsMeta } from '@/api'

// Probe /api/snapshots for a given run/point. Returns n_snapshots=0 for
// runs that weren't generated with save_psi_snapshots:true, which the UI
// uses to decide whether to show the time-scrubber at all.
export function useSnapshots(run: string | null, file: string | null) {
  const [state, setState] = useState<{
    data: SnapshotsMeta | null
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
      .getSnapshots(run, file)
      .then((d) => {
        if (!cancelled) setState({ data: d, loading: false, error: null })
      })
      .catch((e: Error) => {
        if (!cancelled) setState({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [run, file])

  return state
}
