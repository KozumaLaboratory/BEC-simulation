#!/usr/bin/env julia
#
# Level 10 cross-code diff: compare two `operator_rhs.jld2` artifacts
# produced by `export_operator_rhs.jl` (one from us, one from an
# external code such as the Ueda lab).
#
# Per validation ladder Level 10 (memory `validation_ladder_2026_05_24`),
# this is the **strongest** test we can run before time evolution:
#
#   ‖H_ours · ψ - H_Ueda · ψ‖_L² / ‖H_ours · ψ‖_L²
#
# A small relative residual here (< 1e-10) means both codes implement
# the SAME operator — any subsequent time-evolution disagreement is
# integrator-level, not physics-level.
#
# A large residual (> 1e-2) means a convention is mismatched. Read
# the per-term energy diff to localize the offending term, then
# consult `docs/validation/parameter_contract_with_Ueda.md` for the
# row that needs reconciliation.
#
# Usage:
#
#   julia --project=. scripts/validation/compare_operator_rhs.jl \
#     ours.jld2 theirs.jld2 [tolerance]
#
# Default tolerance: 1e-10 (machine-precision regime for double-precision
# arithmetic over a 32³×13 grid).
#
# Exit code: 0 if all checks pass, 1 if any term exceeds tolerance.

using JLD2
using LinearAlgebra
using Printf

function usage_and_exit()
    println(
        stderr,
        """
Usage: compare_operator_rhs.jl ours.jld2 theirs.jld2 [tolerance]

Default tolerance: 1e-10 (relative L² for Hψ; per-term relative for E).

See docs/validation/parameter_contract_with_Ueda.md for acceptance
criteria and the per-row convention contract that must precede
this comparison.
""",
    )
    exit(2)
end

length(ARGS) ∈ (2, 3) || usage_and_exit()
ours_path = String(ARGS[1])
theirs_path = String(ARGS[2])
tol = length(ARGS) == 3 ? parse(Float64, ARGS[3]) : 1.0e-10

isfile(ours_path) || (println(stderr, "ERROR: $ours_path not found"); exit(1))
isfile(theirs_path) || (println(stderr, "ERROR: $theirs_path not found"); exit(1))

println("=== Level 10 cross-code operator-RHS diff ===")
println("ours   : $ours_path")
println("theirs : $theirs_path")
println("tolerance (relative L²): $tol")
println()

function _load(path)
    JLD2.jldopen(path, "r") do f
        Dict(
            "psi" => f["psi"],
            "Hpsi" => f["Hpsi"],
            "E_decomp" => f["E_decomp"],
            "grid_n_pts" => f["grid_n_pts"],
            "grid_box" => f["grid_box"],
            "grid_dx" => f["grid_dx"],
            "atom_name" => f["atom_name"],
            "atom_F" => f["atom_F"],
            "interactions_c0" => f["interactions_c0"],
            "interactions_c1" => f["interactions_c1"],
            "ddi_c_dd" => f["ddi_c_dd"],
            "conventions" => f["conventions"],
        )
    end
end

ours = _load(ours_path)
theirs = _load(theirs_path)

# 1. Metadata sanity — same atom, same grid, same coefficients.
println("--- Setup metadata ---")
all_match = true
function _expect_equal(label, a, b; atol=0.0)
    global all_match
    eq = a isa Number ? isapprox(Float64(a), Float64(b); atol) : a == b
    if eq
        @printf("  %-30s OK   (%s)\n", label, string(a))
    else
        @printf("  %-30s FAIL ours=%s theirs=%s\n", label, string(a), string(b))
        all_match = false
    end
end
_expect_equal("atom_name", ours["atom_name"], theirs["atom_name"])
_expect_equal("atom_F", ours["atom_F"], theirs["atom_F"])
_expect_equal("grid_n_pts", ours["grid_n_pts"], theirs["grid_n_pts"])
_expect_equal("grid_box", ours["grid_box"], theirs["grid_box"]; atol=1e-12)
_expect_equal("interactions_c0", ours["interactions_c0"],
    theirs["interactions_c0"]; atol=1e-10)
_expect_equal("interactions_c1", ours["interactions_c1"],
    theirs["interactions_c1"]; atol=1e-10)
_expect_equal("ddi_c_dd", ours["ddi_c_dd"], theirs["ddi_c_dd"]; atol=1e-10)

if !all_match
    println("\nSETUP MISMATCH — operator diff below is not meaningful.")
    println("Resolve setup disagreement first, then re-export both sides.")
    exit(1)
end

# 2. psi diff — should be near machine precision if both sides started
#    from the same converged ground state. A non-zero diff means the
#    initial state itself is not bit-identical; we report and continue.
println("\n--- ψ₀ diff (the input state for Hψ) ---")
psi_ours = ours["psi"]
psi_theirs = theirs["psi"]
size(psi_ours) == size(psi_theirs) ||
    (println("ERROR: psi shape mismatch"); exit(1))
