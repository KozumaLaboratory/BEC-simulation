# --- Base.show overloads for REPL pretty printing ---
#
# RunResult, RunSweep, RunComparison, CheckResult get multi-line text
# representations so REPL display is informative without the user
# having to write @printf loops.

# Compact one-line forms (default Base.show)
Base.show(io::IO, r::RunResult) = print(
    io, "RunResult($(r.atom.name) F=$(r.atom.F) grid=$(r.grid.config.n_points))"
)

Base.show(io::IO, s::RunSweep) = print(
    io, "RunSweep($(length(s.runs)) runs, vary=$(s.varying.first)=>$(s.varying.second))"
)

Base.show(io::IO, c::RunComparison) = print(io, "RunComparison($(c.label_a) vs $(c.label_b))")

# Multi-line MIME"text/plain" forms (shown when typed bare in REPL)
function Base.show(io::IO, ::MIME"text/plain", r::RunResult)
    println(io, "RunResult — $(basename(r.path))")
    println(io, "  atom        : $(r.atom.name) (F=$(r.atom.F))")
    println(io, "  grid        : $(r.grid.config.n_points), box $(r.grid.config.box_size)")
    n_total = sum(abs2, r.psi) * prod(r.grid.dx)
    @printf(io, "  ψ |L²       : %.6f\n", sqrt(n_total))
    if r.hpsi !== nothing
        n_hpsi = sum(abs2, r.hpsi) * prod(r.grid.dx)
        @printf(io, "  Hψ |L²      : %.6f\n", sqrt(n_hpsi))
    end
    if r.dynamics !== nothing
        d = r.dynamics
        n = length(d.times)
        @printf(io, "  dynamics    : %d frames, t ∈ [%.4f, %.4f]\n",
            n, d.times[1], d.times[end])
        if n >= 2
            nd = maximum(abs.(d.norms .- d.norms[1]))
            ed = maximum(abs.(d.energies .- d.energies[1]))
            fzd = maximum(abs.(d.Fz .- d.Fz[1]))
            @printf(io, "    norm drift   : %.2e\n", nd)
            @printf(io, "    energy drift : %.2e\n", ed)
            @printf(io, "    ⟨F_z⟩ drift  : %.2e (from %.4f to %.4f)\n",
                fzd, d.Fz[1], d.Fz[end])
        end
    else
        println(io, "  dynamics    : (no time series)")
    end
    if !isempty(r.e_decomp)
        @printf(io, "  E_total     : %+.6e\n",
            get(r.e_decomp, "total", NaN))
    end
end

function Base.show(io::IO, ::MIME"text/plain", s::RunSweep)
    println(io, "RunSweep — vary $(s.varying.first) over $(s.varying.second)")
    println(io, "  runs:")
    for (val, r) in zip(s.varying.second, s.runs)
        println(io, "    $val => $(basename(r.path))  ($(r.atom.name) F=$(r.atom.F))")
    end
end

function Base.show(io::IO, ::MIME"text/plain", c::RunComparison)
    println(io, "RunComparison")
    println(io, "  $(c.label_a) : $(basename(c.a.path))")
    println(io, "  $(c.label_b) : $(basename(c.b.path))")
    if c.a.atom.name != c.b.atom.name
        println(io, "  ⚠ atoms differ: $(c.a.atom.name) vs $(c.b.atom.name)")
    end
    if c.a.grid.config.n_points != c.b.grid.config.n_points
        println(io, "  ⚠ grids differ: $(c.a.grid.config.n_points) vs $(c.b.grid.config.n_points)")
    end
end

_check_mark(s::Symbol) =
    if s === :pass
        "✓ "
    elseif s === :fail
        "✗ "
    else
        "? "
    end

function _detail_status(d)
    d isa NamedTuple || return :fail
    haskey(d, :status) && return d.status
    haskey(d, :pass) && return d.pass ? :pass : :fail
    :fail
end

function Base.show(io::IO, ::MIME"text/plain", r::CheckResult)
    print(io, _check_mark(r.status))
    println(io, r.summary)
    if !isempty(r.details)
        for p in r.details
            obs = p.first
            d = p.second
            marker = "  " * _check_mark(_detail_status(d))
            got_str = if d isa NamedTuple && haskey(d, :got)
                d.got isa Number ? @sprintf("%.4e", d.got) : repr(d.got)
            else
                repr(d)
            end
            bound_str = if d isa NamedTuple && haskey(d, :bound)
                d.bound isa Number ? @sprintf("%.4e", d.bound) : repr(d.bound)
            else
                "—"
            end
            print(io, marker)
            @printf(io, "%-22s got=%s  bound<%s\n", string(obs), got_str, bound_str)
        end
    end
end
