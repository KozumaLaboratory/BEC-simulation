import { useEffect, useRef, useState } from 'react'
import { Button } from '@/components/ui/button'
import { Play, Pause, Rewind, FastForward } from 'lucide-react'
import type { SnapshotsMeta } from '@/api'

interface Props {
  meta: SnapshotsMeta | null
  snapIdx: number
  onChange: (idx: number) => void
  fps?: number // playback target
}

// Minimal time scrubber. Slider spans [1, n_snapshots] (1-indexed to match
// Julia conventions); play advances at ~fps frames/sec and wraps at the end.
export function TimeScrubber({ meta, snapIdx, onChange, fps = 30 }: Props) {
  const [playing, setPlaying] = useState(false)
  const timerRef = useRef<number | null>(null)
  const n = meta?.n_snapshots ?? 0

  useEffect(() => {
    if (!playing || n === 0) return
    const interval = Math.max(1000 / fps, 16) // cap at ~60 fps max in practice
    const id = window.setInterval(() => {
      onChange(((snapIdx - 1 + 1) % n) + 1)
    }, interval)
    timerRef.current = id
    return () => window.clearInterval(id)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playing, n, fps, snapIdx])

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
