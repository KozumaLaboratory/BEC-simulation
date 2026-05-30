import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { stringify as yamlStringify } from 'yaml'
import { Card, CardContent } from '@/components/ui/card'
import {
  api,
  type AutopilotQueueEntry,
  type AutopilotQueueResponse,
  type Tag,
} from '@/api'
import { useDashboardURL, type TabId } from '@/state/useDashboardURL'
import { EnqueueDialog } from '@/components/EnqueueDialog'
import { QueueToastStack, type QueueToastInfo } from '@/components/QueueToast'
import { displayName } from '@/lib/displayName'

type State = AutopilotQueueEntry['status']
const STATES: State[] = ['pending', 'running', 'done', 'killed_data', 'killed_bug']

const STATE_LABEL: Record<State, string> = {
  pending: 'pending',
  running: 'running',
  done: 'done',
  killed_data: 'killed · data',
  killed_bug: 'killed · bug',
}

const STATE_COLOR: Record<State, string> = {
  pending: 'var(--ink-soft)',
  running: 'var(--t-cyan, #4a8bb8)',
  done: 'var(--t-green, #5a8b5a)',
  killed_data: 'var(--vermillion, #d97a3c)',
  killed_bug: 'var(--t-red, #d94e1f)',
}

const STATE_SYMBOL: Record<State, string> = {
  pending: '◦',
  running: '⟳',
  done: '✓',
  killed_data: '⚡',
  killed_bug: '✗',
}

// An "intention" — one manual enqueue, one sweep, or one recipe lineage —
// is the unit an operator reasons about. The backend stamps every entry
// with a shared `group_id` (== content_id for singletons, `grp-<hash>` for
// sweeps, inherited by on_complete children). We bucket the flat 5-state
// snapshot back into those intentions so 100 sweep cells collapse to one
// expandable row with a status rollup instead of 100 disconnected rows.
interface IntentionGroupData {
  group_id: string
  cells: AutopilotQueueEntry[]
  label: string
  recipeName: string | null
  rollup: Record<State, number>
  total: number
  latest: string // most recent enqueued_at, for ordering
}

function groupByIntention(snap: AutopilotQueueResponse): IntentionGroupData[] {
  const buckets = new Map<string, AutopilotQueueEntry[]>()
  for (const s of STATES) {
    for (const e of snap[s] ?? []) {
      const arr = buckets.get(e.group_id)
      if (arr) arr.push(e)
      else buckets.set(e.group_id, [e])
    }
  }
  const groups: IntentionGroupData[] = []
  for (const [group_id, cells] of buckets) {
    const rollup: Record<State, number> = {
      pending: 0,
      running: 0,
      done: 0,
      killed_data: 0,
      killed_bug: 0,
    }
    let latest = ''
    for (const e of cells) {
      rollup[e.status] += 1
      if (e.enqueued_at > latest) latest = e.enqueued_at
    }
    const recipeName = cells.find((c) => c.recipe.name)?.recipe.name ?? null
    const isGrp = group_id.startsWith('grp-')
    const label =
      cells.length === 1
        ? displayName(cells[0].content_id, { recipeName })
        : recipeName ?? (isGrp ? 'sweep' : displayName(group_id))
    groups.push({
      group_id,
      cells,
      label,
      recipeName,
      rollup,
      total: cells.length,
      latest,
    })
  }
  // Most recently touched intentions first; stable for equal timestamps.
  groups.sort((a, b) => (a.latest < b.latest ? 1 : a.latest > b.latest ? -1 : 0))
  return groups
}

function sessionId(): string {
  try {
    const k = 'spinorbec.dashboard.session_id'
    const v = sessionStorage.getItem(k)
    if (v) return v
    const nv = Math.random().toString(36).slice(2, 10)
    sessionStorage.setItem(k, nv)
    return nv
  } catch {
    return 'tab-' + Math.random().toString(36).slice(2, 10)
  }
}

