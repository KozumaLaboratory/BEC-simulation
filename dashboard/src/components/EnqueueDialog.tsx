import { useEffect, useMemo, useState } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import {
  api,
  type EnqueuePreviewResponse,
  type EnqueueCommitResponse,
  type EnqueueFinding,
  type EnqueueRequest,
} from '@/api'

// 2-step preview-confirm modal.
//
//   Step 1 (form)    — fill YAML + backend + priority + autonomy + recipe
//                       + profile + walltime, click "Preview"
//   Step 2 (preview) — inspector findings + budget impact + would-be cid,
//                       click "Commit" (button labelled "Commit [DRY-RUN]"
//                       when the autopilot is in dry-run mode).
//
// Closes on commit success. autonomy_level defaults to :propose so a
// Web-driven enqueue does NOT auto-dispatch even if the autopilot is
// live; operator promotes via CLI after sanity check.

interface Props {
  open: boolean
  onClose: () => void
  /** Initial YAML — populated when "Fork" was clicked from a queue row,
   * empty when "+ Enqueue" was clicked from the header. */
  initialYaml?: string
  /** Whether the autopilot is currently in dry-run mode (from /api/queue). */
  dryRun: boolean
  /** Whether the autopilot is paused. We let commits through even when
   * paused (the entry sits in :pending until resume), but warn. */
  paused: boolean
  /** Called on a successful commit. Caller refreshes the queue. */
  onCommitted?: (resp: EnqueueCommitResponse) => void
}

type Step = 'form' | 'preview'

const SESSION_ID = (() => {
  // Stable per-tab session id so provenance traces back to the same
  // dashboard session. Persists for the lifetime of the tab.
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
})()

const DEFAULT_YAML = `# Edit this YAML, then click Preview.
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [10.0, 10.0, 10.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 10000, omega_ref: 691.1504}
      B: {Bz: "0.01 Gauss"}
      dt: 0.005
      n_steps: 3000
      tol: 1.0e-8
`

export function EnqueueDialog({
  open,
  onClose,
  initialYaml,
  dryRun,
  paused,
  onCommitted,
}: Props) {
  const [step, setStep] = useState<Step>('form')
  const [yamlText, setYamlText] = useState<string>(initialYaml || DEFAULT_YAML)
  const [backend, setBackend] = useState<'local' | 'slurm'>('local')
  const [priority, setPriority] = useState<number>(5)
  const [autonomy, setAutonomy] = useState<'suggest' | 'propose' | 'dispatch'>(
    'propose',
  )
  const [profile, setProfile] = useState<string>('default')
  const [recipeName, setRecipeName] = useState<string>('')
  const [walltime, setWalltime] = useState<number>(2.0)

  const [busy, setBusy] = useState<boolean>(false)
  const [preview, setPreview] = useState<EnqueuePreviewResponse | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (open) {
      setStep('form')
      setPreview(null)
      setError(null)
      if (initialYaml !== undefined) {
        setYamlText(initialYaml || DEFAULT_YAML)
      }
    }
  }, [open, initialYaml])

  const req: EnqueueRequest = useMemo(
    () => ({
      preview: true,
      yaml: yamlText,
      backend,
      priority,
      autonomy_level: autonomy,
      recipe_name: recipeName,
      profile,
      estimated_walltime_hours: walltime,
      session_id: SESSION_ID,
    }),
    [yamlText, backend, priority, autonomy, recipeName, profile, walltime],
  )

  async function handlePreview() {
    setBusy(true)
    setError(null)
    try {
      const r = await api.autopilotEnqueuePreview(req)
      if (!r.ok) {
        setError(r.error || 'preview failed')
      } else {
        setPreview(r)
        setStep('preview')
      }
    } catch (e) {
      setError(String(e))
    } finally {
      setBusy(false)
    }
  }

  async function handleCommit() {
    setBusy(true)
    setError(null)
    try {
      const r = await api.autopilotEnqueueCommit(req)
      if (!r.ok) {
        setError(r.error || 'commit failed')
      } else {
        onCommitted?.(r)
        onClose()
      }
    } catch (e) {
      setError(String(e))
    } finally {
      setBusy(false)
    }
  }

  if (!open) return null
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4"
      style={{ background: 'color-mix(in oklch, black 60%, transparent)' }}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose()
      }}
    >
      <Card className="w-full max-w-3xl max-h-[90vh] flex flex-col">
        <CardContent className="p-0 flex flex-col flex-1 min-h-0">
          <DialogHeader
            step={step}
            dryRun={dryRun}
            paused={paused}
            onClose={onClose}
          />
          <div className="flex-1 min-h-0 overflow-auto p-5">
            {step === 'form' ? (
              <FormStep
                yamlText={yamlText}
                onYamlChange={setYamlText}
                backend={backend}
                onBackendChange={setBackend}
                priority={priority}
                onPriorityChange={setPriority}
                autonomy={autonomy}
                onAutonomyChange={setAutonomy}
                profile={profile}
                onProfileChange={setProfile}
                recipeName={recipeName}
                onRecipeNameChange={setRecipeName}
                walltime={walltime}
                onWalltimeChange={setWalltime}
              />
            ) : (
              preview && <PreviewStep preview={preview} />
            )}
            {error && <ErrorBanner message={error} />}
          </div>
          <DialogFooter
            step={step}
            busy={busy}
            dryRun={dryRun}
            preview={preview}
            onBack={() => setStep('form')}
            onPreview={handlePreview}
            onCommit={handleCommit}
            onCancel={onClose}
          />
        </CardContent>
      </Card>
    </div>
  )
}

