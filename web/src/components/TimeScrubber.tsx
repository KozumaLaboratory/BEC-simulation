import { useEffect, useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Play, Pause, Rewind, FastForward } from 'lucide-react'
import type { SnapshotsMeta } from '@/api'

interface Props {
  meta: SnapshotsMeta | null
  snapIdx: number
  onChange: (idx: number) => void
  fps?: number // playback target
  /** when true, the play loop holds the current frame instead of
   * advancing — prevents request pile-up when the backend can't keep up. */
  loading?: boolean
}

// Minimal time scrubber. Slider spans [1, n_snapshots] (1-indexed to match
// Julia conventions); play advances at ~fps frames/sec and wraps at the end.
export function TimeScrubber({
  meta,
  snapIdx,
  onChange,
  fps = 10,
  loading = false,
}: Props) {
  const [playing, setPlaying] = useState(false)
  const timerRef = useRef<number | null>(null)
  const n = meta?.n_snapshots ?? 0

  // Latest snapIdx + loading via refs so the play interval reads the
  // current values without being re-created on every tick.
  const snapIdxRef = useRef(snapIdx)
  const loadingRef = useRef(loading)
  useEffect(() => {
    snapIdxRef.current = snapIdx
  }, [snapIdx])
  useEffect(() => {
    loadingRef.current = loading
  }, [loading])

  useEffect(() => {
    if (!playing || n === 0) return
    // Default 10 fps — at 30 fps each tick fires another density3d_bin
    // GET (~30 ms decode + JLD2 read), so requests pile up faster than
    // they complete and the viewer freezes. 10 fps gives the backend
    // breathing room.
    const interval = Math.max(1000 / fps, 33)
    const id = window.setInterval(() => {
      // Skip this tick if the current frame is still loading — keeps
      // playback synced to backend throughput instead of forcing every
      // tick onto the request queue.
      if (loadingRef.current) return
      onChange((snapIdxRef.current % n) + 1)
    }, interval)
    timerRef.current = id
    return () => window.clearInterval(id)
  }, [playing, n, fps, onChange])

  if (!meta || meta.n_snapshots === 0) return null

  const t = meta.times?.[snapIdx - 1]
  const tFmt = t !== undefined ? ` · t = ${t.toFixed(2)} ω⁻¹` : ''

  return (
    <div className="flex items-center gap-2 px-2 py-1.5 rounded-md border bg-card/50">
      <Button
        variant="outline"
        size="icon-sm"
        onClick={() => onChange(1)}
        disabled={snapIdx <= 1}
        title="Rewind"
      >
        <Rewind />
      </Button>
      <Button
        variant={playing ? 'default' : 'outline'}
        size="icon-sm"
        onClick={() => setPlaying((p) => !p)}
        title={playing ? 'Pause' : 'Play'}
      >
        {playing ? <Pause /> : <Play />}
      </Button>
      <Button
        variant="outline"
        size="icon-sm"
        onClick={() => onChange(n)}
        disabled={snapIdx >= n}
        title="End"
      >
        <FastForward />
      </Button>
      <input
        type="range"
        min={1}
        max={n}
        step={1}
        value={snapIdx}
        onChange={(e) => onChange(Number(e.target.value))}
        className="flex-1 accent-primary"
      />
      <div className="text-xs text-muted-foreground tabular-nums whitespace-nowrap">
        {snapIdx} / {n}
        <span className="text-muted-foreground/70">{tFmt}</span>
      </div>
    </div>
  )
}
