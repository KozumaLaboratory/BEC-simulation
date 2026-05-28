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

export interface Phase3D {
  nx: number
  ny: number
  nz: number
  n_comp: number
  F: number
  component: number
  populations: Float32Array
  phase: Float32Array // radians, [-π, π]
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

export interface SnapshotsMeta {
  n_snapshots: number
  times: number[]
  shape?: number[]
  /** Global peak total density across all snapshots (spin-summed).
   * Used by the 3D viewer for absolute-scale normalisation so the
   * volume render stays the same physical size frame-to-frame. */
  density_max_total?: number
}

export interface DynamicsSeries {
  has_dynamics: boolean
  times?: number[]
  energies?: number[]
  magnetizations?: number[]
  norms?: number[]
  pop_top?: number[]
  pop_mid?: number[]
}

export interface AutopilotQueueResponse {
  autopilot: { dry_run: boolean; paused: boolean }
  pending: AutopilotQueueEntry[]
  running: AutopilotQueueEntry[]
  done: AutopilotQueueEntry[]
  killed_data: AutopilotQueueEntry[]
  killed_bug: AutopilotQueueEntry[]
}

export interface EnqueueFinding {
  kind: string
  severity: 'info' | 'warn' | 'error' | 'block'
  step_index: number
  title: string
}

export interface EnqueuePreviewResponse {
  ok: true
  preview: true
  content_id: string
  profile: string
  estimated_walltime_hours: number
  inspector: {
    block_count: number
    warn_count: number
    error_count: number
    blocked: EnqueueFinding[]
    warned: EnqueueFinding[]
    errored: EnqueueFinding[]
  }
  budget: {
    available: boolean
    allow?: boolean
    reason?: string
    realized?: number
    predicted?: number
    quarter_cap?: number
    daily_cap?: number
  }
}

export interface EnqueueCommitResponse {
  ok: true
  preview: false
  content_id: string
  status: 'pending'
  autonomy_level: 'suggest' | 'propose' | 'dispatch'
  backend: 'local' | 'slurm'
  profile: string
  run_dir: string
  enqueued_by: string
}

export interface EnqueueErrorResponse {
  ok: false
  error: string
}

export interface EnqueueRequest {
  preview: boolean
  yaml: string
  backend?: 'local' | 'slurm'
  priority?: number
  autonomy_level?: 'suggest' | 'propose' | 'dispatch'
  recipe_name?: string
  recipe_params?: Record<string, unknown>
  profile?: string
  estimated_walltime_hours?: number
  session_id?: string
}

export interface QueueActionResponse {
  ok: true
  content_id: string
  status: 'pending' | 'killed_bug'
  autonomy_level?: 'suggest' | 'propose' | 'dispatch'
  action: 'promote' | 'cancel'
}

export interface QueueActionErrorResponse {
  ok: false
  error: string
}

export interface AutopilotQueueEntry {
  content_id: string
  status: 'pending' | 'running' | 'done' | 'killed_data' | 'killed_bug'
  kill_reason: string
  attempt: number
  priority: number
  enqueued_at: string
  enqueued_by: string
  parent_id: string | null
  recipe: { name: string | null; autonomy_level: 'suggest' | 'propose' | 'dispatch' }
  backend: {
    type: 'local' | 'slurm'
    job_id: string | null
    profile: string
    estimated_walltime_hours: number
  }
  budget: { gpu_hours_realized: number }
  run_dir: string
}

export interface VortexLine {
  m: string // "+5", "-3", "0"
  charge: number // ±1, ±2, ...
  points: number[][] // [[x, y, z], ...] in physical (Julia) coords
}

export interface VortexLinesResponse {
  lines: VortexLine[]
  box: number[]
  n_lines: number
}

export interface PhaseSlice {
  ndim: number
  axis: number
  slice_index: number
  shape: number[]
  box: number[]
  axis_labels: string[]
  axis_ranges: number[][]
  m_values: number[]
  // Typed arrays: skip the Array.from() copy on the hot scrubbing path.
  // Plotly heatmap accepts typed arrays for its z field directly.
  phases: Float32Array[] // per-component flat arrays, values in [-π, π]
  densities: Float32Array[] // per-component |ψ|² at the same slice, for low-density masking
}

export interface ColumnDensity {
  ndim: number
  axis: number
  shape: number[] // 2D: [nx, ny]
  box: number[]
  axis_labels: string[] // remaining axes, e.g. ["x", "y"]
  axis_ranges: number[][] // [[x_min,x_max], [y_min,y_max]]
  m_values: number[]
  total_density: Float32Array // flat length shape[0]*shape[1]
  densities: Float32Array[] // per-component flat arrays
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

async function _post<TResp>(url: string, body: unknown): Promise<TResp> {
  // Tolerate non-2xx responses — handlers return structured errors as
  // JSON, and the caller surfaces them in the UI. Only network failures
  // throw.
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const text = await r.text()
  try {
    return JSON.parse(text) as TResp
  } catch {
    return { ok: false, error: `non-JSON ${r.status}: ${text}` } as unknown as TResp
  }
}

export const api = {
  listRuns(): Promise<string[]> {
    return json('/api/runs')
  },

  getRunData(name: string): Promise<DashboardData> {
    return json(`/api/data/${encodeURIComponent(name)}`)
  },

  getVortexLines(
    run: string,
    file: string,
    snap?: number,
    mask = 0.01,
  ): Promise<VortexLinesResponse> {
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    return json(
      `/api/vortex_lines/${encodeURIComponent(run)}/${encodeURIComponent(file)}?mask=${mask}${snapArg}`,
    )
  },

  getDynamicsSeries(run: string, file: string): Promise<DynamicsSeries> {
    return json(
      `/api/dynamics_series/${encodeURIComponent(run)}/${encodeURIComponent(file)}`,
    )
  },

  getSnapshots(run: string, file: string): Promise<SnapshotsMeta> {
    return json(
      `/api/snapshots/${encodeURIComponent(run)}/${encodeURIComponent(file)}`,
    )
  },

  /** Lab image ring buffer for the live monitor (#67). Returns an
   * array of recently-uploaded shots for the run, most recent first.
   * Each entry has `url` ready to drop into <img src=…>. */
  listLabImages(
    run: string,
    limit = 32,
  ): Promise<Array<{ name: string; url: string; mtime_ms: number; size: number }>> {
    return json(
      `/api/lab/list/${encodeURIComponent(run)}?limit=${limit}`,
    )
  },

  /** Live status snapshot for an in-progress run. Returns the latest
   * step / energy / Mz / populations the simulator wrote to its
   * `_live_status.json`. 404 when the run isn't actively writing. */
  liveStatus(run: string): Promise<{
    step: number
    t: number
    energy: number
    norm: number
    populations: number[]
    updated_ms: number
  }> {
    return json(`/api/live/${encodeURIComponent(run)}`)
  },

  /** Returns runs whose live status was touched in the last 5 minutes —
   * the dashboard's "what's running right now" panel polls this. */
  listLiveRuns(): Promise<Array<{ run: string; mtime_ms: number; age_s: number }>> {
    return json('/api/live/list')
  },

  /** Returns the autopilot queue state across the 5-state model plus
   * the global `autopilot` flags (dry_run, paused). */
  autopilotQueue(): Promise<AutopilotQueueResponse> {
    return json('/api/queue')
  },

  /** Preview an enqueue. Returns content_id, inspector findings, and
   * budget impact WITHOUT writing state.toml. */
  autopilotEnqueuePreview(
    req: Omit<EnqueueRequest, 'preview'>,
  ): Promise<EnqueuePreviewResponse | EnqueueErrorResponse> {
    return _post('/api/queue/enqueue', { ...req, preview: true })
  },

  /** Commit an enqueue to disk. Refused if inspector returns any :block. */
  autopilotEnqueueCommit(
    req: Omit<EnqueueRequest, 'preview'>,
  ): Promise<EnqueueCommitResponse | EnqueueErrorResponse> {
    return _post('/api/queue/enqueue', { ...req, preview: false })
  },

  /** Promote a :propose entry to :dispatch, or cancel a :pending entry.
   * Refused for any non-:pending entry. */
  autopilotAction(
    content_id: string,
    action: 'promote' | 'cancel',
    session_id?: string,
  ): Promise<QueueActionResponse | QueueActionErrorResponse> {
    return _post('/api/queue/action', { content_id, action, session_id })
  },

  /** Per-run scan progress: how many `point_NNN.jld2` files have landed
   * vs. the total number of points the YAML scan block plans, plus a
   * naive linear ETA based on the spread between the first and last
   * completed point's mtimes. `expected` is null for a single-point
   * (no scan block) run. */
  scanStatus(run: string): Promise<{
    completed: number
    expected: number | null
    latest_mtime_s: number | null
    eta_s: number | null
  }> {
    return json(`/api/scan_status/${encodeURIComponent(run)}`)
  },

  /** 3D density atlas: one binary blob containing every snap's full
   * 3D density volume for one component. Layout matches the backend's
   * "D3AT" packer (see /api/density3d_atlas). Returns the per-snap
   * slabs already broken into Float32Array views — feed each one into
   * a `THREE.Data3DTexture(slab, nx, ny, nz)` to scrub by texture
   * swap instead of fetch + upload. */
  async getDensity3dAtlas(
    run: string,
    file: string,
    component = 0,
  ): Promise<{
    nx: number
    ny: number
    nz: number
    n_snaps: number
    n_comp: number
    F: number
    component: number
    snaps: Float32Array[]
  }> {
    const buf = await bin(
      `/api/density3d_atlas/${encodeURIComponent(run)}/${encodeURIComponent(file)}?comp=${component}`,
    )
    // "D3AT" magic (4) + 6 Int32 header (24) = 28 byte header
    const magic = new Uint8Array(buf, 0, 4)
    if (
      magic[0] !== 0x44 ||
      magic[1] !== 0x33 ||
      magic[2] !== 0x41 ||
      magic[3] !== 0x54
    ) {
      throw new Error('density3d_atlas: bad magic')
    }
    const hdr = new Int32Array(buf, 4, 6)
    const n_snaps = hdr[0]
    const nx = hdr[1]
    const ny = hdr[2]
    const nz = hdr[3]
    const n_comp = hdr[4]
    const comp = hdr[5]
    const slabFloats = nx * ny * nz
    const slabBytes = slabFloats * 4
    const snaps: Float32Array[] = []
    let off = 28
    for (let s = 0; s < n_snaps; s++) {
      snaps.push(new Float32Array(buf, off, slabFloats).slice())
      off += slabBytes
    }
    return { nx, ny, nz, n_snaps, n_comp, F: 0, component: comp, snaps }
  },

  /** Synthetic-dimension dispersion image (k_real × k_synth). Wraps
   * the backend's /api/synthetic_dispersion endpoint, which packs the
   * spectrum into the same Float32-binary layout as a column density
   * with n_comp=0 (the spectrum lives in the `total_density` slot).
   * Returns nx = number of points along the chosen real axis,
   * ny = D = 2F+1 (synthetic axis length). */
  async getSyntheticDispersion(
    run: string,
    file: string,
    axis: 1 | 2 | 3,
    snap?: number,
  ): Promise<{ nx: number; ny: number; spectrum: Float32Array }> {
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    const buf = await bin(
      `/api/synthetic_dispersion/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}${snapArg}`,
    )
    const header = new Int32Array(buf, 0, 6)
    const nx = header[2]
    const ny = header[3]
    // Skip header (24) + axis_ranges (16) — n_comp=0 so no m_values.
    const spectrum = new Float32Array(buf, 40, nx * ny).slice()
    return { nx, ny, spectrum }
  },

  /** Lazy companion to getSnapshots: the global peak total density
   * across all snapshots. Used by the 3D viewer for absolute-scale
   * normalisation. Computing it server-side walks 16 sampled frames,
   * so it lives behind its own endpoint to keep snapshots metadata
   * instant. */
  async getDensityMax(run: string, file: string): Promise<number> {
    const d = await json<{ density_max_total?: number; error?: string }>(
      `/api/density_max/${encodeURIComponent(run)}/${encodeURIComponent(file)}`,
    )
    return typeof d.density_max_total === 'number' ? d.density_max_total : 1
  },

  async getVorticity3d(run: string, file: string, snap?: number): Promise<Density3D> {
    // Returns scalar |∇×v_s| in the same binary layout as density3d_bin,
    // so the consumer path can be reused without a separate type.
    const snapArg = snap !== undefined ? `?snap=${snap}` : ''
    const buf = await bin(
      `/api/vorticity3d_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}${snapArg}`,
    )
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

  async getDensity3d(
    run: string,
    file: string,
    component = 0,
    angleDeg = 0,
    snap?: number,
  ): Promise<Density3D> {
    // Rotation only matters for per-component requests; the total density
    // (component=0) is invariant under quantization-axis rotation.
    const useRotated = component > 0 && Math.abs(angleDeg) > 0.01
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    const url = useRotated
      ? `/api/density3d_rotated/${encodeURIComponent(run)}/${encodeURIComponent(file)}?angle=${angleDeg}&comp=${component}${snapArg}`
      : `/api/density3d_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?comp=${component}${snapArg}`
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
    snap?: number,
  ): Promise<VectorField3D> {
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    const buf = await bin(
      `/api/vector3d_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?field=${field}&stride=${stride}${snapArg}`,
    )
    const header = new Int32Array(buf, 0, 7)
    const nx = header[0],
      ny = header[1],
      nz = header[2],
      s = header[3]
    const data = new Float32Array(buf, 28, nx * ny * nz * 4)
    return { nx, ny, nz, stride: s, data }
  },

  async getColumnDensity(
    run: string,
    file: string,
    axis: 1 | 2 | 3,
    snap?: number,
  ): Promise<ColumnDensity> {
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    type RawColumnDensity = Omit<ColumnDensity, 'total_density' | 'densities'> & {
      total_density: number[]
      densities: number[][]
    }
    const d = await json<RawColumnDensity>(
      `/api/density/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}${snapArg}`,
    )
    return {
      ...d,
      total_density: Float32Array.from(d.total_density),
      densities: d.densities.map((arr) => Float32Array.from(arr)),
    }
  },

  /** Binary column density — same shape as ColumnDensity but ~7× smaller
   * over the wire and skips JSON.parse, so the time-scrubber can render
   * frames at <20 ms per request. Falls back to numeric arrays the rest
   * of the SlicePanel was already written against. */
  async getColumnDensityBin(
    run: string,
    file: string,
    axis: 1 | 2 | 3,
    snap?: number,
  ): Promise<ColumnDensity> {
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    const buf = await bin(
      `/api/density_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}${snapArg}`,
    )
    const header = new Int32Array(buf, 0, 6)
    const ndim = header[0],
      ax = header[1],
      nx = header[2],
      ny = header[3],
      n_comp = header[4]
    let off = 24
    const ranges = new Float32Array(buf, off, 4)
    off += 16
    const m_values = Array.from(new Int32Array(buf, off, n_comp))
    off += n_comp * 4
    // Copy out of the response buffer so the underlying ArrayBuffer can
    // be GC'd. `slice()` on a Float32Array view is a single memcpy and
    // far cheaper than the per-element Array.from we used before.
    const total = new Float32Array(buf, off, nx * ny).slice()
    off += nx * ny * 4
    const dens_flat = new Float32Array(buf, off, n_comp * nx * ny)
    const densities: Float32Array[] = []
    for (let c = 0; c < n_comp; c++) {
      densities.push(dens_flat.slice(c * nx * ny, (c + 1) * nx * ny))
    }
    const axis_labels = ax === 1 ? ['y', 'z'] : ax === 2 ? ['x', 'z'] : ['x', 'y']
    return {
      ndim,
      axis: ax,
      shape: [nx, ny],
      box: [],
      axis_labels,
      axis_ranges: [
        [ranges[0], ranges[1]],
        [ranges[2], ranges[3]],
      ],
      m_values,
      total_density: total,
      densities,
    }
  },

  async getPhase3d(
    run: string,
    file: string,
    component: number,
    snap?: number,
  ): Promise<Phase3D> {
    if (component < 1) {
      throw new Error('phase3d requires component >= 1 (per-m only)')
    }
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    const buf = await bin(
      `/api/phase3d_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?comp=${component}${snapArg}`,
    )
    const header = new Int32Array(buf, 0, 6)
    const nx = header[0],
      ny = header[1],
      nz = header[2]
    const n_comp = header[3],
      F = header[4],
      comp = header[5]
    const populations = new Float32Array(buf, 24, n_comp)
    const phase = new Float32Array(buf, 24 + n_comp * 4, nx * ny * nz)
    return { nx, ny, nz, n_comp, F, component: comp, populations, phase }
  },

  async getPhaseSlice(
    run: string,
    file: string,
    axis: 1 | 2 | 3,
    sliceIndex?: number,
    snap?: number,
  ): Promise<PhaseSlice> {
    const sliceArg = sliceIndex !== undefined ? `&slice=${sliceIndex}` : ''
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    type RawPhaseSlice = Omit<PhaseSlice, 'phases' | 'densities'> & {
      phases: number[][]
      densities: number[][]
    }
    const d = await json<RawPhaseSlice>(
      `/api/phase/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}${sliceArg}${snapArg}`,
    )
    return {
      ...d,
      phases: d.phases.map((arr) => Float32Array.from(arr)),
      densities: d.densities.map((arr) => Float32Array.from(arr)),
    }
  },

  /** Binary phase slice — see getColumnDensityBin for motivation. */
  async getPhaseSliceBin(
    run: string,
    file: string,
    axis: 1 | 2 | 3,
    sliceIndex?: number,
    snap?: number,
  ): Promise<PhaseSlice> {
    const sliceArg = sliceIndex !== undefined ? `&slice=${sliceIndex}` : ''
    const snapArg = snap !== undefined ? `&snap=${snap}` : ''
    const buf = await bin(
      `/api/phase_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}${sliceArg}${snapArg}`,
    )
    const header = new Int32Array(buf, 0, 7)
    const ndim = header[0],
      ax = header[1],
      slice_index = header[2],
      nx = header[3],
      ny = header[4],
      n_comp = header[5]
    let off = 28
    const ranges = new Float32Array(buf, off, 4)
    off += 16
    const m_values = Array.from(new Int32Array(buf, off, n_comp))
    off += n_comp * 4
    const phases_flat = new Float32Array(buf, off, n_comp * nx * ny)
    off += n_comp * nx * ny * 4
    const dens_flat = new Float32Array(buf, off, n_comp * nx * ny)
    const phases: Float32Array[] = []
    const densities: Float32Array[] = []
    for (let c = 0; c < n_comp; c++) {
      phases.push(phases_flat.slice(c * nx * ny, (c + 1) * nx * ny))
      densities.push(dens_flat.slice(c * nx * ny, (c + 1) * nx * ny))
    }
    const axis_labels = ax === 1 ? ['y', 'z'] : ax === 2 ? ['x', 'z'] : ['x', 'y']
    return {
      ndim,
      axis: ax,
      slice_index,
      shape: [nx, ny],
      box: [],
      axis_labels,
      axis_ranges: [
        [ranges[0], ranges[1]],
        [ranges[2], ranges[3]],
      ],
      m_values,
      phases,
      densities,
    }
  },

  refresh(): Promise<void> {
    return fetch('/api/refresh').then(() => undefined)
  },

  getEnsemble(run: string, file: string): Promise<EnsembleSummary> {
    return json(
      `/api/ensemble/${encodeURIComponent(run)}/${encodeURIComponent(file)}`,
    )
  },

  /** Pre-run config inspector. Loads the run's config.yaml, runs the full
   * normalize_and_validate pipeline, samples the resolved B(t)/q(t)/Raman
   * for each step, and returns typed warnings for silent semantic
   * mismatches (e.g. `B.theta` dropped on split-step, ramp collapsed to
   * quench, Hz strings, rotating_frame_omega + GPU). Backed by the Julia
   * `inspect_config` function. */
  getEffectiveConfig(run: string): Promise<EffectiveConfig> {
    return json(`/api/effective_config/${encodeURIComponent(run)}`)
  },
}

// --- Effective-config inspector ----------------------------------------
// Mirrors src/workflow/experiments/inspect.jl::to_dict. Optional fields
// reflect the per-step variation in the Julia struct (analyze steps carry
// no traces; ground_state steps may have 1-sample traces).

export interface EffectiveConfigTrace {
  kind: string                            // "zeeman" | "raman"
  t: number[]
  channels: Record<string, number[]>       // e.g. bx, by, bz, q
}

export interface EffectiveConfigStep {
  index: number
  name: string                            // "ground_state" | "dynamics" | "analyze"
  kind: string                            // "split_step" | "rotating_basis" | "binary" | "analyze"
  duration: number
  params_summary: Record<string, unknown>
  traces: EffectiveConfigTrace[]
}

export interface EffectiveConfigWarning {
  kind: string
  severity: 'error' | 'warn' | 'info'
  step_index: number
  title: string
  message: string
  suggestion: string
  details: Record<string, unknown>
}

export interface EffectiveConfig {
  path: string
  raw: Record<string, unknown>
  normalised: Record<string, unknown>
  warnings: EffectiveConfigWarning[]
  steps: EffectiveConfigStep[]
}

// --- TWA ensemble summary (Round-2 Task 5) -------------------------------
// Mirrors `_compute_ensemble_summary` in src/workflow/io/dashboard/routes.jl.
// Heavy 3D mean/variance volumes are NOT included; this is the lightweight
// JSON the EnsemblePanel uses for time series + σ/μ histogram display.

export interface EnsembleHistogram {
  bin_edges: number[]
  counts: number[]
  n_voxels: number
  threshold_frac_of_peak: number
}

export interface EnsembleObservable {
  has_mean: boolean
  has_variance: boolean
  shape?: number[]
  // density-only scalar series (filled by _density_scalars!)
  peak_mean?: number[]
  on_axis_ratio_mean?: number[]
  peak_variance?: number[]
  sigma_over_mu_at_peak?: number[]
  sigma_over_mu_histogram?: EnsembleHistogram
}

export interface EnsemblePhase {
  phase_idx: number
  n_trajectories: number
  times: number[]
  observables: string[]
  // dictionary keyed by observable name, e.g. "density"
  [observable: string]: EnsembleObservable | number | number[] | string[] | undefined
}

export interface EnsembleSummary {
  phases: EnsemblePhase[]
  error?: string
}