function useAutopilotQueue(intervalMs = 5000) {
  const [snap, setSnap] = useState<AutopilotQueueResponse | null>(null)
  const [tagsByCid, setTagsByCid] = useState<Record<string, string[]>>({})
  const [error, setError] = useState<string | null>(null)
  const stopRef = useRef(false)
  const tickRef = useRef<(() => Promise<void>) | null>(null)

  useEffect(() => {
    stopRef.current = false
    const tick = async () => {
      if (document.hidden) return
      try {
        const q = await api.autopilotQueue()
        // Tags are a separate, newer endpoint — don't let its absence
        // (old server) take down the queue view.
        let tags: Tag[] = []
        try {
          tags = await api.listTags()
        } catch {
          tags = []
        }
        if (!stopRef.current) {
          setSnap(q)
          const map: Record<string, string[]> = {}
          for (const t of tags) (map[t.content_id] ??= []).push(t.name)
          setTagsByCid(map)
          setError(null)
        }
      } catch (e) {
        if (!stopRef.current) setError((e as Error).message)
      }
    }
    tickRef.current = tick
    void tick()
    const id = window.setInterval(tick, intervalMs)
    return () => {
      stopRef.current = true
      window.clearInterval(id)
    }
  }, [intervalMs])

  const refresh = () => {
    void tickRef.current?.()
  }
  return { snap, tagsByCid, error, refresh }
}

