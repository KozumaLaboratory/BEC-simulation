# Emit the data behind docs/figs/lhy_full_bdg_uv_convergence.png:
# ε_LHY from the general-spinor BdG zero-point integral as a function of the
# momentum cutoff, for the pre-2026-07-27 UV subtraction and the current one,
# against the closed forms.
#
#   julia --project=. scripts/lhy_full_bdg_uv_data.jl [out.csv]

using SpinorBEC
using SpinorBEC: _bdg_contact_matrices, _lhy_bdg_energy_density, _gauss_legendre,
    lhy_energy_polar, lhy_energy_fm, build_polar_lhy_coefs, build_fm_lhy_coefs,
    _c0c1_to_gS
using LinearAlgebra

# The pre-fix subtraction, verbatim in structure: the per-branch asymptote
# `mu_b` was built INCLUDING ek and then ek was subtracted again, and the
# branch was labelled by the dominant component of the eigenvector.
function lhy_prefix(spinor, n0, F, ip, k_max, n_k)
    D = 2F + 1
    h_mf, M_anom, zee, _ = _bdg_contact_matrices(spinor, F, ip, ZeemanParams())
    mu = real(dot(spinor, (Diagonal(zee) .+ n0 .* h_mf) * spinor))
    k_values = collect(range(1e-6, k_max; length=n_k))
    dk = k_values[2] - k_values[1]
    E = 0.0
    for k in k_values
        ek = k^2 / 2
        L = 2n0 .* h_mf
        for i in 1:D
            L[i, i] += ek - mu + zee[i]
        end
        M_sc = n0 .* M_anom
        H = zeros(ComplexF64, 2D, 2D)
        H[1:D, 1:D] .= L
        H[1:D, (D + 1):(2D)] .= M_sc
        H[(D + 1):(2D), 1:D] .= .-conj.(M_sc)
        H[(D + 1):(2D), (D + 1):(2D)] .= .-conj.(L)
        ef = eigen(H)
        zpe = 0.0
        for (eb, ev) in enumerate(ef.values)
            omega = real(ev)
            omega > 1e-10 || continue
            c_star = argmax(abs2.(view(ef.vectors, 1:D, eb)))
            mu_b = ek + n0 * real(h_mf[c_star, c_star]) - mu + zee[c_star]
            zpe += 0.5 * (omega - ek - mu_b + mu_b^2 / (2.0 * max(ek, 1e-30)))
        end
        E += k^2 * zpe * dk / (2.0 * π^2)
    end
    E
end

const CASES = (
    (label="F=1 polar", F=1, c0=10.0, c1=0.5,
        spinor=ComplexF64[0, 1, 0], ansatz=:polar),
    (label="F=6 polar", F=6, c0=10.0, c1=0.1,
        spinor=ComplexF64[c == 7 ? 1.0 : 0.0 for c in 1:13], ansatz=:polar),
    (label="F=6 FM", F=6, c0=10.0, c1=-0.1,
        spinor=ComplexF64[c == 1 ? 1.0 : 0.0 for c in 1:13], ansatz=:fm),
)

out = length(ARGS) >= 1 ? ARGS[1] : "lhy_full_bdg_uv.csv"
kmaxes = round.(exp.(range(log(4.0), log(120.0); length=28)); digits=4)

open(out, "w") do io
    println(io, "case,k_max,eps_prefix,eps_fixed,eps_closed")
    for c in CASES
        ip = InteractionParams(Dict(0 => c.c0, 1 => c.c1))
        g = _c0c1_to_gS(c.F, c.c0, c.c1)
        closed = if c.ansatz === :polar
            lhy_energy_polar(1.0, build_polar_lhy_coefs(c.F, g))
        else
            lhy_energy_fm(1.0, build_fm_lhy_coefs(c.F, g))
        end
        for km in kmaxes
            nk = max(200, round(Int, 12 * km))
            pre = lhy_prefix(c.spinor, 1.0, c.F, ip, km, nk)
            fix = _lhy_bdg_energy_density(c.spinor, 1.0, c.F, ip, ZeemanParams(),
                0.0, km, min(nk, 400), 1)
            println(io, "$(c.label),$km,$pre,$fix,$closed")
        end
        println(stderr, "done: $(c.label)  closed=$closed")
    end
end
println("wrote $out")
