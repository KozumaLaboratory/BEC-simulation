# Precompile the small loss kernels without constructing a Workspace.

using PrecompileTools

@setup_workload begin
    @compile_workload begin
        try
            # Loss-kernel primer: seed apply_loss_step! for both the linear
            # L3_per_m (linear-in-n) and the true-3-body K3_per_m_cubic
            # (quadratic-in-n) paths so EdH / K3 runs don't pay JIT on first
            # dynamics step. Tiny F=1 D=3 4³ exercises the inner branch table
            # in losses.jl without the multi-minute make_workspace cascade.
            let
                psi_loss = ones(ComplexF64, 4, 4, 4, 3)
                loss_k3 = LossParams(; gamma_dr=0.0,
                    K3_per_m_cubic=[0.01, 0.01, 0.01])
                apply_loss_step!(psi_loss, loss_k3, 1, 0.001, 3, 3)
                loss_l3 = LossParams(; gamma_dr=0.01,
                    L3_per_m=[0.01, 0.01, 0.01])
                apply_loss_step!(psi_loss, loss_l3, 1, 0.001, 3, 3)
                # YAML parsing path (cheap; no make_workspace):
                _parse_loss_params(
                    Dict{String, Any}(
                        "gamma_dr" => 0.02,
                        "K3_per_m" => [0.01, 0.01, 0.01],
                    ),
                )
            end
        catch
            # Don't break package precompile if the workload trips.
        end
    end
end
