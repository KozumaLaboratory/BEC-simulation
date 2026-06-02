#!/usr/bin/env julia
# scripts/sprint5_M1_ITP_cpu_scout.jl
#
# M1-ITP Gate-1 SCOUT (CPU forced — rotating_frame_omega + spinor + GPU
# scalar-indexes Coriolis step, known gotcha:
# gotcha_rotating_frame_omega_gpu_scalar_indexing.md).
#
# Scaled-down config for CPU envelope:
#   - 16³ box=(20,20,18) (vs digital twin 24³ box=(30,30,26))
#   - 3 Ω × 3 B = 9 cells (vs full 5×6=30 grid)
#   - 1 seed (polar) to start; multistart in follow-up if scout cells
#     show non-uniform basin behaviour
#
# Incremental checkpointing (per-cell save) preserves progress against
# any further WSL/CUDA driver crashes.
#
# Run: julia --project=. scripts/sprint5_M1_ITP_cpu_scout.jl

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

# Smaller grid for CPU envelope
const GRID = make_grid(GridConfig((16, 16, 16), (20.0, 20.0, 18.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))

const DT_ITP = 0.005
const N_ITP = 8000
const TOL_ITP = 1e-8

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const P_PER_NT = 0.148
const OMEGAS = [0.0, 0.3, 0.6]
const B_VALUES_NT = [0.0, 2.6, 10.0]
const OUT_DIR = "runs/sprint5_M1_ITP_cpu_scout"

function compute_grad_norm_cpu(ws::Workspace)
    psi = ws.state.psi
    grad = similar(psi)
    fill!(grad, 0.0)
    SpinorBEC.energy_gradient!(grad, psi, ws)
    dV = SpinorBEC.cell_volume(ws.grid)
    overlap = sum(conj.(psi) .* grad) * dV
    grad .-= overlap .* psi
    sqrt(real(sum(abs2, grad)) * dV)
end

function run_cell(omega::Float64, B_nT::Float64)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    # Pass lab-frame p directly; make_workspace adds the Barnett −Ω·F_z
    # via the rotating_frame_omega kwarg (sign corrected 2026-06-02).
    p_lab = B_nT * P_PER_NT
    zeeman = ZeemanParams(p_lab, 0.0)
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=:polar)
    # noise
    rng = MersenneTwister(1)
    @inbounds for i in eachindex(psi_init)
        psi_init[i] += 0.01 * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi_init) * SpinorBEC.cell_volume(GRID))
    psi_init ./= n

    t0 = time()
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=zeeman, potential=POT,
        dt=DT_ITP, n_steps=N_ITP, tol=TOL_ITP,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
        rotating_frame_omega=omega,
        backend=CPUBackend())
    t_run = time() - t0

    psi = ws.state.psi
    b = energy_decomposition(ws)
    grad_norm = compute_grad_norm_cpu(ws)
    sm = ws.spin_matrices
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    f_max = maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
    dV = SpinorBEC.cell_volume(GRID)
    fz_total = sum(fz) * dV
    m_dist = zeros(D)
    for c in 1:D
        m_dist[c] = sum(abs2, psi[:, :, :, c]) * dV
    end
    plans = ws.fft_plans
    Lz = orbital_angular_momentum(psi, ws.grid, plans)

    return (
        omega=omega, B_nT=B_nT,
        E=E, conv=conv, grad_norm=grad_norm,
        breakdown=b, fz_total=fz_total, Lz=Lz, f_max=f_max,
        m_dist=m_dist, time_min=t_run/60,
    )
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== M1-ITP CPU scout (16³, 9 cells) ===\n")
    @printf "N=%d, ω=(110,110,130) Hz, c_dd/c_0=%.4f\n" N_ATOMS (C_DD/C0)
    @printf "Sweep: %d Ω × %d B = %d cells (1 seed each)\n\n" length(OMEGAS) length(B_VALUES_NT) (
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
            try
                r = run_cell(Ω, B_nT)
                @printf "  E=%.6f conv=%s ‖∇E‖=%.3e ⟨F_z⟩=%+.3e ⟨L_z⟩=%+.3e f_max=%.3f (%.1f min)\n" r.E (
                    r.conv ? "✓" : "✗"
                ) r.grad_norm r.fz_total r.Lz r.f_max r.time_min
                push!(results, r)
                # Incremental checkpoint
                partial = [
                    Dict(
                        "omega" => r.omega, "B_nT" => r.B_nT,
                        "E" => r.E, "conv" => r.conv, "grad_norm" => r.grad_norm,
                        "breakdown" => Dict(
                            string(k) => getfield(r.breakdown, k) for
                            k in propertynames(r.breakdown)
                        ),
                        "fz_total" => r.fz_total, "Lz" => r.Lz, "f_max" => r.f_max,
                        "m_dist" => r.m_dist, "time_min" => r.time_min,
                    ) for r in results
                ]
                @save partial_path partial icell n_total
            catch err
                @warn "Cell failed" B_nT Ω err
            end
        end
    end

    println("\n\n=== Sweep summary ===\n")
    @printf "%-10s %-6s %-13s %-13s %-13s %-13s %-13s\n" "B[nT]" "Ω" "E" "⟨F_z⟩" "⟨L_z⟩" "f_max" "‖∇E‖"
    for r in results
        @printf "%-10.2f %-6.2f %.6f %+.4e %+.4e %.4f %.3e\n" r.B_nT r.omega r.E r.fz_total r.Lz r.f_max r.grad_norm
    end

    println("\n--- ⟨F_z⟩ map (Barnett response) ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        ;
        @printf "%-13.2f " Ω;
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            cell = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            if !isempty(cell)
                @printf "%+.4e " cell[1].fz_total
            else
                @printf "%-13s " "—"
            end
        end
        println()
    end

    println("\n--- ⟨L_z⟩ map (vortex/orbital response) ---")
    @printf "%-10s " "B\\Ω"
    for Ω in OMEGAS
        ;
        @printf "%-13.2f " Ω;
    end
    println()
    for B_nT in B_VALUES_NT
        @printf "%-10.2f " B_nT
        for Ω in OMEGAS
            cell = filter(r -> r.omega == Ω && r.B_nT == B_nT, results)
            if !isempty(cell)
                @printf "%+.4e " cell[1].Lz
            else
                @printf "%-13s " "—"
            end
        end
        println()
    end

    if !isempty(results)
        max_fz_r = results[argmax([abs(r.fz_total) for r in results])]
        @printf "\nMax |⟨F_z⟩|: %.4e at (B=%.1f nT, Ω=%.2f)\n" abs(max_fz_r.fz_total) max_fz_r.B_nT max_fz_r.omega
        if abs(max_fz_r.fz_total) > 0.01
            println("→ Barnett MEANINGFUL — theme stands at scout grid; scale to 24³ + finer (B,Ω)")
        elseif abs(max_fz_r.fz_total) > 1e-3
            println("→ Barnett MARGINAL — finer sweep needed near peak")
        else
            println("→ Barnett NEGLIGIBLE — framework reconsideration suggested")
        end
    end

    println("\n=== Done ===")
end

main()
