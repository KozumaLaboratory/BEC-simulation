using SpinorBEC, LinearAlgebra, Printf
const SB = SpinorBEC

const ATOM = Eu151
const OMEGA_REF = 2π * 110.0
const NAT = 10_000

# physical couplings (dimensionless, hbar=m=omega_ref=1)
const A_HO = sqrt(SB.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * NAT
const C0 = C_TOTAL / (1 + ATOM.F^2 / 36.0)
const C1_BASE = C0 / 36.0
const C_DD = SB.compute_c_dd_dimless(ATOM; N_atoms=NAT, omega_ref=OMEGA_REF)

const NPTS = (20, 20, 20)
const BOX = (18.0, 18.0, 16.0)
const TRAP = (1.0, 1.0, 1.1818)

qval(Bg) = SB.compute_quadratic_zeeman(ATOM; p_dimless=SB.Units.bfield_to_p(Bg, ATOM.g_F, OMEGA_REF), omega_ref=OMEGA_REF)

function build_grid_pot()
    grid = SB.make_grid(SB.GridConfig(NPTS, BOX))
    pot = SB.HarmonicTrap{3}(TRAP)
    grid, pot
end

# ITP-relax the polarized (m=+F) spatial mode with DDI on, no field.
function relax_envelope(grid, pot; c1=C1_BASE, n_steps=1500, dt=0.01)
    sys = SB.SpinSystem(ATOM.F)
    psi0 = SB.init_psi(grid, sys; state=:m_plus_F)
    inter = SB.InteractionParams(Dict{Int,Float64}(0 => C0, 1 => c1))
    sp = SB.SimParams(; dt=dt, n_steps=n_steps, imaginary_time=true, normalize_every=1,
                      save_every=n_steps)
    ws = SB.make_workspace(; grid=grid, atom=ATOM, interactions=inter,
                           zeeman=SB.ZeemanParams(0.0, 0.0), potential=pot,
                           sim_params=sp, psi_init=psi0,
                           enable_ddi=true, c_dd=C_DD, secular_ddi=false)
    SB.run_simulation!(ws)
    copy(ws.state.psi)
end

# Build transverse coherent state from relaxed envelope (component 1 = m=+F).
function transverse_from_envelope(psi_relaxed, grid)
    sys = SB.SpinSystem(ATOM.F)
    D = sys.n_components
    sm = SB.spin_matrices(ATOM.F)
    Uy = exp(-1im * (π/2) * Matrix(sm.Fy))
    cbase = Uy[:, 1]                      # Ry(pi/2)|m=+F>
    env = @view psi_relaxed[:, :, :, 1]   # spatial mode
    psi = zeros(ComplexF64, size(psi_relaxed))
    @inbounds for I in CartesianIndices(size(env))
        for c in 1:D
            psi[I, c] = env[I] * cbase[c]
        end
    end
    psi
end

function run_quench(grid, pot, psi_init; c1, q, enable_ddi, n_steps, save_every, dt=0.005)
    sys = SB.SpinSystem(ATOM.F)
    inter = SB.InteractionParams(Dict{Int,Float64}(0 => C0, 1 => c1))
    sp = SB.SimParams(; dt=dt, n_steps=n_steps, imaginary_time=false,
                      save_every=save_every)
    ws = SB.make_workspace(; grid=grid, atom=ATOM, interactions=inter,
                           zeeman=SB.ZeemanParams(0.0, q), potential=pot,
                           sim_params=sp, psi_init=copy(psi_init),
                           enable_ddi=enable_ddi, c_dd=(enable_ddi ? C_DD : NaN),
                           secular_ddi=false)
    times = Float64[]
    pops = Vector{Vector{Float64}}()
    cb = SB.SimulationCallbacks(; on_snapshot=function(wcb, step, snap)
        push!(times, wcb.state.t)
        push!(pops, SB.component_populations(wcb.state.psi, grid, sys).populations)
    end)
    SB.run_simulation!(ws; callbacks=cb)
    times, reduce(hcat, pops)  # pops: D x nframes
end
