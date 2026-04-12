# --- Phase Scan Utilities ---
#
# Scan iteration is handled by run_yaml (pipeline-based) in run_registry.jl.
# This file only keeps CSV helpers used by legacy code paths.

function _open_csv(dir, filename)
    open(joinpath(dir, filename), "w")
end

function _write_csv(io, values)
    row = join(values, ",")
    if io !== nothing
        println(io, row)
        flush(io)
    end
    row
end
