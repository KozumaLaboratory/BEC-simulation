using Test
import CUDA
using SpinorBEC

# The CUDA extension's device caches must key on the objects they describe.
#
# Three of them keyed on a bare `objectid` (or a hash of one) and held no
# reference to the object:
#
#   `_get_gpu_raman_cache`   hash((objectid(sm), k_eff, N_spatial, D, T))
#   `_device_lhy_table`      (objectid(l), RT)
#   `_device_spatial_table`  objectid(l)
#
# Two distinct defects follow. The first is an outright key omission: the Raman
# cache's `kr` field is `k_eff · r` built from `grid.x`, and `grid` was not in
# the key — only `N_spatial`. So two grids sharing a point count collided, and
# 32x32x16 and 64x16x16 are both 16384, as is the same shape in a different box.
#
# MEASURED on an RTX 5070 Ti, 2026-08-08, two 8^3 grids at box 6.0 and 12.0:
#
#   old key   same cache object returned: true    max|kr_A - kr_B| = 0.0
#   new key   same cache object returned: false   max|kr_A - kr_B| = 2.625
#
# and 2.625 is exactly max|kr_A| — doubling the box doubles k·r, so the
# difference equals the original. The second grid was being handed the first
# grid's phase, silently and exactly.
#
# The second defect is the bare `objectid`: it is address-derived for a struct
# with Vector fields, and with no reference held the id is reusable after GC, so
# a later object landing on the same address inherits a stale device table. All
# three now go through `SpinorBEC.scratch_get!`, an `IdDict` whose key tuple
# holds the objects — which pins them and makes the id unreusable. That is the
# mechanism `_to_device_cached` documents, and `foundation/scratch.jl` says the
# registry exists to replace exactly these ad-hoc IdDicts.

if !CUDA.functional()
    @info "CUDA not functional — skipping GPU device-cache key gate"
