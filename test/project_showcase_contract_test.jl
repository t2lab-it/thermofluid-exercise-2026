using Test
@testset "project showcase input and artifact contracts" begin
    @test success(`python3 $(joinpath(@__DIR__, "project_showcase_test.py"))`)
    @test success(`python3 $(joinpath(@__DIR__, "..", "scripts", "project_showcase.py")) check $(normpath(joinpath(@__DIR__, "..")))`)
end
