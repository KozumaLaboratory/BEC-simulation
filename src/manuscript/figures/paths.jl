# Output-path conventions for manuscript figures.
#
# Each (paper, fig) lands in
#   docs/manuscript/papers/<paper_dir>/figures/<fig>_<paper>.<ext>
# where `paper_dir` is the long name (paper3 → paper3_universal_theorem).

const _MANUSCRIPT_PAPER_DIRS = Dict(
    "paper1" => "paper1_F2_cyclic",
    "paper2" => "paper2_F6_icosahedral",
    "paper3" => "paper3_universal_theorem",
    "paper4" => "paper4_chaotic_dynamics",
)

# Project root is two `dirname` levels up from src/manuscript/figures/.
const _MANUSCRIPT_PROJECT_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))

function manuscript_figure_dir(paper::AbstractString)
    # The "docs" pseudo-paper collects documentation figures; they land in
    # docs/figs/ (the paths the prose already knows), not under papers/.
    dir = if String(paper) == "docs"
        joinpath(_MANUSCRIPT_PROJECT_ROOT, "docs", "figs")
    else
        paper_dir = get(_MANUSCRIPT_PAPER_DIRS, String(paper), String(paper))
        joinpath(_MANUSCRIPT_PROJECT_ROOT,
            "docs", "manuscript", "papers", paper_dir, "figures")
    end
    mkpath(dir)
    return dir
end

function manuscript_figure_path(paper::AbstractString, fig::AbstractString,
    ext::AbstractString)
    joinpath(manuscript_figure_dir(paper),
        "$(lowercase(String(fig)))_$(paper).$ext")
end

# Helper: write structured CSV alongside a matplotlib renderer.
# `basename` overrides the `<fig>_<paper>` naming for figures whose output
# path predates the registry (e.g. the docs/figs/ PNGs).
function _emit_csv_py(io::IO, paper::AbstractString, fig::AbstractString,
    csv::AbstractString, py::AbstractString;
    basename::Union{Nothing, AbstractString}=nothing)
    dir = manuscript_figure_dir(paper)
    base = joinpath(dir,
        basename === nothing ? lowercase(String(fig)) * "_" * paper :
        String(basename))
    csv_path = base * ".csv"
    py_path = base * ".py"
    open(csv_path, "w") do f
        write(f, csv)
    end
    open(py_path, "w") do f
        write(f, py)
    end
    println(io, "OK: $paper $fig")
    println(io, "  data: $csv_path")
    println(io, "  renderer: $py_path")
    println(io, "  build PDF: python3 $py_path")
    return (csv=csv_path, py=py_path)
end

function _emit_tikz(io::IO, paper::AbstractString, fig::AbstractString,
    tikz::AbstractString)
    dir = manuscript_figure_dir(paper)
    tex_path = joinpath(dir, lowercase(String(fig)) * "_" * paper * ".tex")
    open(tex_path, "w") do f
        write(f, tikz)
    end
    println(io, "OK: $paper $fig")
    println(io, "  TikZ source: $tex_path")
    println(io, "  Build: cd $dir && pdflatex $(basename(tex_path))")
    return tex_path
end