// Open the enqueue dialog when routed here with ?enqueue (from the SideNav
// "+ Enqueue"), then clear the flag so it doesn't re-fire on remount.
function useEnqueueFlag(
  flag: boolean,
  open: () => void,
  clear: () => void,
) {
  useEffect(() => {
    if (!flag) return
    open()
    clear()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [flag])
}

export function QueuePanel() {
  const { snap, tagsByCid, error, refresh } = useAutopilotQueue()
  const [url, setUrl] = useDashboardURL()
  const [dialogOpen, setDialogOpen] = useState(false)
  const [dialogInitialYaml, setDialogInitialYaml] = useState<string | undefined>()
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())
  const [groupExpanded, setGroupExpanded] = useState<Set<string>>(() => new Set())
  const [flashCid, setFlashCid] = useState<string | null>(null)
  const [actionBusy, setActionBusy] = useState<Set<string>>(() => new Set())
  const [toasts, setToasts] = useState<QueueToastInfo[]>([])
  const toastIdRef = useRef(1)

  const counts = useMemo(() => {
    if (!snap) return null
    return Object.fromEntries(
      STATES.map((s) => [s, snap[s]?.length ?? 0]),
    ) as Record<State, number>
  }, [snap])

  const dryRun = snap?.autopilot.dry_run ?? false
  const paused = snap?.autopilot.paused ?? false

  function pushToast(t: Omit<QueueToastInfo, 'id'>) {
    const id = toastIdRef.current++
    setToasts((cur) => [...cur, { ...t, id }])
  }
  function dismissToast(id: number) {
    setToasts((cur) => cur.filter((t) => t.id !== id))
  }

  function toggleExpand(cid: string) {
    setExpanded((cur) => {
      const next = new Set(cur)
      if (next.has(cid)) next.delete(cid)
      else next.add(cid)
      return next
    })
  }

  function toggleGroup(gid: string) {
    setGroupExpanded((cur) => {
      const next = new Set(cur)
      if (next.has(gid)) next.delete(gid)
      else next.add(gid)
      return next
    })
  }

  function revealAndFlash(cid: string) {
    // Expand the row + flash highlight + scroll into view. Used by toast
    // click after a fresh enqueue and by parent_id click for lineage.
    // The row only renders if its intention group is open, so open that too.
    setExpanded((cur) => new Set(cur).add(cid))
    if (snap) {
      const gid = STATES.flatMap((s) => snap[s] ?? []).find(
        (e) => e.content_id === cid,
      )?.group_id
      if (gid) setGroupExpanded((cur) => new Set(cur).add(gid))
    }
    setFlashCid(cid)
    requestAnimationFrame(() => {
      const el = document.querySelector(`[data-cid="${cid}"]`)
      el?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    })
    window.setTimeout(() => setFlashCid(null), 1800)
  }

  function openEffectiveConfig(cid: string) {
    // Switch to Sheet 05 (Effective config) for this run. The Effective
    // config tab keys off `selectedRun` which is the URL `run` param —
    // autopilot stores runs by content_id so cid IS the run name.
    setUrl({ tab: 'config', run: cid })
  }

  function openBlank() {
    setDialogInitialYaml(undefined)
    setDialogOpen(true)
  }

  // Close the dialog and, if we were routed here by a per-config enqueue,
  // return to the originating tab so tab=queue doesn't stick.
  function closeEnqueue() {
    setDialogOpen(false)
    try {
      const rt = sessionStorage.getItem('spinorbec.enqueueReturnTab')
      if (rt) {
        sessionStorage.removeItem('spinorbec.enqueueReturnTab')
        setUrl({ tab: rt as TabId })
      }
    } catch {
      /* ignore */
    }
  }

  // Routed here with ?enqueue=true (per-config "Enqueue this config" from
  // the Effective Config panel / Catalog) → open the dialog pre-filled
  // with the stashed YAML if present, else blank; then clear the flag.
  useEnqueueFlag(
    url.enqueue,
    () => {
      let y: string | null = null
      try {
        y = sessionStorage.getItem('spinorbec.enqueueYaml')
      } catch {
        /* sessionStorage disabled — fall through to blank */
      }
      if (y) {
        try {
          sessionStorage.removeItem('spinorbec.enqueueYaml')
        } catch {
          /* ignore */
        }
        setDialogInitialYaml(y)
        setDialogOpen(true)
      } else {
        openBlank()
      }
    },
    () => setUrl({ enqueue: false }),
  )

  function openFork(entry: AutopilotQueueEntry) {
    api
      .getEffectiveConfig(entry.content_id)
      .then((d) => {
        try {
          const text = yamlStringify(d.raw, { indent: 2, lineWidth: 0 })
          setDialogInitialYaml(text)
        } catch {
          setDialogInitialYaml(undefined)
        }
        setDialogOpen(true)
      })
      .catch(() => {
        setDialogInitialYaml(undefined)
        setDialogOpen(true)
      })
  }

  const doTag = useCallback(
    async (cid: string) => {
      const name = window.prompt(
        `Tag run ${cid.slice(0, 8)} — enter a name (e.g. paper3_fig6_final):`,
      )
      if (!name) return
      const trimmed = name.trim()
      if (!trimmed) return
      try {
        const r = await api.tagRun(trimmed, cid)
        pushToast(
          r.ok
            ? {
                content_id: cid,
                kind: 'success',
                message: `tagged "${trimmed}"`,
                onClick: () => revealAndFlash(cid),
              }
            : { content_id: cid, kind: 'error', message: 'tag failed', detail: r.error },
        )
      } catch (e) {
        pushToast({ content_id: cid, kind: 'error', message: 'tag threw', detail: String(e) })
      } finally {
        refresh()
      }
    },
    [refresh],
  )

  const doUntag = useCallback(
    async (name: string, cid: string) => {
      try {
        await api.untagRun(name)
      } catch (e) {
        pushToast({ content_id: cid, kind: 'error', message: 'untag threw', detail: String(e) })
      } finally {
        refresh()
      }
    },
    [refresh],
  )

  const doAction = useCallback(
    async (cid: string, action: 'promote' | 'cancel') => {
      setActionBusy((cur) => new Set(cur).add(cid))
      try {
        const r = await api.autopilotAction(cid, action, sessionId())
        if (r.ok) {
          pushToast({
            content_id: cid,
            kind: 'success',
            message:
              action === 'promote'
                ? 'promoted to :dispatch'
                : 'cancelled (→ killed_bug)',
            detail:
              action === 'promote'
                ? 'autopilot will dispatch on the next tick'
                : undefined,
            onClick: () => revealAndFlash(cid),
          })
        } else {
          pushToast({
            content_id: cid,
            kind: 'error',
            message: action + ' failed',
            detail: r.error,
          })
        }
      } catch (e) {
        pushToast({
          content_id: cid,
          kind: 'error',
          message: action + ' threw',
          detail: String(e),
        })
      } finally {
        setActionBusy((cur) => {
          const next = new Set(cur)
          next.delete(cid)
          return next
        })
        refresh()
      }
    },
    [refresh],
  )

  return (
    <div className="space-y-5">
      <SummaryStrip
        counts={counts}
        loading={!snap && !error}
        error={error}
        dryRun={dryRun}
        paused={paused}
        onEnqueueClick={openBlank}
      />
      {snap &&
        groupByIntention(snap).map((g) => (
          <IntentionGroup
            key={g.group_id}
            group={g}
            groupOpen={g.cells.length === 1 || groupExpanded.has(g.group_id)}
            expanded={expanded}
            flashCid={flashCid}
            actionBusy={actionBusy}
            tagsByCid={tagsByCid}
            onToggleGroup={() => toggleGroup(g.group_id)}
            onToggleExpand={toggleExpand}
            onFork={openFork}
            onAction={doAction}
            onTag={doTag}
            onUntag={doUntag}
            onJumpToCid={revealAndFlash}
            onOpenConfig={openEffectiveConfig}
          />
        ))}
      {snap && Object.values(counts ?? {}).every((n) => n === 0) && (
        <Card>
          <CardContent className="p-6 text-sm text-muted-foreground text-center">
            queue is empty
          </CardContent>
        </Card>
      )}
      <EnqueueDialog
        open={dialogOpen}
        onClose={closeEnqueue}
        initialYaml={dialogInitialYaml}
        dryRun={dryRun}
        paused={paused}
        onCommitted={(resp) => {
          refresh()
          pushToast({
            content_id: resp.content_id,
            kind: 'success',
            message:
              dryRun
                ? 'enqueued (DRY-RUN) — synthetic outcome will be written'
                : `enqueued on ${resp.backend === 'local' ? 'suzume' : 'tsubame'}`,
            detail:
              `autonomy = :${resp.autonomy_level} · profile = ${resp.profile}`,
            onClick: () => revealAndFlash(resp.content_id),
          })
        }}
      />
      <QueueToastStack toasts={toasts} onDismiss={dismissToast} />
    </div>
  )
}

