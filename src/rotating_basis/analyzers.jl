"""
Analyzers for Option γ rotating-basis dynamics output (修論 figure 6 panels).

Input: pipeline `:rotating_basis_dynamics` Dict containing
  - :times          Vector{Float64}
  - :per_m_history  Vector{Vector{Float64}} — per-m populations at each save_every
  - :Lz, :Fz        Vector{Float64} — spin/orbital angular momentum
  - :psi_snapshots  Vector{Array{ComplexF64,4}} — full ψ̃(r,m) per frame (optional)
  - :theta_const, :phi_omega — B̂(t) waveform parameters

Output: derived quantities tagged for direct plotting:
  - X2 / Fig 2: population_dynamics(...)             N_m(t) for all m
  - X2'/ Fig 5: edh_conservation(...)                ⟨F_z⟩(t) + ⟨L_z⟩(t)
  - X3 / Fig 3: spin_texture_xy(...)                 ⟨F_α⟩(x,y) at selected times
  - X4 / Fig 4: per_m_column_density(...)            |ψ̃_m(x,y)|² per m
  - X4 / Fig 4: detect_per_m_vortices(...)           vortex cores per m component
  - X6 / Fig 6: berry_connection_trajectory(...)     Â(t) analytical from waveforms
"""

# --- X2: Population dynamics -------------------------------------------

"""
Extract N_m(t) for all m components (rows = m index 1..D, cols = time).
Population is per-m norm × N_atoms (or normalized fraction).
"""
function population_dynamics(dyn::Dict; normalize::Bool=true)
    pm_hist = dyn[:per_m_history]::Vector
    times = dyn[:times]::Vector{Float64}
    D = length(pm_hist[1])
    N_m = Matrix{Float64}(undef, D, length(times))
    @inbounds for (i, pm) in enumerate(pm_hist)
        for m_idx in 1:D
            N_m[m_idx, i] = pm[m_idx]
        end
    end
    if normalize
        @inbounds for i in 1:size(N_m, 2)
            s = sum(@view N_m[:, i])
            if s > 0
                @views N_m[:, i] .= N_m[:, i] ./ s
            end
        end
    end
    (times=times, N_m=N_m, F=(D - 1) ÷ 2)
end

# --- X2'/X5: EdH conservation check ------------------------------------

"""
Total angular momentum ⟨J_z⟩(t) = ⟨F_z⟩(t) + ⟨L_z⟩(t).
For a closed dipolar system this is conserved; magnetostir transfers angular
momentum between spin and orbital channels.
"""
function edh_conservation(dyn::Dict)
    times = dyn[:times]::Vector{Float64}
    Fz = dyn[:Fz]::Vector{Float64}
    Lz = dyn[:Lz]::Vector{Float64}
    Jz = Fz .+ Lz
    drift = Jz .- Jz[1]
    (times=times, Fz=Fz, Lz=Lz, Jz=Jz, Jz_drift=drift,
        conservation_max_rel=maximum(abs.(drift)) / max(abs(Jz[1]), 1.0))
end

# --- X3: Spin texture ⟨F_α⟩(x,y) ---------------------------------------

