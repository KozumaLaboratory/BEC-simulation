import { useEffect, useRef, useState } from 'react'
import { api } from '@/api'

export interface LabImage {
  name: string
  url: string
  mtime_ms: number
  size: number
}

/**
 * Polls the dashboard's lab image listing for a run, refreshing every
 * `intervalMs` ms (default 5 s — matches typical absorption-imaging
 * shot rate without hammering the backend). Returns the most-recent
 * `limit` shots in newest-first order, ready to render in the
 * LabImageOverlay React component.
 */
export function useLabImages(run: string | null, limit = 32, intervalMs = 5000) {
  const [images, setImages] = useState<LabImage[]>([])
  const [error, setError] = useState<string | null>(null)
  const stopRef = useRef(false)

  useEffect(() => {
    stopRef.current = false
    if (!run) {
      setImages([])
      setError(null)
      return
    }
    const tick = async () => {
      try {
        const list = await api.listLabImages(run, limit)
        if (!stopRef.current) {
          setImages(list)
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
  }, [run, limit, intervalMs])

  return { images, error }
}
