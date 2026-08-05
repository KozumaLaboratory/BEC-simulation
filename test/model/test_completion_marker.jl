# Cutover step 2, invariant 4: "a cache hit requires a completion marker written
# last, naming the bytes it certifies. An id alone never serves."
#
# The three cheap controls. The expensive one — interrupt a real ITP and assert
# the next run recomputes — is `test_interrupted_run_recomputes.jl`; these run in
# milliseconds and cover the failure modes that need no process control:
#
#   1. TRUNCATION. A payload shorter than its marker records is REJECTED. This
#      is the arm the byte counts exist for, and it is not hypothetical:
#      `_move_scratch_to_final` (`run_registry.jl:681`) is `mv(…; force=true)`,
#      and Julia's `_mv_replace` falls back to `cp` + `rm` when `rename` fails —
#      exactly the `SPINORBEC_SCRATCH_DIR` configuration TSUBAME runs under. A
#      walltime kill during that copy leaves a short file at the final path with
#      no exception anywhere.
#   2. LEGACY. An unmarked payload is ADMITTED, carries `:unmarked`, and warns
#      ONCE per store. Measured at cutover: 671 `.jld2` under `runs/`, zero
#      markers.
#   3. WRITTEN LAST. The marker cannot exist before the bytes it names.
#
# Each has its own canary in-file: an arm that must go the OTHER way. Without
# them, "rejected" would pass against an `admit_payload` that rejects
# everything, and "admitted" against one that admits everything.

using Test
using TOML
using SpinorBEC
using SpinorBEC: marker_path, incomplete_marker_path, write_complete_marker,
    write_incomplete_marker, read_complete_marker, admit_payload,
    CompletionMarker, PayloadEntry, Admission, COMPLETE_MARKER_FORMAT,
    _reset_unmarked_warnings!, code_tree_hash

fixture(dir, name, nbytes) = begin
    p = joinpath(dir, name)
    write(p, rand(UInt8, nbytes))
    p
end

shorten!(p, n) = open(io -> truncate(io, filesize(p) - n), p, "r+")

# Arm (b) is bounded by a date (`MARKER_CUTOVER_UNIX`, W3), so a payload that is
# meant to stand for a PRE-cutover artifact has to actually be older than the
# cutover. A fixture written just now is a run killed after this cutover, which
# is the case the cutoff exists to reject. `touch(p)` can only set "now".
# 2023-11-14 as a literal rather than `MARKER_CUTOVER_UNIX - 1`, so this file
# keeps testing what it tested if the cutoff is reverted on its own.
predate!(p) = (run(pipeline(`touch -d @1700000000 $p`; stdout=devnull)); p)

