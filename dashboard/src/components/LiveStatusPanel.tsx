import {
  useLiveRuns,
  useLiveStatus,
  useScanStatus,
} from '@/state/useLiveRuns'
import { Sparkline } from '@/components/Sparkline'

interface Props {
  /** Currently-selected run name; if it's actively writing live status,
   * its details are shown. The panel always lists every active run. */
  run: string | null
  /** Optional: clicking an entry in the active-runs list calls this with
   * the run name. Without it the list is read-only. */
  onSelect?: (run: string) => void
  className?: string
}

function _formatEta(eta_s: number): string {
  if (!Number.isFinite(eta_s) || eta_s < 0) return '?'
  if (eta_s < 60) return `${Math.round(eta_s)}s`
  if (eta_s < 3600) return `${Math.round(eta_s / 60)}m`
  if (eta_s < 86400) {
    const h = Math.floor(eta_s / 3600)
    const m = Math.round((eta_s - h * 3600) / 60)
    return `${h}h${m}m`
  }
  const d = Math.floor(eta_s / 86400)
  const h = Math.round((eta_s - d * 86400) / 3600)
  return `${d}d${h}h`
}

/**
 * "What's running right now" panel: lists every run whose
 * `_live_status.json` was touched in the last 5 min, and shows the
 * latest step / energy / norm / m-populations + scan-points-done / ETA
 * for the selected run.
 *
 * Lightweight by design — pure JSON polling, no charts, no FFT, no
 * heavy 3D. Intended as a permanent corner widget; the dashboard's
 * heavyweight panels still drive the bulk of the UI.
 */
export function LiveStatusPanel({ run, onSelect, className = '' }: Props) {
  const { runs, error: listErr } = useLiveRuns()
  const { status, history, error: statusErr } = useLiveStatus(run)
  const { status: scan } = useScanStatus(run)

  if (listErr) {
    return (
      <div className={`text-xs text-red-500 ${className}`}>
        live status unavailable: {listErr}
      </div>
    )
  }

  if (runs.length === 0) {
    return (
      <div className={`text-xs text-gray-500 ${className}`}>no active runs</div>
    )
  }

  return (
    <div className={`flex flex-col gap-2 text-xs ${className}`}>
      <div>
        <div className="font-semibold text-gray-700">Active runs</div>
        <ul className="mt-1 ml-1 space-y-0.5">
          {runs.map((r) => {
            const selected = r.run === run
            const baseClass = selected
              ? 'text-blue-600 font-mono'
              : 'text-gray-700 font-mono'
            return (
              <li key={r.run}>
                {onSelect ? (
                  <button
                    type="button"
                    onClick={() => onSelect(r.run)}
                    className={`${baseClass} hover:underline cursor-pointer text-left`}
                  >
                    {r.run}{' '}
                    <span className="text-gray-400">
                      ({r.age_s.toFixed(1)} s ago)
                    </span>
                  </button>
                ) : (
                  <span className={baseClass}>
                    {r.run}{' '}
                    <span className="text-gray-400">
                      ({r.age_s.toFixed(1)} s ago)
                    </span>
                  </span>
                )}
              </li>
            )
          })}
        </ul>
      </div>

      {status && run && (
        <div className="border-t border-gray-200 pt-1 space-y-0.5">
          <div className="font-semibold text-gray-700">{run}</div>
          {scan && scan.expected !== null && (
            <div className="font-mono text-gray-600">
              scan: {scan.completed}/{scan.expected} done
              {scan.eta_s !== null && (
                <> · ETA {_formatEta(scan.eta_s)}</>
              )}
            </div>
          )}
          <div className="font-mono text-gray-600">
            step {status.step} · t = {status.t.toFixed(3)} · E ={' '}
            {status.energy.toFixed(4)}
          </div>
          <div className="font-mono text-gray-600 flex items-center gap-2">
            <span>E(t)</span>
            <Sparkline
              ys={history.map((h) => h.energy)}
              w={120}
              h={18}
              color="#2563eb"
            />
          </div>
          <div className="font-mono text-gray-600 flex items-center gap-2">
            <span>‖ψ‖² = {status.norm.toFixed(5)}</span>
            <Sparkline
              ys={history.map((h) => h.norm)}
              w={120}
              h={18}
              color="#059669"
            />
          </div>
          <div className="font-mono text-gray-600 break-all">
            pops: [{status.populations.map((p) => p.toFixed(3)).join(', ')}]
          </div>
          {history.length > 1 && (
            <div className="text-gray-400">
              {history.length} samples · spans{' '}
              {(history[history.length - 1].t - history[0].t).toFixed(3)}{' '}
              time-units
            </div>
          )}
        </div>
      )}

      {statusErr && run && (
        <div className="text-gray-400 italic">{statusErr}</div>
      )}
    </div>
  )
}
