#!/usr/bin/env julia
# Is our DDI operator itself right, on the state that matters?
#
#     julia --project=. scripts/validation/matsui_ddi_operator_audit.jl <run_dir>
#
# Every test so far has varied the SCALE of the dipolar drive — c_dd, density,
# N, box, grid, dt — and none of them can produce a uniform 20 % excess in how
# far the spin cascade runs. What none of them touched is the SPIN STRUCTURE:
# the off-diagonal channel that actually moves population between m states.
#
# `src/validation/reference_rhs/ddi.jl` is an independent statement of the same
# operator, written to be obviously correct rather than fast. This applies both
# to the real 5 ms state — 13 populated components with genuine texture, not a
# toy — and compares them per component, so a 20 % error confined to one channel
# cannot average away.
#
# The reference is the BARE periodic kernel, so production is put in the same
# configuration (padded=false, trunc=none). Padding and the cutoff are audited
# separately by matsui_kernel_field_compare.jl.
#
# Two positive controls, because the absence of one has already invalidated two
# nulls in this campaign:
#   1. a reference with the off-diagonal Q zeroed must DISAGREE loudly
#   2. a reference with c_dd scaled by 1.2 must disagree by 20 %

using SpinorBEC
using CodecZstd
using JLD2
using Printf
using LinearAlgebra

const OMEGA_REF = 691.1504

rel(a, b) = norm(a .- b) / max(norm(b), eps())

function main(run_dir)
    fs = sort(filter(f -> occursin(r"^point_\d+\.jld2$", f), readdir(run_dir)))
    # point_001 carries the last point's state (the known scan defect); take a
    # mid-scan file, which is a real 5 ms state deep in the cascade.
    psi, npts, boxs, c0, c1 = jldopen(joinpath(run_dir, fs[10]), "r") do g
        (ComplexF64.(g["psi"]), g["grid_n_points"], g["grid_box_size"],
            g["interactions_c0"], g["interactions_c1"])
    end
    n = Int(npts[1])
    box = Float64(boxs[1])
    D = size(psi, 4)
    F = (D - 1) ÷ 2
    w = [sum(abs2, selectdim(psi, 4, c)) for c in 1:D]
    @printf("state: %d^3, box %.3f, %d components; m=-F holds %.1f %%, m=0 holds %.1f %%\n",
        n, box, D, 100 * w[end] / sum(w), 100 * w[F + 1] / sum(w))

    atom = Eu151
    c_dd = compute_c_dd_dimless(atom; N_atoms=50_000, omega_ref=OMEGA_REF)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> box, 3)))
    ws = make_workspace(; grid, atom,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
        zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.181818)),
        sim_params=SimParams(; dt=1e-3, n_steps=1), psi_init=psi,
        enable_ddi=true, c_dd, secular_ddi=false,
        ddi_padding=false, ddi_trunc_radius=NaN, backend=CPUBackend())

    sm = ws.spin_matrices
    ddi_term = only(filter(t -> t isa DDITerm, collect(build_h_terms_registry(ws))))

    prod_out = zeros(ComplexF64, size(psi))
    apply_operator!(prod_out, ddi_term, ws, psi)

    ref_out = zeros(ComplexF64, size(psi))
    reference_ddi_apply!(ref_out, psi, sm, grid, c_dd; secular=false)

    println()
    @printf("production vs independent reference, bare periodic kernel\n")
    @printf("  total relative L2 difference : %.3e\n", rel(prod_out, ref_out))
    println()
    @printf("%5s %14s %14s\n", "m", "|Hψ|_m", "rel diff")
    for c in 1:D
        a = selectdim(prod_out, 4, c)
        b = selectdim(ref_out, 4, c)
        @printf("%5d %14.6e %14.3e\n", F - (c - 1), norm(b), rel(a, b))
    end

    println("\n--- positive controls (these MUST be large) ---")
    # 1. off-diagonal Q removed: the reference's secular branch does exactly that
    sec = zeros(ComplexF64, size(psi))
    reference_ddi_apply!(sec, psi, sm, grid, c_dd; secular=true)
    @printf("  secular reference (off-diagonal Q zeroed) vs full : %.3e\n", rel(sec, ref_out))
    # 2. c_dd scaled 1.2x
    scaled = zeros(ComplexF64, size(psi))
    reference_ddi_apply!(scaled, psi, sm, grid, 1.2 * c_dd; secular=false)
    @printf("  reference with c_dd x 1.2 vs full                 : %.3e (expect 0.2)\n",
        rel(scaled, ref_out))
    println("\nIf the production/reference difference is at machine precision while the")
    println("controls are O(0.1-1), our DDI operator is exonerated and the residual is")
    println("not in the transfer channel.")
end

isempty(ARGS) && error("usage: matsui_ddi_operator_audit.jl <run_dir>")
main(ARGS[1])
