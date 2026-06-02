#!/usr/bin/env julia
# scripts/sprint5_A1_v3_digital_twin_gpu.jl
#
# Eu Matsui digital twin: A1 v3 3D follow-up at the actual experimental
# geometry and N. Uniform-vs-texture rank with full 3D MDDI on GPU.
#
# Digital twin parameters (Matsui Science 2026 reproduction target):
#   N = 5×10⁴, ω = (110, 110, 130) Hz, B_z = 0 (no Zeeman bias),
#   c_0 + F²c_1 = 4π·a_12·N/a_ho with a_12 = 110 a_B, c_1/c_0 = 1/36,
#   c_n = 0 for n ≥ 2 (Matsui-literal channel set).
#
# Grid: 24³ box=(30, 30, 26) on GPU. Bench showed 0.088 sec/step → 6 inits
# × 20000 ITP ≈ 3h wall-clock.
#
# 6 inits cover the two basins identified at 2D:
#   - icosahedral_explicit: uniform inert reference (winner at 2D N=2000)
#   - cyclic: uniform inert close runner-up (2D status unresolved, may
#     merge with I_h or be separate near-degenerate minimum)
#   - antiferromagnetic: reliable texture-basin seed (lattice-confirmed
#     at 2D 16² and 24²)
#   - ksu_circulation: KSU axial spontaneous circulation analog — the
#     axial-MDDI candidate quasi-2D undercounts the most
#   - polar_core_vortex: alternative axial vortex texture
#   - vortex_lattice: Li-Saito flux-closure ansatz
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/sprint5_A1_v3_digital_twin_gpu.jl

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000     # Matsui digital twin
const OMEGA_REF = 691.15

const GRID = make_grid(GridConfig((24, 24, 24), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 20000
const TOL_ITP = 1e-7

# Matsui-literal channel set: c_n = 0 for n ≥ 2
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const INITS = [
    :icosahedral_explicit,
    :cyclic,
    :antiferromagnetic,
    :ksu_circulation,
    :polar_core_vortex,
    :vortex_lattice,
]
const SEED = 1
const OUT_DIR = "runs/sprint5_A1_v3_digital_twin_gpu"

function build_psi(state::Symbol, sys)
    if state === :ksu_circulation
        psi = init_psi(GRID, sys; state=:m_plus_F)
        xs = GRID.x[1]
        ys = GRID.x[2]
        for k in 1:size(psi, 3), j in eachindex(ys), i in eachindex(xs)
            θ = atan(ys[j], xs[i])
            psi[i, j, k, 1] *= exp(im * θ)
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        psi ./= n
        return psi
    elseif state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(GRID, sys; state=:polar)
        for k in 1:size(psi, 3), j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, k, :)))
            for c in 1:size(psi, 4)
                psi[i, j, k, c] = spatial_amp * ζ[c]
            end
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        n > 0 && (psi ./= n)
        return psi
    else
        return init_psi(GRID, sys; state=state)
    end
end

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
    psi ./= n
end

