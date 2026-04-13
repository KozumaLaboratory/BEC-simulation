# --- Experiment utility functions ---

function scale_interactions_quasi_2d(ip::InteractionParams, l_z::Float64)
    factor = 1.0 / (sqrt(2π) * l_z)
    if ip.c_lhy != 0.0
        @warn "c_lhy scaling under quasi-2D is approximate; 2D LHY requires logarithmic treatment"
    end
    InteractionParams(
        ip.c0 * factor,
        ip.c1 * factor,
        ip.c_lhy * factor,
        isempty(ip.c_extra) ? Float64[] : ip.c_extra .* factor,
    )
end

function _normalize_grid(n_raw, box_raw)
    n_pts = n_raw isa Vector ? Int.(n_raw) : Int[Int(n_raw)]
    box_size = box_raw isa Vector ? Float64.(box_raw) : Float64[Float64(box_raw)]
    length(n_pts) == length(box_size) ||
        throw(ArgumentError("grid n and box must have the same length"))
    (n_pts, box_size)
end

function _add_noise!(psi, amplitude, n_components, ndim, grid)
    n_pts = ntuple(d -> size(psi, d), ndim)
    dV = cell_volume(grid)
    dominant = argmax([
        sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) for c = 1:n_components
    ])
    for c = 1:n_components
        c == dominant && continue
        idx = _component_slice(ndim, n_pts, c)
        view(psi, idx...) .+= amplitude .* randn(ComplexF64, n_pts)
    end
    norm = sqrt(sum(abs2, psi) * dV)
    psi ./= norm
end

function seed_noise(
    psi_gs,
    n_components::Int,
    ndim::Int,
    grid::Grid;
    amplitude::Float64 = 0.001,
    seed::Int = 42,
)
    psi = copy(psi_gs)
    Random.seed!(seed)
    _add_noise!(psi, amplitude, n_components, ndim, grid)
    psi
end

"""Print ground state summary with populations."""
function _print_gs_summary(psi, grid, atom, gs)
    F = atom.F
    D = 2F + 1
    dV = cell_volume(grid)
    n_pts = grid.config.n_points
    ndim = length(n_pts)
    pops = [sum(abs2, view(psi, _component_slice(ndim, n_pts, c)...)) * dV for c in 1:D]
    total = sum(pops)
    pops ./= total
    sorted_idx = sortperm(pops; rev=true)
    top = [(F - (i-1), pops[i]) for i in sorted_idx[1:min(3, D)]]
    pop_str = join(["m=$(m): $(round(p*100; digits=1))%" for (m, p) in top], ", ")
    mz = sum((F - (c-1)) * pops[c] for c in 1:D)
    println("  E=$(round(gs.energy; sigdigits=6)) conv=$(gs.converged) Mz=$(round(mz; digits=2)) [$pop_str]")
end
