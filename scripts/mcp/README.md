# TSUBAME MCP tools

An MCP server for scheduler status, logs, point balance and result transfer.
It uses the `tsubame` SSH alias and launches no Julia processes.

| Tool | Operation |
|---|---|
| `tsubame_qstat` | List scheduler jobs |
| `tsubame_job_detail` | Read job details |
| `tsubame_points` | Read group point balance |
| `tsubame_list_runs` | List local run directories |
| `tsubame_tail_log` | Read a remote log tail |
| `tsubame_pull_results` | Transfer remote results with rsync |
| `tsubame_cancel` | Cancel a job with qdel |

Submit runs with the batch wrappers documented in
[`docs/guides/tsubame.md`](../../docs/guides/tsubame.md).

## Setup

Use an existing Python environment with `mcp` and `pydantic` installed.
Configure the MCP client to launch that Python executable with
`scripts/mcp/tsubame_server.py` as its argument. Set the environment variables
below in the client configuration.

The SSH alias must authenticate non-interactively. Establish the connection
in a terminal with `ssh tsubame true` before using the tools if your SSH
configuration requires an interactive authentication step. Credentials stay
in the SSH configuration; the server passes no credentials.

| Variable | Default | Meaning |
|---|---|---|
| `SPINORBEC_TSUBAME_HOST` | `tsubame` | SSH alias |
| `SPINORBEC_TSUBAME_GROUP` | empty | Group name for remote log paths |
| `SPINORBEC_TSUBAME_RUNS_ROOT` | empty | Remote runs root; required for result transfer |
| `SPINORBEC_PROJECT_DIR` | `/home/suzume/workspace/BEC-simulation` | Local checkout containing runs/ |
| `SPINORBEC_MCP_SSH_TIMEOUT` | `30` | SSH timeout in seconds |
| `SPINORBEC_MCP_RSYNC_TIMEOUT` | `600` | Result-transfer timeout in seconds |

## Registration check

Run in the configured Python environment from the checkout root:

```python
import asyncio
from scripts.mcp import tsubame_server

print(tsubame_server.mcp.name)
print([tool.name for tool in asyncio.run(tsubame_server.mcp.list_tools())])
```

This checks tool registration without accessing the cluster.
