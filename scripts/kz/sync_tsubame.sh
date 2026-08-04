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

ssh "$HOST" "cd $PROOT && git fetch -q origin && git reset -q --hard $SHA && \
    git status --porcelain | head -5 && \
    echo \"remote HEAD=\$(git rev-parse --short HEAD) dirty=\$(git status --porcelain | wc -l)\""

REMOTE_SHA=$(ssh "$HOST" "cd $PROOT && git rev-parse HEAD")
[ "$REMOTE_SHA" = "$SHA" ] || { echo "remote HEAD $REMOTE_SHA != $SHA" >&2; exit 1; }
echo "synced: remote is at ${SHA:0:12}, clean"
