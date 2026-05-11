import { useEffect, useRef, useState, type ChangeEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Play, Pause, Rewind, FastForward } from 'lucide-react'
import type { SnapshotsMeta } from '@/api'

interface Props {
  meta: SnapshotsMeta | null
  snapIdx: number
  onChange: (idx: number) => void
  fps?: number // playback target (ignored when durationSec is set)
  /** when true, the play loop holds the current frame instead of
   * advancing — prevents request pile-up when the backend can't keep up. */
  loading?: boolean
  /** Optional default playback duration in seconds for one full pass
   * through all snapshots. The user can override via the dropdown. */
  defaultDurationSec?: number
}

const DURATION_OPTIONS = [
  { sec: 5, label: '5 s' },
  { sec: 10, label: '10 s' },
  { sec: 20, label: '20 s' },
  { sec: 30, label: '30 s' },
  { sec: 60, label: '60 s' },
]

// Minimal time scrubber. Slider spans [1, n_snapshots] (1-indexed to match
// Julia conventions); play advances at ~fps frames/sec and wraps at the end.
export function TimeScrubber({
  meta,
  snapIdx,
  onChange,
  fps,
  loading = false,
  defaultDurationSec = 20,
}: Props) {
  const [playing, setPlaying] = useState(false)
  const [durationSec, setDurationSec] = useState<number>(defaultDurationSec)
  const timerRef = useRef<number | null>(null)
  const n = meta?.n_snapshots ?? 0
  // Effective fps: prefer fixed duration ("loop the whole sequence in
  // 20 s") over a fixed frame rate, since the absolute time elapsed in
  // the simulation per snap varies between runs.
  const effectiveFps = fps ?? (n > 0 ? n / Math.max(durationSec, 0.5) : 10)

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
    // With atlas mode the backend isn't hit per frame, so the play loop
    // is GPU-only and can comfortably run at 60 fps. Cap interval to 16 ms
    // (~60 fps) which is anyway the display refresh ceiling.
    const interval = Math.max(1000 / effectiveFps, 16)
    const id = window.setInterval(() => {
      // Skip this tick if the current frame is still loading — keeps
      // playback synced to backend throughput instead of forcing every
      // tick onto the request queue.
      if (loadingRef.current) return
      onChange((snapIdxRef.current % n) + 1)
    }, interval)
    timerRef.current = id
    return () => window.clearInterval(id)
  }, [playing, n, effectiveFps, onChange])

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
      <DebouncedRangeInput
        n={n}
        snapIdx={snapIdx}
        onChange={onChange}
      />
      <div className="text-xs text-muted-foreground tabular-nums whitespace-nowrap">
        {snapIdx} / {n}
        <span className="text-muted-foreground/70">{tFmt}</span>
      </div>
      <select
        value={String(durationSec)}
        onChange={(e) => setDurationSec(Number(e.target.value))}
        title="Loop duration (full pass)"
        className="text-xs bg-background border rounded px-1 py-0.5"
      >
        {DURATION_OPTIONS.map((o) => (
          <option key={o.sec} value={o.sec}>
            {o.label}
          </option>
        ))}
      </select>
    </div>
  )
}

interface DebouncedRangeInputProps {
  n: number
  snapIdx: number
  onChange: (idx: number) => void
}

// Drag-time slider with rAF-coalesced commits. The native <input type=range>
// fires onInput on every pixel of mouse motion (50+ events/sec); without
// debouncing each one queues a density_bin GET, and even with the loading
// gate the request log balloons. Coalescing to one commit per animation
// frame caps fetches at ~60/sec and matches the perceived smoothness of the
// drag.
function DebouncedRangeInput({ n, snapIdx, onChange }: DebouncedRangeInputProps) {
  const [local, setLocal] = useState(snapIdx)
  const rafRef = useRef<number | null>(null)
  const pendingRef = useRef<number | null>(null)

  // Mirror upstream changes (play tick, hotkey jumps) into local state.
  useEffect(() => {
    setLocal(snapIdx)
  }, [snapIdx])

  useEffect(() => () => {
    if (rafRef.current !== null) cancelAnimationFrame(rafRef.current)
  }, [])

  const handleInput = (e: ChangeEvent<HTMLInputElement>) => {
    const v = Number(e.target.value)
    setLocal(v)
    pendingRef.current = v
    if (rafRef.current === null) {
      rafRef.current = requestAnimationFrame(() => {
        rafRef.current = null
        const next = pendingRef.current
        pendingRef.current = null
        if (next !== null && next !== snapIdx) onChange(next)
      })
    }
  }

  return (
    <input
      type="range"
      min={1}
      max={n}
      step={1}
      value={local}
      onChange={handleInput}
      className="flex-1 accent-primary"
    />
  )
}
