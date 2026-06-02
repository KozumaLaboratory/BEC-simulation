#!/usr/bin/env julia
# scripts/sprint5_A1_v3_phase_diagram_gpu.jl
#
# Eu phase diagram on the digital-twin "anchor": scan aspect ratio × N
# around Matsui parameters. Each cell relaxes PCV + I_h (uniform reference)
# and reports ΔE = E_PCV − E_uniform, identifying where PCV wins.
#
# Cells (6 base):
#   aspect ∈ {0.7 prolate, 1.18 Matsui, 1.5 oblate}  × N ∈ {2×10⁴, 5×10⁴}
# Optional extension: aspect = 2.0 strongly oblate.
#
# 2 inits per cell (PCV, icosahedral_explicit). 12 GPU ITPs at ~8 min each
# (60k steps, tol=1e-9 — same as refine). Total ~100 min wall-clock.
#
# Box sized per N to fit TF: R_TF ~ (Ng)^(1/5).
#
# Output: matrix of (E_PCV, E_uniform, ΔE, winding) per cell + jld2
#         per-state snapshots for visualization.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_phase_diagram_gpu.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const ATOM = SpinorBEC.Eu151
const OMEGA_REF = 691.15
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT = 0.005
const N_STEPS = 60000
const TOL = 1e-9
const SEED = 1
const OUT_DIR = "runs/sprint5_A1_v3_phase_diagram"

# Cells: (aspect, N) → grid box (scales with N^(1/5) for TF, with aspect for z)
const CELLS = [
    (aspect=0.7, N=20000),
    (aspect=0.7, N=50000),
    (aspect=1.1818, N=20000),
    (aspect=1.1818, N=50000),     # ← Matsui digital twin (cross-check vs original)
    (aspect=1.5, N=20000),
    (aspect=1.5, N=50000),
]

# Box size per N (heuristic: R_TF ∝ (Ng)^(1/5), Eu g~94 dimless at N=2000 → c_total scales)
function box_for_N(N::Int, aspect::Float64)
    # baseline at N=50000 (digital twin): box=(30, 30, 26) with aspect 1.18
    # R_TF ~ N^(1/5) → 50000/N scaling
    Rxy = 15.0 * (N / 50000.0)^(1/5)
    Rz = Rxy / sqrt(aspect)
    box = (2 * Rxy + 4.0, 2 * Rxy + 4.0, 2 * Rz + 4.0)
    return box
end

function build_psi(state::Symbol, grid, sys)
    if state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(grid, sys; state=:polar)
        for k in 1:size(psi, 3), j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, k, :)))
            for c in 1:size(psi, 4)
                psi[i, j, k, c] = spatial_amp * ζ[c]
            end
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
        n > 0 && (psi ./= n)
        return psi
    else
        return init_psi(grid, sys; state=state)
    end
end

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int, grid)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    psi ./= n
end