"""
Local spin density ⟨F_α(r)⟩ = Σ_{m,m'} ψ̃*_m (F_α)_{m,m'} ψ̃_{m'}.

Returns column-projected (z-axis integrated) (⟨F_x⟩, ⟨F_y⟩, ⟨F_z⟩) at
each frame. Frame indices `frame_idxs` selects which times to extract.

For ⟨F_x⟩, ⟨F_y⟩, ⟨F_z⟩ in tilde basis (rotating quantization axis along B̂(t)):
to get lab-frame spin, apply Û_B(t) rotation to F operators or to ψ̃ post-hoc.
This function returns the TILDE-basis spin density — by construction, m=+F
fully polarized state has ⟨F_z⟩_tilde = +F·ρ across the cloud.
"""
function spin_texture_xy(dyn::Dict; frame_idxs::AbstractVector{Int}=Int[])
    haskey(dyn, :psi_snapshots) || error(
        "spin_texture_xy requires :psi_snapshots in dynamics result. " *
        "Re-run with `save: {psi: true}` (default).")
    snaps = dyn[:psi_snapshots]::Vector
    times = dyn[:times]::Vector{Float64}

    if isempty(frame_idxs)
        # Default: 5 evenly spaced frames
        n = length(snaps)
        frame_idxs = Int.(round.(range(1, n; length=min(5, n))))
    end

    sample = snaps[1]
    Nx, Ny, Nz, D = size(sample)
    F_val = (D - 1) / 2

    # Build F_x, F_y, F_z matrix elements (D × D, sparse for F_x/F_y, diagonal for F_z)
    # F_z[i,i] = m_i = F - (i-1)
    # F_x = (F_+ + F_-)/2, F_+[i,j]=√(F(F+1)-m_j(m_j+1)) when m_i = m_j+1
    Fx_mat = zeros(ComplexF64, D, D)
    Fy_mat = zeros(ComplexF64, D, D)
    Fz_mat = zeros(ComplexF64, D, D)
    @inbounds for i in 1:D
        m_i = F_val - (i - 1)
        Fz_mat[i, i] = m_i
    end
    @inbounds for j in 1:D
        m_j = F_val - (j - 1)
        # F_+[i,j] (raises): row m_i = m_j+1 → i = j-1
        if j - 1 >= 1
            i = j - 1
            elem = sqrt(F_val * (F_val + 1) - m_j * (m_j + 1))
            Fx_mat[i, j] += elem / 2
            Fy_mat[i, j] += elem / (2im)
        end
        # F_-[i,j] (lowers): row m_i = m_j-1 → i = j+1
        if j + 1 <= D
            i = j + 1
            elem = sqrt(F_val * (F_val + 1) - m_j * (m_j - 1))
            Fx_mat[i, j] += elem / 2
            Fy_mat[i, j] -= elem / (2im)
        end
    end

    # Output: 3 × Nx × Ny × len(frames) array of column-projected spin
    Fx_xy = zeros(Float64, Nx, Ny, length(frame_idxs))
    Fy_xy = zeros(Float64, Nx, Ny, length(frame_idxs))
    Fz_xy = zeros(Float64, Nx, Ny, length(frame_idxs))

    @inbounds for (k, idx) in enumerate(frame_idxs)
        ψ = snaps[idx]
        for ix in 1:Nx, iy in 1:Ny
            fx_acc = 0.0;
            fy_acc = 0.0;
            fz_acc = 0.0
            for iz in 1:Nz
                # ⟨F_α⟩ at (ix,iy,iz) = Σ_m,m' conj(ψ_m) F_α[m,m'] ψ_m'
                for j in 1:D, i in 1:D
                    a = conj(ψ[ix, iy, iz, i]) * ψ[ix, iy, iz, j]
                    if Fx_mat[i, j] != 0
                        fx_acc += real(Fx_mat[i, j] * a)
                    end
                    if Fy_mat[i, j] != 0
                        fy_acc += real(Fy_mat[i, j] * a)
                    end
                end
                fz_acc += real(Fz_mat[Nz - Nz + 1, Nz - Nz + 1] * 0)  # placeholder no-op
                # F_z is diagonal, simpler:
                for i in 1:D
                    fz_acc += real(Fz_mat[i, i]) * abs2(ψ[ix, iy, iz, i])
                end
            end
            Fx_xy[ix, iy, k] = fx_acc
            Fy_xy[ix, iy, k] = fy_acc
            Fz_xy[ix, iy, k] = fz_acc
        end
    end

    (frame_times=times[frame_idxs], frame_idxs=frame_idxs,
        Fx=Fx_xy, Fy=Fy_xy, Fz=Fz_xy, F=F_val)
end

# --- X4: Per-m column density + vortex detection -----------------------

"""
Column-projected density per m component: |ψ̃_m(x,y)|² = ∫ |ψ̃_m(x,y,z)|² dz.
Returns Array{Float64, 3} indexed [x, y, m] for the requested frame.
"""
function per_m_column_density(dyn::Dict; frame_idx::Int=-1)
    haskey(dyn, :psi_snapshots) || error("requires :psi_snapshots")
    snaps = dyn[:psi_snapshots]::Vector
    f = frame_idx < 0 ? length(snaps) : frame_idx
    ψ = snaps[f]
    Nx, Ny, Nz, D = size(ψ)
    cd = zeros(Float64, Nx, Ny, D)
    @inbounds for m_idx in 1:D, ix in 1:Nx, iy in 1:Ny
        s = 0.0
        for iz in 1:Nz
            s += abs2(ψ[ix, iy, iz, m_idx])
        end
        cd[ix, iy, m_idx] = s
    end
    cd
