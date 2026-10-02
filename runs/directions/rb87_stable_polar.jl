Dict{String, Any}(
    "gate" => Dict{String, Any}(
        "bdg_dim_cap" => 4000,
        "eps_stat" => 0.0001,
        "niter" => 120,
    ),
    "name" => "rb87_stable_polar",
    "physics" => Dict{String, Any}(
        "atom" => "Rb87",
        "box" => [12.0],
        "c0" => 1.0,
        "c1" => 0.1,
        "dims" => [32],
        "q" => 0.5,
    ),
    "solve" => Dict{String, Any}(
        "n_steps" => 800,
        "tol" => 1.0e-10,
    ),
)