function SummaryStrip({
  counts,
  loading,
  error,
  dryRun,
  paused,
  onEnqueueClick,
}: {
  counts: Record<State, number> | null
  loading: boolean
  error: string | null
  dryRun: boolean
  paused: boolean
  onEnqueueClick: () => void
}) {
  const enqueueLabel = dryRun ? '+ Enqueue [DRY-RUN]' : '+ Enqueue'
  return (
    <Card>
      <CardContent className="p-5 flex flex-wrap items-center gap-x-7 gap-y-2">
        <span className="font-mono text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
          Autopilot queue
        </span>
        {STATES.map((s) => (
          <StateChip
            key={s}
            label={STATE_LABEL[s]}
            count={counts?.[s] ?? 0}
            color={STATE_COLOR[s]}
          />
        ))}
        {dryRun && (
          <span
            className="font-mono text-[10px] uppercase tracking-[0.10em] px-1.5 py-px"
            style={{
              background:
                'color-mix(in oklch, var(--vermillion,#d97a3c) 18%, transparent)',
              color: 'var(--vermillion,#d97a3c)',
            }}
            title="autopilot is in dry-run mode (sentinel file present)"
          >
            dry-run
          </span>
        )}
        {paused && (
          <span
            className="font-mono text-[10px] uppercase tracking-[0.10em] px-1.5 py-px"
            style={{
              background: 'color-mix(in oklch, var(--ink-faint) 18%, transparent)',
              color: 'var(--ink-soft)',
            }}
            title="autopilot pause sentinel set — new dispatches skipped"
          >
            paused
          </span>
        )}
        <span className="ml-auto flex items-center gap-3">
          <button
            type="button"
            onClick={onEnqueueClick}
            className="font-mono text-[11px] uppercase tracking-[0.10em] px-3 py-1.5 border border-[var(--ink)] text-[var(--ink)] hover:bg-[var(--ink)] hover:text-background"
            style={{ borderRadius: 0 }}
          >
            {enqueueLabel}
          </button>
          <span className="font-mono text-[10px] text-[var(--ink-faint)]">
            {loading ? 'loading…' : 'updates every 5 s'}
          </span>
        </span>
        {error && (
          <span className="font-mono text-[11px] text-[var(--t-red,#d94e1f)] w-full">
            {error}
          </span>
        )}
      </CardContent>
    </Card>
  )
}

function StateChip({
  label,
  count,
  color,
}: {
  label: string
  count: number
  color: string
}) {
  return (
    <span className="inline-flex items-baseline gap-2">
      <span
        className="inline-block w-2 h-2 rounded-full"
        style={{ background: color }}
        aria-hidden
      />
      <span className="text-[var(--ink-soft)] text-[11px] uppercase tracking-[0.10em]">
        {label}
      </span>
      <span
        className="font-mono numeric text-[15px]"
        style={{ color: count > 0 ? color : 'var(--ink-faint)' }}
      >
        {count}
      </span>
    </span>
  )
}

