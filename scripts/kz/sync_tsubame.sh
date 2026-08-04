#!/bin/bash
# Sync the TSUBAME worktree by GIT, not by rsyncing individual files.
#
# rsync of individual files is why provenance was unestablishable twice in one
# day: the remote tree is permanently dirty, its HEAD says nothing about what is
# in the files, and "did my change land" is answered by comparing md5s by hand —
# which is to say, sometimes not answered. Once the remote spgpe.jl matched
# neither the commit nor what I believed I had sent; once
# measurement_provenance.jl was a formatter revision behind. Both were caught by
# luck.
#
# With `git fetch && reset --hard <sha>` the remote tree is CLEAN and its HEAD is
# a commit that exists on origin, so "what produced this measurement" has an
# answer that does not depend on my bookkeeping. It also makes a
# refuse-if-dirty gate in the submit script meaningful rather than something to
# bypass on every run — a gate that is always overridden is worse than no gate.
#
#   scripts/kz/sync_tsubame.sh [branch]
set -euo pipefail
BRANCH=${1:-$(git rev-parse --abbrev-ref HEAD)}
REMOTE_BRANCH=${SBEC_REMOTE_BRANCH:-feat/spgpe-full-reservoirs}
PROOT=${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/spgpe_evap}
HOST=${SPINORBEC_TSUBAME_HOST:-tsubame}

if [ -n "$(git status --porcelain)" ]; then
    echo "local tree is dirty — commit before syncing, or the remote will run" >&2
    echo "something that is not in history:" >&2
    git status --porcelain >&2
    exit 1
fi
git push -q origin "HEAD:${REMOTE_BRANCH}"
SHA=$(git rev-parse HEAD)
echo "pushed ${SHA:0:12} to ${REMOTE_BRANCH}"

# `reset --hard` leaves UNTRACKED files behind, and this tree accumulates them —
# ad-hoc job scripts written on the remote side. They are not in history, so a job
# that reads one is unreproducible for exactly the reason this script exists.
# `clean -fd` removes them; anything worth keeping belongs in a commit.
ssh "$HOST" "cd $PROOT && git fetch -q origin && git reset -q --hard $SHA && \
    git clean -qfd -e 'runs' -e '*.log'"

# Verify BOTH, and say what was checked. The first version of this script printed
# "clean" next to "dirty=6" because it only compared the SHA — the same shape as a
# job printing a clean commit while running a dirty tree, which is the failure it
# was written to prevent.
read -r REMOTE_SHA REMOTE_DIRTY <<<"$(ssh "$HOST" "cd $PROOT && \
    echo \$(git rev-parse HEAD) \$(git status --porcelain | wc -l)")"
if [ "$REMOTE_SHA" != "$SHA" ]; then
    echo "remote HEAD $REMOTE_SHA != pushed $SHA" >&2
    exit 1
fi
if [ "$REMOTE_DIRTY" -ne 0 ]; then
    echo "remote tree still has $REMOTE_DIRTY modified/untracked file(s):" >&2
    ssh "$HOST" "cd $PROOT && git status --porcelain | head -20" >&2
    exit 1
fi
echo "synced: remote HEAD=${SHA:0:12}, dirty=0 (both verified)"
