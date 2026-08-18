import { useEffect, useMemo, useRef, useState } from 'react'
import embed, { type VisualizationSpec, type Result as VegaResult } from 'vega-embed'
import {
  api,
  type SweepViewspec,
  type SweepNarrative,
  type SweepMode,
  type SweepHypothesis,
} from '@/api'

interface Props {
  run: string | null
}

// SweepView: render the Julia-resolved Vega-Lite spec for a sweep run.
//
// Renderer-paints-only: the spec body is the **single source of truth**.
// Every per-cell decision — fill colour, alpha, edges, dominant-m,
// quality mask — is baked into the JSON by `to_viewspec(::SweepResult)`
// (see `src/analysis/sweep.jl`). This panel does no physics: it embeds
// the spec, surfaces the `_meta` summary in a chrome strip, and forwards
// download buttons to vega-embed's built-in actions.
//
// The Julia → Vega-Lite contract is documented in
// `docs/architecture/sweep_view.md`. If a sweep export adds new
// observables or changes the panel shape, regenerate the viewspec on the
// Julia side; nothing in this component needs to change.
export function SweepView({ run }: Props) {
  const [spec, setSpec] = useState<SweepViewspec | null | undefined>(undefined)
  const [err, setErr] = useState<string | null>(null)
  const mountRef = useRef<HTMLDivElement | null>(null)
  const viewRef = useRef<VegaResult | null>(null)

  useEffect(() => {
    if (!run) {
      setSpec(undefined)
      return
    }
    let cancel = false
    setSpec(undefined)
    setErr(null)
    api
      .getSweepViewspec(run)
      .then((s) => {
        if (!cancel) setSpec(s)
      })
      .catch((e) => {
        if (!cancel) setErr(e instanceof Error ? e.message : String(e))
      })
    return () => {
      cancel = true
    }
  }, [run])

  // Strip the `_*` annotation keys before handing the spec to vega-embed.
  // Vega-Lite tolerates unknown top-level fields but they show up in the
  // editor "view source" view as noise.
  const embedSpec = useMemo(() => {
    if (!spec) return null
    const out: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(spec)) {
      if (k.startsWith('_')) continue
      out[k] = v
    }
    return out as VisualizationSpec
  }, [spec])

  useEffect(() => {
    if (!embedSpec || !mountRef.current) return
    let cancel = false
    embed(mountRef.current, embedSpec, {
      actions: { export: true, source: false, compiled: false, editor: false },
      renderer: 'canvas',
      tooltip: { theme: 'dark' },
    })
      .then((result) => {
        if (cancel) {
          result.finalize()
          return
        }
        viewRef.current?.finalize()
        viewRef.current = result
      })
      .catch((e) => {
        if (!cancel) setErr(e instanceof Error ? e.message : String(e))
      })
    return () => {
      cancel = true
      viewRef.current?.finalize()
      viewRef.current = null
    }
  }, [embedSpec])

  if (!run) {
    return (
      <Empty msg="Select a run to view its sweep export." />
    )
  }
  if (err) {
    return <Empty msg={`sweep load failed: ${err}`} tone="error" />
  }
  if (spec === undefined) {
    return <Empty msg="loading viewspec…" />
  }
  if (spec === null) {
    return (
      <Empty
        msg={
          'No sweep viewspec for this run. Generate one with `write_viewspec` (src/analysis/sweep_viewspec.jl).'
        }
      />
    )
  }

  const narrative = spec._meta.narrative ?? null
  const mode = (spec._meta.mode ?? narrative?.mode ?? 'complete') as SweepMode

  return (
    <div className="space-y-4">
      <NarrativeCard narrative={narrative} mode={mode} />
      {mode === 'failed' && <FailureAlert narrative={narrative} />}
      <Chrome meta={spec._meta} />
      <div
        ref={mountRef}
        className="overflow-auto"
        style={{ background: 'var(--paper)' }}
      />
    </div>
  )
}

// Headline card. Renders the sweep's title + the question (declared on
// the Julia side as `meta.narrative` — see `to_viewspec` in
// `src/analysis/sweep.jl`). Without narrative the card collapses to a
// minimal status line so non-narrative sweeps still get a status read.
function NarrativeCard({
  narrative,
  mode,
}: {
  narrative: SweepNarrative | null
  mode: SweepMode
}) {
  const status = narrative
    ? `${narrative.n_converged} / ${narrative.n_total} converged`
    : null
  const tone = MODE_TONE[mode]
  return (
    <div
      className="border px-5 py-4"
      style={{
        borderColor: tone.border,
        background: tone.background,
        borderLeftWidth: 4,
      }}
    >
      <div className="flex items-baseline justify-between gap-4 mb-1">
        <h3 className="text-[15px] font-semibold tracking-[-0.005em] text-[var(--ink)]">
          {narrative?.title || 'Sweep'}
        </h3>
        <div className="flex items-baseline gap-3 font-mono text-[11px]">
          <ModeBadge mode={mode} />
          {status && (
            <span className="text-[var(--ink-soft)] numeric">{status}</span>
          )}
        </div>
      </div>
      {narrative?.question && (
        <p className="text-[13px] text-[var(--ink-soft)] leading-snug mt-1">
          <span className="font-mono text-[10.5px] uppercase tracking-[0.08em] text-[var(--ink-faint)] mr-2">
            Q:
          </span>
          {narrative.question}
        </p>
      )}
      {narrative?.hypothesis && (
        <HypothesisLine hypothesis={narrative.hypothesis} />
      )}
      {narrative && <AssessabilityHint narrative={narrative} />}
    </div>
  )
}

