import { useMemo } from 'react'
import * as THREE from 'three'
import type { VortexLinesResponse } from '@/api'

interface Props {
  data: VortexLinesResponse
  thickness: number // tube radius in render-space units (cube is 1×1×1)
  colorByCharge?: boolean // if true, + charges red-ish, - charges blue-ish; else per-m palette
}

// 13-color palette keyed to m = +F .. -F. Bright, saturated, readable on
// a #0a0e14 background.
const M_COLORS: Record<string, string> = {
  '+6': '#ff3b3b',
  '+5': '#ff7a00',
  '+4': '#ffbf00',
  '+3': '#ffff3b',
  '+2': '#7fff3b',
  '+1': '#3bffc0',
  '0':  '#3bf0ff',
  '-1': '#3baaff',
  '-2': '#5c6bff',
  '-3': '#a256ff',
  '-4': '#e03bff',
  '-5': '#ff3bc2',
  '-6': '#ff3b7a',
}

// Render extracted vortex lines as emissive tubes — one InstancedMesh of
// short cylindrical segments per polyline. Additive blending on a dark
// canvas gives the "glowing filament" look without needing a full bloom
// post-process. Coordinates in the response are in Julia grid units
// (box = Lx, Ly, Lz a_ho); we normalise to the [-0.5, 0.5]^3 cube that
// the rest of the 3D view lives in.
export function VortexTubes({ data, thickness, colorByCharge }: Props) {
  const [Lx, Ly, Lz] = data.box
  const geometry = useMemo(() => new THREE.CylinderGeometry(1, 1, 1, 12, 1, false), [])

  return (
    <group>
      {data.lines.map((line, idx) => {
        const segs: Array<{
          position: THREE.Vector3
          quaternion: THREE.Quaternion
          scale: THREE.Vector3
        }> = []
        for (let i = 0; i < line.points.length - 1; i++) {
          const p0 = line.points[i]
          const p1 = line.points[i + 1]
          const a = new THREE.Vector3(p0[0] / Lx, p0[1] / Ly, p0[2] / Lz)
          const b = new THREE.Vector3(p1[0] / Lx, p1[1] / Ly, p1[2] / Lz)
          const mid = new THREE.Vector3().addVectors(a, b).multiplyScalar(0.5)
          const diff = new THREE.Vector3().subVectors(b, a)
          const len = diff.length()
          if (len < 1e-6) continue
          const dir = diff.clone().normalize()
          // CylinderGeometry aligns along +Y by default.
          const q = new THREE.Quaternion().setFromUnitVectors(
            new THREE.Vector3(0, 1, 0),
            dir,
          )
          segs.push({
            position: mid,
            quaternion: q,
            scale: new THREE.Vector3(thickness, len, thickness),
          })
        }

        const color = colorByCharge
          ? line.charge > 0
            ? '#ff4040'
            : '#40a0ff'
          : M_COLORS[line.m] ?? '#ffffff'

        return (
          <SegmentInstances
            key={idx}
            geometry={geometry}
            segs={segs}
            color={color}
          />
        )
      })}
    </group>
  )
}

function SegmentInstances({
  geometry,
  segs,
  color,
}: {
  geometry: THREE.CylinderGeometry
  segs: Array<{
    position: THREE.Vector3
    quaternion: THREE.Quaternion
    scale: THREE.Vector3
  }>
  color: string
}) {
  const material = useMemo(
    () =>
      new THREE.MeshBasicMaterial({
        color,
        transparent: true,
        opacity: 0.95,
        depthWrite: false,
        blending: THREE.AdditiveBlending,
      }),
    [color],
  )

  const mesh = useMemo(() => {
    const m = new THREE.InstancedMesh(geometry, material, segs.length)
    const tmp = new THREE.Matrix4()
    segs.forEach((s, i) => {
      tmp.compose(s.position, s.quaternion, s.scale)
      m.setMatrixAt(i, tmp)
    })
    m.instanceMatrix.needsUpdate = true
    m.frustumCulled = false
    return m
  }, [geometry, material, segs])

  return <primitive object={mesh} />
}
