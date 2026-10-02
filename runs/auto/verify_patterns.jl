using SpinorBEC

length(ARGS) == 1 || error("usage: verify_patterns.jl <patterns.jl>")
patterns = SpinorBEC._load_julia_config(ARGS[1])
println("active pattern ids: ", [entry["id"] for entry in patterns["patterns"]])
println("proposed_classes count: ", length(patterns["proposed_classes"]))
println("rejected ids: ", [entry["id"] for entry in get(patterns, "rejected_classes", [])])
println("audit_history count: ", length(patterns["audit_history"]))
println("last audit run_at: ", last(patterns["audit_history"])["run_at"])
