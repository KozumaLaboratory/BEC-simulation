# Shared cell/preset layer for the eu335 spectrum drivers.
#
# `branch_spectrum.jl` (#383) and `precond_ab.jl` (#397/#399) read THE SAME
# stored cells with THE SAME preset, and a stored ψ is only meaningful under the
# Hamiltonian it was converged in — so "which trap, which pin, which DDI kernel"
# has to have exactly one definition. Two copies of `cell_workspace` differing
# in `ddi_padding` would produce two λ_min for one cell and nothing would say
# which was which.
#
# Included, not imported: these are `scripts/`, not a package.
#
# Env consumed here (shared by every driver that includes this file):
#   SP_KAPPA=1.8 SP_GRID=32 SP_BOX=24.0 SP_PIN=0.002 SP_PADDING=0 SP_DEALIAS=0
#   SP_CELLS=a/psi.jld2;b/psi.jld2   `;` — `qsub -v` cuts a value at the comma
#   SP_CELLS_N=                      expected count; guards that cut

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d

const KAPPA = getf("SP_KAPPA", 1.8)
const GRID_N = Int(getf("SP_GRID", 32))
const BOX = getf("SP_BOX", 24.0)
const PIN = getf("SP_PIN", 0.002)
const PADDING = get(ENV, "SP_PADDING", "0") == "1"

# Matching #335: the states were converged with dealiasing off, and a state
# converged under a different Hamiltonian is not stationary under this one.
SpinorBEC.DEALIAS_2_3_ENABLED[] = get(ENV, "SP_DEALIAS", "0") == "1"

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom

p_of(B_uG) = Units.bfield_to_p(B_uG * 1e-6, ATOM.g_F, PRESET.omega_ref)

struct BlindSpectrum <: Exception
    msg::String
end
Base.showerror(io::IO, e::BlindSpectrum) = print(io, "BlindSpectrum: ", e.msg)

"""ψ and its recorded (B, ε), with the parameter-epoch check every consumer of a
stored state owes — same contract as `eu_hysteresis/branch_stability.jl`, because
the Hessian is even less forgiving than a hold: on a state that is not stationary
here, μ is not the chemical potential and λ_min is not a stability verdict."""
function load_cell(path)
    isfile(path) || error("no such cell: $path")
    jldopen(path, "r") do f
        g(k, d) = haskey(f, k) ? f[k] : d
        for (nm, got, want) in (("c0", g("c0", NaN), PRESET.interactions.c[0]),
            ("c1", g("c1", NaN), PRESET.interactions.c[1]),
            ("c_dd", g("c_dd", NaN), PRESET.c_dd))
            isnan(got) && continue
            abs(got - want) / max(abs(want), 1e-30) < 1e-8 ||
                error("cell/preset mismatch on $nm: $got vs $want — $path")
        end
        n = g("grid_n_points", nothing)
        n === nothing || first(n) == GRID_N ||
            error("cell grid $(first(n)) ≠ $GRID_N — $path")
        (; psi=Array{ComplexF64}(f["psi"]), B=Float64(g("B_uG", NaN)),
            pin=Float64(g("pin_bx", g("pin_eps", PIN))),
            fperp0=Float64(g("fperp", NaN)), E0=Float64(g("E_total", g("E", NaN))))
    end
end

"""The workspace the cell was converged in: same trap, same pin, same DDI kernel.
`imaginary_time` is irrelevant here (nothing is propagated) but the Hamiltonian is
not."""
function cell_workspace(psi, B_uG, ε)
    make_workspace(; grid=PRESET.grid, atom=ATOM,
        interactions=PRESET.interactions, potential=PRESET.potential,
        zeeman=static_zeeman(; Bz=p_of(B_uG), Bx=ε, q=0.0),
        sim_params=SimParams(; dt=0.002, n_steps=1, imaginary_time=true),
        psi_init=Array{ComplexF64}(psi), enable_ddi=true, c_dd=PRESET.c_dd,
        secular_ddi=false, backend=BACKEND, ddi_padding=PADDING,
        ddi_trunc_radius=-1.0)
end

"""`SP_CELLS` as a vector of paths, with the `qsub -v` comma-cut guard."""
function parse_cells()
    s = get(ENV, "SP_CELLS", "")
    v = isempty(s) ? String[] : String.(split(s, r"[,;]"))
    n = get(ENV, "SP_CELLS_N", "")
    isempty(n) || length(v) == parse(Int, n) || error("""
        SP_CELLS parsed $(length(v)) entries but SP_CELLS_N says $n.
        A list passed through `qsub -v` is cut at the first comma — use `;`.""")
    isempty(v) && error("SP_CELLS is empty — nothing to measure")
    v
end
