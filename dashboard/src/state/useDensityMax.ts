import { useEffect, useState } from 'react'
import { api } from '@/api'

// Lazy fetch of the global peak total density. Returns undefined while
// loading; consumers should fall back to a per-frame max in the meantime
// so they're never stalled waiting on this.
export function useDensityMax(run: string | null, file: string | null) {
  const [value, setValue] = useState<number | undefined>(undefined)

  useEffect(() => {
    if (!run || !file) {
      setValue(undefined)
      return
    }
    let cancelled = false
    setValue(undefined)
    api
      .getDensityMax(run, file)
      .then((v) => {
        if (!cancelled) setValue(v)
      })
      .catch(() => {
        if (!cancelled) setValue(undefined)
      })
    return () => {
      cancelled = true
    }
  }, [run, file])

  return value
}
