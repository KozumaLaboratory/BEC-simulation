import { useEffect, useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import type { VectorField3D, Density3D } from '@/api'

export interface ParticleParams {
  count: number
  trailLength: number // number of trail samples per particle
  speed: number // world-space units per second
  lifespan: number // seconds
  color: string
  densityThreshold: number // fraction of max density for seeding
}

interface Props {
  field: VectorField3D
  density: Density3D
  densityMax: number
  params: ParticleParams
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
export function ParticleField({ field, density, densityMax, params }: Props) {
  const lineRef = useRef<THREE.LineSegments>(null!)

  const { count, trailLength } = params
  const vertsPerTrail = Math.max(2, trailLength)

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
  // Colors are constant per vertex-in-trail, so bake once.
  useEffect(() => {
    const c = new THREE.Color(params.color)
    for (let i = 0; i < count; i++) {
      for (let t = 0; t < vertsPerTrail; t++) {
        const a = 1 - t / (vertsPerTrail - 1)
        const idx = (i * vertsPerTrail + t) * 4
        colors[idx] = c.r
        colors[idx + 1] = c.g
        colors[idx + 2] = c.b
        colors[idx + 3] = a * a // sharper fade
      }
    }
    const lines = lineRef.current
    if (lines) {
      const attr = lines.geometry.attributes.color as THREE.BufferAttribute
      attr.needsUpdate = true
    }
  }, [params.color, count, vertsPerTrail, colors])

  useEffect(() => {
    // Seed: collapse every particle's trail to a single density-weighted point.
    for (let i = 0; i < count; i++) {
      seedCollapse(positions, ages, i, vertsPerTrail, density, densityMax, params.densityThreshold)
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
  ])

  useFrame((_, deltaRaw) => {
    const dt = Math.min(deltaRaw, 1 / 30)
    const lines = lineRef.current
    if (!lines) return

    const fNx = field.nx,
      fNy = field.ny,
      fNz = field.nz,
      fData = field.data
    const dNx = density.nx,
      dNy = density.ny,
      dNz = density.nz
    const dens = density.density
    const densThresh = densityMax * params.densityThreshold
    const minDensKeep = densThresh * 0.3
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

      // Advance head (t=0) by RK2.
      const hx = positions[trailBase]
      const hy = positions[trailBase + 1]
      const hz = positions[trailBase + 2]
      const v1 = sampleVector(fData, fNx, fNy, fNz, hx, hy, hz)
      const mx = hx + v1[0] * speed * dt * 0.5
      const my = hy + v1[1] * speed * dt * 0.5
      const mz = hz + v1[2] * speed * dt * 0.5
      const v2 = sampleVector(fData, fNx, fNy, fNz, mx, my, mz)
      const nx = hx + v2[0] * speed * dt
      const ny = hy + v2[1] * speed * dt
      const nz = hz + v2[2] * speed * dt
      positions[trailBase] = nx
      positions[trailBase + 1] = ny
      positions[trailBase + 2] = nz
      ages[i] += dt

      // Respawn conditions (same as point version): collapse trail to new seed.
      const vmag = v2[3]
      if (
        ages[i] > life ||
        nx < -0.5 || nx > 0.5 ||
        ny < -0.5 || ny > 0.5 ||
        nz < -0.5 || nz > 0.5 ||
        vmag < 1e-20 ||
        sampleDensity(dens, dNx, dNy, dNz, nx, ny, nz) < minDensKeep
      ) {
        seedCollapse(positions, ages, i, vertsPerTrail, density, densityMax, params.densityThreshold)
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
