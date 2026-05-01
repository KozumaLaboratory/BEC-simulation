// ScanGroupView — cross-run scan dashboard.
//
// Fetches /api/scan_group/<scanName> (see src/workflow/io/dashboard.jl) and
// renders three recharts panels — m_top(final) vs parameter, L_z(max) vs
// parameter, and a Larmor-phase gauge per point — followed by a complete
// run table.
//
// Aesthetic: a quiet laboratory-instrument feel. Fraunces for prose,
// JetBrains Mono for every number. Phosphor-amber for the spin headline,
// teal for the orbital, red→amber→teal Larmor regime palette. No purple,
// no cliché chart-default theming.

import { useEffect, useMemo, useState } from "react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

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

const REGIME = {
  none: "#5c6370",
  safe: "#7fb9a6",
  marginal: "#c8a76b",
  stiff: "#c97064",
  danger: "#9a3a3a",
};
function regimeOf(p?: number): { label: string; color: string } {
  if (p === undefined || !isFinite(p) || p === 0) return { label: "—", color: REGIME.none };
  if (p < 1) return { label: "safe", color: REGIME.safe };
  if (p < 100) return { label: "marginal", color: REGIME.marginal };
  if (p < 300) return { label: "stiff", color: REGIME.stiff };
  return { label: "danger", color: REGIME.danger };
}
function fmt(v: number | undefined, digits = 4): string {
  if (v === undefined || !isFinite(v)) return "—";
  if (v !== 0 && (Math.abs(v) < 1e-3 || Math.abs(v) > 1e4)) return v.toExponential(2);
  return v.toFixed(digits);
}

const AXIS = "#5c6370";
const GRID = "#23252a";
const SPIN = "#d6c7a8";
const ORBITAL = "#7fb9a6";

function ChartTooltip({ active, payload, label, unit }: { active?: boolean; payload?: { value: number; name: string; color: string }[]; label?: number; unit?: string }) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-[#0e0f12] border border-stone-700 px-3 py-2 num text-[11px] text-stone-200 shadow-lg">
      <div className="text-stone-500 sc text-[9px] mb-0.5">{label !== undefined ? `${fmt(label, 3)} ${unit ?? ""}` : ""}</div>
      {payload.map((p, i) => (
        <div key={i} style={{ color: p.color }}>{p.name}: {fmt(p.value, 4)}</div>
      ))}
    </div>
  );
}

interface PanelProps { title: string; subtitle: string; children: React.ReactNode; className?: string }
function Panel({ title, subtitle, children, className = "" }: PanelProps) {
  return (
    <div className={`bg-[#0e0f12] p-5 ${className}`}>
      <div className="flex items-baseline justify-between mb-3 pb-2 border-b border-stone-800">
        <div className="text-stone-100 text-[13px]">{title}</div>
        <div className="num sc text-[9px] text-stone-500">{subtitle}</div>
      </div>
      <div className="h-[220px]">{children}</div>
    </div>
  );
}

