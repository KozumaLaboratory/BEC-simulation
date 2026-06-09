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
# - implemented: ALL 14 — kinetic, trap, zeeman_z, zeeman_transverse,
#   density_c0, spin_c1, ddi (periodic, full + secular kernels), lhy
#   (scalar), tensor (c2 singlet part), raman, light_shift, coriolis,
#   magnetic_gradient, loss (≡ 0).
# - DDI model declaration: the secular flag is NOT read back from the
#   baked ws.ddi.Q arrays — those are exactly what is under test. The
#   caller passes `ddi_secular::Bool` explicitly (it is part of the
#   model declaration, like θ), and the dumb side rebuilds Q from the
#   formula: Q_αβ = k̂_αk̂_β − δ_αβ/3, Q(0) = 0, secular ⇒
#   Q = diag(−q/2, −q/2, q) with q = k̂_z² − 1/3 (CLAUDE.md pinned
#   conventions: c_dd = μ₀μ², no 4π, no 1/(4π)).
#   The PADDED (non-periodic) DDI variant is a follow-up sub-unit
#   (App. A defect 9 verdict lives there).
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
    p, q, bx, by = if z === nothing
        (0.0, 0.0, 0.0, 0.0)
    elseif z isa ZeemanParams
        (z.p, z.q, 0.0, 0.0)
    elseif z isa TimeDependentZeeman
        (
            evaluate(z.p_wf, t), evaluate(z.q_wf, t),
            z.bx_wf === nothing ? 0.0 : evaluate(z.bx_wf, t),
            z.by_wf === nothing ? 0.0 : evaluate(z.by_wf, t),
        )
    else
        error("dumb_zeeman_pqbxby: unsupported zeeman type $(typeof(z))")
    end
    # Spin-rotating-frame model (declaration, restated independently):
    # the production frame is H_RF with p → p − ω_R and (bx, by)
    # rotated by −ω_R·t into RF coordinates. Same model, own
    # expression — the master oracle then checks the production
    # registry implements it identically (gates defect 5).
    ω_R = ws.sim_params.spin_rotating_frame_omega
    p -= ω_R
    if ω_R != 0.0
        cR = cos(ω_R * t)
        sR = sin(ω_R * t)
        bx, by = bx * cR + by * sR, -bx * sR + by * cR
    end
    return (p, q, bx, by)
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
# Dumb DDI (periodic): Q from the formula + dense-DFT convolution
# ============================================================================

"""Kernel wavenumbers for the rfft-halved axis: like `dumb_k_axis` but
the even-n Nyquist representative is **+n/2·dk**, matching production's
`rfftfreq` on axis 1. The diagonal Q is even, so this representative is
sign-independent there; the odd off-diagonals are zeroed on the Nyquist
planes by `_dumb_ddi_kernel` (see the note there and the matching
production zeroing in `_build_q_tensor!`), which is what removes the
former O(1) x↔y asymmetry on broadband states."""
function dumb_k_axis_rfft(n::Int, L::Float64)
    dk = 2π / L
    return [dk * (j0 <= n ÷ 2 ? j0 : j0 - n) for j0 in 0:(n - 1)]
end

"""
    dumb_ddi_potential(ws, fx, fy, fz, nd; secular) -> (Φx, Φy, Φz)

`Φ_α = c_dd · IDFT[ Q_αβ(k) · DFT(f_β) ]` with Q restated from the
pinned convention (NOT read from ws.ddi.Q — the baked arrays are what
the master oracle tests). Missing axes (nd < 3) have k-component 0,
matching the production builder; axis 1 uses the rfft Nyquist
representative (see `dumb_k_axis_rfft`).
"""
function dumb_ddi_potential(ws, fx, fy, fz, nd; secular::Bool)
    boxes = ntuple(d -> Float64(ws.grid.config.box_size[d]), nd)
    return _dumb_ddi_kernel(ws.ddi.C_dd, fx, fy, fz, nd, boxes; secular)
end

