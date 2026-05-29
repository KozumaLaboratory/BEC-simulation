import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Search, RefreshCw, Keyboard, Sun, Moon, X, Tag as TagIcon } from 'lucide-react'
import { useLiveRuns, useLiveStatus } from '@/state/useLiveRuns'
import { useTags } from '@/state/useTags'
import { useCatalogIndex } from '@/state/useCatalogIndex'
import { api } from '@/api'
import type { RunDataState } from '@/state/useRunData'
import { cn } from '@/lib/utils'

interface Props {
  state: RunDataState
  isDark: boolean
  width: number
  onResize: (w: number) => void
  onShortcuts: () => void
  onToggleTheme: () => void
  /** Current top-level tab, for highlighting the active global destination. */
  currentTab: string
  /** Switch the global surface (Catalog / Queue). */
  onNavigate: (tab: string) => void
  /** Below the md breakpoint the sidebar becomes a slide-in drawer. */
  isMobile?: boolean
  mobileOpen?: boolean
  onClose?: () => void
}

// Drawer width on phones: most of the viewport but capped so a sliver of
// the dimmed page stays visible as an affordance to tap-to-close.
const MOBILE_WIDTH = 'min(86vw, 320px)'

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
  currentTab,
  onNavigate,
  isMobile = false,
  mobileOpen = false,
  onClose,
}: Props) {
  const { runs, selectedRun, setSelectedRun, refresh } = state
  const [q, setQ] = useState('')
  // Simplified mini-catalog: group the run list by Layer (the same coarse
  // tier as the Catalog tab) so the always-visible rail is navigable, not
  // a flat 300. Layers collapse independently; a filter auto-opens them.
  const { rows: catRows } = useCatalogIndex()
  const [openLayers, setOpenLayers] = useState<Set<string>>(() => new Set())
  const layerOf = useMemo(() => {
    const m: Record<string, string> = {}
    for (const r of catRows) m[r.name] = r.layer ?? 'other'
    return m
  }, [catRows])
  const { runs: liveRuns } = useLiveRuns()
  const liveStatus = useLiveStatus(selectedRun)
  const { tagsByCid, refresh: refreshTags } = useTags()
  const dragging = useRef(false)

  const liveSet = useMemo(
    () => new Set(liveRuns.map((r) => r.run)),
    [liveRuns],
  )

  // Filter matches a run's name OR any tag pinned to it, so searching
  // "fig6" finds both `..._fig6_...` dirs and runs tagged `paper3_fig6`.
  const filteredRuns = useMemo(() => {
    if (!q.trim()) return runs
    const needle = q.toLowerCase()
    return runs.filter(
      (r) =>
        r.toLowerCase().includes(needle) ||
        (tagsByCid[r] ?? []).some((t) => t.toLowerCase().includes(needle)),
    )
  }, [runs, q, tagsByCid])

  const onTagRun = useCallback(
    async (run: string) => {
      const name = window.prompt(
        `Tag run "${run}" — enter a name (e.g. paper3_fig6_final):`,
      )
      const trimmed = name?.trim()
      if (!trimmed) return
      try {
        await api.tagRun(trimmed, run)
      } finally {
        refreshTags()
      }
    },
    [refreshTags],
  )

  const onUntag = useCallback(
    async (name: string) => {
      try {
        await api.untagRun(name)
      } finally {
        refreshTags()
      }
    },
    [refreshTags],
  )

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
      className={cn(
        'fixed left-0 top-0 bottom-0 z-30 border-r border-[var(--ink)] bg-background flex flex-col',
        isMobile && 'transition-transform duration-200',
        isMobile && !mobileOpen && '-translate-x-full',
      )}
      style={{ width: isMobile ? MOBILE_WIDTH : width }}
      aria-label="Run index"
      aria-hidden={isMobile && !mobileOpen}
    >
      {/* Resize handle — desktop only (6px wide, flush with right border) */}
      <div
        role="separator"
        aria-orientation="vertical"
        aria-label="Resize sidebar (double-click to reset)"
        title="Drag to resize · double-click to reset"
        onPointerDown={onPointerDown}
        onDoubleClick={onResetWidth}
        className={cn(
          'absolute top-0 right-0 bottom-0 w-[6px] -mr-[3px] cursor-col-resize group z-40',
          isMobile && 'hidden',
        )}
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
          {isMobile && (
            <IconBtn onClick={() => onClose?.()} title="Close run index">
              <X className="size-3.5" />
            </IconBtn>
          )}
          <IconBtn onClick={onToggleTheme} title="Toggle theme">
            {isDark ? <Sun className="size-3.5" /> : <Moon className="size-3.5" />}
          </IconBtn>
          <IconBtn onClick={onShortcuts} title="Keyboard shortcuts">
            <Keyboard className="size-3.5" />
          </IconBtn>
        </div>
      </div>

      {/* Destinations — global surfaces (run-independent). Catalog is the
          primary navigation; Queue is the autopilot view. */}
      <nav className="px-3 pt-3 pb-2 flex flex-col gap-0.5">
        {(
          [
            ['catalog', 'Catalog'],
            ['queue', 'Queue'],
          ] as const
        ).map(([id, label]) => {
          const active = currentTab === id
          return (
            <button
              key={id}
              type="button"
              onClick={() => onNavigate(id)}
              className={cn(
                'w-full text-left px-2 py-1.5 font-mono text-[12px] uppercase tracking-[0.08em] transition-colors',
                active
                  ? 'bg-[var(--ink)] text-[var(--paper)]'
                  : 'text-[var(--ink-soft)] hover:bg-[var(--paper-tint)] hover:text-[var(--ink)]',
              )}
              style={{ borderRadius: 0 }}
            >
              {label}
            </button>
          )
        })}
      </nav>

      {/* Search */}
      <div className="px-5 pt-4 pb-3">
        <SectionHead label="Filter" />
        <div className="mt-2 flex items-center gap-2 px-2.5 py-1.5 border border-[var(--ink-faint)] bg-card focus-within:border-[var(--ink)]">
          <Search className="size-3 text-[var(--ink-faint)]" />
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="name or tag"
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
                tags={tagsByCid[r.run] ?? []}
                onTag={() => onTagRun(r.run)}
                onUntag={onUntag}
              />
            ))}
          </ol>
        </div>
      )}

      {/* Mini-catalog — runs grouped by Layer (the simplified Catalog) */}
      <div className="px-5 pb-3 flex-1 min-h-0 flex flex-col">
        <SectionHead label={`Catalog · ${filteredRuns.length}`} />
        <div className="mt-2 flex-1 min-h-0 overflow-y-auto -mx-1 px-1">
          {filteredRuns.length === 0 && (
            <p className="px-2 py-2 text-[11px] font-mono text-[var(--ink-faint)] italic">
              no matching runs
            </p>
          )}
          {(() => {
            const byLayer = new Map<string, string[]>()
            for (const name of filteredRuns) {
              const L = layerOf[name] ?? 'other'
              const arr = byLayer.get(L)
              if (arr) arr.push(name)
              else byLayer.set(L, [name])
            }
            const lvlNum = (k: string) =>
              /^L\d+$/.test(k) ? parseInt(k.slice(1), 10) : null
            const order = [...byLayer.keys()].sort((a, b) => {
              const la = lvlNum(a)
              const lb = lvlNum(b)
              if (la !== null && lb !== null) return la - lb
              if (la !== null) return -1
              if (lb !== null) return 1
              return byLayer.get(b)!.length - byLayer.get(a)!.length
            })
            const filtering = q.trim() !== ''
            return order.map((L) => {
              const names = byLayer.get(L)!
              const lopen = filtering || openLayers.has(L)
              return (
                <div key={L}>
                  <button
                    type="button"
                    onClick={() =>
                      setOpenLayers((cur) => {
                        const n = new Set(cur)
                        if (n.has(L)) n.delete(L)
                        else n.add(L)
                        return n
                      })
                    }
                    className="w-full flex items-baseline gap-1.5 px-1 py-1 text-left hover:bg-[var(--paper-tint)]"
                  >
                    <span className="text-[var(--ink-faint)] font-mono text-[10px] w-2.5">
                      {lopen ? '▾' : '▸'}
                    </span>
                    <span className="font-mono text-[11px] text-[var(--ink)]">{L}</span>
                    <span className="font-mono text-[10px] text-[var(--ink-faint)]">
                      {names.length}
                    </span>
                  </button>
                  {lopen && (
                    <ol className="space-y-0.5 mb-1">
                      {names.map((name, i) => (
                        <RunRow
                          key={name}
                          index={i + 1}
                          name={name}
                          isLive={liveSet.has(name)}
                          isSelected={name === selectedRun}
                          onClick={() => setSelectedRun(name)}
                          tags={tagsByCid[name] ?? []}
                          onTag={() => onTagRun(name)}
                          onUntag={onUntag}
                        />
                      ))}
                    </ol>
                  )}
                </div>
              )
            })
          })()}
        </div>
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
  tags = [],
  onTag,
  onUntag,
}: {
  index: number
  name: string
  isSelected: boolean
  isLive?: boolean
  onClick: () => void
  annot?: string
  tags?: string[]
  onTag?: () => void
  onUntag?: (name: string) => void
}) {
  // The row select is one <button>; tag controls are sibling buttons (not
  // nested) so the markup stays valid. `group` reveals +tag on hover.
  return (
    <li>
      <div
        className={
          'group px-2 py-1 transition-colors ' +
          (isSelected ? 'bg-[var(--ink)]' : 'hover:bg-[var(--paper-tint)]')
        }
      >
        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={onClick}
            className="flex-1 min-w-0 leader text-left text-[12px]"
            title={name}
          >
            <span
              className="label"
              style={isSelected ? { color: 'var(--paper)', opacity: 0.7 } : undefined}
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
          {onTag && (
            <button
              type="button"
              onClick={onTag}
              title={`tag "${name}"`}
              aria-label={`tag ${name}`}
              className={
                'shrink-0 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity ' +
                (isSelected
                  ? 'text-[var(--paper)]'
                  : 'text-[var(--ink-faint)] hover:text-[var(--ink)]')
              }
            >
              <TagIcon className="size-3" />
            </button>
          )}
        </div>
        {tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-1 pl-[1.6em]">
            {tags.map((t) => (
              <span
                key={t}
                className="inline-flex items-center gap-0.5 font-mono text-[9.5px] px-1 leading-tight border"
                style={{
                  borderRadius: 0,
                  borderColor: isSelected
                    ? 'color-mix(in oklch, var(--paper) 50%, transparent)'
                    : 'var(--t-cyan,#4a8bb8)',
                  color: isSelected ? 'var(--paper)' : 'var(--t-cyan,#4a8bb8)',
                }}
                title={`tag: ${t}`}
              >
                {t}
                {onUntag && (
                  <button
                    type="button"
                    onClick={() => onUntag(t)}
                    className="hover:text-[var(--t-red,#d94e1f)] leading-none"
                    aria-label={`remove tag ${t}`}
                  >
                    ×
                  </button>
                )}
              </span>
            ))}
          </div>
        )}
      </div>
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
