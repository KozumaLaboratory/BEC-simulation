// ScanGroupView — cross-run comparison view for SpinorBEC scan groups.
// Reads `/api/scan_group/<scanName>` (see src/workflow/io/dashboard.jl) and
// renders three small-multiples plots + a tabular run summary.
//
// Aesthetic: laboratory notebook + observatory control panel. Hand-rolled
// SVG charts (no chart-lib dep) so the visual language stays bespoke
// rather than off-the-shelf. Fraunces for the few prose headers, JetBrains
// Mono for every number we show.

import { useEffect, useMemo, useState } from "react";

// ─── types ──────────────────────────────────────────────────────────────
interface Run {
  value: number;
  value_display: number;
  completed: boolean;
  point_dir: string;
  Lz_min?: number; Lz_max?: number; Lz_init?: number; Lz_final?: number;
  Fz_min?: number; Fz_max?: number; Fz_init?: number; Fz_final?: number;
  m_top_init?: number; m_top_final?: number;
  norm_max_dev?: number;
  larmor_phase_per_step?: number;
  error?: string;
}
interface ScanGroup {
  name: string;
  description: string;
  parameter: { key: string; values: number[]; unit: string; display_unit: string; display_factor: number };
  runs: Run[];
}

// ─── helpers ────────────────────────────────────────────────────────────
const REGIME_COLORS = { safe: "#7fb9a6", marginal: "#c8a76b", stiff: "#c97064", danger: "#9a3a3a", none: "#5c6370" };
function regimeOf(p?: number) {
  if (p === undefined || !isFinite(p) || p === 0) return { label: "—", color: REGIME_COLORS.none };
  if (p < 1) return { label: "safe", color: REGIME_COLORS.safe };
  if (p < 100) return { label: "marginal", color: REGIME_COLORS.marginal };
  if (p < 300) return { label: "stiff", color: REGIME_COLORS.stiff };
  return { label: "danger", color: REGIME_COLORS.danger };
}
function fmt(v: number | undefined, digits = 4): string {
  if (v === undefined || !isFinite(v)) return "—";
  if (v !== 0 && (Math.abs(v) < 1e-3 || Math.abs(v) > 1e4)) return v.toExponential(2);
  return v.toFixed(digits);
}
const niceTicks = (lo: number, hi: number, n = 4) => {
  const step = (hi - lo) / n;
  return Array.from({ length: n + 1 }, (_, i) => lo + i * step);
};

