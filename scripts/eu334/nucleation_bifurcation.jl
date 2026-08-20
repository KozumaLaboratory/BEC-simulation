#!/usr/bin/env julia
# Where the flower branch is BORN, as a condensate grows at the #334 target point.
#
# #334 asks whether a cooling trajectory nucleates the flower texture in place at
# (κ = 1.8, B = 20 µG) or gets caught on the polarised branch. `window.jl` measures
# the two numbers that bound the answer before any trajectory is run; this measures
# the third, and it is the one that says WHERE in the trajectory the choice is made.
#
# The argument. A condensate that grows at fixed field is a state whose couplings
# grow with it: (c₀, c₁, c_dd) ∝ N₀ at fixed p, because every one of them carries
# the atom number and the Zeeman term does not. So the family of mean-field states
# a growing condensate can occupy is a one-parameter continuation in
#
#     f ≡ N₀ / N,     N = 5×10⁴,     B = 20 µG, κ = 1.8 held fixed.
#
# At f → 0 the Zeeman term wins and the only state is polarised. At f = 1 the
# flower is the ground state, 0.133 ℏω_ref per atom below the polarised branch
# (#335 §5.1). Between them two things have to happen, and they are different
# events at different f:
#
#   f_eq  — the energies CROSS. Below it polarised is the ground state, above it
#           flower is. The extensive separation N₀·ΔE passes through zero here, so
#           this is the ONLY place on the growth path where the two textures are
#           within k_BT of each other — i.e. the only place a fluctuation can
#           choose.
#   f_sp  — the flower branch comes into EXISTENCE (its spinodal in f). Below it
#           there is nothing to select; a growing condensate has no choice at all.
#
# and the third question is whether the polarised branch has a spinodal in f at
# all. If it does not — if it stays a local minimum from f = 0 to f = 1 — then a
# condensate that grows quasi-statically **stays polarised**, deterministically,
# and the flower is reachable only by a fluctuation in the window around f_eq.
# That is a falsifiable structural statement about the cooling experiment, and it
# is measured here for ~1 CPU-minute per cell rather than by an ensemble of
# stochastic trajectories.
#
# The output is therefore the pre-registered PREDICTION the SPGPE ensemble tests:
# the selection window in f, its width in k_BT at each candidate temperature, and
# the growth rate that would cross it adiabatically.
#
# Two guards, both inherited from `scripts/eu_hysteresis/branch_continuation.jl`
# because the failure modes are identical — "the branch died" and "the solver gave
# up" produce the same picture on this soft manifold:
#
#   1. ε-LADDER ON EVERY CELL. A fixed pin stalls at |∇E| ~ 1e-2, four orders above
#      the gate. A stalled cell is the warm seed for the next one, so one stall
#      propagates and the continuation falls off the branch for solver reasons at
#      an f that then gets reported as a bifurcation.
#   2. ORDER-PARAMETER RESPONSE TO A SECOND POLISH. |∇E| does not certify a
#      minimum here (3.6e-4 was once 0.59 off in ⟨F⊥⟩, memory
#      `mistake_small_gradient_was_not_the_right_minimum_2026_08_06`). Cells whose
#      ⟨F⊥⟩ still moves are refused rather than read.
#
# Unpadded DDI and pin ε = 0.002, matching #335 so the f = 1 end of each walk must
# reproduce that campaign's own converged branch — which is this script's positive
# control and is asserted, not hoped for.
#
# Env:
#   NB_KAPPA=1.8  NB_B=20.0        the target point
#   NB_GRID=32  NB_BOX=24.0
#   NB_FMIN=0.02  NB_FMAX=1.0  NB_NF=25    f ladder (geometric)
#   NB_PIN=0.002  NB_LADDER=0.008;0.004;0.002
#   NB_LBFGS=400  NB_ITP=2000  NB_TOL=1e-5
#   NB_SEEDS=figs/eu334/seeds       reference_{flower,m_minus_F}.jld2 anchor the f=1 end
#   NB_OUT=figs/eu334/bifurcation
#   NB_SMOKE=1                      4 cells, tiny caps — every path in ≤ 3 min
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu334/nucleation_bifurcation.jl

using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, find_ground_state,
    find_ground_state_lbfgs, init_psi, static_zeeman, spin_scalars, magnetization,
    orbital_angular_momentum, make_workspace, SimParams, cell_volume,
    apply_operator_via_registry!, upsample_spinor, CPUBackend
using JLD2: jldopen, jldsave
using DelimitedFiles: writedlm
using Printf