psi_diff = sqrt(sum(abs2, psi_ours .- psi_theirs))
psi_norm_o = sqrt(sum(abs2, psi_ours))
psi_norm_t = sqrt(sum(abs2, psi_theirs))
psi_rel = psi_diff / max(psi_norm_o, psi_norm_t)
@printf("  ‖ψ_ours - ψ_theirs‖_L² / max(‖.‖) = %.3e\n", psi_rel)
if psi_rel > 1e-6
    println("""
        Note: ψ₀ differs at $(round(psi_rel; sigdigits=3)) — the input states
        are not the same. The Hψ diff below is dominated by the input
        difference and is NOT a clean operator-RHS test. To get a clean
        operator-level comparison, both codes must run on the SAME ψ₀.
        """)
end

# 3. Energy decomposition diff.
println("\n--- Per-term energy diff ---")
@printf("  %-15s %-15s %-15s %-15s %s\n",
    "term", "ours", "theirs", "|diff|", "|diff|/|E_total|")
E_total = max(abs(get(ours["E_decomp"], "total", 1.0)),
    abs(get(theirs["E_decomp"], "total", 1.0)))
global e_terms_ok = true
for term in sort(collect(keys(ours["E_decomp"])))
    haskey(theirs["E_decomp"], term) || continue
    e_o = Float64(ours["E_decomp"][term])
    e_t = Float64(theirs["E_decomp"][term])
    d = abs(e_o - e_t)
    rel = d / E_total
    status = rel < tol ? "OK" : "FAIL"
    @printf("  %-15s %-15.6e %-15.6e %-15.3e %-15.3e %s\n",
        term, e_o, e_t, d, rel, status)
    if term != "total" && rel >= tol
        global e_terms_ok = false
    end
end

# 4. Hψ diff — the strongest test.
println("\n--- Hψ diff (the operator action; strongest test) ---")
Hpsi_ours = ours["Hpsi"]
Hpsi_theirs = theirs["Hpsi"]
size(Hpsi_ours) == size(Hpsi_theirs) ||
    (println("ERROR: Hψ shape mismatch"); exit(1))
hpsi_diff = sqrt(sum(abs2, Hpsi_ours .- Hpsi_theirs))
hpsi_norm = sqrt(sum(abs2, Hpsi_ours))
hpsi_rel = hpsi_diff / hpsi_norm
@printf("  ‖Hψ_ours‖_L²              = %.6e\n", hpsi_norm)
@printf("  ‖Hψ_theirs‖_L²            = %.6e\n", sqrt(sum(abs2, Hpsi_theirs)))
@printf("  ‖Hψ_ours - Hψ_theirs‖_L²  = %.6e\n", hpsi_diff)
@printf("  relative L² residual      = %.3e\n", hpsi_rel)
hpsi_ok = hpsi_rel < tol
@printf("  → %s\n", hpsi_ok ? "PASS" : "FAIL")

# 5. Per-component Hψ diff — helps localise WHICH spinor component
#    the operator disagreement lives in (e.g. only m=+F means a Zeeman
#    sign issue; uniform means a c₀ issue; alternating-sign means a
#    spin-mixing sign issue).
println("\n--- Per-component Hψ relative residual ---")
D = size(Hpsi_ours)[end]
for c in 1:D
    comp_ours = selectdim(Hpsi_ours, ndims(Hpsi_ours), c)
    comp_theirs = selectdim(Hpsi_theirs, ndims(Hpsi_theirs), c)
    d_c = sqrt(sum(abs2, comp_ours .- comp_theirs))
    n_c = sqrt(sum(abs2, comp_ours))
    rel_c = n_c > 0 ? d_c / n_c : 0.0
    F_val = (D - 1) / 2
    m_label = F_val - (c - 1)
    @printf("  c=%2d (m=%+5.1f) rel = %.3e\n", c, m_label, rel_c)
end

# 6. Final verdict.
println("\n=== VERDICT ===")
all_ok = e_terms_ok && hpsi_ok
if all_ok
    println("✓ Level 10 PASS (relative tolerance $tol)")
    println("  Operators agree — any time-evolution disagreement is integrator-level.")
    println("  Validation ladder Levels 11 (convergence) and 12 (production) UNBLOCKED.")
    exit(0)
else
    println("✗ Level 10 FAIL")
    println()
    println("Read the per-term and per-component diffs above to localise:")
    println("  - all components fail uniformly  → c₀, normalization, or units")
    println("  - only m=±F fail               → linear Zeeman sign / p convention")
    println("  - |m|² pattern                  → quadratic Zeeman sign / q")
    println("  - alternating-sign pattern      → spin-mixing c₁ sign")
    println("  - DDI energy term FAILs        → c_dd 4π / μ definition / kernel sign")
    println("  - LHY energy term FAILs        → c_lhy coefficient / spinor LHY choice")
    println()
    println("Cross-reference rows in docs/validation/parameter_contract_with_Ueda.md.")
    println("DO NOT advance to Level 11/12 until this PASSes.")
    exit(1)
end
