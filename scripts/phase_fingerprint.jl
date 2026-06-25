# Complete gauge/frame-invariant phase fingerprint for an F=6 dipolar spinor.
# Thin driver over scripts/phase_fingerprint_lib.jl (the single source for every
# metric). Run on KNOWN states (imprints + inert candidates) to check each metric
# recovers the known structure — keep only the parameters that do.
#
# Env: FP_STATE=polar|fm|cyclic|biaxial_nematic|fl_vortex|polar_core_vortex|chiral_spin_vortex|spin_helix
#      FP_IN=<jld2>   (classify a saved state instead of a named imprint)
#      FP_GRID=40 FP_BOX=24
#   julia --project=. scripts/phase_fingerprint.jl

import SpinorBEC
using SpinorBEC: eu151_preset, SpinSystem, init_psi, load_state
using LinearAlgebra: norm
using Printf
include(joinpath(@__DIR__, "phase_fingerprint_lib.jl"))

const F   = 6
const NX  = parse(Int, get(ENV, "FP_GRID", "40"))
const BOX = parse(Float64, get(ENV, "FP_BOX", "24.0"))
const GRID = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, 1.0)).grid
const SYS = SpinSystem(F)
const CTX = fp_context(GRID; box=BOX, F=F)

function get_psi()
    if haskey(ENV, "FP_IN")
        st = load_state(ENV["FP_IN"])
        return Array{ComplexF64}(st.psi), basename(ENV["FP_IN"])
    end
    s = Symbol(get(ENV, "FP_STATE", "polar"))
    s === :fm && (s = :m_plus_F)
    kw = Dict{Symbol, Any}()
    s in (:fl_vortex, :polar_core_vortex, :chiral_spin_vortex) && (kw[:init_vortex_charge] = 1)
    s === :spin_helix && (kw[:helix_k] = (2π / BOX * 3, 0.0, 0.0))
    Array{ComplexF64}(init_psi(GRID, SYS; state=s, kw...)), String(s)
end

psi, name = get_psi()
print_fingerprint(CTX, fingerprint(CTX, psi), name)
