import { useEffect, useState } from 'react'
import { api, type PhaseSlice } from '@/api'

export function useColumnPhase(
  run: string | null,
  file: string | null,
  axis: 1 | 2 | 3,
  sliceIdx?: number,
  snap?: number,
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
      .getPhaseSliceBin(run, file, axis, sliceIdx, snap)
      .then((d) => {
        if (cancelled) return
        const err = (d as unknown as { error?: string }).error
        if (typeof err === 'string') {
          setState({ data: null, loading: false, error: err })
          return
        }
        setState({ data: d, loading: false, error: null })
        if (snap !== undefined) {
          const sliceArg = sliceIdx !== undefined ? `&slice=${sliceIdx}` : ''
          for (const dk of [1, 2]) {
            void fetch(
              `/api/phase_bin/${encodeURIComponent(run!)}/${encodeURIComponent(file!)}?axis=${axis}${sliceArg}&snap=${snap + dk}`,
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
  }, [run, file, axis, sliceIdx, snap])

  return state
}