else
    const _EXT = Base.get_extension(SpinorBEC, :SpinorBECCUDAExt)

    @testset "GPU device caches key on the object, not its address" begin
        sm = spin_matrices(1)
        ram = RamanCoupling{3}(0.5, 0.0, (1.0, 0.0, 0.0))
        psi = CUDA.zeros(ComplexF64, 8, 8, 8, 3)

        gA = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
        gB = make_grid(GridConfig((8, 8, 8), (12.0, 12.0, 12.0)))

        cA = _EXT._get_gpu_raman_cache(psi, sm, ram, gA, 3)
        cB = _EXT._get_gpu_raman_cache(psi, sm, ram, gB, 3)

        # CALIBRATION. The two grids must genuinely differ in the quantity the
        # cache derives, or "they get different entries" proves nothing.
        @testset "the two grids give different k·r" begin
            @test gA.config.box_size != gB.config.box_size
            @test prod(gA.config.n_points) == prod(gB.config.n_points)  # the collision
            krA, krB = Array(cA.kr), Array(cB.kr)
            @test maximum(abs, krA) > 1e-6
            @test maximum(abs, krA .- krB) > 1e-6
            # doubling the box doubles k·r, so the difference IS the original
            @test maximum(abs, krA .- krB) ≈ maximum(abs, krA) rtol = 1e-12
        end

        @testset "different grids are not served the same cache" begin
            @test !(cA === cB)
        end

        # NEGATIVE CONTROL: it must still be a cache. Keying on more must not
        # trade a wrong answer for a rebuilt device buffer on every step.
        @testset "the same (sm, grid, k_eff) still reuses" begin
            @test _EXT._get_gpu_raman_cache(psi, sm, ram, gA, 3) === cA
            @test _EXT._get_gpu_raman_cache(psi, sm, ram, gB, 3) === cB
        end

        # The LHY tables: same registry, same contract. Two tables with
        # different content must not share a device buffer.
        @testset "the LHY device tables key on the table" begin
            mkws(c0) = make_workspace(;
                grid=make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0))),
                atom=Rb87, interactions=InteractionParams(Dict(0 => c0, 1 => 0.02)),
                potential=HarmonicTrap((1.0, 1.0, 1.0)),
                spinor_lhy=:polar_contact, backend=CUDABackend(),
                sim_params=SimParams(; dt=1.0e-3, n_steps=1, save_every=1))

            wsA, wsB = mkws(1.0), mkws(4.0)
            @test wsA.lhy isa SpinorBEC.TabulatedLHY
            @test wsB.lhy isa SpinorBEC.TabulatedLHY

            # CALIBRATION: the two tables must genuinely differ, or "they get
            # different entries" is vacuous.
            @test maximum(abs, wsA.lhy.potential_values .-
                               wsB.lhy.potential_values) > 1e-12

            proto = CUDA.zeros(Float64, 8)
            t1 = _EXT._device_lhy_table(wsA.lhy, Float64, proto)
            @test _EXT._device_lhy_table(wsA.lhy, Float64, proto) === t1  # cached
            t2 = _EXT._device_lhy_table(wsB.lhy, Float64, proto)
            @test !(t2 === t1)
            @test maximum(abs, Array(t2) .- Array(t1)) > 1e-12
        end

        # Not every `objectid` key is a defect, and banning the token outright
        # would be the enumeration-instead-of-property mistake. The four below
        # are SAFE for a reason worth stating: their cached content is a
        # function of the OTHER key components, so `objectid` is redundant and a
        # collision serves a correct value.
        #
        #   gpu_spin_mixing.jl:33          hash((objectid(sm), N, D, T))
        #   gpu_ddi_rotation.jl:28         hash((objectid(sm), N, D, T))
        #   gpu_spin_rotation_taylor.jl:47 hash((objectid(sm), D, T))
        #       V / λ / m_vals / the tridiagonal bands are the spin algebra —
        #       fixed by D and T alone. (Note the reason is NOT "the value keeps
        #       a reference to `sm`": `GPUSMCache` and `SpinTridiagCoef` hold
        #       only CuArrays and a scalar. Checked, because that WAS the
        #       explanation offered and it is wrong.)
        #   gpu_energy.jl:27               hash((objectid(ws), size(psi)))
        #       pure scratch buffers, sized by `size(psi)`, which is in the key.
        #
        # The three that were NOT safe are the ones fixed here: the Raman cache
        # derived `kr` from a `grid` absent from the key, and the two LHY tables
        # cached the object's OWN data with nothing else identifying it.
        @testset "every objectid key in the extension is a declared-safe one" begin
            root = normpath(joinpath(@__DIR__, "..", "..", "ext",
                "SpinorBECCUDAExt"))
            expected = Set([
                "gpu_spin_mixing.jl", "gpu_ddi_rotation.jl",
                "gpu_spin_rotation_taylor.jl", "gpu_energy.jl",
            ])
            found = Dict{String, Int}()
            for f in readdir(root; join=true)
                endswith(f, ".jl") || continue
                for l in eachline(f)
                    startswith(strip(l), "#") && continue
                    occursin("objectid(", l) &&
                        (found[basename(f)] = get(found, basename(f), 0) + 1)
                end
            end
            surprises = setdiff(keys(found), expected)
            isempty(surprises) || println(
                "\n  a new objectid-keyed cache appeared in: ",
                join(sort(collect(surprises)), ", "),
                "\n  Either its content is fixed by the rest of the key — then add it\n",
                "  to `expected` with that reason — or it is the Raman/LHY defect again.")
            @test isempty(surprises)

            # POSITIVE CONTROL: the scan must still SEE the declared four, or an
            # empty `surprises` means the walk read nothing.
            @test length(intersect(keys(found), expected)) == 4

            # and the three fixed caches must be on the registry
            uses = 0
            for f in readdir(root; join=true)
                endswith(f, ".jl") || continue
                uses += count(l -> !startswith(strip(l), "#") &&
                                   occursin("scratch_get!", l), collect(eachline(f)))
            end
            @test uses >= 3
        end
    end
end
