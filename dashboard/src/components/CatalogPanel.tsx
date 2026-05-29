import { useCallback, useMemo, useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { useCatalogIndex } from '@/state/useCatalogIndex'
import { useTags } from '@/state/useTags'
import { ParallelCoordinates } from '@/components/ParallelCoordinates'
import { api, type CatalogRow } from '@/api'

// Tag controls reused across every run row (tree / attention / table) so
// any run is taggable from the primary surface, not just the SideNav.
// Sibling buttons (not nested in the row's open-button) to keep markup
// valid; stopPropagation so a tag click doesn't also open the run.
function RunTags({
  tags,
  onTag,
  onUntag,
}: {
  tags: string[]
  onTag: () => void
  onUntag: (name: string) => void
}) {
  return (
    <span className="inline-flex flex-wrap items-center gap-1 shrink-0">
      {tags.map((t) => (
        <span
          key={t}
          className="inline-flex items-center gap-0.5 font-mono text-[9.5px] px-1 border"
          style={{
            borderRadius: 0,
            borderColor: 'var(--t-cyan,#4a8bb8)',
            color: 'var(--t-cyan,#4a8bb8)',
          }}
          title={`tag: ${t}`}
        >
          {t}
          <button
            type="button"
            onClick={(e) => {
              e.stopPropagation()
              onUntag(t)
            }}
            className="hover:text-[var(--t-red,#d94e1f)] leading-none"
            aria-label={`remove tag ${t}`}
          >
            ×
          </button>
        </span>
      ))}
      <button
        type="button"
        onClick={(e) => {
          e.stopPropagation()
          onTag()
        }}
        className="font-mono text-[10px] text-[var(--ink-faint)] hover:text-[var(--ink)] px-1 leading-none"
        title="pin a stable name to this run"
      >
        +tag
      </button>
    </span>
  )
}

// Facets are derived, zero-discipline axes the system already stamps —
// the primary navigation. Each maps a row to its value (or undefined when
// the field is absent, so a run without observables still shows under
// family/status but drops out of observable facets).
type FacetKey = 'layer' | 'family' | 'F' | 'status' | 'collapsed' | 'state'

const FACETS: { key: FacetKey; label: string; of: (r: CatalogRow) => string | undefined }[] = [
  { key: 'layer', label: 'Layer', of: (r) => (typeof r.layer === 'string' ? r.layer : undefined) },
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
  const { tagsByCid, refresh: refreshTags } = useTags()

  const onTag = useCallback(
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
          <p className="w-full font-mono text-[11px] text-[var(--ink-faint)] leading-relaxed">
            Click a facet value below (or type above) to narrow to a cohort —
            parallel coordinates + a sortable table appear. Click any run to
            open it. With nothing selected, the lists below are picked for you.
          </p>
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
            tagsByCid={tagsByCid}
            onSort={setSort}
            onOpenRun={onOpenRun}
            onTag={onTag}
            onUntag={onUntag}
          />
        </>
      ) : (
        <>
          <AttentionBanner
            rows={rows}
            tagsByCid={tagsByCid}
            onOpenRun={onOpenRun}
            onTag={onTag}
            onUntag={onUntag}
          />
          <CatalogTree
            rows={rows}
            tagsByCid={tagsByCid}
            onOpenRun={onOpenRun}
            onTag={onTag}
            onUntag={onUntag}
          />
        </>
      )}
    </div>
  )
}

