#!/usr/bin/env julia
# scripts/sprint5_A1_v3_analyze.jl
#
# Post-processor for A1 v3. Reads the v3 stdout log, identifies the top-K
# states by E_total, re-relaxes them with the SAME ITP envelope, saves
# jld2 + emits diagnostic plots (|f|(r), |ψ_m|² per component, spinor
# texture summary).
#
# Why re-relax instead of saving inside v3: v3 was launched before we
# decided to keep all ws's. Re-relaxing ~3 winners is < 10 min vs ~70
# min for the full scan, so re-running just the winners is cheap.
#
# Outputs (in runs/sprint5_A1_v3_analysis/):
#   - top_states.jld2  — relaxed ψ + breakdown per top-K state
#   - rank_summary.csv  — full rank parsed from log
#   - figures/<label>.png — |f|(r) heatmap + per-m density maps (if Makie)
#
# Run AFTER `scripts/sprint5_A1_v3_texture_inclusive.jl` finishes:
#   julia --project=. scripts/sprint5_A1_v3_analyze.jl

using SpinorBEC
using LinearAlgebra
using Random
using Printf
using JLD2

const LOG_PATH = "runs/sprint5_A1_v3_log.txt"
const OUT_DIR = "runs/sprint5_A1_v3_analysis"
const TOP_K = 5

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((16, 16), (8.0, 8.0)))
const POT = HarmonicTrap{2}((1.0, 1.0))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 20000   # looser than v3 (8000) to actually reach conv=✓
const TOL_ITP = 1e-7         # relaxed from 1e-10 (cluster A gap ~0.1% is above this)
const L_Z_DDI = 1.0

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

# Parse v3 log to extract (init, seed, E) tuples
function parse_v3_log(path::AbstractString)
    rows = NamedTuple{(:init, :seed, :E, :f_max), Tuple{Symbol, Int, Float64, Float64}}[]
    isfile(path) || error("log not found: $path")
    for line in eachline(path)
        # `init=... seed=... ... E=... conv=... [E_ddi=...] f_max=...`
        m = match(r"init=(\S+)\s+seed=(\d+)\s+\.\.\.\s+E=([-\d.eE]+).*?f_max=([-\d.eE]+)", line)
        m === nothing && continue
        push!(
            rows,
            (
                init=Symbol(m.captures[1]),
                seed=parse(Int, m.captures[2]),
                E=parse(Float64, m.captures[3]),
                f_max=parse(Float64, m.captures[4])),
        )
    end
    rows
end

# Same build_psi as v3
function build_psi(state::Symbol, sys)
    if state === :magnetic_domain_stripe
        return init_psi(GRID, sys; state=:magnetic_domain, init_vortex_charge=1)
    elseif state === :magnetic_domain_square
        return init_psi(GRID, sys; state=:magnetic_domain, init_vortex_charge=2)
    elseif state === :ksu_circulation
        psi = init_psi(GRID, sys; state=:m_plus_F)
        xs = GRID.x[1]
        ys = GRID.x[2]
        for j in eachindex(ys), i in eachindex(xs)
            θ = atan(ys[j], xs[i])
            psi[i, j, 1] *= exp(im * θ)
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        psi ./= n
        return psi
    elseif state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(GRID, sys; state=:polar)
        for j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, :)))
            for c in 1:size(psi, 3)
                psi[i, j, c] = spatial_amp * ζ[c]
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

function relax(init_state::Symbol, seed::Int)
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    sys = SpinSystem(F)
    psi_init = build_psi(init_state, sys)
    apply_noise!(psi_init, 0.01, seed)
    initial_state_for_fgs = if init_state in (:magnetic_domain_stripe, :magnetic_domain_square)
        :magnetic_domain
    elseif init_state === :ksu_circulation
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
        quasi_2d=true, l_z=L_Z_DDI)
    return ws, E, conv
end

function spin_density_field(ws)
    sm = ws.spin_matrices
    psi = ws.state.psi
    ndim = ndims(psi) - 1
    fx, fy, fz = spin_density_vector(psi, sm, ndim)
    (fx=fx, fy=fy, fz=fz, f_mag=sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function density_per_m(ws)
    psi = ws.state.psi
    ndim = ndims(psi) - 1
    D = size(psi, ndim + 1)
    Dict(c => abs2.(view(psi, ntuple(_ -> Colon(), ndim)..., c)) for c in 1:D)
end

function main()
    isdir(OUT_DIR) || mkpath(OUT_DIR)

    rows = parse_v3_log(LOG_PATH)
    if isempty(rows)
        @warn "v3 log empty or no parseable lines yet — has v3 finished?"
        return nothing
    end
    sorted = sort(rows; by=r -> r.E)

    # CSV rank summary
    open(joinpath(OUT_DIR, "rank_summary.csv"), "w") do io
        println(io, "rank,init,seed,E_total,f_max")
        for (i, r) in enumerate(sorted)
            println(io, "$i,$(r.init),$(r.seed),$(r.E),$(r.f_max)")
        end
    end
    @info "Parsed log → $(length(rows)) entries, top-1 = $(sorted[1].init) seed=$(sorted[1].seed) E=$(sorted[1].E)"

    # Re-relax top-K, save state
    top = sorted[1:min(TOP_K, end)]
    saved = []
    for (i, r) in enumerate(top)
        @info "Re-relaxing top-$i: init=$(r.init) seed=$(r.seed)"
        ws, E, conv = relax(r.init, r.seed)
        b = energy_decomposition(ws)
        f = spin_density_field(ws)
        nm = density_per_m(ws)
        entry = Dict(
            "rank" => i,
            "init" => string(r.init),
            "seed" => r.seed,
            "E" => E,
            "conv" => conv,
            "breakdown" => Dict(string(k) => getfield(b, k) for k in propertynames(b)),
            "psi" => Array(ws.state.psi),
            "f_mag" => f.f_mag, "fx" => f.fx, "fy" => f.fy, "fz" => f.fz,
            "density_per_m" => nm,
        )
        push!(saved, entry)
        @printf "  E=%.6f  E_ddi=%+.4e  conv=%s  f_max=%.4f\n" E b.ddi (conv ? "✓" : "✗") maximum(
            f.f_mag
        )
    end

    save_path = joinpath(OUT_DIR, "top_states.jld2")
    @save save_path saved
    @info "Saved top-$TOP_K relaxed states to $save_path"

    # Diagnostic text summary
    open(joinpath(OUT_DIR, "diagnostic.txt"), "w") do io
        println(io, "=== A1 v3 top-$TOP_K diagnostic ===\n")
        for entry in saved
            @printf io "rank %d: init=%s seed=%d  E=%.6f  conv=%s\n" entry["rank"] entry["init"] entry["seed"] entry["E"] (
                entry["conv"] ? "✓" : "✗"
            )
            b = entry["breakdown"]
            @printf io "  E_kin=%.4e  E_trap=%.4e  E_density=%.4e  E_spin=%.4e  E_ddi=%.4e\n" b["kinetic"] b["trap"] b["density"] b["spin"] b["ddi"]
            @printf io "  max(|f|) = %.4e   E_ddi/E_total = %.3e\n\n" maximum(entry["f_mag"]) (
                b["ddi"] / b["total"]
            )
        end
    end

    println()
    println("=== Done. Outputs in $OUT_DIR ===")
end

main()
