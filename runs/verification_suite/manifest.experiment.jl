Dict{String, Any}(
    "benchmarks" => [Dict{String, Any}(
        "file" => "yamls/00_scalar_free_uniform_stationary.experiment.jl",
        "id" => "00",
        "tier" => "exact",
        "verifies" => ["FFT k=0 stationarity", "norm conservation", "energy conservation", "component population invariance"],
    ), Dict{String, Any}(
        "file" => "yamls/01_scalar_harmonic_oscillator_ground.experiment.jl",
        "id" => "01",
        "tier" => "analytic",
        "verifies" => ["imaginary-time ground state", "harmonic oscillator units", "kinetic/potential balance"],
    ), Dict{String, Any}(
        "file" => "yamls/02_spin1_polar_contact_ground.experiment.jl",
        "id" => "02",
        "tier" => "mean_field_phase",
        "verifies" => ["c1>0 polar phase", "spin_order near zero", "spin-1 contact sign convention"],
    ), Dict{String, Any}(
        "file" => "yamls/03_spin1_ferromagnetic_contact_ground.experiment.jl",
        "id" => "03",
        "tier" => "mean_field_phase",
        "verifies" => ["c1<0 ferromagnetic phase", "spin_order near one", "m_plus_F Zeeman convention"],
    ), Dict{String, Any}(
        "file" => "yamls/04_spin2_cyclic_contact_ground.experiment.jl",
        "id" => "04",
        "tier" => "mean_field_phase",
        "verifies" => ["spin-2 singlet-pair c2 parsing", "cyclic phase", "Majorana/order-parameter analyzer"],
    ), Dict{String, Any}(
        "file" => "yamls/05_spin1_zeeman_phase_only.experiment.jl",
        "id" => "05",
        "tier" => "exact",
        "verifies" => ["linear/quadratic Zeeman phase evolution", "no artificial spin transfer", "population invariance"],
    ), Dict{String, Any}(
        "file" => "yamls/06_spin1_sma_spin_mixing.experiment.jl",
        "id" => "06",
        "tier" => "dynamical_conservation",
        "verifies" => ["spin-exchange path", "M_z conservation", "N conservation", "population oscillations"],
    ), Dict{String, Any}(
        "file" => "yamls/07_spin1_polar_bogoliubov_stable.experiment.jl",
        "id" => "07",
        "tier" => "linear_response",
        "verifies" => ["Bogoliubov analyzer", "stable polar spectrum", "absence of false dynamical instability"],
    ), Dict{String, Any}(
        "file" => "yamls/08_ddi_spherical_polarized_zero_kernel.experiment.jl",
        "id" => "08",
        "tier" => "ddi_kernel",
        "verifies" => ["DDI traceless kernel", "k=0 handling", "4pi/sign convention"],
    ), Dict{String, Any}(
        "file" => "yamls/09_edh_toy_spin_orbit_transfer.experiment.jl",
        "id" => "09",
        "tier" => "qualitative_dipolar_spinor",
        "verifies" => ["DDI spin-orbit coupling", "EdH qualitative transfer", "Jz=Lz+Sz analyzer path"],
    )],
    "created_by" => "ChatGPT",
    "created_for" => "Kozuma_Labo",
    "ladder_extension" => [Dict{String, Any}(
        "file" => "yamls/L2_ddi_axis_flip_Bx.experiment.jl",
        "id" => "L2_ddi_axis_flip_Bx",
        "ladder_level" => 2,
        "verifies" => ["DDI kernel B-axis transformation"],
    ), Dict{String, Any}(
        "file" => "yamls/L2_ddi_prolate_trap.experiment.jl",
        "id" => "L2_ddi_prolate_trap",
        "ladder_level" => 2,
        "verifies" => ["prolate trap + B||axis → attractive DDI"],
    ), Dict{String, Any}(
        "file" => "yamls/L2_ddi_oblate_trap.experiment.jl",
        "id" => "L2_ddi_oblate_trap",
        "ladder_level" => 2,
        "verifies" => ["oblate trap + B⊥plane → repulsive DDI"],
    ), Dict{String, Any}(
        "file" => "yamls/L3_cr_f3_edh_toy_ddi_on.experiment.jl",
        "id" => "L3_cr_f3_edh_toy_ddi_on",
        "ladder_level" => 3,
        "verifies" => ["Fz→Lz transfer", "Jz conserved", "winding ℓ growth in m=-F+1"],
    ), Dict{String, Any}(
        "file" => "yamls/L3_cr_f3_edh_toy_ddi_off.experiment.jl",
        "id" => "L3_cr_f3_edh_toy_ddi_off",
        "ladder_level" => 3,
        "verifies" => ["DDI off → no EdH transfer"],
    ), Dict{String, Any}(
        "file" => "yamls/L4_eu_matsui_hamiltonian_only_32.experiment.jl",
        "id" => "L4_eu_matsui_hamiltonian_only_32",
        "ladder_level" => 4,
        "verifies" => ["Eu Hamiltonian-only (loss off, LHY off)"],
    ), Dict{String, Any}(
        "file" => "yamls/L4_eu_matsui_hamiltonian_only_ddi_off_32.experiment.jl",
        "id" => "L4_eu_matsui_hamiltonian_only_ddi_off_32",
        "ladder_level" => 4,
        "verifies" => ["Eu DDI off control"],
    ), Dict{String, Any}(
        "file" => "yamls/L4_eu_matsui_hamiltonian_only_64.experiment.jl",
        "id" => "L4_eu_matsui_hamiltonian_only_64",
        "ladder_level" => 4,
        "verifies" => ["64³ grid convergence (Level 6 prerequisite)"],
    )],
    "purpose" => "Small YAML benchmarks to verify physical correctness before production spinor-BEC simulations.",
    "references" => ["Kawaguchi & Ueda, Spinor Bose-Einstein condensates: spinor phases, GPE, BdG, spin mixing, DDI, EdH.", "Ohmi & Machida / Ho 1998: spinor-BEC contact Hamiltonian and spin-1 polar/ferromagnetic phases.", "Kawaguchi, Saito & Ueda 2006: Einstein-de Haas effect in dipolar spinor BECs."],
    "suite" => "spinorbec_physics_verification",
)