// Default browse: a heavily-consolidated 2-tier tree — Layer (validation
// level / campaign bucket) ▸ Family (variant) ▸ runs. Collapsed by default
// so 300 runs read as ~12 layers; expand to drill. Click a run to open.
function CatalogTree({
  rows,
  tagsByCid,
  onOpenRun,
  onTag,
  onUntag,
}: {
  rows: CatalogRow[]
  tagsByCid: Record<string, string[]>
  onOpenRun: (name: string) => void
  onTag: (name: string) => void
  onUntag: (name: string) => void
}) {
  const [openLayers, setOpenLayers] = useState<Set<string>>(() => new Set())
  const [openFams, setOpenFams] = useState<Set<string>>(() => new Set())

  const tree = useMemo(() => {
    const m = new Map<string, Map<string, CatalogRow[]>>()
    for (const r of rows) {
      const L = r.layer ?? 'other'
      let fm = m.get(L)
      if (!fm) m.set(L, (fm = new Map()))
      const arr = fm.get(r.family)
      if (arr) arr.push(r)
      else fm.set(r.family, [r])
    }
    return m
  }, [rows])

  const lvlNum = (k: string) => (/^L\d+$/.test(k) ? parseInt(k.slice(1), 10) : null)
  const layerCount = (L: string) =>
    [...tree.get(L)!.values()].reduce((s, v) => s + v.length, 0)
  const layerOrder = useMemo(() => {
    return [...tree.keys()].sort((a, b) => {
      const la = lvlNum(a)
      const lb = lvlNum(b)
      if (la !== null && lb !== null) return la - lb
      if (la !== null) return -1
      if (lb !== null) return 1
      return layerCount(b) - layerCount(a)
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tree])

  function toggle(set: Set<string>, setter: (s: Set<string>) => void, k: string) {
    const next = new Set(set)
    if (next.has(k)) next.delete(k)
    else next.add(k)
    setter(next)
  }

  return (
    <Card>
      <CardContent className="p-0">
        <ul className="divide-y divide-[var(--ink-faint)]">
          {layerOrder.map((L) => {
            const fams = tree.get(L)!
            const total = layerCount(L)
            const att = [...fams.values()].flat().filter(needsAttention).length
            const lopen = openLayers.has(L)
            return (
              <li key={L}>
                <button
                  type="button"
                  onClick={() => toggle(openLayers, setOpenLayers, L)}
                  className="w-full text-left px-4 py-2 flex items-center gap-2 hover:bg-[color-mix(in_oklch,var(--ink)_3%,transparent)]"
                >
                  <span className="text-[var(--ink-faint)] font-mono text-xs w-3">
                    {lopen ? '▾' : '▸'}
                  </span>
                  <span className="font-mono text-[13px] text-[var(--ink)]">{L}</span>
                  <span className="font-mono text-[11px] text-[var(--ink-soft)]">
                    {total} · {fams.size} {fams.size === 1 ? 'family' : 'families'}
                  </span>
                  {att > 0 && (
                    <span
                      className="ml-auto font-mono text-[10px] px-1 border"
                      style={{
                        borderRadius: 0,
                        borderColor: 'var(--t-red,#d94e1f)',
                        color: 'var(--t-red,#d94e1f)',
                      }}
                    >
                      {att} ⚠
                    </span>
                  )}
                </button>
                {lopen && (
                  <ul className="bg-[color-mix(in_oklch,var(--ink)_2%,transparent)]">
                    {[...fams.entries()]
                      .sort((a, b) => b[1].length - a[1].length)
                      .map(([F, frows]) => {
                        const fkey = L + '/' + F
                        const fopen = openFams.has(fkey) || frows.length === 1
                        return (
                          <li key={fkey} className="border-t border-[var(--ink-faint)]">
                            {frows.length > 1 ? (
                              <button
                                type="button"
                                onClick={() => toggle(openFams, setOpenFams, fkey)}
                                className="w-full text-left pl-9 pr-4 py-1.5 flex items-center gap-2 hover:bg-[color-mix(in_oklch,var(--ink)_3%,transparent)]"
                              >
                                <span className="text-[var(--ink-faint)] font-mono text-xs w-3">
                                  {fopen ? '▾' : '▸'}
                                </span>
                                <span className="font-mono text-[12px] text-[var(--ink-soft)]">
                                  {F}
                                </span>
                                <span className="font-mono text-[10.5px] text-[var(--ink-faint)]">
                                  {frows.length}
                                </span>
                              </button>
                            ) : null}
                            {fopen && (
                              <ul>
                                {frows.map((r) => (
                                  <li
                                    key={r.name}
                                    className="flex items-center gap-3 pl-14 pr-4 py-1.5 hover:bg-[color-mix(in_oklch,var(--ink)_4%,transparent)]"
                                  >
                                    <button
                                      type="button"
                                      onClick={() => onOpenRun(r.name)}
                                      className="flex-1 min-w-0 text-left font-mono text-[11.5px] text-[var(--ink)] truncate"
                                    >
                                      {r.name}
                                    </button>
                                    <RowBadges r={r} />
                                    <RunTags
                                      tags={tagsByCid[r.name] ?? []}
                                      onTag={() => onTag(r.name)}
                                      onUntag={onUntag}
                                    />
                                  </li>
                                ))}
                              </ul>
                            )}
                          </li>
                        )
                      })}
                  </ul>
                )}
              </li>
            )
          })}
        </ul>
      </CardContent>
    </Card>
  )
}

function AttentionBanner({
  rows,
  tagsByCid,
  onOpenRun,
  onTag,
  onUntag,
}: {
  rows: CatalogRow[]
  tagsByCid: Record<string, string[]>
  onOpenRun: (name: string) => void
  onTag: (name: string) => void
  onUntag: (name: string) => void
}) {
  const att = rows.filter(needsAttention)
  if (att.length === 0) return null
  return (
    <Card>
      <CardContent className="p-0">
        <div
          className="px-4 py-2 border-b border-[var(--ink-faint)] font-mono text-[10.5px] uppercase tracking-[0.10em]"
          style={{
            background: 'color-mix(in oklch, var(--t-red,#d94e1f) 7%, transparent)',
            color: 'var(--t-red,#d94e1f)',
          }}
        >
          Needs attention · {att.length}
        </div>
        <ul className="divide-y divide-[var(--ink-faint)]">
          {att.slice(0, 12).map((r) => (
            <li
              key={r.name}
              className="flex items-center gap-3 px-4 py-2 hover:bg-[color-mix(in_oklch,var(--ink)_3%,transparent)]"
            >
              <button
                type="button"
                onClick={() => onOpenRun(r.name)}
                className="flex-1 min-w-0 text-left font-mono text-[11.5px] text-[var(--ink)] truncate"
              >
                {r.name}
              </button>
              <RowBadges r={r} />
              <RunTags
                tags={tagsByCid[r.name] ?? []}
                onTag={() => onTag(r.name)}
                onUntag={onUntag}
              />
            </li>
          ))}
        </ul>
      </CardContent>
    </Card>
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
  const anyValues = FACETS.some((f) => (facetValues[f.key]?.size ?? 0) > 0)
  return (
    <Card>
      <CardContent className="p-5 space-y-3">
        <div className="font-mono text-[10px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
          Filter — click a value to narrow{' '}
          {!anyValues && '(waiting for the index…)'}
        </div>
        {FACETS.map((f) => {
          const counts = facetValues[f.key]
          if (!counts || counts.size === 0) return null
          const values = [...counts.entries()]
            .sort((a, b) => b[1] - a[1])
            .slice(0, 24)
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
  tagsByCid,
  onSort,
  onOpenRun,
  onTag,
  onUntag,
}: {
  rows: CatalogRow[]
  sortKey: string
  sortDir: 1 | -1
  tagsByCid: Record<string, string[]>
  onSort: (key: string) => void
  onOpenRun: (name: string) => void
  onTag: (name: string) => void
  onUntag: (name: string) => void
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
              <th className="px-3 py-2 text-left">tags</th>
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
                <td className="px-3 py-2 whitespace-nowrap" onClick={(e) => e.stopPropagation()}>
                  <RunTags
                    tags={tagsByCid[r.name] ?? []}
                    onTag={() => onTag(r.name)}
                    onUntag={onUntag}
                  />
                </td>
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
