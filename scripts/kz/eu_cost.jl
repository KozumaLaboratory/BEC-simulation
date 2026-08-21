# What does an F=6 SPGPE step cost, measured rather than extrapolated?
#
# Today's extrapolation was 10x wrong (20 us guessed against 189 us measured),
# because the overhead does not scale with the grid. So measure the real thing at
# the component counts and dimensions that matter, with and without the DDI.
using SpinorBEC, FFTW, Printf, Statistics
bench(f, n) = (f(); t0 = time(); for _ in 1:n; f(); end; (time() - t0) / n * 1e3)

@printf("%-6s %-8s %-6s %-8s %-11s %-11s %-11s\n",
    "F", "grid", "D", "DDI", "split ms", "spgpe ms", "total ms")
for (F, ndim, n, box) in ((1, 1, 1024, 200.0), (6, 1, 1024, 200.0),
    (1, 3, 32, 12.0), (6, 3, 32, 12.0), (6, 3, 48, 12.0))
    for ddi in (false, true)
        D = SpinSystem(F).n_components
        shape = ntuple(_ -> n, ndim)
        grid = make_grid(GridConfig(shape, ntuple(_ -> box, ndim)))
        k_cut = sqrt(2 * 2.0)
        sp = SimParams(; dt=0.05, n_steps=1, imaginary_time=false, save_every=1,
            normalize_every=0)
        atom = F == 1 ? Rb87 : Eu151
        ws = try
            make_workspace(; grid, atom,
                interactions=InteractionParams(Dict{Int, Float64}(0 => 0.02, 1 => -1e-4)),
                potential=ndim == 1 ? HarmonicTrap{1}((0.0,)) :
                          HarmonicTrap{3}((1.0, 1.0, 1.0)),
                sim_params=sp, fft_flags=FFTW.ESTIMATE,
                enable_ddi=ddi, c_dd=(ddi ? 0.1 : NaN))
        catch e
            @printf("%-6d %-8s %-6d %-8s SKIP: %s\n", F, "$(n)^$(ndim)", D,
                ddi ? "on" : "off", first(split(sprint(showerror, e), "\n"))[1:min(end, 60)])
            continue
        end
        res = SPGPEReservoir(; T=1.0, mu=2.0, a_s=0.007, k_cut, gamma=0.1, M=0.1,
            allow_unphysical_rates=true)
        # fill with something non-trivial so no branch short-circuits
        for c in 1:D
            view(ws.state.psi, ntuple(_ -> Colon(), ndim)..., c) .= 0.1 + 0.01im
        end
        N = ndim == 1 ? 200 : 20
        t_split = bench(() -> split_step!(ws), N)
        t_spgpe = bench(() -> apply_spgpe_step!(ws, res, 0.05; t=0.0, seed=1), N)
        @printf("%-6d %-8s %-6d %-8s %-11.3f %-11.3f %-11.3f\n",
            F, "$(n)^$(ndim)", D, ddi ? "on" : "off", t_split, t_spgpe,
            t_split + t_spgpe)
        flush(stdout)
    end
end
