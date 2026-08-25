# A test whose subject is CACHE ADMISSION must not depend on whether the
# developer has uncommitted work.
#
# THE PROBLEM. `_assert_point_provenance` refuses to reuse a stored point unless
# the point's recorded `env.git_hash` equals the current one AND neither tree was
# dirty. Four tests in the fast tier write a point and then re-run to prove the
# second pass is served from cache. In a working checkout the tree is dirty — that
# is what a working checkout IS — so the second pass throws and the four go red.
#
# They pass in CI, on a clean checkout, and they pass locally right after a
# commit. So the fast tier is red exactly while someone is working in it, which is
# the shape this project has measured getting gates switched off: a test that
# reddens on correct work teaches people to ignore it.
#
# WHY THE OVERRIDE IS CORRECT HERE AND NOT A WEAKENING. In these tests the stored
# point was written by THIS PROCESS seconds earlier, so "was it produced by the
# code running now?" is trivially yes. The gate cannot tell, because a dirty tree
# makes the hash uninformative in general — and the override exists for exactly
# this: `run_registry.jl` says to set it "if you know the difference cannot
# matter", and here it provably cannot.
#
# What is NOT weakened: `admit_payload` runs BEFORE the provenance check and does
# the admission counting these tests read, so the numbers are unchanged. And the
# provenance gate keeps its own file — `test/workflow/test_run_dir_provenance_gate.jl`
# — where the subject IS the refusal and the env is controlled deliberately.

export with_cacheable_tree

"""
    with_cacheable_tree(f)

Run `f` with `SPINORBEC_ALLOW_STALE_POINTS=1`.

For a test that needs a second `run_yaml` to hit the cache and is NOT about the
provenance gate. Do not reach for this to silence a refusal you have not
explained: the override is right here because the point was written by the same
process, and that reasoning has to hold at every new call site.
"""
with_cacheable_tree(f::Function) =
    withenv(f, "SPINORBEC_ALLOW_STALE_POINTS" => "1")
