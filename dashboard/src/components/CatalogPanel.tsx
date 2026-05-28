import { useMemo, useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { useCatalogIndex } from '@/state/useCatalogIndex'
import { ParallelCoordinates } from '@/components/ParallelCoordinates'
import type { CatalogRow } from '@/api'

// Facets are derived, zero-discipline axes the system already stamps —
// the primary navigation. Each maps a row to its value (or undefined when
// the field is absent, so a run without observables still shows under
// family/status but drops out of observable facets).
type FacetKey = 'family' | 'F' | 'status' | 'collapsed' | 'state'

const FACETS: { key: FacetKey; label: string; of: (r: CatalogRow) => string | undefined }[] = [
  { key: 'family', label: 'Family', of: (r) => r.family },
  { key: 'F', label: 'Spin F', of: (r) => (r.F != null ? `F=${r.F}` : undefined) },
  { key: 'status', label: 'Status', of: (r) => r.status },
  { key: 'collapsed', label: 'Collapse', of: (r) => r.collapsed },
  {
    key: 'state',
    label: 'Index',
    of: (r) => (r.has_summary ? 'summarized' : r.has_jld2 ? 'needs reindex' : 'config only'),
  },
]

function needsAttention(r: CatalogRow): boolean {
  return (
    (typeof r.status === 'string' && r.status.startsWith('killed')) ||
    r.collapsed === 'collapse' ||
    (Array.isArray(r.extraction_error) && r.extraction_error.length > 0)
  )
}

function matchesQuery(r: CatalogRow, q: string): boolean {
  if (!q) return true
  const n = q.toLowerCase()
  return (
    r.name.toLowerCase().includes(n) ||
    r.family.toLowerCase().includes(n) ||
    (typeof r.recipe === 'string' && r.recipe.toLowerCase().includes(n))
  )
}

function passesExcept(
  r: CatalogRow,
  selected: Record<string, Set<string>>,
  q: string,
  except: FacetKey | null,
): boolean {
  if (!matchesQuery(r, q)) return false
  for (const f of FACETS) {
    if (f.key === except) continue
    const sel = selected[f.key]
    if (sel && sel.size > 0) {
      const v = f.of(r)
      if (v === undefined || !sel.has(v)) return false
    }
  }
  return true
}

export function CatalogPanel({ onOpenRun }: { onOpenRun: (name: string) => void }) {
  const { rows, loading, error, refresh } = useCatalogIndex()
  const [selected, setSelected] = useState<Record<string, Set<string>>>({})
  const [query, setQuery] = useState('')
  const [sortKey, setSortKey] = useState<string>('mtime')
  const [sortDir, setSortDir] = useState<1 | -1>(-1)

  const hasFilter =
    query.trim() !== '' || Object.values(selected).some((s) => s.size > 0)

  // Final filtered set (all facets + query applied).
  const filtered = useMemo(
    () => rows.filter((r) => passesExcept(r, selected, query, null)),
    [rows, selected, query],
  )

  // Per-facet available values + counts, computed from rows that pass the
  // OTHER facets — so a value never leads to an empty result (empty-hiding).
  const facetValues = useMemo(() => {
    const out: Record<string, Map<string, number>> = {}
    for (const f of FACETS) {
      const counts = new Map<string, number>()
      for (const r of rows) {
        if (!passesExcept(r, selected, query, f.key)) continue
        const v = f.of(r)
        if (v === undefined) continue
        counts.set(v, (counts.get(v) ?? 0) + 1)
      }
      out[f.key] = counts
    }
    return out
  }, [rows, selected, query])

  const sorted = useMemo(() => {
    const arr = [...filtered]
    arr.sort((a, b) => {
      const av = a[sortKey]
      const bv = b[sortKey]
      const an = typeof av === 'number' ? av : av == null ? -Infinity : NaN
      const bn = typeof bv === 'number' ? bv : bv == null ? -Infinity : NaN
      if (Number.isNaN(an) || Number.isNaN(bn)) {
        return String(av ?? '').localeCompare(String(bv ?? '')) * sortDir
      }
      return (an - bn) * sortDir
    })
    return arr
  }, [filtered, sortKey, sortDir])

  function toggle(key: FacetKey, value: string) {
    setSelected((cur) => {
      const next = { ...cur }
      const set = new Set(next[key] ?? [])
      if (set.has(value)) set.delete(value)
      else set.add(value)
      next[key] = set
      return next
    })
  }
  function clearAll() {
    setSelected({})
    setQuery('')
  }
  function setSort(key: string) {
    if (key === sortKey) setSortDir((d) => (d === 1 ? -1 : 1))
    else {
      setSortKey(key)
      setSortDir(-1)
    }
  }

  const summarized = rows.filter((r) => r.has_summary).length

  return (
    <div className="space-y-5">
      <Card>
        <CardContent className="p-5 flex flex-wrap items-center gap-x-6 gap-y-2">
          <span className="font-mono text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
            Catalog
          </span>
          <span className="font-mono text-[12px] text-[var(--ink-soft)]">
            {rows.length} runs · {summarized} summarized ·{' '}
            {rows.length - summarized} need reindex
          </span>
          <span className="ml-auto flex items-center gap-3">
            <input
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="name / family / recipe"
              className="bg-transparent text-[12.5px] font-mono outline-none border border-[var(--ink-faint)] focus:border-[var(--ink)] px-2 py-1 w-56"
              style={{ borderRadius: 0 }}
            />
            {hasFilter && (
              <button
                type="button"
                onClick={clearAll}
                className="font-mono text-[11px] text-[var(--ink-soft)] hover:text-[var(--ink)]"
              >
                clear
              </button>
            )}
            <button
              type="button"
              onClick={refresh}
              className="font-mono text-[11px] text-[var(--ink-soft)] hover:text-[var(--ink)]"
            >
              {loading ? 'loading…' : 'refresh'}
            </button>
          </span>
          {error && (
            <span className="w-full font-mono text-[11px] text-[var(--t-red,#d94e1f)]">
              {error}
            </span>
          )}
        </CardContent>
      </Card>

      <FacetBar facetValues={facetValues} selected={selected} onToggle={toggle} />

      {hasFilter ? (
        <>
          {filtered.length >= 2 && (
            <Card>
              <CardContent className="p-4">
                <ParallelCoordinates rows={filtered} />
              </CardContent>
            </Card>
          )}
          <ResultTable
            rows={sorted}
            sortKey={sortKey}
            sortDir={sortDir}
            onSort={setSort}
            onOpenRun={onOpenRun}
          />
        </>
      ) : (
        <TriageLanding rows={rows} onOpenRun={onOpenRun} />
      )}
    </div>
  )
}

function FacetBar({
  facetValues,
  selected,
  onToggle,
}: {
  facetValues: Record<string, Map<string, number>>
  selected: Record<string, Set<string>>
  onToggle: (key: FacetKey, value: string) => void
}) {
  return (
    <Card>
      <CardContent className="p-5 space-y-3">
        {FACETS.map((f) => {
          const counts = facetValues[f.key]
          if (!counts || counts.size === 0) return null
          const values = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 24)
          const sel = selected[f.key] ?? new Set<string>()
          return (
            <div key={f.key} className="flex flex-wrap items-baseline gap-x-3 gap-y-1.5">
              <span className="font-mono text-[10px] uppercase tracking-[0.10em] text-[var(--ink-faint)] w-16 shrink-0">
                {f.label}
              </span>
              <span className="flex flex-wrap gap-1.5">
                {values.map(([v, n]) => {
                  const active = sel.has(v)
                  return (
                    <button
                      key={v}
                      type="button"
                      onClick={() => onToggle(f.key, v)}
                      className="font-mono text-[11px] px-1.5 py-0.5 border"
                      style={{
                        borderRadius: 0,
                        borderColor: active ? 'var(--ink)' : 'var(--ink-faint)',
                        background: active ? 'var(--ink)' : 'transparent',
                        color: active ? 'var(--background)' : 'var(--ink-soft)',
                      }}
                      title={`${v} · ${n}`}
                    >
                      {v} <span style={{ opacity: 0.6 }}>{n}</span>
                    </button>
                  )
                })}
              </span>
            </div>
          )
        })}
      </CardContent>
    </Card>
  )
}

