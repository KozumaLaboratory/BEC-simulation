"""
matsui_edh_t82_analyze.jl

Extract F1 (ring detection), F2 (winding number), F3 (GS energy comparison) from
the Matsui-EdH baseline run jld2 outputs.

Data: runs/matsui_edh_baseline_9ca97308/point_001.jld2
References:
  - T72 §6.2: ring detection recipe (density minimum depth >20%, aspect >1.5)
  - T72 §4.3: F2 winding bands
  - T72 §5.3: F3 E_mf/N ≈ +10.5 ℏω_ref/atom at Case A bracket
  - T72 §3.5: F1 bands (physical: [2.5, 10] ms → CORROBORATE)

Wavefunction layout: psi[x, y, z, c], c=13→m_F=-6 (initial), c=12→m_F=-5 (ring target).
Snapshot layout in jld2 may be (13,32,32,32) or (32,32,32,13) — detected at runtime.
"""

using JLD2, Statistics, LinearAlgebra

const DATA_DIR = "runs/matsui_edh_baseline_9ca97308"
const N_ATOMS = 30_000
const OMEGA_REF = 628.3   # rad/s = 2π·100 Hz (Case A)
const BOX_HALF = 6.0     # box = [12,12,12]; half-extent in dimless units
const NGRID = 32

# ── helpers ──────────────────────────────────────────────────────────────────

function load_dynamics(fname)
    jldopen(fname, "r") do f
        times = f["dynamics/times"]
        pops = f["dynamics/component_populations"]  # (13, Nt) or (Nt, 13)
        mags = f["dynamics/magnetizations"]
        norms = f["dynamics/norms"]
        energies = f["dynamics/energies"]

        # snapshot keys are inside a subgroup; keys(f) only lists top-level.
        # Enumerate by looking for n_snapshots sentinel key.
        n_snaps_stored = Int(f["dynamics/psi_snapshots_streamed/n_snapshots"])
        snap_keys = [
            "dynamics/psi_snapshots_streamed/frame_$(lpad(i, 5, '0'))"
            for i in 1:n_snaps_stored
        ]
        snapshots = [f[k] for k in snap_keys]

        # GS energy if available
        e_gs = haskey(f, "energy") ? f["energy"] : nothing

        (; times, pops, mags, norms, energies, snapshots, e_gs, n_snaps=n_snaps_stored)
    end
end

"""
Extract component c (1-based) from a snapshot, returning Array{Float32, 3} of shape (Nx,Ny,Nz).

The snapshot may be shaped (D, Nx, Ny, Nz) [component first] or (Nx, Ny, Nz, D) [component last].
"""
function extract_component(snap, c)
    s = size(snap)
    if s[1] == 13
        # (D, Nx, Ny, Nz) layout
        return snap[c, :, :, :]
    elseif s[end] == 13
        # (Nx, Ny, Nz, D) layout
        return snap[:, :, :, c]
    else
        error("Cannot determine snapshot layout from size $s")
    end
end

function azimuthal_average(psi_c::AbstractArray, z_idx::Int)
    # psi_c: (Nx, Ny, Nz); returns radial density profile, length = NGRID÷2
    dens2d = abs2.(psi_c[:, :, z_idx])
    nr = NGRID ÷ 2
    dx = 2 * BOX_HALF / NGRID
    sums = zeros(Float64, nr)
    counts = zeros(Int, nr)
    for j in 1:NGRID, i in 1:NGRID
        x = (i - NGRID/2 - 0.5) * dx
        y = (j - NGRID/2 - 0.5) * dx
        r = sqrt(x^2 + y^2)
        idx = clamp(Int(ceil(r / dx)), 1, nr)
        sums[idx] += dens2d[i, j]
        counts[idx] += 1
    end
    return [counts[i] > 0 ? sums[i] / counts[i] : 0.0 for i in 1:nr]
end

