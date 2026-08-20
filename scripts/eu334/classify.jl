#!/usr/bin/env julia
# Which branch did an SPGPE trajectory land in? — the #334 classifier, with the
# calibration it refuses to run without.
#
# WHY NOT THE TOTAL ENERGY, WHICH IS WHAT #334 ASKS FOR
#
# #334's acceptance criterion is "branch determination by energy against the two
# reference values, not by eyeballing ⟨F⊥⟩", and it is right about the second half:
# the adiabatic endpoints sat at ⟨F⊥⟩ ≈ 3.2 with the branches at 5.14 and 0.07, so
# an order-parameter classifier calls an excited state "flower". But the first half
# cannot be done literally on a finite-temperature c-field. `scripts/eu334/window.jl`
# measures the C region's thermal energy at 10³–10⁴ times the 0.133/atom branch
# separation, so the total energy of ψ is a thermometer, not a branch label.
#
# What is done instead is the same claim made on a state where it means something:
# the field is QUENCHED (reservoir off) and RELAXED to the nearest local minimum at
# its own condensate fraction, and THAT state's energy is compared against the two
# branches. The relaxed state answers exactly the question the criterion is after —
# which basin is the field in — and it inherits the reference values rather than
# inventing a threshold.
#
# Three outcomes, not two. #335 measured prepared states sitting ABOVE both
# branches, so a binary classifier would have to call one of them a branch. A cell
# whose relaxed energy exceeds both references by more than the branch separation
# is reported as `excited`, and that is a result, not a failure.
#
# THE CALIBRATION IS NOT OPTIONAL
#
# `--calibrate` runs the classifier on states whose answer is known and refuses to
# classify anything until they come back right:
#
#   flower reference               → flower       (can it see a branch at all)
#   polarised reference            → polarised    (can it see the OTHER one)
#   flower + noise of the run's own amplitude → flower   (does the quench undo the
#                                                         thermal excitation)
#   polarised + the same noise     → polarised
#   an equal mix of the two        → whatever it says, recorded — this is the cell
#                                    where the classifier is allowed to be
#                                    ambiguous, and it must not be silently binary
#
# A classifier calibrated only on clean references proves nothing about a
# trajectory endpoint, which is why the noised pair is in the list.
#
# Env:
#   CL_PSI=            trajectory ψ jld2 from nucleate.jl (or a bifurcation cell)
#   CL_BIF=figs/eu334/bifurcation      the two branch walks (E and ⟨F⊥⟩ vs f)
#   CL_KAPPA=1.8 CL_B=20.0 CL_GRID=64 CL_BOX=24.0 CL_PIN=0.002
#   CL_LADDER=0.008;0.004;0.002  CL_LBFGS=400  CL_TOL=1e-5
#   CL_NOISE_ETA=                calibration noise, as a density-weighted fraction;
#                                defaults to the run's own measured excitation
#   CL_OUT=figs/eu334/classify
#   CL_CALIBRATE=1               run the calibration and stop
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu334/classify.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, find_ground_state_lbfgs,
    static_zeeman, spin_scalars, magnetization, orbital_angular_momentum,
    component_populations, winding_number_field, cell_volume, total_norm,
    make_grid, GridConfig, make_fft_plans, CUDABackend, CPUBackend
using JLD2: jldopen
using DelimitedFiles: writedlm, readdlm
using Random
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)
getl(k, d) = sort(parse.(Float64, split(gets(k, d), r"[,;]")); rev=true)

const KAPPA = getf("CL_KAPPA", 1.8)
const B_UG = getf("CL_B", 20.0)
const GRID_N = Int(getf("CL_GRID", 64))
const BOX = getf("CL_BOX", 24.0)
const PIN = getf("CL_PIN", 0.002)
const LADDER = getl("CL_LADDER", "0.008;0.004;0.002")
const LBFGS = Int(getf("CL_LBFGS", 400))
const TOL = getf("CL_TOL", 1e-5)
const BIF = gets("CL_BIF", joinpath("figs", "eu334", "bifurcation"))
const OUT = gets("CL_OUT", joinpath("figs", "eu334", "classify"))
const WIND_THRESH = getf("CL_WIND_THRESH", 1e-3)
# Eigenvector-residual polish on the final rung. Off by default (~20×120 HvPs);
# ON is what makes the energy comparison certified rather than merely small.
const RESID = gets("CL_RESIDUAL", "0") == "1"
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET1 = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET1.atom
const SYS = SpinSystem(ATOM.F)
const NATOMS = PRESET1.n_atoms

