// Per-entry ETA (estimated time to terminal) for the queue panel.
//
// Backend stamps four lifecycle timestamps on each entry:
//   enqueued_at         — when the user / recipe called enqueue!
//   dispatched_at       — when the tick fired dispatch! (qsub / subprocess spawn)
//   cluster_started_at  — when the scheduler flipped pending → running (qw → r)
//   terminal_at         — when status went to :done / :killed_*
//
// ETA composition (predicted remaining time until terminal):
//
//   :pending                                 ETA ≥ est_walltime           (cluster qw unknown)
//   :running + cluster_state :pending  (qw)  ETA ≥ est_walltime           (qw remaining unknown)
//   :running + cluster_state :running        ETA = max(0, est − ran)      (live)
//   :done / :killed_*                        no ETA
//
// "≥" prefix marks lower bounds (we know compute will take at least
// `est_walltime`, but TSUBAME-side qw wait is invisible without
// `qstat -j` scheduler-hint integration — that's a v2 upgrade).
//
// Sub-helpers expose the raw elapsed times too so callers that want
// the audit-trail in a hover title can render the per-phase breakdown.

import type { AutopilotQueueEntry } from '@/api'

const SECOND = 1000
const MINUTE = 60 * SECOND
const HOUR = 60 * MINUTE
const DAY = 24 * HOUR

/** Format a millisecond duration as "5s", "3m", "2h 15m", "1d 4h". */
export function humanizeElapsed(ms: number): string {
  if (!Number.isFinite(ms) || ms < 0) return '?'
  if (ms < MINUTE) return `${Math.floor(ms / SECOND)}s`
  if (ms < HOUR) return `${Math.floor(ms / MINUTE)}m`
  if (ms < DAY) {
    const h = Math.floor(ms / HOUR)
    const m = Math.floor((ms % HOUR) / MINUTE)
    return m === 0 ? `${h}h` : `${h}h ${m}m`
  }
  const d = Math.floor(ms / DAY)
  const h = Math.floor((ms % DAY) / HOUR)
  return h === 0 ? `${d}d` : `${d}d ${h}h`
}

/** ISO string → epoch ms, or null if invalid/missing. */
function ms(iso: string | null | undefined): number | null {
  if (!iso) return null
  const t = Date.parse(iso)
  return Number.isFinite(t) ? t : null
}

/** Estimated remaining time until this entry hits a terminal state.
 *
 * Returned `eta` is the human string for the queue-panel cell;
 * `lower_bound` is true when we know it's at least that long (cluster
 * qw addend unknown); `basis` explains where the number came from for
 * a hover-title audit trail.
 *
 * Returns null for terminal entries (no ETA to predict).
 */
export function entryETA(
  e: AutopilotQueueEntry,
  now: number,
): {
  eta: string
  lower_bound: boolean
  basis: string
} | null {
  if (e.status === 'done' || e.status === 'killed_data' || e.status === 'killed_bug') {
    return null
  }
  const estMs = e.backend.estimated_walltime_hours * HOUR
  const cst = ms(e.timing?.cluster_started_at ?? null)
  const cstate = e.timing?.cluster_state ?? 'unknown'

  // Compute actually started: subtract elapsed from estimate.
  if (e.status === 'running' && cstate === 'running' && cst) {
    const ran = now - cst
    const remaining = Math.max(0, estMs - ran)
    return {
      eta: humanizeElapsed(remaining),
      lower_bound: false,
      basis: `est ${humanizeElapsed(estMs)} − ran ${humanizeElapsed(ran)}`,
    }
  }
  // Pending or stuck in cluster qw: compute hasn't started. If we have
  // a historical qw median for this (backend, profile), use it to
  // tighten the estimate — otherwise fall back to the lower-bound view
  // ("at least est_walltime, qw remaining unknown").
  const qwMedianS = e.timing?.qw_median_s ?? null
  if (qwMedianS !== null) {
    const qwRemainingMs = qwAdjustedRemaining(e, qwMedianS, now)
    return {
      eta: humanizeElapsed(qwRemainingMs + estMs),
      lower_bound: false,
      basis:
        `est compute ${humanizeElapsed(estMs)} + qw remaining ` +
        `~${humanizeElapsed(qwRemainingMs)} (historical median ${humanizeElapsed(qwMedianS * 1000)})`,
    }
  }
  return {
    eta: humanizeElapsed(estMs),
    lower_bound: true,
    basis: `est compute ${humanizeElapsed(estMs)} (cluster qw remaining unknown)`,
  }
}

/** When we have a historical qw median, the remaining wait is
 * `median - already_waited`. For :pending entries we haven't waited
 * yet (dispatched_at not stamped), so the full median applies. For
 * entries already in qw (dispatched but not yet running), subtract
 * the already-elapsed qw time. Floor at 0 — a job past its median
 * isn't going to start MORE recently. */
function qwAdjustedRemaining(
  e: AutopilotQueueEntry,
  qwMedianS: number,
  now: number,
): number {
  const disp = ms(e.timing?.dispatched_at ?? null)
  const medianMs = qwMedianS * 1000
  if (!disp) return medianMs
  const waited = now - disp
  return Math.max(0, medianMs - waited)
}

/** Per-phase elapsed breakdown for hover-title audit. Always
 * available regardless of ETA. */
export function entryElapsedBreakdown(
  e: AutopilotQueueEntry,
  now: number,
): string {
  const enq = ms(e.enqueued_at)
  const disp = ms(e.timing?.dispatched_at ?? null)
  const cst = ms(e.timing?.cluster_started_at ?? null)
  const term = ms(e.timing?.terminal_at ?? null)
  const parts: string[] = []
  if (enq && disp) parts.push(`queue ${humanizeElapsed(disp - enq)}`)
  if (disp && cst) parts.push(`qw ${humanizeElapsed(cst - disp)}`)
  if (cst) {
    const end = term ?? now
    if (end) parts.push(`${term ? 'run' : 'running'} ${humanizeElapsed(end - cst)}`)
  }
  if (enq) {
    const end = term ?? now
    parts.push(`total ${humanizeElapsed(end - enq)}`)
  }
  return parts.join(' · ') || '(no timing data)'
}