function TagPill({ name, onRemove }: { name: string; onRemove: () => void }) {
  return (
    <span
      data-row-action
      className="inline-flex items-center gap-1 font-mono text-[10px] px-1.5 py-px border"
      style={{
        borderRadius: 0,
        borderColor: 'var(--t-cyan,#4a8bb8)',
        color: 'var(--t-cyan,#4a8bb8)',
        background: 'color-mix(in oklch, var(--t-cyan,#4a8bb8) 10%, transparent)',
      }}
      title={`tag: ${name}`}
    >
      {name}
      <button
        type="button"
        data-row-action
        onClick={(ev) => {
          ev.stopPropagation()
          onRemove()
        }}
        className="hover:text-[var(--t-red,#d94e1f)] leading-none"
        title={`remove tag "${name}"`}
        aria-label={`remove tag ${name}`}
      >
        ×
      </button>
    </span>
  )
}

function Rollup({ rollup }: { rollup: Record<State, number> }) {
  const active = STATES.filter((s) => rollup[s] > 0)
  return (
    <span className="inline-flex items-baseline gap-2 font-mono text-[12px]">
      {active.map((s) => (
        <span
          key={s}
          style={{ color: STATE_COLOR[s] }}
          title={STATE_LABEL[s]}
          className="inline-flex items-baseline gap-0.5"
        >
          <span className="numeric">{rollup[s]}</span>
          <span aria-hidden>{STATE_SYMBOL[s]}</span>
        </span>
      ))}
    </span>
  )
}

