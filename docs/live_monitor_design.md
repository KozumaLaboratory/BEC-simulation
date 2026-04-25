# Live monitoring — design note

Status: **scaffold / deferred** (Phase 5.4, Scenario #67).

The lab-side live-monitor socket adds a push endpoint to the existing
dashboard so a pickup script on the experiment PC can ship absorption
images, and the dashboard can overlay those onto the matching simulation
snapshot. ~300 lines once polished, but the data format + auth model
need pinning down before code lands.

## Existing infrastructure

- `serve_dashboard(port)` in `src/workflow/io/dashboard.jl` — HTTP server
  listening on `port`, serves the Vite-built React UI from `web/dist/`.
- WebGPU 3D raymarch already loads `dynamics/psi_snapshots_streamed/...`
  from `runs/<run>/<point>.jld2` over HTTP.

## What's missing

1. **POST endpoint** `/api/lab/image` accepting a multipart upload with:
    - PNG / FITS / NPZ payload (column density at the imaging plane)
    - JSON sidecar: `{shot_id, timestamp, axis, exposure_ms, ROI, ...}`

2. **In-memory ring buffer** per active run that holds the most recent
    N lab images for the dashboard to fetch.

3. **Sim-vs-lab overlay** in the React 3D view: render the lab image as
    a textured plane at the imaging axis, with a slider to scrub through
    the simulation timeline.

4. **Auth**: bearer token in `~/.spinorbec/lab_token` checked on POST.
    No cross-origin POST without it.

## Recommended approach for next session

- Start CPU-only: server just stores incoming PNGs to
  `runs/<run>/lab_images/shot_XXXXX.png` and serves them via the existing
  static file route.
- Skip auth for v0 (assume LAN-only), revisit if exposed beyond loopback.
- Defer the React overlay — first prove the round-trip works with a
  curl POST + an `<img>` tag.

## Recommendation

Punt this to a session where the lab PC is also live and we can iterate
on the overlay UX. Pure code-only scaffolding here would risk landing the
wrong API.
