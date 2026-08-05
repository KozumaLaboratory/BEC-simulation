# Every solver path that builds a workspace must carry the tabulated LHY.
#
# The HamTerm registry made LHY's SIGN single-declaration, but it says nothing
# about which *table* a given code path installs as `ws.lhy` — and that
# resolution is written once per path. All four known paths have silently
# dropped it:
#
#   #125  GPU broadcast path collapsed every table to c_lhy = 0
#   #174  dynamics pipeline step never resolved its own `lhy:` block
#   #179  find_ground_state_lbfgs had no spinor_lhy kwarg at all
#   here  the adaptive-ITP branch and the L-BFGS pin ε-continuation
#
# The failure is always silent and always looks like a physics answer, because
# `scalar` keeps working (it rides in `interactions.c_lhy`, threaded separately)
# while only the modes that need a TABLE vanish. #179 is the cautionary case: an
# LHY-on/LHY-off A/B came back bit-identical on all 34 points, which reads as
# "LHY changes nothing" rather than as a broken run.
#
# So this gate is deliberately structural, not behavioural. A behavioural test
# has to pick a path to exercise, and the bug is precisely in the path nobody
# picked. Two invariants:
#
#   1. PAIRING — `spinor_lhy` and `lhy_opts` always appear together. #174 was
#      exactly the split: `spinor_lhy` threaded, `lhy_opts` defaulted, so the
#      table got built with n_atoms = 1 and came out N_atoms too strong.
#   2. FORWARDING — a file that declares `spinor_lhy` forwards it to every
#      `make_workspace` and every ground-state solver call it makes. A branch
#      that accepts the kwarg and drops it is the #179/adaptive/pin shape.

using Test
using SpinorBEC

@testset "LHY table reaches every workspace-building path" begin
    srcdir = abspath(joinpath(@__DIR__, "..", "..", "src"))
    isdir(srcdir) || (srcdir = abspath(joinpath(@__DIR__, "..", "src")))

    jl_files = String[]
    for (root, _, files) in walkdir(srcdir), f in files
        endswith(f, ".jl") && push!(jl_files, joinpath(root, f))
    end
    @test !isempty(jl_files)

    # Strip `#` comments AND `"""` docstrings before matching. Comments close
    # the token-comment loophole a naive grep guard has; docstrings matter too —
    # `pinned.jl`'s docstring writes `find_ground_state_lbfgs(; pin=…)` as prose,
    # which read as an unforwarded call site until this stripped it.
    function code_of(path)
        body = replace(read(path, String), r"\"\"\"(?s).*?\"\"\"" => "")
        join((replace(l, r"#.*$" => "") for l in split(body, '\n')), "\n")
    end

    codes = Dict(relpath(p, srcdir) => code_of(p) for p in jl_files)

    # ---- invariant 1: spinor_lhy and lhy_opts travel together ----------------
    declares(code, name) = occursin(Regex("\\b$name\\s*::"), code)
    split_decl = [f for (f, c) in codes
                        if declares(c, "spinor_lhy") != declares(c, "lhy_opts")]
    if !isempty(split_decl)
        @info """A file declares one of (spinor_lhy, lhy_opts) without the other. \
`lhy_opts` carries n_atoms, which is the unit conversion — defaulting it makes \
every table N_atoms too strong (#174).""" split_decl
    end
    @test isempty(split_decl)

    # ---- invariant 2: whoever declares it, forwards it -----------------------
    # `make_workspace` itself is the consumer, not a forwarder.
    consumers = Set(["workflow/initialization/make_workspace.jl"])
    decl_files = sort([f for (f, c) in codes if declares(c, "spinor_lhy")])
    @test !isempty(decl_files)          # the pattern still exists at all
    @test "solvers/ground_state.jl" in decl_files          # ITP
    @test "solvers/lbfgs/driver.jl" in decl_files          # L-BFGS
    @test "solvers/ground_state/adaptive.jl" in decl_files # adaptive ITP
    @test "solvers/ground_state/pinned.jl" in decl_files   # pin ε-continuation

    # A call is "covered" when `spinor_lhy` appears in the same call parens.
    function unforwarded_calls(code, callee)
        bad = 0
        for m in eachmatch(Regex("\\b$callee\\s*\\(", "s"), code)
            i = m.offset + length(m.match) - 1     # at the '('
            depth, j, n = 1, i + 1, lastindex(code)
            while j <= n && depth > 0
                c = code[j]
                depth += (c == '(') - (c == ')')
                j = nextind(code, j)
            end
            occursin("spinor_lhy", code[i:min(j, n)]) || (bad += 1)
        end
        bad
    end

    gaps = Tuple{String, String, Int}[]
    for f in decl_files
        f in consumers && continue
        for callee in ("make_workspace", "find_ground_state", "find_ground_state_lbfgs",
            "_find_ground_state_adaptive", "_lbfgs_pin_continuation")
            n = unforwarded_calls(codes[f], callee)
            n > 0 && push!(gaps, (f, callee, n))
        end
    end
    if !isempty(gaps)
        @info """A file that accepts `spinor_lhy` calls a workspace-building \
routine without passing it on. That branch runs with NO tabulated LHY, silently, \
and `scalar` keeps working so the gap looks like a physics result (#179).""" gaps
    end
    @test isempty(gaps)
end
