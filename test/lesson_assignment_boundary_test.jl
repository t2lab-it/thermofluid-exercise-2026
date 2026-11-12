using Test

isdefined(@__MODULE__, :parse_qmd_document) ||
    include(joinpath(@__DIR__, "support", "qmd_contracts.jl"))

"""Inspect dependencies, while allowing self-contained code and mathematical examples."""
function lesson_dependencies(source)
    prose = replace(source, r"(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$" => "")
    violations = String[]
    occursin(r"https://github\.com/t2lab-it/thermofluid-exercise-student-2026/(?:blob|tree)/", prose) &&
        push!(violations, "distributed source")
    for m in eachmatch(r"\{\{<\s*include\s+([^>]+?)\s*>\}\}", prose)
        target = strip(m[1], [' ', '\"', Char(0x27)])
        occursin(r"(?:^|/)assignments/", target) &&
            push!(violations, "assignment include: $target")
    end
    violations
end

@testset "lesson dependency classifier" begin
    @test !isempty(lesson_dependencies("[api](https://github.com/t2lab-it/thermofluid-exercise-student-2026/blob/main/src/Example.jl#L1)"))
    @test !isempty(lesson_dependencies("{{< include ../assignments/_elliptic-formulation.qmd >}}"))
    @test !isempty(lesson_dependencies("{{< include /assignments/_understanding-check.qmd >}}"))
    @test isempty(lesson_dependencies(raw"""
    ![一般格子](../assets/grid.svg)
    $u_i^{n+1}$，例の格子幅0.25．
    ```julia
    mean_temperature(x) = sum(x) / length(x)
    isapprox(mean_temperature([1., 2.]), 1.5; atol=1e-12)
    ```
    [指定問題](../assignments/F02.qmd#api)
    """))
end

@testset "all regular lessons are independent" begin
    root = normpath(joinpath(@__DIR__, ".."))
    ids = ["F0$i" for i in 0:4]
    append!(ids, ["N0$i" for i in 1:9])
    for id in ids
        source = read(joinpath(root, "lessons", "$id.qmd"), String)
        @testset "$id" begin
            @test isempty(lesson_dependencies(source))
            @test occursin("../assignments/$id.qmd", source)
        end
    end
end
