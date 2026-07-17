using Test
using TOML

const PATH_SITE_ROOT = normpath(joinpath(@__DIR__, ".."))
const PATH_VERIFY = joinpath(PATH_SITE_ROOT, "scripts", "verify_contracts.jl")
isdefined(@__MODULE__, :path_inside) || include(PATH_VERIFY)

@testset "contract paths enforce strict lexical descendants" begin
    mktempdir() do parent
        root = joinpath(parent, "root")
        sibling = joinpath(parent, "sibling")
        prefix_collision = joinpath(parent, "root-other")
        child = joinpath(root, "assignments", "F00.qmd")
        mkpath.(dirname.((child, joinpath(sibling, "file"), joinpath(prefix_collision, "file"))))
        write(child, "fixture\n")

        relative_child = joinpath("assignments", "F00.qmd")
        root_with_separator = root * string(Base.Filesystem.path_separator)
        @test path_inside(root, relative_child) == child
        @test path_inside(root_with_separator, relative_child) == child
        @test path_inside(root, "assignments$(Base.Filesystem.path_separator)F00.qmd") == child

        @test path_inside(root, joinpath("..", "sibling", "file")) === nothing
        @test path_inside(
            root,
            joinpath("assignments", "..", "..", "sibling", "file"),
        ) === nothing
        @test path_inside(root, joinpath("..", "root-other", "file")) === nothing
        @test path_inside(root, sibling) === nothing
        @test path_inside(root, ".") === nothing
        @test path_inside(root, joinpath("assignments", "..")) === nothing
    end
end

@testset "contract verifier accepts literal dot as public root" begin
    mktempdir() do student
        assignments = TOML.parsefile(
            joinpath(PATH_SITE_ROOT, "assignments", "contracts.toml"),
        )["assignments"]
        for entry in values(assignments)
            task = joinpath(student, entry["student_path"])
            mkpath(dirname(task))
            canonical = entry["canonical_url"]
            write(task, "詳しい説明: $canonical\n")
        end

        command = Cmd(
            `$(Base.julia_cmd()) --startup-file=no --project=. $(PATH_VERIFY) assignments/contracts.toml . $(student)`,
            dir=PATH_SITE_ROOT,
        )
        output = PipeBuffer()
        process = run(pipeline(ignorestatus(command); stdout=output, stderr=output))

        @test success(process)
        @test occursin("assignment contracts verified", String(take!(output)))
    end
end
