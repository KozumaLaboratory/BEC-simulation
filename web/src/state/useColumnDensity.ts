import { useEffect, useState } from 'react'
import { api, type ColumnDensity } from '@/api'

export function useColumnDensity(
  run: string | null,
  file: string | null,
  axis: 1 | 2 | 3,
  snap?: number,
) {
  const [state, setState] = useState<{
    data: ColumnDensity | null
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
      .getColumnDensityBin(run, file, axis, snap)
      .then((d) => {
        if (cancelled) return
        const err = (d as unknown as { error?: string }).error
        if (typeof err === 'string') {
          setState({ data: null, loading: false, error: err })
          return
        }
        setState({ data: d, loading: false, error: null })
        // Fire-and-forget prefetch so the next 2 frames are warm on the
        // server when the user keeps scrubbing forward. Cold disk reads
        // are ~30 ms; this hides them behind the current render.
        if (snap !== undefined) {
          for (const dk of [1, 2]) {
            void fetch(
              `/api/density_bin/${encodeURIComponent(run!)}/${encodeURIComponent(file!)}?axis=${axis}&snap=${snap + dk}`,
            ).catch(() => {})
          }
        }
      })
      .catch((e: Error) => {
        if (!cancelled) setState({ data: null, loading: false, error: e.message })
      })
    return () => {
      cancelled = true
    }
  }, [run, file, axis, snap])

  return state
}
