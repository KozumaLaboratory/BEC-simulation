# Live monitoring — design note

> **FROZEN 2026-04-26.** Describes the tree as of that date and is **not maintained** against the code — do not cite it as current.
> Live sources: `CLAUDE.md`, `docs/index.md`, and the code itself. Audit: `docs/audit/docs_inventory_2026-08-04.md`.

Status: **partially implemented** (2026-04-26). The two halves of the "live monitor" idea were split and implemented separately:

- **Lab-image side (items 1-3 below): IMPLEMENTED.** `/api/lab/image` POST + `/api/lab/list` GET in `dashboard.jl` accept and serve `runs/<run>/lab_images/shot_*.png`; the React `LabImageOverlay` component renders them in the 3D view. Auth (item 4) is still deferred — server is LAN-only.
- **Simulation-observable streaming: IMPLEMENTED separately** via the YAML knob `dynamics.live_monitor: {every: N}` → `<run>/_live_status.json`. Two new dashboard endpoints `/api/live/list` and `/api/live/<run>` return the freshest status JSON. Frontend hooks `useLiveRuns` / `useLiveStatus` and component `LiveStatusPanel` render it in the App header. See `pipeline_runner.jl:_build_live_callback` for the writer side.

The original design note (kept below for context) imagined a single push socket; in practice splitting "lab pushes images" from "sim publishes status JSON" was simpler — both share the dashboard's static file route and an atomic-rename writer.

---

The lab-side live-monitor socket adds a push endpoint to the existing dashboard so a pickup script on the experiment PC can ship absorption images, and the dashboard can overlay those onto the matching simulation snapshot. ~300 lines once polished, but the data format + auth model need pinning down before code lands.

## Existing infrastructure

- `serve_dashboard(port)` in `src/workflow/io/dashboard.jl` — HTTP server listening on `port`, serves the Vite-built React UI from `dashboard/dist/`.
- WebGPU 3D raymarch already loads `dynamics/psi_snapshots_streamed/...` from `runs/<run>/<point>.jld2` over HTTP.

## What's missing

1. **POST endpoint** `/api/lab/image` accepting a multipart upload with:
    - PNG / FITS / NPZ payload (column density at the imaging plane)
    - JSON sidecar: `{shot_id, timestamp, axis, exposure_ms, ROI, ...}`

2. **In-memory ring buffer** per active run that holds the most recent N lab images for the dashboard to fetch.

3. **Sim-vs-lab overlay** in the React 3D view: render the lab image as a textured plane at the imaging axis, with a slider to scrub through the simulation timeline.

4. **Auth**: bearer token in `~/.spinorbec/lab_token` checked on POST. No cross-origin POST without it.

## Recommended approach for next session

- Start CPU-only: server just stores incoming PNGs to `runs/<run>/lab_images/shot_XXXXX.png` and serves them via the existing static file route.
- Skip auth for v0 (assume LAN-only), revisit if exposed beyond loopback.
- Defer the React overlay — first prove the round-trip works with a curl POST + an `<img>` tag.

## Recommendation

Punt this to a session where the lab PC is also live and we can iterate on the overlay UX. Pure code-only scaffolding here would risk landing the wrong API.