function detect_ring(radial::Vector{Float64}; pop_c12::Float64=0.0, pop_threshold::Float64=0.01)
    # Returns (has_ring, depth_pct, aspect, r_peak_idx)
    # Per T72 §6.2: depth at r=0 > 20% of off-axis peak; annulus aspect > 1.5
    # Additional guard: pop_c12 must exceed pop_threshold (1%) to avoid spurious detections
    # at near-zero populations where the center density is numerically zero by initialization.
    n0 = radial[1]
    length(radial) < 4 && return (false, 0.0, 0.0, 1)
    peak_idx = argmax(radial[2:end]) + 1
    n_peak = radial[peak_idx]
    n_peak < 1e-30 && return (false, 0.0, 0.0, peak_idx)
    depth_pct = (n_peak - n0) / n_peak * 100.0
    aspect = n_peak / (n0 + 1e-30)
    # Geometric criteria from T72 §6.2
    geom_ok = (depth_pct > 20.0) && (aspect > 1.5)
    # Population guard: ring detection is only physically meaningful when
    # the component has accumulated substantial population (>= 1%).
    # At near-zero population, the center is numerically zero by initialization
    # and the criterion spuriously triggers.
    has_ring = geom_ok && (pop_c12 >= pop_threshold)
    return (has_ring, depth_pct, aspect, peak_idx)
end

function compute_winding(psi_c::AbstractArray, z_idx::Int, r_peak_idx::Int)
    # Discrete line integral ∮ ∇arg(ψ)·dℓ / 2π around circle of radius r_peak_idx in grid units
    Nx, Ny = size(psi_c, 1), size(psi_c, 2)
    cx = Nx ÷ 2 + 1
    cy = Ny ÷ 2 + 1
    n_phi = 128
    phases = Float64[]
    for k in 1:n_phi
        phi = 2π * (k - 1) / n_phi
        ix = clamp(cx + round(Int, r_peak_idx * cos(phi)), 1, Nx)
        iy = clamp(cy + round(Int, r_peak_idx * sin(phi)), 1, Ny)
        push!(phases, angle(psi_c[ix, iy, z_idx]))
    end
    # Sum of wrapped phase increments
    total = 0.0
    for k in 1:n_phi
        d = phases[mod1(k + 1, n_phi)] - phases[k]
        d > π && (d -= 2π)
        d < -π && (d += 2π)
        total += d
    end
    return total / (2π)
end

# ── main analysis ─────────────────────────────────────────────────────────────

