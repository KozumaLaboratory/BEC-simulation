# Excitation FREQUENCIES of a trapped spinor condensate — the ω axis, at
# 13 components in 3D.
#
# WHY THIS FILE EXISTS. Before it, three BdG paths existed and none could
# produce the excitation spectrum of a trapped 13-component texture:
#   `bogoliubov_spectrum`        — uniform spinor only, no spatial dependence;
#   `trapped_bdg_spectrum`       — dense, `dim_cap=4000` ≪ 2·32³·13 = 851,968;
#   `trapped_bdg_low_modes`      — the ONLY 3D/D=13 path, but it returns the
#                                  lowest eigenvalues of the constrained
#                                  HESSIAN, which are not frequencies.
#
# λ IS NOT ω, and this is the whole reason the third path did not already
# answer the question. `energy_gradient!` is `2·δE/δψ̄`, so the gated
# `hessian_vector_product` is `Hδ = 2(L_op δ + M_op δ̄)` and the constrained
# operator is `A = P(H−2μ)P`. For a REAL background the two sectors decouple:
# A acts as `A₊ = 2(L−μ+M)` on real δ (density-like, STIFF) and as
# `A₋ = 2(L−μ−M)` on imaginary δ (phase-like, SOFT). In the uniform scalar
# limit `A₊ = 2(ε_k + 2gn)` and `A₋ = 2ε_k`, while the Bogoliubov frequency is
# `ω = √(ε_k(ε_k+2gn)) = √(λ₊λ₋)/2`. So the Hessian's own low eigenvalues are
# `2ε_k ∝ k²` where the frequency is `ω ∝ k` — the two disagree in their
# LEADING POWER, not by a factor. Reading `trapped_bdg_low_modes`' λ as a
# spectrum would have reported a phonon branch that is quadratic at small k.
#
# WHAT THIS DOES INSTEAD. The linearised GP in the frame of `ψe^{−iμt}` is
# `i ∂_t δ = ½ A δ`, i.e. `∂_t δ = J(½A)δ` with `J δ = −iδ`. `J` is
# antisymmetric under the Hessian's own real inner product `⟨a,b⟩_R = Re∫ā b`
# and `A` is symmetric, so this is a real Hamiltonian system whose eigenvalues
# come in `±iω` pairs. Two facts make it cheap:
#
#   1. `J` is multiplication by `−i`, so ANY complex-linear span is
#      J-invariant. The complexification `span_R{X_k, iX_k}` of the Hessian's
#      soft eigenvectors therefore carries the symplectic structure exactly.
#   2. A soft mode's stiff partner is (to leading order) `i ×` itself — in the
#      uniform limit exactly so, since the phase mode `i·e^{ikx}ζ` and the
#      density mode `e^{ikx}ζ` differ by `i`. So the complexification supplies
#      the `λ₊ ≈ 4c₀n` partner WITHOUT the eigensolver ever having to climb to
#      `λ ≈ 4c₀n`, which at Eu production (`c₀n ≈ 2343`) it cannot.
#
# The reduction is therefore: solve for `n` soft Hessian modes (the existing
# preconditioned LOBPCG), complexify, orthonormalise, and diagonalise the
# `m×m` real generator `M_ij = ½⟨Sᵢ, J A Sⱼ⟩_R = ½ Im ∫ S̄ᵢ (A Sⱼ)`. Its
# eigenvalues are `γ ± iω`: `ω` is the frequency, `γ` the DYNAMICAL growth rate.
# Cost above the Hessian solve: `m ≤ 2n` extra operator applications.
#
# WHAT IS AND IS NOT CERTIFIED. The Hessian side keeps its per-mode Kato–Temple
# two-sided bounds. The symplectic reduction has NO such bound: what is
# reported per mode is a FULL-SPACE residual of the mode equation, which is a
# necessary condition, not an interval. `j_min` reports whether the subspace
# really is J-closed (it is not if MGS dropped a direction) and
# `pair_residual` whether the `λ ↦ −λ` symmetry survived — both are
# necessary-but-not-sufficient, exactly like `quartet_residual` on the dense
# path. Say "residual", not "error bar", when quoting these.

