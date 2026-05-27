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

Two processes are required. From the repo root:

```bash
# Terminal 1 — Julia HTTP backend (default port 8090).
julia --project=. -e 'using SpinorBEC; serve_dashboard(8090)'

# Terminal 2 — Vite dev server (default port 9876, binds 0.0.0.0).
cd dashboard
bun install   # first time only
bun run dev
```

Then open <http://localhost:9876/>. Vite proxies `/api/*` to the Julia
backend per `vite.config.ts` (`VITE_API_TARGET`, default
`http://localhost:8090`).

### Tailscale HTTPS (WSL2 setup)

`tailscale serve` is preconfigured on `anko-wsl` to terminate HTTPS at
`https://anko-wsl.tailfd804.ts.net:9877` and reverse-proxy to
`http://10.255.255.254:9876` (the WSL2 external-facing IP). After
starting both processes above, the dashboard is reachable from any
tailnet device at:

```
https://anko-wsl.tailfd804.ts.net:9877/
```

**WSL2 loopback footgun** — on this host the kernel periodically loses
the `127.0.0.1` route under load. Symptom: `nc -z 127.0.0.1 <any-port>`
hangs, while `nc -z 10.255.255.254 <port>` succeeds, even though
`ss -tln` shows the listener up. When this happens, `vite.config.ts`'s
default proxy target (`http://localhost:8090`) breaks and `/api/*`
returns 502.

Workaround: override the API target to the WSL2 external IP for the
Vite session:

```bash
VITE_API_TARGET=http://10.255.255.254:8090 bun run dev
```

Backend still listens on `0.0.0.0:8090`, so it is reachable via either
address — only Vite's proxy lookup needs the working route.

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
