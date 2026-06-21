#!/usr/bin/env python3
"""MCP server for driving TSUBAME 4 (UGE) from the Claude Desktop app.

Thin wrapper over the SSH alias `tsubame` and the project's autopilot CLI
(`scripts/cli.jl autopilot ...`). Runs inside WSL so it reuses the local
`~/.ssh` setup; the Desktop app launches it via `wsl.exe`.

Tool families:
  read-only   : qstat, job_detail, points, autopilot_status, budget, list_runs
  collect     : pull_results (rsync remote runs -> local runs/)
  submit      : enqueue (queue a config), tick (dispatch via qsub), cancel (qdel)

Submission is gated server-side by the autopilot's own budget caps and circuit
breakers — this server does not re-implement those guards.

Prerequisites (see scripts/mcp/README.md):
  * SSH alias `tsubame` resolves and authenticates NON-INTERACTIVELY
    (ControlMaster master connection established once, or a passphraseless key).
    Otherwise every ssh/rsync call hangs on a passphrase/2FA prompt.
  * `scripts/spinorbec.env` sourced into this process's environment
    (the Desktop launch command does `set -a; source scripts/spinorbec.env`).
"""

import asyncio
import os
import shlex
from enum import Enum
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("tsubame_mcp")

# ── Configuration (env-overridable) ──────────────────────────────────
HOST = os.environ.get("SPINORBEC_TSUBAME_HOST", "tsubame")
GROUP = os.environ.get("SPINORBEC_TSUBAME_GROUP", "")
RUNS_ROOT = os.environ.get("SPINORBEC_TSUBAME_RUNS_ROOT", "")
PROJECT_DIR = os.environ.get(
    "SPINORBEC_PROJECT_DIR", "/home/suzume/workspace/BEC-simulation"
)
LOCAL_JULIA = os.environ.get(
    "SPINORBEC_LOCAL_JULIA",
    "/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia",
)
LOCAL_RUNS = os.path.join(PROJECT_DIR, "runs")

# Julia commands pay a multi-minute JIT cascade; SSH calls are fast.
SSH_TIMEOUT = float(os.environ.get("SPINORBEC_MCP_SSH_TIMEOUT", "30"))
JULIA_TIMEOUT = float(os.environ.get("SPINORBEC_MCP_JULIA_TIMEOUT", "900"))
RSYNC_TIMEOUT = float(os.environ.get("SPINORBEC_MCP_RSYNC_TIMEOUT", "600"))

_AUTH_HINT = (
    "If this timed out, the SSH connection is likely blocked on a "
    "passphrase/2FA prompt (this server runs non-interactively). Open a WSL "
    f"terminal and run `ssh {HOST} true` once to establish a ControlMaster "
    "master connection (requires ControlMaster/ControlPersist in ~/.ssh/config), "
    "then retry."
)


class ResponseFormat(str, Enum):
    MARKDOWN = "markdown"
    JSON = "json"


# ── Shared subprocess helpers ────────────────────────────────────────
async def _run(argv: list[str], timeout: float, cwd: Optional[str] = None) -> dict:
    """Run argv (no shell), capture output. Returns rc/stdout/stderr/timed_out."""
    try:
        proc = await asyncio.create_subprocess_exec(
            *argv,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
            cwd=cwd,
            stdin=asyncio.subprocess.DEVNULL,
        )
    except FileNotFoundError as e:
        return {"rc": 127, "stdout": "", "stderr": f"command not found: {e.filename}",
                "timed_out": False}
    try:
        out, err = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError:
        proc.kill()
        await proc.wait()
        return {"rc": 124, "stdout": "", "stderr": "timed out", "timed_out": True}
    return {
        "rc": proc.returncode,
        "stdout": out.decode("utf-8", "replace"),
        "stderr": err.decode("utf-8", "replace"),
        "timed_out": False,
    }


async def _ssh(remote_cmd: str, timeout: float = SSH_TIMEOUT) -> dict:
    """Run a command on TSUBAME via the `tsubame` SSH alias, non-interactively."""
    argv = [
        "ssh", "-o", "BatchMode=yes", "-o", f"ConnectTimeout={int(min(timeout, 20))}",
        HOST, remote_cmd,
    ]
    return await _run(argv, timeout=timeout)


async def _julia_autopilot(sub_args: list[str], timeout: float = JULIA_TIMEOUT) -> dict:
    """Run `cli.jl autopilot <sub_args>` locally (drives the UGE backend)."""
    argv = [LOCAL_JULIA, "--project=.", "scripts/cli.jl", "autopilot", *sub_args]
    return await _run(argv, timeout=timeout, cwd=PROJECT_DIR)


