# Voxel → buffer index, for kernels reading or writing a field that may live in
# the `[1:n_pts...]` corner of a zero-padded DDI buffer rather than in a
# contiguous array of its own.
#
# `nothing` is the contiguous case and compiles to the bare linear index, so the
# unpadded kernels are byte-for-byte what they were. A `CartesianIndices(n_pts)`
# is the padded case: isbits (so it also passes by value into a CUDA kernel),
# one `_ind2sub` per voxel.
#
# One declaration for both devices. The alternative — materialising the crop,
# `phi[CartesianIndices(n_pts)]` — is an allocation plus a gather per component,
# three per DDI call and twice per ITP step, and was wanted independently by the
# spin-density write, the CPU Euler-angle pre-pass and the GPU rotation's field
# read. `DDI_PADDED_DEFAULT` flipping to `true` (9c117c05) put every production
# run on that path.

@inline _voxel_index(::Nothing, i) = i
@inline _voxel_index(map, i) = @inbounds map[i]