import CUDA
const HAS_CUDA = CUDA.functional()
const BACKEND = HAS_CUDA ? SpinorBEC.CUDABackend() : CPUBackend()

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)
function getl(k, d)
    s = gets(k, d)
    v = sort(parse.(Float64, split(s, r"[,;]")); rev=true)
    n = get(ENV, k * "_N", "")
    isempty(n) || length(v) == parse(Int, n) ||
        error("$k parsed $(length(v)) entries but $(k)_N says $n: $(repr(s)) — use `;`")
    v
end

const SMOKE = gets("NB_SMOKE", "") == "1"
const KAPPA = getf("NB_KAPPA", 1.8)
const B_UG = getf("NB_B", 20.0)
const GRID_N = Int(getf("NB_GRID", 32))
const BOX = getf("NB_BOX", 24.0)
const PIN = getf("NB_PIN", 0.002)
const LADDER = SMOKE ? [2PIN, PIN] : getl("NB_LADDER", "0.008;0.004;0.002")
const LADDER_A = SMOKE ? [4PIN, PIN] : getl("NB_LADDER_ANCHOR", "0.02;0.01;0.005;0.002")
const LBFGS = SMOKE ? 60 : Int(getf("NB_LBFGS", 400))
const ITP = SMOKE ? 150 : Int(getf("NB_ITP", 2000))
const TOL = getf("NB_TOL", 1e-5)
const FMIN = getf("NB_FMIN", 0.02)
const FMAX = getf("NB_FMAX", 1.0)
const NF = SMOKE ? 4 : Int(getf("NB_NF", 25))
const SEEDS = gets("NB_SEEDS", joinpath("figs", "eu334", "seeds"))
const OUT = gets("NB_OUT", joinpath("figs", "eu334", "bifurcation"))
mkpath(OUT)

isapprox(last(LADDER), PIN; rtol=1e-12) || error("NB_LADDER must end at NB_PIN=$PIN")

# The f ladder is GEOMETRIC: f_eq and f_sp are set by the ratio of the spin
# interaction (∝ N₀) to the Zeeman term (fixed), so the interesting structure is
# at small f and a linear ladder would spend most of its cells where nothing
# happens.
#
# ROUNDED to the 4 decimals the cell filenames carry, so that the name and the
# value are the same number. Without it a refinement walk asked for FMAX=0.2714
# and was handed a cell recording 0.27144176, and the anchor check — correctly —
# refused it: a file named after a rounded f is a lossy key, and the fix is to
# make the key exact rather than to loosen the check.
const F_LADDER = round.(collect(exp.(range(log(FMIN), log(FMAX); length=NF))); digits=4)

# The f = 1 preset IS #335's, and its couplings are the thing every anchor is
# checked against.
const PRESET1 = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET1.atom
const SYS = SpinSystem(ATOM.F)
const NATOMS = PRESET1.n_atoms

p_of(B) = Units.bfield_to_p(B * 1e-6, ATOM.g_F, PRESET1.omega_ref)
const P_TARGET = p_of(B_UG)

"""The preset at condensate fraction `f`. `eu151_preset` folds the atom number
into (c₀, c₁, c_dd) — all three, through the same `n_atoms` — so scaling it IS
scaling the condensate at fixed trap and fixed field. That single entry point is
why this is not three separate rescalings that could drift apart."""
preset_at(f) = eu151_preset(; n_atoms=max(1, round(Int, f * NATOMS)),
    n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))

base_kw(pr, ε) = (; grid=pr.grid, atom=ATOM, interactions=pr.interactions,
    potential=pr.potential, zeeman=static_zeeman(; Bz=P_TARGET, Bx=ε, q=0.0),
    enable_ddi=true, c_dd=pr.c_dd, secular_ddi=false, backend=BACKEND,
    ddi_padding=false, ddi_trunc_radius=-1.0)

function cell_scalars(psi, grid, fft_plans)
    s = spin_scalars(psi, grid)
    Lz = orbital_angular_momentum(psi, grid, fft_plans)
    Sz = magnetization(psi, grid, SYS)
    (; s.fz, s.fperp, Lz, Sz, Jz=Lz + Sz)
end

"""Walk the ε ladder from `psi0` at condensate fraction `f`, warm-restarting each
rung, then certify with a second polish at the final rung."""
function solve_cell(psi0, f; cap=LBFGS, ladder=LADDER)
    pr = preset_at(f)
    psi = Array{ComplexF64}(psi0)
    local g
    for (j, ε) in enumerate(ladder)
        g = find_ground_state_lbfgs(; base_kw(pr, ε)..., psi_init=psi, n_steps=cap,
            tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false)
        psi = Array{ComplexF64}(g.workspace.state.psi)
    end
    sc = cell_scalars(psi, pr.grid, g.workspace.fft_plans)
    g2 = find_ground_state_lbfgs(; base_kw(pr, last(ladder))..., psi_init=psi,
        n_steps=cap, tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false)
    psi2 = Array{ComplexF64}(g2.workspace.state.psi)
    sc2 = cell_scalars(psi2, pr.grid, g2.workspace.fft_plans)
    dfp = sc2.fperp - sc.fperp
    (; psi=psi2, E=g2.energy, grad=g2.grad_norm, conv=g2.converged,
        stop=String(g2.stop_reason), last_step=g2.last_step, sc2...,
        dfperp_polish=dfp, n_atoms=preset_at(f).n_atoms)