export trapped_bdg_frequencies, bdg_symmetry_generators, bdg_expected_zero_modes

# The complex inner product WITH the cell volume. Its real part is the
# Hessian's ⟨,⟩_R and its imaginary part is the symplectic form ⟨a, Jb⟩_R —
# one reduction pass buys both, so the generator costs no extra operator
# applications. `dot` rather than `sum(conj.(a) .* b)`: the reduction is m²
# inner products over fields that are 6.8 MB each at 32³ × 13, and the
# broadcast form would push a temporary of that size through the GC every time.
_ipC(a, b, dV) = dot(a, b) * dV

# Apply a D×D spin matrix to every voxel's spinor. Cold path (called once per
# generator), so clarity over allocation.
function _apply_spin_matrix(Mat, ψ, ndim::Int, n_pts, D::Int)
    out = zero(ψ)
    for c in 1:D, c2 in 1:D
        w = Mat[c, c2]
        abs(w) < COUPLING_TOL && continue
        view(out, _component_slice(ndim, n_pts, c)...) .+=
            w .* view(ψ, _component_slice(ndim, n_pts, c2)...)
    end
    out
end

# Periodic central difference along axis `d`. Periodic is right for the box
# fixtures; for a trapped cloud the wrap lands on the vacuum tail.
function _central_diff(ψ, d::Int, dx::Real)
    (
        circshift(ψ, ntuple(i -> i == d ? -1 : 0, ndims(ψ))) .-
        circshift(ψ, ntuple(i -> i == d ? 1 : 0, ndims(ψ)))
    ) ./ (2dx)
end

# (x ∂_y − y ∂_x)ψ — the generator of rotation about z.
#
# The coordinate arrays are moved to ψ's device. `grid.x` is a host Vector even
# for a GPU workspace, and broadcasting it against a CuArray does not fall back
# to the CPU — it fails to compile the kernel ("passing non-bitstype argument"),
# which is how a 32³ × 13 Eu cell on an H100 found this on the instrument's first
# real GPU use. Everything else here was already device-agnostic (`circshift`,
# scalar × array), so this one line was the whole gap.
function _lz_action(ψ, grid, ndim::Int, backend)
    shp(d) = ntuple(i -> i == d ? length(grid.x[d]) : 1, ndims(ψ))
    xa = _to_device(backend, reshape(collect(grid.x[1]), shp(1)))
    ya = _to_device(backend, reshape(collect(grid.x[2]), shp(2)))
    xa .* _central_diff(ψ, 2, grid.dx[2]) .- ya .* _central_diff(ψ, 1, grid.dx[1])
end

"""
    bdg_symmetry_generators(ws, ψ) → Vector{Pair{Symbol, array}}

Tangent directions generated by the symmetries a spinor condensate can break:
the U(1) gauge `iψ`, the three spin rotations `iF_αψ`, one translation per
spatial axis `∂_dψ`, and (in 2D/3D) the rotation `(x∂_y−y∂_x)ψ`. These are the
directions a ZERO frequency is allowed to sit in — naming which one a `ω ≈ 0`
mode occupies is the difference between "physical Goldstone of a broken
symmetry" and "the solver returned a numerical null vector".

Not projected here: `trapped_bdg_frequencies` projects them into the same
tangent space it works in, so the gauge generator comes back with overlap ≈ 0
(it is DEFLATED by the constrained Hessian's own projection `P`, which removes
`ψ` and `iψ` together) — that near-zero is the evidence the deflation happened,
not a bug.
"""
function bdg_symmetry_generators(ws, ψ)
    ndim = ndims(ws.grid.k_squared)
    n_pts = ntuple(d -> size(ψ, d), ndim)
    sm = ws.spin_matrices
    D = sm.system.n_components
    gens = Pair{Symbol, typeof(ψ)}[:gauge => im .* ψ]
    for (name, Fmat) in ((:spin_x, sm.Fx), (:spin_y, sm.Fy), (:spin_z, sm.Fz))
        push!(gens, name => im .* _apply_spin_matrix(Fmat, ψ, ndim, n_pts, D))
    end
    for d in 1:ndim
        push!(gens, Symbol(:translation_, d) => _central_diff(ψ, d, ws.grid.dx[d]))
    end
    ndim >= 2 && push!(gens, :rotation_z => _lz_action(ψ, ws.grid, ndim, ws.backend))
    gens
