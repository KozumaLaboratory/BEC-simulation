/// <reference lib="webworker" />
//
// Bulk-loads a column-density atlas for a run. Uses the
// /api/density_atlas endpoint which returns every snap in one binary
// blob so we avoid 157× HTTP round-trips. Falls back to per-snap
// /api/density_bin parallel fetches only if the bulk endpoint isn't
// available (older dashboards).

interface AtlasReq {
  type: 'fetch'
  reqId: number
  run: string
  file: string
  axis: 1 | 2 | 3
  totalSnaps: number
}

interface CancelReq {
  type: 'cancel'
  reqId: number
}

type Req = AtlasReq | CancelReq

let activeReqId = -1

self.addEventListener('message', (event: MessageEvent<Req>) => {
  const msg = event.data
  if (msg.type === 'cancel') {
    if (msg.reqId === activeReqId) activeReqId = -1
    return
  }
  if (msg.type === 'fetch') {
    activeReqId = msg.reqId
    void runFetch(msg)
  }
})

async function runFetch(req: AtlasReq) {
  const { reqId, run, file, axis, totalSnaps } = req
  // Attempt the bulk endpoint first; if it isn't there we fall back.
  try {
    const res = await fetch(
      `/api/density_atlas/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}`,
    )
    if (activeReqId !== reqId) return
    if (res.ok) {
      const buf = await res.arrayBuffer()
      const decoded = decodeAtlas(buf)
      if (decoded === null) {
        self.postMessage({ type: 'error', reqId, message: 'atlas decode failed' })
        return
      }
      // Single ready event covers the whole load.
      self.postMessage(
        { type: 'progress', reqId, loaded: totalSnaps, total: totalSnaps },
      )
      const transfers: Transferable[] = [
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (decoded.totalAtlas as any).buffer as ArrayBuffer,
      ]
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      for (const a of decoded.componentAtlases as any[]) {
        transfers.push(a.buffer as ArrayBuffer)
      }
      self.postMessage(
        {
          type: 'ready',
          reqId,
          nx: decoded.nx,
          ny: decoded.ny,
          m_values: decoded.m_values,
          axisLabels: decoded.axisLabels,
          totalAtlas: decoded.totalAtlas,
          componentAtlases: decoded.componentAtlases,
        },
        transfers,
      )
      return
    }
  } catch {
    // Fall through to per-snap fallback below.
  }
  // Legacy fallback: parallel per-snap fetches.
  await runFetchPerSnap(req)
}

interface DecodedAtlas {
  nx: number
  ny: number
  m_values: number[]
  axisLabels: string[]
  totalAtlas: Float32Array
  componentAtlases: Float32Array[]
}

function decodeAtlas(buf: ArrayBuffer): DecodedAtlas | null {
  if (buf.byteLength < 32) return null
  const magic = new Uint8Array(buf, 0, 4)
  if (magic[0] !== 0x44 || magic[1] !== 0x41 || magic[2] !== 0x54 || magic[3] !== 0x4c) {
    return null // not "DATL"
  }
  const hdr = new Int32Array(buf, 4, 7)
  const n_snaps = hdr[0]
  const ax = hdr[2]
  const nx = hdr[3]
  const ny = hdr[4]
  const n_comp = hdr[5]
  let off = 32
  off += 16 // skip axis_ranges
  const m_values = Array.from(new Int32Array(buf, off, n_comp))
  off += n_comp * 4
  const planeFloats = nx * ny
  const slabFloats = planeFloats * n_snaps
  const slabBytes = slabFloats * 4
  // The shader expects the Float32Array buffers to remain mapped to the
  // raw response payload — but we call .slice() because the response
  // ArrayBuffer would otherwise pin the entire 46 MB blob alive whenever
  // we retain a per-panel view.
  const totalAtlas = new Float32Array(buf, off, slabFloats).slice()
  off += slabBytes
  const componentAtlases: Float32Array[] = []
  for (let c = 0; c < n_comp; c++) {
    componentAtlases.push(new Float32Array(buf, off, slabFloats).slice())
    off += slabBytes
  }
  const axisLabels = ax === 1 ? ['y', 'z'] : ax === 2 ? ['x', 'z'] : ['x', 'y']
  return { nx, ny, m_values, axisLabels, totalAtlas, componentAtlases }
}

