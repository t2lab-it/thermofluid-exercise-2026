using Test
using TOML

const PATH_SITE_ROOT = normpath(joinpath(@__DIR__, ".."))
const PATH_VERIFY = joinpath(PATH_SITE_ROOT, "scripts", "verify_contracts.jl")
isdefined(@__MODULE__, :path_inside) || include(PATH_VERIFY)

function write_verifier_fixture(parent; missing_lesson_link=nothing, navigation_paths=false)
    public = joinpath(parent, "public")
    student = joinpath(parent, "student")
    mkpath.((joinpath(public, "assignments"), joinpath(public, "lessons"), student))

    contracts_source = joinpath(PATH_SITE_ROOT, "assignments", "contracts.toml")
    contracts_path = joinpath(public, "assignments", "contracts.toml")
    cp(contracts_source, contracts_path)
    assignments = TOML.parsefile(contracts_path)["assignments"]

    navigation = navigation_paths ?
                 join((entry["site_path"] for entry in values(assignments)), '\n') :
                 "website:\n  title: fixture\n"
    write(joinpath(public, "_quarto.yml"), navigation)

    for (id, entry) in assignments
        site_path = entry["site_path"]
        student_path = entry["student_path"]
        command = entry["start_command"]
        canonical = entry["canonical_url"]

        site_file = joinpath(public, site_path)
        mkpath(dirname(site_file))
        write(site_file, "student: $student_path\ncommand: $command\n")

        lesson_file = joinpath(public, "lessons", "$id.qmd")
        lesson = id == missing_lesson_link ?
                 "# Lesson $id\n" :
                 "[課題](../$site_path#完了条件)\n"
        write(lesson_file, lesson)

        student_file = joinpath(student, student_path)
        mkpath(dirname(student_file))
        write(student_file, "詳しい説明: $canonical\n")
    end

    return contracts_path, public, student
end

function run_contract_verifier(contracts_path, public, student)
    command = `$(Base.julia_cmd()) --startup-file=no --project=. $(PATH_VERIFY) $(contracts_path) $(public) $(student)`
    output = PipeBuffer()
    process = run(pipeline(ignorestatus(command); stdout=output, stderr=output))
    return success(process), String(take!(output))
end

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

@testset "contract verifier follows lesson assignment links" begin
    mktempdir() do parent
        contracts, public, student = write_verifier_fixture(parent)
        passed, output = run_contract_verifier(contracts, public, student)

        @test passed
        @test occursin("assignment contracts verified", output)
    end

    mktempdir() do parent
        contracts, public, student = write_verifier_fixture(
            parent;
            missing_lesson_link="F00",
            navigation_paths=true,
        )
        passed, output = run_contract_verifier(contracts, public, student)

        @test !passed
        @test occursin("lesson assignment link missing for F00", output)
        @test occursin("../assignments/F00.qmd", output)
        @test !occursin("nav inclusion missing", output)
    end

    deceptive_lessons = Dict(
        "plain assignment path" => "See ../assignments/F00.qmd for details.\n",
        "longer invalid target" => "[課題](../assignments/F00.qmd.disabled)\n",
        "fenced code example" => "```markdown\n[課題](../assignments/F00.qmd)\n```\n",
        "HTML comment" => "<!-- [課題](../assignments/F00.qmd) -->\n",
    )
    for (description, lesson) in deceptive_lessons
        mktempdir() do parent
            contracts, public, student = write_verifier_fixture(parent)
            write(joinpath(public, "lessons", "F00.qmd"), lesson)
            passed, output = run_contract_verifier(contracts, public, student)

            @test !passed
            @test occursin("lesson assignment link missing for F00", output)
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
