import { Canvas, useThree } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import * as THREE from 'three'
import * as THREE_WEBGPU from 'three/webgpu'
import { useEffect, useMemo } from 'react'
import { DensityVolume, type VolumeParams } from './DensityVolume'
import { VectorField, type VectorFieldParams } from './VectorField'
import { ParticleField, type ParticleParams } from './ParticleField'
import type { DensityTexture } from './useDensityTexture'
import type { PhaseTexture } from './usePhaseTexture'
import type { VectorField3D } from '@/api'

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
  }
}

const webgpuSupported =
  typeof navigator !== 'undefined' && 'gpu' in navigator

export function VolumeCanvas({ density, phase, params, vector, particles }: Props) {
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
      camera={{ position: [1.1, 1.1, 1.4], fov: 50, near: 0.05, far: 20 }}
      gl={async (glProps) => {
        const renderer = new THREE_WEBGPU.WebGPURenderer({
          canvas: glProps.canvas as HTMLCanvasElement,
          antialias: true,
          alpha: true,
        })
        await renderer.init()
        return renderer
      }}
    >
      <ResizeFix />
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
        />
      )}
      <BoundingBox />
      <OrbitControls enableDamping dampingFactor={0.08} />
    </Canvas>
  )
}

function BoundingBox() {
  const edges = useMemo(() => new THREE.EdgesGeometry(new THREE.BoxGeometry(1, 1, 1)), [])
  return (
    <lineSegments geometry={edges}>
      <lineBasicMaterial color="#21262d" />
    </lineSegments>
  )
}

// R3F's async gl factory returns the WebGPURenderer *after* init(), but by
// then the renderer's internal depth buffer has already been created at the
// canvas's default 300×150 size. R3F's own resize path doesn't re-allocate
// it. Force a setSize call after mount and on every size change; WebGPURenderer
// rebuilds the depth attachment as part of setSize.
function ResizeFix() {
  const { gl, size } = useThree()
  useEffect(() => {
    const g = gl as unknown as { setSize: (w: number, h: number, updateStyle?: boolean) => void }
    g.setSize(size.width, size.height, false)
  }, [gl, size.width, size.height])
  return null
}
