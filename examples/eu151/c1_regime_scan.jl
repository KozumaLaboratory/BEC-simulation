include(joinpath(@__DIR__, "eu151_params.jl"))
using Printf, Random, FFTW, JLD2

# ================================================================
# c₁ regime scan for sequential EdH observation
#
# With physical c₁/c₀≈1/36 and c_dd≈7647, DDI instability rate
# (γ_max≈182ω) dominates spin-exchange (c₁×n≈0.26ω) by ~700×.
# This scan explores whether stronger c₁ or disabling DDI reveals
# sequential mF→mF-1 transfer.
#
# Configs:
#   1. Physical:  c₁/c₀=1/36,  DDI on  (baseline)
#   2. Enhanced:  c₁/c₀=1/12,  DDI on  (3× spin-exchange)
#   3. Strong:    c₁/c₀=1/6,   DDI on  (6× spin-exchange)
#   4. Dominant:  c₁/c₀=1/3,   DDI on  (12× spin-exchange)
#   5. Control:   c₁/c₀=1/36,  DDI off (pure spin-exchange)
#
# All start from pure mF=+6 (scalar GS without DDI).
# Short runs: 0.5 ms ≈ 0.345 ω⁻¹
# ================================================================

N_GRID = parse(Int, get(ENV, "NGRID", "32"))
BOX = 20.0

configs = [
    ("phys",     1.0/36.0, true),
    ("c1×3",     1.0/12.0, true),
    ("c1×6",     1.0/6.0,  true),
    ("c1×12",    1.0/3.0,  true),
    ("no-DDI",   1.0/36.0, false),
]

println("=" ^ 70)
@printf("  Eu151 c₁ regime scan (%d³, box=%.0f)\n", N_GRID, BOX)
@printf("  c_total = %.1f, c_dd = %.1f, p = %.4f\n", EU_c_total, EU_c_dd, EU_p_weak)
println("-" ^ 70)
for (label, ratio, use_ddi) in configs
    ip = eu_interaction_params(ratio)
    @printf("  %-8s: c1/c0=%+.4f, c0=%.1f, c1=%+.1f, DDI=%s\n",
        label, ratio, ip.c0, ip.c1, use_ddi ? "on" : "off")
end
println("=" ^ 70)

grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> BOX, 3)))
atom = AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0)
D = 13
dV = cell_volume(grid)
sys = SpinSystem(6)
trap = HarmonicTrap((1.0, 1.0, EU_λ_z))

# Scalar ground state (no DDI, no c₁) → pure mF=+6
cache_file = joinpath(@__DIR__, "cache_eu151_gs_3d_$(N_GRID).jld2")
psi_gs = if isfile(cache_file)
    @printf("Loading cached ground state: %s\n", cache_file)
    load(cache_file, "psi")
else
    println("Computing scalar ground state (no DDI)...")
    gs = find_ground_state(;
        grid, atom,
        interactions=InteractionParams(EU_c_total, 0.0),
        zeeman=ZeemanParams(100.0, 0.0),
        potential=trap,
        dt=0.005, n_steps=15000, tol=1e-9,
        initial_state=:ferromagnetic,
        enable_ddi=false,
        fft_flags=FFTW.MEASURE,
    )
    @printf("  converged=%s, energy=%.2f\n", gs.converged, gs.energy)
    save(cache_file, "psi", gs.workspace.state.psi)
    gs.workspace.state.psi
end

n_dens = SpinorBEC.total_density(psi_gs, 3)
n_peak = maximum(n_dens)
pops_gs = [sum(abs2, @view(psi_gs[:,:,:,c])) * dV for c in 1:D]
@printf("  P(+6)=%.6f, n_peak=%.4e, norm=%.8f\n\n", pops_gs[1], n_peak, sum(abs2, psi_gs) * dV)

# Dynamics parameters
dt = 2e-4
t_final = parse(Float64, get(ENV, "T_FINAL", "0.345"))  # 0.5 ms in ω⁻¹
n_steps = round(Int, t_final / dt)
save_every = max(1, round(Int, 0.002 / dt))

results = Dict{String, NamedTuple}()

