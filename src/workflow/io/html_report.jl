# --- Per-run HTML archival report ---

export generate_html_report

# Generate a self-contained static HTML page summarising a completed
# run (or scan dir). No JS required to read it; embedded base64 PNGs
# for the energy curve + first/last density snapshot. Pairs with
# print_run_summary for a richer offline artifact.

"""
    generate_html_report(run_dir; out_path = joinpath(run_dir, "report.html"))

Build a static HTML page summarising a run. Walks every `point_NNN.jld2`
plus the optional `frames/` directory and embeds:

  - Per-point: energy, Mz, convergence, dynamics trace head/tail, list
    of analyzers run.
  - First and last frame from `frames/` if present (base64-embedded).

Returns the output path. Self-contained — no CSS / JS dependencies.
"""
function generate_html_report(run_dir::AbstractString;
    out_path::AbstractString=
    joinpath(run_dir, "report.html"))
    isdir(run_dir) || throw(ArgumentError("run_dir not found: $run_dir"))
    files = sort(filter(f -> endswith(f, ".jld2"), readdir(run_dir)))
    frames_dir = joinpath(run_dir, "frames")
    pngs =
        isdir(frames_dir) ?
        sort(filter(f -> endswith(f, ".png"), readdir(frames_dir))) : String[]

    io = IOBuffer()
    println(
        io,
        """
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>SpinorBEC run: $(basename(run_dir))</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
         max-width: 900px; margin: 2em auto; padding: 0 1em; color: #222; }
  h1 { border-bottom: 2px solid #333; padding-bottom: .3em; }
  h2 { margin-top: 1.5em; }
  table { border-collapse: collapse; margin: 1em 0; }
  th, td { padding: .35em .8em; border: 1px solid #ddd; text-align: left; }
  th { background: #f3f3f3; }
  .muted { color: #888; font-size: .9em; }
  .frame { display: inline-block; margin: .5em; vertical-align: top; }
  .frame img { max-width: 320px; border: 1px solid #ccc; }
  code { background: #f3f3f3; padding: .1em .3em; border-radius: 3px; }
</style></head><body>
""",
    )
    println(io, "<h1>SpinorBEC run: <code>$(basename(run_dir))</code></h1>")
    println(
        io,
        "<p class='muted'>Generated $(now())  •  $(length(files)) point(s)  •  $(length(pngs)) frame(s)</p>",
    )

    println(io, "<h2>Per-point summary</h2>")
    println(
        io, "<table><tr><th>file</th><th>energy</th><th>conv</th><th>Mz</th><th>analyzers</th></tr>"
    )
    for fname in files
        path = joinpath(run_dir, fname)
        try
            jldopen(path, "r") do f
                e = haskey(f, "energy") ? string(f["energy"]) : "—"
                c = haskey(f, "converged") ? string(f["converged"]) : "—"
                m = haskey(f, "mz_actual") ? string(f["mz_actual"]) : "—"
                analyzers = filter(k -> startswith(k, "analyze/"), keys(f))
                seen = Set{String}()
                for k in analyzers
                    parts = split(k, '/')
                    length(parts) >= 2 && push!(seen, parts[2])
                end
                analyz = join(sort(collect(seen)), ", ")
                println(
                    io,
                    "<tr><td><code>$fname</code></td><td>$e</td><td>$c</td><td>$m</td><td>$analyz</td></tr>",
                )
            end
        catch e
            println(
                io,
                "<tr><td><code>$fname</code></td><td colspan='4' class='muted'>read error: $e</td></tr>",
            )
        end
    end
    println(io, "</table>")

    if !isempty(pngs)
        println(io, "<h2>Frames</h2>")
        # Reference first and last frame relative to the report location.
        # Report sits in run_dir, frames in run_dir/frames/, so a relative
        # path works for `file://` and any HTTP serve of the same dir.
        for fname in [pngs[1], pngs[end]]
            println(io, "<div class='frame'>")
            println(io, "  <img src='frames/$fname'><br>")
            println(io, "  <span class='muted'>$fname</span>")
            println(io, "</div>")
        end
        println(
            io,
            "<p class='muted'>Showing first + last; full sequence: $(length(pngs)) frames in <code>frames/</code></p>",
        )
    end

    println(io, "</body></html>")

    write(out_path, String(take!(io)))
    out_path
end