"""
    dumb_ddi_potential_padded(ws, fx, fy, fz, nd; secular) -> (Φx, Φy, Φz)

Zero-padded variant: pad the spin density into the 2×-per-dim grid,
run the SAME kernel statement on the doubled box (production's padded
axes are `rfftfreq(2n, 2π/dx)` — sample spacing dk/2, i.e. the 2L
box), and crop the [1:n, …] corner back. Independent statement of
`_compute_and_convolve_ddi_padded!` + the crop the rotation step is
supposed to read (App. A defect 9).
"""
function dumb_ddi_potential_padded(ws, fx, fy, fz, nd; secular::Bool)
    sizes = size(fx)
    pads = ntuple(d -> 2 * sizes[d], nd)
    crop = CartesianIndices(sizes)
    fxp = zeros(Float64, pads)
    fyp = zeros(Float64, pads)
    fzp = zeros(Float64, pads)
    fxp[crop] .= fx
    fyp[crop] .= fy
    fzp[crop] .= fz
    boxes = ntuple(d -> 2.0 * Float64(ws.grid.config.box_size[d]), nd)
    Φx, Φy, Φz = _dumb_ddi_kernel(ws.ddi.C_dd, fxp, fyp, fzp, nd, boxes; secular)
    return (Φx[crop], Φy[crop], Φz[crop])
end

"""
    dumb_rhs_ddi_padded(ws, ψ; secular) -> Array

DDI slot of the canonical RHS with the ZERO-PADDED convolution — the
variational counterpart of the padded propagator step
(`apply_ddi_step!` with a `DDIPaddedContext`). No production
energy/gradient face uses the padded kernel (registry DDI is
unpadded), so this exists purely as the dt-valley reference for the
padded step.
"""
function dumb_rhs_ddi_padded(ws, ψ::AbstractArray{<:Complex}; secular::Bool)
    D = _dumb_D(ψ)
    nd = ndims(ψ) - 1
    sm = dumb_spin_matrices((D - 1) ÷ 2)
    fx = dumb_local_expectation(ψ, sm.Fx)
    fy = dumb_local_expectation(ψ, sm.Fy)
    fz = dumb_local_expectation(ψ, sm.Fz)
    Φx, Φy, Φz = dumb_ddi_potential_padded(ws, fx, fy, fz, nd; secular)
    g = zeros(ComplexF64, size(ψ))
    for I in _dumb_spatial(ψ)
        H = Φx[I] .* sm.Fx .+ Φy[I] .* sm.Fy .+ Φz[I] .* sm.Fz
        for c in 1:D
            s = zero(ComplexF64)
            for cp in 1:D
                s += H[c, cp] * ψ[I, cp]
            end
            g[I, c] = s
        end
    end
    return g
end

