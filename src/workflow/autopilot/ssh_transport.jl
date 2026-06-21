# ── Shared SSH / rsync transport (UGE + UMS backends) ─────────────────
#
# Scheduler-agnostic data movement: ControlMaster-pooled ssh, rsync
# push/pull/collect, code sync, and Manifest-hash auto-instantiate. The
# scheduler-specific verbs (qsub/qstat/qdel/qacct for UGE,
# ums-start/ums-submit/ums-list for UMS) live in the backend files; this
# is the transport both share. Extracted from backends_uge.jl so UMS
# reuses the audited rsync machinery instead of copy-pasting it (the
# duplicated-physics-drift class this repo forbids).
#
# All functions take primitives (host string, paths) rather than a
# backend struct, so any backend with an ssh_host + project_root can
# call them without a common supertype carrying those fields.

# SSH ControlMaster pools all of a tick's ssh/rsync calls into one
# persistent connection. Without it, each `ssh tsubame qstat …` opens a
# fresh TCP+SSH handshake (~hundreds of ms), and a tick reaping N running
# entries pays that N+1 times. ControlPersist=60s keeps the socket across
# the tick body and into the next closely-spaced tick.
#
# ControlPath=/tmp/ssh-spinorbec-%C — %C is a hash of host:port:user, so
# different SSH targets get different sockets; safe to share across
# spinor-autopilot.service / spinor-dashboard.service (same user).
const _SSH_CM_OPTS = [
    "-o", "ControlMaster=auto",
    "-o", "ControlPath=/tmp/ssh-spinorbec-%C",
    "-o", "ControlPersist=60s",
]

# Pre-quoted string for rsync's -e (which takes a single shell-tokenised
# argument). Must match _SSH_CM_OPTS exactly.
const _RSYNC_SSH_CM = "ssh -o ControlMaster=auto -o ControlPath=/tmp/ssh-spinorbec-%C -o ControlPersist=60s"

_ssh_cm(host::AbstractString) = `ssh $_SSH_CM_OPTS $host`

# ── rsync / ssh command builders (separate so tests can assert shape) ──

_ssh_mkdir_cmd(host::AbstractString, remote_dir::AbstractString) =
    `$(_ssh_cm(host)) mkdir -p $(remote_dir)`

# Push a single file into a remote directory (trailing slash on dest).
_rsync_push_cmd(host::AbstractString, src::AbstractString,
    remote_dir::AbstractString) =
    `rsync -e $_RSYNC_SSH_CM $(src) $(host):$(remote_dir)/`

# Pull one remote file to a local path; tolerate it being absent.
_rsync_pull_missing_cmd(host::AbstractString, remote_path::AbstractString,
    local_path::AbstractString) =
    `rsync -e $_RSYNC_SSH_CM --ignore-missing-args $(host):$(remote_path) $(local_path)`

# Mirror a remote run dir back, minus the autopilot's own state files.
_rsync_collect_cmd(host::AbstractString, remote_dir::AbstractString,
    local_dir::AbstractString) =
    `rsync -av -e $_RSYNC_SSH_CM --exclude=state.toml --exclude=.state.lock $(host):$(remote_dir)/ $(local_dir)/`

# Push a file to an explicit remote path (no trailing-slash dir semantics).
_rsync_file_cmd(host::AbstractString, src::AbstractString,
    remote_path::AbstractString) =
    `rsync -e $_RSYNC_SSH_CM $(src) $(host):$(remote_path)`

# Sync the LOCAL project working tree to the remote project_root. rsync
# (not git checkout) so the dispatcher's exact files — including
# uncommitted edits — become the remote state without a GitHub round-trip.
# `--update` never clobbers files newer on remote (protects in-flight
# edits made directly on the cluster).
function _rsync_code_sync_cmd(host::AbstractString, local_root::AbstractString,
    project_root::AbstractString)
    # `--exclude=*.jld2` must be a single quoted token in Julia backticks
    # (raw `*` is unquoted-special). Interpolate via a String so the glob
    # reaches rsync verbatim.
    jld_excl = "--exclude=*.jld2"
    `rsync -az --update -e $_RSYNC_SSH_CM --exclude=runs/ --exclude=.git/ --exclude=node_modules/ --exclude=dashboard/dist/ --exclude=dashboard/.vite/ --exclude=.venv/ $jld_excl $(local_root)/ $(host):$(project_root)/`
end

# ── local project + Manifest-hash helpers (auto-instantiate) ──────────

# Resolve the LOCAL Julia project directory (where Project.toml sits).
# `Base.active_project()` returns the Project.toml path; dirname() gives
# the project dir. Robust against cwd shenanigans.
_ssh_local_project_root() = dirname(Base.active_project())

_ssh_local_manifest_path() = joinpath(_ssh_local_project_root(), "Manifest.toml")

_ssh_local_manifest_hash() =
    if isfile(_ssh_local_manifest_path())
        bytes2hex(SHA.sha256(read(_ssh_local_manifest_path())))
    else
        ""
    end

# The remote stores a `.manifest_hash` file under project_root holding the
# sha256 of the Manifest.toml last `Pkg.instantiate`d there. After code
# sync we compare local → remote; differ → instantiate + write the new
# hash; same → skip (instantiate is 10-60s, not free).
_ssh_remote_manifest_hash_path(project_root::AbstractString) =
    joinpath(project_root, ".manifest_hash")

function _ssh_remote_manifest_hash(host::AbstractString, project_root::AbstractString)
    try
        strip(read(`$(_ssh_cm(host)) cat $(_ssh_remote_manifest_hash_path(project_root))`,
            String))
    catch
        ""   # file absent / first run / ssh blip — treat as "differs"
    end
end

"""
    _ssh_instantiate_if_needed(host, project_root, julia_path, julia_depot) -> Bool

After a code sync, run `Pkg.instantiate` on the remote iff the local
Manifest.toml hash differs from the remote's recorded hash. Returns true
iff instantiate was actually invoked. No-op when there's no local
Manifest.toml or when the hashes match.
"""
function _ssh_instantiate_if_needed(host::AbstractString, project_root::AbstractString,
    julia_path::AbstractString, julia_depot::AbstractString)
    local_hash = _ssh_local_manifest_hash()
    isempty(local_hash) && return false
    remote_hash = _ssh_remote_manifest_hash(host, project_root)
    local_hash == remote_hash && return false
    @info "autopilot: Manifest.toml changed; running Pkg.instantiate on remote" host=host local_sha=local_hash[1:8] remote_sha=(
        isempty(remote_hash) ? "none" : remote_hash[1:8]
    )
    # Single ssh round-trip: instantiate + write hash. depot_export is
    # important — without it the compute node's $JULIA_DEPOT_PATH might
    # differ from the login node's, instantiating into the wrong depot.
    depot_export = isempty(julia_depot) ? "" :
                   "export JULIA_DEPOT_PATH=\"$(julia_depot)\"; "
    snippet =
        depot_export *
        "cd $(project_root) && " *
        "$(julia_path) --project=. -e 'using Pkg; Pkg.instantiate()' && " *
        "printf %s $(local_hash) > $(_ssh_remote_manifest_hash_path(project_root))"
    run(`$(_ssh_cm(host)) bash -lc $snippet`)
    return true
end
