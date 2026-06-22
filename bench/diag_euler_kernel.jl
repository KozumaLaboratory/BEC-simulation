# Diagnose register / local-memory usage of the DDI euler kernel.
# Local-memory bytes > 0 ⇒ the MVector spinor/tmp spilled to (slow) local
# memory — the suspected occupancy bottleneck. Card-independent diagnosis.
import CUDA
using SpinorBEC
using StaticArrays: MVector

const Ext = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

function build(N, ::Type{T}) where {T}
    D = 13
    P = CUDA.zeros(Complex{T}, N, D)
    px = CUDA.zeros(T, N); py = CUDA.zeros(T, N); pz = CUDA.zeros(T, N)
    m = CUDA.zeros(T, 1, D); λ = CUDA.zeros(T, 1, D)
    V = CUDA.zeros(Complex{T}, D, D); cV = CUDA.zeros(Complex{T}, D, D)
    (P, px, py, pz, m, λ, V, cV)
end

for T in (Float64, Float32)
    P, px, py, pz, m, λ, V, cV = build(128^3, T)
    k = Ext._ddi_euler_kernel!
    ck = CUDA.@cuda launch=false k(P, px, py, pz, m, λ, V, cV, T(0.0025), Val(13), Val(false))
    reg  = CUDA.registers(ck)
    lmem = CUDA.memory(ck).local
    smem = CUDA.memory(ck).shared
    cmem = CUDA.memory(ck).constant
    println("== _ddi_euler_kernel  T=$T ==")
    println("  registers/thread : $reg")
    println("  local  mem/thread: $lmem bytes  <-- spill if >0")
    println("  shared mem/block : $smem bytes")
    println("  const  mem       : $cmem bytes")
    # occupancy
    cfg = CUDA.launch_configuration(ck.fun)
    println("  suggested threads: $(cfg.threads), blocks: $(cfg.blocks)")
end
println("DONE")
