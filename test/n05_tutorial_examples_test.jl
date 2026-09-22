using Test

# Execute the published files, not a second implementation of the example.
function n05_example_blocks(source)
    blocks = collect(eachmatch(r"```\{\.(?:julia|toml) \.n05-example #([^}]+)\}\n(.*?)\n```"s, source))
    expected = Set(["n05-project", "n05-before", "n05-package", "n05-boundary", "n05-after", "n05-checks"])
    ids = [m[1] for m in blocks]
    Set(ids) == expected && length(ids) == length(expected) || error("N05 example inventory mismatch")
    length(collect(eachmatch(r"```\{?\.?julia\b", source))) == count(m -> m[1] != "n05-project", blocks) || error("unregistered N05 Julia example")
    Dict(m[1] => m[2] for m in blocks)
end

@testset "N05 published extraction example" begin
    source = read(joinpath(@__DIR__, "..", "lessons", "N05.qmd"), String)
    examples = n05_example_blocks(source)
    @test_throws ErrorException n05_example_blocks("")
    @test_throws ErrorException n05_example_blocks(source * "\n```julia\n1 + 1\n```\n")
    @test_throws ErrorException n05_example_blocks(replace(source, "#n05-before" => "#unknown"))
    # Disable cache generation for the disposable package; leave global depots untouched.
    for stage in ("before", "after")
        mktempdir() do root
            mkpath(joinpath(root, "src"))
            write(joinpath(root, "Project.toml"), examples["n05-project"])
            write(joinpath(root, "src", "ThermofluidExercise.jl"), examples["n05-package"])
            write(joinpath(root, "src", "N01Boundary.jl"), examples["n05-boundary"])
            write(joinpath(root, "boundary.jl"), examples["n05-$stage"])
            write(joinpath(root, "checks.jl"), examples["n05-checks"])
            @test success(pipeline(`$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$root $(joinpath(root, "checks.jl"))`; stdout=stdout, stderr=stderr))
            if stage == "after"
                # A sentinel method proves the old entry actually calls the package,
                # forwards the keyword and preserves the returned object.
                write(joinpath(root, "delegation.jl"), """
                using Test
                include("boundary.jl")
                const calls = Ref(0)
                @eval ThermofluidExercise.N01 function apply_boundary!(u::AbstractVector{<:Real}; left_value::Real = 1.0)
                    Main.calls[] += 1
                    u[1] = left_value + 10
                    return u
                end
                u = [8.0, 9.0]
                @test apply_boundary!(u; left_value=2.0) === u
                @test u == [12.0, 9.0]
                @test calls[] == 1
                @test apply_boundary!(u) === u
                @test u == [11.0, 9.0]
                @test calls[] == 2
                """)
                @test success(pipeline(`$(Base.julia_cmd()) --startup-file=no --compiled-modules=no --project=$root $(joinpath(root, "delegation.jl"))`; stdout=stdout, stderr=stderr))
            end
        end
    end
end