export default function ScanGroupView({ scanName }: { scanName: string }) {
  const [data, setData] = useState<ScanGroup | null>(null);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => {
    let cancelled = false;
    setError(null); setData(null);
    fetch(`/api/scan_group/${encodeURIComponent(scanName)}`)
      .then((r) => (r.ok ? r.json() : Promise.reject(`HTTP ${r.status}`)))
      .then((j) => !cancelled && (j.error ? setError(j.error) : setData(j)))
      .catch((e) => !cancelled && setError(String(e)));
    return () => { cancelled = true; };
  }, [scanName]);

  const xUnit = data?.parameter.display_unit || data?.parameter.unit || "";
  const xKey = data?.parameter.key ?? "";

  const rows = useMemo(() => data?.runs.map((r) => ({
    x: r.value_display,
    m_top_final: r.m_top_final,
    Lz_max: r.Lz_max,
    larmor: r.larmor_phase_per_step ?? 0,
    color: regimeOf(r.larmor_phase_per_step).color,
  })) ?? [], [data]);

  return (
    <div className="min-h-screen bg-[#0e0f12] text-stone-200" style={{ fontFamily: '"Fraunces", "Iowan Old Style", Georgia, serif' }}>
      <style>{`@import url('https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,300;9..144,400;9..144,600&family=JetBrains+Mono:wght@400;500;700&display=swap');
        .num{font-family:'JetBrains Mono',monospace;font-variant-numeric:tabular-nums}
        .sc{font-variant:small-caps;letter-spacing:.08em}
        .stagger>*{opacity:0;animation:fu .5s ease-out forwards}
        .stagger>*:nth-child(1){animation-delay:0s}.stagger>*:nth-child(2){animation-delay:.08s}.stagger>*:nth-child(3){animation-delay:.16s}
        @keyframes fu{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:translateY(0)}}
        .recharts-text{font-family:'JetBrains Mono',monospace;font-size:9px;fill:${AXIS}}
        .recharts-cartesian-axis-line,.recharts-cartesian-axis-tick-line{stroke:${AXIS}}`}</style>

      <header className="border-b border-stone-800 px-6 lg:px-10 py-5 flex flex-wrap items-baseline gap-x-6 gap-y-2">
        <div className="text-[10px] num sc text-stone-500">scan_group</div>
        <h1 className="text-2xl lg:text-3xl font-light tracking-tight text-stone-100">{data?.name?.replace(/_/g, " ") ?? scanName}</h1>
        {data && (
          <div className="ml-auto text-[11px] num text-stone-500">
            {data.runs.length} pts · axis: <span className="text-stone-300">{xKey}</span>{xUnit && <> [{xUnit}]</>}
          </div>
        )}
      </header>

      {error && <div className="px-10 py-6 text-sm num text-red-300">error: {error}</div>}
      {!data && !error && <div className="px-10 py-12 text-stone-500 num sc text-xs animate-pulse">loading…</div>}

      {data && (
        <>
          {data.description && <p className="px-6 lg:px-10 py-4 text-[13px] text-stone-400 italic max-w-3xl leading-relaxed">{data.description}</p>}

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-px bg-stone-800/40 stagger">
            <Panel className="lg:col-span-4" title="m_top final" subtitle={`spin top vs ${xKey}`}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={rows} margin={{ top: 8, right: 12, left: -8, bottom: 8 }}>
                  <CartesianGrid stroke={GRID} strokeDasharray="2 4" />
                  <XAxis dataKey="x" type="number" domain={["dataMin", "dataMax"]} tickFormatter={(v) => fmt(v, 1)} stroke={AXIS} label={{ value: xUnit || xKey, position: "insideBottom", offset: -4, fill: AXIS, fontSize: 9, fontStyle: "italic" }} />
                  <YAxis stroke={AXIS} tickFormatter={(v) => fmt(v, 2)} domain={["auto", "auto"]} />
                  <Tooltip content={<ChartTooltip unit={xUnit} />} />
                  <ReferenceLine y={0} stroke={AXIS} strokeOpacity={0.4} />
                  <Line type="monotone" dataKey="m_top_final" stroke={SPIN} strokeWidth={1.6} dot={{ r: 3, fill: SPIN, stroke: "#0e0f12", strokeWidth: 0.8 }} activeDot={{ r: 5 }} isAnimationActive={false} name="m_top final" connectNulls />
                </LineChart>
              </ResponsiveContainer>
            </Panel>

            <Panel className="lg:col-span-4" title="L_z max" subtitle={`orbital peak vs ${xKey}`}>
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={rows} margin={{ top: 8, right: 12, left: -8, bottom: 8 }}>
                  <CartesianGrid stroke={GRID} strokeDasharray="2 4" />
                  <XAxis dataKey="x" type="number" domain={["dataMin", "dataMax"]} tickFormatter={(v) => fmt(v, 1)} stroke={AXIS} label={{ value: xUnit || xKey, position: "insideBottom", offset: -4, fill: AXIS, fontSize: 9, fontStyle: "italic" }} />
                  <YAxis stroke={AXIS} tickFormatter={(v) => fmt(v, 2)} domain={["auto", "auto"]} />
                  <Tooltip content={<ChartTooltip unit={xUnit} />} />
                  <ReferenceLine y={0} stroke={AXIS} strokeOpacity={0.4} />
                  <Line type="monotone" dataKey="Lz_max" stroke={ORBITAL} strokeWidth={1.6} dot={{ r: 3, fill: ORBITAL, stroke: "#0e0f12", strokeWidth: 0.8 }} activeDot={{ r: 5 }} isAnimationActive={false} name="L_z max" connectNulls />
                </LineChart>
              </ResponsiveContainer>
            </Panel>

            <Panel className="lg:col-span-4" title="Larmor phase" subtitle={`p · F · dt per point`}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={rows} margin={{ top: 8, right: 12, left: -8, bottom: 8 }}>
                  <CartesianGrid stroke={GRID} strokeDasharray="2 4" vertical={false} />
                  <XAxis dataKey="x" type="number" domain={["dataMin", "dataMax"]} tickFormatter={(v) => fmt(v, 1)} stroke={AXIS} label={{ value: xUnit || xKey, position: "insideBottom", offset: -4, fill: AXIS, fontSize: 9, fontStyle: "italic" }} />
                  <YAxis stroke={AXIS} tickFormatter={(v) => fmt(v, 1)} />
                  <Tooltip content={<ChartTooltip unit={xUnit} />} />
                  <ReferenceLine y={Math.PI} stroke={REGIME.danger} strokeDasharray="3 3" strokeOpacity={0.6} label={{ value: "π", fill: REGIME.danger, fontSize: 9, position: "right" }} />
                  <Bar dataKey="larmor" name="Larmor" isAnimationActive={false}>
                    {rows.map((r, i) => <Cell key={i} fill={r.color} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </Panel>
          </div>

          <section className="px-6 lg:px-10 py-8">
            <div className="sc num text-[10px] text-stone-500 mb-3 flex flex-wrap gap-x-4 gap-y-1">
              <span>all runs · {data.runs.length} points</span>
              {(["safe", "marginal", "stiff", "danger"] as const).map((r) => (
                <span key={r} className="flex items-center gap-1.5"><span className="inline-block w-2 h-2" style={{ background: REGIME[r] }} />{r}</span>
              ))}
            </div>
            <div className="overflow-x-auto border border-stone-800">
              <table className="w-full text-[11px] num">
                <thead className="bg-stone-900/80 text-stone-400 sc text-[10px]">
                  <tr>
                    {["param", "display", "m_top init", "m_top final", "L_z max", "L_z final", "F_z final", "norm dev", "Larmor", "regime"].map((h) => (
                      <th key={h} className="px-2 py-2 text-right font-normal">{h}</th>
                    ))}
                    <th className="px-3 py-2 text-left font-normal">point_dir</th>
                  </tr>
                </thead>
                <tbody>
                  {data.runs.map((r, i) => {
                    const reg = regimeOf(r.larmor_phase_per_step);
                    return (
                      <tr key={i} className="border-t border-stone-800 hover:bg-stone-900/40 transition-colors">
                        <Td>{fmt(r.value, 3)}</Td>
                        <Td>{fmt(r.value_display, 2)}</Td>
                        <Td>{fmt(r.m_top_init)}</Td>
                        <Td className="text-amber-200">{fmt(r.m_top_final)}</Td>
                        <Td className="text-emerald-300">{fmt(r.Lz_max, 3)}</Td>
                        <Td className="text-stone-400">{fmt(r.Lz_final, 3)}</Td>
                        <Td className="text-sky-300">{fmt(r.Fz_final, 3)}</Td>
                        <Td className="text-stone-500">{fmt(r.norm_max_dev, 1)}</Td>
                        <Td><span style={{ color: reg.color }}>{fmt(r.larmor_phase_per_step, 1)}</span></Td>
                        <Td className="sc text-[10px]" style={{ color: reg.color }}>{reg.label}</Td>
                        <td className="px-3 py-1.5 text-left text-stone-500 max-w-xs truncate">
                          {r.point_dir}
                          {!r.completed && <span className="ml-2 text-amber-400 text-[9px] sc">pending</span>}
                        </td>
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

function Td({ children, className = "", style }: { children: React.ReactNode; className?: string; style?: React.CSSProperties }) {
  return <td className={`px-2 py-1.5 text-right text-stone-300 ${className}`} style={style}>{children}</td>;
}