// Honest read of "is this view interpretable yet?". Some relations need
// a minimum number of converged points before the picture answers
// anything — a collapse plot with one converged dot is a preview, not a
// result. Surfacing this stops the reader from over-reading partial
// modes.
function AssessabilityHint({ narrative }: { narrative: SweepNarrative }) {
  const hyp = narrative.hypothesis
  if (!hyp) return null
  if (narrative.mode === 'failed') return null
  const minConv = MIN_CONVERGED_FOR_RELATION[hyp.relation] ?? 0
  if (minConv === 0 || narrative.n_converged >= minConv) return null
  return (
    <p className="mt-2 font-mono text-[11px] text-[var(--ink-soft)]">
      <span className="text-[var(--t-amber, #b8954a)]">⚠</span>{' '}
      <span className="text-[var(--ink)]">
        {hyp.relation} not yet assessable
      </span>{' '}
      <span className="text-[var(--ink-faint)]">
        ({narrative.n_converged}/{narrative.n_total} converged; need ≥{minConv}{' '}
        spanning the {hyp.relation === 'collapse' ? 'x range' : 'axis'} to read
        off a result — the panel below is a preview, not a conclusion).
      </span>
    </p>
  )
}

const MIN_CONVERGED_FOR_RELATION: Partial<Record<SweepHypothesis['relation'], number>> = {
  collapse: 5,
  asymptote: 4,
  scaling: 5,
  correlation: 5,
  residual: 4,
}

const RELATION_MARK_LABEL: Record<string, string> = {
  asymptote: 'line plot vs axis, horizontal limit',
  collapse: 'scatter on dimensionless x + theory envelope',
  residual: 'observed − predicted (heatmap or line)',
  scaling: 'log-log of |residual| or |observed| vs axis',
  correlation: 'scatter primary_obs vs obs_y',
}

function HypothesisLine({ hypothesis }: { hypothesis: SweepHypothesis }) {
  const modelKeys = Object.keys(hypothesis.models)
  const primaryModel = hypothesis.models[hypothesis.primary_obs]
  const mark = RELATION_MARK_LABEL[hypothesis.relation] ?? 'auto'
  return (
    <div className="mt-2 font-mono text-[12px] text-[var(--ink-soft)] space-y-1">
      <p>
        <span className="text-[var(--ink-faint)]">relation:</span>{' '}
        <span className="text-[var(--ink)]">{hypothesis.relation}</span>
        <span className="text-[var(--ink-faint)]">  ·  mark: {mark}</span>
      </p>
      {primaryModel && (
        <p>
          <span className="text-[var(--ink-faint)]">model[</span>
          <span className="text-[var(--ink)]">{hypothesis.primary_obs}</span>
          <span className="text-[var(--ink-faint)]">]:</span>{' '}
          <span className="text-[var(--ink)]">{primaryModel.label}</span>
        </p>
      )}
      {primaryModel?.has_collapse_var && primaryModel.collapse_var_label && (
        <p>
          <span className="text-[var(--ink-faint)]">collapse x:</span>{' '}
          <span className="text-[var(--ink)]">
            {primaryModel.collapse_var_label}
          </span>
        </p>
      )}
      {modelKeys.length > 1 && (
        <p>
          <span className="text-[var(--ink-faint)]">other models:</span>{' '}
          <span className="text-[var(--ink)]">
            {modelKeys.filter((k) => k !== hypothesis.primary_obs).join(', ')}
          </span>
        </p>
      )}
    </div>
  )
}

function ModeBadge({ mode }: { mode: SweepMode }) {
  const tone = MODE_TONE[mode]
  return (
    <span
      className="inline-flex items-center gap-1.5 px-2 py-0.5 font-mono text-[10.5px] uppercase tracking-[0.08em]"
      style={{
        background: tone.badgeBg,
        color: tone.badgeFg,
        border: `1px solid ${tone.border}`,
      }}
    >
      <span
        className="inline-block size-1.5 rounded-full"
        style={{ background: tone.badgeFg }}
      />
      {mode}
    </span>
  )
}

