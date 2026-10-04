using Test

# Read only the reduction section; unrelated Julia snippets are not examples here.
function reduction_example_blocks(source)
    section = match(r"(?m)^## [^\n]*\{#reduce-bug\}\s*\n(.*?)(?=^## |\z)"s, source)
    isnothing(section) && error("missing reduce-bug section")
    blocks = collect(eachmatch(r"(?m)^```\{\.julia \.reduction-example([^}]*)\}\n(.*?)\n```"s, section[1]))
    isempty(blocks) && error("missing reduction examples")
    julia_count = length(collect(eachmatch(r"(?m)^```(?:julia\b|\{\.?julia\b)", section[1])))
    length(blocks) == julia_count || error("unregistered reduction Julia example")
    return blocks
end

@testset "troubleshooting published reduction examples" begin
    source = read(joinpath(@__DIR__, "..", "guides", "troubleshooting.qmd"), String)
    blocks = reduction_example_blocks(source)
    scope = Module(gensym(:ReductionExamples))
    for (index, block) in enumerate(blocks)
        @testset "example $index" begin
            expected = match(r"expected-error=\"([^\"]+)\"", block[1])
            if isnothing(expected)
                include_string(scope, block[2], "reduction example $index")
            else
                @test expected[1] == "BoundsError"
                @test_throws BoundsError Core.eval(scope, Meta.parse(block[2]))
            end
        end
    end
    # Independent expectations catch a copied but wrong formula or mutated input.
    for (input, expected) in (([2, 5, 9], [7, 14]), ([2, 5], [7]))
        original = copy(input)
        @test_throws BoundsError Base.invokelatest(getfield(scope, :adjacent_sums_bug), input)
        @test input == original
        result = Base.invokelatest(getfield(scope, :adjacent_sums), input)
        @test result == expected
        @test length(result) == length(input) - 1
        @test result !== input
        @test input == original
    end
end

@testset "reduction example inventory rejects omissions" begin
    fixture = """
    ## Example {#reduce-bug}

    ```{.julia .reduction-example}
    1 + 1
    ```

    ## Next section
    ```julia
    2 + 2
    ```
    """
    @test length(reduction_example_blocks(fixture)) == 1
    @test_throws ErrorException reduction_example_blocks("")
    @test_throws ErrorException reduction_example_blocks("## Example {#reduce-bug}\n")
    @test_throws ErrorException reduction_example_blocks(replace(fixture, ".reduction-example" => ""))
    unregistered = replace(fixture, "## Next section" => "```julia\n3 + 3\n```\n\n## Next section")
    @test_throws ErrorException reduction_example_blocks(unregistered)
end
