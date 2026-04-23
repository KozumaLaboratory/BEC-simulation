import { useEffect, useMemo, useRef } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import type { VectorField3D, Density3D } from '@/api'

export interface ParticleParams {
  count: number
  speed: number // world-space units per second
  lifespan: number // seconds
  pointSize: number
  color: string
  densityThreshold: number // fraction of max density for seeding
}

interface Props {
  field: VectorField3D
  density: Density3D
  densityMax: number
  params: ParticleParams
}

// Resample v_mass into world-space [-0.5, 0.5]^3 and advect N particles
// with RK2 on the CPU. For Eu-151 64³ grids and N ≤ 10k this is comfortably
// 60 fps on a modern laptop; once we need >50k or 128³+ fields we can move
// this into a TSL compute kernel sharing the same Data3DTexture.
export function ParticleField({ field, density, densityMax, params }: Props) {
  const pointsRef = useRef<THREE.Points>(null!)

  const { positions, ages } = useMemo(() => {
    const n = params.count
    return {
      positions: new Float32Array(n * 3),
      ages: new Float32Array(n),
    }
  }, [params.count])

  // Seed positions in high-density regions once per field/density change.
  useEffect(() => {
    for (let i = 0; i < params.count; i++) {
      seed(positions, ages, i, density, densityMax, params.densityThreshold)
    }
    if (pointsRef.current) {
      const attr = pointsRef.current.geometry.attributes.position as THREE.BufferAttribute
      attr.needsUpdate = true
    }
  }, [density, densityMax, params.count, params.densityThreshold, positions, ages])

  useFrame((_, deltaRaw) => {
    const dt = Math.min(deltaRaw, 1 / 30) // clamp for long frames
    const mesh = pointsRef.current
    if (!mesh) return
    const fNx = field.nx,
      fNy = field.ny,
      fNz = field.nz,
      stride = field.stride,
      fData = field.data
    const n = params.count
    const speed = params.speed
    const life = params.lifespan
    const dens = density.density
    const dNx = density.nx,
      dNy = density.ny,
      dNz = density.nz
    const densThresh = densityMax * params.densityThreshold

    for (let i = 0; i < n; i++) {
      // RK2: sample v at current pos, at half step, advance full step.
      const px = positions[i * 3]
      const py = positions[i * 3 + 1]
      const pz = positions[i * 3 + 2]

      const v1 = sampleVector(fData, fNx, fNy, fNz, stride, px, py, pz)
      const mx = px + v1[0] * speed * dt * 0.5
      const my = py + v1[1] * speed * dt * 0.5
      const mz = pz + v1[2] * speed * dt * 0.5
      const v2 = sampleVector(fData, fNx, fNy, fNz, stride, mx, my, mz)

      positions[i * 3] = px + v2[0] * speed * dt
      positions[i * 3 + 1] = py + v2[1] * speed * dt
      positions[i * 3 + 2] = pz + v2[2] * speed * dt
      ages[i] += dt

      // Respawn conditions: out of the unit cube, exceeded lifespan, or
      // drifted into a vacuum region where v is meaningless.
      const vmag = v2[3]
      const ax = positions[i * 3],
        ay = positions[i * 3 + 1],
        az = positions[i * 3 + 2]
      if (
        ages[i] > life ||
        ax < -0.5 || ax > 0.5 ||
        ay < -0.5 || ay > 0.5 ||
        az < -0.5 || az > 0.5 ||
        vmag < 1e-20 ||
        sampleDensity(dens, dNx, dNy, dNz, ax, ay, az) < densThresh * 0.3
      ) {
        seed(positions, ages, i, density, densityMax, params.densityThreshold)
      }
    }

    const attr = mesh.geometry.attributes.position as THREE.BufferAttribute
    attr.needsUpdate = true
  })

  const material = useMemo(
    () =>
      new THREE.PointsMaterial({
        size: params.pointSize,
        color: params.color,
        transparent: true,
        opacity: 0.9,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
        sizeAttenuation: true,
      }),
    [params.pointSize, params.color],
  )

  return (
    <points ref={pointsRef} material={material} frustumCulled={false}>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          args={[positions, 3]}
          usage={THREE.DynamicDrawUsage}
        />
      </bufferGeometry>
    </points>
  )
}

// Seed one particle in a density-weighted random location within the cube.
// Simple rejection sampling against the density threshold — fine for the
// one-shot initial fill and the per-frame respawn rate (~few %).
function seed(
  positions: Float32Array,
  ages: Float32Array,
  i: number,
  density: Density3D,
  densityMax: number,
  thresholdFrac: number,
) {
  const thresh = densityMax * thresholdFrac
  for (let attempt = 0; attempt < 20; attempt++) {
    const x = Math.random() - 0.5
    const y = Math.random() - 0.5
    const z = Math.random() - 0.5
    const d = sampleDensity(density.density, density.nx, density.ny, density.nz, x, y, z)
    if (d > thresh) {
      positions[i * 3] = x
      positions[i * 3 + 1] = y
      positions[i * 3 + 2] = z
      ages[i] = Math.random() * 1.0 // stagger ages to avoid synchronized dying
      return
    }
  }
  // Fallback: put it somewhere near the centre.
  positions[i * 3] = (Math.random() - 0.5) * 0.3
  positions[i * 3 + 1] = (Math.random() - 0.5) * 0.3
  positions[i * 3 + 2] = (Math.random() - 0.5) * 0.3
  ages[i] = 0
}

// Trilinear interpolation of a 3D scalar field on the unit cube [-0.5, 0.5]^3.
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
  const i100 = i000 + 1
  const i010 = i000 + nx
  const i110 = i010 + 1
  const i001 = i000 + s
  const i101 = i001 + 1
  const i011 = i010 + s
  const i111 = i011 + 1
  const c00 = data[i000] * (1 - fx) + data[i100] * fx
  const c10 = data[i010] * (1 - fx) + data[i110] * fx
  const c01 = data[i001] * (1 - fx) + data[i101] * fx
  const c11 = data[i011] * (1 - fx) + data[i111] * fx
  const c0 = c00 * (1 - fy) + c10 * fy
  const c1 = c01 * (1 - fy) + c11 * fy
  return c0 * (1 - fz) + c1 * fz
}

// Trilinear interpolation of the RGBA velocity field; returns [vx, vy, vz, mag].
// Data layout: interleaved 4-channel per strided cell, ordered (ix, iy, iz).
// Particle coords are in [-0.5, 0.5]; map to the strided subgrid.
function sampleVector(
  data: Float32Array,
  nx: number,
  ny: number,
  nz: number,
  _stride: number,
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