end

# Real-linear rank of a set of complex fields under ⟨a,b⟩_R = Re∫ā b.
function _real_span_rank(vs, ipR; tol::Float64=1e-8)
    isempty(vs) && return 0
    ns = [sqrt(max(ipR(v, v), 0.0)) for v in vs]
    keep = findall(>(UNDERFLOW_FLOOR), ns)
    isempty(keep) && return 0
    us = [vs[i] ./ ns[i] for i in keep]
    G = [ipR(us[i], us[j]) for i in eachindex(us), j in eachindex(us)]
    count(>(tol), eigvals(Symmetric(G)))
end

"""
    bdg_expected_zero_modes(ws, ψ; params, ε, order, flat_rel, rank_tol, rng)
        → NamedTuple

How many `ω ≈ 0` modes `trapped_bdg_frequencies` SHOULD return at `ψ`, derived
from the broken symmetries alone. Compare it with the number it DOES return:
an EXCESS is a flat direction no symmetry accounts for — an accidental
degeneracy, which is the thing order-by-disorder needs before fluctuations can
select within it.

**The count is over COMPLEX planes, not over broken generators, and the
difference is not bookkeeping.** The reduction complexifies its subspace
(`span_R{X, iX}`) and emits one frequency per plane, so

    predicted = dim_R span_R({g_a} ∪ {i g_a}) / 2

For a magnetised state `i·(iF_xψ) = iF_yψ`: the two broken spin rotations are
the SAME complex plane and give ONE zero mode — the quadratic (type-B) magnon.
For polar `⟨F⟩ = 0`, the planes are independent and there are two linear
(type-A) magnons. That is the Nambu–Goldstone count `n_A + n_B` with
`n_broken = n_A + 2n_B`, written in this instrument's own coordinates, and both
routes are returned so they can be compared rather than trusted: `n_B` is
computed from the symplectic Gram `ρ_ab = Im⟨g_a, g_b⟩` — a different matrix —
and `consistent` is `predicted == n_A + n_B`. Counting generators instead of
planes reports 2 for every magnetised state and then reads the correct
`dim(null) = 1` as the solver dropping a Goldstone.

**Which generators are broken is MEASURED, not assumed.** `bdg_symmetry_generators`
returns what a spinor condensate CAN break; which of those commute with this
Hamiltonian is a property of the Hamiltonian. Rather than assert a list, each
projected generator is pushed through the constrained Hessian and kept only if
`‖A ĝ‖` is negligible against a random direction's — so a trapped cloud's
translations come back stiff (measured 2.07 against a control of 57) without
anyone having to remember that a trap breaks translation invariance. The
threshold is relative to that control because the FD Hessian's own noise floor
scales with the operator.

Returns `predicted`, `flat` (the generator names kept), `n_broken`
(= `rank_R` of them, so a repeated direction cannot inflate the count), `n_A`,
`n_B`, `consistent`, `residuals` (per generator `(name, ‖g‖, ‖Aĝ‖)` for every
generator, kept or not), and `control`.

REQUIRES a stationary `ψ`, for the same reason the frequencies do: the whole
construction is a statement about `∇E = 2μψ`. And `ψ` may not alias
`ws.state.psi` — `hessian_vector_product` refuses that, see its docstring.
"""
function bdg_expected_zero_modes(
    ws, ψ; params=nothing, ε::Float64=1e-5, order::Int=2,
    flat_rel::Float64=1e-4, rank_tol::Float64=1e-8, rng=Random.default_rng(),
)
    p = params === nothing ? constrained_hessian_params(ws, ψ) : params
    ipR(a, b) = real(_ipC(a, b, p.dV))
    A(v) = constrained_hessian_action(ws, ψ, v; p.μ, p.dV, p.n2, ε, order)

    vr = _tangent_project(
        _to_device(ws.backend, randn(rng, ComplexF64, size(ψ))), ψ, p.dV, p.n2)
    nr = sqrt(max(ipR(vr, vr), 0.0))
    vr = vr ./ max(nr, UNDERFLOW_FLOOR)
    Avr = A(vr)
    control = sqrt(max(ipR(Avr, Avr), 0.0))

    flat = Symbol[]
    nulls = typeof(ψ)[]
    residuals = Tuple{Symbol, Float64, Float64}[]
    for (name, graw) in bdg_symmetry_generators(ws, ψ)
        g = _tangent_project(graw, ψ, p.dV, p.n2)
        ng = sqrt(max(ipR(g, g), 0.0))
        # A generator the projection annihilates (gauge) or that leaves the
        # state where it is (`F_z` on a polar state) is not a broken symmetry
        # and contributes no mode. Reported with ‖Aĝ‖ = 0 rather than dropped.
        if ng <= UNDERFLOW_FLOOR
            push!(residuals, (name, ng, 0.0))
            continue
        end
        ĝ = g ./ ng
        Aĝ = A(ĝ)
        an = sqrt(max(ipR(Aĝ, Aĝ), 0.0))
        push!(residuals, (name, ng, an))
        if an < flat_rel * max(control, UNDERFLOW_FLOOR)
            push!(flat, name)
            push!(nulls, ĝ)
        end
    end

    predicted =
        _real_span_rank(vcat(nulls, [im .* v for v in nulls]), ipR; tol=rank_tol) ÷ 2
    n_broken = _real_span_rank(nulls, ipR; tol=rank_tol)
    n_B = if isempty(nulls)
        0
    else
        ρ = [imag(_ipC(nulls[i], nulls[j], p.dV))
            for i in eachindex(nulls), j in eachindex(nulls)]
        # ρ is real antisymmetric: iρ is Hermitian and its nonzero eigenvalues
        # come in ± pairs, so rank(ρ)/2 counts the conjugate pairs.
        count(>(rank_tol), abs.(eigvals(im .* ρ))) ÷ 2
    end
    n_A = n_broken - 2n_B

    (; predicted, flat, n_broken, n_A, n_B, consistent=(predicted == n_A + n_B),
        residuals, control, mu=p.μ)
