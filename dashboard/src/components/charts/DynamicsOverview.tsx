import { useMemo } from 'react'
import { Card, CardContent } from '@/components/ui/card'
import { LineChartSVG, type LineChartTrace } from './LineChartSVG'
import { CHART_COLORS } from './chartColors'
import type { DynamicsSeries } from '@/api'

interface Props {
  series: DynamicsSeries
}

// Time-evolution overview for a single dynamics run. The per-point scan
// charts (Energy vs point index etc.) collapse to a single marker for
// these runs — the meaningful signal is the evolution over `dynamics/*`
// snapshots, which this panel plots instead.
export function DynamicsOverview({ series: s }: Props) {
  const popTraces = useMemo<LineChartTrace[]>(() => {
    if (!s?.populations || !s.m_values || !s.n_comp || !s.pop_times) return []
    const nComp = s.n_comp
    const times = s.pop_times
    const nSnaps = times.length
    return s.m_values.map((m, c) => ({
      name: `m=${m}`,
      color: CHART_COLORS[c % CHART_COLORS.length],
      x: times,
      y: Array.from({ length: nSnaps }, (_, t) => s.populations![t * nComp + c]),
    }))
  }, [s])

  const energyTrace: LineChartTrace[] =
    s.times && s.energies
      ? [{ name: 'Energy', color: CHART_COLORS[0], x: s.times, y: s.energies }]
      : []
  const mzTrace: LineChartTrace[] =
    s.times && s.magnetizations
      ? [{ name: '⟨Fz⟩', color: CHART_COLORS[1], x: s.times, y: s.magnetizations }]
      : []
  const normTrace: LineChartTrace[] =
    s.times && s.norms
      ? [{ name: 'norm', color: CHART_COLORS[4], x: s.times, y: s.norms }]
      : []
  // Anchor the norm axis to a ±1% conservation band. Hamiltonian-only
  // runs conserve norm to ~1e-13, and without a floor the auto-range
  // zooms into that float round-off and renders it as a dramatic (and
  // misleading) curve with every tick label collapsing to "1.00". The
  // band keeps a perfectly-conserved norm visibly flat while still
  // revealing real loss (e.g. a lossy run dropping toward 0.9).
  const normRange: [number, number] | undefined = s.norms?.length
    ? [Math.min(0.99, ...s.norms), Math.max(1.01, ...s.norms)]
    : undefined

  return (
    <>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        <Card>
          <CardContent className="p-6">
            <Head index={1} name="Energy" expr="ℏω_ref" />
            <LineChartSVG
              traces={energyTrace}
              xLabel="t (ω_ref⁻¹)"
              yLabel="Energy"
              height={300}
            />
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-6">
            <Head index={2} name="Magnetization" expr="⟨Fz⟩(t)" />
            <LineChartSVG
              traces={mzTrace}
              xLabel="t (ω_ref⁻¹)"
              yLabel="⟨Fz⟩"
              height={300}
            />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardContent className="p-6">
          <Head index={3} name="Populations" expr="|c_m|²(t)" />
          <LineChartSVG
            title="Populations per m vs time"
            traces={popTraces}
            xLabel="t (ω_ref⁻¹)"
            yLabel="Population"
            yRange={[0, 1]}
            height={360}
          />
        </CardContent>
      </Card>

      <Card>
        <CardContent className="p-6">
          <Head index={4} name="Norm" expr="∫|ψ|² — conservation" />
          <LineChartSVG
            traces={normTrace}
            xLabel="t (ω_ref⁻¹)"
            yLabel="norm"
            yRange={normRange}
            height={260}
          />
        </CardContent>
      </Card>
    </>
  )
}

function Head({
  name,
  expr,
  index,
}: {
  name: string
  expr?: string
  index?: number
}) {
  return (
    <div className="section-head">
      {index != null && (
        <span className="num">§{String(index).padStart(2, '0')}</span>
      )}
      <span>{name}</span>
      <span className="rule" aria-hidden />
      {expr && <span className="unit">{expr}</span>}
    </div>
  )
}
