# --- The dumb reference ---
#
# Blatantly-correct, independent statements of every Hamiltonian term's
# energy and RHS (δE/δψ̄ per-voxel density, the canonical gradient of
# docs/design/term_oracle_bootstrap.md §1). The master oracle
# (test/oracles/test_master_oracle.jl) compares these per-term against
# the production registry faces — the mechanism behind architectural
# commitment #3 (zero silent sign drift via day-0 gated redundancy).
# See docs/design/hamiltonian_layered_architecture.md §1.
#
# Rules of this file (the independence contract):
#
# - NO FFTW: spectral operations use naive index-form DFT matrices
#   built from exp(−2πi·jk/n). The index form matches FFTW's
#   convention exactly; per-k phases from the cell-centered x-grid
#   cancel in every |·|² and in forward∘inverse pairs.
# - NO shared helper code with production: spin matrices, k-grids,
#   spin densities, singlet amplitudes are restated here from first
#   principles. Shared DATA is allowed and deliberate — ws coefficient
#   fields, ws.potential_values, waveform `evaluate` — the dumb and
#   fast sides must consume the same θ (a magnitude error in θ itself
#   is the CG-oracle's and Fisher-identifiability's job, not ours).
# - SAME discrete mathematics (discretization pinning): spectral
#   kinetic on the same fftfreq k-grid (recomputed from the formula,
#   not read from grid.k_squared), the same m-ordering c=1 ↔ m=+F,
#   the same cell volume.
# - Tiny grids only. Zero performance budget. Explicit loops preferred
#   over cleverness everywhere.
#
# Coverage (slots of H_TERMS_CANONICAL_ORDER):
# - implemented: kinetic, trap, zeeman_z, zeeman_transverse,
#   density_c0, spin_c1, lhy (scalar), tensor (c2 singlet part),
#   raman, light_shift, coriolis, magnetic_gradient, loss (≡ 0).
# - DEFERRED (own unit, arch doc §6): ddi — its dumb statement is the
#   same subtle physics in slower code and ships together with its
#   physics anchors. Slot returns NaN / nothing; the master oracle
#   carries the explicit deferral list.
# - DECLARED PRODUCTION GAPS made visible here: raman and tensor RHS
#   exist on the dumb side while production apply_operator! is nil
#   (KNOWN-LIMIT) — the master oracle asserts both sides of that gap.

# ============================================================================
# Dumb spin matrices (independent of SpinMatrices)
# ============================================================================

"""
    dumb_spin_matrices(F) -> (; Fx, Fy, Fz, Fp, Fm, m)

Spin-F matrices from the ladder formula, m-ordering pinned to the
codebase convention c = 1 ↔ m = +F … c = D ↔ m = −F.
"""
function dumb_spin_matrices(F::Int)
    D = 2F + 1
    m = [Float64(F - (c - 1)) for c in 1:D]
    Fz = zeros(ComplexF64, D, D)
    for c in 1:D
        Fz[c, c] = m[c]
    end
    # F₊|m⟩ = √(F(F+1) − m(m+1)) |m+1⟩; component c has m[c], and
    # m[c]+1 lives at component c−1.
    Fp = zeros(ComplexF64, D, D)
    for c in 2:D
        Fp[c - 1, c] = sqrt(F * (F + 1) - m[c] * (m[c] + 1))
    end
    Fm = collect(adjoint(Fp))
    Fx = (Fp .+ Fm) ./ 2
    Fy = (Fp .- Fm) ./ (2im)
    return (; Fx, Fy, Fz, Fp, Fm, m)
end

# ============================================================================
# Dumb spectral machinery (index-form DFT; k-grid recomputed from formula)
# ============================================================================

"""fftfreq-convention wavenumbers, restated: k[j] = (2π/L)·f, with
f = j₀ for j₀ < ⌈n/2⌉ else j₀ − n (j₀ = j − 1)."""
function dumb_k_axis(n::Int, L::Float64)
    dk = 2π / L
    return [dk * (j0 < cld(n, 2) ? j0 : j0 - n) for j0 in 0:(n - 1)]
end

