# Static analysis of the weak-field Eu (F=6) GS library: WHERE to ramp and how
# fast the *field-following* bound allows — the cheap prerequisite of the
# adiabatic-passage protocol (scripts/eu_adiabatic_ramp_protocol.jl).
#
# Physics being staged. The transition ORDER is set by the trap oblateness κ
# (tricritical κ_tc ≈ 0.95): κ ≲ 0.9 is a crossover (single branch), κ ≳ 1.0 is
# first-order (two converged branches with an energy crossing). A ramp protocol
# therefore has to be designed at a *stated* κ — an experiment that ramps a
# spherical trap through 40 µG measures a crossover and sees no hysteresis by
# construction. This script reads the converged library and reports, per κ:
#
#   B_eq       energy crossing  E_up(B) = E_dn(B)             (the transition)
#   bracket    B-range where the two branches are DISTINCT     (δ⟨F⊥⟩ > tol)
#              — the mean-field spinodal separation, i.e. the hysteresis loop
#              width a *slow* ramp must converge to. A loop wider than this is
#              dynamical lag, not bistability.
#   Larmor     ω_L vs the field-tilt rate dθ/dt of the ramp: a NECESSARY
#              adiabaticity bound (spin follows the local quantisation axis).
#              It is not sufficient — the collective texture rearrangement
#              timescale is not available in closed form here and is what the
#              dynamics sweep measures.
#
# The pin b_x = ε that locks the Goldstone orientation is kept: it is also the
# residual transverse lab field, so the ramp is designed at the ε the experiment
# actually has, and ε enters the Larmor bound directly.
#
# Env:
#   AR_LIB=figs/eu_gs_library      merged library dir (library.csv + g*/k*/…)
#   AR_KAPPAS=1.8,0.8              κ values to analyse (first-order, crossover)
#   AR_GRID=32                     library grid
#   AR_GRAD_TOL=1e-4               keep only states converged to |∇E| < tol
#   AR_DFPERP_TOL=0.05             δ⟨F⊥⟩ above which branches count as distinct
#   AR_OUT=figs/eu_adiabatic_window
#
#   julia --project=. scripts/eu_adiabatic_window.jl

using SpinorBEC
using SpinorBEC: Units, eu151_preset, _spin_expectation_fields, cell_volume,
    larmor_frequency, field_tilt, adiabaticity_trajectory
using DelimitedFiles: writedlm
using JLD2: jldopen
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const LIB = get(ENV, "AR_LIB", "figs/eu_gs_library")
const KAPPAS = parse.(Float64, split(get(ENV, "AR_KAPPAS", "1.8,0.8"), ","))
const GRID = Int(getf("AR_GRID", 32))
const GTOL = getf("AR_GRAD_TOL", 1e-4)
const DFTOL = getf("AR_DFPERP_TOL", 0.05)
const BSELF_X_UG = getf("AR_B_SELF_X", 0.0)   # stated residual/self transverse field [µG]
const OUT = get(ENV, "AR_OUT", "figs/eu_adiabatic_window")
mkpath(OUT)

# ---------------------------------------------------------------- library read

"""Rows of `library.csv` for one (grid, κ, branch), converged to |∇E| < GTOL."""
function lib_rows(; κ, branch, grid=GRID, lib=LIB, gtol=GTOL)
    csv = joinpath(lib, "library.csv")
    isfile(csv) || error("no merged library at $csv")
    lines = readlines(csv)
    hdr = split(lines[1], '\t')
    col = Dict(strip(h) => i for (i, h) in enumerate(hdr))
    rows = NamedTuple[]
    for ln in lines[2:end]
        c = split(ln, '\t')
        length(c) < length(hdr) && continue
        parse(Int, c[col["grid"]]) == grid || continue
        abs(parse(Float64, c[col["κ"]]) - κ) < 1e-3 || continue
        strip(c[col["branch"]]) == branch || continue
        g = parse(Float64, c[col["grad_norm"]])
        g < gtol || continue
        push!(
            rows,
            (; B=parse(Float64, c[col["B"]]),
                E=parse(Float64, c[col["E"]]),
                grad=g,
                pin=parse(Float64, c[col["pin"]]),
                raw=String(strip(c[col["path"]]))),
        )
    end
    sort!(rows; by=r -> r.B)
    rows
end

# The `path` column is already repo-relative (figs/eu_gs_library/g32/…), so use
# it directly unless the caller relocated the library.
resolve(raw) = isfile(raw) ? raw :
               joinpath(LIB, join(splitpath(raw)[max(1, end - 2):end], "/"))

"""Density-weighted (⟨F_z⟩, ⟨F⊥⟩) per atom — same definition as the library
driver's `frame_scalars`, so numbers are comparable across scans."""
function spin_scalars(path, grid)
    psi = jldopen(resolve(path), "r") do f
        Array{ComplexF64}(f["psi"])
    end
    dV = cell_volume(grid)
    dens = dropdims(sum(abs2, psi; dims=4); dims=4)
    fx, fy, fz = _spin_expectation_fields(psi, grid)
    ntot = sum(dens) * dV
    (; fz=sum(fz) * dV / ntot,
        fperp=sum(sqrt.(fx .^ 2 .+ fy .^ 2)) * dV / ntot)
