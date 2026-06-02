#!/usr/bin/env julia
# scripts/sprint5_M1_ITP_omega_sweep_polished.jl
#
# Track M1-ITP — Gate-1 (B, Ω) sweep at production convergence.
# Promotes the scout run (sprint5_M1_ITP_omega_sweep.jl, N_LBFGS=0) to
# load-bearing verdict numbers via ITP warm-up + LBFGS polish on the
# correct rotating-frame functional. Reports ‖∇E‖ from the LBFGS final
# point as the verdict-gate residual.
#
# Both ITP (Strang propagator) and LBFGS (post-2026-06-02 with Coriolis
# −Ω·L_z·ψ added to `energy_gradient!`) now optimise the same rotating-
# frame functional. The LBFGS polish picks up where ITP plateaus and
# drives ‖∇E‖ to LBFGS tol.
#
# Sweep: 5 Ω × 6 B = 30 cells, polar seed.
# ITP n_steps=2000, dt=0.005, tol=1e-7 → LBFGS n_steps=1000, tol=1e-5,
# Sobolev α=0.02.
# Gate: conv=✓ and ‖∇E‖ < 1e-5 required for a cell to count as converged.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_M1_ITP_omega_sweep_polished.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const D = 2F + 1
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24, 24, 24), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))

const DT_ITP = 0.005
const N_ITP = 2000
const TOL_ITP = 1e-7
const N_LBFGS = 1000
const TOL_LBFGS = 1e-5
const SOBOLEV = 0.02
const NOISE_AMP = 0.01

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD = SpinorBEC.compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const P_PER_NT = 0.148
const OMEGAS = [0.0, 0.1, 0.2, 0.4, 0.6]
const B_VALUES_NT = [0.0, 1.0, 2.6, 5.0, 10.0, 100.0]
const NOISE_SEED = 1
const OUT_DIR = "runs/sprint5_M1_ITP_omega_sweep_polished"

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int, grid::Grid)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    psi ./= n
end

