import { useEffect, useRef, useState } from 'react'

/**
 * Per-component atlas: every snapshot's column density stacked
 * vertically into one Float32Array of length nx × ny × n_snaps.
 * Layout for sample (ix, iy, snap):
 *   data[ix + (iy + snap * ny) * nx]
 * Equivalently in shader space, sample at
 *   vec2(uv.x, (uv.y + snap) / n_snaps).
 */
export interface ColumnDensityAtlas {
  ready: boolean
  loaded: number
  total: number
  nx: number
  ny: number
  m_values: number[]
  axisLabels: string[]
  totalAtlas: Float32Array | null
  componentAtlases: Float32Array[]
}

const EMPTY: ColumnDensityAtlas = {
  ready: false,
  loaded: 0,
  total: 0,
  nx: 0,
  ny: 0,
  m_values: [],
  axisLabels: ['x', 'y'],
  totalAtlas: null,
  componentAtlases: [],
}

// Singleton worker — Vite handles the URL+module bundling. One worker
// can drive the parallel fetches for the whole dashboard; concurrent
// requests are serialised by the worker via `activeReqId`.
let workerSingleton: Worker | null = null
function getWorker(): Worker {
  if (workerSingleton) return workerSingleton
  workerSingleton = new Worker(
    new URL('@/workers/atlasWorker.ts', import.meta.url),
    { type: 'module' },
  )
  return workerSingleton
}

let nextReqId = 1

interface ProgressMsg { type: 'progress'; reqId: number; loaded: number; total: number }
interface ReadyMsg {
  type: 'ready'
  reqId: number
  nx: number
  ny: number
  m_values: number[]
  axisLabels: string[]
  totalAtlas: Float32Array
  componentAtlases: Float32Array[]
}
interface ErrorMsg { type: 'error'; reqId: number; message: string }
type WorkerMsg = ProgressMsg | ReadyMsg | ErrorMsg

/**
 * Bulk-fetch every snap of a column density via a Web Worker; the
 * Float32Array atlases are transferred (zero-copy) back into the main
 * thread once assembled. Keeps the main thread free of fetch + decode
 * jank during the load, so the 3D viewer / sidebar stay responsive
 * while the user just opened a new run.
 */
export function useColumnDensityAtlas(
  run: string | null,
  file: string | null,
  axis: 1 | 2 | 3,
  totalSnaps: number,
): ColumnDensityAtlas {
  const [state, setState] = useState<ColumnDensityAtlas>(EMPTY)
  const reqRef = useRef<number>(0)

  useEffect(() => {
    if (!run || !file || totalSnaps <= 0) {
      setState(EMPTY)
      return
    }
    const w = getWorker()
    const reqId = nextReqId++
    reqRef.current = reqId
    setState({ ...EMPTY, total: totalSnaps })

    const onMessage = (event: MessageEvent<WorkerMsg>) => {
      const msg = event.data
      if (msg.reqId !== reqRef.current) return
      if (msg.type === 'progress') {
        setState((prev) => ({ ...prev, loaded: msg.loaded, total: msg.total }))
      } else if (msg.type === 'ready') {
        setState({
          ready: true,
          loaded: totalSnaps,
          total: totalSnaps,
          nx: msg.nx,
          ny: msg.ny,
          m_values: msg.m_values,
          axisLabels: msg.axisLabels,
          totalAtlas: msg.totalAtlas,
          componentAtlases: msg.componentAtlases,
        })
      } else if (msg.type === 'error') {
        setState((prev) => ({ ...prev, ready: false }))
      }
    }
    w.addEventListener('message', onMessage)
    w.postMessage({ type: 'fetch', reqId, run, file, axis, totalSnaps })

    return () => {
      w.removeEventListener('message', onMessage)
      w.postMessage({ type: 'cancel', reqId })
    }
  }, [run, file, axis, totalSnaps])

  return state
}