"""Unnormalized forward DFT matrix W[k,j] = exp(−2πi·(j−1)(k−1)/n)
(FFTW forward convention). Inverse is conj(W)/n."""
function dumb_dft_matrix(n::Int)
    W = Matrix{ComplexF64}(undef, n, n)
    for kk in 1:n, j in 1:n
        W[kk, j] = cis(-2π * (j - 1) * (kk - 1) / n)
    end
    return W
end

"""Apply an n×n matrix along `axis` of a spatial array (explicit
line-by-line gather/scatter — dumb on purpose)."""
function dumb_axis_apply(A::AbstractArray{ComplexF64}, axis::Int, W::Matrix{ComplexF64})
    B = similar(A)
    n = size(A, axis)
    nd = ndims(A)
    for I in CartesianIndices(A)
        I[axis] == 1 || continue
        line = [A[CartesianIndex(ntuple(d -> d == axis ? j : I[d], nd))] for j in 1:n]
        out = W * line
        for j in 1:n
            B[CartesianIndex(ntuple(d -> d == axis ? j : I[d], nd))] = out[j]
        end
    end
    return B
end

"""Forward (unnormalized) full-dimensional DFT of one spatial component."""
function dumb_dft(A::AbstractArray{ComplexF64})
    B = copy(A)
    for axis in 1:ndims(A)
        B = dumb_axis_apply(B, axis, dumb_dft_matrix(size(A, axis)))
    end
    return B
end

"""Inverse (normalized) full-dimensional DFT."""
function dumb_idft(A::AbstractArray{ComplexF64})
    B = copy(A)
    for axis in 1:ndims(A)
        n = size(A, axis)
        B = dumb_axis_apply(B, axis, collect(conj.(dumb_dft_matrix(n)) ./ n))
    end
    return B
end

# ============================================================================
# Dumb field/coefficient resolution (direct struct-field reads; bypasses
# the production accessors — including zeeman_at's lossy collapse)
# ============================================================================

function dumb_zeeman_pqbxby(ws)
    z = ws.zeeman
    t = ws.state.t
    z === nothing && return (0.0, 0.0, 0.0, 0.0)
    if z isa ZeemanParams
        return (z.p, z.q, 0.0, 0.0)
    elseif z isa TimeDependentZeeman
        bx = z.bx_wf === nothing ? 0.0 : evaluate(z.bx_wf, t)
        by = z.by_wf === nothing ? 0.0 : evaluate(z.by_wf, t)
        return (evaluate(z.p_wf, t), evaluate(z.q_wf, t), bx, by)
    end
    error("dumb_zeeman_pqbxby: unsupported zeeman type $(typeof(z))")
end

function dumb_lhy_coefficient(ws)
    l = ws.lhy
    l === nothing && return ws.interactions.c_lhy
    l isa ScalarLHY && return l.c_lhy
    error(
        "dumb reference: only scalar LHY is implemented; got $(typeof(l)). " *
        "Typed-LHY kinds are a declared limitation (extend together with " *
        "their physics anchors).",
    )
end

function dumb_raman_resolved(ws)
    r = ws.raman
    r === nothing && return nothing
    t = ws.state.t
    r isa RamanCoupling && return (Omega=r.Omega_R, delta=r.delta, k_eff=r.k_eff)
    r isa TimeDependentRaman &&
        return (Omega=evaluate(r.omega_wf, t), delta=evaluate(r.delta_wf, t), k_eff=r.k_eff)
    error("dumb_raman_resolved: unsupported raman type $(typeof(r))")
end

function dumb_mg_resolved(ws)
    mg = ws.magnetic_gradient
    mg === nothing && return nothing
    g = mg isa TimeDependentMagneticGradient ? evaluate(mg.gradient_wf, ws.state.t) :
        mg.gradient
    return (gradient=g, axis=mg.axis, g_F=mg.g_F)
end

# ============================================================================
# Dumb spinor field helpers
# ============================================================================

_dumb_D(ψ) = size(ψ, ndims(ψ))
_dumb_spatial(ψ) = CartesianIndices(size(ψ)[1:(end - 1)])

function dumb_density(ψ)
    D = _dumb_D(ψ)
    n = zeros(Float64, size(ψ)[1:(end - 1)])
    for I in _dumb_spatial(ψ), c in 1:D
        n[I] += abs2(ψ[I, c])
    end
    return n
end

