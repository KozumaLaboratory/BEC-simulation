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
    paper_dir = get(_MANUSCRIPT_PAPER_DIRS, String(paper), String(paper))
    dir = joinpath(_MANUSCRIPT_PROJECT_ROOT,
        "docs", "manuscript", "papers", paper_dir, "figures")
    mkpath(dir)
    return dir
end

function manuscript_figure_path(paper::AbstractString, fig::AbstractString,
    ext::AbstractString)
    joinpath(manuscript_figure_dir(paper),
        "$(lowercase(String(fig)))_$(paper).$ext")
end

# Helper: write structured CSV alongside a matplotlib renderer.
function _emit_csv_py(io::IO, paper::AbstractString, fig::AbstractString,
    csv::AbstractString, py::AbstractString)
    dir = manuscript_figure_dir(paper)
    base = joinpath(dir, lowercase(String(fig)) * "_" * paper)
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