function run_cell(init_state::Symbol, aspect::Float64, N::Int)
    box = box_for_N(N, aspect)
    grid = make_grid(GridConfig((24, 24, 24), box))
    pot = HarmonicTrap{3}((1.0, 1.0, aspect))
    a_ho = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
    C_TOTAL = 4π * (ATOM.a_s / a_ho) * N
    C0 = C_TOTAL / (1 + F^2 / 36.0)
    C1 = C0 / 36.0
    c_dd = SpinorBEC.compute_c_dd_dimless(ATOM; N_atoms=N, omega_ref=OMEGA_REF)

    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    sys = SpinSystem(F)
    psi_init = build_psi(init_state, grid, sys)
    apply_noise!(psi_init, 0.01, SEED, grid)
    initial_state_for_fgs = init_state === :icosahedral_explicit ? :polar : init_state

    ws, conv, E, _, _ = find_ground_state(;
        grid=grid, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=pot,
        dt=DT, n_steps=N_STEPS, tol=TOL,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=c_dd, secular_ddi=false,
        backend=CUDABackend())
    return ws, E, conv
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi_host = Array(ws.state.psi)
    fx, fy, fz = spin_density_vector(psi_host, sm, 3)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function winding_at(psi_host, c::Int, ic::Int, jc::Int, k::Int, r::Int)
    pts = ComplexF64[]
    for theta in range(0, 2π; length=33)[1:(end - 1)]
        i = round(Int, ic + r * cos(theta))
        j = round(Int, jc + r * sin(theta))
        push!(pts, psi_host[i, j, k, c])
    end
    w = 0.0
    for ki in 1:length(pts)
        knext = mod1(ki+1, length(pts))
        dphi = angle(pts[knext]) - angle(pts[ki])
        while dphi > π
            ;
            dphi -= 2π;
        end
        while dphi < -π
            ;
            dphi += 2π;
        end
        w += dphi
    end
    w / 2π
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== Eu phase diagram (aspect × N) — GPU 60k ITP ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9

    cells_out = []
    for (idx, cell) in enumerate(CELLS)
        aspect, N = cell.aspect, cell.N
        box = box_for_N(N, aspect)
        @printf "\n--- Cell %d: aspect=%.3f, N=%d, box=(%.1f, %.1f, %.1f) ---\n" idx aspect N box...
        flush(stdout)

        # PCV
        t0 = time()
        ws_pcv, E_pcv, conv_pcv = run_cell(:polar_core_vortex, aspect, N)
        b_pcv = energy_decomposition(ws_pcv)
        f_pcv = spin_density_max(ws_pcv)
        @printf "  PCV : E=%.6f  conv=%s  E_ddi=%+.4e  f_max=%.4f  (%.1f min)\n" E_pcv (
            conv_pcv ? "✓" : "✗"
        ) b_pcv.ddi f_pcv ((time() - t0) / 60)
        psi_pcv = Array(ws_pcv.state.psi)
        w_pcv_p1 = winding_at(psi_pcv, 6, 12, 12, 13, 4)
        w_pcv_m1 = winding_at(psi_pcv, 8, 12, 12, 13, 4)
        @printf "         windings: w(m=+1)=%+.3f  w(m=-1)=%+.3f\n" w_pcv_p1 w_pcv_m1
        CUDA.reclaim()

        # uniform reference: I_h_explicit
        t0 = time()
        ws_uni, E_uni, conv_uni = run_cell(:icosahedral_explicit, aspect, N)
        b_uni = energy_decomposition(ws_uni)
        f_uni = spin_density_max(ws_uni)
        @printf "  I_h : E=%.6f  conv=%s  E_ddi=%+.4e  f_max=%.4f  (%.1f min)\n" E_uni (
            conv_uni ? "✓" : "✗"
        ) b_uni.ddi f_uni ((time() - t0) / 60)
        psi_uni = Array(ws_uni.state.psi)
        w_uni_p1 = winding_at(psi_uni, 6, 12, 12, 13, 4)
        w_uni_m1 = winding_at(psi_uni, 8, 12, 12, 13, 4)
        @printf "         windings: w(m=+1)=%+.3f  w(m=-1)=%+.3f\n" w_uni_p1 w_uni_m1
        CUDA.reclaim()

        # ΔE
        ΔE = E_pcv - E_uni
        rel = 100 * ΔE / abs(E_uni)
        winner = ΔE < 0 ? "PCV" : "I_h_uniform"
        @printf "  ΔE = %+.4e (%.4f%%)  → winner: %s\n" ΔE rel winner

        push!(
            cells_out,
            (
                idx=idx, aspect=aspect, N=N,
                E_pcv=E_pcv, E_uni=E_uni, ΔE=ΔE,
                conv_pcv=conv_pcv, conv_uni=conv_uni,
                f_pcv=f_pcv, f_uni=f_uni,
                b_pcv=b_pcv, b_uni=b_uni,
                w_pcv_p1=w_pcv_p1, w_pcv_m1=w_pcv_m1,
                w_uni_p1=w_uni_p1, w_uni_m1=w_uni_m1,
                psi_pcv=psi_pcv, psi_uni=psi_uni,
            ),
        )
    end

    println("\n\n=== Phase diagram summary ===\n")
    @printf "%-3s  %-7s  %-7s  %-14s  %-14s  %-12s  %-6s\n" "#" "aspect" "N" "E_PCV" "E_uniform" "ΔE (PCV-uni)" "winner"
    for c in cells_out
        winner = c.ΔE < 0 ? "PCV" : "uniform"
        @printf "%-3d  %-7.3f  %-7d  %+.6e  %+.6e  %+.4e   %-6s\n" c.idx c.aspect c.N c.E_pcv c.E_uni c.ΔE winner
    end

    # Save (without psi to avoid huge files — keep summary)
    snapshot = [
        Dict(
            "idx" => c.idx, "aspect" => c.aspect, "N" => c.N,
            "E_pcv" => c.E_pcv, "E_uni" => c.E_uni, "ΔE" => c.ΔE,
            "conv_pcv" => c.conv_pcv, "conv_uni" => c.conv_uni,
            "f_pcv" => c.f_pcv, "f_uni" => c.f_uni,
            "b_pcv" => Dict(string(k) => getfield(c.b_pcv, k) for k in propertynames(c.b_pcv)),
            "b_uni" => Dict(string(k) => getfield(c.b_uni, k) for k in propertynames(c.b_uni)),
            "w_pcv" => (c.w_pcv_p1, c.w_pcv_m1),
            "w_uni" => (c.w_uni_p1, c.w_uni_m1),
        ) for c in cells_out
    ]
    @save joinpath(OUT_DIR, "phase_diagram_summary.jld2") snapshot
    @info "Saved phase diagram summary"

    println("\n=== Done ===")
end

main()