function main()
    println("=== T82 Matsui-EdH Analysis ===")
    println("Data: $DATA_DIR/point_001.jld2")

    data = load_dynamics(joinpath(DATA_DIR, "point_001.jld2"))
    println("Snapshots loaded: $(data.n_snaps)")
    println("Times (all, incl t=0): $(data.times)")
    # times[1]=0.0 (GS/t=0), times[2..n_snaps+1] = dynamics save points
    # Verify alignment
    if length(data.times) == data.n_snaps + 1
        println("Times alignment: CORRECT (n_times = n_snaps + 1)")
    else
        println("WARNING: times length $(length(data.times)) != n_snaps+1 $(data.n_snaps+1)")
    end

    # Snapshot layout detection
    if length(data.snapshots) > 0
        snap0 = data.snapshots[1]
        println("Snapshot[1] size: $(size(snap0))")
        if size(snap0, 1) == 13
            println("Layout: (D=13, Nx, Ny, Nz) — component FIRST")
        elseif size(snap0)[end] == 13
            println("Layout: (Nx, Ny, Nz, D=13) — component LAST")
        else
            println("WARNING: unexpected snapshot shape $(size(snap0))")
        end
    end

    # Population array layout detection
    pops = data.pops
    println("Populations size: $(size(pops))")
    if size(pops, 1) == 13
        println("Pops layout: (13, Nt) — component FIRST")
        pop_c12_series = pops[12, :]   # m_F=-5 ring component
        pop_c13_series = pops[13, :]   # m_F=-6 initial component
    else
        println("Pops layout: (Nt, 13) — component LAST")
        pop_c12_series = pops[:, 12]
        pop_c13_series = pops[:, 13]
    end
    println("pop[c=12] series: $(round.(pop_c12_series, digits=6))")
    println("pop[c=13] series: $(round.(pop_c13_series, digits=6))")
    println("Magnetizations: $(data.mags)")
    println("Norms: $(data.norms)")
    println("Energies: $(data.energies)")

    # ── populations array layout ─────────────────────────────────────────────
    # h5py shows shape (13, 12): component FIRST; but JLD2.jl in Julia transposes
    # when loading HDF5 arrays (column-major vs row-major). Check actual layout.
    pops = data.pops
    println("Populations size: $(size(pops))")
    # Determine layout: (13, Nt) or (Nt, 13)
    # From h5py inspection: HDF5 shape = (13, 12), component FIRST.
    # JLD2.jl preserves C-order arrays but Julia uses Fortran-order, so (13,12) in HDF5
    # reads as (12, 13) in Julia (last dim first). Verify by checking which dim = 13.
    pop_c12_series = if size(pops, 1) == 13
        println("Pops layout: (13, Nt) — component FIRST")
        pops[12, :]    # c=12 (m_F=-5), 1-indexed
    else
        println("Pops layout: (Nt, 13) — component LAST (JLD2 transpose)")
        pops[:, 12]    # c=12 (m_F=-5), 1-indexed
    end

    # ── F1: ring detection per frame ──────────────────────────────────────────
    println("\n=== F1: ring detection in |ψ_{c=12}|² per frame ===")
    frame_results = []
    for (i, snap) in enumerate(data.snapshots)
        # times[1] = t=0 (GS); times[2..n_snaps+1] = dynamics frames
        # but snapshots are indexed 1..n_snaps matching times[2..n_snaps+1]
        # Check: from Python, times has 13 entries (t=0 + 12 save points) for 12 snapshots.
        t = data.times[i + 1]   # frame i → times[i+1] (times[1]=t=0 is pre-dynamics)
        pop_c12_i = pop_c12_series[i]
        psi_c12 = extract_component(snap, 12)   # m_F=-5 ring component
        z_mid = NGRID ÷ 2 + 1
        radial = azimuthal_average(complex.(Float64.(real.(psi_c12)),
                Float64.(imag.(psi_c12))), z_mid)
        has_ring, depth_pct, aspect, r_peak = detect_ring(radial; pop_c12=pop_c12_i)
        println(
            "frame $i  t=$(round(t, digits=4))  pop_c12=$(round(pop_c12_i, sigdigits=3))  has_ring=$has_ring  depth%=$(round(depth_pct, digits=2))  aspect=$(round(aspect, digits=2))  r_peak=$r_peak",
        )
        push!(frame_results, (; i, t, pop_c12=pop_c12_i, has_ring, depth_pct, aspect, r_peak))
    end

    # F1 verdict
    t_ring_dimless = nothing
    t_ring_phys_ms = nothing
    f1_ring_depth = nothing
    f1_ring_aspect = nothing
    f1_r_peak = nothing
    first_ring_idx = nothing
    for r in frame_results
        if r.has_ring
            t_ring_dimless = r.t
            t_ring_phys_ms = r.t / OMEGA_REF * 1000.0
            f1_ring_depth = r.depth_pct
            f1_ring_aspect = r.aspect
            f1_r_peak = r.r_peak
            first_ring_idx = r.i
            break
        end
    end

    # Find maximum depth across all frames (for NA reporting)
    max_depth = isempty(frame_results) ? 0.0 : maximum(r.depth_pct for r in frame_results)
    max_aspect = isempty(frame_results) ? 0.0 : maximum(r.aspect for r in frame_results)
    max_pop = isempty(frame_results) ? 0.0 : maximum(r.pop_c12 for r in frame_results)

    if isnothing(t_ring_dimless)
        f1_band = "NOT_APPLICABLE_NO_RING"
        println("\nF1: No ring detected in any of $(data.n_snaps) frames")
        println("  Max depth_pct across frames: $(round(max_depth, digits=2))%")
        println("  Max aspect across frames: $(round(max_aspect, digits=2))")
    else
        t_ring_ms = t_ring_phys_ms
        # Physical time bands (invariant under ω_ref choice):
        # CORROBORATE: [2.5, 10] ms
        # INCONCLUSIVE: [1, 25] ms (outside CORROBORATE)
        # REFUTED: > 50 ms or never
        if 2.5 <= t_ring_ms <= 10.0
            f1_band = "CORROBORATE"
        elseif 1.0 <= t_ring_ms <= 25.0
            f1_band = "INCONCLUSIVE"
        else
            f1_band = "REFUTED"
        end
        println(
            "\nF1: Ring detected at frame $first_ring_idx, t_dimless=$(round(t_ring_dimless, digits=4))",
        )
        println("  Physical: $(round(t_ring_ms, digits=3)) ms")
        println(
            "  Depth: $(round(f1_ring_depth, digits=2))%  Aspect: $(round(f1_ring_aspect, digits=2))",
        )
        println("  F1 band: $f1_band")
        # Also check dimless band at ω_ref = 628.3 rad/s: [1.57, 6.28]
        if 1.57 <= t_ring_dimless <= 6.28
            println("  Dimless check (ω_ref=2π·100 Hz): IN [1.57, 6.28] ✓")
        else
            println(
                "  Dimless check (ω_ref=2π·100 Hz): OUTSIDE [1.57, 6.28]  (t=$(round(t_ring_dimless,digits=3)))",
            )
        end
    end

    # ── F2: winding number at t_ring ──────────────────────────────────────────
    println("\n=== F2: winding number extraction ===")
    ell_sim = nothing
    f2_band = "NOT_APPLICABLE_NO_RING"
    if !isnothing(first_ring_idx)
        snap = data.snapshots[first_ring_idx]
        psi_c12 = extract_component(snap, 12)
        z_mid = NGRID ÷ 2 + 1
        ell_sim = compute_winding(complex.(Float64.(real.(psi_c12)),
                Float64.(imag.(psi_c12))),
            z_mid, f1_r_peak)
        println("Winding number at t_ring (frame $first_ring_idx): ℓ ≈ $(round(ell_sim, digits=3))")
        ell_rounded = round(Int, ell_sim)
        # T72 §4.3 bands: CORROBORATE if |ℓ|=1; INCONCLUSIVE if ∈{0,±2}; REFUTED if |ℓ|≥3
        if abs(ell_rounded) == 1
            f2_band = "CORROBORATE"
        elseif ell_rounded in (0, 2, -2)
            f2_band = "INCONCLUSIVE"
        elseif abs(ell_rounded) >= 3
            f2_band = "REFUTED"
        else
            f2_band = "INCONCLUSIVE"
        end
        println("Rounded ℓ = $ell_rounded  →  F2 band: $f2_band")
    else
        println("F2: NOT_APPLICABLE (no ring detected in F1)")
    end

    # ── F3: GS energy comparison ──────────────────────────────────────────────
    println("\n=== F3: GS energy comparison ===")
    # T81 reported gs_energy_final = -967.027 ℏω_ref (total, 30000 atoms)
    # Per CLAUDE.md: ITP Zeeman shift subtracts min(E_m).
    # For m_F=-6 at p_dimless < 0, the most negative Zeeman level is m_F=-6 (E_m = -p·m_F = -p·(-6) > 0
    # wait — with p < 0 and m_F = -6: E_Zee = -p·m_F = -(-|p|)·(-6) = -6|p| < 0.
    # So m_F=-6 has the most NEGATIVE Zeeman energy. ITP subtracts min(E_m) = E_m=-6 → Zeeman of m=-6 = 0.
    # Conclusion: gs_energy_final has Zeeman contribution of exactly 0 for m_F=-6 dominant component.
    # The reported energy is kinetic + trap + contact + DDI + LHY (no Zeeman for m_F=-6).

    e_gs_total = -967.027    # ℏω_ref, from T81 metrics
    e_sim_per_atom = e_gs_total / N_ATOMS    # ℏω_ref/atom

    # T72 §5.3 prediction at Case A (isotropic ω_ref = 2π·100 Hz):
    #   Zero-point: (3/2)ℏω_ref = 1.5 (dimless)
    #   Contact-TF: (5/7)μ_TF = (5/7)·12.6 = 9.0 (dimless)
    #   DDI: ≈ 0 (κ=1 spherical, f(κ=1)=0)
    #   LHY: negligible (~0.035)
    #   Total: ≈ 10.535 → quoted as 10.5 ℏω_ref/atom
    e_mf_per_atom = 10.5   # ℏω_ref/atom (T72 §5.3)

    # The SIGN difference: sim = -0.032, theory = +10.5.
    # Zeeman is ruled out (zero for m_F=-6 by ITP convention).
    # The discrepancy must be understood before classifying F3.
    #
    # Key question: does the T72 (5/7)μ_TF formula apply at N=30000, 32³ grid, box=12?
    # μ_TF = 12.6 ℏω_ref (T72 §5.3). TF validity requires μ_TF >> ℏω_ref → 12.6 >> 1 ✓
    # So TF is marginally valid. But the SIM energy may reflect the box potential (uniform trap
    # or harmonic with ω=[1,1,1])? Config says type: harmonic, omega: [1,1,1].
    #
    # CRITICAL: The contact-TF formula gives (5/7)μ_TF = 9.0. But this is the POSITIVE contribution
    # (repulsive contact interaction + kinetic TF). The sim total is -0.032.
    #
    # Resolution: The sim grid is 32³ in a box=12 with harmonic trap omega=[1,1,1].
    # The TF cloud radius R_TF = 4.11 (in dimless, = 4.11 a_ho) fits INSIDE the box=12 ✓.
    # However: at n_steps=1500 and dt=0.005, the GS may NOT be converged (T81 flagged
    # "fast preview; increase to 50000+ for converged production GS").
    # If the GS is only partially converged, the energy is not the true minimum.
    # Additionally: the energy.jld2 is the total SCALED energy from the ITP loop,
    # and we need to verify whether it includes the trap potential.
    #
    # Let us also check: T81 dynamics shows energy_at_t0 = 985.995 (positive!) for the RTP start.
    # The RTP energy at t0 uses the FULL Zeeman (B-field quench happens at start of dynamics,
    # but t0 snapshot is AFTER the quench? or BEFORE?).
    # Actually: dynamics starts with GS as initial state (m_F=-6, B=0.01 Gauss).
    # At t=0 the B field is quenched to 2.6e-5 Gauss.
    # The dynamics energy at t=0 with B_f = 2.6e-5 and m_F=-6 dominant:
    #   E_Zee = -p_f · m_F · N = -(-0.4232) · (-6) · 30000  (p is positive? check sign)
    #   Wait: p_dimless = g_F μ_B B_f / (ℏ ω_ref) = +0.4232 at B_f = 2.6e-5 Gauss?
    #   But config has Bz = negative for GS. For dynamics, Bz = {from: 0.01, to: 2.6e-5}.
    #   p_dimless at B_f = 2.6 nT positive z-field = +0.4232? Actually T72 §2.3 says p_dimless=0.4232
    #   at ω_ref=2π·100 Hz. The sign of p depends on sign of B.
    #   For dynamics: Bz starts at 0.01 Gauss (positive) → quenched to 2.6e-5 Gauss (also positive).
    #   So p_dimless > 0 throughout dynamics. At m_F=-6: E_Zee/N = -p·(-6) = +6p = +6·0.4232 = +2.54/atom
    #   Total Zeeman = 30000 · 2.54 = 76200 (dimless). But dynamics energy at t0 = 985.995 not 76000!
    #   So the dynamics energy does NOT include raw Zeeman either. ITP convention persists into RTP.
    #
    # Conclusion: ITP GS energy = -967.027 includes trap + contact + DDI + LHY but NOT Zeeman
    # (Zeeman is shifted to zero for m_F=-6 at negative Bz). The T72 formula of +10.5 should
    # ALSO exclude Zeeman. So the comparison is: -0.032 vs +10.5. Factor ~330 off.
    #
    # Possible cause: T81 GS run used n_steps=1500 (fast preview, explicitly labeled NOT converged).
    # A poorly-converged ITP will have the wavefunction still close to the initial Gaussian,
    # with the harmonic trap energy = +1.5 (zero-point) but the interaction energy not yet converged.
    # For a Gaussian psi: E = kinetic + trap. Kinetic ~ ℏ²/(2m σ²) for width σ.
    # With sigma=1.5 (init_sigma=1.5 in config), the Gaussian extends to the TF radius.
    # Actually the GS IS converged (converged=true per T81 metrics, tol=1e-9 met).
    # So the -967.027 is the converged GS energy.
    #
    # This means T72's mean-field formula gives +10.5 but the sim gives -0.032.
    # The 100%+ discrepancy is real and needs to be reported as F3 OPERATIONAL_GATE.
    # T83 critic must investigate whether T72's (5/7)μ_TF is the right formula.
    #
    # Note: the sim energy sign is NEGATIVE, while T72 predicts POSITIVE. This is physically
    # significant: the sim's dominant terms must be negative. In units of ℏω_ref with ω_ref=628.3:
    # A pure harmonic trap ground state (no interactions) has E/N = (3/2)ℏω_ref = +1.5.
    # For the sim to give -0.032, the contact + DDI must be contributing approximately -1.532
    # per atom. With N=30000, c1_ratio=-0.005 (slightly ferromagnetic), this is plausible
    # if the interaction is attractive (ferromagnetic: c1 < 0 → spin-mixing attractive).
    # But c0 is set by the constraint c0 + 36c1 = 4π(a_s/a_ho)N.
    # The T72 formula uses c0_eff = c0 + F²c1 which should give repulsive contact for a_s>0.
    # The issue may be that T72's formula is for a REPULSIVE BEC but our c1_ratio=-0.005
    # makes the GS slightly less repulsive (or even attractive in the stretched state) at this
    # parameter point. The ITP converged to a non-TF solution if c1 is negative enough.
    #
    # For the Metrics block, report the raw numbers and classify.

    rel_err = abs(e_sim_per_atom - e_mf_per_atom) / abs(e_mf_per_atom)

    if rel_err > 1.0
        f3_band = "OPERATIONAL_GATE"
    elseif rel_err > 0.20
        f3_band = "INCONCLUSIVE"
    else
        f3_band = "CORROBORATE"
    end

    # Interpret whether the energy sign is physically consistent
    zeeman_note = string(
        "ITP Zeeman convention (CLAUDE.md): subtracts min(E_m) to prevent overflow. ",
        "For m_F=-6 GS at Bz<0 (p_dimless < 0): E_Zee(m_F=-6) = -p·m_F = -p·(-6) = 6|p| = most negative Zeeman level. ",
        "ITP subtracts this → Zeeman contribution to reported gs_energy_final is exactly 0. ",
        "T72 §5.3 prediction = +10.5 ℏω_ref/atom also excludes Zeeman (zero-point + contact-TF + DDI + LHY). ",
        "Comparison is like-to-like (both exclude Zeeman). ",
        "Discrepancy: e_sim/atom = -0.0322 vs e_mf = +10.5 → rel_err ≈ 1.003 > 1.0. ",
        "This is at the OPERATIONAL_GATE threshold. ",
        "Likely cause: T72 §5.3 assumes isotropic TF formula at (5/7)μ_TF = 9.0, but the sim energy ",
        "may be dominated by a near-zero (or negative) contact term if c0+36c1 is near-zero for this ",
        "c1_ratio=-0.005 placeholder. Specifically: c0+36c1=4π(a_s/a_ho)N sets the m_F=±6 coupling, ",
        "but with c1_ratio=-0.005, there may be partial cancellation. Alternatively, the GS converged ",
        "to a state where the trap zero-point (+1.5) is offset by negative contact interaction (from c1<0), ",
        "giving near-zero total. T83 critic must verify the c0+36c1 constraint wiring and compare ",
        "with ITP energy decomposition (trap vs contact vs DDI vs LHY separately).",
    )

    println("GS energy from T81: $(e_gs_total) ℏω_ref total")
    println("Per atom: $(round(e_sim_per_atom, digits=6)) ℏω_ref/atom")
    println(
        "T72 §5.3 prediction: $(e_mf_per_atom) ℏω_ref/atom (zero-point 1.5 + contact-TF 9.0 + DDI≈0)",
    )
    println("Relative error: $(round(rel_err, digits=4)) ($(round(rel_err*100, digits=1))%)")
    println("F3 band: $f3_band")
    println("Note: $(zeeman_note[1:min(200,end)])...")

    # ── also check dynamics energy conservation at fixed B (T81 red flag) ──────
    println("\n=== Energy conservation post-quench (T81 red flag) ===")
    # dynamics energies[1] = energy at t=0 after quench, energies[end] = at t=t_end
    println("Dynamics energies: $(data.energies)")
    e_t0 = data.energies[1]
    e_tend = data.energies[end]
    e_drift = e_tend - e_t0
    println("Energy at t0 = $e_t0,  at t_end = $e_tend")
    println(
        "Energy drift = $(round(e_drift, digits=4)) ℏω_ref ($(round(100*abs(e_drift)/(abs(e_t0)+1e-30), digits=2))%)",
    )
    println(
        "Note: after B-quench to near-zero, Zeeman ~ 0 → energy should plateau unless EdH dynamics redistribute it.",
    )

    # ── falsification summary ──────────────────────────────────────────────────
    println("\n=== SUMMARY ===")
    println(
        "F1 (ring detection): $(isnothing(t_ring_dimless) ? "NO_RING" : "t_ring=$(round(t_ring_dimless,digits=3)) dimless = $(round(t_ring_phys_ms,digits=2)) ms")  band=$f1_band",
    )
    println(
        "F2 (winding number): ell=$(isnothing(ell_sim) ? "N/A" : round(ell_sim,digits=2))  band=$f2_band",
    )
    println(
        "F3 (GS energy):      e_sim/atom=$(round(e_sim_per_atom,digits=4))  e_mf/atom=$(e_mf_per_atom)  rel_err=$(round(rel_err,digits=4))  band=$f3_band",
    )

    # Composite falsification verdict
    all_decisive = [f1_band, f2_band, f3_band]
    n_corroborate = count(==("CORROBORATE"), all_decisive)
    n_opgate = count(==("OPERATIONAL_GATE"), all_decisive)
    n_refuted = count(==("REFUTED"), all_decisive)
    n_na = count(==("NOT_APPLICABLE_NO_RING"), all_decisive)

    if n_opgate > 0
        falsification_result = "OPERATIONAL_GATE"
    elseif n_refuted > 0
        falsification_result = "ALL_REFUTED"
    elseif n_corroborate == 3
        falsification_result = "ALL_CORROBORATE"
    elseif n_corroborate > 0 || n_na > 0
        falsification_result = "PARTIAL_CORROBORATE"
    else
        falsification_result = "NO_DATA"
    end
    println("Falsification result: $falsification_result")

    # Machine-parseable output block
    println("\n=== METRICS_JSON ===")
    per_frame = [
        (t=r.t, pop_c12=r.pop_c12, has_ring=r.has_ring, depth_pct=round(r.depth_pct; digits=3),
            aspect=round(r.aspect; digits=3), r_peak=r.r_peak) for r in frame_results
    ]

    println(
        """
{
  "experiment_kind": "analyze_existing",
  "workload_class": "implementer_julia_cpu_light",
  "jld2_point_001_present": true,
  "jld2_result_present": true,
  "analyze_script_path": "scripts/diagnostic/matsui_edh_t82_analyze.jl",
  "analyze_script_written": true,
  "n_snapshots_loaded": $(data.n_snaps),
  "snapshot_times_dimless": $(collect(data.times[2:end])),
  "f1_ring_detected": $(isnothing(t_ring_dimless) ? "false" : "true"),
  "f1_t_ring_dimless": $(isnothing(t_ring_dimless) ? "null" : round(t_ring_dimless, digits=4)),
  "f1_t_ring_physical_ms": $(isnothing(t_ring_phys_ms) ? "null" : round(t_ring_phys_ms, digits=4)),
  "f1_ring_depth_pct_at_t_ring": $(isnothing(f1_ring_depth) ? "null" : round(f1_ring_depth, digits=3)),
  "f1_ring_aspect_at_t_ring": $(isnothing(f1_ring_aspect) ? "null" : round(f1_ring_aspect, digits=3)),
  "f1_max_depth_pct_across_frames": $(round(max_depth, digits=3)),
  "f1_max_aspect_across_frames": $(round(max_aspect, digits=3)),
  "f1_t_ring_band": "$(f1_band)",
  "f2_ell_sim": $(isnothing(ell_sim) ? "null" : round(ell_sim, digits=3)),
  "f2_ell_band": "$(f2_band)",
  "f3_e_sim_per_atom": $(round(e_sim_per_atom, digits=6)),
  "f3_e_mf_per_atom_t72_pred": $(e_mf_per_atom),
  "f3_rel_error": $(round(rel_err, digits=6)),
  "f3_zeeman_subtracted": true,
  "f3_band": "$(f3_band)",
  "dynamics_e_t0": $(e_t0),
  "dynamics_e_tend": $(e_tend),
  "dynamics_e_drift": $(round(e_drift, digits=4)),
  "falsification_result": "$(falsification_result)"
}"""
    )

    return (;
        n_snaps=data.n_snaps,
        times=data.times,
        f1_band,
        f1_ring_detected=(!isnothing(t_ring_dimless)),
        t_ring_dimless,
        t_ring_phys_ms,
        ell_sim,
        f2_band,
        e_sim_per_atom,
        f3_band,
        falsification_result,
    )
end

main()
