import { useEffect, useMemo, useState } from 'react'
import { parse } from 'yaml'
import { Card, CardContent } from '@/components/ui/card'

interface Props {
  yaml: string
}

// YAML viewer with lazy Shiki highlighting + derived-value side panel.
// Shiki lives in a separate async chunk so the initial bundle never pays
// for the highlighter grammar (+theme) files unless the user actually
// opens this tab.
export function ConfigViewer({ yaml: src }: Props) {
  const [html, setHtml] = useState<string | null>(null)
  const derived = useMemo(() => deriveValues(src), [src])

  useEffect(() => {
    if (!src) {
      setHtml(null)
      return
    }
    let cancelled = false
    import('shiki').then(async ({ createHighlighter }) => {
      const hl = await createHighlighter({
        themes: ['github-dark'],
        langs: ['yaml'],
      })
      const out = hl.codeToHtml(src, { lang: 'yaml', theme: 'github-dark' })
      if (!cancelled) setHtml(out)
    })
    return () => {
      cancelled = true
    }
  }, [src])

  if (!src) {
    return (
      <Card>
        <CardContent className="p-4 text-sm text-muted-foreground">
          (no config)
        </CardContent>
      </Card>
    )
  }

  return (
    <div className="grid grid-cols-1 lg:grid-cols-[1fr_18rem] gap-4">
      <Card>
        <CardContent className="p-0">
          <div className="max-h-[700px] overflow-auto text-xs">
            {html ? (
              <div
                className="shiki-container"
                // Shiki output is trusted — it's server-side or our own
                // local YAML text passed through a known highlighter.
                dangerouslySetInnerHTML={{ __html: html }}
              />
            ) : (
              <pre className="p-3 whitespace-pre-wrap">{src}</pre>
            )}
          </div>
        </CardContent>
      </Card>
      <Card>
        <CardContent className="p-4 space-y-2 text-xs">
          <div className="text-primary font-medium text-sm mb-1">Derived</div>
          {derived.length === 0 ? (
            <div className="text-muted-foreground">
              (couldn't parse pipeline.0.ground_state)
            </div>
          ) : (
            <dl className="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 tabular-nums">
              {derived.map(([k, v]) => (
                <DerivedRow key={k} name={k} value={v} />
              ))}
            </dl>
          )}
        </CardContent>
      </Card>
    </div>
  )
}

function DerivedRow({ name, value }: { name: string; value: string }) {
  return (
    <>
      <dt className="text-muted-foreground font-mono">{name}</dt>
      <dd className="text-right">{value}</dd>
    </>
  )
}

// Parse the YAML and derive a handful of quantities the user would
// otherwise compute by hand from config + physics constants. Best-effort;
// returns an empty list if the document doesn't look like our schema.
function deriveValues(src: string): Array<[string, string]> {
  if (!src) return []
  let cfg: unknown
  try {
    cfg = parse(src)
  } catch {
    return []
  }
  const gs = findGroundState(cfg)
  if (!gs) return []

  const out: Array<[string, string]> = []
  const inter = (gs as { interactions?: Record<string, unknown> }).interactions ?? {}
  const N = numeric(inter.N_atoms)
  const omega = numeric(inter.omega_ref)
  const c0 = numeric(inter.c_total ?? inter.c0)
  const c1_ratio = numeric(inter.c1_ratio)
  const ddi = (gs as { ddi?: Record<string, unknown> }).ddi
  const c_dd = ddi && typeof ddi === 'object' ? numeric((ddi as Record<string, unknown>).c_dd) : null
  const grid = (gs as { grid?: Record<string, unknown> }).grid
  const box = grid && Array.isArray((grid as Record<string, unknown>).box)
    ? ((grid as Record<string, unknown>).box as unknown[]).map((x) => numeric(x))
    : null
  const n = grid && Array.isArray((grid as Record<string, unknown>).n)
    ? ((grid as Record<string, unknown>).n as unknown[]).map((x) => numeric(x))
    : null

  const push = (k: string, v: string | null) => {
    if (v !== null) out.push([k, v])
  }

  if (omega !== null) {
    const a_ho = 1 / Math.sqrt(omega * (2 * Math.PI * 0 + 1)) // ℏ=m=1 in dimensionless
    // a_ho is already 1 in dimensionless units; show physical a_ho from omega_ref (rad/s).
    // a_ho = sqrt(ℏ / (m ω)). For Eu-151 (m ≈ 151 amu): a_ho ~ 0.78 μm at 2π×110 Hz.
    const m_Eu = 151 * 1.66053906660e-27
    const hbar = 1.054571817e-34
    const a_ho_si = Math.sqrt(hbar / (m_Eu * omega))
    push('ω_ref', `${omega.toExponential(3)} rad/s`)
    push('a_ho', `${(a_ho_si * 1e6).toFixed(3)} μm`)
    push('dimless t = 1ms', `${(1e-3 * omega).toFixed(3)} ω⁻¹`)
    void a_ho
  }
  if (N !== null) push('N_atoms', `${N.toExponential(2)}`)
  if (c0 !== null) push('c₀', `${c0.toFixed(2)}`)
  if (c1_ratio !== null) push('c₁ / c₀', `${c1_ratio.toFixed(3)}`)
  if (c_dd !== null) push('c_dd', `${c_dd.toFixed(2)}`)
  if (c0 !== null && c_dd !== null) {
    push('ε_dd = c_dd/c₀', `${(c_dd / c0).toFixed(3)}`)
  }
  if (n) push('grid', `${n.map((x) => (x ?? '?')).join('×')}`)
  if (box) push('box', `${box.map((x) => (typeof x === 'number' ? x.toFixed(1) : '?')).join(' × ')}`)
  if (c0 !== null && N !== null) {
    // Thomas-Fermi radius estimate, dimensionless:
    // R_TF = (15 N c₀ / (8π))^(1/5). Anisotropic traps get a correction we skip.
    const rtf = Math.pow((15 * N * c0) / (8 * Math.PI), 0.2)
    push('R_TF (iso)', `${rtf.toFixed(2)} a_ho`)
  }

  return out
}

function findGroundState(cfg: unknown): Record<string, unknown> | null {
  if (!cfg || typeof cfg !== 'object') return null
  const pipeline = (cfg as { pipeline?: unknown }).pipeline
  if (!Array.isArray(pipeline) || pipeline.length === 0) return null
  const first = pipeline[0]
  if (!first || typeof first !== 'object') return null
  const gs = (first as Record<string, unknown>).ground_state
  return gs && typeof gs === 'object' ? (gs as Record<string, unknown>) : null
}

function numeric(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v
  if (typeof v === 'string') {
    const parsed = Number.parseFloat(v)
    return Number.isFinite(parsed) ? parsed : null
  }
  return null
}
