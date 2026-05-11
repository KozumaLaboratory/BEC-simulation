# SpinorBEC dashboard (React + WebGPU)

Frontend for the Julia `serve_dashboard` backend. Replaces the previous
Plotly.js dashboard (`runs/tools/dashboard.html`) with:

- shadcn/ui + Tailwind v4 shell
- inline SVG line charts (`LineChartSVG`) for 2D series (energy / Mz /
  populations / timing) — Plotly.js was dropped 2026-04-26 to cut the
  ~4 MB bundle hit
- React Three Fiber + Three.js WebGPURenderer + TSL for 3D volume raymarch
- leva for live shader / render parameters

## Toolchain

Pinned via `dashboard/mise.toml`:

- Node 24
- bun 1.3

## Develop

```bash
# From dashboard/:
bun install
bun run dev
```

Vite dev server runs on <http://localhost:5173> and proxies `/api/*` to
the Julia dashboard server. Start the backend separately:

```bash
julia --project=. -e 'using SpinorBEC; serve_dashboard(8080)'
```

Override the proxy target with `VITE_API_TARGET=http://other-host:8080`.

## Production build

```bash
bun run build
```

Output goes to `dashboard/dist/`. `serve_dashboard` in Julia serves this
directory — it refuses to start if `dashboard/dist/index.html` is missing.
The legacy Plotly dashboard remains reachable at `/legacy` as long as
`runs/tools/dashboard.html` is on disk.

## Browser support

Requires WebGPU for the 3D view:

- Chrome / Edge 113+
- Safari 17.4+ (macOS 14.4 / iOS 17.4) — enable "WebGPU" in Feature Flags
- Firefox Nightly with `dom.webgpu.enabled`

The 2D charts and data tabs work everywhere; the 3D tab shows an inline
fallback message when `navigator.gpu` is absent.
