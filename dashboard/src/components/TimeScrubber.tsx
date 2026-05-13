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
  const n = meta?.n_snapshots ?? 0

  // Latest snapIdx + loading via refs so the rAF loop reads the
  // current values without being re-created on every tick.
  const snapIdxRef = useRef(snapIdx)
  const loadingRef = useRef(loading)
  useEffect(() => {
    snapIdxRef.current = snapIdx
  }, [snapIdx])
  useEffect(() => {
    loadingRef.current = loading
  }, [loading])

  // rAF-driven elapsed-time loop. durationSec means "one full pass in N
  // seconds, exactly" — the loop computes the target snap from elapsed
  // wall-clock instead of advancing by `+1` per tick. Visual smoothness
  // is capped by the display refresh rate (frames are skipped when
  // n / durationSec exceeds the display fps), but the playback wall
  // duration matches the dropdown value precisely. The legacy fps prop
  // takes precedence if supplied (fixed frame rate for non-snapshot
  // viewers).
  useEffect(() => {
    if (!playing || n === 0) return
    let cancelled = false
    let rafId = 0
    let startTime: number | null = null

    const tick = (now: number) => {
      if (cancelled) return
      if (loadingRef.current) {
        // Initial atlas fetch is in flight — hold startTime relative so
        // the elapsed-based index doesn't skip ahead while we wait.
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
      let targetSnap: number
      if (fps !== undefined) {
        // Legacy fixed-rate path — snap = 1 + floor(elapsedSec * fps), wrap.
        targetSnap = ((Math.floor(elapsedSec * fps)) % n) + 1
      } else {
        const cycleSec = elapsedSec % durationSec
        targetSnap = Math.min(n, Math.floor((cycleSec / durationSec) * n) + 1)
      }
      if (targetSnap !== snapIdxRef.current) {
        onChange(targetSnap)
      }
      rafId = requestAnimationFrame(tick)
    }
    rafId = requestAnimationFrame(tick)
    return () => {
      cancelled = true
      if (rafId) cancelAnimationFrame(rafId)
    }
  }, [playing, n, durationSec, fps, onChange])

  if (!meta || meta.n_snapshots === 0) return null

  const t = meta.times?.[snapIdx - 1]
  // Render a placeholder when t is missing (happens when meta.times.length
  // < n_snapshots — observed on eu151_edh_k3_compare where snap 18 has no
  // dynamics/times entry). Keeps the row width stable and avoids layout
  // shift of the <select> sibling at the last frame.
  const tFmt = t !== undefined
    ? ` · t = ${t.toFixed(2)} ω⁻¹`
    : ` · t = — ω⁻¹`

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
