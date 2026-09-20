using Test

const STYLES_CONTRACT_ROOT = normpath(joinpath(@__DIR__, ".."))

@testset "display math avoids vertical overflow scrollbars" begin
    styles = read(joinpath(STYLES_CONTRACT_ROOT, "assets", "styles.css"), String)
    math_rule = match(r"(?s)\.math\.display\s*\{(.*?)\}", styles)

    @test !isnothing(math_rule)
    if !isnothing(math_rule)
        declarations = math_rule.captures[1]
        @test occursin("overflow-x: auto;", declarations)
        @test occursin("overflow-y: hidden;", declarations)
    end
end
