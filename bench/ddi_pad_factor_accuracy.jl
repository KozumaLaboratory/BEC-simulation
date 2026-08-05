# How much zero-padding the open-boundary DDI actually needs.
#
#   LD_LIBRARY_PATH=... julia --project=. bench/ddi_pad_factor_accuracy.jl [N]
#
# `ddi_pad_factor` defaults to 2 in every axis, so the convolution runs on 8× the
# voxels. Since `DDI_PADDED_DEFAULT` flipped to `true` (9c117c05) that is every
# production run, and at 128³ those six rFFTs on a 256³ grid are more than half
# the RTP step — the largest single item left after the fused half-step.
#
# 9c117c05 measured what the padding BUYS: the bare periodic kernel carries a
# 2.1e-2 to 4.7e-2 dipolar field error against free space, flat in resolution.
# Nobody measured what it COSTS to buy less of it. The padding removes periodic
# images, and image strength falls like 1/r³ with the image distance, so the
# error should fall steeply in `pad_factor` and a factor of 2 may be far more
# than needed.
#
# Reference is pad_factor 3 rather than an analytic form: the question is not
# "what is Φ" but "how much does Φ still move as the box grows", which is the
# same convergence question the padding exists to answer, and it needs no second
# implementation to be trusted. The bare (unpadded) arm is the positive control —
# it must show the ~2e-2 that commit reported, or the meter is not measuring the
# thing it claims to.

import CUDA
using SpinorBEC
using Printf
using LinearAlgebra: norm

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 48
const PAD_REF = 3.0

function build(; pad::Union{Nothing, Float64}, n=N_GRID)
    grid = make_grid(GridConfig(ntuple(_ -> n, 3), ntuple(_ -> 12.0, 3)))
    sp = SimParams(; dt=1e-4, n_steps=1, imaginary_time=false, save_every=10^9)
    kw = pad === nothing ? (; ddi_padding=false) :
         (; ddi_padding=true, ddi_pad_factor=pad)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
        sim_params=sp, enable_ddi=true, c_dd=EU_c_dd,
        backend=CUDABackend(), kw...,
    )
    psi = init_psi(grid, ws.spin_matrices.system;
        state=:spin_coherent, init_theta=0.6, init_phi=0.4)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    copyto!(ws.state.psi, psi)
    ws
end

"Φ on the physical grid, as three host arrays."
function phi_of(ws)
    sm = ws.spin_matrices
    D = sm.system.n_components
    n_pts = ntuple(d -> size(ws.state.psi, d), 3)
    if ws.ddi_padded === nothing
        SpinorBEC._compute_and_convolve_ddi!(
            ws.state.psi, sm, ws.ddi, ws.ddi_bufs, Val(D), 3, n_pts)
        CUDA.synchronize()
        b = ws.ddi_bufs
        return (Array(b.Phi_x), Array(b.Phi_y), Array(b.Phi_z))
    end
    p = ws.ddi_padded
    SpinorBEC._compute_and_convolve_ddi_padded!(
        ws.state.psi, sm, ws.ddi, p, Val(D), 3, n_pts)
    CUDA.synchronize()
    c = CartesianIndices(n_pts)
    (Array(p.Phi_x_pad)[c], Array(p.Phi_y_pad)[c], Array(p.Phi_z_pad)[c])
end

rel_err(a, b) = sqrt(sum(norm(a[i] - b[i])^2 for i in 1:3)) /
                sqrt(sum(norm(b[i])^2 for i in 1:3))

"ms per RTP step at this padding."
function ms_per_step(ws; k=10, samples=3)
    step!(m) = (for _ in 1:m
        SpinorBEC.split_step!(ws)
    end; CUDA.synchronize())
    step!(3)
    best = Inf
    for _ in 1:samples
        t0 = time_ns()
        step!(k)
        best = min(best, (time_ns() - t0) * 1e-6 / k)
    end
    best
end

function main()
    @printf("DDI pad_factor — %s, Eu151 F=6 (D=13) F64, %d³ box 12\n",
        CUDA.name(CUDA.device()), N_GRID)
    @printf("  reference: pad_factor = %.1f\n\n", PAD_REF)

    ref = phi_of(build(; pad=PAD_REF))
    GC.gc(true);
    CUDA.reclaim()

    @printf("  %-14s %14s %14s %10s\n",
        "pad_factor", "rel. Φ error", "ms/RTP step", "FFT voxels")
    for pad in (nothing, 1.25, 1.5, 1.75, 2.0, 2.5)
        ws = build(; pad)
        e = rel_err(phi_of(ws), ref)
        t = ms_per_step(ws)
        vox = pad === nothing ? 1.0 : Float64(pad)^3
        lbl = pad === nothing ? "none (bare)" : @sprintf("%.2f", pad)
        @printf("  %-14s %14.3e %14.3f %9.2f×\n", lbl, e, t, vox)
        ws = nothing
        GC.gc(true)
        CUDA.reclaim()
    end
    println("\n  The `none` row is the positive control: 9c117c05 measured the bare")
    println("  periodic kernel at 2.1e-2 to 4.7e-2 against free space, so a value")
    println("  far below that would mean this meter is not seeing the images.")
end

main()
