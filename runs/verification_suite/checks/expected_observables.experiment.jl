# Expected checks for the verification YAML suite.
# Numerical tolerances assume small CPU grids. Tighten after convergence studies.

Dict{String, Any}(
    "00_scalar_free_uniform_stationary" => Dict{String, Any}(
        "inspect" => ["dynamics/norms", "dynamics/energies", "dynamics/component_populations"],
        "pass" => Dict{String, Any}(
            "component_population_drift" => "zero within numerical roundoff",
            "energy_absolute_drift" => "< 1e-10",
            "norm_relative_drift" => "< 1e-10 for f64 CPU; < 1e-7 acceptable if f32/GPU",
        ),
        "theory" => "Free scalar uniform state: k=0 mode, no trap, no interactions; state is exactly stationary up to global phase.",
    ),
    "01_scalar_harmonic_oscillator_ground" => Dict{String, Any}(
        "inspect" => ["ground_state/energy", "analyze/energy_decomposition", "final density rms widths"],
        "pass" => Dict{String, Any}(
            "energy_per_particle" => "approximately 1.5; grid and finite box errors should decrease with n and box",
            "spin_order" => "zero, because F=0",
        ),
        "theory" => "Noninteracting 3D harmonic oscillator in dimensionless units. Ground state energy per particle should be 3/2 for omega=(1,1,1).",
    ),
    "02_spin1_polar_contact_ground" => Dict{String, Any}(
        "inspect" => ["analyze/phase_classify"],
        "pass" => Dict{String, Any}(
            "magnetization_density" => "near 0",
            "phase" => "polar or polar-like",
            "spin_order" => "< 1e-3 after convergence",
        ),
        "theory" => "Spin-1 contact interaction: E_spin=(c1/2)|F|^2. For c1>0, polar state minimizes |F|.",
    ),
    "03_spin1_ferromagnetic_contact_ground" => Dict{String, Any}(
        "inspect" => ["analyze/phase_classify"],
        "pass" => Dict{String, Any}(
            "magnetization_density" => "near +1 for m_plus_F seed unless the classifier reports a rotated ferromagnet",
            "phase" => "ferromagnetic or ferromagnetic-like",
            "spin_order" => "> 0.99",
        ),
        "theory" => "Spin-1 contact interaction: for c1<0, energy is minimized by maximal spin order.",
    ),
    "04_spin2_cyclic_contact_ground" => Dict{String, Any}(
        "inspect" => ["analyze/phase_classify", "analyze/majorana_order"],
        "pass" => Dict{String, Any}(
            "phase" => "cyclic or cyclic-like",
            "singlet_pair" => "near 0 if reported",
            "spin_order" => "near 0",
        ),
        "theory" => "Spin-2 mean-field contact model. With c1>0 and c2>0, cyclic minimizes both |F| and singlet amplitude A00.",
    ),
    "05_spin1_zeeman_phase_only" => Dict{String, Any}(
        "inspect" => ["dynamics/norms", "dynamics/magnetizations", "dynamics/component_populations"],
        "pass" => Dict{String, Any}(
            "component_population_drift" => "< 1e-10",
            "magnetization_drift" => "< 1e-10",
            "norm_relative_drift" => "< 1e-10 f64 CPU",
        ),
        "theory" => "Pure diagonal Zeeman evolution changes phases but not populations.",
    ),
    "06_spin1_sma_spin_mixing" => Dict{String, Any}(
        "inspect" => ["dynamics/norms", "dynamics/magnetizations", "dynamics/component_populations"],
        "pass" => Dict{String, Any}(
            "magnetization_drift" => "< 1e-8",
            "norm_relative_drift" => "< 1e-7 coarse grid",
            "qualitative" => "m0 and m±1 populations should oscillate after seed; no net Mz should be generated",
        ),
        "theory" => "Spin-exchange collision 2 m0 <-> m+1 + m-1; total atom number and total Mz are conserved.",
    ),
    "07_spin1_polar_bogoliubov_stable" => Dict{String, Any}(
        "inspect" => ["analyze/bogoliubov", "analyze/bogoliubov_dispersion"],
        "pass" => Dict{String, Any}(
            "imaginary_frequency" => "none above tolerance",
            "max_growth_rate" => "0 or below numerical tolerance",
        ),
        "theory" => "Polar c1>0, q>=0 spin-1 state has stable small-k Bogoliubov modes for this parameter choice.",
    ),
    "08_ddi_spherical_polarized_zero_kernel" => Dict{String, Any}(
        "inspect" => ["analyze/energy_decomposition", "analyze/phase_classify"],
        "pass" => Dict{String, Any}(
            "ddi_energy" => "small compared with contact/trap energy; should converge toward zero as grid/box improve",
            "phase" => "ferromagnetic / stretched spinor remains polarized",
        ),
        "theory" => "For a spherical spin-polarized Gaussian-like density, the traceless DDI contribution should be very small; the test catches 4pi/sign/kernel errors.",
    ),
    "09_edh_toy_spin_orbit_transfer" => Dict{String, Any}(
        "inspect" => ["analyze/winding_map", "dynamics/magnetizations", "dynamics/component_populations"],
        "pass" => Dict{String, Any}(
            "Jz" => "approximately conserved in final winding_map; tighten after saving time-resolved Lz",
            "qualitative" => "small population transfer out of stretched component and nonzero Lz/winding signal",
        ),
        "theory" => "Dipolar spinor BEC under weak field should exchange spin and orbital angular momentum while approximately conserving Jz=Lz+Sz in the closed-system limit.",
    ),
)
