# Symmetry-breaking pinning + ε→0 extrapolation for soft-manifold ground states.
#
# Below ~60 µG the Eu F=6 + DDI ground state spontaneously breaks the exact axial
# U(1) e^{-iθ(L_z+F_z)} (spin+space co-rotation). The resulting Goldstone makes
# the GS a degenerate ORBIT, so |∇E| floors ~0.05 and a :polar seed false-
# converges to a HIGHER-energy symmetric saddle — there is no isolated point to
# converge to.
#
# Fix (textbook SSB): add a small explicit term ε that BREAKS the symmetry,
# turning the orbit into an isolated non-degenerate minimum where |∇E|→0 is
# reachable. Warm-continue down a descending ε ladder, evaluate the BARE (ε=0)
# energy at each pinned state, and extrapolate
#     E_bare(ε) = E0 + c·ε²        (the state distorts O(ε) ⇒ bare energy O(ε²))
# to recover the certified GS energy E0 of the degenerate problem. Reaches
# |∇E|~1e-5 (4 orders below the un-pinned 0.05 floor).
#
# Exposed through `find_ground_state_lbfgs(; pin, epsilon_ramp=…)`: pass a pin
# closure `ε -> (; zeeman=…)` or `ε -> (; potential=…)`. `pin_transverse_field`
# is the built-in conjugate-field pin (transverse b_x = ε); an elliptical trap
# `ε -> (; potential = <ω_y²=(1+ε)ω_x²>)` is the pure-spatial alternative.

export pin_transverse_field

"""
    pin_transverse_field(; Bz, q=0.0) -> (ε -> NamedTuple)

Built-in symmetry-breaking pin: a transverse field `b_x = ε` (the field conjugate
to the broken transverse-spin order), keeping the axial `Bz` and quadratic `q`.
Returns a closure suitable for `find_ground_state_lbfgs(; pin=…, epsilon_ramp=…)`.
"""
pin_transverse_field(; Bz::Real, q::Real=0.0) =
    ε -> (; zeeman=static_zeeman(; Bz=Bz, Bx=ε, q=q))

# Least-squares fit E_bare = E0 + c·ε² ⇒ (E0, slope c, fit RMS).
function _quad_extrapolate(eps::AbstractVector, ebare::AbstractVector)
    n = length(eps)
    n < 2 && return (Float64(ebare[1]), 0.0, NaN)
    x = Float64.(eps) .^ 2
    y = Float64.(ebare)
    x̄ = sum(x) / n
    ȳ = sum(y) / n
    sxx = sum((x .- x̄) .^ 2)
    c = sxx == 0 ? 0.0 : dot(x .- x̄, y .- ȳ) / sxx
    E0 = ȳ - c * x̄
    rms = sqrt(sum((y .- (E0 .+ c .* x)) .^ 2) / n)
    (E0, c, rms)
end

