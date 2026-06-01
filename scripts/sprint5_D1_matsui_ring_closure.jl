#!/usr/bin/env julia
# scripts/sprint5_D1_matsui_ring_closure.jl
#
# Track D1 ONE-SHOT closure (per North Star plan execution discipline:
# do this ONCE properly, do NOT iterate further). Goal: confirm or refute
# the FM=2 vs AFM=3 ring contrast on m=−4 for Eu at Matsui conditions,
# matching the spectroscopy-route AFM c_1 sign.
#
# Four fixes from the v_extended retraction:
#   (1) Output to file (not via wrapper tail) — both FM and AFM survive.
#   (2) Spin-dependent K_3 profile calibrated to Matsui's ~40%/40 ms total
#       loss with cascade products enhanced (m=-6 immune, m=-5/-4/-3
#       enhanced). K_3 magnitudes are around the calibrated baseline ≈ 50.
#   (3) Two grid sizes (16³ and 24³) for lattice-convergence test on the
#       ring count. The discriminator survives only if count agrees
#       between sizes.
#   (4) Robust ring count via radial smoothing + threshold on |ψ|² with
#       a minimum-prominence local-max detector (NOT raw bin peaks).
#
# Result is a 2 × 2 table: (FM, AFM) × (16³, 24³) → ring counts. Closure
# criterion: FM = AFM−1 and both stable across grid → spectroscopy ↔
# ring-count consistent on c_1 sign. Anything else: documented and we
# move on (no further D1 polish).
#
# Expected wall-clock: ~ 2 hours total (4 dynamics runs, the 24³ ones
# dominate). Run as a single overnight / background job.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const POT16 = HarmonicTrap{3}((1.0, 1.0, 1.182))
const POT24 = HarmonicTrap{3}((1.0, 1.0, 1.182))
const ZEEMAN = ZeemanParams(0.3, 0.0)   # Matsui Phase 2 (~2.6 nT)
const T_EVOLVE = 28.0                    # 40 ms ≈ Matsui regime
const DT = 0.005
const N_STEPS = Int(round(T_EVOLVE / DT))

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const SCENARIOS = [("FM", 0.0), ("AFM", 1.0 / 18.0)]
const GRIDS = [(16, 16, 12), (24, 24, 18)]
const BOX = (10.0, 10.0, 8.0)
const OUT_FILE = "scripts/_d1_closure_output.txt"

# Spin-dependent K_3 calibrated to Matsui's ~40% over 40 ms with cascade
# products doing most of the loss (Matsui paper notes m=−6 survival dominates).
function k3_per_m()
    k3 = zeros(Float64, 2F + 1)
    for c in 1:(2F + 1)
        m = F - (c - 1)
        k3[c] = if m == -F
            5.0              # stretched immune
        elseif m in (-F + 1, -F + 2, -F + 3)
            80.0    # cascade products
        else    # cascade products
            30.0                            # other m
        end                            # other m
    end
    k3
end

function run_dynamics(c1_ratio::Float64, grid_size::NTuple{3, Int})
    grid = make_grid(GridConfig(grid_size, BOX))
    pot = HarmonicTrap{3}((1.0, 1.0, 1.182))
    c0 = C_TOTAL / (1 + F^2 * c1_ratio)
    c1 = c1_ratio * c0
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => c0, 1 => c1,
            2 => 0.05 * c0, 4 => 0.02 * c0, 6 => 0.005 * c0)
    )
    sp = SimParams(; dt=DT, n_steps=N_STEPS, imaginary_time=false,
        normalize_every=0, save_every=N_STEPS)
    sys = SpinSystem(F)
    psi_init = init_psi(grid, sys; state=:m_minus_F)
    loss = LossParams(; K3_per_m_cubic=k3_per_m())
    ws = make_workspace(;
        grid=grid, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=pot, sim_params=sp,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        loss=loss)
    for _ in 1:N_STEPS
        SpinorBEC.split_step!(ws)
    end
    ws
end

"""Robust radial profile: density integrated over thin radial shells, with
finer binning than the local-peak bin width to break the alternating-zero
discretisation artefact."""
function radial_profile_smooth(ws, m_target::Int)
    psi = ws.state.psi
    F_loc = ws.atom.F
    c_idx = (F_loc - m_target) + 1
    nx, ny, nz = ws.grid.config.n_points
    xs = ws.grid.x[1]
    ys = ws.grid.x[2]
    z_mid = (nz + 1) ÷ 2
    n_slice = abs2.(view(psi,:,:,z_mid,c_idx))
    box = ws.grid.config.box_size[1]
    rho_max = 0.5 * box
    # n_bins finer than nx so radial sampling overlaps multiple cells per ring
    n_bins = 2 * nx
    bin_w = rho_max / n_bins
    radial_n = zeros(Float64, n_bins)
    radial_w = zeros(Float64, n_bins)
    for j in 1:ny, i in 1:nx
        ρ = sqrt(xs[i]^2 + ys[j]^2)
        ρ < rho_max || continue
        b = Int(div(ρ, bin_w)) + 1
        b > n_bins && continue
        radial_n[b] += n_slice[i, j]
        radial_w[b] += 1.0
    end
    for b in 1:n_bins
        radial_w[b] > 0 && (radial_n[b] /= radial_w[b])
    end
    # Smooth with a moving average (window 3 bins) to suppress single-bin noise
    smoothed = similar(radial_n)
    for b in 1:n_bins
        b0 = max(1, b - 1)
        b1 = min(n_bins, b + 1)
        smoothed[b] = sum(radial_n[b0:b1]) / (b1 - b0 + 1)
    end
    ρ_centers = [(b - 0.5) * bin_w for b in 1:n_bins]
    (ρ=ρ_centers, n_raw=radial_n, n=smoothed)
