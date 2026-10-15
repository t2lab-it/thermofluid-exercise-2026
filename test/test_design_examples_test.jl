using Test

# IDs identify executable excerpts, independently of the surrounding prose.
const TEST_DESIGN_BLOCK_IDS = [
    "td-f02-integer", "td-f02-weak", "td-f02-zero", "td-f02-reversed",
    "td-f02-floor", "td-f02-copy", "td-f02-alias",
    "td-n03-setup", "td-n03-table", "td-n03-weak", "td-n03-false-rejection",
    "td-n03-heat", "td-n03-bad-heat", "td-n03-values",
    "td-n03-bad-values", "td-n03-unchanged",
]
const TEST_DESIGN_FAILURES = Dict(
    "td-f02-zero" => :(zero_deviations == expected_deviations),
    "td-f02-reversed" => :(reversed_deviations == expected_deviations),
    "td-f02-floor" => :(floored_deviations == expected_deviations),
    "td-n03-false-rejection" => :(sum(updated) == sum(old)),
    "td-n03-bad-heat" => :(heat(wrong_endpoints, dx) == 8.0),
    "td-n03-bad-values" => :(wrong_endpoints == expected_step),
    "td-n03-unchanged" => :(unchanged == expected_step),
)

function test_design_blocks(source)
    blocks = collect(eachmatch(
        r"(?ms)^```\{\.julia #([\w-]+)\}\n(.*?)\n```", source))
    ids = [m[1] for m in blocks]
    # Fail closed on missing/duplicate markers or untested Julia examples.
    @test ids == TEST_DESIGN_BLOCK_IDS
    @test length(blocks) == length(collect(eachmatch(
        r"(?m)^```(?:julia\b|\{[.]?julia\b)", source)))
    return blocks
end

@testset "test design published Julia examples" begin
    path = joinpath(@__DIR__, "..", "advanced", "test-design.qmd")
    @test isfile(path)
    source = isfile(path) ? read(path, String) : ""
    blocks = test_design_blocks(source)
    if [m[1] for m in blocks] == TEST_DESIGN_BLOCK_IDS
        scope = Module(gensym(:TestDesignExamples))
        for block in blocks
            id, code = block.captures
            @testset "$id" begin
                observed = Test.DefaultTestSet(id; verbose=false)
                redirect_stdout(devnull) do
                    Test.@with_testset observed begin
                        include_string(scope, code, "$path:$id")
                    end
                end
                # Error is never accepted in place of an intended assertion failure.
                @test !any(result -> result isa Test.Error, observed.results)
                if haskey(TEST_DESIGN_FAILURES, id)
                    @test length(observed.results) == 1
                    @test observed.n_passed == 0
                    if length(observed.results) == 1
                        result = only(observed.results)
                        @test result isa Test.Fail
                        if result isa Test.Fail
                            @test Meta.parse(string(result.orig_expr)) == TEST_DESIGN_FAILURES[id]
                            @test result.test_type == :test
                        end
                    end
                else
                    @test isempty(observed.results)
                    @test observed.n_passed > 0
                end
            end
        end
        # Hand-derived observations also guard against a published @test being
        # weakened to `true`, or a table drifting away from the executed example.
        @test Core.eval(scope, :(integer_deviations)) == [-3.0, -1.0, 4.0]
        @test Core.eval(scope, :(correct_deviations)) == [-0.5, 0.5]
        @test Core.eval(scope, :(zero_deviations)) == [0.0, 0.0]
        @test Core.eval(scope, :(reversed_deviations)) == [0.5, -0.5]
        @test Core.eval(scope, :(floored_deviations)) == [0.0, 1.0]
        @test Core.eval(scope, :(saved_values)) == [1.0, 2.0]
        @test Core.eval(scope, :(alias_values)) == [99.0, 2.0]
        @test Core.eval(scope, :(old)) == [1.0, 2.0, 4.0, 3.0]
        @test Core.eval(scope, :(updated)) == [1.5, 2.25, 3.25, 3.5]
        @test Core.eval(scope, :(wrong_endpoints)) == [1.25, 2.25, 3.25, 3.25]
        @test Core.eval(scope, :(unchanged)) == [1.0, 2.0, 4.0, 3.0]
        @test Core.eval(scope, :(heat_table)) == [8.0, 8.0, 7.75, 8.0]
        @test Core.eval(scope, :(sum_table)) == [10.0, 10.5, 10.0, 10.0]
    end
end
