import { useEffect, useState } from 'react'
import { api, type PhaseSlice } from '@/api'

export function useColumnPhase(
  run: string | null,
  file: string | null,
  axis: 1 | 2 | 3,
  sliceIdx?: number,
) {
  const [state, setState] = useState<{
    data: PhaseSlice | null
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
      .getPhaseSlice(run, file, axis, sliceIdx)
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
  }, [run, file, axis, sliceIdx])

  return state
}