"""⟨ψ(x)| M |ψ(x)⟩ per voxel (real for Hermitian M)."""
function dumb_local_expectation(ψ, M::Matrix{ComplexF64})
    D = _dumb_D(ψ)
    out = zeros(Float64, size(ψ)[1:(end - 1)])
    for I in _dumb_spatial(ψ)
        s = zero(ComplexF64)
        for c in 1:D, cp in 1:D
            s += conj(ψ[I, c]) * M[c, cp] * ψ[I, cp]
        end
        out[I] = real(s)
    end
    return out
end

"""out[I,:] += w(I) · M · ψ[I,:] with per-voxel complex weight w."""
function dumb_add_matrix_action!(out, ψ, M::Matrix{ComplexF64}, w)
    D = _dumb_D(ψ)
    for I in _dumb_spatial(ψ)
        for c in 1:D
            s = zero(ComplexF64)
            for cp in 1:D
                s += M[c, cp] * ψ[I, cp]
            end
            out[I, c] += w(I) * s
        end
    end
    return out
end

"""Singlet-pair amplitude A(x) = (1/√D) Σ_c (−1)^(c−1) ψ_c ψ_(D+1−c)
(restates (−1)^(F−m) with m-ordering pinned)."""
function dumb_singlet_amplitude(ψ)
    D = _dumb_D(ψ)
    A = zeros(ComplexF64, size(ψ)[1:(end - 1)])
    for I in _dumb_spatial(ψ), c in 1:D
        A[I] += (-1)^(c - 1) * ψ[I, c] * ψ[I, D + 1 - c] / sqrt(D)
    end
    return A
end

"""−i(x∂_y − y∂_x)ψ per component — L_z action via dumb axis DFTs.
Requires ndim ≥ 2; axes 1=x, 2=y; derivative ∂_d = idft(i·k_d · dft)."""
function dumb_Lz_action(ψ, ws)
    nd = ndims(ψ) - 1
    nd >= 2 || error("dumb_Lz_action: needs ≥ 2 spatial dimensions")
    D = _dumb_D(ψ)
    nx = size(ψ, 1)
    ny = size(ψ, 2)
    kx = dumb_k_axis(nx, Float64(ws.grid.config.box_size[1]))
    ky = dumb_k_axis(ny, Float64(ws.grid.config.box_size[2]))
    xv = ws.grid.x[1]
    yv = ws.grid.x[2]
    out = zeros(ComplexF64, size(ψ))
    idx = ntuple(_ -> Colon(), nd)
    for c in 1:D
        comp = ψ[idx..., c]
        # ∂_y ψ
        ŷ = dumb_axis_apply(comp, 2, dumb_dft_matrix(ny))
        for I in CartesianIndices(ŷ)
            ŷ[I] *= im * ky[I[2]]
        end
        dy = dumb_axis_apply(ŷ, 2, collect(conj.(dumb_dft_matrix(ny)) ./ ny))
        # ∂_x ψ
        x̂ = dumb_axis_apply(comp, 1, dumb_dft_matrix(nx))
        for I in CartesianIndices(x̂)
            x̂[I] *= im * kx[I[1]]
        end
        dx = dumb_axis_apply(x̂, 1, collect(conj.(dumb_dft_matrix(nx)) ./ nx))
        for I in CartesianIndices(comp)
            out[I, c] = -im * (xv[I[1]] * dy[I] - yv[I[2]] * dx[I])
        end
    end
    return out
end

# ============================================================================
# Per-slot energies
# ============================================================================

const DUMB_DEFERRED_SLOTS = (:ddi,)

