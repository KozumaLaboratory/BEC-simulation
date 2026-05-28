import { useCallback, useEffect, useRef, useState } from 'react'
import { api, type CatalogRow } from '@/api'

/**
 * The catalog index (`/api/index`) as a reactive array. Loads once on
 * mount; `refresh()` re-pulls (e.g. after a backfill). The whole array is
 * held client-side so faceting + parallel-coordinates filter with zero
 * round-trips — fine until the row count outgrows a single payload
 * (~10^4), at which point the server query layer (DuckDB) graduates in.
 */
export function useCatalogIndex(pollMs = 0) {
  const [rows, setRows] = useState<CatalogRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const stop = useRef(false)
  const loadRef = useRef<(() => Promise<void>) | null>(null)

  useEffect(() => {
    stop.current = false
    const load = async () => {
      try {
        const r = await api.catalogIndex()
        if (!stop.current) {
          setRows(r)
          setError(null)
        }
      } catch (e) {
        if (!stop.current) setError((e as Error).message)
      } finally {
        if (!stop.current) setLoading(false)
      }
    }
    loadRef.current = load
    void load()
    let id: number | undefined
    if (pollMs > 0) id = window.setInterval(() => void load(), pollMs)
    return () => {
      stop.current = true
      if (id) window.clearInterval(id)
    }
  }, [pollMs])

  const refresh = useCallback(() => {
    void loadRef.current?.()
  }, [])

  return { rows, loading, error, refresh }
}
