using Test

@testset "refactoring design distributed file links" begin
    path = joinpath(@__DIR__, "..", "advanced", "refactoring-design.qmd")
    source = read(path, String)
    base = "https://github.com/t2lab-it/thermofluid-exercise-student-2026/blob/main/examples/refactoring-design"
    files = ("before", "common", "after", "wide", "strict", "checks", "compare")
    file_links = Set(m[1] for m in eachmatch(
        r"\]\((https://github\.com/t2lab-it/thermofluid-exercise-student-2026/blob/main/examples/refactoring-design/[^)]+)\)", source))
    @test file_links == Set("$base/$file.jl" for file in files)
end
