import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { stringify as yamlStringify } from 'yaml'
import { Card, CardContent } from '@/components/ui/card'
import {
  api,
  type AutopilotQueueEntry,
  type AutopilotQueueResponse,
} from '@/api'
import { useDashboardURL } from '@/state/useDashboardURL'
import { EnqueueDialog } from '@/components/EnqueueDialog'
import { QueueToastStack, type QueueToastInfo } from '@/components/QueueToast'

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
  const [error, setError] = useState<string | null>(null)
  const stopRef = useRef(false)
  const tickRef = useRef<(() => Promise<void>) | null>(null)

  useEffect(() => {
    stopRef.current = false
    const tick = async () => {
      if (document.hidden) return
      try {
        const q = await api.autopilotQueue()
        if (!stopRef.current) {
          setSnap(q)
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
  return { snap, error, refresh }
}

export function QueuePanel() {
  const { snap, error, refresh } = useAutopilotQueue()
  const [, setUrl] = useDashboardURL()
  const [dialogOpen, setDialogOpen] = useState(false)
  const [dialogInitialYaml, setDialogInitialYaml] = useState<string | undefined>()
  const [expanded, setExpanded] = useState<Set<string>>(() => new Set())
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

  function revealAndFlash(cid: string) {
    // Expand the row + flash highlight + scroll into view. Used by toast
    // click after a fresh enqueue and by parent_id click for lineage.
    setExpanded((cur) => new Set(cur).add(cid))
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
        STATES.map((s) =>
          (snap[s]?.length ?? 0) > 0 ? (
            <StateGroup
              key={s}
              state={s}
              entries={snap[s]}
              expanded={expanded}
              flashCid={flashCid}
              actionBusy={actionBusy}
              onToggleExpand={toggleExpand}
              onFork={openFork}
              onAction={doAction}
              onJumpToCid={revealAndFlash}
              onOpenConfig={openEffectiveConfig}
            />
          ) : null,
        )}
      {snap && Object.values(counts ?? {}).every((n) => n === 0) && (
        <Card>
          <CardContent className="p-6 text-sm text-muted-foreground text-center">
            queue is empty
          </CardContent>
        </Card>
      )}
      <EnqueueDialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
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

function StateGroup({
  state,
  entries,
  expanded,
  flashCid,
  actionBusy,
  onToggleExpand,
  onFork,
  onAction,
  onJumpToCid,
  onOpenConfig,
}: {
  state: State
  entries: AutopilotQueueEntry[]
  expanded: Set<string>
  flashCid: string | null
  actionBusy: Set<string>
  onToggleExpand: (cid: string) => void
  onFork: (e: AutopilotQueueEntry) => void
  onAction: (cid: string, action: 'promote' | 'cancel') => void
  onJumpToCid: (cid: string) => void
  onOpenConfig: (cid: string) => void
}) {
  return (
    <Card>
      <CardContent className="p-0">
        <div
          className="px-5 py-3 border-b border-[var(--ink-faint)] flex items-baseline gap-2"
          style={{
            background:
              'color-mix(in oklch, ' + STATE_COLOR[state] + ' 7%, transparent)',
          }}
        >
          <span
            className="inline-block w-2 h-2 rounded-full"
            style={{ background: STATE_COLOR[state] }}
            aria-hidden
          />
          <span className="font-mono text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink)]">
            {STATE_LABEL[state]} · {entries.length}
          </span>
        </div>
        <div className="overflow-auto">
          <table className="w-full text-xs font-mono">
            <thead className="text-[var(--ink-faint)] uppercase tracking-[0.06em] text-[10px]">
              <tr className="border-b border-[var(--ink-faint)]">
                <th className="px-3 py-2 text-left w-6"></th>
                <th className="px-3 py-2 text-left">cid</th>
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
              {entries.map((e) => (
                <EntryRow
                  key={e.content_id + '@' + e.enqueued_at}
                  e={e}
                  expanded={expanded.has(e.content_id)}
                  flashed={flashCid === e.content_id}
                  busy={actionBusy.has(e.content_id)}
                  onToggle={() => onToggleExpand(e.content_id)}
                  onFork={() => onFork(e)}
                  onAction={(action) => onAction(e.content_id, action)}
                  onJumpToCid={onJumpToCid}
                  onOpenConfig={onOpenConfig}
                />
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  )
}

function EntryRow({
  e,
  expanded,
  flashed,
  busy,
  onToggle,
  onFork,
  onAction,
  onJumpToCid,
  onOpenConfig,
}: {
  e: AutopilotQueueEntry
  expanded: boolean
  flashed: boolean
  busy: boolean
  onToggle: () => void
  onFork: () => void
  onAction: (action: 'promote' | 'cancel') => void
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
          <td colSpan={11} className="px-3 py-3 bg-[color-mix(in_oklch,var(--ink)_2%,transparent)] border-b border-[var(--ink-faint)]">
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
