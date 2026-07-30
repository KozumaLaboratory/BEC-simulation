using SpinorBEC, JLD2, CodecZstd
CELLS = [
  ("K3=0, LHY=off",            "LHY_off_K0_2e71a8ce",          0,   "off"),
  ("K3=0, LHY=scalar",         "LHY_scalar_K0_7fa5a5de",       0,   "scalar"),
  ("K3=0, LHY=polar_contact",  "LHY_polar_contact_K0_b7492d26",0,   "polar_contact"),
  ("K3=0, LHY=icosa",          "LHY_icosahedral_K0_026053aa",  0,   "icosa"),
  ("K3=200, LHY=off",          "LHY_off_9ed79424",             200, "off"),
  ("K3=200, LHY=scalar",       "LHY_scalar_41f93da5",          200, "scalar"),
  ("K3=200, LHY=polar_contact","LHY_polar_contact_f142b6fb",   200, "polar_contact"),
  ("K3=200, LHY=icosa",        "LHY_icosahedral_35a4ee80",     200, "icosa"),
]
rows = Any[]
for (label, dir, k3, lhy) in CELLS
    # Two output trees: the six LHY-enabled cells landed on the work volume
    # before the group quota was raised, the two `off` controls on /gs/fs.
    ROOTS = ["runs", "/gs/bs/work/7/uk07267/BEC-lhy-rerun/runs"]
    f = ""
    for R in ROOTS
        cand = joinpath(R, dir, "point_001.jld2")
        isfile(cand) && (f = cand; break)
    end
    isempty(f) && (@warn "missing" dir; continue)
    pk, nr, cp = jldopen(f, "r") do io
        (io["dynamics/peak_density"], io["dynamics/norms"],
         io["dynamics/component_populations"])
    end
    r  = open_result(f)
    nfr = nr[end] / nr[1]
    cls = SpinorBEC.classify_collapse(pk, nfr)
    # `ratio` in the original is the peak growth factor, peaks[argmax]/peaks[1].
    ratio = maximum(pk) / pk[1]
    # top3 populations at the final frame, m = +F .. -F over the component axis
    F = r.atom.F
    finalpop = cp isa AbstractMatrix ? cp[end, :] : cp[end]
    ord = sortperm(collect(finalpop); rev=true)[1:min(3, length(finalpop))]
    top3 = [Dict("m" => F - (c - 1), "N_m" => Float64(finalpop[c])) for c in ord]
    push!(rows, Dict(
        "label" => label, "K3" => k3, "LHY" => lhy,
        "classification" => String(cls), "status" => "OK",
        "peak_max" => Float64(maximum(pk)),
        "Fz_per_N" => Float64(last(r.Fz_t)),
        "N_final_ratio" => Float64(nfr),
        "ratio" => Float64(ratio),
        "top3" => top3))
end
# Hand-emitted JSON: JSON3/JSON are not in this project's deps and adding one
# for an eight-row file is not worth a Manifest change.
function jstr(x)
    x isa AbstractString && return "\"" * x * "\""
    x isa Integer && return string(x)
    x isa AbstractFloat && return string(x)
    x isa AbstractDict && return "{" * join([jstr(String(k)) * ": " * jstr(v)
                                             for (k, v) in x], ", ") * "}"
    x isa AbstractVector && return "[" * join(jstr.(x), ", ") * "]"
    error("unhandled $(typeof(x))")
end
open("factorial_2x4_new.json", "w") do io
    println(io, "{")
    println(io, "  \"rows\": [")
    for (i, r) in enumerate(rows)
        println(io, "    ", jstr(r), i == length(rows) ? "" : ",")
    end
    println(io, "  ]")
    println(io, "}")
end
println("wrote $(length(rows)) rows")
for r in rows
    println("  ", rpad(r["label"], 28), rpad(r["classification"], 20),
            " Fz/N=", round(r["Fz_per_N"]; digits=5),
            " N(T)/N(0)=", round(r["N_final_ratio"]; digits=4))
end