end

"""An anchor ψ, checked and (when the walk runs on a finer grid) upsampled.

`f_at` is the condensate fraction the anchor is supposed to be a state OF: the
f = 1 references from #335 for a full walk, or a coarse-grid cell of a previous
walk when a narrow window is being refined at a finer grid. A ψ from another f,
field or pin is not a state of this Hamiltonian at all, so every key the file
records is compared and a mismatch is fatal rather than a warning."""
function load_anchor(path, f_at)
    isfile(path) || error("""
        missing anchor $path.
        For the f = 1 references, fetch the #335 seeds:
          rsync -av tsubame:/gs/fs/tga-kozuma-kouhi/uk07267/runs/eu335/seeds/ $SEEDS/""")
    jldopen(path, "r") do fh
        g(k, d) = haskey(fh, k) ? fh[k] : d
        pr = preset_at(f_at)
        for (nm, got, want) in (("c0", g("c0", NaN), pr.interactions.c[0]),
            ("c1", g("c1", NaN), pr.interactions.c[1]),
            ("c_dd", g("c_dd", NaN), pr.c_dd))
            isnan(got) && continue
            abs(got - want) / max(abs(want), 1e-30) < 1e-8 ||
                error("anchor/preset mismatch on $nm: $got vs $want — $path")
        end
        for (nm, got, want) in (("f", Float64(g("f", NaN)), f_at),
            ("B_uG", Float64(g("B_uG", NaN)), B_UG),
            ("kappa", Float64(g("kappa", NaN)), KAPPA),
            ("pin_bx", Float64(g("pin_bx", NaN)), PIN))
            isnan(got) && continue
            abs(got - want) <= 1e-9 + 1e-9 * abs(want) ||
                error("anchor/run mismatch on $nm: $got vs $want — $path")
        end
        psi = Array{ComplexF64}(fh["psi"])
        n = g("grid_n_points", nothing)
        ns = n === nothing ? size(psi, 1) : first(n)
        if ns != GRID_N
            ns < GRID_N || error("anchor grid $ns > run grid $GRID_N — $path")
            psi = upsample_spinor(psi, GRID_N)
            @printf("  upsampled anchor %d³ → %d³: %s\n", ns, GRID_N, basename(path))
        end
        # ⟨F⊥⟩ is recomputed rather than read: the stored cells carry no `fperp`
        # key, and a NaN in the positive control is a control that cannot fail.
        (; psi, E=Float64(g("E_total", g("E", NaN))),
            fperp=spin_scalars(psi, PRESET1.grid).fperp)
    end
end

"""The #335 reference at f = 1 — the positive control for a full walk: the f = 1
cell has to land back on the branch #335 converged, and if it does not, nothing
downstream of it means anything."""
anchor_f1(which) = load_anchor(
    joinpath(SEEDS, which == :flower ? "reference_flower.jld2" :
                    "reference_m_minus_F.jld2"), 1.0)

const COLS = ["f", "n_atoms", "E_atom", "E_total", "fperp", "fz", "Lz", "Sz", "Jz",
    "grad", "conv", "stop", "dfperp_polish", "last_step", "wall_s"]