end

# ------------------------------------------------------------------- analysis

"""Linear-interpolated zero crossing of `y(x)`; `nothing` if no sign change."""
function zero_crossing(x, y)
    for i in 1:(length(x) - 1)
        (isfinite(y[i]) && isfinite(y[i + 1])) || continue
        if y[i] == 0
            return x[i]
        elseif y[i] * y[i + 1] < 0
            return x[i] + (x[i + 1] - x[i]) * y[i] / (y[i] - y[i + 1])
        end
    end
    nothing
end

"""Pin ε (dimensionless p-units) → transverse field magnitude [tesla]."""
pin_to_tesla(ε, atom, omega_ref) =
    abs(ε) * Units.HBAR * omega_ref / (atom.g_F * Units.BOHR_MAGNETON)

"""Field-following (Larmor) bound on the ramp duration, via the audited
`adiabaticity_trajectory`.

A B_z ramp at fixed transverse field B_⊥ tilts the local quantisation axis; the
spin follows it only while ω_L ≫ ω_rot = dθ/dt. Since ω_rot ∝ 1/T_ramp, the
worst-case ratio is linear in T_ramp, so one trajectory at T = 1 s gives the
required duration for any target margin:

    T_required = target / min(ratio)|_{T = 1 s}

`B_perp` [tesla] is the transverse tilt source: the Goldstone pin ε (which is
also the residual transverse lab field) or, if larger, the cloud's own DDI
self-field. NECESSARY, not sufficient — it bounds the SPIN, not the collective
texture rearrangement, which the dynamics sweep measures."""
function larmor_bound(B_lo_uG, B_hi_uG, B_perp_T, atom, omega_ref; target=10.0)
    traj = adiabaticity_trajectory((B_perp_T, 0.0, 0.0), atom;
        B_ini=B_hi_uG * 1e-10, B_fin=B_lo_uG * 1e-10, T_ramp=1.0, n=2000)
    r = minimum(@view traj.ratio[2:end])          # ratio[1] = Inf (ω_rot = 0)
    T_req = target / r                            # seconds
    (; tau_larmor=T_req * omega_ref, T_req_s=T_req, ratio_1s=r,
        tilt_max=maximum(traj.tilt),
        f_L_min_hz=minimum(traj.omega_larmor) / 2π)
end

const PRESET_REF = eu151_preset(; n_pts=(GRID, GRID, GRID), box=(24.0, 24.0, 24.0))
const ATOM = PRESET_REF.atom
const ΩREF = PRESET_REF.omega_ref

summary_rows = Any[]

