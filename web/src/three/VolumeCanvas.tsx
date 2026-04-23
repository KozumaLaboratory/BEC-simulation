import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import * as THREE from 'three'
import * as THREE_WEBGPU from 'three/webgpu'
import { useMemo } from 'react'
import { DensityVolume, type VolumeParams } from './DensityVolume'
import type { DensityTexture } from './useDensityTexture'

interface Props {
  density: DensityTexture
  params: VolumeParams
}

const webgpuSupported =
  typeof navigator !== 'undefined' && 'gpu' in navigator

export function VolumeCanvas({ density, params }: Props) {
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
      camera={{ position: [2, 2, 2.5], fov: 40, near: 0.1, far: 50 }}
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
      <color attach="background" args={['#0a0e14']} />
      <ambientLight intensity={0.4} />
      <DensityVolume density={density} params={params} />
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
