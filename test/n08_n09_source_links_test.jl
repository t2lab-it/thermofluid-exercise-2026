using Test

include(joinpath(@__DIR__, "..", "scripts", "verify_n08_n09_source_links.jl"))
using .N08N09SourceLinks

@testset "N08/N09 source links identify definitions at immutable commits" begin
    commit = repeat("a", 40)
    base = "https://github.com/t2lab-it/thermofluid-exercise-student-2026/blob"
    link(name, line; ref=commit) = "[`$name`]($base/$ref/src/example.jl#L$line)"
    source = "module Elliptic\nfunction poisson_jacobi_step!(u)\n# TODO poisson_jacobi_step!\nend\nsolve_poisson(u)=u\nfunction laplace_jacobi_step!(u)\nend\n"
    read_source = (ref, path) -> source

    valid = join((link("poisson_jacobi_step!(u)", 2), link("solve_poisson", 5),
                  link("ThermofluidExercise.Elliptic", 1)), "\n")
    @test isempty(check_links(valid, "fixture", read_source))
    @test !isempty(check_links(link("poisson_jacobi_step!", 3), "fixture", read_source))
    @test !isempty(check_links(link("poisson_jacobi_step!", 6), "fixture", read_source))
    @test !isempty(check_links(link("solve_poisson", 99), "fixture", read_source))
    @test !isempty(check_links(link("solve_poisson", 5; ref="main"), "fixture", read_source))
    @test !isempty(check_links(link("solve_poisson", 5; ref="aaaaaaa"), "fixture", read_source))
    @test !isempty(check_links(link("solve_poisson", 5), "fixture",
                              (ref, path) -> error("missing Git object")))
    @test !isempty(check_links(link("ThermofluidExercise.Other", 1), "fixture", read_source))
    @test !isempty(check_links("no definition links", "fixture", read_source))
    @test !isempty(check_links(valid * "\n[unlabelled]($base/$commit/src/example.jl#L3)",
                              "fixture", read_source))

    # The URL commit must select the source, even if main has moved.
    refs = String[]
    @test isempty(check_links(link("solve_poisson", 5), "fixture", (ref, path) -> begin
        push!(refs, ref)
        ref == commit ? source : "# changed main\n"
    end))
    @test refs == [commit]
end

@testset "all four pages retain pinned required, driver and extension links" begin
    root = normpath(joinpath(@__DIR__, ".."))
    expected = Dict(
        "lessons/N08.qmd" => ["laplace_jacobi_step!", "apply_dirichlet!", "laplace_residual!"],
        "lessons/N09.qmd" => ["poisson_jacobi_step!", "poisson_residual!"],
        "assignments/N08.qmd" => ["Elliptic", "apply_dirichlet!", "laplace_jacobi_step!",
                                 "laplace_residual!", "residual_converged", "solve_laplace"],
        "assignments/N09.qmd" => ["Elliptic", "poisson_jacobi_step!", "poisson_residual!",
                                 "solve_poisson", "neumann_jacobi_step!", "neumann_residual!",
                                 "solve_neumann", "gauss_seidel_step!", "sor_step!"],
    )
    for (page, names) in expected
        source = read(joinpath(root, page), String)
        links = source_links(source)
        @test Set(link.name for link in links) == Set(names)
        @test all(link -> occursin(r"^[0-9a-f]{40}$", link.commit), links)
    end
end
