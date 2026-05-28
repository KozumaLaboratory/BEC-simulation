import { useCallback, useEffect, useRef, useState } from 'react'
import { api, type Tag } from '@/api'

/**
 * Catalog tags as a reactive lookup. `tagsByCid` maps a run's identity
 * (content_id == run dir name) to the human names pinned to it, so any
 * run-listing surface (SideNav index, QueuePanel) can show pills and
 * filter by tag. Resilient: a server without /api/tags yields empty maps
 * rather than throwing.
 *
 * Pass `pollMs > 0` to refresh on an interval; otherwise it loads once on
 * mount and on explicit `refresh()` (called after a tag mutation).
 */
export function useTags(pollMs = 0) {
  const [tagsByCid, setTagsByCid] = useState<Record<string, string[]>>({})
  const [allTags, setAllTags] = useState<Tag[]>([])
  const stop = useRef(false)
  const loadRef = useRef<(() => Promise<void>) | null>(null)

  useEffect(() => {
    stop.current = false
    const load = async () => {
      try {
        const tags = await api.listTags()
        if (stop.current) return
        setAllTags(tags)
        const map: Record<string, string[]> = {}
        for (const t of tags) (map[t.content_id] ??= []).push(t.name)
        setTagsByCid(map)
      } catch {
        /* old server / endpoint absent — leave maps empty */
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

  return { tagsByCid, allTags, refresh }
}
