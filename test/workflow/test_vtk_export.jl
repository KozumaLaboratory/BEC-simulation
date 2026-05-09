# `WriteVTK` is a weak dep loaded via SpinorBECVTKExt; we explicitly
# `using` it here so `export_vtk` resolves to the extension method.
using WriteVTK

@testset "VTK Export" begin
    F = 1
    sys = SpinSystem(F)
    grid = make_grid(GridConfig((8, 8, 8), (10.0, 10.0, 10.0)))
    psi = init_psi(grid, sys; state=:polar)

    @testset "single frame" begin
        outdir = mktempdir()
        path = export_vtk(psi, grid;
            output=joinpath(outdir, "test_bec"),
            fields=[:density, :current, :spin_density, :velocity],
            atom=Rb87)
        @test isfile(path)
        @test filesize(path) > 0
    end

    @testset "component densities" begin
        outdir = mktempdir()
        path = export_vtk(psi, grid;
            output=joinpath(outdir, "test_comp"),
            fields=[:component_densities],
            atom=Rb87)
        @test isfile(path)
        @test filesize(path) > 0
    end

    @testset "vorticity" begin
        outdir = mktempdir()
        path = export_vtk(psi, grid;
            output=joinpath(outdir, "test_vort"),
            fields=[:density, :vorticity],
            atom=Rb87)
        @test isfile(path)
    end

    @testset "time series" begin
        result = SimulationResult(
            [0.0, 0.1, 0.2],
            [1.0, 1.0, 1.0],
            [1.0, 1.0, 1.0],
            [0.0, 0.0, 0.0],
            [copy(psi), copy(psi), copy(psi)],
        )
        outdir = mktempdir()
        pvd_path = export_vtk_series(result, grid;
            output_dir=outdir,
            fields=[:density, :spin_density],
            atom=Rb87)
        @test isfile(pvd_path)
        vti_files = filter(f -> endswith(f, ".vti"), readdir(outdir))
        @test length(vti_files) == 3
    end

    @testset "series with stride" begin
        result = SimulationResult(
            [0.0, 0.1, 0.2, 0.3],
            [1.0, 1.0, 1.0, 1.0],
            [1.0, 1.0, 1.0, 1.0],
            [0.0, 0.0, 0.0, 0.0],
            [copy(psi), copy(psi), copy(psi), copy(psi)],
        )
        outdir = mktempdir()
        export_vtk_series(result, grid;
            output_dir=outdir,
            fields=[:density],
            atom=Rb87,
            stride=2)
        vti_files = filter(f -> endswith(f, ".vti"), readdir(outdir))
        @test length(vti_files) == 2
    end

    @testset "infer F from psi" begin
        outdir = mktempdir()
        path = export_vtk(psi, grid;
            output=joinpath(outdir, "test_infer"),
            fields=[:density])
        @test isfile(path)
    end
end
