import { useMemo, useRef, useEffect } from 'react'
import * as THREE from 'three'
import * as THREE_WEBGPU from 'three/webgpu'
import {
  Fn,
  vec3,
  vec4,
  float,
  positionWorld,
  cameraPosition,
  texture3D,
  uniform,
  Loop,
  If,
  max,
  min as tslMin,
  normalize,
  mix,
  smoothstep,
  clamp,
  Break,
} from 'three/tsl'
import type { DensityTexture } from './useDensityTexture'

export interface VolumeParams {
  isoMin: number // fraction of max density [0,1]
  isoMax: number
  stepCount: number // compile-time constant; changes rebuild the shader
  opacity: number
  colorA: THREE.Color
  colorB: THREE.Color
}

interface Props {
  density: DensityTexture
  params: VolumeParams
}

export function DensityVolume({ density, params }: Props) {
  const tex = density.texture
  const maxValue = density.maxValue

  const uniforms = useMemo(
    () => ({
      isoMin: uniform(params.isoMin * maxValue),
      isoMax: uniform(params.isoMax * maxValue),
      opacity: uniform(params.opacity),
      colorA: uniform(new THREE.Color(params.colorA)),
      colorB: uniform(new THREE.Color(params.colorB)),
    }),
    // Uniforms created once per mount; values live-updated below.
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [],
  )

  useEffect(() => {
    uniforms.isoMin.value = params.isoMin * maxValue
    uniforms.isoMax.value = params.isoMax * maxValue
    uniforms.opacity.value = params.opacity
    uniforms.colorA.value.set(params.colorA)
    uniforms.colorB.value.set(params.colorB)
  }, [params, maxValue, uniforms])

  const material = useMemo(() => {
    const mat = new THREE_WEBGPU.NodeMaterial()
    mat.transparent = true
    mat.side = THREE.BackSide // inside-out raymarch from back faces
    mat.depthWrite = false

    const raymarch = Fn(() => {
      // Map world-space [-0.5, 0.5] → local [0, 1].
      const worldEntry = positionWorld.add(vec3(0.5))
      const camLocal = cameraPosition.add(vec3(0.5))
      const rayDir = normalize(worldEntry.sub(camLocal))

      // Ray-AABB intersection against [0,1]^3.
      const invDir = vec3(1.0).div(rayDir)
      const t0 = vec3(0.0).sub(camLocal).mul(invDir)
      const t1 = vec3(1.0).sub(camLocal).mul(invDir)
      const tMinV = tslMin(t0, t1)
      const tMaxV = max(t0, t1)
      const tNear = max(max(tMinV.x, tMinV.y), tMinV.z)
      const tFar = tslMin(tslMin(tMaxV.x, tMaxV.y), tMaxV.z)

      const tStart = max(tNear, float(0.0))
      const dtTotal = tFar.sub(tStart)

      const color = vec3(0.0).toVar()
      const alpha = float(0.0).toVar()

      If(dtTotal.greaterThan(float(0.0)), () => {
        const dt = dtTotal.div(float(params.stepCount))
        const t = tStart.add(dt.mul(0.5)).toVar()

        Loop({ start: 0, end: params.stepCount, type: 'int' }, () => {
          const p = clamp(camLocal.add(rayDir.mul(t)), vec3(0.0), vec3(1.0))
          const d = texture3D(tex, p).r
          const norm = smoothstep(uniforms.isoMin, uniforms.isoMax, d)
          const col = mix(uniforms.colorA, uniforms.colorB, norm)
          const stepAlpha = clamp(
            norm.mul(uniforms.opacity),
            float(0.0),
            float(0.999),
          )
          const trans = float(1.0).sub(alpha)
          color.addAssign(col.mul(stepAlpha).mul(trans))
          alpha.addAssign(stepAlpha.mul(trans))
          If(alpha.greaterThan(float(0.995)), () => {
            Break()
          })
          t.addAssign(dt)
        })
      })

      return vec4(color, alpha)
    })

    mat.colorNode = raymarch()
    return mat
  }, [tex, uniforms, params.stepCount])

  const meshRef = useRef<THREE.Mesh>(null!)
  return (
    <mesh ref={meshRef} material={material as unknown as THREE.Material}>
      <boxGeometry args={[1, 1, 1]} />
    </mesh>
  )
}
