import { useEffect, useMemo, useState } from 'react'
import { stringify as yamlStringify } from 'yaml'
import { Card, CardContent } from '@/components/ui/card'
import {
  api,
  type EffectiveConfig,
  type EffectiveConfigStep,
  type EffectiveConfigWarning,
} from '@/api'
import { LineChartSVG, type LineChartTrace } from '@/components/charts/LineChartSVG'
import { CHART_COLORS } from '@/components/charts/chartColors'

interface Props {
  /** Run name; used to fetch `/api/effective_config/<run>`. Empty → no fetch. */
  runName: string | undefined
  /** Raw YAML text from `data.config_yaml` — shown alongside the resolved
   * view so the user can compare what they wrote vs what the simulator sees. */
  yaml: string
}

/**
 * Pre-run "what does this YAML actually solve?" panel.
 *
 * Three sections, top to bottom:
 *   1. Warnings — sorted by severity (error → warn → info).
 *   2. Per-step list — resolved scalars + B(t)/q(t) line chart per step.
 *   3. Raw YAML — collapsible viewer for reference.
 *
 * Backed by `/api/effective_config/<run>`, which runs the full
 * `_normalize_and_validate!` pipeline + per-step waveform sampling.
 */
export function EffectiveConfigPanel({ runName, yaml }: Props) {
  const [ins, setIns] = useState<EffectiveConfig | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!runName) {
      setIns(null)
      return
    }
    let cancelled = false
    setLoading(true)
    setError(null)
    api
      .getEffectiveConfig(runName)
      .then((d) => {
        if (!cancelled) setIns(d)
      })
      .catch((e) => {
        if (!cancelled) setError(String(e))
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [runName])

  if (!runName) {
    return (
      <Card>
        <CardContent className="p-4 text-sm text-muted-foreground">
          (no run selected)
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="space-y-5">
      {loading && (
        <div className="text-xs text-muted-foreground">
          <span className="status-dot is-cyan mr-2" />
          inspecting config…
        </div>
      )}
      {error && <ErrorBox message={error} />}
      {ins && <WarningsSection warnings={ins.warnings} />}
      {ins && <StepsSection steps={ins.steps} />}
      {ins && <RawVsResolvedSection ins={ins} rawYaml={yaml} />}
    </div>
  )
}

// --- Warnings -----------------------------------------------------------

const SEV_RANK: Record<EffectiveConfigWarning['severity'], number> = {
  error: 0,
  warn: 1,
  info: 2,
}

const SEV_BADGE: Record<EffectiveConfigWarning['severity'], { label: string; color: string }> = {
  error: { label: 'ERROR', color: 'var(--t-red)' },
  warn: { label: 'WARN', color: 'var(--vermillion, #d94e1f)' },
  info: { label: 'INFO', color: 'var(--t-cyan, #4a8bb8)' },
}

function WarningsSection({ warnings }: { warnings: EffectiveConfigWarning[] }) {
  if (warnings.length === 0) {
    return (
      <Card>
        <CardContent className="p-4 text-sm text-muted-foreground flex items-center gap-2">
          <span className="status-dot is-green" />
          no inspector warnings — config resolves cleanly
        </CardContent>
      </Card>
    )
  }
  const sorted = [...warnings].sort((a, b) => {
    const r = SEV_RANK[a.severity] - SEV_RANK[b.severity]
    return r !== 0 ? r : a.step_index - b.step_index
  })
  return (
    <Card>
      <CardContent className="p-0">
        <div className="px-5 py-3 border-b border-[var(--ink-faint)] text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)]">
          Warnings ({warnings.length})
        </div>
        <ul className="divide-y divide-[var(--ink-faint)]">
          {sorted.map((w, i) => (
            <WarningRow key={i} w={w} />
          ))}
        </ul>
      </CardContent>
    </Card>
  )
}

function WarningRow({ w }: { w: EffectiveConfigWarning }) {
  const badge = SEV_BADGE[w.severity]
  const tag = w.step_index === 0 ? '[config]' : `[step ${w.step_index}]`
  return (
    <li className="px-5 py-3">
      <div className="flex items-baseline gap-2.5 flex-wrap">
        <span
          className="font-mono text-[10px] uppercase tracking-[0.10em] px-1.5 py-px"
          style={{
            background: 'color-mix(in oklch, ' + badge.color + ' 14%, transparent)',
            color: badge.color,
            borderRadius: 0,
          }}
        >
          {badge.label}
        </span>
        <span className="font-mono text-[10.5px] text-[var(--ink-faint)]">{tag}</span>
        <span className="text-sm text-[var(--ink)] font-medium">{w.title}</span>
      </div>
      <div className="mt-1.5 text-xs text-[var(--ink-soft)] leading-relaxed">
        {w.message}
      </div>
      {w.suggestion && (
        <div className="mt-1.5 text-xs text-[var(--ink)] leading-relaxed">
          → {w.suggestion}
        </div>
      )}
    </li>
  )
}

// --- Per-step section ---------------------------------------------------

function StepsSection({ steps }: { steps: EffectiveConfigStep[] }) {
  return (
    <div className="space-y-4">
      <div className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono">
        Resolved pipeline
      </div>
      {steps.map((s) => (
        <StepRow key={s.index} step={s} />
      ))}
    </div>
  )
}

function StepRow({ step }: { step: EffectiveConfigStep }) {
  const summaryEntries = Object.entries(step.params_summary).filter(
    ([k]) => k !== 'duration',
  )
  return (
    <Card>
      <CardContent className="p-5 space-y-3">
        <div className="flex items-baseline gap-2 flex-wrap">
          <span className="font-mono text-[10.5px] text-[var(--ink-faint)]">
            #{String(step.index).padStart(2, '0')}
          </span>
          <span className="text-base font-medium text-[var(--ink)]">
            {step.name}
          </span>
          <span className="font-mono text-[10.5px] uppercase tracking-[0.10em] px-1.5 py-px border border-[var(--ink-faint)] text-[var(--ink-soft)]">
            {step.kind}
          </span>
          {step.duration > 0 && (
            <span className="font-mono text-[11px] text-[var(--ink-soft)]">
              dur = {fmt(step.duration)}
            </span>
          )}
        </div>
        {summaryEntries.length > 0 && (
          <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs">
            {summaryEntries.map(([k, v]) => (
              <SummaryRow key={k} name={k} value={v} />
            ))}
          </dl>
        )}
        {step.traces.map((tr) => (
          <TraceBlock key={tr.kind} step={step} trace={tr} />
        ))}
      </CardContent>
    </Card>
  )
}

function SummaryRow({ name, value }: { name: string; value: unknown }) {
  return (
    <>
      <dt className="text-[var(--ink-faint)] font-mono">{name}</dt>
      <dd className="font-mono text-[var(--ink)] break-all">
        {fmtSummaryValue(value)}
      </dd>
    </>
  )
}

function TraceBlock({
  step,
  trace,
}: {
  step: EffectiveConfigStep
  trace: EffectiveConfigStep['traces'][number]
}) {
  // Ground-state / zero-duration steps have a single sample. Show as a
  // static-values strip instead of a degenerate chart.
  if (trace.t.length <= 1) {
    return (
      <div className="border-t border-[var(--ink-faint)] pt-3">
        <div className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono mb-2">
          {trace.kind} (static)
        </div>
        <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs font-mono">
          {Object.entries(trace.channels).map(([cn, vals]) => (
            <SummaryRow key={cn} name={cn} value={vals[0]} />
          ))}
        </dl>
      </div>
    )
  }
  const channelNames = Object.keys(trace.channels)
  // Only render channels that vary or that anchor a non-trivial baseline.
  const significantChannels = channelNames.filter((cn) =>
    isSignificantChannel(trace.channels[cn]),
  )
  if (significantChannels.length === 0) {
    return null
  }
  // Small multiples: one mini-chart per channel. Each gets its own
  // y-axis so the q(t) ramp (~1e-2 to 1e-7) doesn't get hidden by
  // Bz at ~-148. Without this the visual is dominated by whichever
  // channel has the largest absolute scale.
  return (
    <div className="border-t border-[var(--ink-faint)] pt-3">
      <div className="text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono mb-2">
        {trace.kind} on step {step.index}
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {significantChannels.map((cn, i) => (
          <ChannelMini
            key={cn}
            name={cn}
            color={CHART_COLORS[i % CHART_COLORS.length]}
            x={trace.t}
            y={trace.channels[cn]}
            kindLabel={trace.kind}
          />
        ))}
      </div>
    </div>
  )
}

function ChannelMini({
  name,
  color,
  x,
  y,
  kindLabel,
}: {
  name: string
  color: string
  x: number[]
  y: number[]
  kindLabel: string
}) {
  const lo = Math.min(...y)
  const hi = Math.max(...y)
  const start = y[0]
  const end = y[y.length - 1]
  const traces: LineChartTrace[] = [{ name, color, x, y }]
  return (
    <div>
      <div className="flex items-baseline justify-between gap-2 px-1 mb-0.5">
        <span className="font-mono text-[11px] text-[var(--ink)]">
          {kindLabel}.{name}
        </span>
        <span className="font-mono text-[10px] text-[var(--ink-faint)] numeric">
          {fmt(start)} → {fmt(end)}
          {Math.abs(hi - lo) > 1e-12 && (
            <>
              {' '}
              <span className="text-[var(--ink-soft)]">
                ({fmt(lo)}…{fmt(hi)})
              </span>
            </>
          )}
        </span>
      </div>
      <LineChartSVG
        traces={traces}
        xLabel="t / ω_ref⁻¹"
        yLabel=""
        height={140}
        ticks={4}
      />
    </div>
  )
}

function isSignificantChannel(vals: number[]): boolean {
  if (vals.length === 0) return false
  let lo = vals[0]
  let hi = vals[0]
  for (const v of vals) {
    if (v < lo) lo = v
    if (v > hi) hi = v
  }
  if (hi - lo > 1e-9) return true
  return Math.abs(hi) > 1e-9
}

function fmtSummaryValue(v: unknown): string {
  if (v === null || v === undefined) return '—'
  if (typeof v === 'number') return fmt(v)
  if (typeof v === 'string') return v
  if (typeof v === 'boolean') return v ? 'true' : 'false'
  try {
    return JSON.stringify(v)
  } catch {
    return String(v)
  }
}

function fmt(v: number): string {
  if (!Number.isFinite(v)) return String(v)
  if (v === 0) return '0'
  const abs = Math.abs(v)
  if (abs >= 1e4 || abs < 1e-3) return v.toExponential(3)
  if (abs >= 100) return v.toFixed(2)
  return v.toPrecision(4)
}

// --- Raw vs Resolved YAML --------------------------------------------
//
// Side-by-side viewer for what the user wrote vs what the simulator
// will actually solve. Light line-based highlighting marks lines that
// appear in only one column. Both panes are YAML-stringified from the
// JSON dicts the backend returns.

function RawVsResolvedSection({
  ins,
  rawYaml,
}: {
  ins: EffectiveConfig
  rawYaml: string
}) {
  const [open, setOpen] = useState(false)

  const resolvedYaml = useMemo(() => {
    try {
      return yamlStringify(ins.normalised, { indent: 2, lineWidth: 0 })
    } catch (e) {
      return `# Failed to stringify resolved config: ${String(e)}`
    }
  }, [ins.normalised])

  const diffSets = useMemo(() => {
    const rawLines = new Set(
      (rawYaml || '').split('\n').map((l) => l.trim()).filter(Boolean),
    )
    const resolvedLines = new Set(
      resolvedYaml.split('\n').map((l) => l.trim()).filter(Boolean),
    )
    return { rawLines, resolvedLines }
  }, [rawYaml, resolvedYaml])

  if (!rawYaml && !resolvedYaml) return null
  return (
    <Card>
      <CardContent className="p-0">
        <button
          type="button"
          className="w-full text-left px-5 py-3 border-b border-[var(--ink-faint)] text-[10.5px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono hover:text-[var(--ink)] flex items-center justify-between"
          onClick={() => setOpen((v) => !v)}
        >
          <span>
            {open ? '▾' : '▸'} Raw vs Resolved YAML
          </span>
          <span className="text-[var(--ink-faint)] normal-case tracking-normal text-[10px]">
            what you wrote · what the simulator solves
          </span>
        </button>
        {open && (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-px bg-[var(--ink-faint)]">
            <YamlPane
              label="Raw (your YAML)"
              text={rawYaml || ''}
              foreignLines={diffSets.resolvedLines}
              addedColor="rgba(180, 80, 80, 0.18)"
            />
            <YamlPane
              label="Resolved (effective config)"
              text={resolvedYaml}
              foreignLines={diffSets.rawLines}
              addedColor="rgba(80, 140, 80, 0.18)"
            />
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function YamlPane({
  label,
  text,
  foreignLines,
  addedColor,
}: {
  label: string
  text: string
  foreignLines: Set<string>
  addedColor: string
}) {
  const lines = text.split('\n')
  return (
    <div className="bg-background min-w-0">
      <div className="px-4 py-2 text-[10px] uppercase tracking-[0.10em] text-[var(--ink-faint)] font-mono border-b border-[var(--ink-faint)]">
        {label}
      </div>
      <pre className="text-xs whitespace-pre overflow-auto max-h-[600px] m-0 p-0 leading-snug font-mono">
        {lines.map((line, i) => {
          const trimmed = line.trim()
          const isOnlyHere = trimmed && !foreignLines.has(trimmed)
          return (
            <div
              key={i}
              className="px-4"
              style={isOnlyHere ? { background: addedColor } : undefined}
            >
              {line || ' '}
            </div>
          )
        })}
      </pre>
    </div>
  )
}

function ErrorBox({ message }: { message: string }) {
  return (
    <Card>
      <CardContent className="p-4 text-sm text-[var(--t-red,#d94e1f)] flex items-start gap-2">
        <span className="status-dot is-red mt-1" />
        <span>{message}</span>
      </CardContent>
    </Card>
  )
}