// Big-block alert when mode = failed. The bug-finding moves to the
// Effective config tab; this panel is what tells the reader "do not
// interpret the heatmap thumbnails as physics".
function FailureAlert({ narrative }: { narrative: SweepNarrative | null }) {
  return (
    <div
      className="border px-5 py-4"
      style={{
        borderColor: 'color-mix(in oklch, var(--t-red) 60%, transparent)',
        background: 'color-mix(in oklch, var(--t-red) 8%, transparent)',
      }}
    >
      <div className="flex items-baseline gap-3 mb-1">
        <span className="status-dot is-red" />
        <h4 className="font-mono text-[12px] uppercase tracking-[0.08em] text-[var(--t-red)]">
          Sweep failed — no physics conclusion
        </h4>
      </div>
      <p className="text-[13px] text-[var(--ink-soft)] leading-snug mt-1">
        {narrative
          ? `${narrative.n_converged} of ${narrative.n_total} cells converged. `
          : 'No converged cells. '}
        Heatmap thumbnails below show the optimiser's last (unconverged) values
        — read them only as failure-mode diagnostics, never as physics.
      </p>
      <p className="text-[12px] text-[var(--ink-soft)] mt-2">
        Next step: open the <span className="font-mono text-[var(--ink)]">Effective config</span>{' '}
        tab to check launch params, then drill into one failing cell's per-iter
        ‖∇E‖ trace.
      </p>
    </div>
  )
}

const MODE_TONE: Record<SweepMode, {
  border: string
  background: string
  badgeBg: string
  badgeFg: string
}> = {
  complete: {
    border: 'color-mix(in oklch, var(--t-green, #4a8b6b) 60%, transparent)',
    background: 'color-mix(in oklch, var(--t-green, #4a8b6b) 5%, transparent)',
    badgeBg: 'color-mix(in oklch, var(--t-green, #4a8b6b) 12%, transparent)',
    badgeFg: 'var(--t-green, #4a8b6b)',
  },
  partial: {
    border: 'color-mix(in oklch, var(--t-amber, #b8954a) 60%, transparent)',
    background: 'color-mix(in oklch, var(--t-amber, #b8954a) 5%, transparent)',
    badgeBg: 'color-mix(in oklch, var(--t-amber, #b8954a) 12%, transparent)',
    badgeFg: 'var(--t-amber, #b8954a)',
  },
  failed: {
    border: 'color-mix(in oklch, var(--t-red) 60%, transparent)',
    background: 'color-mix(in oklch, var(--t-red) 5%, transparent)',
    badgeBg: 'color-mix(in oklch, var(--t-red) 12%, transparent)',
    badgeFg: 'var(--t-red)',
  },
}

function Chrome({ meta }: { meta: SweepViewspec['_meta'] }) {
  // Show axes dimensionality, not `_view_shape` — calling the strip
  // "view: heatmap" while the primary mark is a line plot (when
  // expected.kind = :asymptote) was an active self-contradiction. The
  // *mark* is announced by NarrativeCard's `expected:` line; this
  // strip just describes the data shape (#dims, what axes are swept,
  // how many observables of each role).
  const sweptAxes = meta.axes.filter((a) => a.n_values > 1)
  const axesDim = sweptAxes.length
  const axesLabel = sweptAxes
    .map((a) => `${a.name} (${a.unit}, ${a.scale}, n=${a.n_values})`)
    .join('  ×  ')
  const obsCount = meta.observables.length
  const dataObs = meta.observables.filter((o) => o.role === 'data').length
  const qObs = meta.quality_observable ?? 'none'
  return (
    <div className="border border-[var(--ink-faint)] px-4 py-2 font-mono text-[11px] text-[var(--ink-soft)] flex flex-wrap gap-x-5 gap-y-1">
      <span>
        <span className="text-[var(--ink-faint)]">axes</span>{' '}
        <span className="text-[var(--ink)]">{axesDim}D</span>
      </span>
      <span>
        <span className="text-[var(--ink-faint)]">F</span>{' '}
        <span className="text-[var(--ink)]">{meta.F}</span>
      </span>
      <span>
        <span className="text-[var(--ink-faint)]">swept</span>{' '}
        <span className="text-[var(--ink)]">{axesLabel || '—'}</span>
      </span>
      <span>
        <span className="text-[var(--ink-faint)]">obs</span>{' '}
        <span className="text-[var(--ink)]">
          {dataObs} data / {obsCount} total
        </span>
      </span>
      <span>
        <span className="text-[var(--ink-faint)]">quality</span>{' '}
        <span className="text-[var(--ink)]">{qObs}</span>
      </span>
      <span>
        <span className="text-[var(--ink-faint)]">schema</span>{' '}
        <span className="text-[var(--ink)]">{meta.schema_version}</span>
      </span>
    </div>
  )
}

function Empty({
  msg,
  tone,
}: {
  msg: string
  tone?: 'error'
}) {
  return (
    <div
      className="border px-4 py-6 text-sm flex items-center gap-2.5"
      style={{
        borderColor:
          tone === 'error'
            ? 'color-mix(in oklch, var(--t-red) 50%, transparent)'
            : 'var(--ink-faint)',
        background:
          tone === 'error'
            ? 'color-mix(in oklch, var(--t-red) 7%, transparent)'
            : undefined,
        color: tone === 'error' ? 'var(--t-red)' : 'var(--ink-soft)',
      }}
    >
      <span
        className={
          'status-dot ' + (tone === 'error' ? 'is-red' : 'is-cyan')
        }
      />
      <span>{msg}</span>
    </div>
  )
}