end

# Overlap of a direction `g` with the subspace `vecs` spans: 0 = orthogonal,
# 1 = g lies inside it. Orthonormalising first matters — the mode planes are
# generally NOT orthogonal, and summing raw normalised projections can exceed 1
# and rank a barely-present generator above the one that dominates.
function _subspace_overlap(g, vecs, ipR)
    ng = sqrt(max(ipR(g, g), 0.0))
    ng < COUPLING_TOL && return 0.0
    ĝ = g ./ ng
    basis = _mgs_ortho(vecs, ipR)
    isempty(basis) && return 0.0
    min(1.0, sqrt(sum(e -> ipR(ĝ, e)^2, basis)))
end

# Per-mode symmetry labels, computed on DEGENERATE BLOCKS rather than on single
# modes. Inside a degenerate multiplet an eigenvector is only defined up to a
# rotation among its partners, so a per-mode overlap there is an artefact of
# whatever basis LAPACK happened to return: the F=1 polar spin Goldstone is a
# 4-dimensional zero block (two broken generators × their symplectic partners)
# and its individual planes can mix `iF_xψ` with the conjugate direction of
# `iF_yψ`, which reads as "no generator claims this mode" while the BLOCK is
# entirely spin rotation. Overlaps are therefore taken against the union of the
# block's planes and shared by every mode in it; `blocks[k]` says which modes
# were grouped, so a label is never read as more resolved than it is.
function _label_modes(omega, planes, gens_proj, ipR;
    omega_zero_tol::Float64, label_tol::Float64)
    n = length(omega)
    blocks = zeros(Int, n)
    nb = 0
    for k in 1:n
        if k == 1 || abs(omega[k] - omega[k - 1]) >
                     max(omega_zero_tol, 1e-3 * abs(omega[k]))
            nb += 1
        end
        blocks[k] = nb
    end

    ng = length(gens_proj)
    overlaps = zeros(Float64, n, ng)
    labels = Vector{Symbol}(undef, n)
    for bi in 1:nb
        rows = findall(==(bi), blocks)
        vecs = reduce(vcat, ([a, b] for (a, b) in view(planes, rows)))
        row = [_subspace_overlap(g, vecs, ipR) for (_, g) in gens_proj]
        best = argmax(row)
        named = row[best] >= label_tol
        lab = if omega[rows[1]] < omega_zero_tol
            named ? Symbol(:zero_mode_, gens_proj[best][1]) : :zero_mode_unidentified
        else
            named ? gens_proj[best][1] : :excitation
        end
        for r in rows
            overlaps[r, :] .= row
            labels[r] = lab
        end
    end
    blocks, overlaps, labels