function TriageLanding({
  rows,
  onOpenRun,
}: {
  rows: CatalogRow[]
  onOpenRun: (name: string) => void
}) {
  const attention = rows.filter(needsAttention).slice(0, 16)
  const recent = [...rows].sort((a, b) => b.mtime - a.mtime).slice(0, 16)
  const notable = rows
    .filter((r) => r.collapsed && r.collapsed !== 'stable_arrest' && !needsAttention(r))
    .slice(0, 16)

  return (
    <div className="space-y-5">
      {attention.length > 0 && (
        <TriageGroup
          title="Needs attention"
          tone="var(--t-red,#d94e1f)"
          rows={attention}
          onOpenRun={onOpenRun}
        />
      )}
      <TriageGroup
        title="Recent"
        tone="var(--t-cyan,#4a8bb8)"
        rows={recent}
        onOpenRun={onOpenRun}
      />
      {notable.length > 0 && (
        <TriageGroup
          title="Notable (collapse / arrest)"
          tone="var(--vermillion,#d97a3c)"
          rows={notable}
          onOpenRun={onOpenRun}
        />
      )}
    </div>
  )
}

function TriageGroup({
  title,
  tone,
  rows,
  onOpenRun,
}: {
  title: string
  tone: string
  rows: CatalogRow[]
  onOpenRun: (name: string) => void
}) {
  return (
    <Card>
      <CardContent className="p-0">
        <div
          className="px-5 py-2.5 border-b border-[var(--ink-faint)] flex items-baseline gap-2"
          style={{ background: `color-mix(in oklch, ${tone} 7%, transparent)` }}
        >
          <span className="inline-block w-2 h-2 rounded-full" style={{ background: tone }} />
          <span className="font-mono text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink)]">
            {title} · {rows.length}
          </span>
        </div>
        <ul className="divide-y divide-[var(--ink-faint)]">
          {rows.map((r) => (
            <li key={r.name}>
              <button
                type="button"
                onClick={() => onOpenRun(r.name)}
                className="w-full text-left px-5 py-2 hover:bg-[color-mix(in_oklch,var(--ink)_3%,transparent)] flex items-center gap-3"
              >
                <span className="font-mono text-[12px] text-[var(--ink)] truncate flex-1">
                  {r.name}
                </span>
                <RowBadges r={r} />
              </button>
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
  )
}

const COLS: { key: string; label: string; fmt: (r: CatalogRow) => string }[] = [
  { key: 'family', label: 'family', fmt: (r) => r.family },
  { key: 'F', label: 'F', fmt: (r) => (r.F != null ? String(r.F) : '—') },
  { key: 'energy', label: 'energy', fmt: (r) => (r.energy != null ? r.energy.toFixed(4) : '—') },
  { key: 'Mz', label: 'Mz', fmt: (r) => (r.Mz != null ? r.Mz.toFixed(3) : '—') },
  {
    key: 'norm_rel_drift',
    label: 'norm drift',
    fmt: (r) => (r.norm_rel_drift != null ? r.norm_rel_drift.toExponential(1) : '—'),
  },
  { key: 'collapsed', label: 'collapse', fmt: (r) => r.collapsed ?? '—' },
  { key: 'status', label: 'status', fmt: (r) => r.status ?? '—' },
]

function ResultTable({
  rows,
  sortKey,
  sortDir,
  onSort,
  onOpenRun,
}: {
  rows: CatalogRow[]
  sortKey: string
  sortDir: 1 | -1
  onSort: (key: string) => void
  onOpenRun: (name: string) => void
}) {
  return (
    <Card>
      <CardContent className="p-0 overflow-auto">
        <table className="w-full text-xs font-mono">
          <thead className="text-[var(--ink-faint)] uppercase tracking-[0.06em] text-[10px]">
            <tr className="border-b border-[var(--ink-faint)]">
              <th className="px-3 py-2 text-left">run · {rows.length}</th>
              {COLS.map((c) => (
                <th
                  key={c.key}
                  className="px-3 py-2 text-left cursor-pointer hover:text-[var(--ink)] whitespace-nowrap"
                  onClick={() => onSort(c.key)}
                >
                  {c.label}
                  {sortKey === c.key ? (sortDir === 1 ? ' ▲' : ' ▼') : ''}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr
                key={r.name}
                className="border-b border-[var(--ink-faint)] hover:bg-[color-mix(in_oklch,var(--ink)_3%,transparent)] cursor-pointer"
                onClick={() => onOpenRun(r.name)}
              >
                <td className="px-3 py-2 text-[var(--ink)] max-w-[320px] truncate" title={r.name}>
                  {r.name}
                </td>
                {COLS.map((c) => (
                  <td key={c.key} className="px-3 py-2 text-[var(--ink-soft)] whitespace-nowrap">
                    {c.fmt(r)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </CardContent>
    </Card>
  )
}

function RowBadges({ r }: { r: CatalogRow }) {
  const badges: { text: string; color: string }[] = []
  if (typeof r.status === 'string' && r.status.startsWith('killed'))
    badges.push({ text: r.status, color: 'var(--t-red,#d94e1f)' })
  if (r.collapsed) badges.push({ text: r.collapsed, color: 'var(--vermillion,#d97a3c)' })
  if (Array.isArray(r.extraction_error) && r.extraction_error.length > 0)
    badges.push({ text: 'extract err', color: 'var(--t-red,#d94e1f)' })
  if (!r.has_summary && r.has_jld2)
    badges.push({ text: 'needs reindex', color: 'var(--ink-faint)' })
  if (r.F != null) badges.push({ text: `F=${r.F}`, color: 'var(--ink-soft)' })
  return (
    <span className="flex flex-wrap gap-1 shrink-0">
      {badges.map((b, i) => (
        <span
          key={i}
          className="font-mono text-[9.5px] px-1 py-px border"
          style={{ borderRadius: 0, borderColor: b.color, color: b.color }}
        >
          {b.text}
        </span>
      ))}
    </span>
  )
}
