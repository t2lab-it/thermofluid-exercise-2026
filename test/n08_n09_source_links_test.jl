using Test

include(joinpath(@__DIR__, "..", "scripts", "verify_n08_n09_source_links.jl"))
using .N08N09SourceLinks

@testset "N08/N09 source links identify definitions on student main" begin
    base = "https://github.com/t2lab-it/thermofluid-exercise-student-2026/blob"
    link(name, line; ref="main") = "[`$name`]($base/$ref/src/N08N09Elliptic.jl#L$line)"
    source = "module Elliptic\nfunction poisson_jacobi_step!(u)\n# TODO poisson_jacobi_step!\nend\nsolve_poisson(u)=u\nfunction laplace_jacobi_step!(u)\nend\nend\n"
    read_source = (ref, path) -> source

    valid = join((link("poisson_jacobi_step!(u)", 2), link("solve_poisson", 5),
                  link("ThermofluidExercise.Elliptic", 1)), "\n")
    @test isempty(check_links(valid, "fixture",
                             (ref, path) -> ref == "main" ? source : error("unexpected student ref")))
    @test !isempty(check_links(link("poisson_jacobi_step!", 3), "fixture", read_source))
    @test !isempty(check_links(link("poisson_jacobi_step!", 6), "fixture", read_source))
    @test !isempty(check_links(link("solve_poisson", 99), "fixture", read_source))
    @test !isempty(check_links(link("solve_poisson", 5; ref=repeat("a", 40)), "fixture", read_source))
    @test !isempty(check_links(link("solve_poisson", 5), "fixture",
                              (ref, path) -> error("missing Git object")))
    @test !isempty(check_links(valid * "\n[unlabelled]($base/main/src/example.jl#L3)",
                              "fixture", read_source))
end

@testset "N08/N09 range links preserve the existing API" begin
    base = "https://github.com/t2lab-it/thermofluid-exercise-student-2026/blob/main/src/example.jl"
    source = "module Elliptic\nfunction poisson_jacobi_step!(u)\nu\nend\nend\n"
    text = "[`poisson_jacobi_step!(u)`]($base#L2-L4)"
    links = source_links(text)
    @test length(links) == 1
    @test only(links).name == "poisson_jacobi_step!"
    @test only(links).line == 2
    @test only(links).ref == "main"
    @test !isempty(check_links(replace(text, "L2-L4" => "L2-L3"), "fixture", (ref, path) -> source))
    directory = "[exercise](https://github.com/t2lab-it/thermofluid-exercise-student-2026/tree/main/exercises/N08-N09_laplace_poisson)"
    @test isempty(check_links(text * "\n" * directory, "fixture", (ref, path) -> source))
end

@testset "all four pages follow student main" begin
    root = normpath(joinpath(@__DIR__, ".."))
    @test all(N08N09SourceLinks.PAGES) do page
        links = source_links(read(joinpath(root, page), String))
        !isempty(links) && all(link -> link.ref == "main", links)
    end
end
