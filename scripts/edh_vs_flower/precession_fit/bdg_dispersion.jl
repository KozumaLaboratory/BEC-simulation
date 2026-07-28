using SpinorBEC, LinearAlgebra, JSON
F = 6; D = 2F + 1
spinor = zeros(ComplexF64, D); spinor[D] = 1.0 + 0im
inter = InteractionParams(Dict(0 => 2343.5, 1 => 65.1))
zee = ZeemanParams(0.385, 0.0)
cdd = 211.0; n0 = 0.008
kmax = 2.0; nk = 60

# per k, the lowest few POSITIVE real eigenfreqs (the physical branches)
function branches(res, nlow=3)
    nk = length(res.k_values)
    out = fill(NaN, nlow, nk)
    for ik in 1:nk
        pos = sort(real.(res.omega[:, ik]))
        pos = pos[pos .> 1e-9]
        for b in 1:min(nlow, length(pos)); out[b, ik] = pos[b]; end
    end
    out
end

cases = Dict()
for (name, kdir) in [("zpar", (0.,0.,1.)), ("xperp", (1.,0.,0.))]
    for (dtag, cval) in [("noDDI", 0.0), ("DDI", cdd)]
        r = bogoliubov_spectrum(; spinor, n0, F, interactions=inter, zeeman=zee,
                                c_dd=cval, k_max=kmax, n_k=nk, k_direction=kdir)
        cases["$(name)_$(dtag)"] = Dict("k"=>r.k_values, "br"=>branches(r), "unstable"=>r.unstable)
    end
end
open(ARGS[1], "w") do io
    JSON.print(io, Dict("cases"=>cases, "omega_L"=>0.385, "n0"=>n0, "cdd"=>cdd))
end
println("wrote ", ARGS[1])
