using SpinorBEC
atom = SpinorBEC.resolve_atom(:Eu151_f1_effective)
@assert atom.F == 1
println("atom F=", atom.F, " a_s=", atom.a_s, " mu=", atom.mu_mag)
println("precondition OK")
