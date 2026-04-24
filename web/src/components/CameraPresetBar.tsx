import type CameraControlsImpl from 'camera-controls'
import { Button } from '@/components/ui/button'
import { CAMERA_PRESETS } from '@/three/CameraRig'

interface Props {
  controlsRef: React.MutableRefObject<CameraControlsImpl | null>
  onReset?: () => void
}

const LABELS: Record<string, string> = {
  iso: 'iso',
  top: '+Y',
  bottom: '−Y',
  front: '+Z',
  back: '−Z',
  right: '+X',
  left: '−X',
}

// Floating overlay that drives the camera via CameraControls.setLookAt.
// Sits on top of the R3F canvas in DOM space, not as <Html> inside the
// scene, so buttons stay crisp and don't inherit any scene transforms.
export function CameraPresetBar({ controlsRef, onReset }: Props) {
  const fly = (p: readonly [number, number, number]) => {
    const c = controlsRef.current
    if (!c) return
    c.setLookAt(p[0], p[1], p[2], 0, 0, 0, true)
  }

  return (
    <div className="absolute top-2 left-2 z-10 flex flex-wrap gap-1 rounded-md bg-card/80 backdrop-blur px-1 py-1 border">
      {Object.entries(CAMERA_PRESETS).map(([k, p]) => (
        <Button
          key={k}
          variant="outline"
          size="xs"
          onClick={() => fly(p)}
          title={`${k} view`}
        >
          {LABELS[k] ?? k}
        </Button>
      ))}
      {onReset && (
        <Button variant="outline" size="xs" onClick={onReset} title="Reset camera">
          reset
        </Button>
      )}
    </div>
  )
}
