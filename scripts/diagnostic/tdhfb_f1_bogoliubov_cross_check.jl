# T100: TDHFB generic-F kernel Tier-3 cross-validation — F1/F2/F3 falsifiers + F4 advisory.
using SpinorBEC, LinearAlgebra

function bdg_omegas(zeta, c0, c1, mu, F=1; ks=exp10.(range(-3.0, -2.0, length=10)))
    D = 2F + 1;
    phi = zeros(ComplexF64, 1, D);
    phi[1, :] .= zeta
    rho = zeros(ComplexF64, 1, D, D)
    g_S = SpinorBEC.ku_c01_to_g_S(F, c0, c1)
    h_hf = SpinorBEC.hf_matrix_generic(phi, rho, F, g_S)[1, :, :]
    V = SpinorBEC.channel_kernel(F, g_S)
    Delta = zeros(ComplexF64, D, D)
    for m in 1:D, mp in 1:D, m2 in 1:D, m2p in 1:D
        Delta[m, mp] += V[m, mp, m2, m2p] * phi[1, m2] * phi[1, m2p]
    end
    Id = Matrix{ComplexF64}(I, D, D)
    function L_eigs(k)
        H = (0.5k^2 + 0im) .* Id .+ h_hf .- mu .* Id
        sort(abs.(real.(eigvals([H Delta; -conj.(Delta) -conj.(H)]))))
    end
    pos_min(k) = (e=L_eigs(k); e[findfirst(>(1e-10), e)])
    omegas = [pos_min(k) for k in ks]
    return omegas, ks, minimum(L_eigs(0.0))
end

t0 = time()
om_p, ks, gst = bdg_omegas(ComplexF64[0, 1, 0], 1.0, 0.1, 1.0)   # F1 polar
cs_polar = sum(om_p .* ks) / sum(ks .^ 2)   # least-squares cs through origin: ω = cs·k
om_f, ks2, _ = bdg_omegas(ComplexF64[1, 0, 0], 1.0, -0.1, 0.9)   # F2 FM
cs_fm = sum(om_f .* ks2) / sum(ks2 .^ 2)
phi_p = zeros(ComplexF64, 1, 3);
phi_p[1, 2] = 1.0                 # F3 ratio
z = zeros(ComplexF64, 1, 3, 3)
h_bdg = real(
    SpinorBEC.hf_matrix_generic(phi_p, z, 1, SpinorBEC.ku_c01_to_g_S(1, 1.0, 0.1))[1, 2, 2]
)
h_gp = real(SpinorBEC.hf_matrix_F1(phi_p, z, z, 1.0, 0.1)[1, 2, 2])
ratio = h_bdg / h_gp
wt = time() - t0
println(
    "{\"F1_cs_polar\":$cs_polar,\"F2_cs_fm\":$cs_fm,\"F3_ratio\":$ratio,\"F4_goldstone_omega_at_k0\":$gst,\"wall_time_sec\":$wt}",
)
