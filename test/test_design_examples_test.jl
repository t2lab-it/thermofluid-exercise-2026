using Test

# IDs identify executable excerpts, independently of the surrounding prose.
const TEST_DESIGN_SECTIONS = [
    (anchor="deviations", blocks=[
        "td-f02-integer" => 1, "td-f02-weak" => 4,
        "td-f02-zero" => 0, "td-f02-reversed" => 0, "td-f02-floor" => 0]),
    (anchor="input-preservation", blocks=[
        "td-input-setup" => 0, "td-input-alias" => 1,
        "td-input-copy" => 2, "td-input-mutating" => 0]),
    (anchor="input-transformation", blocks=[
        "td-shift-setup" => 0, "td-shift-weak" => 1,
        "td-shift-correct" => 2, "td-shift-bad" => 0]),
    (anchor="conservation", blocks=[
        "td-n03-setup" => 0, "td-n03-weak" => 2,
        "td-n03-heat" => 2, "td-n03-change" => 2,
        "td-n03-false-rejection" => 0, "td-n03-bad-heat" => 0,
        "td-n03-unchanged" => 0]),
]
const TEST_DESIGN_BLOCK_IDS = [first(b) for s in TEST_DESIGN_SECTIONS for b in s.blocks]
const TEST_DESIGN_FAILURES = Dict(
    "td-f02-zero" => :(zero_deviations == expected_deviations),
    "td-f02-reversed" => :(reversed_deviations == expected_deviations),
    "td-f02-floor" => :(floored_deviations == expected_deviations),
    "td-shift-bad" => :(sum_anomaly(x .+ c) == sum_anomaly(x)),
    "td-input-mutating" => :(bad_values == bad_before),
    "td-n03-false-rejection" => :(sum(updated) == sum(old)),
    "td-n03-bad-heat" => :(heat(wrong_endpoints, dx) == heat(old, dx)),
    "td-n03-unchanged" => :(unchanged != old),
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

# Capture ordinary Test results without treating exceptions as intended failures.
function observe_design_code(scope, code, filename)
    observed = Test.DefaultTestSet(filename; verbose=false)
    redirect_stdout(devnull) do
        Test.@with_testset observed begin
            include_string(scope, code, filename)
        end
    end
    return observed
end

@testset "test design published Julia examples" begin
    path = joinpath(@__DIR__, "..", "advanced", "test-design.qmd")
    source = read(path, String)
    blocks = test_design_blocks(source)
    if [m[1] for m in blocks] == TEST_DESIGN_BLOCK_IDS
        by_id = Dict(m[1] => m for m in blocks)
        for section in TEST_DESIGN_SECTIONS
            @testset "$(section.anchor) in isolation" begin
                # A block must belong to the section whose definitions it uses.
                section_source = only(filter(s -> occursin(
                    "{#$(section.anchor)}", first(split(s, '\n'))),
                    split(source, r"(?m)^## ")))
                @test [m[1] for m in eachmatch(
                    r"(?m)^```\{\.julia #([\w-]+)\}", section_source)] == first.(section.blocks)
                setup = String[]
                scope = Module(gensym(:TestDesignSection))
                for (id, passes) in section.blocks
                    code = by_id[id][2]
                    @testset "$id" begin
                        if haskey(TEST_DESIGN_FAILURES, id)
                            # Replay only earlier successful blocks, so failures
                            # cannot share mutations or depend on later setup.
                            failure_scope = Module(gensym(:TestDesignFailure))
                            preparation = observe_design_code(failure_scope,
                                join(setup, "\n"), "$path:$id:preparation")
                            @test isempty(preparation.results)
                            observed = observe_design_code(failure_scope, code, "$path:$id")
                            @test observed.n_passed == 0
                            @test length(observed.results) == 1
                            if length(observed.results) == 1
                                result = only(observed.results)
                                @test result isa Test.Fail
                                if result isa Test.Fail
                                    @test Meta.parse(string(result.orig_expr)) == TEST_DESIGN_FAILURES[id]
                                    @test result.test_type == :test
                                end
                            end
                        else
                            observed = observe_design_code(scope, code, "$path:$id")
                            @test isempty(observed.results)
                            @test observed.n_passed == passes
                            push!(setup, code)
                        end
                        @test !any(result -> result isa Test.Error, observed.results)
                    end
                end
                # Known values are maintenance regressions, independent of the
                # article's choice of comparison evidence.
                if section.anchor == "deviations"
                    @test Core.eval(scope, :(integer_deviations)) == [-3.0, -1.0, 4.0]
                    @test Core.eval(scope, :(correct_deviations)) == [-0.5, 0.5]
                    @test Core.eval(scope, :(zero_deviations)) == [0.0, 0.0]
                    @test Core.eval(scope, :(reversed_deviations)) == [0.5, -0.5]
                    @test Core.eval(scope, :(floored_deviations)) == [0.0, 1.0]
                elseif section.anchor == "input-preservation"
                    @test Core.eval(scope, :(alias_values === alias_before))
                    @test Core.eval(scope, :(alias_values)) == [-0.5, 0.5]
                    @test Core.eval(scope, :(good_values)) == [1.0, 2.0]
                    @test Core.eval(scope, :(good_values !== good_before))
                    @test Core.eval(scope, :(bad_values !== bad_before))
                    @test Core.eval(scope, :(bad_before)) == [1.0, 2.0]
                    @test Core.eval(scope, :(bad_values)) == [-0.5, 0.5]
                    @test Core.eval(scope, :(good_result == bad_result))
                elseif section.anchor == "input-transformation"
                    @test Core.eval(scope, :(x)) == [1.0, 2.0]
                    @test Core.eval(scope, :(c)) == 10.0
                    @test Core.eval(scope, :(anomaly(x .+ c))) == [-0.5, 0.5]
                    @test Core.eval(scope, :(sum_anomaly(x))) == [-2.0, -1.0]
                    @test Core.eval(scope, :(sum_anomaly(x .+ c))) == [-12.0, -11.0]
                elseif section.anchor == "conservation"
                    @test Core.eval(scope, :([
                        (sum(u) == sum(old), heat(u, dx) == heat(old, dx), u != old)
                        for u in [updated, wrong_endpoints, unchanged]
                    ])) == [(false, true, true), (true, false, true), (true, true, false)]
                    @test Core.eval(scope, :(old)) == [1.0, 2.0, 4.0, 3.0]
                    @test Core.eval(scope, :(updated)) == [1.5, 2.25, 3.25, 3.5]
                    @test Core.eval(scope, :(wrong_endpoints)) == [1.25, 2.25, 3.25, 3.25]
                    @test Core.eval(scope, :(unchanged)) == [1.0, 2.0, 4.0, 3.0]
                    @test Core.eval(scope, :([heat(u, dx) for u in [old, updated, wrong_endpoints, unchanged]])) == [8.0, 8.0, 7.75, 8.0]
                    @test Core.eval(scope, :([sum(u) for u in [old, updated, wrong_endpoints, unchanged]])) == [10.0, 10.5, 10.0, 10.0]
                end
            end
        end
    end
end