function run_one(init_state::Symbol)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    sys = SpinSystem(F)
    psi_init = build_psi(init_state, sys)
    apply_noise!(psi_init, 0.01, SEED)
    initial_state_for_fgs = if init_state === :ksu_circulation
        :m_plus_F
    elseif init_state === :icosahedral_explicit
        :polar
    else
        init_state
    end
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL_ITP,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        backend=CUDABackend())
    return ws, E, conv
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi_host = Array(ws.state.psi)
    fx, fy, fz = spin_density_vector(psi_host, sm, 3)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)
    println("=== A1 v3 Eu Matsui digital twin (GPU 3D) ===\n")
    @printf "Atom: %s, N=%d, ω=(110, 110, 130) Hz aspect=(1,1,1.1818)\n" ATOM.name N_ATOMS
    @printf "Grid: 24³ box=(30, 30, 26) on GPU\n"
    @printf "c_total=%.4e c_dd=%.4e c_dd/c_total=%.4f\n" C_TOTAL C_DD_DIMLESS (
        C_DD_DIMLESS / C_TOTAL
    )
    @printf "Channel set: Matsui-literal (c_0=%.3e c_1=%.3e c_n=0 for n≥2)\n" C0 C1
    @printf "ITP: n_steps=%d tol=%.1e\n" N_STEPS_ITP TOL_ITP
    @printf "%d inits × 1 seed   |  bench est: ~3h\n\n" length(INITS)

    @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9

    results = []
    for init in INITS
        print("  init=$init seed=$SEED ... ")
        flush(stdout)
        t0 = time()
        try
            ws, E, conv = run_one(init)
            t_run = time() - t0
            b = energy_decomposition(ws)
            f_max = spin_density_max(ws)
            push!(results, (init=init, E=E, conv=conv, b=b, f_max=f_max,
                psi=Array(ws.state.psi)))
            @printf "E=%.6f conv=%s E_ddi=%+.4e E_spin=%+.4e f_max=%.4f (%.1f min)\n" E (
                conv ? "✓" : "✗"
            ) b.ddi b.spin f_max (t_run / 60)
        catch err
            println("FAILED: $err")
        end
        # Free GPU memory between runs
        CUDA.reclaim()
    end

    println("\n--- 3D digital-twin rank by E_total ---\n")
    sorted = sort(results; by=r -> r.E)
    @printf "  %-3s %-26s %-12s  %-12s  %-12s  %-12s  %-6s\n" "#" "init" "E_total" "E_ddi" "E_spin" "E_kin" "f_max"
    for (i, r) in enumerate(sorted)
        @printf "  %-3d %-26s %+.6e  %+.4e  %+.4e  %+.4e  %.4f\n" i string(r.init) r.E r.b.ddi r.b.spin r.b.kinetic r.f_max
    end

    println("\n--- Uniform vs texture ---\n")
    uniform = [:icosahedral_explicit, :cyclic]
    texture = [:antiferromagnetic, :ksu_circulation, :polar_core_vortex, :vortex_lattice]
    u_results = filter(r -> r.init in uniform, sorted)
    t_results = filter(r -> r.init in texture, sorted)
    if !isempty(u_results) && !isempty(t_results)
        u_best = u_results[1]
        t_best = t_results[1]
        ΔE = t_best.E - u_best.E
        @printf "Uniform best:  %-26s  E=%.6f  E_ddi=%+.4e  f_max=%.4f\n" string(u_best.init) u_best.E u_best.b.ddi u_best.f_max
        @printf "Texture best:  %-26s  E=%.6f  E_ddi=%+.4e  f_max=%.4f\n" string(t_best.init) t_best.E t_best.b.ddi t_best.f_max
        @printf "ΔE (texture − uniform) = %+.4e  (%.3f%% of uniform |E|)\n" ΔE (
            100ΔE / abs(u_best.E)
        )
        if ΔE < 0
            println()
            println("→ TEXTURE WINS in 3D digital-twin.")
            println("→ Eu GS is a magnetic spin texture (uniform-nematic loses to MDDI texturing).")
            println(
                "→ Track A and Track C converge: GS = vortex texture, not polyhedral inert state."
            )
        else
            println()
            println("→ Uniform inert still wins in 3D at digital-twin geometry.")
            println(
                "→ Gap shrunk from 2.7% (2D) to $(round(100ΔE/abs(u_best.E); digits=3))% in 3D; texture closer.",
            )
            println(
                "→ Track B (LHY/order-by-disorder) may still tip near boundary; check c_1 sensitivity.",
            )
        end
    end

    # Persist for downstream visualization
    snapshot = [
        Dict(
            "init" => string(r.init), "seed" => SEED,
            "E" => r.E, "conv" => r.conv,
            "breakdown" => Dict(string(k) => getfield(r.b, k) for k in propertynames(r.b)),
            "f_max" => r.f_max, "psi" => r.psi) for r in sorted
    ]
    save_path = joinpath(OUT_DIR, "digital_twin_states.jld2")
    @save save_path snapshot
    @info "Saved per-init relaxed states + breakdown to $save_path"

    println("\n=== Done ===")
end

main()