def _fmt(res: dict, action: str) -> str:
    """Render a subprocess result as an actionable string."""
    if res["timed_out"]:
        return f"Error: `{action}` timed out after waiting. {_AUTH_HINT}"
    if res["rc"] != 0:
        tail = (res["stderr"] or res["stdout"]).strip()
        msg = f"Error: `{action}` failed (rc={res['rc']}).\n{tail}"
        if res["rc"] in (124, 255) or "Permission denied" in tail or not tail:
            msg += f"\n\n{_AUTH_HINT}"
        return msg
    body = res["stdout"].strip()
    return body if body else f"`{action}` succeeded (no output)."


# ── Input models ─────────────────────────────────────────────────────
class Empty(BaseModel):
    model_config = ConfigDict(extra="forbid")


class JobIdInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    job_id: str = Field(..., description="UGE job id from qstat (digits only, e.g. '7805552').",
                        min_length=1, max_length=20, pattern=r"^\d+$")


class JobDetailInput(JobIdInput):
    pass


class EnqueueInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    config_path: str = Field(
        ...,
        description="Path to a run config YAML, relative to the project root "
                    "(e.g. 'runs/eu151_edh_ext/config.yaml').",
        min_length=1, max_length=400,
    )
    priority: Optional[int] = Field(
        default=None, description="Optional queue priority (higher runs first).", ge=0, le=100
    )

    @field_validator("config_path")
    @classmethod
    def _no_escape(cls, v: str) -> str:
        if v.startswith("/") or ".." in v.split("/"):
            raise ValueError("config_path must be a project-relative path without '..'")
        if not v.endswith((".yaml", ".yml")):
            raise ValueError("config_path must point to a .yaml/.yml file")
        return v


class TailLogInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    lines: int = Field(default=40, description="Number of trailing lines to show.", ge=1, le=2000)
    pattern: Optional[str] = Field(
        default=None,
        description="Optional run-name substring to pick a specific log under logs/.",
        max_length=200,
    )