function dumb_energy_breakdown(ws, ψ::AbstractArray{<:Complex})
    nd = ndims(ψ) - 1
    D = _dumb_D(ψ)
    F = (D - 1) ÷ 2
    sm = dumb_spin_matrices(F)
    dV = prod(Float64(ws.grid.config.box_size[d]) / size(ψ, d) for d in 1:nd)
    Np = prod(size(ψ)[1:nd])
    n = dumb_density(ψ)
    idx = ntuple(_ -> Colon(), nd)

    # kinetic: (1/2)·(dV/Np)·Σ_c Σ_k k²|ψ̂|² — k recomputed from formula.
    ksq = zeros(Float64, size(ψ)[1:nd])
    kaxes = [dumb_k_axis(size(ψ, d), Float64(ws.grid.config.box_size[d])) for d in 1:nd]
    for I in CartesianIndices(ksq)
        ksq[I] = sum(kaxes[d][I[d]]^2 for d in 1:nd)
    end
    E_kin = 0.0
    for c in 1:D
        ψ̂ = dumb_dft(ψ[idx..., c])
        for I in CartesianIndices(ψ̂)
            E_kin += 0.5 * ksq[I] * abs2(ψ̂[I])
        end
    end
    E_kin *= dV / Np

    # trap: Σ V|ψ|²dV (V_trap is problem data, shared deliberately).
    E_trap = 0.0
    for I in _dumb_spatial(ψ)
        E_trap += ws.potential_values[I] * n[I]
    end
    E_trap *= dV

    # zeeman
    p, q, bx, by = dumb_zeeman_pqbxby(ws)
    E_zz = 0.0
    for c in 1:D
        coef = -p * sm.m[c] + q * sm.m[c]^2
        for I in _dumb_spatial(ψ)
            E_zz += coef * abs2(ψ[I, c])
        end
    end
    E_zz *= dV
    fx = dumb_local_expectation(ψ, sm.Fx)
    fy = dumb_local_expectation(ψ, sm.Fy)
    fz = dumb_local_expectation(ψ, sm.Fz)
    E_zt = sum(-bx .* fx .- by .* fy) * dV

    # contact + LHY
    c0 = ws.interactions[0]
    c1 = ws.interactions[1]
    E_c0 = 0.5 * c0 * sum(abs2, n) * dV
    E_c1 = 0.5 * c1 * sum(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2) * dV
    clhy = dumb_lhy_coefficient(ws)
    E_lhy = (2 / 5) * clhy * sum(x -> x^(5 / 2), n) * dV

    # tensor slot: c2 singlet part (higher channels deferred with the cache)
    c2 = get_cn(ws.interactions, 2)
    A = dumb_singlet_amplitude(ψ)
    E_singlet = 0.5 * c2 * sum(abs2, A) * dV
    ws.tensor_cache === nothing || error(
        "dumb reference: tensor_cache channels not implemented (deferred " *
        "with the DDI unit); fixture must not activate the cache.",
    )

    # raman: Σ [δ·f_z + Ω·Re(e^{ik·x} f₊)] dV with f₊ = ⟨F₊⟩ per voxel.
    rm = dumb_raman_resolved(ws)
    E_raman = 0.0
    if rm !== nothing
        for I in _dumb_spatial(ψ)
            kr = sum(rm.k_eff[d] * ws.grid.x[d][I[d]] for d in 1:nd)
            fp = zero(ComplexF64)
            for c in 1:D, cp in 1:D
                fp += conj(ψ[I, c]) * sm.Fp[c, cp] * ψ[I, cp]
            end
            fzv = sum(sm.m[c] * abs2(ψ[I, c]) for c in 1:D)
            E_raman += rm.delta * fzv + rm.Omega * real(cis(kr) * fp)
        end
        E_raman *= dV
    end

    # light shift: Σ profile·⟨U diag(λ) U†⟩ dV
    E_ls = 0.0
    if ws.light_shift !== nothing
        ls = ws.light_shift
        M = ls.U * (collect(Float64.(ls.eigvals)) .* ls.U')
        Mc = ComplexF64.(M)
        w = dumb_local_expectation(ψ, Mc)
        prof = Array(ls.profile)
        for I in _dumb_spatial(ψ)
            E_ls += prof[I] * w[I]
        end
        E_ls *= dV
    end

    # coriolis: −Ω·Re⟨ψ, L_z ψ⟩dV
    Ω = ws.sim_params.rotating_frame_omega
    E_cor = 0.0
    if Ω != 0.0 && nd >= 2
        Lψ = dumb_Lz_action(ψ, ws)
        s = zero(ComplexF64)
        for I in _dumb_spatial(ψ), c in 1:D
            s += conj(ψ[I, c]) * Lψ[I, c]
        end
        E_cor = -Ω * real(s) * dV
    end

    # magnetic gradient: spin-INDEPENDENT scalar tilt g_F·G·x_axis
    # (matches the production model — _apply_mg_to_V! adds the same
    # value to every component; physics question flagged in the arch
    # doc, the dumb side states the production model, not an opinion).
    mg = dumb_mg_resolved(ws)
    E_mg = 0.0
    if mg !== nothing
        for I in _dumb_spatial(ψ)
            E_mg += mg.g_F * mg.gradient * ws.grid.x[mg.axis][I[mg.axis]] * n[I]
        end
        E_mg *= dV
    end

    return (
        kinetic=E_kin, trap=E_trap, zeeman_z=E_zz, zeeman_transverse=E_zt,
        density_c0=E_c0, spin_c1=E_c1, ddi=NaN, lhy=E_lhy,
        tensor=E_singlet, raman=E_raman, light_shift=E_ls, coriolis=E_cor,
        magnetic_gradient=E_mg, loss=0.0,
    )
end

# ============================================================================
# Per-slot RHS (δE/δψ̄ per-voxel density)
# ============================================================================

"""
    dumb_rhs_breakdown(ws, ψ) -> NamedTuple of arrays (or nothing)

Per-slot canonical gradients. `nothing` marks the deferred DDI slot
ONLY; production KNOWN-LIMIT gaps (raman, tensor) are present HERE —
the master oracle asserts production is nil where these are not.
"""
function dumb_rhs_breakdown(ws, ψ::AbstractArray{<:Complex})
    nd = ndims(ψ) - 1
    D = _dumb_D(ψ)
    F = (D - 1) ÷ 2
    sm = dumb_spin_matrices(F)
    n = dumb_density(ψ)
    idx = ntuple(_ -> Colon(), nd)

    zed() = zeros(ComplexF64, size(ψ))

    # kinetic: idft( (k²/2)·dft ψ ) per component
    g_kin = zed()
    kaxes = [dumb_k_axis(size(ψ, d), Float64(ws.grid.config.box_size[d])) for d in 1:nd]
    for c in 1:D
        ψ̂ = dumb_dft(ψ[idx..., c])
        for I in CartesianIndices(ψ̂)
            ψ̂[I] *= 0.5 * sum(kaxes[d][I[d]]^2 for d in 1:nd)
        end
        back = dumb_idft(ψ̂)
        for I in CartesianIndices(back)
            g_kin[I, c] = back[I]
        end
    end

    g_trap = zed()
    for I in _dumb_spatial(ψ), c in 1:D
        g_trap[I, c] = ws.potential_values[I] * ψ[I, c]
    end

    p, q, bx, by = dumb_zeeman_pqbxby(ws)
    g_zz = zed()
    for c in 1:D
        coef = -p * sm.m[c] + q * sm.m[c]^2
        for I in _dumb_spatial(ψ)
            g_zz[I, c] = coef * ψ[I, c]
        end
    end
    Ht = ComplexF64.(-bx .* sm.Fx .- by .* sm.Fy)
    g_zt = zed()
    dumb_add_matrix_action!(g_zt, ψ, Ht, _ -> 1.0)

    c0 = ws.interactions[0]
    c1 = ws.interactions[1]
    g_c0 = zed()
    for I in _dumb_spatial(ψ), c in 1:D
        g_c0[I, c] = c0 * n[I] * ψ[I, c]
    end
    fx = dumb_local_expectation(ψ, sm.Fx)
    fy = dumb_local_expectation(ψ, sm.Fy)
    fz = dumb_local_expectation(ψ, sm.Fz)
    g_c1 = zed()
    for I in _dumb_spatial(ψ)
        H = c1 .* (fx[I] .* sm.Fx .+ fy[I] .* sm.Fy .+ fz[I] .* sm.Fz)
        for c in 1:D
            s = zero(ComplexF64)
            for cp in 1:D
                s += H[c, cp] * ψ[I, cp]
            end
            g_c1[I, c] = s
        end
    end

    clhy = dumb_lhy_coefficient(ws)
    g_lhy = zed()
    for I in _dumb_spatial(ψ), c in 1:D
        g_lhy[I, c] = clhy * n[I]^(3 / 2) * ψ[I, c]
    end

    # tensor slot: c2 singlet RHS — conjugate-linear (pairing):
    # δE/δψ̄_μ = (c2/√D)·A(x)·(−1)^(μ−1)·conj(ψ_(D+1−μ))
    c2 = get_cn(ws.interactions, 2)
    g_singlet = zed()
    if c2 != 0.0
        A = dumb_singlet_amplitude(ψ)
        for I in _dumb_spatial(ψ), c in 1:D
            g_singlet[I, c] =
                (c2 / sqrt(D)) * A[I] * (-1)^(c - 1) * conj(ψ[I, D + 1 - c])
        end
    end

    # raman: δ·F_z ψ + (Ω/2)(e^{ik·x}F₊ + e^{−ik·x}F₋)ψ
    rm = dumb_raman_resolved(ws)
    g_raman = zed()
    if rm !== nothing
        for I in _dumb_spatial(ψ)
            kr = sum(rm.k_eff[d] * ws.grid.x[d][I[d]] for d in 1:nd)
            ph = cis(kr)
            for c in 1:D
                s = rm.delta * sm.m[c] * ψ[I, c]
                for cp in 1:D
                    s += (rm.Omega / 2) *
                         (ph * sm.Fp[c, cp] + conj(ph) * sm.Fm[c, cp]) * ψ[I, cp]
                end
                g_raman[I, c] = s
            end
        end
    end

    g_ls = zed()
    if ws.light_shift !== nothing
        ls = ws.light_shift
        Mc = ComplexF64.(ls.U * (collect(Float64.(ls.eigvals)) .* ls.U'))
        prof = Array(ls.profile)
        dumb_add_matrix_action!(g_ls, ψ, Mc, I -> prof[I])
    end

    Ω = ws.sim_params.rotating_frame_omega
    g_cor = zed()
    if Ω != 0.0 && nd >= 2
        Lψ = dumb_Lz_action(ψ, ws)
        for I in _dumb_spatial(ψ), c in 1:D
            g_cor[I, c] = -Ω * Lψ[I, c]
        end
    end

    mg = dumb_mg_resolved(ws)
    g_mg = zed()
    if mg !== nothing
        for I in _dumb_spatial(ψ), c in 1:D
            g_mg[I, c] =
                mg.g_F * mg.gradient * ws.grid.x[mg.axis][I[mg.axis]] * ψ[I, c]
        end
    end

    return (
        kinetic=g_kin, trap=g_trap, zeeman_z=g_zz, zeeman_transverse=g_zt,
        density_c0=g_c0, spin_c1=g_c1, ddi=nothing, lhy=g_lhy,
        tensor=g_singlet, raman=g_raman, light_shift=g_ls, coriolis=g_cor,
        magnetic_gradient=g_mg, loss=zed(),
    )
end

# ============================================================================
# Total RHS + dumb RK4 time integration (reference trajectories)
# ============================================================================

"""
    dumb_rhs_total(ws, ψ) -> Array

Sum of all implemented per-slot canonical gradients — the full
H_eff[ψ]·ψ of the dumb statement. Errors if a deferred slot is active
(DDI): a reference that silently omits an active term is the
rotted-reference failure mode, not a reference.
"""
function dumb_rhs_total(ws, ψ::AbstractArray{<:Complex})
    ws.ddi === nothing || error(
        "dumb_rhs_total: DDI is active but the dumb DDI statement is " *
        "deferred (own unit). Use a DDI-free fixture.",
    )
    G = dumb_rhs_breakdown(ws, ψ)
    total = zeros(ComplexF64, size(ψ))
    for slot in keys(G)
        g = G[slot]
        g === nothing && continue
        total .+= g
    end
    return total
end

"""
    dumb_rk4_evolve(ws, ψ0, T, nsteps) -> Array

Classical RK4 on the full nonlinear dumb RHS, `dψ/dt = −i·G(ψ)` (real
time, autonomous fields — time-dependent waveforms are evaluated at
the frozen ws.state.t). Global error O(dt⁴): at tiny grids and small T
this is the reference trajectory the split-step order test (slope ≈ 2
for Strang) is measured against.
"""
function dumb_rk4_evolve(ws, ψ0::AbstractArray{<:Complex}, T::Float64, nsteps::Int)
    dt = T / nsteps
    ψ = ComplexF64.(copy(ψ0))
    f(ϕ) = -im .* dumb_rhs_total(ws, ϕ)
    for _ in 1:nsteps
        k1 = f(ψ)
        k2 = f(ψ .+ (dt / 2) .* k1)
        k3 = f(ψ .+ (dt / 2) .* k2)
        k4 = f(ψ .+ dt .* k3)
        ψ .+= (dt / 6) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
    end
    return ψ
end
