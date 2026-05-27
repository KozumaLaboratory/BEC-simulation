import { useEffect, useMemo, useRef, useState } from 'react'
import { Canvas, useThree } from '@react-three/fiber'
import * as THREE from 'three'
import { getLutTexture, type ColormapName } from '@/three/colormapLuts'

export interface HeatmapPanelSpec {
  /** Stable React key. */
  id: string
  /** Optional in-canvas title shown at the top centre of the panel. */
  title?: string
  /** Either a single nx×ny frame or — when atlasFrames > 1 — an atlas
   * with `atlasFrames` frames stacked vertically (length = nx · ny ·
   * atlasFrames). The shader samples the slab at `atlasFrame`. */
  data: Float32Array
  nx: number
  ny: number
  /** Number of frames packed vertically in `data`. Default: 1 (legacy
   * single-frame mode). When > 1, only `atlasFrame` changes per scrub
   * snap — the GPU upload happens once. */
  atlasFrames?: number
  /** Index into the atlas (0-based). Ignored when atlasFrames is 1. */
  atlasFrame?: number
  zmin: number
  zmax: number
  colormap: ColormapName
  /** Mask texture: cells with mask.data[k] < threshold are discarded.
   * If atlasFrames > 1, mask.data must also be an atlas of the same
   * shape (nx · ny · atlasFrames). */
  mask?: { data: Float32Array; threshold: number }
}

interface Props {
  panels: HeatmapPanelSpec[]
  /** Columns in the grid for the per-m panels. */
  cols: 1 | 2 | 3 | 4
  /** Per-panel CSS height in pixels (Total panel inherits its own height). */
  rowHeight: number
  axisLabels?: [string, string]
  /** When true, render the first panel full-width on its own row above the
   * grid (used for the spin-summed "Total" panel above per-m panels). */
  firstFull?: boolean
  totalHeight?: number  // CSS height for the firstFull panel
  gap?: number
}

/**
 * Renders N heatmaps inside a single shared R3F `<Canvas>`. Each panel is
 * a separate mesh + DataTexture, but the WebGPU/WebGL context, render
 * loop, and 1D LUT texture are reused across all panels.
 *
 * The previous implementation mounted one `<Canvas>` per panel — which on
 * Klaus (F=8) meant 14 simultaneous WebGPU contexts (each ~1 MB of GPU
 * state, plus per-frame compositing). Consolidating to one canvas saves
 * ~13 contexts and lets the GPU batch draw calls.
 */
