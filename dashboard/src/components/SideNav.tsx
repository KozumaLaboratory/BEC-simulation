import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Search, RefreshCw, Keyboard, Sun, Moon } from 'lucide-react'
import { useLiveRuns, useLiveStatus } from '@/state/useLiveRuns'
import type { RunDataState } from '@/state/useRunData'

interface Props {
  state: RunDataState
  isDark: boolean
  width: number
  onResize: (w: number) => void
  onShortcuts: () => void
  onToggleTheme: () => void
}

const DEFAULT_WIDTH = 280

/**
 * Sidebar = "index sheet" of the drafting set.
 *   ── PROJECT  spinorbec / dashboard
 *   ── INDEX    01 ........ eu151_edh
 *               02 ........ mz_scan
 *   ── LIVE     • streaming runs
 *   ── FOOTER   refresh + total
 */
export function SideNav({
  state,
  isDark,
  width,
  onResize,
  onShortcuts,
  onToggleTheme,
}: Props) {
  const { runs, selectedRun, setSelectedRun, refresh } = state
  const [q, setQ] = useState('')
  const { runs: liveRuns } = useLiveRuns()
  const liveStatus = useLiveStatus(selectedRun)
  const dragging = useRef(false)

  const liveSet = useMemo(
    () => new Set(liveRuns.map((r) => r.run)),
    [liveRuns],
  )

  const filteredRuns = useMemo(() => {
    if (!q.trim()) return runs
    const needle = q.toLowerCase()
    return runs.filter((r) => r.toLowerCase().includes(needle))
  }, [runs, q])

  const onPointerDown = useCallback(
    (e: React.PointerEvent) => {
      e.preventDefault()
      dragging.current = true
      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'
    },
    [],
  )

  useEffect(() => {
    const onMove = (e: PointerEvent) => {
      if (!dragging.current) return
      onResize(e.clientX)
    }
    const onUp = () => {
      if (!dragging.current) return
      dragging.current = false
      document.body.style.cursor = ''
      document.body.style.userSelect = ''
    }
    window.addEventListener('pointermove', onMove)
    window.addEventListener('pointerup', onUp)
    window.addEventListener('pointercancel', onUp)
    return () => {
      window.removeEventListener('pointermove', onMove)
      window.removeEventListener('pointerup', onUp)
      window.removeEventListener('pointercancel', onUp)
    }
  }, [onResize])

  const onResetWidth = useCallback(() => {
    onResize(DEFAULT_WIDTH)
  }, [onResize])

  return (
    <aside
      className="fixed left-0 top-0 bottom-0 z-30 border-r border-[var(--ink)] bg-background flex flex-col"
      style={{ width }}
      aria-label="Run index"
    >
      {/* Resize handle — 6px wide, sits flush with right border */}
      <div
        role="separator"
        aria-orientation="vertical"
        aria-label="Resize sidebar (double-click to reset)"
        title="Drag to resize · double-click to reset"
        onPointerDown={onPointerDown}
        onDoubleClick={onResetWidth}
        className="absolute top-0 right-0 bottom-0 w-[6px] -mr-[3px] cursor-col-resize group z-40"
      >
        <div className="absolute inset-y-0 left-1/2 -translate-x-1/2 w-px bg-[var(--ink-faint)] group-hover:bg-[var(--ink)] group-active:bg-[var(--vermillion)] transition-colors" />
        {/* knurl marks — 3 short ticks centered vertically */}
        <div
          aria-hidden
          className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 flex flex-col gap-[3px] opacity-0 group-hover:opacity-100 transition-opacity"
        >
          <span className="block w-[3px] h-[1.5px] bg-[var(--ink)]" />
          <span className="block w-[3px] h-[1.5px] bg-[var(--ink)]" />
          <span className="block w-[3px] h-[1.5px] bg-[var(--ink)]" />
        </div>
      </div>
      {/* Project tag — title-block top */}
      <div className="px-5 pt-5 pb-3 border-b border-[var(--ink)] flex items-start justify-between">
        <div>
          <div className="font-mono text-[10.5px] uppercase tracking-[0.1em] text-[var(--ink-faint)]">
            Project
          </div>
          <div className="font-condensed font-semibold uppercase tracking-[-0.005em] text-[17px] leading-tight mt-1">
            SpinorBEC
          </div>
          <div className="font-mono text-[10.5px] uppercase tracking-[0.08em] text-[var(--ink-soft)] mt-0.5">
            Dashboard / v0.1
          </div>
        </div>
        <div className="flex flex-col gap-1">
          <IconBtn onClick={onToggleTheme} title="Toggle theme">
            {isDark ? <Sun className="size-3.5" /> : <Moon className="size-3.5" />}
          </IconBtn>
          <IconBtn onClick={onShortcuts} title="Keyboard shortcuts">
            <Keyboard className="size-3.5" />
          </IconBtn>
        </div>
      </div>

      {/* Search */}
      <div className="px-5 pt-4 pb-3">
        <SectionHead label="Filter" />
        <div className="mt-2 flex items-center gap-2 px-2.5 py-1.5 border border-[var(--ink-faint)] bg-card focus-within:border-[var(--ink)]">
          <Search className="size-3 text-[var(--ink-faint)]" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="substring"
            className="flex-1 bg-transparent text-[12.5px] font-mono outline-none placeholder:text-[var(--ink-faint)]"
          />
          {q && (
            <button
              type="button"
              onClick={() => setQ('')}
              className="text-[11px] font-mono text-[var(--ink-soft)] hover:text-[var(--ink)]"
              aria-label="Clear filter"
            >
              ×
            </button>
          )}
        </div>
      </div>

      {/* Live section */}
      {liveRuns.length > 0 && (
        <div className="px-5 pb-3">
          <SectionHead
            label={
              <>
                <span className="status-dot is-live mr-2 align-middle" />
                Live · {liveRuns.length}
              </>
            }
          />
          <ol className="mt-2 space-y-0.5">
            {liveRuns.map((r, i) => (
              <RunRow
                key={r.run}
                index={i + 1}
                name={r.run}
                isLive
                isSelected={r.run === selectedRun}
                onClick={() => setSelectedRun(r.run)}
                annot={`${r.age_s.toFixed(0)}s`}
              />
            ))}
          </ol>
        </div>
      )}

      {/* Index */}
      <div className="px-5 pb-3 flex-1 min-h-0 flex flex-col">
        <SectionHead label={`Index · ${filteredRuns.length}`} />
        <ol className="mt-2 flex-1 min-h-0 overflow-y-auto -mx-1 px-1 space-y-0.5">
          {filteredRuns.length === 0 && (
            <li className="px-2 py-2 text-[11px] font-mono text-[var(--ink-faint)] italic">
              no matching runs
            </li>
          )}
          {filteredRuns.map((r, i) => (
            <RunRow
              key={r}
              index={i + 1}
              name={r}
              isLive={liveSet.has(r)}
              isSelected={r === selectedRun}
              onClick={() => setSelectedRun(r)}
            />
          ))}
        </ol>
      </div>

      {/* Live status footer */}
      {liveStatus.status && selectedRun && liveSet.has(selectedRun) && (
        <div className="border-t border-[var(--ink)] px-5 py-3 space-y-1.5">
          <SectionHead label="Streaming" tone="live" />
          <div className="leader text-[12px] mt-2">
            <span className="label">step</span>
            <span className="fill" />
            <span className="value">{liveStatus.status.step}</span>
          </div>
          <div className="leader text-[12px]">
            <span className="label">E</span>
            <span className="fill" />
            <span className="value">
              {liveStatus.status.energy.toFixed(4)}
            </span>
          </div>
          <div className="leader text-[12px]">
            <span className="label">‖ψ‖²</span>
            <span className="fill" />
            <span className="value">{liveStatus.status.norm.toFixed(5)}</span>
          </div>
        </div>
      )}

      {/* Footer */}
      <div className="border-t border-[var(--ink)] px-5 py-3 flex items-center justify-between text-[10.5px] font-mono uppercase tracking-[0.08em] text-[var(--ink-soft)]">
        <span>{runs.length} sheets</span>
        <button
          type="button"
          onClick={refresh}
          className="inline-flex items-center gap-1.5 hover:text-[var(--ink)] transition-colors"
          title="Refresh run list"
        >
          <RefreshCw className="size-3" />
          Refresh
        </button>
      </div>
    </aside>
  )
}

