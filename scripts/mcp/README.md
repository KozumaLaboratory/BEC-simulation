# TSUBAME MCP server (Claude Desktop → TSUBAME 4)

Drive TSUBAME 4 (UGE) from the **Claude Desktop** app. The server is a thin
wrapper over the SSH alias `tsubame` and the project autopilot CLI
(`scripts/cli.jl autopilot ...`).

It runs **inside WSL** (where `~/.ssh`, the Julia project, `runs/`, and `rsync`
live); Claude Desktop on Windows launches it via `wsl.exe`. Transport: stdio.

```
Claude Desktop (Windows) ──stdio──▶ wsl.exe ──▶ tsubame_server.py (WSL)
                                                   │ ssh tsubame / rsync
                                                   │ cli.jl autopilot enqueue|tick
                                                   ▼
                                              TSUBAME 4 (UGE)
```

## Tools

| Tool | Kind | Wraps |
|---|---|---|
| `tsubame_qstat` | read | `ssh tsubame qstat` |
| `tsubame_job_detail` | read | `ssh tsubame qstat -j <id>` |
| `tsubame_points` | read | `ssh tsubame 't4-user-info group point'` |
| `tsubame_autopilot_status` | read | `cli.jl autopilot status` |
| `tsubame_budget` | read | `cli.jl autopilot budget` |
| `tsubame_list_runs` | read | local `runs/` listing |
| `tsubame_tail_log` | read | tail newest `logs/` file |
| `tsubame_pull_results` | write (local fs) | `rsync` remote runs → local `runs/` |
| `tsubame_enqueue` | write | `cli.jl autopilot enqueue <yaml>` |
| `tsubame_tick` | write | `cli.jl autopilot tick` (qsub dispatch — **spends points**) |
| `tsubame_cancel` | destructive | `ssh tsubame qdel <id>` |

`tsubame_tick` dispatch is gated server-side by the autopilot's budget caps +
circuit breakers; this server does not bypass them.

## One-time setup

### 1. Non-interactive SSH (required)

The server runs non-interactively — if the `tsubame` key has a passphrase or
2FA, every `ssh`/`rsync` call **hangs** unless a ControlMaster master
connection is already open. Add to the `Host tsubame` block in `~/.ssh/config`:

```sshconfig
Host tsubame
  # ... existing HostName / User / IdentityFile ...
  ControlMaster auto
  ControlPath ~/.ssh/controlmasters/%r@%h:%p
  ControlPersist 8h
  ServerAliveInterval 60
```

Then authenticate **once** per ~8h window (in a WSL terminal):

```bash
mkdir -p ~/.ssh/controlmasters && chmod 700 ~/.ssh/controlmasters   # once
ssh tsubame true      # type passphrase / 2FA here; opens the persistent master
```

All subsequent server `ssh tsubame …` / `rsync … tsubame:…` calls reuse this
socket with no prompt. (Alternative: a dedicated passphraseless key scoped to
this use — less secure, but enables fully unattended operation.)

### 2. Python env

```bash
cd /home/suzume/workspace/BEC-simulation
uv venv scripts/mcp/.venv --python 3.14
uv pip install --python scripts/mcp/.venv/bin/python mcp
```

### 3. Register with Claude Desktop

Settings → Developer → Edit Config (or edit
`%APPDATA%\Claude\claude_desktop_config.json` on Windows). Add:

```json
{
  "mcpServers": {
    "tsubame": {
      "command": "wsl.exe",
      "args": [
        "-d", "Ubuntu",
        "--", "bash", "-lc",
        "cd /home/suzume/workspace/BEC-simulation && set -a && source scripts/spinorbec.env && set +a && exec scripts/mcp/.venv/bin/python scripts/mcp/tsubame_server.py"
      ]
    }
  }
}
```

- Replace `Ubuntu` with your distro's registered name — check in PowerShell:
  `wsl -l -v`.
- `source scripts/spinorbec.env` injects `SPINORBEC_TSUBAME_*` so the autopilot
  UGE backend and `tsubame_pull_results` know the host / group / runs root.

Restart Claude Desktop. The 11 `tsubame_*` tools appear in the tools list.

## Configuration (env overrides)

Read from the process environment (set via `scripts/spinorbec.env` + the launch
command):

| Var | Default | Meaning |
|---|---|---|
| `SPINORBEC_TSUBAME_HOST` | `tsubame` | SSH alias |
| `SPINORBEC_TSUBAME_RUNS_ROOT` | (from env file) | remote runs root for pull |
| `SPINORBEC_PROJECT_DIR` | `…/BEC-simulation` | local project root |
| `SPINORBEC_LOCAL_JULIA` | juliaup 1.12.6 path | local Julia for `cli.jl` |
| `SPINORBEC_MCP_JULIA_TIMEOUT` | `900` | s; Julia pays a multi-minute JIT cascade |
| `SPINORBEC_MCP_SSH_TIMEOUT` | `30` | s |
| `SPINORBEC_MCP_RSYNC_TIMEOUT` | `600` | s |

## Notes

- **Julia tools are slow on cold start** (`autopilot_status` / `budget` /
  `enqueue` / `tick`) — the local Julia process pays a JIT cascade on first
  call. SSH tools (`qstat` / `points` / `cancel`) are fast.
- **Stop the autopilot systemd timer** before heavy concurrent local Julia work
  — `spinor-autopilot.timer` + concurrent JIT can crash WSL.
- Secrets never leave `~/.ssh`. The server passes no credentials.

## Smoke test (WSL, without Desktop)

```bash
cd /home/suzume/workspace/BEC-simulation
scripts/mcp/.venv/bin/python - <<'PY'
import asyncio, scripts.mcp.tsubame_server as s
print(s.mcp.name, len(asyncio.run(s.mcp.list_tools())), "tools")
PY
```
