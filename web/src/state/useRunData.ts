import { useCallback, useEffect, useMemo, useState } from 'react'
import { api, type DashboardData, type PointMeta } from '@/api'

export interface RunDataState {
  runs: string[]
  selectedRun: string | null
  data: DashboardData | null
  loading: boolean
  error: string | null
  xKey: string // "index" or a scan_keys entry
  runFilter: string // "" for all
  setSelectedRun: (name: string) => void
  setXKey: (key: string) => void
  setRunFilter: (filter: string) => void
  refresh: () => void
}

export function useRunData(): RunDataState {
  const [runs, setRuns] = useState<string[]>([])
  const [selectedRun, setSelectedRun] = useState<string | null>(null)
  const [data, setData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [xKey, setXKey] = useState<string>('index')
  const [runFilter, setRunFilter] = useState<string>('')
  const [refreshToken, setRefreshToken] = useState(0)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    api
      .listRuns()
      .then((list) => {
        if (cancelled) return
        setRuns(list)
        if (list.length > 0 && !selectedRun) setSelectedRun(list[0])
        setError(null)
      })
      .catch((e: Error) => {
        if (!cancelled) setError(e.message)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refreshToken])

  useEffect(() => {
    if (!selectedRun) {
      setData(null)
      return
    }
    let cancelled = false
    setLoading(true)
    api
      .getRunData(selectedRun)
      .then((d) => {
        if (cancelled) return
        setData(d)
        setError(null)
      })
      .catch((e: Error) => {
        if (!cancelled) setError(e.message)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [selectedRun, refreshToken])

  const refresh = useCallback(() => {
    api.refresh().finally(() => setRefreshToken((n) => n + 1))
  }, [])

  return {
    runs,
    selectedRun,
    data,
    loading,
    error,
    xKey,
    runFilter,
    setSelectedRun,
    setXKey,
    setRunFilter,
    refresh,
  }
}

export function getX(point: PointMeta, xKey: string): number {
  if (xKey === 'index') return point.index
  const v = point.override?.[xKey]
  return typeof v === 'number' ? v : point.index
}

export function filterPoints(data: DashboardData | null, runFilter: string): PointMeta[] {
  if (!data) return []
  return runFilter ? data.points.filter((p) => p.run_name === runFilter) : data.points
}

export function useGroupedPoints(data: DashboardData | null, runFilter: string) {
  return useMemo(() => {
    if (!data) return {} as Record<string, PointMeta[]>
    const runNames = data.run_names ?? []
    if (runFilter || runNames.length === 0) {
      return { '': filterPoints(data, runFilter) }
    }
    const groups: Record<string, PointMeta[]> = {}
    for (const rn of runNames) {
      groups[rn] = data.points.filter((p) => p.run_name === rn)
    }
    return groups
  }, [data, runFilter])
}