class PullInput(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    run_name: Optional[str] = Field(
        default=None,
        description="Optional run subdirectory under the runs root to pull "
                    "(e.g. 'eu151_edh_ext'). Omit to sync the whole runs tree.",
        max_length=200,
    )
    dry_run: bool = Field(default=False, description="Preview the transfer without copying.")

    @field_validator("run_name")
    @classmethod
    def _safe_name(cls, v: Optional[str]) -> Optional[str]:
        if v and (v.startswith("/") or ".." in v.split("/")):
            raise ValueError("run_name must be a simple subdirectory without '/' prefix or '..'")
        return v


class ListRunsInput(BaseModel):
    model_config = ConfigDict(extra="forbid")
    limit: int = Field(default=50, description="Max run directories to list.", ge=1, le=500)


# ── Read-only tools ──────────────────────────────────────────────────
@mcp.tool(
    name="tsubame_qstat",
    annotations={"title": "List TSUBAME jobs", "readOnlyHint": True,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": True},
)
async def tsubame_qstat(params: Empty) -> str:
    """List the current user's jobs on TSUBAME 4 via `qstat`.

    Returns the raw `qstat` listing (job-ID, name, state, queue, submit/start
    time, slots). State column: r=running, qw=queued/waiting, Eqw=error,
    dr/dt=deleting. Use tsubame_job_detail for one job's full record.

    Args:
        params (Empty): no parameters.

    Returns:
        str: the `qstat` table, or "Error: ..." with an auth hint on failure.
    """
    return _fmt(await _ssh("qstat"), "qstat")


@mcp.tool(
    name="tsubame_job_detail",
    annotations={"title": "TSUBAME job detail", "readOnlyHint": True,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": True},
)
async def tsubame_job_detail(params: JobDetailInput) -> str:
    """Show the full UGE record for one job via `qstat -j <id>`.

    Note: `qstat -j` output has NO job_state field — use tsubame_qstat for
    live state. This is for submission args, resource request, error reason.

    Args:
        params (JobDetailInput): job_id (digits).

    Returns:
        str: the `qstat -j` detail block, or an "Error: ..." string.
    """
    return _fmt(await _ssh(f"qstat -j {shlex.quote(params.job_id)}"), f"qstat -j {params.job_id}")


@mcp.tool(
    name="tsubame_points",
    annotations={"title": "TSUBAME group point balance", "readOnlyHint": True,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": True},
)
async def tsubame_points(params: Empty) -> str:
    """Show the compute-group point balance via `t4-user-info group point`.

    Points are the TSUBAME billing currency drained by `-g <group>` jobs.
    Check before large submissions.

    Args:
        params (Empty): no parameters.

    Returns:
        str: the point-balance table, or an "Error: ..." string.
    """
    return _fmt(await _ssh("t4-user-info group point"), "t4-user-info group point")


@mcp.tool(
    name="tsubame_autopilot_status",
    annotations={"title": "Autopilot queue status", "readOnlyHint": True,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": True},
)
async def tsubame_autopilot_status(params: Empty) -> str:
    """Show the local autopilot queue + dispatch state (`cli.jl autopilot status`).

    Reflects what the autopilot has queued / dispatched / completed. Slow on a
    cold start: the local Julia process pays a multi-minute JIT cascade.

    Args:
        params (Empty): no parameters.

    Returns:
        str: the autopilot status report, or an "Error: ..." string.
    """
    return _fmt(await _julia_autopilot(["status"]), "autopilot status")


@mcp.tool(
    name="tsubame_budget",
    annotations={"title": "Autopilot GPU-hour budget", "readOnlyHint": True,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": True},
)
async def tsubame_budget(params: Empty) -> str:
    """Show the autopilot's GPU-hour budget gate (`cli.jl autopilot budget`).

    Reports quarter + daily caps and realized usage. Submissions are blocked
    by this gate when caps are hit. Slow on cold start (Julia JIT).

    Args:
        params (Empty): no parameters.

    Returns:
        str: the budget report, or an "Error: ..." string.
    """
    return _fmt(await _julia_autopilot(["budget"]), "autopilot budget")


@mcp.tool(
    name="tsubame_list_runs",
    annotations={"title": "List local run directories", "readOnlyHint": True,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": False},
)
async def tsubame_list_runs(params: ListRunsInput) -> str:
    """List run directories under the local `runs/` tree (most-recent first).

    These are the local mirrors that tsubame_pull_results syncs into. Use to
    find a run_name to pull or a config_path to enqueue.

    Args:
        params (ListRunsInput): limit (max entries).

    Returns:
        str: newline-separated "mtime  name" rows, or a notice if runs/ is empty.
    """
    if not os.path.isdir(LOCAL_RUNS):
        return f"No local runs directory at {LOCAL_RUNS}."
    entries = []
    with os.scandir(LOCAL_RUNS) as it:
        for e in it:
            if e.is_dir():
                try:
                    entries.append((e.stat().st_mtime, e.name))
                except OSError:
                    continue
    entries.sort(reverse=True)
    entries = entries[: params.limit]
    if not entries:
        return f"No run directories under {LOCAL_RUNS}."
    import datetime
    rows = [f"{datetime.datetime.fromtimestamp(m).strftime('%Y-%m-%d %H:%M')}  {n}"
            for m, n in entries]
    return f"# Local runs ({len(rows)} shown)\n" + "\n".join(rows)


@mcp.tool(
    name="tsubame_tail_log",
    annotations={"title": "Tail a local run log", "readOnlyHint": True,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": False},
)
async def tsubame_tail_log(params: TailLogInput) -> str:
    """Tail the most recent log file under the project's `logs/` directory.

    Args:
        params (TailLogInput): lines (trailing lines), pattern (optional
            filename substring to select a specific log).

    Returns:
        str: the last `lines` lines of the selected log, or an "Error: ..." string.
    """
    logs_dir = os.path.join(PROJECT_DIR, "logs")
    if not os.path.isdir(logs_dir):
        return f"No logs directory at {logs_dir}."
    cands = []
    for root, _dirs, files in os.walk(logs_dir):
        for f in files:
            if params.pattern and params.pattern not in f:
                continue
            p = os.path.join(root, f)
            try:
                cands.append((os.stat(p).st_mtime, p))
            except OSError:
                continue
    if not cands:
        sel = f" matching '{params.pattern}'" if params.pattern else ""
        return f"No log files{sel} under {logs_dir}."
    cands.sort(reverse=True)
    path = cands[0][1]
    res = await _run(["tail", "-n", str(params.lines), path], timeout=15)
    header = f"# {os.path.relpath(path, PROJECT_DIR)} (last {params.lines} lines)\n"
    return header + _fmt(res, f"tail {path}")


# ── Collect tool ─────────────────────────────────────────────────────
@mcp.tool(
    name="tsubame_pull_results",
    annotations={"title": "Pull TSUBAME results", "readOnlyHint": False,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": True},
)
async def tsubame_pull_results(params: PullInput) -> str:
    """Rsync result files (*.jld2 + outcome/exit summaries) from TSUBAME to local runs/.

    Pulls from the remote runs root (SPINORBEC_TSUBAME_RUNS_ROOT) into the local
    runs/ tree. Only result/metadata files are transferred (not heavy scratch).
    Idempotent: re-pulling skips unchanged files.

    Args:
        params (PullInput): run_name (optional subdir to limit the pull),
            dry_run (preview only).

    Returns:
        str: the rsync transfer summary, or an "Error: ..." string.
    """
    if not RUNS_ROOT:
        return ("Error: SPINORBEC_TSUBAME_RUNS_ROOT is not set in the environment. "
                "Ensure scripts/spinorbec.env is sourced into this server's process "
                "(see the Desktop launch command in scripts/mcp/README.md).")
    sub = (params.run_name + "/") if params.run_name else ""
    remote = f"{HOST}:{RUNS_ROOT.rstrip('/')}/{sub}"
    local = os.path.join(LOCAL_RUNS, params.run_name or "") + "/"
    os.makedirs(local, exist_ok=True)
    argv = [
        "rsync", "-az", "--prune-empty-dirs",
        "--include=*/",
        "--include=*.jld2", "--include=outcome.toml",
        "--include=_exit_summary.json", "--include=_live_status.json",
        "--include=config.yaml",
        "--exclude=*",
        "-e", "ssh -o BatchMode=yes",
    ]
    if params.dry_run:
        argv.append("--dry-run")
    argv += ["--stats", remote, local]
    res = await _run(argv, timeout=RSYNC_TIMEOUT)
    label = f"rsync {'(dry-run) ' if params.dry_run else ''}{remote} -> {local}"
    return _fmt(res, label)


# ── Submit tools ─────────────────────────────────────────────────────
@mcp.tool(
    name="tsubame_enqueue",
    annotations={"title": "Queue a config for TSUBAME", "readOnlyHint": False,
                 "destructiveHint": False, "idempotentHint": True, "openWorldHint": False},
)
async def tsubame_enqueue(params: EnqueueInput) -> str:
    """Add a run config to the autopilot queue (`cli.jl autopilot enqueue <yaml>`).

    Queues only — does NOT dispatch. Call tsubame_tick afterward to submit
    queued jobs to TSUBAME via qsub. Re-enqueuing the same config is idempotent
    at the queue level. Slow on cold start (Julia JIT).

    Args:
        params (EnqueueInput): config_path (project-relative .yaml),
            priority (optional 0-100).

    Returns:
        str: the enqueue confirmation (content id / queue position), or an
        "Error: ..." string. A missing-file error means config_path is wrong
        relative to the project root.
    """
    full = os.path.join(PROJECT_DIR, params.config_path)
    if not os.path.isfile(full):
        return (f"Error: config not found at {params.config_path} (resolved {full}). "
                "Use tsubame_list_runs to find valid configs.")
    args = ["enqueue", params.config_path]
    if params.priority is not None:
        args += ["--priority", str(params.priority)]
    return _fmt(await _julia_autopilot(args), f"autopilot enqueue {params.config_path}")


@mcp.tool(
    name="tsubame_tick",
    annotations={"title": "Dispatch queued jobs to TSUBAME", "readOnlyHint": False,
                 "destructiveHint": False, "idempotentHint": False, "openWorldHint": True},
)
async def tsubame_tick(params: Empty) -> str:
    """Run one autopilot tick: dispatch queued jobs to TSUBAME via qsub (`cli.jl autopilot tick`).

    This SUBMITS jobs and SPENDS compute points. Dispatch is gated server-side
    by the autopilot's budget caps + circuit breakers; this tool does not
    bypass them. A tick also collects finished remote runs back to local runs/.
    Slow on cold start (Julia JIT).

    Args:
        params (Empty): no parameters.

    Returns:
        str: the tick summary (dispatched / collected / skipped counts), or an
        "Error: ..." string.
    """
    return _fmt(await _julia_autopilot(["tick"]), "autopilot tick")


@mcp.tool(
    name="tsubame_cancel",
    annotations={"title": "Cancel a TSUBAME job", "readOnlyHint": False,
                 "destructiveHint": True, "idempotentHint": True, "openWorldHint": True},
)
async def tsubame_cancel(params: JobIdInput) -> str:
    """Cancel a running/queued job via `qdel <job_id>` (DESTRUCTIVE).

    Terminates the job; any unsaved progress is lost (checkpointed dynamics can
    resume on resubmit). Confirm the job_id with tsubame_qstat first.

    Args:
        params (JobIdInput): job_id (digits) from tsubame_qstat.

    Returns:
        str: the `qdel` confirmation, or an "Error: ..." string.
    """
    return _fmt(await _ssh(f"qdel {shlex.quote(params.job_id)}"), f"qdel {params.job_id}")


if __name__ == "__main__":
    mcp.run()
