import { useEffect, useMemo, useRef } from 'react'
import { Canvas } from '@react-three/fiber'
import * as THREE from 'three'
import { getLutTexture, type ColormapName } from '@/three/colormapLuts'

interface Props {
  /** Flat row-major data, length = nx * ny. */
  data: Float32Array
  nx: number
  ny: number
  zmin: number
  zmax: number
  colormap: ColormapName
  /** Optional density mask: cells where mask[k] < threshold are discarded
   * (used by phase mode to hide angles where |ψ|² is too small for the
   * angle to be physically meaningful). */
  mask?: { data: Float32Array; threshold: number }
  title?: string
  axisLabels?: [string, string]
  height?: number
}

/**
 * 2D heatmap rendered via R3F + a single textured plane. Drop-in for the
 * old Plotly `<heatmap>` panel: an `r32float` `DataTexture` carries the
 * raw values and a 256-stop 1D LUT applies the colormap in the fragment
 * shader.
 *
 * Texture filtering is `NearestFilter` so per-cell values are NOT
 * interpolated between neighbours. Sweep data is **discrete**: a
 * (B, Ω) cell is one resolved measurement, not a sample from a
 * continuous field. Bilinear filtering (the previous default) drew
 * smooth-looking gradients between cells that didn't exist, which
 * over-suggested structure at cell boundaries and made adjacent
 * unconverged vs converged cells blend into each other visually.
 * See `docs/architecture/sweep_view.md` for the rationale.
 *
 * Why R3F instead of Plotly: 14 panels × 60 fps fit easily on a GPU but
 * crushed Plotly's CPU heatmap path; bundle savings of removing Plotly
 * are a separate bonus.
 */
export function Heatmap2D({
  data,
  nx,
  ny,
  zmin,
  zmax,
  colormap,
  mask,
  title,
  axisLabels,
  height = 220,
}: Props) {
  return (
    <div
      style={{
        position: 'relative',
        width: '100%',
        height,
        background: '#0a0e14',
        borderRadius: 4,
        overflow: 'hidden',
      }}
    >
      {title && (
        <div
          style={{
            position: 'absolute',
            top: 4,
            left: 0,
            right: 0,
            textAlign: 'center',
            fontSize: 11,
            color: '#00d9ff',
            pointerEvents: 'none',
            zIndex: 1,
          }}
        >
          {title}
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
              color: '#7d8590',
              pointerEvents: 'none',
              zIndex: 1,
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
              color: '#7d8590',
              pointerEvents: 'none',
              zIndex: 1,
            }}
          >
            {axisLabels[1]}
          </div>
        </>
      )}
      <Canvas
        orthographic
        // Fit the [-1,1] × [-1,1] frustum to the canvas; the plane below
        // fills exactly that range so it covers the viewport edge-to-edge
        // regardless of canvas size.
        camera={{ position: [0, 0, 1], left: -1, right: 1, top: 1, bottom: -1, near: 0.01, far: 10, zoom: 1 }}
        dpr={1}
        gl={{ antialias: false, alpha: false }}
      >
        <color attach="background" args={['#0a0e14']} />
        <HeatmapMesh
          data={data}
          nx={nx}
          ny={ny}
          zmin={zmin}
          zmax={zmax}
          colormap={colormap}
          mask={mask}
        />
      </Canvas>
    </div>
  )
}

interface MeshProps {
  data: Float32Array
  nx: number
  ny: number
  zmin: number
  zmax: number
  colormap: ColormapName
  mask?: { data: Float32Array; threshold: number }
}

function HeatmapMesh({ data, nx, ny, zmin, zmax, colormap, mask }: MeshProps) {
  const matRef = useRef<THREE.ShaderMaterial | null>(null)

  // (Re)allocate the texture only when shape changes; the snap scrubber
  // keeps shape constant and only swaps the data buffer, which we
  // handle via `needsUpdate` below to avoid GPU churn.
  const dataTex = useMemo(() => {
    const tex = new THREE.DataTexture(data, nx, ny, THREE.RedFormat, THREE.FloatType)
    // NearestFilter (not Linear): sweep cells are discrete measurements,
    // not samples of a continuum. See header comment.
    tex.minFilter = THREE.NearestFilter
    tex.magFilter = THREE.NearestFilter
    tex.wrapS = THREE.ClampToEdgeWrapping
    tex.wrapT = THREE.ClampToEdgeWrapping
    tex.unpackAlignment = 1
    tex.needsUpdate = true
    return tex
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nx, ny])

  // See the long note in HeatmapGrid.tsx — the canonical
  // cleanup-time dispose pattern silently breaks under React StrictMode
  // because the cached useMemo value gets disposed between the dev-
  // double-mount cycle. Skip the cleanup and accept the bounded leak.
  useEffect(() => {
    dataTex.image.data = data
    dataTex.needsUpdate = true
  }, [dataTex, data])

  const maskTex = useMemo(() => {
    if (!mask) return null
    const tex = new THREE.DataTexture(
      mask.data,
      nx,
      ny,
      THREE.RedFormat,
      THREE.FloatType,
    )
    // Same NearestFilter rationale as the data texture above.
    tex.minFilter = THREE.NearestFilter
    tex.magFilter = THREE.NearestFilter
    tex.wrapS = THREE.ClampToEdgeWrapping
    tex.wrapT = THREE.ClampToEdgeWrapping
    tex.unpackAlignment = 1
    tex.needsUpdate = true
    return tex
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nx, ny, mask !== undefined])

  useEffect(() => {
    if (!maskTex || !mask) return
    maskTex.image.data = mask.data
    maskTex.needsUpdate = true
  }, [maskTex, mask?.data])

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
        varying vec2 vUv;
        void main() {
          ${useMask ? `
          float n = texture2D(maskTex, vUv).r;
          if (n < threshold) {
            gl_FragColor = vec4(0.04, 0.055, 0.078, 1.0);
            return;
          }
          ` : ''}
          float v = texture2D(dataTex, vUv).r;
          float t = clamp((v - zmin) / max(zmax - zmin, 1e-30), 0.0, 1.0);
          vec3 rgb = texture2D(lut, vec2(t, 0.5)).rgb;
          gl_FragColor = vec4(rgb, 1.0);
        }
      `,
      // DoubleSide is precautionary here (this canvas uses the standard
      // top=1, bottom=-1 frustum so winding isn't actually inverted),
      // but kept consistent with HeatmapGrid where the HTML-overlay
      // frustum (top < bottom) silently broke ShaderMaterial planes.
      side: THREE.DoubleSide,
      depthTest: false,
      depthWrite: false,
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dataTex, maskTex, lut, mask !== undefined])

  useEffect(() => {
    matRef.current = material
  }, [material])

  // Patch scalar uniforms in place — recreating the material would force a
  // GLSL recompile per frame, which is much slower than a uniform write.
  useEffect(() => {
    if (!matRef.current) return
    matRef.current.uniforms.zmin.value = zmin
    matRef.current.uniforms.zmax.value = zmax
    if (mask !== undefined) {
      matRef.current.uniforms.threshold.value = mask.threshold
    }
  }, [zmin, zmax, mask?.threshold, mask])

  return (
    <mesh material={material}>
      <planeGeometry args={[2, 2]} />
    </mesh>
  )
}
