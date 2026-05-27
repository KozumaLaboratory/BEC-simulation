import { useEffect, useMemo, useRef, useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { api, type AutopilotQueueEntry, type AutopilotQueueResponse } from '@/api'

// 5-state autopilot queue viewer. Read-only — operate via the CLI
// (`julia --project=. scripts/autopilot.jl pause | resume | drain | why`).
// State counts on top, grouped per-state tables below. Polls every 5 s.

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

function useAutopilotQueue(intervalMs = 5000) {
  const [snap, setSnap] = useState<AutopilotQueueResponse | null>(null)
  const [error, setError] = useState<string | null>(null)
  const stopRef = useRef(false)

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
    void tick()
    const id = window.setInterval(tick, intervalMs)
    return () => {
      stopRef.current = true
      window.clearInterval(id)
    }
  }, [intervalMs])

  return { snap, error }
}

export function QueuePanel() {
  const { snap, error } = useAutopilotQueue()

  const counts = useMemo(() => {
    if (!snap) return null
    return Object.fromEntries(
      STATES.map((s) => [s, snap[s]?.length ?? 0]),
    ) as Record<State, number>
  }, [snap])

  return (
    <div className="space-y-5">
      <SummaryStrip counts={counts} loading={!snap && !error} error={error} />
      {snap &&
        STATES.map((s) =>
          (snap[s]?.length ?? 0) > 0 ? (
            <StateGroup key={s} state={s} entries={snap[s]} />
          ) : null,
        )}
      {snap && Object.values(counts ?? {}).every((n) => n === 0) && (
        <Card>
          <CardContent className="p-6 text-sm text-muted-foreground text-center">
            queue is empty
          </CardContent>
        </Card>
      )}
    </div>
  )
}

function SummaryStrip({
  counts,
  loading,
  error,
}: {
  counts: Record<State, number> | null
  loading: boolean
  error: string | null
}) {
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
        <span className="ml-auto font-mono text-[10px] text-[var(--ink-faint)]">
          {loading ? 'loading…' : 'updates every 5 s'}
        </span>
        {error && (
          <span className="font-mono text-[11px] text-[var(--t-red,#d94e1f)]">
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
}: {
  state: State
  entries: AutopilotQueueEntry[]
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
                <th className="px-3 py-2 text-left">cid</th>
                <th className="px-3 py-2 text-left">recipe / autonomy</th>
                <th className="px-3 py-2 text-left">profile</th>
                <th className="px-3 py-2 text-right">attempt</th>
                <th className="px-3 py-2 text-right">est wall (h)</th>
                <th className="px-3 py-2 text-right">gpu·h done</th>
                <th className="px-3 py-2 text-left">job_id</th>
                <th className="px-3 py-2 text-left">parent</th>
                <th className="px-3 py-2 text-left">reason / by</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((e) => (
                <EntryRow key={e.content_id + '@' + e.enqueued_at} e={e} />
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  )
}

function EntryRow({ e }: { e: AutopilotQueueEntry }) {
  const reasonOrBy =
    e.status === 'killed_data' || e.status === 'killed_bug'
      ? e.kill_reason
      : e.enqueued_by
  return (
    <tr className="border-b border-[var(--ink-faint)] hover:bg-[color-mix(in_oklch,var(--ink)_3%,transparent)]">
      <td className="px-3 py-2 text-[var(--ink)]" title={e.content_id}>
        {e.content_id.slice(0, 8)}
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
        {e.parent_id ? e.parent_id.slice(0, 8) : '—'}
      </td>
      <td
        className="px-3 py-2 text-[var(--ink-soft)] truncate max-w-[280px]"
        title={reasonOrBy}
      >
        {reasonOrBy}
      </td>
    </tr>
  )
}