p_of(B) = Units.bfield_to_p(B * 1e-6, ATOM.g_F, PRESET1.omega_ref)
preset_at(f) = eu151_preset(; n_atoms=max(1, round(Int, f * NATOMS)),
    n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX), trap_ratios=(1.0, 1.0, KAPPA))

base_kw(pr, ε) = (; grid=pr.grid, atom=ATOM, interactions=pr.interactions,
    potential=pr.potential, zeeman=static_zeeman(; Bz=p_of(B_UG), Bx=ε, q=0.0),
    enable_ddi=true, c_dd=pr.c_dd, secular_ddi=false, backend=BACKEND,
    ddi_padding=false, ddi_trunc_radius=-1.0)

"""The two branches as functions of f, read from the bifurcation walks.

Interpolated at the trajectory's OWN condensate fraction rather than compared to
the f = 1 references: a growth ramp ends where its lag leaves it, and comparing a
state at f = 0.8 to the f = 1 branch energies would report the missing atoms as a
branch difference. Linear in f between cells; the walks are dense enough
(geometric, 25 cells over a decade and a half) that the interpolation error is
far below the branch separation, and both are reported so that can be seen."""
function branch_table()
    tabs = Dict{Symbol, Any}()
    for (k, nm) in ((:flower, "flower_down.csv"), (:polar, "polar_up.csv"))
        p = joinpath(BIF, nm)
        isfile(p) || error("""
            missing $p — the branch table is what a classification is against.
            Run scripts/eu334/nucleation_bifurcation.jl first.""")
        raw = readdlm(p, '\t')
        hdr = String.(raw[1, :])
        col(c) = raw[2:end, findfirst(==(c), hdr)]
        ord = sortperm(Float64.(col("f")))
        f = Float64.(col("f"))[ord]
        fp = Float64.(col("fperp"))[ord]
        # The flower WALK keeps going after the flower BRANCH ends: below f_sp it
        # has fallen onto the polarised branch, and those rows wear the flower
        # walk's filename while holding polarised energies. Interpolating them
        # would compare a polarised state against a polarised reference labelled
        # "flower" and return FLOWER — which is what it did, on every 60 ms probe
        # endpoint seeded below f_sp.
        #
        # ⟨F⊥⟩ separates the two by a factor 20 here (0.12 against 3.5), so a cut
        # at 1.0 is not a fitted threshold; it is the gap.
        keep = k === :flower ? fp .> 1.0 : trues(length(f))
        tabs[k] = (; f=f[keep], E=Float64.(col("E_atom"))[ord][keep],
            fperp=fp[keep], Jz=Float64.(col("Jz"))[ord][keep],
            f_min=isempty(f[keep]) ? Inf : minimum(f[keep]))
    end
    isempty(tabs[:flower].f) && error("""
        the flower branch table is empty after masking to ⟨F⊥⟩ > 1 — the walk in
        $BIF never held the flower branch, so there is nothing to classify against.""")
    tabs
end

function interp(t, f, field)
    x, y = t.f, getfield(t, field)
    f <= x[1] && return y[1]
    f >= x[end] && return y[end]
    i = searchsortedlast(x, f)
    w = (f - x[i]) / (x[i + 1] - x[i])
    (1 - w) * y[i] + w * y[i + 1]
end

"""Density-weighted perturbation, a fraction η OF ψ ITSELF.

Not `add_white_noise!`, whose `amp` is absolute: at 64³×13 an amp of 0.01 adds a
norm² of order 100 against the state's 1, so the "perturbed" state is almost all
noise. That mistake produced two controls reading the same ⟨F⊥⟩ from different
branches on 2026-08-18."""
function perturb!(psi, η, seed)
    η > 0 || return psi
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += η * abs(psi[i]) * (randn(rng) + im * randn(rng)) / sqrt(2)
    end
    psi
end