# Pin ε-continuation. Mirrors the find_ground_state_lbfgs physics signature so it
# can (a) build ONE bare (ε=0) workspace for certified-energy evaluation and
# (b) re-enter the single-solve path per ε with the pinned override + warm seed.
function _lbfgs_pin_continuation(;
    pin::Union{Nothing, Function},
    epsilon_ramp::AbstractVector{<:Real},
    grid::Union{Nothing, Grid},
    atom::Union{Nothing, AtomSpecies},
    interactions::InteractionParams,
    zeeman::AbstractZeemanField,
    potential::AbstractPotential,
    n_steps::Int,
    tol::Float64,
    initial_state::Symbol,
    init_state_params::Dict{Symbol, Float64},
    psi_init::Union{Nothing, AbstractArray},
    ws_init::Union{Nothing, Workspace},
    enable_ddi::Bool,
    c_dd::Float64,
    secular_ddi::Bool,
    ddi_trunc_radius::Float64,
    ddi_padding::Bool,
    ddi_pad_factor::Union{Real, NTuple},
    quasi_2d_ddi::Bool,
    l_z_ddi::Float64,
    target_magnetization::Union{Nothing, Float64},
    backend::AbstractBackend,
    m_lbfgs::Int,
    verbose::Bool,
    light_shift::Union{Nothing, LightShift},
    dtype::Union{Nothing, Type{<:AbstractFloat}},
    sobolev_alpha::Union{Float64, Symbol},
    precond_alpha_v::Float64,
    precond_alpha_k::Float64,
    rotating_frame_omega::Float64,
    newton_polish::Bool,
    newton_max_outer::Int,
    newton_max_cg::Int,
    newton_eps::Float64,
)
    pin === nothing &&
        throw(
            ArgumentError(
                "epsilon_ramp requires a `pin` closure ε -> (; zeeman=…) | (; potential=…)"
            ),
        )
    ws_init === nothing ||
        throw(
            ArgumentError(
                "epsilon_ramp pin continuation builds its own workspace; pass grid/atom, not ws_init"
            ),
        )
    (grid === nothing || atom === nothing) &&
        throw(ArgumentError("epsilon_ramp pin continuation requires grid and atom"))

    eps = sort(collect(Float64, epsilon_ramp); rev=true)   # descending ⇒ warm continuation

    # Initial seed for the first (largest) ε.
    seed = if psi_init !== nothing
        Array{ComplexF64}(psi_init)
    else
        sys = SpinSystem(atom.F)
        init_kwargs = Dict{Symbol, Any}(:state => initial_state)
        for (k, v) in init_state_params
            init_kwargs[k] = v
        end
        Array{ComplexF64}(init_psi(grid, sys; init_kwargs...))
    end

    # Bare (ε=0) workspace: the reference Hamiltonian we extrapolate toward.
    bare_ws = make_workspace(;
        grid, atom, interactions, zeeman, potential,
        sim_params=SimParams(; dt=0.001, n_steps=1, imaginary_time=true),
        psi_init=seed,
        enable_ddi, c_dd, secular_ddi, ddi_trunc_radius, ddi_padding, ddi_pad_factor,
        quasi_2d_ddi, l_z_ddi, backend, light_shift, dtype,
    )

    rows = NamedTuple[]
    local res
    hist = nothing   # thread the L-BFGS curvature history across rungs: adjacent ε
    # share a nearly-identical Hessian, so the warm history saves
    # the steepest-descent restart each rung would otherwise pay.
    for ε in eps
        ov = pin(ε)
        zee = get(ov, :zeeman, zeeman)
        pot = get(ov, :potential, potential)
        res = find_ground_state_lbfgs(;
            grid, atom, interactions, zeeman=zee, potential=pot,
            n_steps, tol, psi_init=seed,
            enable_ddi, c_dd, secular_ddi, ddi_trunc_radius, ddi_padding, ddi_pad_factor,
            quasi_2d_ddi, l_z_ddi, target_magnetization, backend, m_lbfgs, verbose,
            light_shift, dtype, sobolev_alpha, precond_alpha_v, precond_alpha_k,
            rotating_frame_omega, newton_polish, newton_max_outer, newton_max_cg, newton_eps,
            lbfgs_history=hist,
        )
        hist = res.lbfgs_history
        seed = Array{ComplexF64}(res.workspace.state.psi)
        copyto!(bare_ws.state.psi, seed)
        E_bare = Float64(total_energy(bare_ws))
        push!(rows, (; eps=ε, E_pin=res.energy, E_bare=E_bare, grad=res.grad_norm))
        verbose && @printf("  pin ε=%.2e | E_bare=%.6f E_pin=%.6f |∇E|=%.2e\n",
            ε, E_bare, res.energy, res.grad_norm)
    end

    E0, slope, rms = _quad_extrapolate([r.eps for r in rows], [r.E_bare for r in rows])
    merge(res, (; E0_extrap=E0, pin_slope=slope, pin_rms=rms, pin_rows=rows))
end