function SectionHead({
  label,
  tone,
}: {
  label: React.ReactNode
  tone?: 'live'
}) {
  return (
    <div
      className="font-mono text-[10.5px] uppercase tracking-[0.1em] font-medium"
      style={{
        color: tone === 'live' ? 'var(--vermillion)' : 'var(--ink-faint)',
      }}
    >
      {label}
    </div>
  )
}

function RunRow({
  index,
  name,
  isSelected,
  isLive,
  onClick,
  annot,
}: {
  index: number
  name: string
  isSelected: boolean
  isLive?: boolean
  onClick: () => void
  annot?: string
}) {
  return (
    <li>
      <button
        type="button"
        onClick={onClick}
        className={
          'w-full leader px-2 py-1 text-left text-[12px] transition-colors ' +
          (isSelected
            ? 'bg-[var(--ink)] text-[var(--paper)]'
            : 'hover:bg-[var(--paper-tint)]')
        }
        style={{ borderRadius: 0 }}
        title={name}
      >
        <span
          className="label"
          style={
            isSelected
              ? { color: 'var(--paper)', opacity: 0.7 }
              : undefined
          }
        >
          {String(index).padStart(2, '0')}
        </span>
        {isLive && (
          <span
            className="status-dot is-live mr-1"
            style={{ width: 6, height: 6 }}
          />
        )}
        <span
          className="value flex-1 truncate font-sans font-normal text-left"
          style={{
            color: isSelected ? 'var(--paper)' : 'var(--ink)',
            letterSpacing: '-0.005em',
          }}
        >
          {name}
        </span>
        {annot && (
          <span
            className="annot"
            style={{
              color: isSelected ? 'var(--paper)' : 'var(--ink-faint)',
              opacity: isSelected ? 0.75 : 1,
            }}
          >
            {annot}
          </span>
        )}
      </button>
    </li>
  )
}

function IconBtn({
  children,
  onClick,
  title,
}: {
  children: React.ReactNode
  onClick: () => void
  title: string
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      title={title}
      className="inline-flex items-center justify-center size-7 border border-[var(--ink-faint)] text-[var(--ink-soft)] hover:border-[var(--ink)] hover:text-[var(--ink)] transition-colors"
      style={{ borderRadius: 0 }}
    >
      {children}
    </button>
  )
}