"""Quench and relax: reservoir off, ε-ladder L-BFGS to the nearest local minimum
at this f. The ladder is the same one the branch walks used — a state relaxed
under a different pin is a state of a different Hamiltonian."""
function relax(psi1, f)
    pr = preset_at(f)
    psi = Array{ComplexF64}(psi1)
    local g
    for (j, ε) in enumerate(LADDER)
        # `residual_polish` on the LAST rung. L-BFGS accepts steps by an energy
        # comparison, so it floors at √eps·‖g‖ and stops at `max_steps` on a state
        # that is as good as the method can make it — which is what every T = 10
        # endpoint did, leaving |∇E| up to 1.7e-2 and the energy comparison
        # uncertified. `residual_newton_refine` drives (H−µ)ψ→0 instead and is not
        # energy-gated, so the gradient becomes the certificate rather than the
        # obstacle. This is the case CLAUDE.md names for it.
        g = find_ground_state_lbfgs(; base_kw(pr, ε)..., psi_init=psi, n_steps=LBFGS,
            tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false,
            residual_polish=(RESID && j == length(LADDER)))
        psi = Array{ComplexF64}(g.workspace.state.psi)
    end
    s = spin_scalars(psi, pr.grid)
    Lz = orbital_angular_momentum(psi, pr.grid, g.workspace.fft_plans)
    Sz = magnetization(psi, pr.grid, SYS)
    (; psi, E=g.energy, grad=g.grad_norm, conv=g.converged,
        stop=String(g.stop_reason), s.fperp, s.fz, Lz, Sz, Jz=Lz + Sz)
end

"""Branch label from the relaxed energy against the two interpolated references.

`excited` is a real outcome: a state above BOTH branches by more than their
separation is not on either, and #335's adiabatic endpoints were exactly that."""
function assign(E, tabs, f)
    # BELOW the flower branch's own start there is no second basin to be in, so
    # there is nothing to classify: the state is polarised because that is the
    # only thing it can be. Returning `:polarised` there would be true but would
    # also inflate a "0 % flower" statistic with cells where the question was not
    # posed, so it is labelled separately.
    f < tabs[:flower].f_min && return (; label=:below_branch,
        E_flower=NaN, E_polar=interp(tabs[:polar], f, :E), sep=NaN,
        dE_flower=NaN, dE_polar=E - interp(tabs[:polar], f, :E))
    # ABOVE the table there is no reference at all, and `interp` clamps at the last
    # row rather than saying so. E/atom rises steeply with f — 7.11 at f = 0.347
    # against 8.33 at 0.521 — so comparing an f = 0.60 state against the f = 0.521
    # references adds ≈ +0.4 to BOTH differences and every endpoint comes back
    # `excited` by ten times the branch separation. That is what the T = 10 cells
    # reported until 2026-08-20, while the same states' relaxed ⟨F⊥⟩ was 4.64 —
    # the flower value. The energy test cannot be run off the end of its table.
    fmax = tabs[:flower].f[end]
    f > fmax * (1 + 1e-9) && return (; label=:above_table,
        E_flower=NaN, E_polar=NaN, sep=NaN, dE_flower=NaN, dE_polar=NaN)
    Ef = interp(tabs[:flower], f, :E)
    Ep = interp(tabs[:polar], f, :E)
    sep = abs(Ep - Ef)
    # DEGENERATE REFERENCES. "Nearer of two" is only a question when there are two.
    # At κ = 0.9 both walks land on the SAME state — #335's result that the
    # crossover side carries one branch. Without this guard the comparison below
    # resolves on the last digit of an interpolation and returns `flower` or
    # `polarised` with full confidence and no refusal: a selection statistic
    # manufactured where there is nothing to select between, which is exactly the
    # failure #334's criterion 7 exists to detect.
    #
    # THE TEST IS ON THE STATE, NOT THE ENERGY, and the first version of this guard
    # got that wrong. Energy separation does NOT distinguish the cases: measured
    # over every masked row, relative |ΔE| is 1.14e-4 … 4.89e-3 at κ = 1.8 (64³)
    # against 8.6e-7 … 4.55e-4 at κ = 0.9. Those OVERLAP — the branches genuinely
    # approach each other in energy near the bifurcation, which is what a
    # bifurcation is — so an energy cut tight enough to catch κ = 0.9 refuses
    # production rows at κ = 1.8. Close is not the same as identical.
    #
    # Transverse spin separates them cleanly: |ΔF⊥|/F⊥ is 0.966 … 0.979 at κ = 1.8
    # (0.968 … 0.986 at 32³) against 2.0e-4 … 0.424 at κ = 0.9. No overlap, and the
    # cut sits ~1.5× from each side rather than hugging either.
    Ff = interp(tabs[:flower], f, :fperp)
    Fp = interp(tabs[:polar], f, :fperp)
    abs(Ff - Fp) <= 0.7 * max(abs(Ff), abs(Fp)) && return (;
        label=:degenerate_references, E_flower=Ef, E_polar=Ep, sep,
        dE_flower=E - Ef, dE_polar=E - Ep)
    lab = if E > max(Ef, Ep) + sep
        :excited
    elseif abs(E - Ef) <= abs(E - Ep)
        :flower
    else
        :polarised
    end
    (; label=lab, E_flower=Ef, E_polar=Ep, sep, dE_flower=E - Ef, dE_polar=E - Ep)