export function HeatmapGrid({
  panels,
  cols,
  rowHeight,
  axisLabels,
  firstFull = false,
  totalHeight = 280,
  gap = 8,
}: Props) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [containerW, setContainerW] = useState(800)

  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    setContainerW(el.clientWidth)
    const ro = new ResizeObserver((entries) => {
      const w = entries[0]?.contentRect.width
      if (typeof w === 'number') setContainerW(w)
    })
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const layout = useMemo(() => {
    const out: Array<{ x: number; y: number; w: number; h: number }> = []
    if (panels.length === 0) return { rects: out, totalH: rowHeight }
    let cursorY = 0
    let start = 0
    if (firstFull) {
      out.push({ x: 0, y: 0, w: containerW, h: totalHeight })
      cursorY = totalHeight + gap
      start = 1
    }
    const colW = (containerW - gap * (cols - 1)) / cols
    for (let i = start; i < panels.length; i++) {
      const localIdx = i - start
      const col = localIdx % cols
      const row = Math.floor(localIdx / cols)
      out.push({
        x: col * (colW + gap),
        y: cursorY + row * (rowHeight + gap),
        w: colW,
        h: rowHeight,
      })
    }
    const totalH = out.length > 0 ? Math.max(...out.map((r) => r.y + r.h)) : rowHeight
    return { rects: out, totalH }
  }, [panels.length, containerW, cols, rowHeight, firstFull, totalHeight, gap])

  return (
    <div
      ref={containerRef}
      style={{ position: 'relative', width: '100%', height: layout.totalH }}
    >
      <Canvas
        orthographic
        // frameloop="demand" stops the per-frame render loop; R3F only
        // re-renders when state.set() is called or invalidate() fires.
        // We update uniforms via material.uniforms.X.value = ... AND
        // mark needsUpdate via the useEffect below — those write paths
        // schedule a redraw without keeping a continuous rAF burning.
        frameloop="demand"
        // CSS-pixel orthographic frustum: y=0 at top, y=totalH at bottom,
        // matching the HTML overlay coordinates exactly. Each panel's
        // mesh is positioned in this same space.
        camera={{
          position: [0, 0, 1],
          left: 0,
          right: containerW,
          top: 0,
          bottom: layout.totalH,
          near: 0.01,
          far: 10,
          zoom: 1,
        }}
        dpr={1}
        gl={{ antialias: false, alpha: true }}
        style={{ position: 'absolute', inset: 0 }}
      >
        <SyncOrthoFrustum width={containerW} height={layout.totalH} />
        {panels.map((p, i) => {
          const r = layout.rects[i]
          if (!r) return null
          return (
            <PositionedHeatmap
              key={p.id}
              spec={p}
              cx={r.x + r.w / 2}
              cy={r.y + r.h / 2}
              w={r.w}
              h={r.h}
            />
          )
        })}
      </Canvas>
      {panels.map((p, i) => {
        const r = layout.rects[i]
        if (!r) return null
        return (
          <div
            key={`${p.id}_ovr`}
            style={{
              position: 'absolute',
              left: r.x,
              top: r.y,
              width: r.w,
              height: r.h,
              pointerEvents: 'none',
            }}
          >
            {p.title && (
              <div
                style={{
                  position: 'absolute',
                  top: 4,
                  left: 0,
                  right: 0,
                  textAlign: 'center',
                  fontSize: 11,
                  color: 'var(--ink)',
                  opacity: 0.85,
                  fontFamily: 'IBM Plex Mono, ui-monospace, monospace',
                  letterSpacing: '0.04em',
                }}
              >
                {p.title}
              </div>
            )}
            {axisLabels && (
              <>
                <div
                  style={{
                    position: 'absolute',
                    bottom: 2,
                    left: 0,
                    right: 0,
                    textAlign: 'center',
                    fontSize: 10,
                    color: 'var(--ink)',
                    opacity: 0.6,
                    fontFamily: 'IBM Plex Mono, ui-monospace, monospace',
                  }}
                >
                  {axisLabels[0]}
                </div>
                <div
                  style={{
                    position: 'absolute',
                    top: '50%',
                    left: 4,
                    transform: 'translateY(-50%) rotate(-90deg)',
                    transformOrigin: 'left center',
                    fontSize: 10,
                    color: 'var(--ink)',
                    opacity: 0.6,
                    fontFamily: 'IBM Plex Mono, ui-monospace, monospace',
                  }}
                >
                  {axisLabels[1]}
                </div>
              </>
            )}
          </div>
        )
      })}
    </div>
  )
}

// Re-applies the orthographic frustum whenever the container size changes,
// so the camera tracks the current viewport in CSS pixels.
function SyncOrthoFrustum({ width, height }: { width: number; height: number }) {
  const { camera } = useThree()
  useEffect(() => {
    if (!('isOrthographicCamera' in camera) || !camera.isOrthographicCamera) return
    const ortho = camera as THREE.OrthographicCamera
    ortho.left = 0
    ortho.right = width
    ortho.top = 0
    ortho.bottom = height
    ortho.updateProjectionMatrix()
  }, [camera, width, height])
  return null
}

interface PositionedProps {
  spec: HeatmapPanelSpec
  cx: number
  cy: number
  w: number
  h: number
}

