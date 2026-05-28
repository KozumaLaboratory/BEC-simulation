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

Two processes (Julia API on `:8090`, Vite dev server on `:9876`). On
this host (WSL2) **always** start Vite with the API target pinned to
the WSL2 external IP — see the loopback note below for why.

```bash
# Backend — first run precompiles for ~20 s. dist/index.html must exist.
julia --project=. -e 'using SpinorBEC; serve_dashboard(8090)'

# Frontend — first time only:  bun install
cd dashboard
VITE_API_TARGET=http://10.255.255.254:8090 bun run dev
```

URLs to open, in order of reliability on this host:

| URL | When to use |
|---|---|
| `http://10.255.255.254:9876/` | default — Vite HMR, loopback-independent |
| `https://anko-wsl.tailfd804.ts.net:9877/` | from another tailnet device (HTTPS via `tailscale serve` → WSL2 ext-IP → Vite) |
| `http://10.255.255.254:8090/` | Julia-only, no HMR; minimal process count |
| `http://localhost:9876/` | only after confirming loopback works (see below) |

Stop with `pkill -f vite` + `pkill -f 'julia.*serve_dashboard'`.

### WSL2 loopback footgun

On this host the kernel periodically loses the `127.0.0.1` route under
load. Symptom: `curl http://localhost:<port>` hangs and exits with
code 28 (000 status); `ss -tln` still shows the listener UP; the WSL2
external IP `10.255.255.254` keeps working.

When this happens, Vite's *default* proxy (`http://localhost:8090`)
returns 502 on every `/api/*` call.

Diagnosis from a shell:

```bash
curl -s -o /dev/null -w "%{http_code} (exit=%{exitcode})\n" \
     --max-time 5 http://127.0.0.1:8090/api/runs
# 200 → loopback OK.
# 000 (exit=28) → loopback DOWN. Use 10.255.255.254 in user-facing URLs
#                 AND set VITE_API_TARGET when starting Vite.
```

Backend listens on `0.0.0.0:8090` regardless, so it's reachable via
either address — only Vite's proxy lookup needs the working route.
The `VITE_API_TARGET` override is harmless when loopback is healthy,
so the recommended habit is to set it always rather than diagnose
per session.

### Auth (production / multi-user)

Web UI enqueue is write-capable, so once more than one person hits the
dashboard, put Caddy + Basic auth in front. Recipe + trust-model notes
are in [`docs/guides/dashboard_auth.md`](../docs/guides/dashboard_auth.md).

### Smoke test

After starting both processes:

```bash
# Use the external IP — loopback may be silently down.
curl -s -o /dev/null -w "Julia /api/runs    → %{http_code}\n" --max-time 5 http://10.255.255.254:8090/api/runs
curl -s -o /dev/null -w "Vite serve         → %{http_code}\n" --max-time 5 http://10.255.255.254:9876/
curl -s -o /dev/null -w "Vite-proxied /api  → %{http_code}\n" --max-time 8 http://10.255.255.254:9876/api/runs
```

All three should return `200`. The last one exercises the Vite → Julia
proxy path; if it returns `502` and the first one is `200`, the
`VITE_API_TARGET` override is the fix.

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