function _dumb_ddi_kernel(c_dd, fx, fy, fz, nd, boxes; secular::Bool)
    sizes = size(fx)
    kaxes = [
        if d == 1
            dumb_k_axis_rfft(sizes[d], boxes[d])
        else
            dumb_k_axis(sizes[d], boxes[d])
        end for d in 1:nd
    ]
    # The production convolution runs on the rfft HALF-grid (kx ≥ 0
    # stored; the kx < 0 half is implied by Hermitian symmetry). Its
    # effective full-grid kernel is therefore Q∘rep — Q evaluated at
    # the STORED REPRESENTATIVE of each mode. rep is the identity on
    # the stored half; on the kx < 0 half it is the index mirror
    # j → (j == 1 ? 1 : n + 2 − j) on every axis. For the DIAGONAL Q
    # (even in every axis) the mirror is invisible. The OFF-DIAGONALS
    # are odd in two axes: at a Nyquist mode (its own mirror; −n/2·dk
    # does not flip) the continuum kernel of an odd function is 0, and
    # the raw representative would be axis-asymmetric (rfft stores
    # +k_Nyq on axis 1, fft stores −k_Nyq on the others). Production
    # therefore zeros each off-diagonal on its odd axes' Nyquist planes
    # to keep the kernel x↔y(↔z) symmetric; this dumb statement does the
    # same below. Physically negligible on resolved states (Nyquist
    # power → 0) but order-unity on broadband fields. The secular kernel
    # is even in every axis separately — Nyquist-immune, no rep needed.
    mirror(j, n) = j == 1 ? 1 : n + 2 - j
    # Nyquist index per axis (its own mirror; -1 = no Nyquist for odd n).
    nyqidx = ntuple(d -> iseven(sizes[d]) ? sizes[d] ÷ 2 + 1 : -1, nd)
    f̂ = (dumb_dft(ComplexF64.(fx)), dumb_dft(ComplexF64.(fy)), dumb_dft(ComplexF64.(fz)))
    Φ̂ = (zeros(ComplexF64, sizes), zeros(ComplexF64, sizes), zeros(ComplexF64, sizes))
    for I in CartesianIndices(sizes)
        kx = kaxes[1][I[1]]
        ky = nd >= 2 ? kaxes[2][I[2]] : 0.0
        kz = nd >= 3 ? kaxes[3][I[3]] : 0.0
        if kx < 0.0   # not stored: evaluate Q at the rfft representative
            kx = -kx  # interior mirror on the rfft axis
            ky = nd >= 2 ? kaxes[2][mirror(I[2], sizes[2])] : 0.0
            kz = nd >= 3 ? kaxes[3][mirror(I[3], sizes[3])] : 0.0
        end
        k2 = kx^2 + ky^2 + kz^2
        k2 == 0.0 && continue   # Q(0) = 0 (pinned convention)
        # Nyquist flag per axis (index is mirror-invariant, so test I, not k).
        nyqf = ntuple(d -> I[d] == nyqidx[d], nd)
        on_nyq(a) = a <= nd && nyqf[a]
        if secular
            q = kz^2 / k2 - 1 / 3
            Φ̂[1][I] = -q / 2 * f̂[1][I]
            Φ̂[2][I] = -q / 2 * f̂[2][I]
            Φ̂[3][I] = q * f̂[3][I]
        else
            kv = (kx, ky, kz)
            for α in 1:3, β in 1:3
                # Off-diagonals are odd in axes α and β; their folded-Nyquist
                # continuum value is 0. Zero them on either axis's Nyquist
                # plane so the kernel stays x↔y(↔z) symmetric (matches
                # production `_build_q_tensor!`).
                if α != β && (on_nyq(α) || on_nyq(β))
                    continue
                end
                Q = kv[α] * kv[β] / k2 - (α == β ? 1 / 3 : 0.0)
                Φ̂[α][I] += Q * f̂[β][I]
            end
        end
    end
    return (
        c_dd .* real.(dumb_idft(Φ̂[1])),
        c_dd .* real.(dumb_idft(Φ̂[2])),
        c_dd .* real.(dumb_idft(Φ̂[3])),
    )
end

_require_ddi_flag(ws, ddi_secular) =
    ws.ddi !== nothing && ddi_secular === nothing &&
    error(
        "dumb reference: ws has active DDI — pass ddi_secular::Bool " *
        "explicitly (the secular flag is model declaration; reading it " *
        "back from the baked Q arrays would erase the independence of " *
        "the kernel construction).",
    )

# ============================================================================
# Per-slot energies
# ============================================================================

const DUMB_DEFERRED_SLOTS = ()

