# A throwaway git repo that does NOT inherit the developer's git config.
#
# WHY THIS EXISTS
#
# Two tests build a scratch repo in `mktempdir()` and commit into it. Both set
# `user.email` and `user.name` locally — the two settings anyone remembers — and
# inherit everything else. On a machine with
#
#     [commit] gpgsign = true
#     [gpg]    format  = ssh
#
# — which is this project's own setup, since its commits are signed — `git commit`
# in that scratch repo tries to sign, has no usable agent for it, and exits 128
# after about a minute. Both files then FAIL, permanently, on the developer's
# machine and pass in CI, where no global config exists.
#
# That is the worst shape a gate can have. A test that is red for reasons having
# nothing to do with the code is a test people learn to ignore, and this project
# has measured that the dangerous direction is a gate that reddens on correct
# work, not one that is too lax (`feedback_test_the_direction_where_a_gate_must_pass`).
#
# WHY THE ENVIRONMENT AND NOT `commit.gpgsign=false`
#
# Turning off signing fixes the instance. The class is that a scratch repo
# inherits the ambient configuration at all, and signing is one of many things
# that can arrive through that door: `core.hooksPath` pointing at this repo's
# pre-commit hooks, `init.templateDir`, `commit.gpgsign`, `core.autocrlf`,
# `gc.auto`, an alias shadowing a subcommand. Each would be a separate mystery
# with the same symptom. `GIT_CONFIG_GLOBAL` / `GIT_CONFIG_SYSTEM` pointed at
# /dev/null shut the whole door, and git documents them for exactly this.
#
# USE
#
#     scratch_git("init", "-q"; dir)
#     scratch_git("commit", "-q", "-m", "init"; dir)
#     run(setenv(Cmd(`git status`; dir), SCRATCH_GIT_ENV))   # raw, if needed

export SCRATCH_GIT_ENV, scratch_git, scratch_git_repo

"""
    SCRATCH_GIT_ENV

Environment for a git command that must depend on nothing outside its own
repository. Pass it to `setenv`, or use [`scratch_git`](@ref).

Identity is included because `git commit` refuses without one and a scratch repo
has no `.git/config` entries yet — with the global file switched off, setting it
locally per repo would be a second thing to remember.
"""
const SCRATCH_GIT_ENV = copy(ENV)
for (k, v) in (
    # The two doors the ambient configuration comes through.
    "GIT_CONFIG_GLOBAL" => "/dev/null",
    "GIT_CONFIG_SYSTEM" => "/dev/null",
    "GIT_AUTHOR_NAME" => "t",
    "GIT_AUTHOR_EMAIL" => "t@t",
    "GIT_COMMITTER_NAME" => "t",
    "GIT_COMMITTER_EMAIL" => "t@t",
    # Belt and braces, and they say what they are guarding: even with the config
    # files switched off, these are settable from the environment.
    "GIT_CONFIG_COUNT" => "1",
    "GIT_CONFIG_KEY_0" => "commit.gpgsign",
    "GIT_CONFIG_VALUE_0" => "false",
)
    SCRATCH_GIT_ENV[k] = v
end

"""
    scratch_git(args...; dir, capture=false) -> Nothing | String

Run `git args...` in `dir` under [`SCRATCH_GIT_ENV`](@ref), discarding output
(or returning it when `capture=true`).

Every git command in a test's throwaway repository should go through this. It is
not a convenience wrapper: the isolation is the point, and a bare `Cmd(`git …`;
dir)` silently reads the developer's `~/.gitconfig`.
"""
function scratch_git(args::AbstractString...; dir::AbstractString, capture::Bool=false)
    cmd = setenv(Cmd(`git $(collect(args))`; dir=String(dir)), SCRATCH_GIT_ENV)
    capture ? read(cmd, String) :
    (run(pipeline(cmd; stdout=devnull, stderr=devnull)); nothing)
end

"""
    scratch_git_repo(f)

`mktempdir` + `git init` under [`SCRATCH_GIT_ENV`](@ref), then `f(dir)`.

Only the initialisation is shared — the layout each test needs differs, and a
one-size builder would grow flags until it was harder to read than the three
lines it replaced.
"""
function scratch_git_repo(f::Function)
    mktempdir() do dir
        scratch_git("init", "-q"; dir)
        f(dir)
    end
end
