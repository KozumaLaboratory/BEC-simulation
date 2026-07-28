# Measurement-operator verification (PASS-0 gate). The Jz "leak" is dt-independent
# (bit-identical at dt 4e-4 vs 2e-4) with norm+energy conserved and L_z-ONLY drift
# -> more consistent with a broken L_z MEASUREMENT than broken physics (a physical
# Jz leak should show energy tension; a rotationally-asymmetric L_z operator on a
# cubic grid drifts the measured value while the dynamics conserves Jz exactly).
#
# Decisive test: a charge-m vortex (x+iy)^m * exp(-r^2/2σ^2) is an EXACT L_z
# eigenstate (⟨L_z⟩=m) for ANY radial profile σ. Sweep σ from smooth (low-k) to
# sharp (high-k) on the SAME 48^3 grid as the leaking runs. If orbital_angular_
# momentum returns m at every σ -> operator is exact, leak is dynamical (-> 64^3).
# If measured L_z drifts from m as σ shrinks (high-k) -> the OPERATOR is the leak,
# physics conserves Jz, and "-0.44"/"AM lost" were bookkeeping artifacts.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/verify_lz_operator.jl
using SpinorBEC
using FFTW, Printf, LinearAlgebra

# same grid as the quench/Jz-check runs
grid = make_grid(GridConfig((48, 48, 24), (12.0, 12.0, 6.0)))
plans = make_fft_plans((48, 48, 24); flags=FFTW.ESTIMATE)
xg, yg, zg = grid.x
D = 13; F = 6                                  # Eu spinor, put the vortex in one component

# build a single-component charge-m vortex with Gaussian(σ) radial profile
function vortex_state(m::Int, sigma::Float64; comp::Int=1)
    psi = zeros(ComplexF64, 48, 48, 24, D)
    for k in 1:24, j in 1:48, i in 1:48
        x = xg[i]; y = yg[j]; z = zg[k]
        r2 = x^2 + y^2
        amp = exp(-(r2) / (2sigma^2) - z^2 / (2 * 1.0^2))
        phase = (x + im * y)^abs(m)
        phase = m >= 0 ? phase : conj(phase)
        psi[i, j, k, comp] = amp * phase
    end
    dV = cell_volume(grid)
    psi ./= sqrt(sum(abs2, psi) * dV)           # normalise to ∫|ψ|²dV = 1
    psi
end

@printf("%-6s %-8s %-14s %-12s %s\n", "m", "sigma", "Lz_measured", "error", "verdict")
println("-"^58)
maxerr = 0.0
for m in (0, 1, 2, -1, -2)
    for sigma in (2.5, 1.5, 1.0, 0.7, 0.5)      # smooth -> sharp (higher k)
        psi = vortex_state(m, sigma)
        lz = orbital_angular_momentum(psi, grid, plans)
        err = lz - m
        global maxerr = max(maxerr, abs(err))
        v = abs(err) < 1e-3 ? "ok" : (abs(err) < 0.05 ? "SMALL DRIFT" : "LEAK")
        @printf("%-6d %-8.2f %-14.6f %-12.2e %s\n", m, sigma, lz, err, v)
    end
end
@printf("\nmax |Lz_measured - m| over the sweep = %.3e\n", maxerr)
if maxerr < 1e-3
    println("=> L_z OPERATOR IS EXACT at all σ -> the Jz leak is DYNAMICAL, not measurement.")
    println("   (measurement exonerated; 64^3-from-P1 resolution test is justified.)")
else
    println("=> L_z OPERATOR DRIFTS at high-k -> the MEASUREMENT is (part of) the leak.")
    println("   Physics may conserve Jz; '-0.44' / 'AM lost' need re-reading with a")
    println("   corrected L_z. 64^3 rebuild would be WASTED on a measurement bug.")
end
println("LZ_VERIFY_DONE")