end

"""Per-component winding on the mid-plane, thresholded on THAT component's own
peak, with the charged-plaquette count beside it.

A minority component holding 0.3 % of the atoms sits two to three orders below the
global density peak, so a global mask erases it and returns a spurious zero; the
plaquette count is what separates "zero, measured" from "nothing was looked at".
The detector is exact for |ℓ| ≤ 1 on this grid and mis-reads |ℓ| ≥ 2, which is
stated because a null here would otherwise be unfalsifiable."""
function windings(psi, grid)
    D = size(psi)[end]
    kz = size(psi, 3) ÷ 2 + 1
    pops = component_populations(psi, grid, SYS).populations
    out = NamedTuple[]
    for c in 1:D
        pk = maximum(abs2, view(psi, :, :, :, c))
        pk > 0 || (push!(out, (; c, m=SYS.m_values[c], pop=pops[c], w=0, nz=0)); continue)
        w = winding_number_field(psi, grid; component=c, threshold=WIND_THRESH * pk)
        pl = view(w, :, :, kz)
        push!(out, (; c, m=SYS.m_values[c], pop=pops[c], w=sum(pl), nz=count(!iszero, pl)))
    end
    out
end

"""ψ (unit-normalised) and the condensate fraction it was carrying."""
function load_psi(path)
    jldopen(path, "r") do h
        g(k, d) = haskey(h, k) ? h[k] : d
        psi = Array{ComplexF64}(h["psi"])
        n = g("grid_n_points", nothing)
        n === nothing || first(n) == GRID_N ||
            error("ψ grid $(first(n)) ≠ $GRID_N — $path")
        # a trajectory ψ is norm-N; a bifurcation cell is unit-norm with its own f
        nrm = total_norm(psi, PRESET1.grid)
        f = haskey(h, "N_C") ? Float64(h["N_C"]) / NATOMS :
            haskey(h, "f") ? Float64(h["f"]) : nrm / NATOMS
        (; psi=psi ./ sqrt(nrm), f, meta=(; N=nrm,
            T=Float64(g("T", NaN)), tau_ms=Float64(g("tau_ms", NaN)),
            seed=Int(g("seed", -1)), noise=g("noise", missing)))
    end
end

"""Excitation the endpoint carries, as a density-weighted fraction — the amplitude
the calibration has to survive. Measured as the relative distance between the
field and its own relaxed state, so the controls are noised at the level the real
cells actually arrive with rather than at a number someone picked."""
function excitation(psi1, relaxed_psi, grid)
    a = vec(psi1)
    b = vec(relaxed_psi)
    ph = angle(sum(conj.(b) .* a))          # remove the global phase before differencing
    sqrt(sum(abs2, a .- b .* cis(ph)) / sum(abs2, b))
end

function calibrate(tabs, f, eta)
    @printf("\ncalibration at f = %.4f, noise η = %.4f\n", f, eta)
    fl = joinpath(BIF, @sprintf("flower_down_f%06.4f.jld2", f))
    po = joinpath(BIF, @sprintf("polar_up_f%06.4f.jld2", f))
    for p in (fl, po)
        isfile(p) || error("missing calibration state $p — pick an f the walks hold")
    end
    load(p) = jldopen(h -> Array{ComplexF64}(h["psi"]), p, "r")
    ok = true
    cases = Any[("flower", load(fl), :flower), ("polarised", load(po), :polarised),
        ("flower+noise", perturb!(copy(load(fl)), eta, 11), :flower),
        ("polarised+noise", perturb!(copy(load(po)), eta, 12), :polarised),
        ("half-and-half", (load(fl) .+ load(po)) ./ sqrt(2), nothing)]
    rows = Any[]
    for (nm, psi, want) in cases
        r = relax(psi, f)
        a = assign(r.E, tabs, f)
        got = a.label
        pass = want === nothing ? true : got === want
        ok &= pass
        @printf("  %-16s → %-10s  E=%.6f  ΔE_flower=%+.2e  ⟨F⊥⟩=%.4f   %s\n",
            nm, String(got), r.E, a.dE_flower, r.fperp,
            want === nothing ? "(recorded)" : (pass ? "ok" : "FAIL, wanted $want"))
        push!(rows, Any[nm, String(got), want === nothing ? "" : String(want), pass,
            r.E, a.dE_flower, a.dE_polar, r.fperp, r.Jz, r.grad, r.stop])
    end
    writedlm(joinpath(OUT, @sprintf("calibration_f%06.4f.csv", f)),
        vcat(permutedims(["case", "got", "want", "pass", "E", "dE_flower", "dE_polar",
                "fperp", "Jz", "grad", "stop"]), permutedims.(rows)...), '\t')
    ok || error("""
        classifier calibration FAILED — no trajectory is classified.
        A classifier that cannot recover a branch from its own reference state
        cannot be read on a trajectory endpoint.""")
    @printf("  calibration passed\n")
    ok