// ─── tiny SVG plot primitives ───────────────────────────────────────────
interface PlotProps { rows: { x: number; y?: number; color?: string }[]; xLabel: string; yLabel: string; yDomain?: [number, number]; logY?: boolean; }
function LinePlot({ rows, xLabel, yLabel, yDomain }: PlotProps) {
  const W = 320, H = 200, PL = 44, PR = 12, PT = 14, PB = 32;
  const pts = rows.filter((r) => r.y !== undefined && isFinite(r.y!));
  if (pts.length < 2) return <PlotEmpty W={W} H={H} />;
  const xs = pts.map((p) => p.x), ys = pts.map((p) => p.y!);
  const xLo = Math.min(...xs), xHi = Math.max(...xs);
  const yLo = yDomain ? yDomain[0] : Math.min(...ys), yHi = yDomain ? yDomain[1] : Math.max(...ys);
  const xS = (v: number) => PL + ((v - xLo) / (xHi - xLo || 1)) * (W - PL - PR);
  const yS = (v: number) => H - PB - ((v - yLo) / (yHi - yLo || 1)) * (H - PT - PB);
  const path = pts.map((p, i) => `${i === 0 ? "M" : "L"}${xS(p.x).toFixed(1)},${yS(p.y!).toFixed(1)}`).join("");
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-full">
      <Axes W={W} H={H} PL={PL} PR={PR} PT={PT} PB={PB} xTicks={niceTicks(xLo, xHi, 4)} yTicks={niceTicks(yLo, yHi, 4)} xS={xS} yS={yS} xLabel={xLabel} yLabel={yLabel} />
      <path d={path} fill="none" stroke="#d6c7a8" strokeWidth={1.4} className="origin-center" />
      {pts.map((p, i) => (
        <circle key={i} cx={xS(p.x)} cy={yS(p.y!)} r={3} fill={p.color ?? "#d6c7a8"} stroke="#0e0f12" strokeWidth={0.8} />
      ))}
    </svg>
  );
}
function BarPlotLog({ rows, xLabel, yLabel }: PlotProps) {
  const W = 320, H = 200, PL = 48, PR = 12, PT = 14, PB = 32;
  const pts = rows.filter((r) => r.y !== undefined && r.y! > 0);
  if (pts.length === 0) return <PlotEmpty W={W} H={H} />;
  const ys = pts.map((p) => p.y!);
  const lyLo = Math.log10(Math.max(0.1, Math.min(...ys) * 0.5));
  const lyHi = Math.log10(Math.max(...ys) * 1.5);
  const yS = (v: number) => H - PB - ((Math.log10(v) - lyLo) / (lyHi - lyLo || 1)) * (H - PT - PB);
  const bw = (W - PL - PR) / pts.length * 0.7;
  const xStep = (W - PL - PR) / pts.length;
  const tickVals = [1, 10, 100, 1000];
  const tickLabels = tickVals.filter((t) => Math.log10(t) >= lyLo && Math.log10(t) <= lyHi).map((t) => ({ v: t, label: t.toString() }));
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-full">
      {/* horizontal threshold lines for regime classification */}
      {[1, 100, 300].filter((t) => Math.log10(t) >= lyLo && Math.log10(t) <= lyHi).map((t) => (
        <line key={t} x1={PL} x2={W - PR} y1={yS(t)} y2={yS(t)} stroke="#2a2c30" strokeDasharray="2 3" strokeWidth={0.8} />
      ))}
      <line x1={PL} y1={H - PB} x2={W - PR} y2={H - PB} stroke="#5c6370" strokeWidth={0.6} />
      <line x1={PL} y1={PT} x2={PL} y2={H - PB} stroke="#5c6370" strokeWidth={0.6} />
      {tickLabels.map((t) => (
        <g key={t.v}>
          <text x={PL - 6} y={yS(t.v) + 3} textAnchor="end" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono">{t.label}</text>
          <line x1={PL - 3} x2={PL} y1={yS(t.v)} y2={yS(t.v)} stroke="#5c6370" strokeWidth={0.6} />
        </g>
      ))}
      {pts.map((p, i) => {
        const x = PL + (i + 0.5) * xStep - bw / 2;
        const y = yS(p.y!);
        return <rect key={i} x={x} y={y} width={bw} height={H - PB - y} fill={p.color ?? "#7fb9a6"} opacity={0.85} />;
      })}
      {pts.map((p, i) => {
        const x = PL + (i + 0.5) * xStep;
        return <text key={i} x={x} y={H - PB + 14} textAnchor="middle" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono">{fmt(p.x, 1)}</text>;
      })}
      <text x={(PL + W - PR) / 2} y={H - 4} textAnchor="middle" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono" fontStyle="italic">{xLabel}</text>
      <text x={12} y={(PT + H - PB) / 2} textAnchor="middle" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono" fontStyle="italic" transform={`rotate(-90 12 ${(PT + H - PB) / 2})`}>{yLabel}</text>
    </svg>
  );
}
function Axes({ W, H, PL, PR, PT, PB, xTicks, yTicks, xS, yS, xLabel, yLabel }: { W: number; H: number; PL: number; PR: number; PT: number; PB: number; xTicks: number[]; yTicks: number[]; xS: (v: number) => number; yS: (v: number) => number; xLabel: string; yLabel: string }) {
  return (
    <g>
      {yTicks.map((t, i) => (
        <g key={`y${i}`}>
          <line x1={PL} x2={W - PR} y1={yS(t)} y2={yS(t)} stroke="#2a2c30" strokeDasharray="2 4" strokeWidth={0.8} />
          <text x={PL - 6} y={yS(t) + 3} textAnchor="end" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono">{fmt(t, 2)}</text>
        </g>
      ))}
      {xTicks.map((t, i) => (
        <g key={`x${i}`}>
          <text x={xS(t)} y={H - PB + 14} textAnchor="middle" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono">{fmt(t, 1)}</text>
          <line x1={xS(t)} x2={xS(t)} y1={H - PB} y2={H - PB + 3} stroke="#5c6370" strokeWidth={0.6} />
        </g>
      ))}
      <line x1={PL} y1={H - PB} x2={W - PR} y2={H - PB} stroke="#5c6370" strokeWidth={0.6} />
      <line x1={PL} y1={PT} x2={PL} y2={H - PB} stroke="#5c6370" strokeWidth={0.6} />
      <text x={(PL + W - PR) / 2} y={H - 4} textAnchor="middle" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono" fontStyle="italic">{xLabel}</text>
      <text x={12} y={(PT + H - PB) / 2} textAnchor="middle" fill="#5c6370" fontSize="9" fontFamily="JetBrains Mono" fontStyle="italic" transform={`rotate(-90 12 ${(PT + H - PB) / 2})`}>{yLabel}</text>
    </g>
  );
}
const PlotEmpty = ({ W, H }: { W: number; H: number }) => <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-full"><text x={W / 2} y={H / 2} textAnchor="middle" fill="#5c6370" fontSize="11" fontFamily="JetBrains Mono">no data</text></svg>;

