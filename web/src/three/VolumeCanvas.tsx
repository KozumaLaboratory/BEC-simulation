import { Canvas } from '@react-three/fiber'
import * as THREE from 'three'
import * as THREE_WEBGPU from 'three/webgpu'
import { forwardRef, useImperativeHandle, useMemo, useRef } from 'react'
import type CameraControlsImpl from 'camera-controls'
import { DensityVolume, type VolumeParams } from './DensityVolume'
import { VectorField, type VectorFieldParams } from './VectorField'
import { ParticleField, type ParticleParams } from './ParticleField'
import { VortexTubes } from './VortexTubes'
import { CameraRig } from './CameraRig'
import type { DensityTexture } from './useDensityTexture'
import type { PhaseTexture } from './usePhaseTexture'
import type { VectorField3D, VortexLinesResponse } from '@/api'

interface Props {
  density: DensityTexture
  phase?: PhaseTexture
  params: VolumeParams
  vector?: {
    field: VectorField3D
    params: VectorFieldParams
  }
  particles?: {
    field: VectorField3D
    params: ParticleParams
    vortexLines?: VortexLinesResponse
  }
  vortexLines?: {
    data: VortexLinesResponse
    thickness: number
    colorByCharge?: boolean
  }
}

const webgpuSupported =
  typeof navigator !== 'undefined' && 'gpu' in navigator

export const VolumeCanvas = forwardRef<CameraControlsImpl, Props>(
  function VolumeCanvas(
    { density, phase, params, vector, particles, vortexLines },
    fwdRef,
  ) {
    const ctrlRef = useRef<CameraControlsImpl | null>(null)
    useImperativeHandle(fwdRef, () => ctrlRef.current as CameraControlsImpl, [])

    if (!webgpuSupported) {
      return (
        <div className="h-full flex items-center justify-center text-sm text-destructive text-center px-6">
          WebGPU is not available in this browser. Use Chrome 113+, Edge, or
          Firefox Nightly with <code>dom.webgpu.enabled</code>.
        </div>
      )
    }
    return (
      <Canvas
        camera={{ fov: 55, near: 0.01, far: 20 }}
        dpr={1}
        gl={async (glProps) => {
          const renderer = new THREE_WEBGPU.WebGPURenderer({
            canvas: glProps.canvas as HTMLCanvasElement,
            antialias: true,
            alpha: true,
            depth: false,
          })
          await renderer.init()
          return renderer
        }}
      >
        <color attach="background" args={['#0a0e14']} />
        <ambientLight intensity={0.4} />
        <DensityVolume density={density} phase={phase} params={params} />
        {vector && (
          <VectorField
            field={vector.field}
            density={density.meta}
            densityMax={density.maxValue}
            params={vector.params}
          />
        )}
        {particles && (
          <ParticleField
            field={particles.field}
            density={density.meta}
            densityMax={density.maxValue}
            params={particles.params}
            vortexLines={particles.vortexLines}
          />
        )}
        {vortexLines && (
          <VortexTubes
            data={vortexLines.data}
            thickness={vortexLines.thickness}
            colorByCharge={vortexLines.colorByCharge}
          />
        )}
        <BoundingBox />
        <CameraRig ref={ctrlRef} initialPreset="iso" />
      </Canvas>
    )
  },
)

function BoundingBox() {
  const edges = useMemo(() => new THREE.EdgesGeometry(new THREE.BoxGeometry(1, 1, 1)), [])
  return (
    <lineSegments geometry={edges}>
      <lineBasicMaterial color="#21262d" />
    </lineSegments>
  )
}