@testset "the completion marker (cutover step 2, invariant 4)" begin
    @testset "read returns a typed value, not a Dict" begin
        mktempdir() do dir
            p = fixture(dir, "point_001.jld2", 1234)
            mp = write_complete_marker(p, [p]; kind="point", artifact_id="abc123")
            @test mp == marker_path(p)
            @test basename(mp) == "point_001.jld2.complete.toml"
            m = read_complete_marker(mp)
            @test m isa CompletionMarker
            @test !(m isa AbstractDict)
            @test m.format == COMPLETE_MARKER_FORMAT
            @test m.kind == "point"
            @test m.artifact_id == "abc123"
            @test m.code_rev == code_tree_hash()
            @test m.payload isa Vector{PayloadEntry}
            @test m.payload == [PayloadEntry("point_001.jld2", 1234)]
            # The bytes are NAMED, which is the half of invariant 4 an id alone
            # cannot do: the path is relative to the marker, so the directory
            # survives being rsync'd off a compute node.
            @test !occursin(dir, read(mp, String))
        end
    end

    @testset "1. TRUNCATION is rejected" begin
        mktempdir() do dir
            p = fixture(dir, "point_001.jld2", 4096)
            write_complete_marker(p, [p]; kind="point")

            # Canary for this arm: the SAME fixture, untouched, must be a hit.
            # Without it "rejected" would also pass against a function that
            # rejects everything.
            a_ok = admit_payload(p)
            @test a_ok.hit
            @test a_ok.provenance === :marked

            shorten!(p, 100)
            a = admit_payload(p)
            @test !a.hit
            @test a.provenance === :rejected
            @test occursin("4096", a.reason) && occursin("3996", a.reason)
            @test a.marker === nothing
        end
    end

    @testset "1b. a marker naming a file that is GONE is rejected" begin
        mktempdir() do dir
            p = fixture(dir, "point_001.jld2", 512)
            side = fixture(dir, "shared_psi.jld2", 2048)
            # The light-point shape: the point's ψ lives in another file.
            write_complete_marker(p, [p, side]; kind="point")
            @test admit_payload(p).hit
            rm(side)
            a = admit_payload(p)
            @test !a.hit
            @test a.provenance === :rejected
            @test occursin("shared_psi.jld2", a.reason)
        end
    end

    @testset "1c. an unparseable / wrong-version marker is rejected, not ignored" begin
        mktempdir() do dir
            p = fixture(dir, "point_001.jld2", 64)
            write(marker_path(p), "this is not toml [[[")
            @test admit_payload(p).provenance === :rejected

            write(marker_path(p),
                "format = 99\nkind = \"point\"\nwritten_at = \"\"\n[[payload]]\npath = \"point_001.jld2\"\nbytes = 64\n",
            )
            @test admit_payload(p).provenance === :rejected

            # A key nothing reads is the accretion sink — refused, as in model/io.jl.
            write(marker_path(p),
                "format = 1\nkind = \"point\"\nwritten_at = \"\"\nwhoops = 1\n[[payload]]\npath = \"point_001.jld2\"\nbytes = 64\n",
            )
            @test admit_payload(p).provenance === :rejected
        end
    end

    @testset "2. an unmarked legacy payload is ADMITTED as :unmarked" begin
        mktempdir() do dir
            _reset_unmarked_warnings!()
            p1 = predate!(fixture(dir, "point_001.jld2", 128))
            p2 = predate!(fixture(dir, "point_002.jld2", 128))
            a = admit_payload(p1)
            @test a.hit
            @test a.provenance === :unmarked
            @test a.marker === nothing

            # Warned ONCE per store, not once per hit: a 45-point scan directory
            # must not emit 45 identical lines, or the signal reads as noise.
            _reset_unmarked_warnings!()
            @test_logs (:warn,) admit_payload(p1)
            @test_logs admit_payload(p2)          # same store: silent
            @test_logs admit_payload(p1)          # and still silent on a re-hit

            # Canary: a DIFFERENT store warns again, so the silence above is
            # per-store memory and not a warning that stopped working.
            mktempdir() do other
                @test_logs (:warn,) admit_payload(predate!(fixture(other, "point_001.jld2", 8)))
            end
        end
    end

    @testset "2b. the tombstone is what keeps arm (b) from grandfathering NEW kills" begin
        mktempdir() do dir
            p = predate!(fixture(dir, "point_001.jld2", 256))
            # Arm (b) alone cannot tell a pre-cutover artifact from a run killed
            # after its payload landed — they are the same bytes. Two things
            # discriminate them: the writer's own statement (the tombstone, here)
            # and the payload's date (`MARKER_CUTOVER_UNIX`, W3 — hence
            # `predate!`, which is what makes this fixture a legacy artifact
            # rather than a post-cutover kill).
            @test admit_payload(p).provenance === :unmarked
            tp = write_incomplete_marker(
                p, [p]; kind="point", reason="the run was INTERRUPTED mid-solve"
            )
            @test tp == incomplete_marker_path(p)
            a = admit_payload(p)
            @test !a.hit
            @test a.provenance === :rejected
            @test occursin("INTERRUPTED", a.reason)

            # A later run that succeeds over the same payload CLEARS the
            # tombstone — otherwise the cell would be poisoned forever.
            write_complete_marker(p, [p]; kind="point")
            @test !isfile(incomplete_marker_path(p))
            @test admit_payload(p).provenance === :marked

            # ...and symmetrically, a tombstone out-votes a stale completion
            # marker left by an earlier successful run of the same cell.
            write_incomplete_marker(p, [p]; kind="point", reason="diverged")
            @test !isfile(marker_path(p))
            @test admit_payload(p).provenance === :rejected
        end
    end

    @testset "3. the marker is written LAST — it cannot precede its bytes" begin
        mktempdir() do dir
            missing_p = joinpath(dir, "never_written.jld2")
            # Fails CLOSED: a marker for bytes that do not exist is not written
            # at all, so no crash-window can leave one certifying a file that
            # was never produced.
            @test_throws ArgumentError write_complete_marker(missing_p, [missing_p]; kind="point")
            @test !isfile(marker_path(missing_p))

            p = fixture(dir, "point_001.jld2", 100)
            @test_throws ArgumentError write_complete_marker(p, [p, missing_p]; kind="point")
            @test !isfile(marker_path(p))

            # A marker that names nothing certifies nothing.
            @test_throws ArgumentError write_complete_marker(p, String[]; kind="point")

            # And when it IS written, it is written after the payload reached
            # its final size — the recorded count is the size on disk now.
            write_complete_marker(p, [p]; kind="point")
            @test read_complete_marker(marker_path(p)).payload[1].bytes == filesize(p)
            @test mtime(marker_path(p)) >= mtime(p)
        end
    end

    @testset "the marker write is atomic and leaves no scratch behind" begin
        mktempdir() do dir
            p = fixture(dir, "point_001.jld2", 77)
            write_complete_marker(p, [p]; kind="point")
            @test !any(f -> occursin(".tmp.", f), readdir(dir))
            # Deterministic bytes: sorted keys, so two writers of the same value
            # produce the same text apart from the timestamp.
            txt = read(marker_path(p), String)
            @test occursin("[[payload]]", txt)
            d = TOML.parse(txt)
            @test d["format"] == COMPLETE_MARKER_FORMAT
        end
    end

    @testset "a rejection on a SYMLINK payload names the LINK, not truncation" begin
        # `save_rotating_basis_result!` publishes `point_001.jld2` as a symlink
        # to `result.jld2`, and `filesize` follows symlinks. So when the
        # rejected payload is a link, "truncation or partial collection" sends
        # the reader to the wrong file: nothing was truncated, the link is
        # naming different bytes than the marker was written against. That was
        # the actual case in `runs/eu151_edh_k3_compare` — a 3-point scan whose
        # `point_001.jld2` pointed at point 3's data.
        mktempdir() do dir
            a = fixture(dir, "result_a.jld2", 4096)
            b = fixture(dir, "result_b.jld2", 8192)
            link = joinpath(dir, "point_001.jld2")
            symlink("result_a.jld2", link)
            write_complete_marker(link, [link]; kind="point")
            @test admit_payload(link).provenance === :marked   # control

            rm(link)
            symlink("result_b.jld2", link)
            adm = admit_payload(link)
            @test !adm.hit
            @test adm.provenance === :rejected
            @test occursin("SYMLINK", adm.reason)
            @test occursin("result_b.jld2", adm.reason)
            @test !occursin("truncation", adm.reason)

            # NEGATIVE CONTROL on the same predicate: a plain file that is
            # genuinely short still gets the truncation reading, so the branch
            # above is a diagnosis and not a message that replaced the old one.
            p = fixture(dir, "point_002.jld2", 4096)
            write_complete_marker(p, [p]; kind="point")
            shorten!(p, 100)
            plain = admit_payload(p)
            @test plain.provenance === :rejected
            @test occursin("truncation", plain.reason)
            @test !occursin("SYMLINK", plain.reason)
        end
    end

    @testset "an absent payload is a plain miss, not a rejection" begin
        mktempdir() do dir
            a = admit_payload(joinpath(dir, "nothing_here.jld2"))
            @test !a.hit
            @test a.provenance === :absent
        end
    end
end