function DialogHeader({
  step,
  dryRun,
  paused,
  onClose,
}: {
  step: Step
  dryRun: boolean
  paused: boolean
  onClose: () => void
}) {
  return (
    <div className="px-5 py-3 border-b border-[var(--ink-faint)] flex items-baseline justify-between">
      <div className="flex items-baseline gap-3">
        <span className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono">
          Enqueue
        </span>
        <span className="text-[var(--ink-soft)] text-[11px]">
          {step === 'form' ? '1 / 2 · form' : '2 / 2 · preview-confirm'}
        </span>
        {dryRun && (
          <span
            className="font-mono text-[10px] uppercase tracking-[0.10em] px-1.5 py-px"
            style={{
              background: 'color-mix(in oklch, var(--vermillion,#d97a3c) 18%, transparent)',
              color: 'var(--vermillion,#d97a3c)',
            }}
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
          >
            paused
          </span>
        )}
      </div>
      <button
        type="button"
        onClick={onClose}
        className="font-mono text-[14px] text-[var(--ink-faint)] hover:text-[var(--ink)] leading-none"
        aria-label="close"
      >
        ×
      </button>
    </div>
  )
}

function FormStep(props: {
  yamlText: string
  onYamlChange: (v: string) => void
  backend: 'local' | 'slurm'
  onBackendChange: (v: 'local' | 'slurm') => void
  priority: number
  onPriorityChange: (v: number) => void
  autonomy: 'suggest' | 'propose' | 'dispatch'
  onAutonomyChange: (v: 'suggest' | 'propose' | 'dispatch') => void
  profile: string
  onProfileChange: (v: string) => void
  recipeName: string
  onRecipeNameChange: (v: string) => void
  walltime: number
  onWalltimeChange: (v: number) => void
}) {
  return (
    <div className="space-y-4">
      <div>
        <label className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono">
          spec YAML
        </label>
        <textarea
          value={props.yamlText}
          onChange={(e) => props.onYamlChange(e.target.value)}
          rows={14}
          spellCheck={false}
          className="mt-1 w-full font-mono text-xs p-3 border border-[var(--ink-faint)] focus:border-[var(--ink)] outline-none bg-background"
          style={{ borderRadius: 0 }}
        />
      </div>
      <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
        <SelectField
          label="backend"
          value={props.backend}
          options={[
            { value: 'local', label: 'suzume (local, default)' },
            { value: 'slurm', label: 'tsubame (slurm)' },
          ]}
          onChange={(v) => props.onBackendChange(v as 'local' | 'slurm')}
        />
        <SelectField
          label="autonomy"
          value={props.autonomy}
          options={[
            { value: 'propose', label: 'propose (default)' },
            { value: 'suggest', label: 'suggest (record only)' },
            { value: 'dispatch', label: 'dispatch (auto-submit)' },
          ]}
          onChange={(v) =>
            props.onAutonomyChange(v as 'suggest' | 'propose' | 'dispatch')
          }
        />
        <SelectField
          label="profile"
          value={props.profile}
          options={[
            { value: 'default', label: 'default' },
            { value: 'single_h100', label: 'single_h100' },
          ]}
          onChange={props.onProfileChange}
        />
        <NumberField
          label="priority (1 = top)"
          value={props.priority}
          onChange={props.onPriorityChange}
          min={1}
          max={99}
          step={1}
        />
        <NumberField
          label="est. walltime (h)"
          value={props.walltime}
          onChange={props.onWalltimeChange}
          min={0.1}
          step={0.1}
        />
        <TextField
          label="recipe (optional)"
          value={props.recipeName}
          onChange={props.onRecipeNameChange}
          placeholder="next_random_in_bounds"
        />
      </div>
      <AutonomyHint level={props.autonomy} />
    </div>
  )
}

