# Is the polarized branch's over-binding in the DDI anisotropy?
#
# THE HYPOTHESIS. Every quantitative gap against the paper is on a POLARIZED
# or dense state; the flux-closure torus agrees to ~1 %. Those two cases are
# governed by different pieces of the same kernel:
#
#   flux closure  E_ddi/E_s = -eps_dd            EXACTLY, shape-independent
#                 (k.M_k = 0 kills the transverse part; only the -delta/3
#                  trace piece survives). Verified here to 0.08 % (F=1) and
#                  0.23 % (F=6).
#   polarized     E_ddi/E_s = -eps_dd f(kappa)   shape-dependent, and it is the
#                 TRANSVERSE k_a k_b part that supplies f(kappa) -- the exact
#                 piece the flux-closure identity does NOT test.
#
# So a defect in the transverse kernel would leave the torus perfect and move
# the cigar, which is the observed pattern. This measures f(kappa) on the
# converged cigars and compares with the closed form.
#
# CAVEAT, stated before the numbers: the closed f(kappa) is derived for a
# GAUSSIAN. A droplet is flat-topped, so a few-% deviation is expected and is
# not evidence of anything. A LARGE one would be.
#
#   julia --project=. runs/saito_li_torus/h15_ddi_anisotropy.jl

using SpinorBEC
using SpinorBEC: make_grid, GridConfig, total_density, spin_density_vector,
    spin_matrices, energy_decomposition, make_workspace, InteractionParams,
    ZeemanParams, HarmonicTrap, SimParams, ATOM_REGISTRY, Units,
    compute_a_dd, compute_c_dd_dimless, scalar_lhy_coefficient, cell_volume
using JLD2, Printf, LinearAlgebra

include(joinpath(@__DIR__, "h3_cells.jl"))

"""
Standard dipolar anisotropy function for a Gaussian of aspect
`kappa = sigma_rho / sigma_z`:  f(0)=1 (infinite cigar), f(1)=0 (sphere),
f(inf) = -2 (pancake).
"""
function f_dip(k::Float64)
    abs(k - 1) < 1e-8 && return 0.0
    if k < 1
        s = sqrt(1 - k^2)
        return (1 + 2k^2) / (1 - k^2) - 3k^2 * atanh(s) / (1 - k^2)^1.5
    end
    s = sqrt(k^2 - 1)
    (1 + 2k^2) / (1 - k^2) + 3k^2 * atan(s) / (k^2 - 1)^1.5
end

"Rebuild the workspace for a saved cell and read its energy decomposition."
function measure_cell(file)
    d = load(file)
    psi = d["psi"]
    cell = d["cell"]
    b = build_cell(cell; n=Tuple(d["n"]), box=Tuple(d["box"]))
    ip = InteractionParams(Dict(0 => b.c0); c_lhy=b.c_lhy)
    ws = make_workspace(; grid=b.grid, atom=b.atom, interactions=ip,
        zeeman=ZeemanParams(b.p, 0.0),
        potential=HarmonicTrap(TRAP_OMEGA, TRAP_OMEGA, TRAP_OMEGA),
        sim_params=SimParams(; dt=1e-4, n_steps=1),
        enable_ddi=true, c_dd=b.c_dd, secular_ddi=false,
        ddi_padding=true, ddi_trunc_radius=-1.0, psi_init=psi)
    e = energy_decomposition(ws)
    rho = total_density(psi, 3)
    dV = cell_volume(b.grid)
    # density-weighted second moments -> aspect
    x2 = z2 = 0.0
    for I in CartesianIndices(rho)
        w = rho[I] * dV
        x2 += w * b.grid.x[1][I[1]]^2
        z2 += w * b.grid.x[3][I[3]]^2
    end
    sm = spin_matrices(b.F)
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    pol = abs(sum(fz) * dV) / (b.F * sum(rho) * dV)     # |<f_z>|/F : 1 = polarized
    (; cell, eps_dd=cell.eps_dd, F=b.F, Bz=cell.Bz_mG,
        e_s=getproperty(e, :density), e_ddi=getproperty(e, :ddi),
        e_lhy=getproperty(e, :lhy), e_kin=getproperty(e, :kinetic),
        e_zee=getproperty(e, :zeeman),
        total=e.total, sx=sqrt(x2), sz=sqrt(z2), pol=pol,
        name=basename(file))
end

function main()
    out = joinpath(@__DIR__, "out")
    files = sort(
        filter(f -> startswith(basename(f), "cell_") &&
                    endswith(f, ".jld2"), readdir(out; join=true)),
    )
    isempty(files) && (println("no cell_*.jld2"); return nothing)
    println("="^100)
    println("DDI anisotropy on the converged states")
    println("  flux closure predicts E_ddi/E_s = -eps_dd exactly (shape-free)")
    println("  polarized  predicts E_ddi/E_s = -eps_dd f(kappa), kappa = s_x/s_z")
    println("="^100)
    @printf("%-30s %4s %6s %7s %7s %8s %8s %8s %9s %9s\n",
        "cell", "F", "Bz/mG", "|f_z|/F", "kappa", "meas r", "-e*f(k)", "-e (fc)",
        "E_int", "LHY/|E|")
    println("  E_int = E_total - E_zeeman: the binding energy per atom. A")
    println("  self-bound droplet MUST have E_int < 0 -- otherwise a dispersed")
    println("  gas, which pays only the Zeeman, is lower.")
    for f in files
        m = try
            measure_cell(f)
        catch err
            continue
        end
        r = m.e_ddi / m.e_s
        kap = m.sx / m.sz
        pred_pol = -m.eps_dd * f_dip(kap)
        @printf("%-30s %4d %6.3f %7.4f %7.4f %8.5f %8.5f %8.5f %9.4f %9.3f\n",
            first(m.name, 30), m.F, m.Bz, m.pol, kap, r, pred_pol,
            -m.eps_dd, m.total - m.e_zee, abs(m.e_lhy) / abs(m.total))
    end
    println()
    println("Read the two right-hand predictions against `meas r`:")
    println("  a POLARIZED cell (|f_z|/F near 1) should follow -eps*f(kappa)")
    println("  a FLUX-CLOSURE cell (|f_z|/F near 0) should follow -eps_dd")
    println("A polarized cell that matches -eps*f(kappa) means the transverse")
    println("kernel is right and the over-binding is NOT the DDI anisotropy.")
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
