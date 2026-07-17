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

@testset "contract paths enforce canonical filesystem containment" begin
    mktempdir() do parent
        root = joinpath(parent, "root")
        outside = joinpath(parent, "outside")
        mkpath.((root, outside))
        inside_file = joinpath(root, "inside.txt")
        outside_file = joinpath(outside, "outside.txt")
        write(inside_file, "inside\n")
        write(outside_file, "outside\n")

        @test path_inside(root, "missing.txt") === nothing
        nul_path = string("missing", Char(0))
        @test canonical_existing_path(nul_path) === nothing
        @test path_inside(root, nul_path) === nothing

        file_symlinks_supported = try
            symlink(inside_file, joinpath(root, "inside-link.txt"))
            true
        catch error
            error isa Base.IOError || error isa SystemError || rethrow()
            false
        end

        if file_symlinks_supported
            @test path_inside(root, "inside-link.txt") == realpath(inside_file)

            symlink(outside_file, joinpath(root, "outside-link.txt"))
            @test path_inside(root, "outside-link.txt") === nothing

            broken = joinpath(root, "broken-link.txt")
            symlink(joinpath(parent, "absent.txt"), broken)
            @test path_inside(root, "broken-link.txt") === nothing
        else
            @test_skip "file symlink creation is unavailable on this host"
        end

        directory_symlinks_supported = try
            symlink(
                outside, joinpath(root, "outside-directory"); dir_target=true,
            )
            true
        catch error
            error isa Base.IOError || error isa SystemError || rethrow()
            false
        end

        if directory_symlinks_supported
            @test path_inside(
                root, joinpath("outside-directory", "outside.txt"),
            ) === nothing
        else
            @test_skip "directory symlink creation is unavailable on this host"
        end
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
