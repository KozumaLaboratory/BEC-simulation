import { useEffect, useRef, useState, type ChangeEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Play, Pause, Rewind, FastForward } from 'lucide-react'
import type { SnapshotsMeta } from '@/api'

interface Props {
  meta: SnapshotsMeta | null
  snapIdx: number
  onChange: (idx: number) => void
  /** Fixed frame rate (frames per real-time second). When set, overrides
   * the durationSec dropdown — used by the legacy non-snapshot viewer. */
  fps?: number
  /** When true the play loop holds the current frame instead of
   * advancing — prevents the rAF tick from racing ahead of a backend
   * that hasn't returned the next slab yet. */
  loading?: boolean
  /** Initial value for the duration dropdown (one full pass in N
   * seconds). The user can override via the dropdown. */
  defaultDurationSec?: number
}

const DURATION_OPTIONS = [
  { sec: 1, label: '1 s' },
  { sec: 3, label: '3 s' },
  { sec: 5, label: '5 s' },
  { sec: 8, label: '8 s' },
  { sec: 10, label: '10 s' },
  { sec: 15, label: '15 s' },
  { sec: 20, label: '20 s' },
]

/**
 * 1-indexed (Julia conventions) snapshot scrubber. Slider spans
 * `[1, n_snapshots]`; the play button drives a requestAnimationFrame
 * loop that hits `targetSnap = 1 + floor((elapsedSec % durationSec) /
 * durationSec * n)`. durationSec from the dropdown controls how long a
 * full pass takes. Frames are visually skipped when n/durationSec
 * exceeds the display refresh rate.
 */
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
  const n = meta?.n_snapshots ?? 0

  usePlaybackLoop({
    playing,
    n,
    durationSec,
    fps,
    loading,
    snapIdx,
    onChange,
  })

  if (!meta || meta.n_snapshots === 0) return null

  // Render a placeholder when t is missing (meta.times.length < n_snapshots,
  // observed on eu151_edh_k3_compare). Keeps the row width stable and
  // avoids layout shift of the <select> sibling at the last frame.
  const t = meta.times?.[snapIdx - 1]
  const tFmt = t !== undefined ? ` · t = ${t.toFixed(2)} ω⁻¹` : ` · t = — ω⁻¹`

  return (
    <div className="flex flex-wrap items-center gap-2 px-2 py-1.5 rounded-md border bg-card/50">
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
      <DebouncedRangeInput n={n} snapIdx={snapIdx} onChange={onChange} />
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

// --- helpers ---------------------------------------------------------

/**
 * Hold a ref synced to the latest value of `v`. Use this when an effect
 * needs to read the freshest closure but must not re-run when the value
 * changes (rAF anchors, event handlers in long-lived effects, etc).
 */
function useLatestRef<T>(v: T) {
  const ref = useRef(v)
  useEffect(() => {
    ref.current = v
  }, [v])
  return ref
}

interface PlaybackLoopArgs {
  playing: boolean
  n: number
  durationSec: number
  fps?: number
  loading: boolean
  snapIdx: number
  onChange: (idx: number) => void
}

/**
 * rAF-driven elapsed-time playback. The tick computes its target snap
 * from wall-clock so durationSec is exact regardless of display refresh
 * rate. snapIdx / loading / onChange flow through refs to keep the
 * effect deps stable — otherwise every parent render (View3D recreates
 * `setSnapIdx` inline) would cancel the rAF and re-anchor startTime,
 * freezing playback near the current frame.
 */
function usePlaybackLoop({
  playing,
  n,
  durationSec,
  fps,
  loading,
  snapIdx,
  onChange,
}: PlaybackLoopArgs) {
  const loadingRef = useLatestRef(loading)
  const snapIdxRef = useLatestRef(snapIdx)
  const onChangeRef = useLatestRef(onChange)

  useEffect(() => {
    if (!playing || n === 0) return
    let cancelled = false
    let rafId = 0
    let startTime: number | null = null

    const tick = (now: number) => {
      if (cancelled) return
      if (loadingRef.current) {
        // Initial atlas fetch in flight — hold startTime relative so the
        // elapsed-based index doesn't skip ahead while we wait.
        startTime = null
        rafId = requestAnimationFrame(tick)
        return
      }
      if (startTime === null) {
        // Anchor t=0 to the *previous* snap so play resumes from where
        // the user left it instead of jumping to frame 1.
        const startSnap = Math.max(1, snapIdxRef.current)
        startTime = now - ((startSnap - 1) / n) * durationSec * 1000
      }
      const elapsedSec = (now - startTime) / 1000
      const targetSnap = fps !== undefined
        ? (Math.floor(elapsedSec * fps) % n) + 1
        : Math.min(n, Math.floor(((elapsedSec % durationSec) / durationSec) * n) + 1)
      if (targetSnap !== snapIdxRef.current) {
        onChangeRef.current(targetSnap)
      }
      rafId = requestAnimationFrame(tick)
    }
    rafId = requestAnimationFrame(tick)
    return () => {
      cancelled = true
      if (rafId) cancelAnimationFrame(rafId)
    }
  }, [playing, n, durationSec, fps, loadingRef, snapIdxRef, onChangeRef])
}

interface DebouncedRangeInputProps {
  n: number
  snapIdx: number
  onChange: (idx: number) => void
}

/**
 * Drag-time slider with rAF-coalesced commits. The native
 * `<input type="range">` fires onInput on every pixel of mouse motion
 * (50+ events/s); without coalescing each one queued a density_bin GET
 * and the request log ballooned. One commit per animation frame caps
 * fetches at ~60/s and matches perceived drag smoothness.
 */
function DebouncedRangeInput({ n, snapIdx, onChange }: DebouncedRangeInputProps) {
  const [local, setLocal] = useState(snapIdx)
  const rafRef = useRef<number | null>(null)
  const pendingRef = useRef<number | null>(null)

  // Mirror upstream changes (play tick, hotkey jumps) into local state.
  useEffect(() => {
    setLocal(snapIdx)
  }, [snapIdx])

  useEffect(
    () => () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current)
    },
    [],
  )

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
      className="flex-1 min-w-[120px] accent-primary"
    />
  )
}
