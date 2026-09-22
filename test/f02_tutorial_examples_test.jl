using Test

@testset "F02 published Julia examples" begin
    source = read(joinpath(@__DIR__, "..", "lessons", "F02.qmd"), String)
    blocks = collect(eachmatch(r"```\{\.julia \.f02-example([^}]*)\}\n(.*?)\n```"s, source))
    @test !isempty(blocks)
    # Every Julia block must participate, so a missing marker cannot silently skip it.
    @test length(blocks) == length(collect(eachmatch(r"(?m)^```(?:julia|\{\.julia\b)", source)))
    scope = Module(gensym(:F02Tutorial))
    errors = Dict("BoundsError" => BoundsError, "InexactError" => InexactError,
                  "ArgumentError" => ArgumentError)
    for (index, block) in enumerate(blocks)
        @testset "example $index" begin
            expected = match(r"expected-error=\"([^\"]+)\"", block[1])
            code = block[2]
            if isnothing(expected)
                include_string(scope, code, "F02 example $index")
            elseif expected[1] == "Test.Fail"
                # Capture the deliberately wrong @test without failing the outer suite.
                intentional = Test.DefaultTestSet("intentional failure"; verbose=false)
                Test.@with_testset intentional begin
                    Core.eval(scope, Meta.parse(code))
                end
                @test length(intentional.results) == 1
                @test only(intentional.results) isa Test.Fail
            else
                exception_type = errors[expected[1]]
                @test_throws exception_type Core.eval(scope, Meta.parse(code))
            end
        end
    end
end