function IntentionGroup({
  group,
  groupOpen,
  expanded,
  flashCid,
  actionBusy,
  tagsByCid,
  onToggleGroup,
  onToggleExpand,
  onFork,
  onAction,
  onTag,
  onUntag,
  onJumpToCid,
  onOpenConfig,
}: {
  group: IntentionGroupData
  groupOpen: boolean
  expanded: Set<string>
  flashCid: string | null
  actionBusy: Set<string>
  tagsByCid: Record<string, string[]>
  onToggleGroup: () => void
  onToggleExpand: (cid: string) => void
  onFork: (e: AutopilotQueueEntry) => void
  onAction: (cid: string, action: 'promote' | 'cancel') => void
  onTag: (cid: string) => void
  onUntag: (name: string, cid: string) => void
  onJumpToCid: (cid: string) => void
  onOpenConfig: (cid: string) => void
}) {
  const isSingleton = group.total === 1
  // A group's headline colour follows its "worst" live state so a sweep
  // with any bug stands out: bug > data > running > pending > done.
  const headState: State =
    group.rollup.killed_bug > 0
      ? 'killed_bug'
      : group.rollup.killed_data > 0
      ? 'killed_data'
      : group.rollup.running > 0
      ? 'running'
      : group.rollup.pending > 0
      ? 'pending'
      : 'done'

  return (
    <Card>
      <CardContent className="p-0">
        <div
          className={
            'px-5 py-3 border-b border-[var(--ink-faint)] flex items-center gap-3 ' +
            (isSingleton ? '' : 'cursor-pointer select-none')
          }
          style={{
            background:
              'color-mix(in oklch, ' + STATE_COLOR[headState] + ' 7%, transparent)',
          }}
          onClick={isSingleton ? undefined : onToggleGroup}
        >
          {!isSingleton && (
            <span className="text-[var(--ink-faint)] font-mono text-xs">
              {groupOpen ? '▾' : '▸'}
            </span>
          )}
          <span
            className="inline-block w-2 h-2 rounded-full shrink-0"
            style={{ background: STATE_COLOR[headState] }}
            aria-hidden
          />
          <span className="font-mono text-[12px] text-[var(--ink)] truncate">
            {group.label}
          </span>
          {!isSingleton && (
            <span className="font-mono text-[10.5px] text-[var(--ink-faint)] shrink-0">
              {group.group_id.startsWith('grp-')
                ? group.group_id
                : group.group_id.slice(0, 12)}
            </span>
          )}
          <span className="ml-auto flex items-baseline gap-3 shrink-0">
            <span className="font-mono numeric text-[13px] text-[var(--ink-soft)]">
              {group.total}
            </span>
            <Rollup rollup={group.rollup} />
          </span>
        </div>
        {groupOpen && (
          <div className="overflow-auto">
            <table className="w-full text-xs font-mono">
              <thead className="text-[var(--ink-faint)] uppercase tracking-[0.06em] text-[10px]">
                <tr className="border-b border-[var(--ink-faint)]">
                  <th className="px-3 py-2 text-left w-6"></th>
                  <th className="px-3 py-2 text-left">cid</th>
                  <th className="px-3 py-2 text-left">state</th>
                  <th className="px-3 py-2 text-left">recipe / autonomy</th>
                  <th className="px-3 py-2 text-left">profile</th>
                  <th className="px-3 py-2 text-right">attempt</th>
                  <th className="px-3 py-2 text-right">est wall (h)</th>
                  <th className="px-3 py-2 text-right">gpu·h done</th>
                  <th className="px-3 py-2 text-left">job_id</th>
                  <th className="px-3 py-2 text-left">parent</th>
                  <th className="px-3 py-2 text-left">reason / by</th>
                  <th className="px-3 py-2 text-right">actions</th>
                </tr>
              </thead>
              <tbody>
                {group.cells.map((e) => (
                  <EntryRow
                    key={e.content_id + '@' + e.enqueued_at}
                    e={e}
                    expanded={expanded.has(e.content_id)}
                    flashed={flashCid === e.content_id}
                    busy={actionBusy.has(e.content_id)}
                    tags={tagsByCid[e.content_id] ?? []}
                    onToggle={() => onToggleExpand(e.content_id)}
                    onFork={() => onFork(e)}
                    onAction={(action) => onAction(e.content_id, action)}
                    onTag={() => onTag(e.content_id)}
                    onUntag={(name) => onUntag(name, e.content_id)}
                    onJumpToCid={onJumpToCid}
                    onOpenConfig={onOpenConfig}
                  />
                ))}
              </tbody>
            </table>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function EntryRow({
  e,
  expanded,
  flashed,
  busy,
  tags,
  onToggle,
  onFork,
  onAction,
  onTag,
  onUntag,
  onJumpToCid,
  onOpenConfig,
}: {
  e: AutopilotQueueEntry
  expanded: boolean
  flashed: boolean
  busy: boolean
  tags: string[]
  onToggle: () => void
  onFork: () => void
  onAction: (action: 'promote' | 'cancel') => void
  onTag: () => void
  onUntag: (name: string) => void
  onJumpToCid: (cid: string) => void
  onOpenConfig: (cid: string) => void
}) {
  const reasonOrBy =
    e.status === 'killed_data' || e.status === 'killed_bug'
      ? e.kill_reason
      : e.enqueued_by
  const flashStyle: React.CSSProperties = flashed
    ? {
        background:
          'color-mix(in oklch, var(--t-cyan,#4a8bb8) 22%, transparent)',
        transition: 'background 1.4s ease-out',
      }
    : {}
  const isPending = e.status === 'pending'
  const isPropose = e.recipe.autonomy_level === 'propose'

  return (
    <>
      <tr
        data-cid={e.content_id}
        style={flashStyle}
        className="border-b border-[var(--ink-faint)] hover:bg-[color-mix(in_oklch,var(--ink)_3%,transparent)] cursor-pointer"
        onClick={(ev) => {
          // Don't toggle when clicking on the action buttons or parent link.
          if ((ev.target as HTMLElement).closest('[data-row-action]')) return
          onToggle()
        }}
      >
        <td className="px-3 py-2 text-[var(--ink-faint)] select-none">
          {expanded ? '▾' : '▸'}
        </td>
        <td className="px-3 py-2" title={e.content_id}>
          <span className="flex flex-wrap items-center gap-1.5">
            <button
              type="button"
              data-row-action
              onClick={(ev) => {
                ev.stopPropagation()
                onOpenConfig(e.content_id)
              }}
              className="font-mono text-[var(--ink)] underline decoration-dotted underline-offset-2 hover:text-[var(--t-cyan,#4a8bb8)]"
              title={`open Effective config for ${e.content_id}`}
            >
              {e.content_id.slice(0, 8)}
            </button>
            {tags.map((name) => (
              <TagPill
                key={name}
                name={name}
                onRemove={() => onUntag(name)}
              />
            ))}
            <button
              type="button"
              data-row-action
              onClick={(ev) => {
                ev.stopPropagation()
                onTag()
              }}
              className="font-mono text-[10px] text-[var(--ink-faint)] hover:text-[var(--ink)] px-1 leading-none"
              title="pin a stable human name to this run"
            >
              +tag
            </button>
          </span>
        </td>
        <td className="px-3 py-2 whitespace-nowrap" style={{ color: STATE_COLOR[e.status] }}>
          <span aria-hidden>{STATE_SYMBOL[e.status]}</span>{' '}
          {STATE_LABEL[e.status]}
        </td>
        <td className="px-3 py-2 text-[var(--ink-soft)]">
          {e.recipe.name ?? '—'}{' '}
          <span className="text-[var(--ink-faint)]">
            [{e.recipe.autonomy_level}]
          </span>
        </td>
        <td className="px-3 py-2 text-[var(--ink-soft)]">{e.backend.profile}</td>
        <td className="px-3 py-2 text-right numeric">{e.attempt}</td>
        <td className="px-3 py-2 text-right numeric">
          {e.backend.estimated_walltime_hours.toFixed(2)}
        </td>
        <td className="px-3 py-2 text-right numeric">
          {e.budget.gpu_hours_realized.toFixed(2)}
        </td>
        <td
          className="px-3 py-2 text-[var(--ink-faint)]"
          title={e.backend.job_id ?? ''}
        >
          {e.backend.job_id ? e.backend.job_id.slice(0, 12) : '—'}
        </td>
        <td
          className="px-3 py-2 text-[var(--ink-faint)]"
          title={e.parent_id ?? ''}
        >
          {e.parent_id ? (
            <button
              type="button"
              data-row-action
              onClick={(ev) => {
                ev.stopPropagation()
                onJumpToCid(e.parent_id!)
              }}
              className="font-mono text-[10px] underline decoration-dotted underline-offset-2 hover:text-[var(--ink)]"
              title={`jump to parent ${e.parent_id}`}
            >
              {e.parent_id.slice(0, 8)}
            </button>
          ) : (
            '—'
          )}
        </td>
        <td
          className="px-3 py-2 text-[var(--ink-soft)] truncate max-w-[280px]"
          title={reasonOrBy}
        >
          {reasonOrBy}
        </td>
        <td
          className="px-3 py-2 text-right whitespace-nowrap"
          data-row-action
          onClick={(ev) => ev.stopPropagation()}
        >
          <RowActions
            isPending={isPending}
            isPropose={isPropose}
            busy={busy}
            onFork={onFork}
            onAction={onAction}
          />
        </td>
      </tr>
      {expanded && (
        <tr style={flashStyle}>
          <td colSpan={12} className="px-3 py-3 bg-[color-mix(in_oklch,var(--ink)_2%,transparent)] border-b border-[var(--ink-faint)]">
            <EntryDetail
              e={e}
              onOpenConfig={() => onOpenConfig(e.content_id)}
            />
          </td>
        </tr>
      )}
    </>
  )
}

function RowActions({
  isPending,
  isPropose,
  busy,
  onFork,
  onAction,
}: {
  isPending: boolean
  isPropose: boolean
  busy: boolean
  onFork: () => void
  onAction: (action: 'promote' | 'cancel') => void
}) {
  const [confirmCancel, setConfirmCancel] = useState(false)
  return (
    <span className="inline-flex gap-1.5">
      {isPending && isPropose && (
        <ActionButton
          label={busy ? '…' : 'promote'}
          tone="ok"
          disabled={busy}
          onClick={() => onAction('promote')}
          title="autonomy_level :propose → :dispatch (tick will submit on next pass)"
        />
      )}
      {isPending &&
        (confirmCancel ? (
          <>
            <ActionButton
              label="confirm?"
              tone="bad"
              disabled={busy}
              onClick={() => {
                setConfirmCancel(false)
                onAction('cancel')
              }}
            />
            <ActionButton
              label="no"
              tone="muted"
              disabled={busy}
              onClick={() => setConfirmCancel(false)}
            />
          </>
        ) : (
          <ActionButton
            label="cancel"
            tone="bad"
            disabled={busy}
            onClick={() => setConfirmCancel(true)}
            title="move :pending → :killed_bug"
          />
        ))}
      <ActionButton
        label="fork"
        tone="muted"
        disabled={busy}
        onClick={onFork}
        title="open Enqueue dialog pre-filled with this run's YAML"
      />
    </span>
  )
}

function ActionButton({
  label,
  tone,
  disabled,
  onClick,
  title,
}: {
  label: string
  tone: 'ok' | 'bad' | 'muted'
  disabled?: boolean
  onClick: () => void
  title?: string
}) {
  const color =
    tone === 'ok'
      ? 'var(--t-green,#5a8b5a)'
      : tone === 'bad'
      ? 'var(--t-red,#d94e1f)'
      : 'var(--ink-soft)'
  return (
    <button
      type="button"
      disabled={disabled}
      title={title}
      onClick={onClick}
      className="font-mono text-[10px] uppercase tracking-[0.10em] px-2 py-0.5 border disabled:opacity-50"
      style={{
        borderRadius: 0,
        borderColor: color,
        color,
      }}
    >
      {label}
    </button>
  )
}

function EntryDetail({
  e,
  onOpenConfig,
}: {
  e: AutopilotQueueEntry
  onOpenConfig: () => void
}) {
  const recipeParamsJson = (() => {
    try {
      return JSON.stringify(e.recipe.name ? e.recipe : {}, null, 2)
    } catch {
      return '{}'
    }
  })()
  return (
    <div className="space-y-3">
      <div className="flex flex-wrap gap-3 text-[11px] font-mono">
        <button
          type="button"
          onClick={onOpenConfig}
          className="px-2 py-1 border border-[var(--t-cyan,#4a8bb8)] text-[var(--t-cyan,#4a8bb8)] hover:bg-[color-mix(in_oklch,var(--t-cyan,#4a8bb8)_12%,transparent)]"
          style={{ borderRadius: 0 }}
        >
          open in Effective config →
        </button>
        <a
          href={`/api/effective_config/${encodeURIComponent(e.content_id)}`}
          target="_blank"
          rel="noopener noreferrer"
          className="px-2 py-1 border border-[var(--ink-faint)] text-[var(--ink-soft)] hover:border-[var(--ink)] hover:text-[var(--ink)]"
          style={{ borderRadius: 0 }}
        >
          raw JSON ↗
        </a>
        <button
          type="button"
          onClick={() => {
            navigator.clipboard?.writeText(e.run_dir)
          }}
          className="px-2 py-1 border border-[var(--ink-faint)] text-[var(--ink-soft)] hover:border-[var(--ink)] hover:text-[var(--ink)]"
          style={{ borderRadius: 0 }}
          title="copy run_dir to clipboard"
        >
          copy run_dir
        </button>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-3 text-xs">
      <DetailField label="content_id" value={e.content_id} mono />
      <DetailField label="enqueued_at" value={e.enqueued_at} mono />
      <DetailField label="enqueued_by" value={e.enqueued_by} mono />
      <DetailField label="run_dir" value={e.run_dir} mono />
      <DetailField label="backend" value={e.backend.type} mono />
      <DetailField label="profile" value={e.backend.profile} mono />
      <DetailField
        label="job_id"
        value={e.backend.job_id ?? '(unset)'}
        mono
      />
      <DetailField
        label="estimated walltime"
        value={`${e.backend.estimated_walltime_hours.toFixed(2)} h`}
        mono
      />
      <DetailField
        label="gpu·h realized"
        value={e.budget.gpu_hours_realized.toFixed(3)}
        mono
      />
      <DetailField
        label="attempt"
        value={String(e.attempt)}
        mono
      />
      <DetailField
        label="priority"
        value={String(e.priority)}
        mono
      />
      <DetailField
        label="autonomy_level"
        value={`:${e.recipe.autonomy_level}`}
        mono
      />
      {e.kill_reason && (
        <DetailField
          label="kill_reason"
          value={e.kill_reason}
          full
          mono
        />
      )}
      <div className="col-span-1 md:col-span-2">
        <div className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono mb-1">
          recipe (name + autonomy)
        </div>
        <pre
          className="text-[11px] p-2 border border-[var(--ink-faint)] overflow-auto max-h-32 font-mono whitespace-pre-wrap"
          style={{ borderRadius: 0 }}
        >
          {recipeParamsJson}
        </pre>
      </div>
      </div>
    </div>
  )
}

function DetailField({
  label,
  value,
  mono = false,
  full = false,
}: {
  label: string
  value: string
  mono?: boolean
  full?: boolean
}) {
  return (
    <div className={full ? 'col-span-1 md:col-span-2' : ''}>
      <div className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono">
        {label}
      </div>
      <div
        className={
          'text-[var(--ink)] mt-0.5 break-all ' + (mono ? 'font-mono' : '')
        }
        style={{ wordBreak: 'break-word' }}
      >
        {value}
      </div>
    </div>
  )
}
