#!/usr/bin/env julia
# How much of an L-BFGS step is motion ALONG the symmetry orbit?
#
#   julia --project=. bench/probe_lbfgs_orbit_fraction.jl [grid_n] [n_steps]
#
# The weak-field Eu+DDI ground state spontaneously breaks the exact axial U(1)
# `e^{-iθ(L_z+F_z)}` (spin+space co-rotation), so the minimum is a degenerate
# ORBIT rather than a point. `∇E ⊥ (L_z+F_z)ψ` holds identically for an exact
# symmetry, and the repo has measured it (cos 6e-5) — so the GRADIENT carries no
# orbit component and nothing is wrong with the direction.
#
# The ITERATE is the question. Nothing stops ψ_{k+1} sitting at a different
# point of the orbit from ψ_k, and any such displacement enters
# `s_k = ψ_{k+1} − ψ_k` while carrying NO curvature information. L-BFGS then
# stores it, spends history depth on it, and shrinks ⟨s,y⟩. Quotienting the
# symmetry out — "phase alignment", picking a canonical representative of each
# orbit before differencing — is the standard remedy (Danaila & Protas
# arXiv:1703.07693; Structure and symmetry of the GP ground-state manifold,
# arXiv:2603.28174, which also shows this degeneracy does NOT preclude local
# linear convergence: Morse-Bott holds when the minimisers are finitely many
# orbits, and one orbit is finitely many).
#
# This probe SIZES that before anything is built. If the orbit fraction of a
# step is a percent, aligning the gauge cannot matter and the idea dies here.
#
# Two generators are measured, and the second is the control:
#   (L_z + F_z)  the broken symmetry
#   1            global phase — also an exact symmetry, and the gradient is
#                orthogonal to it for the same reason, so its fraction is what
#                "small" looks like on this problem.
#
# Iterates come from re-solving with increasing `n_steps` from the same start.
# That is O(K²) steps, and it is exact rather than approximate: the solve is
# deterministic WITHIN a process (it varies between processes only because the
# FFTW plan chosen at startup changes the rounding).

using SpinorBEC
using SpinorBEC: CoriolisTerm, apply_operator!, _realdot
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

const GRID_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const K = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 40

function cell()
    grid = make_grid(GridConfig((GRID_N, GRID_N, GRID_N), (12.0, 12.0, 12.0)))
    (;
        grid, atom=AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0),
        interactions=interaction_params_from_constraint(;
            c_total=EU_c_total, c1_ratio=0.05, F=6),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        enable_ddi=true, c_dd=EU_c_dd, backend=CPUBackend(),
        # NOT `:m_plus_F`, and that is the whole fixture. From it `L_zψ = 0`
        # exactly (no azimuthal dependence) and `F_zψ = Fψ`, so the orbit
        # tangent `-i(L_z+F_z)ψ` is PARALLEL to the phase tangent `iψ` — the two
        # generators are indistinguishable and both are trivially orthogonal to
        # any norm-preserving step. The first run of this probe measured exactly
        # that and reported 0.0000 for the signal AND the control.
        #
        # A transverse spin-coherent state separates them: `F_zψ` is no longer
        # proportional to ψ, so the co-rotation generator acts. It is also the
        # weak-field starting point the soft-manifold work uses.
        initial_state=:spin_coherent,
        init_state_params=Dict(:init_theta => Float64(π) / 2, :init_phi => 0.0),
        verbose=false,
    )
end

"`-i(L_z + F_z)ψ`, the tangent to the axial co-rotation orbit at ψ."
function orbit_tangent(psi, ws)
    lz = similar(psi)
    fill!(lz, zero(eltype(lz)))
    # `H_coriolis = -Ω·L_z` and `apply_operator!` accumulates `H·ψ`, so Ω = 1
    # gives `-L_zψ`. Reusing the audited term rather than writing a second
    # spectral derivative for L_z.
    apply_operator!(lz, CoriolisTerm(1.0), ws, psi)
    lz .*= -1                                   # now L_zψ
    sys = ws.spin_matrices.system
    F, D = sys.F, sys.n_components
    t = similar(psi)
    for c in 1:D
        m = Float64(F - (c - 1))
        idx = ntuple(d -> d == ndims(psi) ? (c:c) : Colon(), ndims(psi))
        @views t[idx...] .= lz[idx...] .+ m .* psi[idx...]
    end
    t .*= -im                                   # -i(L_z + F_z)ψ
    t
end

"`iψ`, the tangent to the global-phase orbit — the control."
phase_tangent(psi) = im .* psi

