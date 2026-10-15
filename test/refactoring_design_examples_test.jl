using Test

# Every Julia block in the article is a complete file, executed below.
function refactoring_design_blocks(source)
    matches = collect(eachmatch(r"```\{\.julia \.refactoring-example #([^}]+)\}\n(.*?)\n```"s, source))
    expected = Set(["rd-before", "rd-common", "rd-after", "rd-wide", "rd-missing",
                    "rd-strict", "rd-retained", "rd-checks", "rd-compare"])
    ids = [m[1] for m in matches]
    Set(ids) == expected && length(ids) == length(expected) ||
        error("refactoring example inventory mismatch")
    length(collect(eachmatch(r"(?m)^```\{?\.?julia\b", source))) == length(matches) ||
        error("unregistered refactoring Julia example")
    return Dict(m[1] => m[2] for m in matches)
end

function run_refactoring_file(root, file, args...)
    command = `$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$root $(joinpath(root, file)) $args`
    return success(pipeline(command; stdout=stdout, stderr=stderr))
end

@testset "refactoring design published examples" begin
    path = joinpath(@__DIR__, "..", "advanced", "refactoring-design.qmd")
    @test isfile(path)
    if isfile(path)
        source = read(path, String)
        blocks = refactoring_design_blocks(source)
        @test_throws ErrorException refactoring_design_blocks("")
        @test_throws ErrorException refactoring_design_blocks(source * "\n```julia\n1\n```\n")
        @test_throws ErrorException refactoring_design_blocks(source * "\n```{.julia #extra}\n1\n```\n")
        @test_throws ErrorException refactoring_design_blocks(replace(source, "#rd-before" => "#unknown"))
        @test_throws ErrorException refactoring_design_blocks(source * "\n```{.julia .refactoring-example #rd-before}\n1\n```\n")
        mktempdir() do root
            write(joinpath(root, "Project.toml"), "[deps]\n")
            for (id, code) in blocks
                write(joinpath(root, replace(id, "rd-" => "") * ".jl"), code)
            end
            # Before, delegated entry and direct common call cannot supply each
            # other's missing dependencies: each is a fresh Julia process.
            for stage in ("before", "after", "common", "retained")
                @test run_refactoring_file(root, "checks.jl", stage)
            end
            @test run_refactoring_file(root, "compare.jl")

            # Isolate the missing dependency even from the old script's definitions.
            write(joinpath(root, "failure.jl"), raw"""
            using Test
            include("missing.jl")
            u = [8.,9.]
            exception = try
                MissingDependency.apply_boundary!(u)
            catch e
                e isa UndefVarError || rethrow()
                e
            end
            @test exception isa UndefVarError
            @test exception.var == :validate_boundary_inputs
            @test u == [8.,9.]
            """)
            @test run_refactoring_file(root, "failure.jl")

            # Independent expectations from the plan, in addition to the published checks.
            write(joinpath(root, "contract.jl"), raw"""
            using Test
            stage = only(ARGS)
            include(stage * ".jl")
            f = stage == "common" ? BoundaryCore.inlet_outlet! : apply_boundary!
            g = stage == "common" ? BoundaryCore.fixed_ends! : fixed_boundary!
            @testset "independent boundary contract: $stage" begin
                for (input, options, expected) in (
                    ([2.,3.,4.], (;), [1.,3.,3.]),
                    ([2.,3.,4.], (;left_value=5.), [5.,3.,3.]),
                    ([8.,9.], (;left_value=2.), [2.,2.]),
                    ([2.,3.,4.,6.], (;left_value=5.), [5.,3.,4.,4.]),
                )
                    u = copy(input)
                    @test f(u; options...) === u
                    @test u == expected
                end
                u = [2.,3.,4.]
                @test g(u; left_value=5., right_value=7.) === u
                @test u == [5.,3.,7.]
                u = [8.,9.]
                @test g(u; left_value=2., right_value=7.) === u
                @test u == [2.,7.]
                for input in (Float64[], [8.], [8.,9.], [2.,3.,4.])
                    for value in (1., Inf, NaN)
                        if length(input) < 2 || !isfinite(value)
                            u = copy(input)
                            @test_throws ArgumentError f(u; left_value=value)
                            @test isequal(u, input)
                        end
                    end
                    for (left, right) in ((5.,7.), (Inf,7.), (NaN,7.), (5.,Inf), (5.,NaN))
                        if length(input) < 2 || !all(isfinite, (left,right))
                            u = copy(input)
                            @test_throws ArgumentError g(u; left_value=left, right_value=right)
                            @test isequal(u, input)
                        end
                    end
                end
            end
            """)
            for stage in ("before", "after", "common")
                @test run_refactoring_file(root, "contract.jl", stage)
            end
            # Same numeric outputs can conceal retained duplication. Replace only
            # the disposable example's common method, never real student code.
            write(joinpath(root, "delegation.jl"), raw"""
            using Test
            stage = only(ARGS)
            include(stage * ".jl")
            const calls = Float64[]
            const token = Ref(:common_return)
            @eval BoundaryCore function inlet_outlet!(u::Vector{Float64}; left_value::Float64=1.0)
                push!(Main.calls, left_value)
                u[1] = left_value + 10.0
                return Main.token
            end
            @testset "actual delegation: $stage" begin
                u = [8.,9.]
                if stage == "after"
                    @test apply_boundary!(u; left_value=2.) === token
                    @test u == [12.,9.]
                    @test apply_boundary!(u) === token
                    @test u == [11.,9.]
                    @test calls == [2.,1.]
                else
                    @test apply_boundary!(u; left_value=2.) === u
                    @test u == [2.,2.]
                    @test isempty(calls)
                end
            end
            """)
            for stage in ("after", "retained")
                @test run_refactoring_file(root, "delegation.jl", stage)
            end
        end
    end
end