for (label, c1_ratio, use_ddi) in configs
    ip = eu_interaction_params(c1_ratio)
    c_dd_eff = use_ddi ? EU_c_dd : 0.0

    println("\n" * "=" ^ 70)
    @printf("  %s  (c0=%.1f, c1=%+.1f, c_dd=%.0f)\n", label, ip.c0, ip.c1, c_dd_eff)
    @printf("  c1×n_peak=%.3f ω, DDI rate≈%.0f ω\n",
        ip.c1 * n_peak, c_dd_eff * n_peak * 6)
    println("=" ^ 70)

    psi = copy(psi_gs)
    Random.seed!(42)
    SpinorBEC._add_noise!(psi, 0.001, D, 3, grid)

    sp = SimParams(; dt, n_steps=1)
    ws = make_workspace(;
        grid, atom,
        interactions=ip,
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=trap,
        sim_params=sp,
        psi_init=psi,
        enable_ddi=use_ddi, c_dd=EU_c_dd,
        fft_flags=FFTW.MEASURE,
    )

    @printf("%8s | %6s | ", "t(μs)", "P(+6)")
    for m in 5:-1:-6
        @printf("P(%+d) ", m)
    end
    @printf("| %8s\n", "Sz")
    println("-" ^ 110)

    data_t = Float64[]
    data_pops = Vector{Float64}[]
    data_sz = Float64[]

    function record_snap!(ws)
        t = ws.state.t
        t_us = t * EU_t_unit * 1e6
        pops = Float64[sum(abs2, @view(ws.state.psi[:,:,:,c])) * dV for c in 1:D]
        Sz = magnetization(ws.state.psi, grid, sys)

        push!(data_t, t)
        push!(data_pops, pops)
        push!(data_sz, Sz)

        @printf("%8.1f | %6.4f | ", t_us, pops[1])
        for c in 2:D
            @printf("%.3f ", pops[c])
        end
        @printf("| %+8.4f\n", Sz)
    end

    record_snap!(ws)

    for _ in 1:3; split_step!(ws); end

    t0 = time()
    for step in 4:(n_steps + 3)
        split_step!(ws)
        if (step - 3) % save_every == 0
            record_snap!(ws)
        end
    end
    wall = time() - t0
    @printf("\n  %d steps in %.1fs (%.2f ms/step)\n", n_steps, wall, wall / n_steps * 1000)

    # Analysis
    t_p6_09 = let idx = findfirst(p -> p[1] < 0.9, data_pops)
        idx !== nothing ? data_t[idx] * EU_t_unit * 1e6 : NaN
    end
    t_p6_05 = let idx = findfirst(p -> p[1] < 0.5, data_pops)
        idx !== nothing ? data_t[idx] * EU_t_unit * 1e6 : NaN
    end

    seq_ratio = NaN
    sequential = false
    idx50 = findfirst(p -> p[1] < 0.5, data_pops)
    if idx50 !== nothing
        pops_50 = data_pops[idx50]
        seq_ratio = pops_50[2] / max(pops_50[3], 1e-10)
        sequential = pops_50[2] > pops_50[3] > pops_50[4]
        println("\n  Growth pattern at P(+6)=0.5:")
        sorted = sort(collect(enumerate(pops_50)), by=x -> -x[2])
        for (rank, (c, pop)) in enumerate(sorted[1:min(5, length(sorted))])
            m = 6 - (c - 1)
            @printf("    rank %d: m=%+3d, P=%.4f\n", rank, m, pop)
        end
        @printf("  Sequential (P₅>P₄>P₃)? %s\n", sequential ? "YES" : "NO")
        @printf("  P(+5)/P(+4) = %.2f\n", seq_ratio)
    end

    results[label] = (;
        c1_ratio, c0=ip.c0, c1=ip.c1, c_dd=c_dd_eff,
        t_p6_09, t_p6_05, seq_ratio, sequential,
        final_Sz=data_sz[end],
        final_pops=data_pops[end],
    )
end

# Comparison table
println("\n" * "=" ^ 70)
println("  COMPARISON TABLE")
println("=" ^ 70)
@printf("%-8s | %7s | %+8s | %7s | %10s | %10s | %8s | %4s\n",
    "Config", "c_dd", "c1", "c1×n", "P6<0.9(μs)", "P6<0.5(μs)", "P5/P4", "Seq?")
println("-" ^ 85)
for (label, _, _) in configs
    haskey(results, label) || continue
    r = results[label]
    @printf("%-8s | %7.0f | %+8.1f | %7.3f | %10.1f | %10.1f | %8.2f | %4s\n",
        label, r.c_dd, r.c1, r.c1 * n_peak, r.t_p6_09, r.t_p6_05,
        r.seq_ratio, r.sequential ? "YES" : "NO")
end
