import { useEffect, useState } from 'react'
import { api, type ColumnDensity } from '@/api'

export function useColumnDensity(
  run: string | null,
  file: string | null,
  axis: 1 | 2 | 3,
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
      .getColumnDensity(run, file, axis)
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
  }, [run, file, axis])

  return state
}
