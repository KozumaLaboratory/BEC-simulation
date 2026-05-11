import { CameraControls } from '@react-three/drei'
import { forwardRef, useEffect, useImperativeHandle, useRef } from 'react'
import type CameraControlsImpl from 'camera-controls'

// Distance from origin for all preset poses. The cube sits in [-0.5,0.5]^3
// so 1.4 puts the camera at ~2× the cube half-diagonal — keeps the whole
// volume inside the viewport with a bit of margin at fov=55.
const R = 1.4
const ISO_S = 1 / Math.sqrt(3)

export const CAMERA_PRESETS = {
  iso:    [R * ISO_S,  R * ISO_S,  R * ISO_S] as const,
  top:    [0.0001,     R,          0.0001] as const,
  bottom: [0.0001,    -R,          0.0001] as const,
  front:  [0,          0,          R] as const,
  back:   [0,          0,         -R] as const,
  right:  [R,          0,          0] as const,
  left:   [-R,         0,          0] as const,
} as const

export type PresetName = keyof typeof CAMERA_PRESETS

interface Props {
  initialPreset?: PresetName
  smoothTime?: number
}

// Replaces OrbitControls with drei's CameraControls so we get
// `setLookAt(..., true)` smooth flies for preset buttons. `ref` lets
// the DOM preset bar drive the camera imperatively. smoothTime defaults
// to 0.35s — fast enough not to feel laggy, slow enough to read the
// transition.
export const CameraRig = forwardRef<CameraControlsImpl, Props>(function CameraRig(
  { initialPreset = 'iso', smoothTime = 0.35 },
  fwdRef,
) {
  const ref = useRef<CameraControlsImpl>(null!)
  useImperativeHandle(fwdRef, () => ref.current, [])

  useEffect(() => {
    const c = ref.current
    if (!c) return
    c.smoothTime = smoothTime
    const p = CAMERA_PRESETS[initialPreset]
    c.setLookAt(p[0], p[1], p[2], 0, 0, 0, false)
  }, [initialPreset, smoothTime])

  return <CameraControls ref={ref} makeDefault dampingFactor={0.08} />
})