// ─── main component ─────────────────────────────────────────────────────
export default function ScanGroupView({ scanName }: { scanName: string }) {
  const [data, setData] = useState<ScanGroup | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    let cancelled = false;
    setError(null); setData(null);
    fetch(`/api/scan_group/${encodeURIComponent(scanName)}`)
      .then((r) => r.ok ? r.json() : Promise.reject(`HTTP ${r.status}`))
      .then((j) => !cancelled && (j.error ? setError(j.error) : setData(j)))
      .catch((e) => !cancelled && setError(String(e)));
    return () => { cancelled = true; };
  }, [scanName]);

  const xLabel = data ? (data.parameter.display_unit || data.parameter.unit || data.parameter.key) : "";
  const mTopRows = useMemo(() => data?.runs.map((r) => ({ x: r.value_display, y: r.m_top_final, color: "#d4a574" })) ?? [], [data]);
  const lzRows = useMemo(() => data?.runs.map((r) => ({ x: r.value_display, y: r.Lz_max, color: "#7fb9a6" })) ?? [], [data]);
  const larmorRows = useMemo(() => data?.runs.map((r) => ({ x: r.value_display, y: r.larmor_phase_per_step, color: regimeOf(r.larmor_phase_per_step).color })) ?? [], [data]);

  return (
    <div className="min-h-screen bg-[#0e0f12] text-stone-200" style={{ fontFamily: '"Fraunces", "Iowan Old Style", Georgia, serif' }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,300;9..144,400;9..144,600&family=JetBrains+Mono:wght@400;500;700&display=swap');
        .num{font-family:'JetBrains Mono',monospace;font-variant-numeric:tabular-nums}.sc{font-variant:small-caps;letter-spacing:.08em}
        .stagger>*{opacity:0;animation:fu .5s ease-out forwards}.stagger>*:nth-child(1){animation-delay:0s}.stagger>*:nth-child(2){animation-delay:.08s}.stagger>*:nth-child(3){animation-delay:.16s}.stagger>*:nth-child(4){animation-delay:.24s}
        @keyframes fu{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}`}</style>

      <header className="border-b border-stone-800 px-6 lg:px-10 py-5 flex flex-wrap items-baseline gap-x-6 gap-y-2">
        <div className="text-[10px] num sc text-stone-500">scan_group</div>
        <h1 className="text-2xl lg:text-3xl font-light tracking-tight text-stone-100">{data?.name?.replace(/_/g, " ") ?? scanName}</h1>
        {data && <div className="ml-auto text-[11px] num text-stone-500">{data.runs.length} pts · axis: <span className="text-stone-300">{data.parameter.key}</span> [{data.parameter.unit}]</div>}
      </header>

      {error && <div className="px-10 py-6 text-sm num text-red-300">error: {error}</div>}
      {!data && !error && <div className="px-10 py-12 text-stone-500 num sc text-xs animate-pulse">loading…</div>}

      {data && (
        <>
          {data.description && <p className="px-6 lg:px-10 py-4 text-[13px] text-stone-400 italic max-w-3xl leading-relaxed">{data.description}</p>}

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-px bg-stone-800/40 stagger">
            <PlotCard className="lg:col-span-5" title="m=+F population" subtitle={`final · vs ${data.parameter.key}`}>
              <LinePlot rows={mTopRows} xLabel={xLabel} yLabel="m_top final" yDomain={[0, 1.02]} />
            </PlotCard>
            <PlotCard className="lg:col-span-4" title="⟨L_z⟩ maximum" subtitle={`vs ${data.parameter.key}`}>
              <LinePlot rows={lzRows} xLabel={xLabel} yLabel="Lz max" />
            </PlotCard>
            <PlotCard className="lg:col-span-3" title="Larmor regime" subtitle="p · F · dt — log scale">
              <BarPlotLog rows={larmorRows} xLabel={data.parameter.key} yLabel="phase / step" />
            </PlotCard>
          </div>

          <section className="px-6 lg:px-10 py-8">
            <div className="sc num text-[10px] text-stone-500 mb-3">all runs · {data.runs.length} points</div>
            <div className="overflow-x-auto border border-stone-800">
              <table className="w-full text-[11px] num">
                <thead className="bg-stone-900/80 text-stone-400 sc text-[10px]">
                  <tr>{["param", "display", "m_top init", "m_top final", "Lz min", "Lz max", "Fz drift", "norm dev", "Larmor", "regime"].map((h) => <th key={h} className="px-2 py-2 text-right font-normal">{h}</th>)}<th className="px-3 py-2 text-left font-normal">point_dir</th></tr>
                </thead>
                <tbody>
                  {data.runs.map((r, i) => {
                    const reg = regimeOf(r.larmor_phase_per_step);
                    const fzd = (r.Fz_final !== undefined && r.Fz_init !== undefined) ? r.Fz_final - r.Fz_init : undefined;
                    return (
                      <tr key={i} className="border-t border-stone-800 hover:bg-stone-900/40 transition-colors">
                        <Td>{fmt(r.value, 3)}</Td>
                        <Td>{fmt(r.value_display, 2)}</Td>
                        <Td>{fmt(r.m_top_init)}</Td>
                        <Td className="text-amber-200">{fmt(r.m_top_final)}</Td>
                        <Td>{fmt(r.Lz_min, 3)}</Td>
                        <Td className="text-emerald-300">{fmt(r.Lz_max, 3)}</Td>
                        <Td>{fmt(fzd, 3)}</Td>
                        <Td className="text-stone-500">{fmt(r.norm_max_dev, 1)}</Td>
                        <Td><span style={{ color: reg.color }}>{fmt(r.larmor_phase_per_step, 1)}</span></Td>
                        <Td className="sc text-[10px]" style={{ color: reg.color }}>{reg.label}</Td>
                        <td className="px-3 py-1.5 text-left text-stone-500 max-w-xs truncate">{r.point_dir}{!r.completed && <span className="ml-2 text-amber-400 text-[9px] sc">pending</span>}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}
    </div>
  );
}

function PlotCard({ title, subtitle, children, className = "" }: { title: string; subtitle: string; children: React.ReactNode; className?: string }) {
  return (
    <div className={`bg-[#0e0f12] p-5 ${className}`}>
      <div className="flex items-baseline justify-between mb-3 pb-2 border-b border-stone-800">
        <div className="text-stone-100 text-[13px]">{title}</div>
        <div className="num sc text-[9px] text-stone-500">{subtitle}</div>
      </div>
      <div className="h-[200px]">{children}</div>
    </div>
  );
}
function Td({ children, className = "", style }: { children: React.ReactNode; className?: string; style?: React.CSSProperties }) {
  return <td className={`px-2 py-1.5 text-right text-stone-300 ${className}`} style={style}>{children}</td>;
}
