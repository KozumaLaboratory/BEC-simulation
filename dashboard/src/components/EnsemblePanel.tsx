// EnsemblePanel — TWA ensemble statistics view (Round-2 Task 5).
//
// Reads /api/ensemble/:run/:file (see _route_ensemble in
// src/workflow/io/dashboard/routes.jl) and renders three Recharts panels
// per ensemble phase: on-axis ratio time series, σ/μ at peak time series,
// and a σ/μ histogram across all voxels with ⟨n⟩ above 1% of peak.
//
// 3D mean/variance volume rendering is a follow-up — currently this is the
// scalar-summary surface; the toggle row marks the volume modes as pending
// so the UI advertises the eventual capability without faking it.

import { useEffect, useMemo, useState } from 'react'
import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { api, type EnsemblePhase, type EnsembleObservable, type EnsembleSummary } from '../api'

const AXIS = '#5c6370'
const GRID = '#23252a'
const MEAN = '#7fb9a6'
const SIGMA = '#d6c7a8'
const REF = '#c97064'

function fmt(v: number | undefined, digits = 4): string {
  if (v === undefined || !isFinite(v)) return '—'
  if (v !== 0 && (Math.abs(v) < 1e-3 || Math.abs(v) > 1e4)) return v.toExponential(2)
  return v.toFixed(digits)
}

function ChartTooltip({
  active, payload, label, unit,
}: {
  active?: boolean
  payload?: { value: number; name: string; color: string }[]
  label?: number
  unit?: string
}) {
  if (!active || !payload?.length) return null
  return (
    <div className="bg-[#0e0f12] border border-stone-700 px-3 py-2 ens-num text-[11px] text-stone-200 shadow-lg">
      <div className="text-stone-500 ens-sc text-[9px] mb-0.5">
        {label !== undefined ? `${fmt(label, 3)}${unit ? ` ${unit}` : ''}` : ''}
      </div>
      {payload.map((p, i) => (
        <div key={i} style={{ color: p.color }}>
          {p.name}: {fmt(p.value, 4)}
        </div>
      ))}
    </div>
  )
}

interface PanelProps {
  title: string
  subtitle: string
  children: React.ReactNode
  className?: string
}
function Panel({ title, subtitle, children, className = '' }: PanelProps) {
  return (
    <div className={`bg-[#0e0f12] p-5 ${className}`}>
      <div className="flex items-baseline justify-between mb-3 pb-2 border-b border-stone-800">
        <div className="text-stone-100 text-[13px]">{title}</div>
        <div className="ens-num ens-sc text-[9px] text-stone-500">{subtitle}</div>
      </div>
      <div className="h-[220px]">{children}</div>
    </div>
  )
}

type ViewMode = 'mean' | 'variance' | 'single' | 'deterministic'

