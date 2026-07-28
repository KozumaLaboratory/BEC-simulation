#!/bin/bash
# Durable resume for the Eu GS phase-diagram campaign. Reads the committed ledger
# runs/eu_gs_phase_c1_B_kappa/CAMPAIGN.tsv, checks per-config completion on TSUBAME,
# and (with --submit) re-qsubs ONLY the missing task indices. Safe across session
# breaks: run_yaml is content-addressed, so already-computed point_*.jld2 are
# skipped — nothing done is recomputed.
#
#   scripts/eu_campaign_resume.sh            # status only
#   scripts/eu_campaign_resume.sh --submit   # fill the gaps (right-sized h_rt)
set -uo pipefail

SUBMIT="${1:-}"
FILTER="${2:-}"   # optional: only act on config paths containing this substring
HERE="$(cd "$(dirname "$0")/.." && pwd)"
LEDGER="$HERE/runs/eu_gs_phase_c1_B_kappa/CAMPAIGN.tsv"
CDIR="runs/eu_gs_phase_c1_B_kappa"
PROOT="/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation"
GRP="tga-kozuma-kouhi"
[ -f "$LEDGER" ] || { echo "no ledger: $LEDGER"; exit 1; }

# Guard code-drift: the CAS content_id depends only on the config spec, NOT the
# source version, so a stale TSUBAME src can make a byte-stable config fail (e.g.
# an unknown 'pin' key after src reverted). Before submitting, sync the committed
# src/ + scripts/ so the remote code matches this branch.
if [ "$SUBMIT" = "--submit" ]; then
    echo "syncing src/ + scripts/ + campaign configs to TSUBAME (guards drift before resume)..."
    rsync -az --delete "$HERE/src/" "tsubame:$PROOT/src/" 2>&1 | tail -1
    rsync -az "$HERE/scripts/" "tsubame:$PROOT/scripts/" 2>&1 | tail -1
    rsync -az "$HERE/$CDIR/" "tsubame:$PROOT/$CDIR/" 2>&1 | tail -1   # configs + submit + ledger
fi

remote_check() {   # $1=config basename  $2=job_name  -> DIRN/DIR/ACTIVE/COUNTS/END
    ssh tsubame "bash -s '$1' '$2' '$PROOT'" <<'REMOTE'
base=$1; jobname=$2; proot=$3
cd "$proot/runs" 2>/dev/null || exit 0
dirs=$(ls -d ${base}_* 2>/dev/null)
echo "DIRN $(echo $dirs | wc -w)"
d=$(echo $dirs | awk '{print $1}')
echo "DIR $d"
echo "ACTIVE $(qstat 2>/dev/null | grep -c "$jobname")"
echo "COUNTS"
[ -n "$d" ] && ls "$d"/point_*.jld2 2>/dev/null | sed -E 's#.*/point_0*([0-9]+)_.*#\1#' | sort -n | uniq -c
echo "END"
REMOTE
}

printf "%-28s %-9s %-14s %-8s %s\n" CONFIG STATUS CELLS ACTIVE MISSING
tail -n +1 "$LEDGER" | while IFS=$'\t' read -r cfg submit jobname ntasks nseeds hrt purpose; do
    [[ "$cfg" =~ ^#.*$ || -z "$cfg" ]] && continue
    [ -n "$FILTER" ] && [[ "$cfg" != *"$FILTER"* ]] && continue
    base="${cfg%.yaml}"
    out="$(remote_check "$base" "$jobname")"
    dirn=$(echo "$out" | awk '/^DIRN/{print $2}')
    active=$(echo "$out" | awk '/^ACTIVE/{print $2}')
    # per-index counts → missing list
    counts=$(echo "$out" | awk '/^COUNTS$/{f=1;next}/^END$/{f=0}f{print $2":"$1}')
    have=0; missing=""
    for ((i=1;i<=ntasks;i++)); do
        c=$(echo "$counts" | awk -F: -v i="$i" '$1==i{print $2}')
        c=${c:-0}
        have=$((have+ (c>=nseeds ? 1 : 0) ))
        [ "${c:-0}" -lt "$nseeds" ] && missing="$missing $i"
    done
    missing="${missing# }"
    nmiss=$(echo $missing | wc -w)
    if [ "$dirn" -gt 1 ]; then st="CONFLICT"; elif [ "$dirn" -eq 0 ]; then st="NOTSTART";
    elif [ "$nmiss" -eq 0 ]; then st="DONE"; else st="PARTIAL"; fi
    printf "%-28s %-9s %-14s %-8s %s\n" "$cfg" "$st" "$have/$ntasks pts" "$active" "${missing:-none}"

    if [ "$SUBMIT" = "--submit" ] && [ "$nmiss" -gt 0 ] && [ "${active:-0}" -ne 0 ]; then
        echo "   ↳ skip submit: $jobname already active ($active in queue)"
    elif [ "$SUBMIT" = "--submit" ] && [ "$nmiss" -gt 0 ] && [ "$dirn" -le 1 ]; then
        # group scattered missing indices into CONTIGUOUS runs → one qsub each,
        # so no already-done task is re-touched (zero skip, zero h_rt waste).
        runs=$(echo $missing | tr ' ' '\n' | sort -n | awk '
            NR==1{s=$1;p=$1;next}
            $1==p+1{p=$1;next}
            {print s"-"p; s=$1;p=$1}
            END{print s"-"p}')
        nruns=$(echo "$runs" | wc -l)
        echo "   ↳ submitting $jobname: $nmiss missing in $nruns contiguous run(s), h_rt=$hrt (0 skips)"
        for r in $runs; do
            ssh tsubame "bash -lc 'cd $PROOT && qsub -g $GRP -N $jobname -l h_rt=$hrt -t $r $CDIR/$submit $CDIR/$cfg'" 2>&1 | tail -1
        done
    fi
done
echo
echo "resume: run with --submit to fill PARTIAL/NOTSTART gaps (done cells are skipped)."
