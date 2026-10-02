# Probe removal of one host scalar readback per spin component.
# julia --project=. bench/energy_kinetic_device.jl [8,64,128]
import CUDA
using SpinorBEC

source_path = "ext/SpinorBECCUDAExt/gpu_energy.jl"
source = read(source_path, String)
start = findfirst("function _gpu_energy_and_optional_grad(", source)
stop = findfirst("# Energy-only entry", source)
body = source[first(start):(first(stop) - 1)]
initial = "E_kin = 0.0"
reduction = if occursin("_gpu_energy_sum", body)
    "E_kin += 0.5 * invn * _gpu_energy_sum((k, p) -> k * abs2(p), ksq, fftb) * dV"
else
    "E_kin += 0.5 * invn * real(sum(ksq .* abs2.(fftb))) * dV"
end
finish = "    # Trap: direct energy"
@assert all(occursin(needle, body) for needle in (initial, reduction, finish))
probe = replace(body,
    initial => """
    kinetic_terms = SpinorBEC.scratch_get!(:gpu_kinetic_terms_probe, (typeof(psi), n_comp)) do
        CUDA.zeros(Float64, n_comp)
    end
    """,
    reduction => """
    integrand = Base.Broadcast.instantiate(Base.Broadcast.broadcasted((k, p) -> k * abs2(p), ksq, fftb))
    reduced = mapreduce(identity, +, integrand; dims=ntuple(identity, Val(N)))
    view(kinetic_terms, c:c) .= (0.5 * invn * dV) .* vec(reduced)
    """,
    finish => "    E_kin = sum(kinetic_terms)\n" * finish)
Base.include_string(Base.get_extension(SpinorBEC, :SpinorBECCUDAExt), probe,
    "kinetic_device_probe.jl")
# The existing A/B harness loads the unmodified on-disk core as its reference.
pushfirst!(ARGS, source_path)
include("energy_reduction_ab.jl")