function AutonomyHint({ level }: { level: 'suggest' | 'propose' | 'dispatch' }) {
  if (level === 'dispatch') {
    return (
      <div
        className="text-xs p-3 border"
        style={{
          borderColor: 'var(--t-red,#d94e1f)',
          background: 'color-mix(in oklch, var(--t-red,#d94e1f) 7%, transparent)',
          color: 'var(--ink)',
          borderRadius: 0,
        }}
      >
        <strong>:dispatch</strong> bypasses the operator-promote step.
        The autopilot will submit this entry on the next tick. Use
        sparingly — the safe default for Web-driven enqueue is
        <code className="px-1 mx-1 font-mono">:propose</code>.
      </div>
    )
  }
  if (level === 'suggest') {
    return (
      <div className="text-xs text-[var(--ink-soft)]">
        <strong>:suggest</strong> records the entry but the autopilot
        never dispatches it. Useful for surrogate proposals the operator
        will audit offline.
      </div>
    )
  }
  return (
    <div className="text-xs text-[var(--ink-soft)]">
      <strong>:propose</strong> enqueues to <code className="font-mono">:pending</code>{' '}
      but the autopilot waits for an operator to promote
      via <code className="font-mono">scripts/autopilot.jl</code> before dispatching.
    </div>
  )
}

function PreviewStep({ preview }: { preview: EnqueuePreviewResponse }) {
  const ins = preview.inspector
  const bud = preview.budget
  const cidShort = preview.content_id.slice(0, 12)
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs font-mono">
        <Stat label="cid" value={cidShort} />
        <Stat label="profile" value={preview.profile} />
        <Stat
          label="est. walltime (h)"
          value={preview.estimated_walltime_hours.toFixed(2)}
        />
        <Stat
          label="inspector"
          value={`${ins.block_count} block / ${ins.warn_count} warn / ${ins.error_count} err`}
          warn={ins.block_count > 0 || ins.warn_count > 0 || ins.error_count > 0}
        />
      </div>

      <FindingsSection
        title="Blocking findings (will refuse commit)"
        findings={ins.blocked}
        color="var(--t-red,#d94e1f)"
      />
      <FindingsSection
        title="Errors (recorded on entry)"
        findings={ins.errored}
        color="var(--vermillion,#d97a3c)"
      />
      <FindingsSection
        title="Warnings"
        findings={ins.warned}
        color="var(--vermillion,#d97a3c)"
      />

      <div>
        <div className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono mb-1">
          Budget impact
        </div>
        {bud.available ? (
          <div className="text-xs font-mono space-y-1">
            <div>
              decision:{' '}
              <span
                style={{
                  color: bud.allow ? 'var(--t-green,#5a8b5a)' : 'var(--t-red,#d94e1f)',
                }}
              >
                {bud.allow ? 'ALLOW' : 'BLOCKED'}
              </span>{' '}
              <span className="text-[var(--ink-soft)]">— {bud.reason}</span>
            </div>
            <div className="text-[var(--ink-soft)]">
              realized {bud.realized?.toFixed(2)} h
              {bud.quarter_cap !== undefined && bud.quarter_cap > 0 && (
                <> / quarter cap {bud.quarter_cap?.toFixed(0)} h</>
              )}
              · predicted in-flight {bud.predicted?.toFixed(2)} h
            </div>
          </div>
        ) : (
          <div className="text-xs text-[var(--ink-faint)]">
            (budget gate unavailable)
          </div>
        )}
      </div>
    </div>
  )
}

function FindingsSection({
  title,
  findings,
  color,
}: {
  title: string
  findings: EnqueueFinding[]
  color: string
}) {
  if (findings.length === 0) return null
  return (
    <div>
      <div
        className="text-[10.5px] uppercase tracking-[0.10em] font-mono mb-1"
        style={{ color }}
      >
        {title}
      </div>
      <ul className="text-xs font-mono space-y-0.5">
        {findings.map((f, i) => (
          <li key={i} className="text-[var(--ink-soft)]">
            <span className="text-[var(--ink)]">[step {f.step_index}]</span>{' '}
            {f.kind}: {f.title}
          </li>
        ))}
      </ul>
    </div>
  )
}

