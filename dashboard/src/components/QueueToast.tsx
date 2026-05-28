import { useEffect, useState } from 'react'

// Minimal toast: bottom-right card that auto-dismisses. Closes earlier
// on click. Intentionally not a generic notification system — the queue
// is the only consumer for now.

export interface QueueToastInfo {
  id: number                      // monotonic for keying
  content_id: string
  message: string                 // primary line
  detail?: string                 // secondary line
  kind: 'success' | 'error'
  onClick?: () => void            // optional action (e.g. scroll-to)
  timeout_ms?: number
}

interface Props {
  toasts: QueueToastInfo[]
  onDismiss: (id: number) => void
}

export function QueueToastStack({ toasts, onDismiss }: Props) {
  return (
    <div className="fixed bottom-6 right-6 z-[60] space-y-2 max-w-sm">
      {toasts.map((t) => (
        <ToastCard key={t.id} t={t} onDismiss={() => onDismiss(t.id)} />
      ))}
    </div>
  )
}

function ToastCard({ t, onDismiss }: { t: QueueToastInfo; onDismiss: () => void }) {
  const [exiting, setExiting] = useState(false)

  useEffect(() => {
    const ms = t.timeout_ms ?? 6000
    const id = window.setTimeout(() => {
      setExiting(true)
      window.setTimeout(onDismiss, 220)
    }, ms)
    return () => window.clearTimeout(id)
  }, [t.id, t.timeout_ms, onDismiss])

  const color =
    t.kind === 'success' ? 'var(--t-green,#5a8b5a)' : 'var(--t-red,#d94e1f)'

  return (
    <div
      className="p-4 cursor-pointer border bg-background shadow-sm transition-opacity"
      style={{
        borderColor: color,
        borderRadius: 0,
        opacity: exiting ? 0 : 1,
      }}
      onClick={() => {
        t.onClick?.()
        setExiting(true)
        window.setTimeout(onDismiss, 220)
      }}
    >
      <div className="flex items-baseline gap-2">
        <span
          className="font-mono text-[10px] uppercase tracking-[0.10em] px-1.5 py-px"
          style={{
            background: 'color-mix(in oklch, ' + color + ' 18%, transparent)',
            color,
          }}
        >
          {t.kind === 'success' ? 'enqueued' : 'error'}
        </span>
        <span className="font-mono text-[11px] text-[var(--ink)] truncate" title={t.content_id}>
          {t.content_id.slice(0, 12)}
        </span>
      </div>
      <div className="text-sm text-[var(--ink)] mt-1">{t.message}</div>
      {t.detail && (
        <div className="text-xs text-[var(--ink-soft)] mt-0.5">{t.detail}</div>
      )}
      {t.onClick && (
        <div className="text-[10px] text-[var(--ink-faint)] mt-1.5 uppercase tracking-[0.10em] font-mono">
          click → reveal in queue
        </div>
      )}
    </div>
  )
}