function dumb_energy_breakdown(
    ws, ψ::AbstractArray{<:Complex}; ddi_secular::Union{Nothing, Bool}=nothing
)
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

    # ddi: E = ½ Σ_α ∫ Φ_α f_α dV (c_dd inside Φ; mean-field d = 4)
    _require_ddi_flag(ws, ddi_secular)
    E_ddi = 0.0
    if ws.ddi !== nothing
        Φx, Φy, Φz = dumb_ddi_potential(ws, fx, fy, fz, nd; secular=ddi_secular)
        for I in _dumb_spatial(ψ)
            E_ddi += Φx[I] * fx[I] + Φy[I] * fy[I] + Φz[I] * fz[I]
        end
        E_ddi *= 0.5 * dV
    end

    # tensor slot: c2 singlet part (higher channels not implemented)
    c2 = get_cn(ws.interactions, 2)
    A = dumb_singlet_amplitude(ψ)
    E_singlet = 0.5 * c2 * sum(abs2, A) * dV
    ws.tensor_cache === nothing || error(
        "dumb reference: tensor_cache channels not implemented; " *
        "fixture must not activate the cache.",
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
        density_c0=E_c0, spin_c1=E_c1, ddi=E_ddi, lhy=E_lhy,
        tensor=E_singlet, raman=E_raman, light_shift=E_ls, coriolis=E_cor,
        magnetic_gradient=E_mg, loss=0.0,
    )
end

# ============================================================================
# Per-slot RHS (δE/δψ̄ per-voxel density)
# ============================================================================

"""
    dumb_rhs_breakdown(ws, ψ; ddi_secular=nothing) -> NamedTuple of arrays

Per-slot canonical gradients. Production KNOWN-LIMIT gaps (raman,
tensor) are present HERE — the master oracle asserts production is nil
where these are not. `ddi_secular` is required when ws has active DDI
(model declaration, see `dumb_ddi_potential`).
"""
function dumb_rhs_breakdown(
    ws, ψ::AbstractArray{<:Complex}; ddi_secular::Union{Nothing, Bool}=nothing
)
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

    # ddi: g = Σ_α Φ_α · (F_α ψ) per voxel
    _require_ddi_flag(ws, ddi_secular)
    g_ddi = zed()
    if ws.ddi !== nothing
        Φx, Φy, Φz = dumb_ddi_potential(ws, fx, fy, fz, nd; secular=ddi_secular)
        for I in _dumb_spatial(ψ)
            H = Φx[I] .* sm.Fx .+ Φy[I] .* sm.Fy .+ Φz[I] .* sm.Fz
            for c in 1:D
                s = zero(ComplexF64)
                for cp in 1:D
                    s += H[c, cp] * ψ[I, cp]
                end
                g_ddi[I, c] = s
            end
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
        density_c0=g_c0, spin_c1=g_c1, ddi=g_ddi, lhy=g_lhy,
        tensor=g_singlet, raman=g_raman, light_shift=g_ls, coriolis=g_cor,
        magnetic_gradient=g_mg, loss=zed(),
    )
end

# ============================================================================
# Total RHS + dumb RK4 time integration (reference trajectories)
# ============================================================================

"""
    dumb_rhs_total(ws, ψ; ddi_secular=nothing) -> Array

Sum of all per-slot canonical gradients — the full H_eff[ψ]·ψ of the
dumb statement.
"""
function dumb_rhs_total(
    ws, ψ::AbstractArray{<:Complex}; ddi_secular::Union{Nothing, Bool}=nothing
)
    G = dumb_rhs_breakdown(ws, ψ; ddi_secular)
    total = zeros(ComplexF64, size(ψ))
    for slot in keys(G)
        total .+= G[slot]
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
function dumb_rk4_evolve(
    ws, ψ0::AbstractArray{<:Complex}, T::Float64, nsteps::Int;
    ddi_secular::Union{Nothing, Bool}=nothing,
)
    dt = T / nsteps
    ψ = ComplexF64.(copy(ψ0))
    f(ϕ) = -im .* dumb_rhs_total(ws, ϕ; ddi_secular)
    for _ in 1:nsteps
        k1 = f(ψ)
        k2 = f(ψ .+ (dt / 2) .* k1)
        k3 = f(ψ .+ (dt / 2) .* k2)
        k4 = f(ψ .+ dt .* k3)
        ψ .+= (dt / 6) .* (k1 .+ 2 .* k2 .+ 2 .* k3 .+ k4)
    end
    return ψ
end