end

function main()
    tabs = branch_table()
    if gets("CL_CALIBRATE", "") == "1"
        f = getf("CL_F", 0.5)
        # nearest f the walks actually hold
        fs = tabs[:flower].f
        f = fs[argmin(abs.(fs .- f))]
        calibrate(tabs, f, getf("CL_NOISE_ETA", 0.05))
        return nothing
    end

    path = gets("CL_PSI", "")
    isempty(path) && error("CL_PSI is required")
    d = load_psi(path)
    grid = PRESET1.grid
    @printf("classify %s\n  f = %.4f (N_C = %.0f), T = %.2f, τ = %.1f ms, seed %d, noise %s\n",
        basename(path), d.f, d.meta.N, d.meta.T, d.meta.tau_ms, d.meta.seed,
        string(d.meta.noise))

    r = relax(d.psi, d.f)
    a = assign(r.E, tabs, d.f)
    eta = excitation(d.psi, r.psi, grid)
    s_raw = spin_scalars(d.psi, grid)
    @printf("  raw ⟨F⊥⟩ %.4f → relaxed %.4f   (branch refs at this f: %.4f / %.4f)\n",
        s_raw.fperp, r.fperp, interp(tabs[:flower], d.f, :fperp),
        interp(tabs[:polar], d.f, :fperp))
    @printf("  E_relaxed = %.6f   ΔE_flower = %+.4e   ΔE_polar = %+.4e   sep = %.4e\n",
        r.E, a.dE_flower, a.dE_polar, a.sep)
    @printf("  |∇E| = %.2e (%s)   excitation carried η = %.4f%s\n", r.grad, r.stop, eta,
        RESID ? "   [residual-polished]" : "")
    # A verdict read off an unconverged relaxation is a verdict about the solver.
    # Say so on the line rather than leaving it to whoever reads `stop` later.
    r.grad < 10 * TOL || @printf(
        "  CAUTION: |∇E| = %.1e is %.0f× the gate — the energy comparison below is a bound, not a measurement\n",
        r.grad, r.grad / TOL)
    @printf("  BRANCH: %s\n", uppercase(String(a.label)))

    w = windings(r.psi, grid)
    tot = sum(x -> x.w, w)
    charged = sum(x -> x.nz, w)
    @printf("  winding: Σ_c w_c = %d over %d charged plaquettes  (per-component, thr %.0e·peak)\n",
        tot, charged, WIND_THRESH)
    for x in w
        x.pop > 1e-4 && @printf("    m=%+d  pop %.4f  w %+d  (%d charged)\n",
            x.m, x.pop, x.w, x.nz)
    end

    pops = component_populations(r.psi, grid, SYS).populations
    lv = count(>=(0.05), pops)
    ipr = 1 / sum(abs2, pops)
    @printf("  Stern-Gerlach: %d levels ≥ 5%%, 1/Σp² = %.2f\n", lv, ipr)

    tag = replace(basename(path), r"^psi_" => "", ".jld2" => "")
    writedlm(joinpath(OUT, "class_$tag.csv"),
        vcat(permutedims(["file", "f", "N_C", "T", "tau_ms", "seed", "branch", "E",
                "dE_flower", "dE_polar", "sep", "fperp_raw", "fperp_relaxed", "Jz",
                "grad", "stop", "eta", "winding_sum", "charged_plaquettes",
                "sg_levels", "sg_ipr"]),
            permutedims(Any[basename(path), d.f, d.meta.N, d.meta.T, d.meta.tau_ms,
                d.meta.seed, String(a.label), r.E, a.dE_flower, a.dE_polar, a.sep,
                s_raw.fperp, r.fperp, r.Jz, r.grad, r.stop, eta, tot, charged, lv, ipr])),
        '\t')
    nothing
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    main()
end
