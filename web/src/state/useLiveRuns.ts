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

export interface ScanStatus {
  completed: number
  expected: number | null
  latest_mtime_s: number | null
  eta_s: number | null
}

/**
 * Polls /api/scan_status/<run> for "N points done out of M, ETA T" data.
 * Lower frequency than useLiveStatus (default 10 s) — point files land
 * minutes apart on a real scan; spamming the listing every second is wasteful.
 */
export function useScanStatus(run: string | null, intervalMs = 10_000) {
  const [status, setStatus] = useState<ScanStatus | null>(null)
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
        const s = await api.scanStatus(run)
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

/**
 * Polls /api/live/<run> for the per-step status snapshot. Returns the
 * latest status plus a ring buffer of the last `historyLen` snapshots
 * (drop oldest when full) so the UI can render trend sparklines for
 * energy / norm without re-fetching anything. Identical timestamps
 * (`updated_ms`) are deduped so polling faster than the backend writes
 * doesn't pad the history with copies.
 */
export function useLiveStatus(
  run: string | null,
  intervalMs = 1500,
  historyLen = 120,
) {
  const [status, setStatus] = useState<LiveStatus | null>(null)
  const [history, setHistory] = useState<LiveStatus[]>([])
  const [error, setError] = useState<string | null>(null)
  const stopRef = useRef(false)
  const lastUpdatedRef = useRef<number | null>(null)

  useEffect(() => {
    stopRef.current = false
    setStatus(null)
    setHistory([])
    setError(null)
    lastUpdatedRef.current = null
    if (!run) return
    const tick = async () => {
      if (document.hidden) return
      try {
        const s = await api.liveStatus(run)
        if (stopRef.current) return
        setError(null)
        setStatus(s)
        if (s.updated_ms !== lastUpdatedRef.current) {
          lastUpdatedRef.current = s.updated_ms
          setHistory((prev) => {
            const next = prev.length >= historyLen ? prev.slice(1) : prev.slice()
            next.push(s)
            return next
          })
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
  }, [run, intervalMs, historyLen])

  return { status, history, error }
}