function run_cell(omega::Float64, B_nT::Float64)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    p_lab = B_nT * P_PER_NT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),
        ConstantWaveform(0.0),
        ConstantWaveform(p_lab),
        ConstantWaveform(0.0),
    )

    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:polar)
    apply_noise!(psi_init, NOISE_AMP, NOISE_SEED, GRID)

    # Stage 1: ITP warm-up (Strang propagator includes Coriolis substep).
    t0 = time()
    r_itp = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=zeeman, potential=POT,
        dt=DT_ITP, n_steps=N_ITP, tol=TOL_ITP,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        rotating_frame_omega=omega,
        backend=CUDABackend())
    t_itp = time() - t0
    ws_itp = r_itp.workspace
    E_itp = r_itp.energy

    # Stage 2: LBFGS polish on the same rotating-frame workspace. `ws_init`
    # carries the rotating_frame_omega in sim_params so the Coriolis
    # gradient term (added 2026-06-02) and the centrifugal trap +
    # Barnett Zeeman shift all activate consistently.
    t0 = time()
    r_lbfgs = SpinorBEC.find_ground_state_lbfgs(;
        ws_init=ws_itp,
        n_steps=N_LBFGS, tol=TOL_LBFGS,
        verbose=false,
        sobolev_alpha=SOBOLEV,
    )
    t_lbfgs = time() - t0
    ws = r_lbfgs.workspace
    E = r_lbfgs.energy
    conv_lbfgs = r_lbfgs.converged
    grad_norm = r_lbfgs.grad_norm

    psi = Array(ws.state.psi)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
    dV = SpinorBEC.cell_volume(GRID)
    fz_total = sum(fz) * dV
    fx_total = sum(fx) * dV
    fy_total = sum(fy) * dV
    m_dist = zeros(D)
    for c in 1:D
        m_dist[c] = sum(abs2, psi[:, :, :, c]) * dV
    end
    Lz = orbital_angular_momentum(psi, ws.grid, ws.fft_plans)
    CUDA.reclaim()
    return (
        omega=omega, B_nT=B_nT,
        E=E, E_itp=E_itp,
        conv_lbfgs=conv_lbfgs, grad_norm=grad_norm,
        fx_total=fx_total, fy_total=fy_total, fz_total=fz_total,
        Lz=Lz, f_max=f_max, m_dist=m_dist,
        time_itp_min=t_itp/60, time_lbfgs_min=t_lbfgs/60,
    )
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== M1-ITP polished — rotating-frame Ω×B sweep ===\n")
    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    @printf "N=%d, ω=(110,110,130) Hz, c_dd/c_0=%.4f\n" N_ATOMS (C_DD/C0)
    @printf "Long-ITP: n_steps=%d dt=%.4f tol=%.0e (imag-time = %.1f)\n" N_ITP DT_ITP TOL_ITP (
        N_ITP * DT_ITP
    )
    @printf "Sweep: %d Ω × %d B = %d cells (polar seed)\n\n" length(OMEGAS) length(B_VALUES_NT) (
        length(OMEGAS) * length(B_VALUES_NT)
    )

    results = []
    icell = 0
    n_total = length(OMEGAS) * length(B_VALUES_NT)
    partial_path = joinpath(OUT_DIR, "partial.jld2")

    for B_nT in B_VALUES_NT
        for Ω in OMEGAS
            icell += 1
            @printf "\n[cell %d/%d] B=%.1f nT, Ω=%.2f\n" icell n_total B_nT Ω
            flush(stdout)
            r = run_cell(Ω, B_nT)
            gate = (r.conv_lbfgs && r.grad_norm < TOL_LBFGS) ? "✓✓" : (
                r.conv_lbfgs ? "✓∇" : "✗"
            )
            @printf "  E=%.6f conv=%s ‖∇E‖=%.3e ⟨F_z⟩=%+.3e ⟨L_z⟩=%+.3e f_max=%.3f (ITP %.1f / LBFGS %.1f min)\n" r.E gate r.grad_norm r.fz_total r.Lz r.f_max r.time_itp_min r.time_lbfgs_min
            push!(results, r)

            partial = [
                Dict(
                    "omega" => r.omega, "B_nT" => r.B_nT,
                    "E" => r.E, "E_itp" => r.E_itp,
                    "conv_lbfgs" => r.conv_lbfgs, "grad_norm" => r.grad_norm,
                    "fx_total" => r.fx_total, "fy_total" => r.fy_total,
                    "fz_total" => r.fz_total, "Lz" => r.Lz, "f_max" => r.f_max,
                    "m_dist" => r.m_dist,
                    "time_itp_min" => r.time_itp_min, "time_lbfgs_min" => r.time_lbfgs_min,
                ) for r in results
            ]
            @save partial_path partial icell n_total
        end
    end

    println("\n\n=== Polished Ω×B sweep — per-cell summary ===\n")
    @printf "%-10s %-6s %-13s %-9s %-13s %-13s %-13s %-13s\n" "B[nT]" "Ω" "E" "‖∇E‖" "⟨F_z⟩" "⟨L_z⟩" "⟨F_x⟩" "f_max"
    for r in results
        gate = (r.conv_lbfgs && r.grad_norm < TOL_LBFGS) ? "✓✓" : "✗"
        @printf "%-10.2f %-6.2f %.6f %.3e %+.4e %+.4e %+.4e %.4f  %s\n" r.B_nT r.omega r.E r.grad_norm r.fz_total r.Lz r.fx_total r.f_max gate
    end

    println("\n--- ⟨F_z⟩(B, Ω) ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        @printf "%-13.2f " Ω
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            cell = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            isempty(cell) ? @printf("%-13s ", "—") : @printf("%+.4e ", cell[1].fz_total)
        end
        println()
    end

    println("\n--- ⟨L_z⟩(B, Ω) ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        @printf "%-13.2f " Ω
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            cell = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            isempty(cell) ? @printf("%-13s ", "—") : @printf("%+.4e ", cell[1].Lz)
        end
        println()
    end

    println("\n--- ‖∇E‖(B, Ω) convergence gate ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        @printf "%-13.2f " Ω
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            cell = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            isempty(cell) ? @printf("%-13s ", "—") : @printf("%.3e   ", cell[1].grad_norm)
        end
        println()
    end

    n_conv = count(r -> r.conv_lbfgs && r.grad_norm < TOL_LBFGS, results)
    println("\nConverged cells: $n_conv / $(length(results))")
    println("\n=== Done ===")

    snapshot = [
        Dict(
            "omega" => r.omega, "B_nT" => r.B_nT,
            "E" => r.E, "E_itp" => r.E_itp,
            "conv_lbfgs" => r.conv_lbfgs, "grad_norm" => r.grad_norm,
            "fx_total" => r.fx_total, "fy_total" => r.fy_total,
            "fz_total" => r.fz_total, "Lz" => r.Lz, "f_max" => r.f_max,
            "m_dist" => r.m_dist,
            "time_itp_min" => r.time_itp_min, "time_lbfgs_min" => r.time_lbfgs_min,
        ) for r in results
    ]
    @save joinpath(OUT_DIR, "polished_sweep.jld2") snapshot
end

main()
