import { useLiveRuns, useLiveStatus } from '@/state/useLiveRuns'

interface Props {
  /** Currently-selected run name; if it's actively writing live status,
   * its details are shown. The panel always lists every active run. */
  run: string | null
  className?: string
}

/**
 * "What's running right now" panel: lists every run whose
 * `_live_status.json` was touched in the last 5 min, and shows the
 * latest step / energy / norm / m-populations for the selected run.
 *
 * Lightweight by design — pure JSON polling, no charts, no FFT, no
 * heavy 3D. Intended as a permanent corner widget; the dashboard's
 * heavyweight panels still drive the bulk of the UI.
 */
export function LiveStatusPanel({ run, className = '' }: Props) {
  const { runs, error: listErr } = useLiveRuns()
  const { status, error: statusErr } = useLiveStatus(run)

  if (listErr) {
    return (
      <div className={`text-xs text-red-500 ${className}`}>
        live status unavailable: {listErr}
      </div>
    )
  }

  if (runs.length === 0) {
    return (
      <div className={`text-xs text-gray-500 ${className}`}>
        no active runs
      </div>
    )
  }

  return (
    <div className={`flex flex-col gap-2 text-xs ${className}`}>
      <div>
        <div className="font-semibold text-gray-700">Active runs</div>
        <ul className="mt-1 ml-1 space-y-0.5">
          {runs.map((r) => (
            <li
              key={r.run}
              className={
                r.run === run
                  ? 'text-blue-600 font-mono'
                  : 'text-gray-700 font-mono'
              }
            >
              {r.run}{' '}
              <span className="text-gray-400">
                ({r.age_s.toFixed(1)} s ago)
              </span>
            </li>
          ))}
        </ul>
      </div>

      {status && run && (
        <div className="border-t border-gray-200 pt-1">
          <div className="font-semibold text-gray-700">{run}</div>
          <div className="font-mono text-gray-600">
            step {status.step} · t = {status.t.toFixed(3)} · E ={' '}
            {status.energy.toFixed(4)}
          </div>
          <div className="font-mono text-gray-600">
            ‖ψ‖² = {status.norm.toFixed(5)}
          </div>
          <div className="font-mono text-gray-600 break-all">
            pops: [
            {status.populations
              .map((p) => p.toFixed(3))
              .join(', ')}
            ]
          </div>
        </div>
      )}

      {statusErr && run && (
        <div className="text-gray-400 italic">{statusErr}</div>
      )}
    </div>
  )
}