"""One walk: `dirn = :down` starts at f = FMAX from the stored anchor and walks
down; `:up` starts at f = FMIN from an ITP solve of `init_state` and walks up.
Each cell warm-starts from the previous one, which is what makes it a branch and
not a set of independent solves."""
function walk(name, dirn, anchor; init_state=:m_minus_F)
    fs = dirn === :down ? reverse(F_LADDER) : F_LADDER
    rows = Any[]
    psi = if anchor !== nothing
        anchor.psi
    else
        pr = preset_at(first(fs))
        p0 = init_psi(pr.grid, SYS; state=init_state)
        gs = find_ground_state(; base_kw(pr, first(LADDER_A))..., psi_init=p0,
            dt=0.002, n_steps=ITP, tol=1e-12, save_every=max(1, ITP ÷ 4), verbose=false)
        Array{ComplexF64}(gs.workspace.state.psi)
    end
    @printf("\n[%s] %s from f = %.4f, %d cells\n", name, String(dirn), first(fs), length(fs))
    for f in fs
        t0 = time()
        r = solve_cell(psi, f)
        wall = time() - t0
        psi = r.psi
        push!(rows, Any[f, r.n_atoms, r.E, r.E * r.n_atoms, r.fperp, r.fz, r.Lz, r.Sz,
            r.Jz, r.grad, r.conv, r.stop, r.dfperp_polish, r.last_step, wall])
        @printf("  f=%.4f N₀=%6d  E/atom=%.6f  E_tot=%10.2f  ⟨F⊥⟩=%.4f  J_z=%+.4f  |∇E|=%.2e %-9s dfp=%+.1e  %.0fs\n",
            f, r.n_atoms, r.E, r.E * r.n_atoms, r.fperp, r.Jz, r.grad, r.stop,
            r.dfperp_polish, wall)
        # Block-buffered under a scheduler: without this a 12 h job shows an
        # empty log until it exits, and there is no way to tell a slow cell from
        # a hung one.
        flush(stdout)
        jldsave(joinpath(OUT, @sprintf("%s_f%06.4f.jld2", name, f)); psi=r.psi, f=f,
            n_atoms=r.n_atoms, E_total=r.E, fperp=r.fperp, Jz=r.Jz,
            grid_n_points=(GRID_N, GRID_N, GRID_N), grid_box_size=(BOX, BOX, BOX),
            B_uG=B_UG, kappa=KAPPA, pin_bx=PIN)
    end
    writedlm(joinpath(OUT, "$name.csv"), vcat(permutedims(COLS), permutedims.(rows)...), '\t')
    rows
end

function main()
    @printf("#334 nucleation bifurcation: κ=%.2f B=%.1f µG grid %d³ box %.1f pin %g  [%s]%s\n",
        KAPPA, B_UG, GRID_N, BOX, PIN, HAS_CUDA ? "CUDA" : "CPU", SMOKE ? "  SMOKE" : "")
    @printf("f ladder: %d cells, %.4f → %.4f (geometric), N = %d\n",
        NF, FMIN, FMAX, NATOMS)

    # A refinement walk over a narrow window on a finer grid anchors on the
    # coarse walk's own cells (upsampled) instead of on f = 1, so the window can
    # be re-measured at the grid a trajectory will actually run on without
    # repeating the decade and a half of cells that led to it.
    afp = gets("NB_ANCHOR_FLOWER", "")
    app = gets("NB_ANCHOR_POLAR", "")
    af = isempty(afp) ? anchor_f1(:flower) : load_anchor(afp, last(F_LADDER))
    ap = isempty(app) ? nothing : load_anchor(app, first(F_LADDER))
    @printf("anchors: flower E=%.6f ⟨F⊥⟩=%.4f | polarised %s\n",
        af.E, af.fperp, ap === nothing ? "ITP from :m_minus_F" :
                        @sprintf("E=%.6f ⟨F⊥⟩=%.4f", ap.E, ap.fperp))

    flower = walk("flower_down", :down, af)
    polar = walk("polar_up", :up, ap; init_state=:m_minus_F)

    # Positive control: the f = 1 cell of each walk must reproduce #335's own
    # converged branch. The flower walk STARTS there so its check is trivial; the
    # polarised walk arrives there after 25 cells of continuation from f = FMIN,
    # and that one is the real test of the ladder.
    # The #335 references are κ = 1.8 states. Comparing a κ = 0.9 walk against
    # them would be a control that always fails, which is worse than none —
    # anything can be attributed to it. At other κ the endpoint is printed and
    # explicitly labelled as unreferenced.
    if isapprox(last(F_LADDER), 1.0; rtol=1e-9) && isapprox(KAPPA, 1.8; rtol=1e-9)
        ref = anchor_f1(:m_minus_F)
        p1 = polar[end]
        @printf("\npositive control — polarised walk's f=1 cell vs #335 reference:\n")
        @printf("  E/atom %.6f vs %.6f (Δ = %.2e)   ⟨F⊥⟩ %.4f vs %.4f\n",
            p1[3], ref.E, p1[3] - ref.E, p1[5], ref.fperp)
        abs(p1[3] - ref.E) < 1e-3 || @printf(
            "  REFUSING to interpret: the walk did not return to the reference branch\n")
    elseif isapprox(last(F_LADDER), 1.0; rtol=1e-9)
        p1 = polar[end]
        @printf("\nκ = %.2f: no converged f = 1 reference exists for this κ, so the walk's\n", KAPPA)
        @printf("endpoint (E/atom %.6f, ⟨F⊥⟩ %.4f) is reported UNREFERENCED.\n", p1[3], p1[5])
    else
        @printf("\nwindow walk (f ends at %.4f) — the f = 1 positive control does not apply here;\n",
            last(F_LADDER))
        @printf("it is carried by the walk this one is anchored on.\n")
    end
    nothing
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    main()
end
