import { useEffect, useRef, useState } from 'react'
import { api } from '@/api'

export interface LiveRun {
  run: string
  mtime_ms: number
  age_s: number
}

export interface LiveStatus {
  step: number
  t: number
  energy: number
  norm: number
  populations: number[]
  updated_ms: number
}

/**
 * Polls /api/live/list every `intervalMs` ms (default 3 s). Returns the
 * runs that wrote to their `_live_status.json` in the past 5 min — i.e.
 * the simulations that the dashboard should render a live progress panel
 * for. Pause when the tab is hidden to avoid waking idle backends.
 */
export function useLiveRuns(intervalMs = 3000) {
  const [runs, setRuns] = useState<LiveRun[]>([])
  const [error, setError] = useState<string | null>(null)
  const stopRef = useRef(false)

  useEffect(() => {
    stopRef.current = false
    const tick = async () => {
      if (document.hidden) return
      try {
        const list = await api.listLiveRuns()
        if (!stopRef.current) {
          setRuns(list)
          setError(null)
        }
      } catch (e) {
        if (!stopRef.current) setError((e as Error).message)
      }
    }
    void tick()
    const id = window.setInterval(tick, intervalMs)
    return () => {
      stopRef.current = true
      window.clearInterval(id)
    }
  }, [intervalMs])

  return { runs, error }
}

/**
 * Polls /api/live/<run> for the per-step status snapshot. Returns null
 * until the first poll lands or when the backend 404s.
 */
export function useLiveStatus(run: string | null, intervalMs = 1500) {
  const [status, setStatus] = useState<LiveStatus | null>(null)
  const [error, setError] = useState<string | null>(null)
  const stopRef = useRef(false)

  useEffect(() => {
    stopRef.current = false
    setStatus(null)
    setError(null)
    if (!run) return
    const tick = async () => {
      if (document.hidden) return
      try {
        const s = await api.liveStatus(run)
        if (!stopRef.current) {
          setStatus(s)
          setError(null)
        }
      } catch (e) {
        if (!stopRef.current) setError((e as Error).message)
      }
    }
    void tick()
    const id = window.setInterval(tick, intervalMs)
    return () => {
      stopRef.current = true
      window.clearInterval(id)
    }
  }, [run, intervalMs])

  return { status, error }
}
