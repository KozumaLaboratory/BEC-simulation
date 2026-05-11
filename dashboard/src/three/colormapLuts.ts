// Pre-computed 256-stop colormap LUTs sampled from matplotlib. Stored as
// flat RGBA Uint8Arrays so they map directly to a 256×1 DataTexture.
//
// `viridis` is the perceptually uniform default for densities; `phase` is
// a cyclic hue ramp (HSL) for arg(ψ). 256 stops are well above the eye's
// discriminability — the textureSample bilinearly interpolates between
// adjacent stops anyway, so values land smoothly.

import * as THREE from 'three'

function makeLut(stops: ReadonlyArray<readonly [number, number, number]>): Uint8Array {
  const out = new Uint8Array(256 * 4)
  for (let i = 0; i < 256; i++) {
    const t = i / 255
    const seg = t * (stops.length - 1)
    const lo = Math.floor(seg)
    const hi = Math.min(lo + 1, stops.length - 1)
    const f = seg - lo
    const a = stops[lo]
    const b = stops[hi]
    out[i * 4 + 0] = Math.round(255 * (a[0] + (b[0] - a[0]) * f))
    out[i * 4 + 1] = Math.round(255 * (a[1] + (b[1] - a[1]) * f))
    out[i * 4 + 2] = Math.round(255 * (a[2] + (b[2] - a[2]) * f))
    out[i * 4 + 3] = 255
  }
  return out
}

// 16-stop viridis sampling — interpolated up to 256 by makeLut(). Source:
// matplotlib viridis (CC0).
const VIRIDIS_STOPS: ReadonlyArray<readonly [number, number, number]> = [
  [0.267, 0.005, 0.329],
  [0.282, 0.094, 0.418],
  [0.279, 0.175, 0.483],
  [0.260, 0.251, 0.521],
  [0.231, 0.318, 0.546],
  [0.197, 0.383, 0.553],
  [0.168, 0.438, 0.557],
  [0.143, 0.495, 0.557],
  [0.121, 0.554, 0.547],
  [0.121, 0.612, 0.524],
  [0.166, 0.672, 0.487],
  [0.265, 0.728, 0.434],
  [0.405, 0.781, 0.366],
  [0.585, 0.823, 0.287],
  [0.781, 0.860, 0.205],
  [0.993, 0.906, 0.144],
]

// Cyclic HSL colormap for phase ∈ [-π, π]. Identical scheme to the old
// Plotly `PHASE_COLORSCALE`.
function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  const c = (1 - Math.abs(2 * l - 1)) * s
  const hp = h / 60
  const x = c * (1 - Math.abs((hp % 2) - 1))
  let r = 0, g = 0, b = 0
  if (hp < 1) [r, g, b] = [c, x, 0]
  else if (hp < 2) [r, g, b] = [x, c, 0]
  else if (hp < 3) [r, g, b] = [0, c, x]
  else if (hp < 4) [r, g, b] = [0, x, c]
  else if (hp < 5) [r, g, b] = [x, 0, c]
  else [r, g, b] = [c, 0, x]
  const m = l - c / 2
  return [r + m, g + m, b + m]
}

const PHASE_STOPS: ReadonlyArray<readonly [number, number, number]> = (() => {
  const N = 24
  const out: Array<[number, number, number]> = []
  for (let i = 0; i <= N; i++) {
    const h = (i / N) * 360
    out.push(hslToRgb(h, 0.8, 0.55))
  }
  return out
})()

export type ColormapName = 'viridis' | 'phase'

const CACHE: Partial<Record<ColormapName, THREE.DataTexture>> = {}

export function getLutTexture(name: ColormapName): THREE.DataTexture {
  const cached = CACHE[name]
  if (cached) return cached
  const stops = name === 'phase' ? PHASE_STOPS : VIRIDIS_STOPS
  const tex = new THREE.DataTexture(makeLut(stops), 256, 1, THREE.RGBAFormat, THREE.UnsignedByteType)
  tex.minFilter = THREE.LinearFilter
  tex.magFilter = THREE.LinearFilter
  tex.wrapS = THREE.ClampToEdgeWrapping
  tex.wrapT = THREE.ClampToEdgeWrapping
  tex.needsUpdate = true
  CACHE[name] = tex
  return tex
}