// --- Legacy fallback: per-snap parallel fetches ---
const PAR = 6

async function runFetchPerSnap(req: AtlasReq) {
  const { reqId, run, file, axis, totalSnaps } = req
  let nx = 0
  let ny = 0
  let m_values: number[] = []
  let axisLabels: string[] = ['x', 'y']
  let totalAtlas: Float32Array | null = null
  const box: { components: Float32Array[] } = { components: [] }
  let loaded = 0

  const installFrame = (snap: number, frame: Awaited<ReturnType<typeof fetchOne>>) => {
    if (frame === null) {
      loaded += 1
      return
    }
    if (totalAtlas === null) {
      nx = frame.nx
      ny = frame.ny
      m_values = frame.m_values
      axisLabels = frame.axis_labels
      totalAtlas = new Float32Array(nx * ny * totalSnaps)
      box.components = frame.densities.map(() => new Float32Array(nx * ny * totalSnaps))
    }
    const slabSize = nx * ny
    const slabOffset = (snap - 1) * slabSize
    totalAtlas!.set(frame.total_density, slabOffset)
    for (let c = 0; c < box.components.length; c++) {
      box.components[c].set(frame.densities[c], slabOffset)
    }
    loaded += 1
    self.postMessage({ type: 'progress', reqId, loaded, total: totalSnaps })
  }

  let next = 1
  const workers = new Array(PAR).fill(0).map(async function pump() {
    while (activeReqId === reqId) {
      const snap = next++
      if (snap > totalSnaps) return
      const frame = await fetchOne(run, file, axis, snap)
      if (activeReqId !== reqId) return
      installFrame(snap, frame)
    }
  })
  await Promise.all(workers)

  if (activeReqId !== reqId) return
  if (totalAtlas === null) {
    self.postMessage({ type: 'error', reqId, message: 'no frames loaded' })
    return
  }
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const totalAny = totalAtlas as any
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const compsAny = box.components as any[]
  const transfers: Transferable[] = [(totalAny as any).buffer as ArrayBuffer]
  for (const arr of compsAny) {
    transfers.push(arr.buffer as ArrayBuffer)
  }
  self.postMessage(
    {
      type: 'ready',
      reqId,
      nx,
      ny,
      m_values,
      axisLabels,
      totalAtlas,
      componentAtlases: box.components,
    },
    transfers,
  )
}

interface FrameDecoded {
  nx: number
  ny: number
  m_values: number[]
  axis_labels: string[]
  total_density: Float32Array
  densities: Float32Array[]
}

async function fetchOne(
  run: string,
  file: string,
  axis: 1 | 2 | 3,
  snap: number,
): Promise<FrameDecoded | null> {
  try {
    const url = `/api/density_bin/${encodeURIComponent(run)}/${encodeURIComponent(file)}?axis=${axis}&snap=${snap}`
    const res = await fetch(url)
    if (!res.ok) return null
    const buf = await res.arrayBuffer()
    const header = new Int32Array(buf, 0, 6)
    const ax = header[1]
    const nx = header[2]
    const ny = header[3]
    const n_comp = header[4]
    let off = 24 + 16
    const m_values = Array.from(new Int32Array(buf, off, n_comp))
    off += n_comp * 4
    const total_density = new Float32Array(buf, off, nx * ny).slice()
    off += nx * ny * 4
    const dens_flat = new Float32Array(buf, off, n_comp * nx * ny)
    const densities: Float32Array[] = []
    for (let c = 0; c < n_comp; c++) {
      densities.push(dens_flat.slice(c * nx * ny, (c + 1) * nx * ny))
    }
    const axis_labels = ax === 1 ? ['y', 'z'] : ax === 2 ? ['x', 'z'] : ['x', 'y']
    return { nx, ny, m_values, axis_labels, total_density, densities }
  } catch {
    return null
  }
}
