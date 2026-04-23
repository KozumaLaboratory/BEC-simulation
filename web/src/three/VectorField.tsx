import { useMemo, useRef, useEffect } from 'react'
import * as THREE from 'three'
import type { VectorField3D, Density3D } from '@/api'

export interface VectorFieldParams {
  arrowScale: number
  densityThreshold: number
  colorLow: string
  colorHigh: string
}

interface Props {
  field: VectorField3D
  density: Density3D
  densityMax: number
  params: VectorFieldParams
}

const UP = new THREE.Vector3(0, 1, 0) // cone geometry points +Y by default
const _q = new THREE.Quaternion()
const _dir = new THREE.Vector3()
const _pos = new THREE.Vector3()
const _scale = new THREE.Vector3()
const _mat = new THREE.Matrix4()
const _col = new THREE.Color()

export function VectorField({ field, density, densityMax, params }: Props) {
  const geometry = useMemo(() => {
    const g = new THREE.ConeGeometry(0.15, 1.0, 6)
    g.translate(0, 0.5, 0) // base at y=0, tip at y=1
    return g
  }, [])

  const material = useMemo(
    () =>
      new THREE.MeshBasicMaterial({
        transparent: true,
        opacity: 0.9,
        depthWrite: false,
      }),
    [],
  )

  // Pre-compute surviving instances and their transforms.
  const { count, matrices, colors } = useMemo(() => {
    const { nx, ny, nz, stride, data } = field
    const densThresh = densityMax * params.densityThreshold
    const densArr = density.density
    const fullNx = density.nx,
      fullNy = density.ny,
      fullNz = density.nz
    const kept: number[] = []

    for (let iz = 0; iz < nz; iz++) {
      for (let iy = 0; iy < ny; iy++) {
        for (let ix = 0; ix < nx; ix++) {
          const idx = ix + iy * nx + iz * nx * ny
          if (data[idx * 4 + 3] < 1e-30) continue
          if (densThresh > 0) {
            const gx = ix * stride,
              gy = iy * stride,
              gz = iz * stride
            const di = gx + gy * fullNx + gz * fullNx * fullNy
            if (di < densArr.length && densArr[di] < densThresh) continue
          }
          kept.push(idx)
        }
      }
    }

    const n = kept.length
    const mat = new Float32Array(n * 16)
    const col = new Float32Array(n * 3)

    // Arrow length scale: one stride cell × user scale, modulated by |v|/max|v|.
    const cell = 1.0 / Math.max(fullNx, fullNy, fullNz)
    const base = cell * stride * params.arrowScale
    let magMax = 0
    for (const idx of kept) {
      const m = data[idx * 4 + 3]
      if (m > magMax) magMax = m
    }
    const invMagMax = magMax > 0 ? 1 / magMax : 1
    const cLow = new THREE.Color(params.colorLow)
    const cHigh = new THREE.Color(params.colorHigh)

    for (let i = 0; i < n; i++) {
      const idx = kept[i]
      const ix = idx % nx
      const iy = Math.floor(idx / nx) % ny
      const iz = Math.floor(idx / (nx * ny))

      const vx = data[idx * 4]
      const vy = data[idx * 4 + 1]
      const vz = data[idx * 4 + 2]
      const mag = data[idx * 4 + 3]
      const invMag = 1 / mag
      _dir.set(vx * invMag, vy * invMag, vz * invMag)
      _q.setFromUnitVectors(UP, _dir)

      // Place on the same [-0.5, 0.5]^3 cube as the density volume.
      const gx = ix * stride,
        gy = iy * stride,
        gz = iz * stride
      _pos.set(
        (gx + 0.5) / fullNx - 0.5,
        (gy + 0.5) / fullNy - 0.5,
        (gz + 0.5) / fullNz - 0.5,
      )

      const t = mag * invMagMax
      const len = base * t
      _scale.set(len * 0.35, len, len * 0.35)

      _mat.compose(_pos, _q, _scale)
      _mat.toArray(mat, i * 16)

      _col.copy(cLow).lerp(cHigh, t)
      col[i * 3] = _col.r
      col[i * 3 + 1] = _col.g
      col[i * 3 + 2] = _col.b
    }

    return { count: n, matrices: mat, colors: col }
  }, [field, density, densityMax, params])

  const meshRef = useRef<THREE.InstancedMesh>(null!)

  useEffect(() => {
    const mesh = meshRef.current
    if (!mesh) return
    mesh.count = count
    if (count === 0) return
    ;(mesh.instanceMatrix.array as Float32Array).set(matrices)
    mesh.instanceMatrix.needsUpdate = true

    if (!mesh.instanceColor || mesh.instanceColor.count !== count) {
      mesh.instanceColor = new THREE.InstancedBufferAttribute(colors, 3)
    } else {
      ;(mesh.instanceColor.array as Float32Array).set(colors)
    }
    mesh.instanceColor.needsUpdate = true
  }, [count, matrices, colors])

  if (count === 0) return null

  return (
    <instancedMesh
      ref={meshRef}
      args={[geometry, material, count]}
      frustumCulled={false}
    />
  )
}
