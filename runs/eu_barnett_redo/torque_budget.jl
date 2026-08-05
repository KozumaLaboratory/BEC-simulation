# Where does the residual J_z leak come from? Measure the budget, do not argue.
#
# At B = 0 every term in the Hamiltonian commutes with J_z = L_z + F_z in the
# continuum, so the EXACT d<J_z>/dt is zero. Discretised, each term contributes
# its own violation, and they can be measured separately on a REAL state:
#
#     dJz/dt|_term = -2 Im <H_term psi | J_z psi>
#
# Summing over terms gives a predicted instantaneous leak rate, which is then
# compared against the observed dJz/dt from the ledger at the same time. That
# comparison is the point: if the terms account for the observed rate, the leak
# is discretisation and we know which term; if they fall short, something else
# (the boundary, the time stepping) carries it and the box/dt probes decide.
#
# Usage:
#   julia --project=. runs/eu_barnett_redo/torque_budget.jl <frames.jld2> <ledger.csv>
using SpinorBEC
using JLD2, Printf, FFTW, LinearAlgebra

const FRAMES = length(ARGS) >= 1 ? ARGS[1] : error("need frames.jld2")
const LEDGER = length(ARGS) >= 2 ? ARGS[2] : ""

const ATOM = SpinorBEC.resolve_atom(:Eu151)
const N_ATOMS = 30000
const OMEGA_REF = 628.3
const OMEGA_TRAP = (1.0, 1.0, 2.0)

# L_z psi = -i (x d_y - y d_x) psi, spectrally. Validated on an l=+1 state.
function apply_Lz(psi, grid)
    n = grid.config.n_points
    D = size(psi, 4)
    out = similar(psi)
    kx, ky = grid.k[1], grid.k[2]
    xg, yg = grid.x[1], grid.x[2]
    buf = Array{ComplexF64}(undef, n...)
    P = plan_fft(buf); Pi = plan_ifft(buf)
    g = similar(buf); dxb = similar(buf); dyb = similar(buf)
    for c in 1:D
        @views buf .= psi[:, :, :, c]
        f = P * buf
        @inbounds for k in axes(f,3), j in axes(f,2), i in axes(f,1)
            g[i,j,k] = im * kx[i] * f[i,j,k]
        end
        dxb .= Pi * g
        @inbounds for k in axes(f,3), j in axes(f,2), i in axes(f,1)
            g[i,j,k] = im * ky[j] * f[i,j,k]
        end
        dyb .= Pi * g
        @inbounds for k in axes(buf,3), j in axes(buf,2), i in axes(buf,1)
            out[i,j,k,c] = -im * (xg[i]*dyb[i,j,k] - yg[j]*dxb[i,j,k])
        end
    end
    out
end

function jz_psi(psi, grid, F)
    out = apply_Lz(psi, grid)
    D = 2F + 1
    @inbounds for c in 1:D
        m = F - (c - 1)
        @views out[:,:,:,c] .+= m .* psi[:,:,:,c]
    end
    out
end

f = jldopen(FRAMES, "r")
nf = f["n_frames"]; box = Tuple(Float64.(f["box"])); npts = Tuple(Int.(f["n"]))
println("frames=$nf  n=$npts  box=$box  dx=", round.(box ./ npts; digits=4))

grid = make_grid(GridConfig(npts, box))
F = ATOM.F; D = 2F + 1
dV = cell_volume(grid)
c0 = compute_c_total(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
c1 = -0.005 * c0
c_dd = compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
a_ho = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
eps_dd = SpinorBEC.compute_a_dd(ATOM) / ATOM.a_s
c_lhy = scalar_lhy_coefficient(ATOM.a_s / a_ho, N_ATOMS; eps_dd)

V = zeros(Float64, npts...)
@inbounds for I in CartesianIndices(V)
    V[I] = 0.5 * sum(OMEGA_TRAP[d]^2 * grid.x[d][I[d]]^2 for d in 1:3)
end

# Observed dJz/dt from the ledger, for comparison.
obs = Tuple{Float64,Float64}[]
if !isempty(LEDGER) && isfile(LEDGER)
    rows = readlines(LEDGER)[2:end]
    ts = Float64[]; jz = Float64[]
    for r in rows
        p = split(r, ",")
        length(p) >= 7 || continue
        push!(ts, parse(Float64, p[1])); push!(jz, parse(Float64, p[7]))
    end
    for i in 2:length(ts)
        push!(obs, (ts[i], (jz[i]-jz[i-1])/(ts[i]-ts[i-1])))
    end
end
obs_rate(t) = isempty(obs) ? NaN :
    obs[argmin(abs(o[1]-t) for o in obs)][2]

@printf("\n%8s | %12s %12s %12s %12s | %12s\n",
        "t", "DDI", "kinetic", "contact+LHY", "SUM", "observed")
for i in 1:nf
    key = "frame_" * lpad(i, 3, '0')
    haskey(f, "$key/psi") || continue
    t = f["$key/t"]
    psi = ComplexF64.(f["$key/psi"])
    t < 30.0 && continue                     # quench stage only: B = 0 there

    ws = make_workspace(; grid, atom=ATOM,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1); c_lhy),
        zeeman=TimeDependentZeeman(ConstantWaveform(0.0), ConstantWaveform(0.0),
                                   ConstantWaveform(0.0), ConstantWaveform(0.0)),
        potential=NoPotential(),
        sim_params=SimParams(; dt=1e-3, n_steps=1, imaginary_time=false),
        psi_init=psi, enable_ddi=true, c_dd=c_dd, backend=CPUBackend())
    copyto!(ws.potential_values, V)

    jz = jz_psi(Array(ws.state.psi), grid, F)
    rate(term) = begin
        h = zeros(ComplexF64, size(psi)...)
        SpinorBEC.apply_operator!(h, term, ws, ws.state.psi)
        -2 * imag(sum(conj.(h) .* jz)) * dV
    end
    r_ddi = rate(SpinorBEC.DDITerm())
    r_kin = rate(SpinorBEC.KineticTerm())
    r_con = rate(SpinorBEC.DensityC0Term(c0)) + rate(SpinorBEC.SpinC1Term(c1)) +
            rate(SpinorBEC.LHYTerm())
    @printf("%8.2f | %12.4e %12.4e %12.4e %12.4e | %12.4e\n",
            t, r_ddi, r_kin, r_con, r_ddi + r_kin + r_con, obs_rate(t))
end
close(f)
println("""
Reading: a term whose rate matches the observed dJz/dt is the leak. If the SUM
falls well short of `observed`, the discretised Hamiltonian is NOT the whole
story and the remainder is boundary or time-stepping — which the box35 / dt5e4
probes separate.""")
