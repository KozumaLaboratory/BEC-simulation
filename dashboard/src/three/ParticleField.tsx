import { useEffect, useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import type { VectorField3D, Density3D, VortexLinesResponse } from '@/api'

export type SeedMode = 'density' | 'vortex_shell'

export interface ParticleParams {
  count: number
  trailLength: number // number of trail samples per particle
  speed: number // world-space units per second
  lifespan: number // seconds
  color: string
  densityThreshold: number // fraction of max density for seeding
  seedMode: SeedMode
  vortexShellRadius: number
  // When true, project v_s onto the azimuthal direction around the nearest
  // vortex-line axis before advecting. The "real physics, radial part
  // removed" path — produces clean orbital motion.
  azimuthalOnly: boolean
}

interface Props {
  field: VectorField3D
  density: Density3D
  densityMax: number
  params: ParticleParams
  vortexLines?: VortexLinesResponse // required when seedMode='vortex_shell'
}

// Advects N particles along the chosen velocity field and renders each
// particle as a short polyline trail (last L positions). Trails make
// rotational flow read instantly where individual points can't.
//
// Storage layout: positions[i * L * 3 + t * 3 + k]
//   i ∈ [0, count), t ∈ [0, trailLength), k ∈ {x,y,z}
//   t = 0 is the newest head position, t = L-1 is the oldest.
// Each frame we shift t back by one (memmove-style) and write the new
// head. Index buffer wires (t, t+1) pairs into LineSegments — built
// once, never rebuilt per frame.
export function ParticleField({
  field,
  density,
  densityMax,
  params,
  vortexLines,
}: Props) {
  const lineRef = useRef<THREE.LineSegments>(null!)

  const { count, trailLength } = params
  const vertsPerTrail = Math.max(2, trailLength)

  // Peak |v| over the whole field. Velocities are divided by this so the
  // user-facing `speed` control is "box fraction per second" regardless of
  // the absolute magnitude of j or v_s (which can vary by 10+ orders of
  // magnitude between ground states and dynamics snapshots).
  const invPeakMag = useMemo(() => {
    const d = field.data
    const n = field.nx * field.ny * field.nz
    let peak = 0
    for (let i = 0; i < n; i++) {
      const m = d[i * 4 + 3]
      if (m > peak) peak = m
    }
    return peak > 0 ? 1 / peak : 0
  }, [field])

  // Precompute one sample per vortex-line point: centre in render space and
  // local tangent direction. Needed only when azimuthalOnly is engaged, but
  // the computation is cheap enough (a couple of hundred samples at most)
  // that we keep it always ready.
  const vortexSamples = useMemo(() => {
    if (!vortexLines || vortexLines.lines.length === 0) return null
    const [Lx, Ly, Lz] = vortexLines.box
    const out: Array<{
      cx: number; cy: number; cz: number
      tx: number; ty: number; tz: number
    }> = []
    for (const line of vortexLines.lines) {
      const n = line.points.length
      for (let i = 0; i < n; i++) {
        const p = line.points[i]
        const prev = line.points[Math.max(0, i - 1)]
        const next = line.points[Math.min(n - 1, i + 1)]
        let tx = (next[0] - prev[0]) / Lx
        let ty = (next[1] - prev[1]) / Ly
        let tz = (next[2] - prev[2]) / Lz
        const tn = Math.hypot(tx, ty, tz)
        if (tn < 1e-8) {
          tx = 0; ty = 0; tz = 1
        } else {
          tx /= tn; ty /= tn; tz /= tn
        }
        out.push({
          cx: p[0] / Lx, cy: p[1] / Ly, cz: p[2] / Lz,
          tx, ty, tz,
        })
      }
    }
    return out
  }, [vortexLines])

  const positions = useMemo(
    () => new Float32Array(count * vertsPerTrail * 3),
    [count, vertsPerTrail],
  )
  const colors = useMemo(
    () => new Float32Array(count * vertsPerTrail * 4),
    [count, vertsPerTrail],
  )
  const ages = useMemo(() => new Float32Array(count), [count])

  const indices = useMemo(() => {
    const arr = new Uint32Array(count * (vertsPerTrail - 1) * 2)
    let k = 0
    for (let p = 0; p < count; p++) {
      const base = p * vertsPerTrail
      for (let t = 0; t < vertsPerTrail - 1; t++) {
        arr[k++] = base + t
        arr[k++] = base + t + 1
      }
    }
    return arr
  }, [count, vertsPerTrail])

  // Pre-bake per-trail-position alpha ramp (head bright, tail faint).
  // Colors are constant per vertex-in-trail, so bake once. Fade curve is
  // `1-t` (linear) rather than the former α² so the whole spiral tail stays
  // visible instead of blending into the background after ~25 % of the
  // trail length.
  useEffect(() => {
    const c = new THREE.Color(params.color)
    for (let i = 0; i < count; i++) {
      for (let t = 0; t < vertsPerTrail; t++) {
        const a = 1 - t / (vertsPerTrail - 1)
        const idx = (i * vertsPerTrail + t) * 4
        colors[idx] = c.r * (0.4 + 0.6 * a) // head brighter than tail for extra contrast
        colors[idx + 1] = c.g * (0.4 + 0.6 * a)
        colors[idx + 2] = c.b * (0.4 + 0.6 * a)
        colors[idx + 3] = a
      }
    }
    const lines = lineRef.current
    if (lines) {
      const attr = lines.geometry.attributes.color as THREE.BufferAttribute
      attr.needsUpdate = true
    }
  }, [params.color, count, vertsPerTrail, colors])

  useEffect(() => {
    for (let i = 0; i < count; i++) {
      seedByMode(
        positions,
        ages,
        i,
        vertsPerTrail,
        density,
        densityMax,
        params.densityThreshold,
        params.seedMode,
        vortexLines,
        params.vortexShellRadius,
      )
    }
    const lines = lineRef.current
    if (lines) {
      const attr = lines.geometry.attributes.position as THREE.BufferAttribute
      attr.needsUpdate = true
    }
  }, [
    positions,
    ages,
    count,
    vertsPerTrail,
    density,
    densityMax,
    params.densityThreshold,
    params.seedMode,
    vortexLines,
    params.vortexShellRadius,
  ])

  useFrame((_, deltaRaw) => {
    const dt = Math.min(deltaRaw, 1 / 30)
    const lines = lineRef.current
    if (!lines) return

    const fNx = field.nx,
      fNy = field.ny,
      fNz = field.nz,
      fData = field.data
    const speed = params.speed
    const life = params.lifespan

    for (let i = 0; i < count; i++) {
      const trailBase = i * vertsPerTrail * 3

      // Shift tail back: trail[t] ← trail[t-1] for t = L-1 .. 1
      for (let t = vertsPerTrail - 1; t > 0; t--) {
        const dst = trailBase + t * 3
        const src = trailBase + (t - 1) * 3
        positions[dst] = positions[src]
        positions[dst + 1] = positions[src + 1]
        positions[dst + 2] = positions[src + 2]
      }

      // Advance head (t=0) by RK2. We integrate along the unit-direction
      // v̂ = v/|v| rather than v itself, so every particle draws a curve of
      // the same arc-length per frame regardless of where it is in the
      // field — this is the only way a slow-moving region produces a
      // trail of comparable length to the core. Magnitude information is
      // recovered by coloring the head by |v|.
      const hx = positions[trailBase]
      const hy = positions[trailBase + 1]
      const hz = positions[trailBase + 2]

      let stepX: number, stepY: number, stepZ: number, vmagAtHead: number

      if (params.azimuthalOnly && vortexSamples && vortexSamples.length > 0) {
        // Project the local v_s onto the azimuthal direction around the
        // nearest vortex-line axis. Radial and axial parts are discarded,
        // so the particle orbits the core on a closed curve rather than
        // spiralling in/out with the breathing component.
        const dir = azimuthalDirection(hx, hy, hz, vortexSamples)
        const v = sampleVector(fData, fNx, fNy, fNz, hx, hy, hz)
        const vAzi = v[0] * dir[0] + v[1] * dir[1] + v[2] * dir[2]
        const signedSpeed = speed * dt * Math.sign(vAzi || 1)
        stepX = dir[0] * signedSpeed
        stepY = dir[1] * signedSpeed
        stepZ = dir[2] * signedSpeed
        vmagAtHead = v[3]
      } else {
        const v1 = sampleVector(fData, fNx, fNy, fNz, hx, hy, hz)
        const m1 = v1[3] > 1e-30 ? 1 / v1[3] : 0
        const stepHalf = speed * dt * 0.5
        const mx = hx + v1[0] * m1 * stepHalf
        const my = hy + v1[1] * m1 * stepHalf
        const mz = hz + v1[2] * m1 * stepHalf
        const v2 = sampleVector(fData, fNx, fNy, fNz, mx, my, mz)
        const m2 = v2[3] > 1e-30 ? 1 / v2[3] : 0
        const step_ = speed * dt
        stepX = v2[0] * m2 * step_
        stepY = v2[1] * m2 * step_
        stepZ = v2[2] * m2 * step_
        vmagAtHead = v2[3]
      }

      const nx = hx + stepX
      const ny = hy + stepY
      const nz = hz + stepZ
      positions[trailBase] = nx
      positions[trailBase + 1] = ny
      positions[trailBase + 2] = nz
      ages[i] += dt

      // Respawn conditions. We used to also kill particles in low-density
      // regions, but that makes vortex cores (|ψ|² → 0) invisible —
      // streamlines got truncated right where the interesting circulation
      // lives. Keep only lifespan, out-of-bounds, and "flow is essentially
      // zero here" (vNorm < 1e-4 relative to field peak).
      const vNorm = vmagAtHead * invPeakMag
      if (
        ages[i] > life ||
        nx < -0.5 || nx > 0.5 ||
        ny < -0.5 || ny > 0.5 ||
        nz < -0.5 || nz > 0.5 ||
        vNorm < 1e-4
      ) {
        seedByMode(
          positions,
          ages,
          i,
          vertsPerTrail,
          density,
          densityMax,
          params.densityThreshold,
          params.seedMode,
          vortexLines,
          params.vortexShellRadius,
        )
      }
    }

    const attr = lines.geometry.attributes.position as THREE.BufferAttribute
    attr.needsUpdate = true
  })

  const material = useMemo(
    () =>
      new THREE.LineBasicMaterial({
        vertexColors: true,
        transparent: true,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      }),
    [],
  )

  return (
    <lineSegments ref={lineRef} material={material} frustumCulled={false}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          args={[positions, 3]}
          usage={THREE.DynamicDrawUsage}
        />
        <bufferAttribute
          attach="attributes-color"
          args={[colors, 4]}
          usage={THREE.StaticDrawUsage}
        />
        <bufferAttribute attach="index" args={[indices, 1]} />
      </bufferGeometry>
    </lineSegments>
  )
}

// Dispatch to the appropriate seeder. Both paths collapse the entire
// trail to the new head position so a new line starts as a point and
// grows once the actual v_s field has carried the particle somewhere.
function seedByMode(
  positions: Float32Array,
  ages: Float32Array,
  i: number,
  trailLength: number,
  density: Density3D,
  densityMax: number,
  thresholdFrac: number,
  mode: SeedMode,
  vortexLines: VortexLinesResponse | undefined,
  shellRadius: number,
) {
  if (mode === 'vortex_shell' && vortexLines && vortexLines.lines.length > 0) {
    seedOnVortexShell(positions, ages, i, trailLength, vortexLines, shellRadius)
    return
  }
  seedCollapse(positions, ages, i, trailLength, density, densityMax, thresholdFrac)
}

// Seed one particle in a thin cylindrical shell perpendicular to a random
// vortex-line segment. Because the shell sits where v_s(r) is actually
// strongest and nearly purely azimuthal, the subsequent RK2 advection on
// the REAL velocity field produces particles that visibly orbit the core —
// no synthetic / procedural motion involved.
function seedOnVortexShell(
  positions: Float32Array,
  ages: Float32Array,
  i: number,
  trailLength: number,
  vortexLines: VortexLinesResponse,
  shellRadius: number,
) {
  const [Lx, Ly, Lz] = vortexLines.box
  const nLines = vortexLines.lines.length
  const line = vortexLines.lines[Math.floor(Math.random() * nLines)]
  const nPts = line.points.length
  const pi = Math.floor(Math.random() * nPts)
  const p = line.points[pi]
  // Local tangent from neighbouring point (if available).
  const pNext = line.points[Math.min(nPts - 1, pi + 1)]
  const pPrev = line.points[Math.max(0, pi - 1)]
  const tx = (pNext[0] - pPrev[0]) / Lx
  const ty = (pNext[1] - pPrev[1]) / Ly
  const tz = (pNext[2] - pPrev[2]) / Lz
  let tlen = Math.hypot(tx, ty, tz)
  if (tlen < 1e-6) {
    // Degenerate (shouldn't happen for real lines with >=2 points). Fall
    // back to z-axis.
    tlen = 1
  }
  const txn = tx / tlen,
    tyn = ty / tlen,
    tzn = tz / tlen
  // Pick e1 perpendicular to tangent.
  const helperZ = Math.abs(tzn) < 0.9
  const hx = helperZ ? 0 : 1
  const hy = 0
  const hz = helperZ ? 1 : 0
  const e1x = tyn * hz - tzn * hy
  const e1y = tzn * hx - txn * hz
  const e1z = txn * hy - tyn * hx
  const e1n = Math.hypot(e1x, e1y, e1z) || 1
  const e1xN = e1x / e1n,
    e1yN = e1y / e1n,
    e1zN = e1z / e1n
  const e2x = tyn * e1zN - tzn * e1yN
  const e2y = tzn * e1xN - txn * e1zN
  const e2z = txn * e1yN - tyn * e1xN
  const theta = Math.random() * Math.PI * 2
  // Slight jitter around the shell radius so the particles don't clump onto
  // one ring.
  const r = shellRadius * (0.8 + Math.random() * 0.4)
  const cx = Math.cos(theta)
  const sn = Math.sin(theta)
  const x = p[0] / Lx + r * (cx * e1xN + sn * e2x)
  const y = p[1] / Ly + r * (cx * e1yN + sn * e2y)
  const z = p[2] / Lz + r * (cx * e1zN + sn * e2z)
  const base = i * trailLength * 3
  for (let t = 0; t < trailLength; t++) {
    positions[base + t * 3] = x
    positions[base + t * 3 + 1] = y
    positions[base + t * 3 + 2] = z
  }
  ages[i] = Math.random() * 0.8
}

// Given a particle position and the pre-computed vortex-line samples,
// find the nearest sample and return the unit azimuthal direction at that
// sample for this particle's position. "Azimuthal" = tangent × r̂ where r̂
// is the unit radial offset from the line axis, projected to the plane
// perpendicular to the tangent.
function azimuthalDirection(
  px: number, py: number, pz: number,
  samples: Array<{ cx: number; cy: number; cz: number; tx: number; ty: number; tz: number }>,
): [number, number, number] {
  let bestD = Infinity
  let bestIdx = 0
  for (let i = 0; i < samples.length; i++) {
    const s = samples[i]
    const d = (px - s.cx) ** 2 + (py - s.cy) ** 2 + (pz - s.cz) ** 2
    if (d < bestD) {
      bestD = d
      bestIdx = i
    }
  }
  const s = samples[bestIdx]
  const dx = px - s.cx, dy = py - s.cy, dz = pz - s.cz
  // Remove axial component: r_perp = d − (d·t) t
  const dDotT = dx * s.tx + dy * s.ty + dz * s.tz
  const rx = dx - dDotT * s.tx
  const ry = dy - dDotT * s.ty
  const rz = dz - dDotT * s.tz
  const rn = Math.hypot(rx, ry, rz)
  if (rn < 1e-9) {
    // Sitting on the axis — pick an arbitrary perpendicular.
    if (Math.abs(s.tz) < 0.9) return [-s.ty, s.tx, 0]
    return [0, -s.tz, s.ty]
  }
  const rxh = rx / rn, ryh = ry / rn, rzh = rz / rn
  // azi = t × r̂
  const ax = s.ty * rzh - s.tz * ryh
  const ay = s.tz * rxh - s.tx * rzh
  const az = s.tx * ryh - s.ty * rxh
  const an = Math.hypot(ax, ay, az) || 1
  return [ax / an, ay / an, az / an]
}

// Seed one particle in a density-weighted random location, collapsing its
// entire trail to the new head position so the line renders as a point
// until it accumulates movement.
function seedCollapse(
  positions: Float32Array,
  ages: Float32Array,
  i: number,
  trailLength: number,
  density: Density3D,
  densityMax: number,
  thresholdFrac: number,
) {
  const thresh = densityMax * thresholdFrac
  let x = 0,
    y = 0,
    z = 0,
    found = false
  for (let attempt = 0; attempt < 20; attempt++) {
    const cx = Math.random() - 0.5
    const cy = Math.random() - 0.5
    const cz = Math.random() - 0.5
    const d = sampleDensity(density.density, density.nx, density.ny, density.nz, cx, cy, cz)
    if (d > thresh) {
      x = cx
      y = cy
      z = cz
      found = true
      break
    }
  }
  if (!found) {
    x = (Math.random() - 0.5) * 0.3
    y = (Math.random() - 0.5) * 0.3
    z = (Math.random() - 0.5) * 0.3
  }
  const base = i * trailLength * 3
  for (let t = 0; t < trailLength; t++) {
    positions[base + t * 3] = x
    positions[base + t * 3 + 1] = y
    positions[base + t * 3 + 2] = z
  }
  ages[i] = Math.random() * 0.8
}

function sampleDensity(
  data: Float32Array,
  nx: number,
  ny: number,
  nz: number,
  x: number,
  y: number,
  z: number,
): number {
  const u = (x + 0.5) * nx - 0.5
  const v = (y + 0.5) * ny - 0.5
  const w = (z + 0.5) * nz - 0.5
  const ix = Math.floor(u),
    iy = Math.floor(v),
    iz = Math.floor(w)
  if (ix < 0 || ix >= nx - 1 || iy < 0 || iy >= ny - 1 || iz < 0 || iz >= nz - 1)
    return 0
  const fx = u - ix,
    fy = v - iy,
    fz = w - iz
  const s = nx * ny
  const i000 = ix + iy * nx + iz * s
  const c00 = data[i000] * (1 - fx) + data[i000 + 1] * fx
  const c10 = data[i000 + nx] * (1 - fx) + data[i000 + nx + 1] * fx
  const c01 = data[i000 + s] * (1 - fx) + data[i000 + s + 1] * fx
  const c11 = data[i000 + nx + s] * (1 - fx) + data[i000 + nx + s + 1] * fx
  const c0 = c00 * (1 - fy) + c10 * fy
  const c1 = c01 * (1 - fy) + c11 * fy
  return c0 * (1 - fz) + c1 * fz
}

function sampleVector(
  data: Float32Array,
  nx: number,
  ny: number,
  nz: number,
  x: number,
  y: number,
  z: number,
): [number, number, number, number] {
  const u = (x + 0.5) * nx - 0.5
  const v = (y + 0.5) * ny - 0.5
  const w = (z + 0.5) * nz - 0.5
  const ix = Math.floor(u),
    iy = Math.floor(v),
    iz = Math.floor(w)
  if (ix < 0 || ix >= nx - 1 || iy < 0 || iy >= ny - 1 || iz < 0 || iz >= nz - 1)
    return [0, 0, 0, 0]
  const fx = u - ix,
    fy = v - iy,
    fz = w - iz
  const rowStride = nx
  const sliceStride = nx * ny
  const at = (ix_: number, iy_: number, iz_: number, ch: number) =>
    data[(ix_ + iy_ * rowStride + iz_ * sliceStride) * 4 + ch]
  let vx = 0,
    vy = 0,
    vz = 0,
    mag = 0
  for (let dx = 0; dx <= 1; dx++) {
    for (let dy = 0; dy <= 1; dy++) {
      for (let dz = 0; dz <= 1; dz++) {
        const wx = dx === 0 ? 1 - fx : fx
        const wy = dy === 0 ? 1 - fy : fy
        const wz = dz === 0 ? 1 - fz : fz
        const wt = wx * wy * wz
        vx += wt * at(ix + dx, iy + dy, iz + dz, 0)
        vy += wt * at(ix + dx, iy + dy, iz + dz, 1)
        vz += wt * at(ix + dx, iy + dy, iz + dz, 2)
        mag += wt * at(ix + dx, iy + dy, iz + dz, 3)
      }
    }
  }
  return [vx, vy, vz, mag]
}