end

"""
    trapped_bdg_frequencies(ws, ψ; nev=6, …) → NamedTuple

Lowest `nev` excitation FREQUENCIES `ω` of a trapped spinor condensate at a
stationary `ψ`, via the complexified symplectic reduction of the constrained
second variation (see the file header for the derivation and for why the
Hessian eigenvalues `λ` are a different object). Works at any `F` and any
dimension the Hessian works at — 13 components in 3D included, which neither
the uniform `bogoliubov_spectrum` nor the dense `trapped_bdg_spectrum` reaches.

Returns:
- `omega` — the `nev` smallest frequencies, ascending (internal units, `ω_ref`).
- `growth` — `Re λ` of the reduced generator per mode: the DYNAMICAL growth
  rate. Nonzero ⇒ the mode grows exponentially. This is the same axis
  `trapped_bdg_spectrum` reports as `max_growth`, and the ORTHOGONAL axis to
  the Hessian's energetic `λ_min` sign. Quote which one you mean.
- `residuals` — per-mode residual of the full-space mode equation
  `½JAa = γa + ωb`, `½JAb = γb − ωa`, divided by the block's `omega_scale`
  (one scale for the whole spectrum, not each mode's own |λ| — see the code).
  A residual, NOT a two-sided bound.
- `labels`, `overlaps`, `generators`, `blocks` — symmetry classification against
  `bdg_symmetry_generators` (`overlaps` is `nev × length(generators)`).
  `labels[k]` is `:excitation` for a mode that is not a zero mode and does not
  align with a generator, `:zero_mode_<gen>` / `:<gen>` when it does, and
  `:zero_mode_unidentified` for `ω < omega_zero_tol` matching nothing known —
  the one label that should stop a spectrum from being published. Labels are
  computed on DEGENERATE BLOCKS (`blocks[k]` is the block index): inside a
  multiplet the individual eigenvectors are basis-arbitrary, so a per-mode
  label there would be an artefact. Modes sharing a `blocks` value share one
  label and one overlap row, and that is the resolution the classification
  actually has. The zero modes sort FIRST, so they consume the lowest `nev`
  slots — size `nev` to clear them before counting excitations.
- `hessian_lambda`, `hessian_residuals`, `hessian_converged` — the underlying
  Hessian block, per mode. **An unconverged Hessian mode makes every frequency
  built from it suspect**; the reduction cannot repair a subspace it was handed.
- `spectrum_reached` — false when EVERY returned mode is a zero mode, i.e. the
  block never left the null manifold and this is not an excitation spectrum at
  all (it also `@warn`s). Measured at F=6 polar with `nev=6`: six ω < 1e-5 modes,
  every number honest and none of them an excitation. Check this before reading
  `omega`.
- `j_min` — smallest singular value of the reduced symplectic form. `≈ 1` means
  the subspace is J-closed and the reduction is faithful; `≈ 0` means it is
  not, and the frequencies from it are not to be trusted.
- `pair_residual` — relative violation of the `λ ↦ −λ` spectral symmetry.
- `hessian_symmetry_defect` — asymmetry of the reduced Hessian, i.e. the
  finite-difference noise floor of the whole construction (the operator is a
  central difference of the gated gradient, so `ε` sets a floor on everything
  here exactly as it does for `trapped_bdg_spectrum`).
- `lhy_active` — whether an LHY term contributed. **A spectrum with
  `lhy_active=true` is not a mean-field spectrum**: it carries `∂²ε_LHY/∂n²`
  and with it the scheme dependence measured in #337. The flag exists so a
  quoted spectrum cannot silently be attributed to the wrong Hamiltonian.
- `mu`, `subspace_dim`, `n_hessian`.

Keywords: `nev`, `n_hessian` (Hessian modes to complexify, default `nev+2`;
each soft mode contributes one frequency pair), `block` / `max_iter` /
`hess_tol` (forwarded to `trapped_bdg_low_modes`), `omega_zero_tol`,
`label_tol` (overlap above which a generator claims a mode), `ε` / `order`
(finite-difference HvP), `params`, `modes` (a precomputed
`trapped_bdg_low_modes` result — pass it to avoid paying the Hessian solve
twice), `extra_nullspace`, `rng`.

SCALE. Measured at D=13 in 3D (¹⁵¹Eu F=6, uniform polar box, `nev=6`): 17.7 s at
8³, 60.8 s at 16³, 199.3 s at 24³ — the last is a BdG dimension of 359,424, i.e.
90× the dense path's `dim_cap`. **At F=6 the polar `e₀` state has a large k=0 null
manifold and a small `nev` lands entirely inside it** (six ω < 1e-5 modes with
large residuals, correctly reported); raise `nev` past it, deflate it with
`extra_nullspace`, or gap it with `q > 0` before reading a spectrum there.

DEVICE. Runs on CPU and CUDA. **The GPU path is gated by
`test/gpu/test_gpu_bdg_instrument_parity.jl`, which CI cannot run — CI has no
GPU, so a green suite says nothing about it.** That file is 3D on purpose: the
rotation generator `(x∂_y − y∂_x)ψ` is only reached at `ndim ≥ 2`, and it was
this function's one host-array leak — found not by a test but by the first real
device use, a 32³ × 13 cell on an H100 (#383), which failed to compile the
kernel rather than falling back.

VALIDITY REGIME. Gated in the uniform limit against `bogoliubov_spectrum` and
against the analytic F=1 polar density/magnon closed forms
(`test/oracles/test_trapped_bdg_frequencies.jl`). The reduction is exact when
the soft modes' stiff partners lie in `i ×` the soft subspace; where they do
not, the per-mode `residuals` rise and are the thing to read. On the weak-field
Eu soft manifold (`κ ≥ 4.7e3`, `λ_min ≤ 3.0e-2`) the low modes are a CLUSTER,
so raising `nev` degrades the Hessian side first — `hessian_converged` is the
gate on a production number, not `omega` looking reasonable.
"""
function trapped_bdg_frequencies(
    ws, ψ;
    nev::Int=6, n_hessian::Union{Nothing, Int}=nothing,
    block::Union{Nothing, Int}=nothing, max_iter::Int=60, hess_tol::Float64=1e-6,
    omega_zero_tol::Float64=1e-3, label_tol::Float64=0.5,
    ε::Float64=1e-5, order::Int=2, params=nothing, modes=nothing,
    extra_nullspace=nothing, rng=Random.default_rng(),
)
    nev >= 1 || throw(ArgumentError("trapped_bdg_frequencies: nev must be ≥ 1"))
    p = params === nothing ? constrained_hessian_params(ws, ψ) : params
    nh = n_hessian === nothing ? nev + 2 : n_hessian
    nh >= nev || throw(
        ArgumentError(
            "trapped_bdg_frequencies: n_hessian=$nh < nev=$nev — each soft Hessian " *
            "mode contributes one frequency pair, so the subspace cannot hold nev"),
    )
    dV = p.dV
    ipR(a, b) = real(_ipC(a, b, dV))

    lm = if modes === nothing
        trapped_bdg_low_modes(
            ws, ψ; nev=nh, block=(block === nothing ? nh + 4 : block),
            max_iter, tol=hess_tol, ε, order, params=p, extra_nullspace, rng,
        )
    else
        modes
    end
    length(lm.vectors) >= nev || throw(
        ArgumentError(
            "trapped_bdg_frequencies: the Hessian block returned " *
            "$(length(lm.vectors)) vectors, fewer than nev=$nev"),
    )

    # Complexify → J-invariant. `iX` is automatically in the tangent space:
    # the projection uses the COMPLEX inner product, so it removes ψ and iψ
    # together and is complex-linear, hence commutes with multiplication by i.
    # `refine` re-deflates after MGS's normalising division for the reason
    # documented at `_mgs_ortho`: the amplified leak would enter here as a
    # spurious ω = 0 mode wearing a physical Goldstone's label.
    function project(v)
        w = _tangent_project(v, ψ, p.dV, p.n2)
        extra_nullspace === nothing && return w
        for mvec in extra_nullspace
            w = w .- mvec .* (ipR(mvec, w) / ipR(mvec, mvec))
        end
        w
    end
    S = _mgs_ortho(
        vcat(lm.vectors, [im .* v for v in lm.vectors]), ipR; refine=project)
    m = length(S)
    AS = [constrained_hessian_action(ws, ψ, s; p.μ, p.dV, p.n2, ε, order) for s in S]

    G = [_ipC(S[i], AS[j], dV) for i in 1:m, j in 1:m]
    A_red = real.(G)
    scale = maximum(abs, A_red) + COUPLING_TOL
    hessian_symmetry_defect = maximum(abs, A_red .- transpose(A_red)) / scale
    gen = imag.(G) ./ 2                     # ½⟨Sᵢ, J A Sⱼ⟩_R
    J_red = [imag(_ipC(S[i], S[j], dV)) for i in 1:m, j in 1:m]
    j_min = m > 0 ? minimum(svdvals(J_red)) : 0.0

    E = eigen(gen)
    evals = E.values
    rad = maximum(abs, evals) + COUPLING_TOL
    pair_residual =
        maximum(λ -> minimum(abs(-λ - λ2) for λ2 in evals), evals) / rad

    # e^{−iωt} branch: Im λ < 0. A purely real λ (Im = 0) is a non-oscillating
    # growth/decay pair and carries no frequency — kept only if nothing else
    # is available, with ω = 0 and its growth reported.
    order_idx = sort(
        [k for k in eachindex(evals) if imag(evals[k]) <= 0];
        by=k -> (-imag(evals[k]), -abs(real(evals[k]))),
    )
    n_out = min(nev, length(order_idx))
    n_out >= 1 || throw(
        ErrorException(
            "trapped_bdg_frequencies: the reduced generator produced no mode " *
            "(subspace_dim=$m) — the Hessian block is degenerate"),
    )

    omega = zeros(Float64, n_out)
    growth = zeros(Float64, n_out)
    residuals = zeros(Float64, n_out)
    planes = Vector{Tuple{typeof(ψ), typeof(ψ)}}(undef, n_out)

    for (out, k) in enumerate(order_idx[1:n_out])
        λk = evals[k]
        ω = max(-imag(λk), 0.0)          # the filter admits Im λ ≤ 0; kill −0.0
        γ = real(λk)
        c = @view E.vectors[:, k]
        # M(p+iq) = (γ−iω)(p+iq) ⇒ the real pair (a,b)=(Re c, Im c) rotates:
        # δ(t) = e^{γt}(cos(ωt)a + sin(ωt)b).
        a = reduce(.+, (real(c[j]) .* S[j] for j in 1:m))
        b = reduce(.+, (imag(c[j]) .* S[j] for j in 1:m))
        nrm = sqrt(max(ipR(a, a) + ipR(b, b), 0.0))
        if nrm > 0
            a = a ./ nrm
            b = b ./ nrm
        end
        Aa = reduce(.+, (real(c[j]) .* AS[j] for j in 1:m)) ./ max(nrm, UNDERFLOW_FLOOR)
        Ab = reduce(.+, (imag(c[j]) .* AS[j] for j in 1:m)) ./ max(nrm, UNDERFLOW_FLOOR)
        # ½JA = ½(−i)A. Full-space residual of the mode equation.
        r1 = (-im / 2) .* Aa .- γ .* a .- ω .* b
        r2 = (-im / 2) .* Ab .- γ .* b .+ ω .* a
        omega[out] = ω
        growth[out] = γ
        residuals[out] = sqrt(max(ipR(r1, r1) + ipR(r2, r2), 0.0))
        planes[out] = (a, b)
    end

    # ONE spectral scale for the whole block, as `trapped_bdg_spectrum` does
    # with `radius`. Dividing each mode by its OWN |λ| is what a relative
    # residual usually means and it is wrong here: a genuine zero mode has
    # ω = γ = 0, so its own scale is 0 and a residual of 1e-11 came back as
    # 6.6e+01 — a perfectly good Goldstone reported as the worst mode in the
    # spectrum. `omega_scale` is reported so the absolute residual is
    # recoverable by multiplying back.
    #
    # The `scale/2` floor covers the case where the ENTIRE block is zero modes,
    # which is not hypothetical: the F=6 polar state has a large k=0 null
    # manifold, so `nev=6` there returns six ω≈0 modes and the spectral scale
    # collapses to 6e-6, reporting residuals of 200–750 for an operator whose
    # own scale says they are O(1). `maximum(abs, A_red)/2` is the largest ½A on
    # this subspace, i.e. the natural bound on ω within it.
    omega_scale = max(maximum(omega) + maximum(abs, growth), scale / 2, COUPLING_TOL)
    residuals ./= omega_scale

    gens_proj = [
        name => _tangent_project(g, ψ, p.dV, p.n2)
        for (name, g) in bdg_symmetry_generators(ws, ψ)
    ]
    blocks, overlaps, labels = _label_modes(
        omega, planes, gens_proj, ipR; omega_zero_tol, label_tol)

    # Did the block get PAST the zero modes? A state with a large null manifold
    # spends the whole `nev` inside it and returns nothing but ω ≈ 0 — measured
    # at F=6 polar, where `nev=6` came back as six ω < 1e-5 modes. Every number
    # in that return is honest and none of them is an excitation, which is the
    # kind of result that reads as "the spectrum is gapless". Say it instead.
    spectrum_reached = any(>(omega_zero_tol), omega)
    spectrum_reached || @warn(
        "trapped_bdg_frequencies: every returned mode is a zero mode — the block " *
            "never left the null manifold, so this is NOT an excitation spectrum. " *
            "Raise nev past the manifold, deflate it with extra_nullspace, or gap it " *
            "(e.g. q > 0). The F=6 polar state has a large k=0 null manifold.",
        nev, n_zero_modes=count(<=(omega_zero_tol), omega), omega_zero_tol,
    )

    (;
        omega, growth, residuals, labels, overlaps, blocks,
        generators=[name for (name, _) in gens_proj],
        hessian_lambda=lm.λ, hessian_residuals=lm.residuals,
        hessian_converged=lm.converged_modes,
        j_min, pair_residual, hessian_symmetry_defect, omega_scale, spectrum_reached,
        lhy_active=_lhy_is_active(ws.lhy),
        mu=p.μ, subspace_dim=m, n_hessian=nh,
    )
end
