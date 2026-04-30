// ScanGroupView — cross-run scan dashboard, Matsui-aligned.
//
// Aligned with Matsui 2025 (Einstein-de Haas proposal for Eu151): the
// headline observables are the spin→orbital transfer (ΔL_z, ΔF_z) and
// the conservation check ΔL_z + ΔF_z ≈ 0. Reads
// `/api/scan_group/<scanName>` (see src/workflow/io/dashboard.jl).
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
const safeDiff = (a?: number, b?: number) =>
  (a !== undefined && b !== undefined && isFinite(a) && isFinite(b)) ? a - b : undefined;
const niceTicks = (lo: number, hi: number, n = 4) => {
  const step = (hi - lo) / n;
  return Array.from({ length: n + 1 }, (_, i) => lo + i * step);
};

// ─── SVG primitives ─────────────────────────────────────────────────────
const W = 320, H = 200, PL = 44, PR = 12, PT = 14, PB = 32;
const PlotEmpty = () => <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-full"><text x={W / 2} y={H / 2} textAnchor="middle" fill="#5c6370" fontSize="11" fontFamily="JetBrains Mono">no data</text></svg>;

interface PlotProps {
  rows: { x: number; y?: number; color?: string }[];
  xLabel: string;
  yLabel: string;
  xDomain?: [number, number];
  yDomain?: [number, number];
  mode?: "line" | "scatter";
  refLine?: (x: number) => number;
  refLabel?: string;
  zeroAxis?: boolean;
}
function LinePlot({ rows, xLabel, yLabel, xDomain, yDomain, mode = "line", refLine, refLabel, zeroAxis = false }: PlotProps) {
  const pts = rows.filter((r) => r.y !== undefined && isFinite(r.y!));
  if (pts.length < (mode === "scatter" ? 1 : 2)) return <PlotEmpty />;
  const xs = pts.map((p) => p.x), ys = pts.map((p) => p.y!);
  let xLo = xDomain ? xDomain[0] : Math.min(...xs);
  let xHi = xDomain ? xDomain[1] : Math.max(...xs);
  let yLo = yDomain ? yDomain[0] : Math.min(...ys);
  let yHi = yDomain ? yDomain[1] : Math.max(...ys);
  if (xLo === xHi) { xLo -= 1; xHi += 1; }
  if (yLo === yHi) { yLo -= 1; yHi += 1; }
  if (refLine) {
    const refYs = [refLine(xLo), refLine(xHi)];
    yLo = Math.min(yLo, ...refYs); yHi = Math.max(yHi, ...refYs);
  }
  const xS = (v: number) => PL + ((v - xLo) / (xHi - xLo || 1)) * (W - PL - PR);
  const yS = (v: number) => H - PB - ((v - yLo) / (yHi - yLo || 1)) * (H - PT - PB);
  const path = mode === "line" ? pts.map((p, i) => `${i === 0 ? "M" : "L"}${xS(p.x).toFixed(1)},${yS(p.y!).toFixed(1)}`).join("") : null;
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full h-full">
      <Axes xTicks={niceTicks(xLo, xHi, 4)} yTicks={niceTicks(yLo, yHi, 4)} xS={xS} yS={yS} xLabel={xLabel} yLabel={yLabel} />
      {zeroAxis && yLo < 0 && yHi > 0 && (
        <line x1={PL} x2={W - PR} y1={yS(0)} y2={yS(0)} stroke="#3a3c40" strokeWidth={0.6} />
      )}
      {refLine && (
        <>
          <line x1={xS(xLo)} y1={yS(refLine(xLo))} x2={xS(xHi)} y2={yS(refLine(xHi))} stroke="#7a8a99" strokeWidth={0.8} strokeDasharray="3 3" opacity={0.7} />
          {refLabel && <text x={W - PR - 4} y={yS(refLine(xHi)) - 4} textAnchor="end" fill="#7a8a99" fontSize="9" fontStyle="italic" fontFamily="JetBrains Mono">{refLabel}</text>}
        </>
      )}
      {path && <path d={path} fill="none" stroke="#d6c7a8" strokeWidth={1.4} />}
      {pts.map((p, i) => (
        <circle key={i} cx={xS(p.x)} cy={yS(p.y!)} r={3} fill={p.color ?? "#d6c7a8"} stroke="#0e0f12" strokeWidth={0.8} />
      ))}
    </svg>
  );
}
function Axes({ xTicks, yTicks, xS, yS, xLabel, yLabel }: { xTicks: number[]; yTicks: number[]; xS: (v: number) => number; yS: (v: number) => number; xLabel: string; yLabel: string }) {
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
  const dLzRows = useMemo(() => data?.runs.map((r) => ({
    x: r.value_display,
    y: safeDiff(r.Lz_final, r.Lz_init),
    color: regimeOf(r.larmor_phase_per_step).color,
  })) ?? [], [data]);
  const dFzRows = useMemo(() => data?.runs.map((r) => ({
    x: r.value_display,
    y: safeDiff(r.Fz_final, r.Fz_init),
    color: regimeOf(r.larmor_phase_per_step).color,
  })) ?? [], [data]);
  const conservationRows = useMemo(() => data?.runs.map((r) => {
    const dF = safeDiff(r.Fz_final, r.Fz_init);
    const dL = safeDiff(r.Lz_final, r.Lz_init);
    return { x: dF ?? NaN, y: dL, color: regimeOf(r.larmor_phase_per_step).color };
  }).filter((r) => isFinite(r.x)) ?? [], [data]);

  return (
    <div className="min-h-screen bg-[#0e0f12] text-stone-200" style={{ fontFamily: '"Fraunces", "Iowan Old Style", Georgia, serif' }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,300;9..144,400;9..144,600&family=JetBrains+Mono:wght@400;500;700&display=swap');
        .num{font-family:'JetBrains Mono',monospace;font-variant-numeric:tabular-nums}.sc{font-variant:small-caps;letter-spacing:.08em}
        .stagger>*{opacity:0;animation:fu .5s ease-out forwards}.stagger>*:nth-child(1){animation-delay:0s}.stagger>*:nth-child(2){animation-delay:.08s}.stagger>*:nth-child(3){animation-delay:.16s}.stagger>*:nth-child(4){animation-delay:.24s}
        @keyframes fu{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}`}</style>

      <header className="border-b border-stone-800 px-6 lg:px-10 py-5 flex flex-wrap items-baseline gap-x-6 gap-y-2">
        <div className="text-[10px] num sc text-stone-500">scan_group · matsui 2025 edh observables</div>
        <h1 className="text-2xl lg:text-3xl font-light tracking-tight text-stone-100">{data?.name?.replace(/_/g, " ") ?? scanName}</h1>
        {data && <div className="ml-auto text-[11px] num text-stone-500">{data.runs.length} pts · axis: <span className="text-stone-300">{data.parameter.key}</span> [{data.parameter.unit}]</div>}
      </header>

      {error && <div className="px-10 py-6 text-sm num text-red-300">error: {error}</div>}
      {!data && !error && <div className="px-10 py-12 text-stone-500 num sc text-xs animate-pulse">loading…</div>}

      {data && (
        <>
          {data.description && <p className="px-6 lg:px-10 py-4 text-[13px] text-stone-400 italic max-w-3xl leading-relaxed">{data.description}</p>}

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-px bg-stone-800/40 stagger">
            <PlotCard className="lg:col-span-4" title="ΔL_z" subtitle={`orbital gain · vs ${data.parameter.key}`}>
              <LinePlot rows={dLzRows} xLabel={xLabel} yLabel="ΔL_z [ℏ]" zeroAxis />
            </PlotCard>
            <PlotCard className="lg:col-span-4" title="ΔF_z" subtitle={`spin change · vs ${data.parameter.key}`}>
              <LinePlot rows={dFzRows} xLabel={xLabel} yLabel="ΔF_z [ℏ]" zeroAxis />
            </PlotCard>
            <PlotCard className="lg:col-span-4" title="EdH conservation" subtitle="ΔL_z vs ΔF_z · ideal y = −x">
              <LinePlot rows={conservationRows} xLabel="ΔF_z [ℏ]" yLabel="ΔL_z [ℏ]" mode="scatter" refLine={(x) => -x} refLabel="ΔL+ΔF=0" zeroAxis />
            </PlotCard>
          </div>

          <section className="px-6 lg:px-10 py-8">
            <div className="sc num text-[10px] text-stone-500 mb-3">all runs · {data.runs.length} points · ΔL_z = L_z(final) − L_z(init)</div>
            <div className="overflow-x-auto border border-stone-800">
              <table className="w-full text-[11px] num">
                <thead className="bg-stone-900/80 text-stone-400 sc text-[10px]">
                  <tr>{["param", "display", "m_top init", "m_top final", "ΔL_z", "L_z max", "ΔF_z", "ΔL+ΔF", "norm dev", "Larmor", "regime"].map((h) => <th key={h} className="px-2 py-2 text-right font-normal">{h}</th>)}<th className="px-3 py-2 text-left font-normal">point_dir</th></tr>
                </thead>
                <tbody>
                  {data.runs.map((r, i) => {
                    const reg = regimeOf(r.larmor_phase_per_step);
                    const dLz = safeDiff(r.Lz_final, r.Lz_init);
                    const dFz = safeDiff(r.Fz_final, r.Fz_init);
                    const cons = (dLz !== undefined && dFz !== undefined) ? dLz + dFz : undefined;
                    const consOK = cons !== undefined && Math.abs(cons) < 0.05;
                    return (
                      <tr key={i} className="border-t border-stone-800 hover:bg-stone-900/40 transition-colors">
                        <Td>{fmt(r.value, 3)}</Td>
                        <Td>{fmt(r.value_display, 2)}</Td>
                        <Td>{fmt(r.m_top_init)}</Td>
                        <Td className="text-amber-200">{fmt(r.m_top_final)}</Td>
                        <Td className="text-emerald-300">{fmt(dLz, 3)}</Td>
                        <Td className="text-stone-400">{fmt(r.Lz_max, 3)}</Td>
                        <Td className="text-sky-300">{fmt(dFz, 3)}</Td>
                        <Td className={consOK ? "text-stone-500" : "text-red-300"}>{fmt(cons, 3)}</Td>
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