end

"""Count rings = local maxima exceeding 15% of global max AND with a dip of
≥ 10% on either side (prominence) AND separated by at least 2 bins.
Lattice-tolerant."""
function count_rings_robust(n::Vector{Float64})
    n_max = maximum(n)
    n_max < 1e-12 && return 0
    threshold = 0.15 * n_max
    prominence_drop = 0.10 * n_max
    peaks = Int[]
    for i in 2:(length(n) - 1)
        n[i] < threshold && continue
        n[i] > n[i - 1] && n[i] > n[i + 1] || continue
        # Walk left/right to find prominence
        local_min_left = n[i]
        for j in (i - 1):-1:1
            local_min_left = min(local_min_left, n[j])
            n[j] > n[i] && break
        end
        local_min_right = n[i]
        for j in (i + 1):length(n)
            local_min_right = min(local_min_right, n[j])
            n[j] > n[i] && break
        end
        prom = n[i] - max(local_min_left, local_min_right)
        prom > prominence_drop || continue
        # Reject if too close to prior peak
        isempty(peaks) || (i - peaks[end] >= 2) || continue
        push!(peaks, i)
    end
    length(peaks)
end

function main()
    open(OUT_FILE, "w") do io
        println(io, "=== D1 closure: Matsui ring contrast (FM vs AFM) × 2 grid sizes ===")
        println(io, "T = $T_EVOLVE ω_ref⁻¹ (≈ 40 ms), Bz quench p=$(ZEEMAN.p), N=$N_ATOMS")
        println(io, "K_3 m-dependent profile (stretched immune, cascade enhanced)")
        println(io)

        results = Dict{Tuple{String, NTuple{3, Int}}, Int}()
        for (label, c1r) in SCENARIOS, gsize in GRIDS
            t0 = time()
            ws = run_dynamics(c1r, gsize)
            dV = SpinorBEC.cell_volume(ws.grid)
            psi = ws.state.psi
            total_norm = sum(abs2, psi) * dV
            n_per_m = Float64[sum(abs2, view(psi,:,:,:,c)) * dV
                              for c in 1:(2F + 1)]
            n_asc = reverse(n_per_m)
            prof = radial_profile_smooth(ws, -4)
            n_rings = count_rings_robust(prof.n)
            results[(label, gsize)] = n_rings
            elapsed = time() - t0
            @printf io "\n--- %s grid=%s (%.0f s) ---\n" label string(gsize) elapsed
            @printf io "total norm: %.4f (loss %.1f%%)\n" total_norm 100 * (1 - total_norm)
            @printf io "f[m=-6]=%.4f, f[m=-5]=%.4f, f[m=-4]=%.4f, f[m=-3]=%.4f\n" n_asc[1] n_asc[2] n_asc[3] n_asc[4]
            @printf io "m=-4 smoothed radial profile (z=0 slice):\n"
            for i in 1:length(prof.ρ)
                bar = "█"^max(0, round(Int, prof.n[i] / max(maximum(prof.n), 1e-30) * 30))
                @printf io "  ρ=%.2f  raw=%.2e  smooth=%.2e  %s\n" prof.ρ[i] prof.n_raw[i] prof.n[i] bar
            end
            @printf io "→ robust ring count = %d\n" n_rings
            flush(io)
        end

        println(io)
        println(io, "=== Verdict ===")
        @printf io "          %-8s %-8s\n" "16³" "24³"
        for label in ("FM", "AFM")
            @printf io "  %-4s    %-8d %-8d\n" label results[(label, GRIDS[1])] results[(
                label, GRIDS[2]
            )]
        end

        fm16 = results[("FM", GRIDS[1])]
        afm16 = results[("AFM", GRIDS[1])]
        fm24 = results[("FM", GRIDS[2])]
        afm24 = results[("AFM", GRIDS[2])]
        println(io)
        if fm16 == fm24 && afm16 == afm24 && afm16 == fm16 + 1
            println(io, "→ Counts converge across grids AND AFM = FM + 1.")
            println(io, "  Spectroscopy ↔ ring-count consistent on the AFM c_1 sign.")
            println(io, "  D1 closure achieved. No further D1 iteration per execution discipline.")
        elseif fm16 != fm24 || afm16 != afm24
            println(io, "→ Lattice non-convergence: ring count differs between grids.")
            println(io, "  D1 inconclusive; do not over-iterate. Logged for record.")
        else
            @printf io "→ Counts converge but AFM (%d) ≠ FM (%d) + 1.\n" afm16 fm16
            println(io, "  Either the discriminator is more subtle than 2 vs 3, or one of")
            println(io, "  the conditions (T, K_3 profile, c_2/c_4/c_6 magnitudes) differs")
            println(io, "  from Matsui's. Documented; no further iteration.")
        end
    end
    println("D1 closure complete. Output: $OUT_FILE")
end

main()
