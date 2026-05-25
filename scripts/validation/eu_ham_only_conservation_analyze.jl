# Eu Hamiltonian-only stationary-state conservation audit.
#
# Iterates over `runs/<variant>_<hash>/point_001.jld2` files (variant
# = `eu_ham_only_24_nonsec` etc.), computes conservation diagnostics
# (norm, energy, ⟨F_z⟩, ⟨L_z⟩, Jz drifts), and produces a side-by-side
# table including grid-convergence (24 / 32 / 48) and secular vs
# non-secular comparison.
#
# Each run_yaml invocation lands in `runs/<yaml_basename>_<contenthash>/`;
# this script auto-discovers the most-recent matching directory per
# variant.

using CodecZstd                                 # Force-load decompressor
using SpinorBEC
using JLD2
using Printf

const VARIANTS = ["eu_ham_only_24_nonsec", "eu_ham_only_32_nonsec",
                  "eu_ham_only_48_nonsec", "eu_ham_only_24_sec"]

struct VariantStats
    variant::String
    n_grid::Int
    secular::Bool
    found::Bool
    norm_init::Float64
    norm_drift::Float64
    E_init::Float64
    E_drift::Float64
    E_rel_drift::Float64
    Fz_init::Float64
    Fz_drift::Float64
    Lz_init::Float64
    Lz_drift::Float64
    Jz_init::Float64
    Jz_drift::Float64
end

function analyze_variant(variant::String)
    # variant = "eu_ham_only_<grid>_<sec|nonsec>"
    parts = split(variant, "_")
    n_grid = parse(Int, parts[end-1])
    secular = parts[end] == "sec"

    # Auto-discover most-recent matching run dir: runs/<variant>_<hash>/
    candidates = filter(d -> startswith(d, variant * "_"), readdir("runs"))
    isempty(candidates) && return VariantStats(variant, n_grid, secular, false,
        NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN)
    sort!(candidates; by=d -> stat(joinpath("runs", d)).mtime, rev=true)
    run_dir = joinpath("runs", first(candidates))
    path = joinpath(run_dir, "point_001.jld2")
    if !isfile(path)
        return VariantStats(variant, n_grid, secular, false,
            NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN)
    end

    d = JLD2.load(path)
    times = d["dynamics/times"]::Vector{Float64}
    energies = d["dynamics/energies"]::Vector{Float64}
    norms = d["dynamics/norms"]::Vector{Float64}
    Fz = d["dynamics/Fz"]::Vector{Float64}

    # Compute Lz from snapshots
    n_snap = d["dynamics/psi_snapshots_streamed/n_snapshots"]::Int
    grid = make_grid(GridConfig((n_grid, n_grid, n_grid), (10.0, 10.0, 10.0)))
    plans = make_fft_plans((n_grid, n_grid, n_grid); flags=SpinorBEC.FFTW.ESTIMATE)
    Lz_snap = Float64[]
    for k in 1:n_snap
        key = @sprintf("dynamics/psi_snapshots_streamed/frame_%05d", k)
        haskey(d, key) || continue
        psi = ComplexF64.(d[key])
        push!(Lz_snap, orbital_angular_momentum(psi, grid, plans))
    end

    # Snapshots are at t = save_every·dt, ..., n_steps·dt (10 frames). Times
    # array has 11 entries including t=0 + the 10 snapshot times. Pair Lz
    # snapshots with times[2..11], so the snapshot Lz aligns with Fz[2..11].
    n_lz = length(Lz_snap)
    if n_lz != length(times) - 1
        @warn "Lz frame count $n_lz ≠ length(times)-1 = $(length(times)-1) in $variant"
    end
    # Build Lz "history" aligned to times[2..end]:
    Lz_hist = Lz_snap

    # Drift over snapshot window: index 1 corresponds to t=times[2], index end to t=times[end].
    Fz_window = Fz[2:end]
    energies_window = energies[2:end]
    norms_window = norms[2:end]

    # Use longest-common window
    n = min(length(Fz_window), length(Lz_hist), length(energies_window), length(norms_window))
    Fz_w = Fz_window[1:n]
    Lz_w = Lz_hist[1:n]
    E_w = energies_window[1:n]
    nrm_w = norms_window[1:n]
    Jz_w = Fz_w .+ Lz_w

    norm_drift = maximum(abs.(nrm_w .- nrm_w[1]))
    E_drift = maximum(abs.(E_w .- E_w[1]))
    E_rel = E_drift / max(abs(E_w[1]), 1e-12)
    Fz_drift = maximum(abs.(Fz_w .- Fz_w[1]))
    Lz_drift = maximum(abs.(Lz_w .- Lz_w[1]))
    Jz_drift = maximum(abs.(Jz_w .- Jz_w[1]))

    VariantStats(variant, n_grid, secular, true,
        nrm_w[1], norm_drift,
        E_w[1], E_drift, E_rel,
        Fz_w[1], Fz_drift,
        Lz_w[1], Lz_drift,
        Jz_w[1], Jz_drift)
end

println("Eu Hamiltonian-only stationary-state conservation audit")
println("=" ^ 80)
stats = [analyze_variant(v) for v in VARIANTS]

@printf("\n%-12s | %5s | %-7s | %8s | %12s | %12s | %12s | %12s\n",
        "variant", "grid", "secular", "norm Δ", "|ΔE|", "|ΔE/E|", "|ΔFz|", "|ΔJz|")
println("-"^120)
for s in stats
    if !s.found
        @printf("%-12s | %5d | %-7s | (not yet — point_001.jld2 missing)\n",
                s.variant, s.n_grid, s.secular ? "true" : "false")
        continue
    end
    @printf("%-12s | %5d | %-7s | %.2e | %+12.4e | %.4e | %.4e | %.4e\n",
            s.variant, s.n_grid, s.secular ? "true" : "false",
            s.norm_drift, s.E_drift, s.E_rel_drift, s.Fz_drift, s.Jz_drift)
end

# Convergence check: 24 → 32 → 48 nonsec
nonsec = filter(s -> s.found && !s.secular, stats)
sort!(nonsec; by=s -> s.n_grid)
if length(nonsec) >= 2
    println("\nConvergence of |ΔJz| with grid (secular=false):")
    for i in eachindex(nonsec)
        s = nonsec[i]
        if i == 1
            @printf("  %d³ : %.4e\n", s.n_grid, s.Jz_drift)
        else
            prev = nonsec[i-1]
            ratio = s.Jz_drift / max(prev.Jz_drift, 1e-15)
            @printf("  %d³ : %.4e   (× %.3f vs %d³)\n", s.n_grid, s.Jz_drift, ratio, prev.n_grid)
        end
    end
end

# Secular comparison at 24³
sec24 = filter(s -> s.found && s.n_grid == 24 && s.secular, stats)
nonsec24 = filter(s -> s.found && s.n_grid == 24 && !s.secular, stats)
if !isempty(sec24) && !isempty(nonsec24)
    s_sec = sec24[1]
    s_non = nonsec24[1]
    println("\nSecular vs non-secular at 24³:")
    @printf("  non-secular |ΔJz| = %.4e\n", s_non.Jz_drift)
    @printf("  secular     |ΔJz| = %.4e   (× %.3f)\n",
            s_sec.Jz_drift, s_sec.Jz_drift / max(s_non.Jz_drift, 1e-15))
    @printf("  non-secular |ΔE|  = %.4e\n", s_non.E_drift)
    @printf("  secular     |ΔE|  = %.4e   (× %.3f)\n",
            s_sec.E_drift, s_sec.E_drift / max(s_non.E_drift, 1e-15))
end