function Stat({
  label,
  value,
  warn = false,
}: {
  label: string
  value: string
  warn?: boolean
}) {
  return (
    <div>
      <div className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
        {label}
      </div>
      <div
        className="numeric mt-0.5"
        style={{ color: warn ? 'var(--vermillion,#d97a3c)' : 'var(--ink)' }}
      >
        {value}
      </div>
    </div>
  )
}

function DialogFooter({
  step,
  busy,
  dryRun,
  preview,
  onBack,
  onPreview,
  onCommit,
  onCancel,
}: {
  step: Step
  busy: boolean
  dryRun: boolean
  preview: EnqueuePreviewResponse | null
  onBack: () => void
  onPreview: () => void
  onCommit: () => void
  onCancel: () => void
}) {
  const blockCount = preview?.inspector.block_count ?? 0
  const commitLabel = dryRun ? 'Enqueue [DRY-RUN]' : 'Enqueue'
  return (
    <div className="px-5 py-3 border-t border-[var(--ink-faint)] flex justify-between items-center">
      <button
        type="button"
        className="text-xs font-mono text-[var(--ink-soft)] hover:text-[var(--ink)]"
        onClick={onCancel}
      >
        cancel
      </button>
      <div className="flex gap-3 items-center">
        {step === 'preview' && (
          <button
            type="button"
            className="text-xs font-mono text-[var(--ink-soft)] hover:text-[var(--ink)]"
            onClick={onBack}
            disabled={busy}
          >
            ← back
          </button>
        )}
        {step === 'form' ? (
          <button
            type="button"
            disabled={busy}
            onClick={onPreview}
            className="text-xs font-mono px-3 py-1.5 border border-[var(--ink)] text-[var(--ink)] hover:bg-[var(--ink)] hover:text-background disabled:opacity-50"
            style={{ borderRadius: 0 }}
          >
            {busy ? 'previewing…' : 'Preview →'}
          </button>
        ) : (
          <button
            type="button"
            disabled={busy || blockCount > 0}
            onClick={onCommit}
            className="text-xs font-mono px-3 py-1.5 border disabled:opacity-50"
            style={{
              borderColor:
                blockCount > 0 ? 'var(--t-red,#d94e1f)' : 'var(--ink)',
              color: blockCount > 0 ? 'var(--t-red,#d94e1f)' : 'var(--ink)',
              borderRadius: 0,
            }}
            title={blockCount > 0 ? 'inspector reports blocking findings' : ''}
          >
            {busy ? 'enqueueing…' : commitLabel}
          </button>
        )}
      </div>
    </div>
  )
}

function ErrorBanner({ message }: { message: string }) {
  return (
    <div
      className="mt-4 text-xs p-3 border"
      style={{
        borderColor: 'var(--t-red,#d94e1f)',
        background: 'color-mix(in oklch, var(--t-red,#d94e1f) 7%, transparent)',
        color: 'var(--t-red,#d94e1f)',
        borderRadius: 0,
      }}
    >
      {message}
    </div>
  )
}

function SelectField({
  label,
  value,
  options,
  onChange,
}: {
  label: string
  value: string
  options: { value: string; label: string }[]
  onChange: (v: string) => void
}) {
  return (
    <label className="block">
      <span className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono">
        {label}
      </span>
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full text-xs font-mono px-2 py-1 border border-[var(--ink-faint)] focus:border-[var(--ink)] outline-none bg-background"
        style={{ borderRadius: 0 }}
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </label>
  )
}

function NumberField({
  label,
  value,
  onChange,
  min,
  max,
  step,
}: {
  label: string
  value: number
  onChange: (v: number) => void
  min?: number
  max?: number
  step?: number
}) {
  return (
    <label className="block">
      <span className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono">
        {label}
      </span>
      <input
        type="number"
        value={value}
        min={min}
        max={max}
        step={step}
        onChange={(e) => onChange(Number(e.target.value))}
        className="mt-1 w-full text-xs font-mono px-2 py-1 border border-[var(--ink-faint)] focus:border-[var(--ink)] outline-none bg-background"
        style={{ borderRadius: 0 }}
      />
    </label>
  )
}

function TextField({
  label,
  value,
  onChange,
  placeholder,
}: {
  label: string
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <label className="block">
      <span className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono">
        {label}
      </span>
      <input
        type="text"
        value={value}
        placeholder={placeholder}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1 w-full text-xs font-mono px-2 py-1 border border-[var(--ink-faint)] focus:border-[var(--ink)] outline-none bg-background"
        style={{ borderRadius: 0 }}
      />
    </label>
  )
}
