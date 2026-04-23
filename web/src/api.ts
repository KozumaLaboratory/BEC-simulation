// Typed fetch wrappers around Julia serve_dashboard routes.
// Binary layouts here must stay in sync with src/workflow/io/dashboard.jl.

export interface PointMeta {
  file: string
  index: number
  run_name: string
  energy: number
  converged: boolean
  mz_actual: number
  populations: number[]
  m_values: number[]
  override: Record<string, unknown>
  duration_seconds: number
  started_at: string
  finished_at: string
}

export interface DashboardData {
  run: string
  config_yaml: string
  F: number
  n_points: number
  scan_keys: string[]
  run_names: string[]
  points: PointMeta[]
}

export interface Density3D {
  nx: number
  ny: number
  nz: number
  n_comp: number
  F: number
  component: number
  populations: Float32Array
  density: Float32Array
}

export interface VectorField3D {
  nx: number
  ny: number
  nz: number
  stride: number
  // interleaved RGBA = (vx, vy, vz, |v|), length = nx*ny*nz*4
  data: Float32Array
}

export type VectorFieldKind = 'current' | 'spin_density' | 'velocity'

export interface PhaseSlice {
  ndim: number
  axis: number
  slice_index: number
  shape: number[]
  box: number[]
  axis_labels: string[]
  axis_ranges: number[][]
  m_values: number[]
  phases: number[][] // per-component flat arrays, values in [-π, π]
  densities: number[][] // per-component |ψ|² at the same slice, for low-density masking
}

export interface ColumnDensity {
  ndim: number
  axis: number
  shape: number[] // 2D: [nx, ny]
  box: number[]
  axis_labels: string[] // remaining axes, e.g. ["x", "y"]
  axis_ranges: number[][] // [[x_min,x_max], [y_min,y_max]]
  m_values: number[]
  total_density: number[] // flat length shape[0]*shape[1]
  densities: number[][] // per-component flat arrays
}

async function json<T>(url: string): Promise<T> {
  const r = await fetch(url)
  if (!r.ok) throw new Error(`${r.status} ${r.statusText} @ ${url}`)
  return r.json() as Promise<T>
}

async function bin(url: string): Promise<ArrayBuffer> {
  const r = await fetch(url)
  if (!r.ok) throw new Error(`${r.status} ${r.statusText} @ ${url}`)
  return r.arrayBuffer()
}

export const api = {
  listRuns(): Promise<string[]> {
    return json('/api/runs')
  },

  getRunData(name: string): Promise<DashboardData> {
    return json(`/api/data/${encodeURIComponent(name)}`)
  },

  async getDensity3d(
    run: string,
    file: string,
    component = 0,
    angleDeg = 0,
  ): Promise<Density3D> {
    // Rotation only matters for per-component requests; the total density
    // (component=0) is invariant under quantization-axis rotation.
    const useRotated = component > 0 && Math.abs(angleDeg) > 0.01
    const url = useRotated
      ? `/api/density3d_rotated/${encodeURIComponent(run)}/${encodeURIComponent(file)}?angle=${angleDeg}&comp=${component}`
      : `/api/density3d_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?comp=${component}`
    const buf = await bin(url)
    const header = new Int32Array(buf, 0, 6)
    const nx = header[0],
      ny = header[1],
      nz = header[2]
    const n_comp = header[3],
      F = header[4],
      comp = header[5]
    const populations = new Float32Array(buf, 24, n_comp)
    const density = new Float32Array(buf, 24 + n_comp * 4, nx * ny * nz)
    return { nx, ny, nz, n_comp, F, component: comp, populations, density }
  },

  async getVector3d(
    run: string,
    file: string,
    field: VectorFieldKind = 'current',
    stride = 2,
  ): Promise<VectorField3D> {
    const buf = await bin(
      `/api/vector3d_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?field=${field}&stride=${stride}`,
    )
    const header = new Int32Array(buf, 0, 7)
    const nx = header[0],
      ny = header[1],
      nz = header[2],
      s = header[3]
    const data = new Float32Array(buf, 28, nx * ny * nz * 4)
    return { nx, ny, nz, stride: s, data }
  },

  getColumnDensity(run: string, file: string, axis: 1 | 2 | 3): Promise<ColumnDensity> {
    return json(
      `/api/density/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}`,
    )
  },

  getPhaseSlice(
    run: string,
    file: string,
    axis: 1 | 2 | 3,
    sliceIndex?: number,
  ): Promise<PhaseSlice> {
    const sliceArg = sliceIndex !== undefined ? `&slice=${sliceIndex}` : ''
    return json(
      `/api/phase/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}${sliceArg}`,
    )
  },

  refresh(): Promise<void> {
    return fetch('/api/refresh').then(() => undefined)
  },
}