for κ in KAPPAS
    up = lib_rows(; κ, branch="up")
    dn = lib_rows(; κ, branch="dn")
    if isempty(up) || isempty(dn)
        @warn "κ=$κ: no converged states on one branch (up=$(length(up)) dn=$(length(dn))) — skipped"
        continue
    end
    # states present on BOTH branches at the same B (within 0.5 µG)
    Bs = Float64[]
    for r in up, s in dn
        abs(r.B - s.B) < 0.5 && push!(Bs, r.B)
    end
    Bs = sort(unique(Bs))
    isempty(Bs) && (@warn "κ=$κ: branches share no field point"; continue)

    tab = Any[]
    for B in Bs
        ru = up[argmin(abs.(getfield.(up, :B) .- B))]
        rd = dn[argmin(abs.(getfield.(dn, :B) .- B))]
        su = spin_scalars(ru.raw, PRESET_REF.grid)
        sd = spin_scalars(rd.raw, PRESET_REF.grid)
        push!(
            tab,
            (; B, E_up=ru.E, E_dn=rd.E, dE=ru.E - rd.E,
                fperp_up=su.fperp, fperp_dn=sd.fperp,
                dfperp=abs(su.fperp - sd.fperp),
                fz_up=su.fz, fz_dn=sd.fz,
                grad_up=ru.grad, grad_dn=rd.grad,
                pin_up=ru.pin, pin_dn=rd.pin),
        )
    end

    B_eq = zero_crossing(getfield.(tab, :B), getfield.(tab, :dE))
    distinct = [t.B for t in tab if t.dfperp > DFTOL]
    bracket = isempty(distinct) ? nothing : (minimum(distinct), maximum(distinct))
    δmax = maximum(getfield.(tab, :dfperp))
    ε = tab[1].pin_dn

    # Is the bracket physical or data-limited? If the branches are still
    # DISTINCT at the edges of the shared range, the spinodals (where a
    # metastable branch ceases to exist) lie OUTSIDE the library — the bracket
    # is then a lower bound on the loop width, not the loop width. The ramp has
    # to run past the data, which dynamics can do and ITP cannot.
    edge_distinct = (tab[1].dfperp > DFTOL, tab[end].dfperp > DFTOL)
    data_limited = bracket !== nothing && any(edge_distinct)

    # Per-branch existence extent over ALL converged points (not just shared
    # fields): how far each anchor's branch survives = the ITP-visible
    # metastability range, the best static proxy for the spinodals.
    ext_up = (minimum(getfield.(up, :B)), maximum(getfield.(up, :B)))
    ext_dn = (minimum(getfield.(dn, :B)), maximum(getfield.(dn, :B)))

    # Ramp window: must ENCLOSE both branch extents when the bracket is
    # data-limited, so each ramp is carried past its own spinodal.
    win = if data_limited
        (max(0.0, min(ext_up[1], ext_dn[1]) - 5), max(ext_up[2], ext_dn[2]) + 5)
    elseif bracket !== nothing
        w = bracket[2] - bracket[1]
        (max(0.0, bracket[1] - 0.5w - 5), bracket[2] + 0.5w + 5)
    elseif B_eq !== nothing
        (max(0.0, B_eq - 15), B_eq + 15)
    else
        (minimum(Bs), maximum(Bs))
    end
    # transverse tilt source: the pin, or a larger stated residual lab field
    B_pin_T = pin_to_tesla(ε, ATOM, ΩREF)
    B_perp_T = max(B_pin_T, BSELF_X_UG * 1e-10)
    lb = larmor_bound(win[1], win[2], B_perp_T, ATOM, ΩREF)

    ks = collect(keys(tab[1]))
    open(joinpath(OUT, @sprintf("window_k%.2f.csv", κ)), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for t in tab
            writedlm(io, reshape(Any[getfield(t, k) for k in ks], 1, :))
        end
    end

    order = bracket === nothing ? "crossover" : "bistable"
    @printf("\nκ = %.2f  [%s]  pin ε = %.0e  %d shared field points\n",
        κ, order, ε, length(tab))
    @printf("  B_eq (E crossing)      : %s\n",
        B_eq === nothing ? "none in window" : @sprintf("%.2f µG", B_eq))
    @printf("  distinct-branch bracket: %s   max δ⟨F⊥⟩ = %.3f\n",
        if bracket === nothing
            "none (δ⟨F⊥⟩ < $DFTOL everywhere)"
        else
            @sprintf("%.1f – %.1f µG (width %.1f%s)", bracket[1], bracket[2],
            bracket[2] - bracket[1],
            data_limited ? ", LOWER BOUND — branches still distinct at the data edge" : "")
        end,
        δmax)
    @printf("  branch extent (up/dn)  : %.1f–%.1f / %.1f–%.1f µG\n",
        ext_up[1], ext_up[2], ext_dn[1], ext_dn[2])
    @printf("  ramp window            : %.1f → %.1f µG\n", win[1], win[2])
    @printf("  transverse field       : pin ε ⇒ %.3g µG%s\n",
        B_pin_T * 1e10,
        BSELF_X_UG > 0 ? @sprintf("  (stated residual %.3g µG used)", BSELF_X_UG) : "")
    @printf("  Larmor bound (×10)     : τ ≳ %.3g ω_ref⁻¹ (%.3g ms)  f_L,min = %.3g Hz\n",
        lb.tau_larmor, lb.T_req_s * 1e3, lb.f_L_min_hz)
    @printf("  max field tilt         : %.3g rad\n", lb.tilt_max)

    push!(
        summary_rows,
        (; κ, order,
            B_eq=B_eq === nothing ? NaN : B_eq,
            bracket_lo=bracket === nothing ? NaN : bracket[1],
            bracket_hi=bracket === nothing ? NaN : bracket[2],
            loop_width_mf=bracket === nothing ? 0.0 : bracket[2] - bracket[1],
            loop_width_is_lower_bound=data_limited,
            ext_up_lo=ext_up[1], ext_up_hi=ext_up[2],
            ext_dn_lo=ext_dn[1], ext_dn_hi=ext_dn[2],
            dfperp_max=δmax, pin=ε, B_perp_uG=B_perp_T * 1e10,
            B_ramp_lo=win[1], B_ramp_hi=win[2],
            tau_larmor=lb.tau_larmor, n_points=length(tab)),
    )
end

if !isempty(summary_rows)
    ks = collect(keys(summary_rows[1]))
    open(joinpath(OUT, "window_summary.csv"), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for r in summary_rows
            writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
        end
    end
    println("\nwrote $(OUT)/window_summary.csv + per-κ window CSVs")
    println("""
    Next: the mean-field loop width above is the τ→∞ limit a slow ramp must
    reproduce. Feed the window + τ grid to

      AR_KAPPA=<κ> AR_B_LO=<lo> AR_B_HI=<hi> \\
        julia --project=. scripts/eu_adiabatic_ramp_protocol.jl
    """)
end