function PositionedHeatmap({ spec, cx, cy, w, h }: PositionedProps) {
  const { data, nx, ny, zmin, zmax, colormap, mask } = spec
  const atlasFrames = Math.max(1, spec.atlasFrames ?? 1)
  const atlasFrame = Math.min(Math.max(0, spec.atlasFrame ?? 0), atlasFrames - 1)
  const matRef = useRef<THREE.ShaderMaterial | null>(null)
  const invalidate = useThree((s) => s.invalidate)
  // Texture height is ny × atlasFrames so all frames stack vertically;
  // the fragment shader picks the active slab via the atlasFrame uniform.
  const texHeight = ny * atlasFrames

  const dataTex = useMemo(() => {
    const tex = new THREE.DataTexture(data, nx, texHeight, THREE.RedFormat, THREE.FloatType)
    tex.minFilter = THREE.LinearFilter
    tex.magFilter = THREE.LinearFilter
    tex.wrapS = THREE.ClampToEdgeWrapping
    tex.wrapT = THREE.ClampToEdgeWrapping
    tex.unpackAlignment = 1
    tex.needsUpdate = true
    return tex
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nx, texHeight])

  useEffect(() => () => dataTex.dispose(), [dataTex])

  useEffect(() => {
    dataTex.image.data = data
    dataTex.needsUpdate = true
    invalidate()
  }, [dataTex, data, invalidate])

  const maskTex = useMemo(() => {
    if (!mask) return null
    const tex = new THREE.DataTexture(
      mask.data,
      nx,
      texHeight,
      THREE.RedFormat,
      THREE.FloatType,
    )
    tex.minFilter = THREE.LinearFilter
    tex.magFilter = THREE.LinearFilter
    tex.wrapS = THREE.ClampToEdgeWrapping
    tex.wrapT = THREE.ClampToEdgeWrapping
    tex.unpackAlignment = 1
    tex.needsUpdate = true
    return tex
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nx, texHeight, mask !== undefined])

  useEffect(() => () => {
    maskTex?.dispose()
  }, [maskTex])

  useEffect(() => {
    if (!maskTex || !mask) return
    maskTex.image.data = mask.data
    maskTex.needsUpdate = true
    invalidate()
  }, [maskTex, mask?.data, invalidate])

  const lut = useMemo(() => getLutTexture(colormap), [colormap])

  const material = useMemo(() => {
    const useMask = mask !== undefined
    return new THREE.ShaderMaterial({
      uniforms: {
        dataTex: { value: dataTex },
        lut: { value: lut },
        maskTex: { value: maskTex },
        zmin: { value: zmin },
        zmax: { value: zmax },
        threshold: { value: mask?.threshold ?? 0 },
        atlasFrames: { value: atlasFrames },
        atlasFrame: { value: atlasFrame },
      },
      vertexShader: /* glsl */ `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
        }
      `,
      fragmentShader: /* glsl */ `
        precision highp float;
        uniform sampler2D dataTex;
        uniform sampler2D lut;
        ${useMask ? 'uniform sampler2D maskTex;' : ''}
        uniform float zmin;
        uniform float zmax;
        ${useMask ? 'uniform float threshold;' : ''}
        uniform float atlasFrames;
        uniform float atlasFrame;
        varying vec2 vUv;
        // Map a per-frame UV into the stacked atlas. atlasFrames=1 falls
        // through to the original single-frame sampling.
        vec2 atlasUv(vec2 uv) {
          if (atlasFrames <= 1.0) return uv;
          return vec2(uv.x, (uv.y + atlasFrame) / atlasFrames);
        }
        void main() {
          vec2 uv = atlasUv(vUv);
          ${useMask ? `
          float n = texture2D(maskTex, uv).r;
          if (n < threshold) {
            gl_FragColor = vec4(0.04, 0.055, 0.078, 1.0);
            return;
          }
          ` : ''}
          float v = texture2D(dataTex, uv).r;
          float t = clamp((v - zmin) / max(zmax - zmin, 1e-30), 0.0, 1.0);
          vec3 rgb = texture2D(lut, vec2(t, 0.5)).rgb;
          gl_FragColor = vec4(rgb, 1.0);
        }
      `,
      depthTest: false,
      depthWrite: false,
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dataTex, maskTex, lut, mask !== undefined])

  useEffect(() => {
    matRef.current = material
    return () => material.dispose()
  }, [material])

  // Patch scalar uniforms in place — recreating the material would force a
  // GLSL recompile per frame, which is much slower than a uniform write.
  // The atlas frame is the per-scrub hot path: this effect runs every snap
  // change and triggers exactly one uniform write + one redraw, no GPU
  // upload, no React reconciliation past this hook.
  useEffect(() => {
    if (!matRef.current) return
    matRef.current.uniforms.zmin.value = zmin
    matRef.current.uniforms.zmax.value = zmax
    matRef.current.uniforms.atlasFrame.value = atlasFrame
    matRef.current.uniforms.atlasFrames.value = atlasFrames
    if (mask !== undefined) {
      matRef.current.uniforms.threshold.value = mask.threshold
    }
    invalidate()
  }, [zmin, zmax, mask?.threshold, mask, atlasFrame, atlasFrames, invalidate])

  return (
    <mesh material={material} position={[cx, cy, 0]}>
      <planeGeometry args={[w, h]} />
    </mesh>
  )
}