export default function EnsemblePanel({
  runName,
  fileName,
}: {
  runName: string
  fileName: string
}) {
  const [data, setData] = useState<EnsembleSummary | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [phaseIdx, setPhaseIdx] = useState<number | null>(null)
  const [viewMode, setViewMode] = useState<ViewMode>('mean')

  useEffect(() => {
    let cancelled = false
    setError(null)
    setData(null)
    api
      .getEnsemble(runName, fileName)
      .then((j) => {
        if (cancelled) return
        if (j.error) setError(j.error)
        else {
          setData(j)
          if (j.phases.length > 0) setPhaseIdx(j.phases[0].phase_idx)
        }
      })
      .catch((e: unknown) => !cancelled && setError(String(e)))
    return () => {
      cancelled = true
    }
  }, [runName, fileName])

  const phase: EnsemblePhase | null = useMemo(() => {
    if (!data || phaseIdx === null) return null
    return data.phases.find((p) => p.phase_idx === phaseIdx) ?? null
  }, [data, phaseIdx])

  const density = (phase?.['density'] as EnsembleObservable | undefined) ?? null

  const tsRows = useMemo(() => {
    if (!phase || !density) return []
    const t = phase.times
    const oar = density.on_axis_ratio_mean ?? []
    const sm = density.sigma_over_mu_at_peak ?? []
    const pm = density.peak_mean ?? []
    return t.map((ti, i) => ({
      t: ti,
      on_axis: oar[i],
      sigma_over_mu: sm[i],
      peak: pm[i],
    }))
  }, [phase, density])

  const histRows = useMemo(() => {
    if (!density?.sigma_over_mu_histogram) return []
    const h = density.sigma_over_mu_histogram
    return h.counts.map((c, i) => ({
      bin_lo: h.bin_edges[i],
      bin_hi: h.bin_edges[i + 1],
      bin_mid: 0.5 * (h.bin_edges[i] + h.bin_edges[i + 1]),
      count: c,
    }))
  }, [density])

  const finalOnAxis = tsRows.length ? tsRows[tsRows.length - 1].on_axis : undefined
  const finalSigma = tsRows.length ? tsRows[tsRows.length - 1].sigma_over_mu : undefined

  return (
    <div className="bg-[#0e0f12] text-stone-200" style={{ fontFamily: '"Fraunces", "Iowan Old Style", Georgia, serif' }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,300;9..144,400;9..144,600&family=JetBrains+Mono:wght@400;500;700&display=swap');
        .ens-num{font-family:'JetBrains Mono',monospace;font-variant-numeric:tabular-nums}
        .ens-sc{font-variant:small-caps;letter-spacing:.08em}
        .ens-stagger>*{opacity:0;animation:ens-fu .5s ease-out forwards}
        .ens-stagger>*:nth-child(1){animation-delay:0s}.ens-stagger>*:nth-child(2){animation-delay:.08s}.ens-stagger>*:nth-child(3){animation-delay:.16s}
        @keyframes ens-fu{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}`}</style>

      <header className="border-b border-stone-800 px-6 py-4 flex flex-wrap items-baseline gap-x-6 gap-y-2">
        <div className="text-[10px] ens-num ens-sc text-stone-500">twa ensemble</div>
        <h2 className="text-xl font-light tracking-tight text-stone-100">{runName} / {fileName}</h2>
        {phase && (
          <div className="ml-auto text-[11px] ens-num text-stone-500">
            phase <span className="text-stone-300">{String(phase.phase_idx).padStart(2, '0')}</span> · {phase.n_trajectories} traj · {phase.times.length} frames
          </div>
        )}
      </header>

      {error && <div className="px-6 py-4 text-sm ens-num text-red-300">error: {error}</div>}
      {!data && !error && <div className="px-6 py-8 text-stone-500 ens-num ens-sc text-xs animate-pulse">loading…</div>}
      {data && data.phases.length === 0 && (
        <div className="px-6 py-6 text-[12px] text-stone-400 italic">
          No TWA ensemble data in this run. Re-run with a <code className="ens-num text-stone-200">twa:</code> block in the dynamics phase.
        </div>
      )}

      {data && data.phases.length > 0 && (
        <>
          <div className="px-6 py-3 flex flex-wrap items-center gap-3 border-b border-stone-800/60">
            <span className="text-[10px] ens-num ens-sc text-stone-500">phase</span>
            {data.phases.map((p) => (
              <button
                key={p.phase_idx}
                onClick={() => setPhaseIdx(p.phase_idx)}
                className={`px-2.5 py-1 ens-num text-[11px] border transition-colors ${
                  p.phase_idx === phaseIdx ? 'border-stone-300 text-stone-100 bg-stone-800/40' : 'border-stone-700 text-stone-400 hover:border-stone-500'
                }`}
              >
                phase_{String(p.phase_idx).padStart(2, '0')}
              </button>
            ))}
            <span className="ml-auto text-[10px] ens-num ens-sc text-stone-500">view</span>
            {(['deterministic', 'single', 'mean', 'variance'] as const).map((m) => {
              const enabled = m === 'mean' || m === 'variance'
              return (
                <button
                  key={m}
                  onClick={() => enabled && setViewMode(m)}
                  disabled={!enabled}
                  className={`px-2.5 py-1 ens-num text-[11px] border transition-colors ${
                    viewMode === m
                      ? 'border-amber-300/60 text-amber-200 bg-amber-900/10'
                      : enabled
                      ? 'border-stone-700 text-stone-400 hover:border-stone-500'
                      : 'border-stone-800 text-stone-600 cursor-not-allowed line-through'
                  }`}
                  title={enabled ? '' : '3D volume rendering — follow-up'}
                >
                  {m}
                </button>
              )
            })}
          </div>

          {phase && density && (
            <>
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-px bg-stone-800/40 ens-stagger">
                <Panel title="on-axis ratio" subtitle="ensemble mean vs t">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={tsRows} margin={{ top: 8, right: 12, left: -8, bottom: 8 }}>
                      <CartesianGrid stroke={GRID} strokeDasharray="2 4" />
                      <XAxis dataKey="t" type="number" domain={['dataMin', 'dataMax']} tickFormatter={(v) => fmt(v, 2)} stroke={AXIS} label={{ value: 't [ω⁻¹]', position: 'insideBottom', offset: -4, fill: AXIS, fontSize: 9, fontStyle: 'italic' }} />
                      <YAxis stroke={AXIS} tickFormatter={(v) => fmt(v, 2)} domain={[0, 'auto']} />
                      <Tooltip content={<ChartTooltip unit="ω⁻¹" />} />
                      <ReferenceLine y={1} stroke={AXIS} strokeOpacity={0.4} strokeDasharray="3 3" />
                      <Line type="monotone" dataKey="on_axis" stroke={MEAN} strokeWidth={1.6} dot={{ r: 2, fill: MEAN, stroke: '#0e0f12', strokeWidth: 0.6 }} activeDot={{ r: 4 }} isAnimationActive={false} name="on_axis ⟨n⟩" connectNulls />
                    </LineChart>
                  </ResponsiveContainer>
                </Panel>

                <Panel title="σ/μ at peak" subtitle="trajectory-level fluctuation">
                  <ResponsiveContainer width="100%" height="100%">
                    <LineChart data={tsRows} margin={{ top: 8, right: 12, left: -8, bottom: 8 }}>
                      <CartesianGrid stroke={GRID} strokeDasharray="2 4" />
                      <XAxis dataKey="t" type="number" domain={['dataMin', 'dataMax']} tickFormatter={(v) => fmt(v, 2)} stroke={AXIS} label={{ value: 't [ω⁻¹]', position: 'insideBottom', offset: -4, fill: AXIS, fontSize: 9, fontStyle: 'italic' }} />
                      <YAxis stroke={AXIS} tickFormatter={(v) => fmt(v, 2)} domain={[0, 'auto']} />
                      <Tooltip content={<ChartTooltip unit="ω⁻¹" />} />
                      <Line type="monotone" dataKey="sigma_over_mu" stroke={SIGMA} strokeWidth={1.6} dot={{ r: 2, fill: SIGMA, stroke: '#0e0f12', strokeWidth: 0.6 }} activeDot={{ r: 4 }} isAnimationActive={false} name="σ/μ peak" connectNulls />
                    </LineChart>
                  </ResponsiveContainer>
                </Panel>

                <Panel
                  title="σ/μ histogram"
                  subtitle={
                    density.sigma_over_mu_histogram
                      ? `final frame · ${density.sigma_over_mu_histogram.n_voxels} voxels · n>${(100 * density.sigma_over_mu_histogram.threshold_frac_of_peak).toFixed(0)}% peak`
                      : 'no variance data'
                  }
                >
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={histRows} margin={{ top: 8, right: 12, left: -8, bottom: 8 }}>
                      <CartesianGrid stroke={GRID} strokeDasharray="2 4" vertical={false} />
                      <XAxis dataKey="bin_mid" type="number" domain={['dataMin', 'dataMax']} tickFormatter={(v) => fmt(v, 2)} stroke={AXIS} label={{ value: 'σ/μ', position: 'insideBottom', offset: -4, fill: AXIS, fontSize: 9, fontStyle: 'italic' }} />
                      <YAxis stroke={AXIS} tickFormatter={(v) => fmt(v, 0)} />
                      <Tooltip content={<ChartTooltip />} />
                      <ReferenceLine x={1} stroke={REF} strokeDasharray="3 3" strokeOpacity={0.7} label={{ value: 'σ=μ', fill: REF, fontSize: 9, position: 'top' }} />
                      <Bar dataKey="count" fill={SIGMA} isAnimationActive={false} name="voxels" />
                    </BarChart>
                  </ResponsiveContainer>
                </Panel>
              </div>

              <section className="px-6 py-5 grid grid-cols-2 lg:grid-cols-4 gap-4 text-[11px] ens-num">
                <Stat label="trajectories" value={String(phase.n_trajectories)} />
                <Stat label="frames" value={String(phase.times.length)} />
                <Stat label="on_axis (final)" value={fmt(finalOnAxis, 3)} accent="emerald" />
                <Stat label="σ/μ peak (final)" value={fmt(finalSigma, 3)} accent="amber" />
              </section>
            </>
          )}
        </>
      )}
    </div>
  )
}

function Stat({ label, value, accent }: { label: string; value: string; accent?: 'amber' | 'emerald' }) {
  const cls =
    accent === 'amber'
      ? 'text-amber-200'
      : accent === 'emerald'
      ? 'text-emerald-300'
      : 'text-stone-100'
  return (
    <div>
      <div className="ens-sc text-[9px] text-stone-500 mb-1">{label}</div>
      <div className={`text-base ${cls}`}>{value}</div>
    </div>
  )
}
