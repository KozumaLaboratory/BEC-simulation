#!/usr/bin/env julia
# Convert the Matsui et al. (2025) EdH published datasets from .xlsx to the CSV
# fixtures under test/fixtures/matsui2025/.
#
# The .xlsx originals are Zenodo record 17303925 (CC-BY-4.0) and are NOT
# committed — only the CSV extracts are, so the fixture stays diffable and the
# repo stays free of binary blobs. Re-run after re-downloading the record:
#
#     julia --project=. scripts/validation/matsui_dataset_to_csv.jl <dir-with-xlsx>
#
# Requires python3 + openpyxl on PATH; xlsx parsing is not worth a Julia dep.

const OUT = joinpath(@__DIR__, "..", "..", "test", "fixtures", "matsui2025")
const FILES = ["dataset_fig2_exp", "dataset_fig2_theo", "dataset_fig4_exp", "dataset_fig4_theo"]

function main(src::AbstractString)
    mkpath(OUT)
    py = """
import csv, os, sys
import openpyxl
src, out = sys.argv[1], sys.argv[2]
for stem in $(repr(FILES)):
    wb = openpyxl.load_workbook(os.path.join(src, stem + '.xlsx'), data_only=True)
    ws = wb.active
    rows = list(ws.iter_rows(values_only=True))
    with open(os.path.join(out, stem + '.csv'), 'w', newline='') as fh:
        w = csv.writer(fh)
        for r in rows:
            w.writerow(['' if v is None else v for v in r])
    print(stem, len(rows) - 1, 'data rows')
"""
    run(`python3 -c $py $src $OUT`)
end

main(isempty(ARGS) ? error("usage: matsui_dataset_to_csv.jl <dir-with-xlsx>") : ARGS[1])