end

"""
Detect vortex cores in a 2D density field via the standard winding-number
criterion: a vortex is a local minimum in density coincident with a 2π
phase winding around it. For per-m vortex pattern (Fig 4) we use a simple
density-minimum + local-mean threshold heuristic; full winding-number
analysis is in `analysis/vortex_extraction.jl` for spinor BEC and can be
applied per-m by passing `selectdim(ψ, 4, m_idx)`.

Returns Vector of (ix, iy) tuples for detected cores. `density_threshold`
is a fraction of peak density below which a local-min counts as a core.
"""
function detect_density_minima(rho::AbstractMatrix{Float64};
    density_threshold::Float64=0.3)
    Nx, Ny = size(rho)
    ρ_max = maximum(rho)
    cores = NTuple{2, Int}[]
    @inbounds for ix in 2:(Nx - 1), iy in 2:(Ny - 1)
        ρ = rho[ix, iy]
        ρ < density_threshold * ρ_max || continue
        # Local minimum check (8-neighbor)
        is_min = true
        for di in -1:1, dj in -1:1
            (di == 0 && dj == 0) && continue
            if rho[ix + di, iy + dj] < ρ
                is_min = false;
                break
            end
        end
        is_min && push!(cores, (ix, iy))
    end
    cores
end

"""Detect vortex cores in each m component for a given frame."""
function detect_per_m_vortices(dyn::Dict; frame_idx::Int=-1,
    density_threshold::Float64=0.2)
    cd = per_m_column_density(dyn; frame_idx)
    Nx, Ny, D = size(cd)
    cores_per_m = Vector{Vector{NTuple{2, Int}}}(undef, D)
    @inbounds for m_idx in 1:D
        cores_per_m[m_idx] = detect_density_minima(@view cd[:, :, m_idx];
            density_threshold)
    end
    (cores=cores_per_m, column_density=cd)
end

# --- X6: Berry connection time profile ---------------------------------

"""
Compute Â(t)/ℏ = θ̇·F_y + φ̇·(cosθ·F_z - sinθ·F_x) component coefficients.

Pure analytical diagnostic: depends only on the prescribed θ(t), φ(t)
waveforms (and their derivatives), NOT on simulation state. Used to
correlate observed spin-population transfer with the rotation-rate-scale
driver Â(t).

Returns time series of (a_x, a_y, a_z) per the gauge-fix convention used:
  - gauge_fix=false: a_x = -φ̇·sinθ, a_y = θ̇, a_z = φ̇·cosθ  (full Â)
  - gauge_fix=true: a_x = -φ̇·sinθ, a_y = θ̇, a_z = 0  (F_z piece absorbed)
"""
function berry_connection_trajectory(times::AbstractVector;
    theta_func::Function,
    phi_func::Function,
    theta_dot_func::Function,
    phi_dot_func::Function,
    gauge_fix::Bool=false)
    a_x = zeros(Float64, length(times))
    a_y = zeros(Float64, length(times))
    a_z = zeros(Float64, length(times))
    @inbounds for (i, t) in enumerate(times)
        θ = Float64(theta_func(t))
        θ̇ = Float64(theta_dot_func(t))
        φ̇ = Float64(phi_dot_func(t))
        a_x[i] = -φ̇ * sin(θ)
        a_y[i] = θ̇
        a_z[i] = gauge_fix ? 0.0 : φ̇ * cos(θ)
    end
    a_mag = @. sqrt(a_x^2 + a_y^2 + a_z^2)
    (times=collect(times), a_x=a_x, a_y=a_y, a_z=a_z, a_mag=a_mag)
end

"""Convenience: extract Â trajectory from a dynamics result (uses
saved theta_const, phi_omega)."""
function berry_connection_trajectory(dyn::Dict; gauge_fix::Bool=false)
    times = dyn[:times]::Vector{Float64}
    θ_const = dyn[:theta_const]::Float64
    φ_omega = dyn[:phi_omega]::Float64
    berry_connection_trajectory(times;
        theta_func=(t)->θ_const,
        phi_func=(t)->φ_omega * t,
        theta_dot_func=(t)->0.0,
        phi_dot_func=(t)->φ_omega,
        gauge_fix=gauge_fix)
end