"Fraction of `s` lying along `t`, in the real inner product the solver uses."
function along(t, s, dV)
    nt = sqrt(_realdot(t, t) * dV)
    ns = sqrt(_realdot(s, s) * dV)
    (nt == 0 || ns == 0) && return 0.0
    abs(_realdot(t, s) * dV) / (nt * ns)
end

"""
    control(psi, ws, dV) → Float64

Apply the group element itself and measure the displacement it produces. A
finite θ rotation gives a step that is almost entirely orbit motion, so this
must come back near 1. Anything else means `orbit_tangent` is not the tangent
to the orbit and every number below it is meaningless — which is exactly how
the first version of this probe reported a clean 0.0000 for signal and control
alike.
"""
function control(psi, ws, dV, θ)
    lz = similar(psi)
    fill!(lz, zero(eltype(lz)))
    apply_operator!(lz, CoriolisTerm(1.0), ws, psi)
    lz .*= -1
    sys = ws.spin_matrices.system
    F, D = sys.F, sys.n_components
    # `e^{-iθ(L_z+F_z)}` is not available as one operator here, so rotate by the
    # F_z part only and check THAT generator, which is the half that
    # distinguishes this orbit from the global phase.
    rot = similar(psi)
    for c in 1:D
        m = Float64(F - (c - 1))
        idx = ntuple(d -> d == ndims(psi) ? (c:c) : Colon(), ndims(psi))
        @views rot[idx...] .= cis(-θ * m) .* psi[idx...]
    end
    s = rot .- psi
    tF = similar(psi)
    for c in 1:D
        m = Float64(F - (c - 1))
        idx = ntuple(d -> d == ndims(psi) ? (c:c) : Colon(), ndims(psi))
        @views tF[idx...] .= (-im * m) .* psi[idx...]
    end
    along(tF, s, dV)
end

function main()
    c = cell()
    dV = cell_volume(c.grid)
    println("orbit-fraction probe — Eu151 F=6 $(GRID_N)^3 +DDI, steps 1..$K")
    println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
    println()
    # Instrument check BEFORE any measurement. A small rotation is almost pure
    # orbit motion; if this is not ~1 the tangent is wrong.
    let r0 = find_ground_state_lbfgs(; c..., n_steps=1, tol=0.0)
        ws0 = r0.workspace
        p0 = copy(ws0.state.psi)
        for θ in (1.0e-4, 1.0e-2)
            ctl = control(p0, ws0, dV, θ)
            @printf("  positive control: rotate by θ=%.0e ⇒ orbit frac %.6f\n", θ, ctl)
            if !(ctl > 0.99)
                println("  !! INSTRUMENT BROKEN — the tangent does not follow the group. Stop.")
                return
            end
        end
        println()
    end

    @printf("  %5s %12s %14s %14s\n", "step", "|s_k|", "orbit frac", "phase frac")

    prev = nothing
    ws_ref = nothing
    fr_orbit = Float64[]
    fr_phase = Float64[]
    for k in 1:(K + 1)
        r = find_ground_state_lbfgs(; c..., n_steps=k, tol=0.0)
        psi = copy(r.workspace.state.psi)
        ws_ref = r.workspace
        if prev !== nothing
            s = psi .- prev
            ns = sqrt(_realdot(s, s) * dV)
            fo = along(orbit_tangent(prev, ws_ref), s, dV)
            fp = along(phase_tangent(prev), s, dV)
            push!(fr_orbit, fo)
            push!(fr_phase, fp)
            # Scientific notation on purpose: `%.4f` printed 1e-5 and 1e-16
            # both as 0.0000, which hid whether the first run's null was a
            # measurement or a degenerate fixture.
            k % 5 == 1 && @printf("  %5d %12.4e %14.4e %14.4e\n", k - 1, ns, fo, fp)
            flush(stdout)
        end
        prev = psi
    end

    srt(v) = sort(v)
    q(v, p) = srt(v)[clamp(round(Int, p * length(v)), 1, length(v))]
    println()
    @printf("  orbit fraction  median %.3e   p90 %.3e   max %.3e   (n=%d)\n",
        q(fr_orbit, 0.5), q(fr_orbit, 0.9), maximum(fr_orbit), length(fr_orbit))
    @printf("  phase fraction  median %.3e   p90 %.3e   max %.3e   [reference]\n",
        q(fr_phase, 0.5), q(fr_phase, 0.9), maximum(fr_phase))
    println()
    println("  A step is a unit vector, so `frac` is the cosine to the orbit tangent.")
    println("  Aligning the gauge before forming s_k can only recover what is here;")
    println("  if the orbit fraction is at the level of the phase control, it is nothing.")
end

main()
