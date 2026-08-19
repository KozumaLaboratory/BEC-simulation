# --- The one statement of the Wick rotation ---
#
# Every split-step substep applies `exp(-i·X·dt)` in real time and, under the
# Wick rotation t → -iτ, `exp(-X·dτ)` in imaginary time. That is ONE branch on
# ONE exponent, and before 2026-08-19 it was written out by hand at eight
# propagator sites in seven files — with the minus sign in a different place at
# each:
#
#   split_step_kernels.jl   psi[I] *= imaginary_time ? exp(arg) : cis(arg)
#   light_shift_builders.jl v[k]   *= imaginary_time ? exp(-phase_arg) : cis(-phase_arg)
#   lhy_term.jl             phase = imaginary_time ? exp.(.-V .* dt) : cis.(.-V .* dt)
#   zeeman.jl               factor = imaginary_time ? exp(-(coef - shift)*dt) : cis(-coef*dt)
#   tensor_interaction.jl   phase = imaginary_time ? exp(-real(h[c,c])*dt) : cis(...)
#   propagators.jl          kp[I,1] = (imaginary_time ? complex(exp(arg)) : cis(arg)) * inv_npts
#
# Every one of those is the same function of the same argument, so the variation
# is pure surface — and surface is where a sign goes wrong. The `zeeman.jl` arm
# read as asymmetric between its branches (the ITP overflow `shift` appears in
# one and not the other) when in fact `shift` is already `0.0` in real time, so
# the two branches share an exponent like all the others. Reading it took a
# minute; the point of this file is that nobody has to.
#
# CONVENTION, declared once: `arg` is the COMPLETE exponent, sign included. A
# substep propagating `exp(-i·X·dt)` passes `arg = -X*dt`. Do not pass `X*dt`
# and expect the function to negate it — the caller owns the physics, this
# owns the rotation.
#
# `wick_phase` returns `Union{T, Complex{T}}`: the real branch really is real,
# and every call site multiplies it into a complex array where a real factor is
# half the flops. That union is exactly what the hand-written ternaries already
# produced, so inlining this reproduces the previous code instruction for
# instruction — the migration is bit-identical by construction, which is what
# `test/oracles/test_wick_phase_single_statement.jl` pins.

export wick_phase

"""
    wick_phase(arg::Real, imaginary_time::Bool)

Propagator phase for one substep, given the COMPLETE exponent `arg`.

    imaginary_time == false  →  cis(arg)  ==  exp(im * arg)
    imaginary_time == true   →  exp(arg)

A substep propagating `exp(-i·X·dt)` calls `wick_phase(-X * dt, it)`. The sign
belongs to the caller; the rotation belongs here.

Returns a real number on the imaginary-time branch. That is deliberate: the
callers multiply it into a `Complex` array, and a real factor costs two flops
where a complex one costs six.
"""
@inline wick_phase(arg::Real, imaginary_time::Bool) =
    imaginary_time ? exp(arg) : cis(arg)

"""
    wick_phase(args::AbstractArray, imaginary_time::Bool)

Materialising form — allocates the phase array for a whole grid at once.

The branch is hoisted OUT of the broadcast rather than evaluated per element
(`wick_phase.(args, ::Bool)` would test the same `Bool` once per voxel and
produce a `Union`-eltype array — see the `Val` methods below for the form that
fuses instead).
"""
@inline wick_phase(args::AbstractArray{<:Real}, imaginary_time::Bool) =
    imaginary_time ? exp.(args) : cis.(args)

"""
    wick_phase(arg, ::Val{true})   → exp(arg)
    wick_phase(arg, ::Val{false})  → cis(arg)

Type-level branch, for the FUSED sites: `psi .*= wick_phase.(expr, itv)` where
`itv = Val(imaginary_time)` is built once outside the broadcast.

This is the form the diagonal propagator needs. Those call sites cannot use the
materialising method (it would allocate a grid-sized phase array they exist to
avoid) and cannot use the `Bool` method (a `Union{T,Complex{T}}` element type
is not `isbits`, so it will not cross into a CUDA kernel and costs a branch per
voxel on the host). With `Val` the eltype is concrete, the broadcast fuses into
the multiply, and the only cost is one 2-way union split per CALL.

The point is not the branch — it is that the physics beside it gets written
ONCE. Before 2026-08-19, 14 of the 32 `if imaginary_time` blocks in the tree
carried a full copy of their exponent in each arm, e.g.

    if imaginary_time
        @. psi_c *= exp(-(V_trap + zee_rel + c0_t * density_buf) * dt_t)
    else
        @. psi_c *= cis(-(V_trap + zee_rel + c0_t * density_buf) * dt_t)
    end

which is a Hamiltonian term stated twice, three tokens apart, with nothing
checking that the copies agree. That is the same defect shape as the second
`B→p` converter, at a smaller radius.
"""
@inline wick_phase(arg::Real, ::Val{true}) = exp(arg)
@inline wick_phase(arg::Real, ::Val{false}) = cis(arg)
