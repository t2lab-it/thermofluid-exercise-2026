using Test
using TOML

const SITE_ROOT = normpath(joinpath(@__DIR__, ".."))
const VERIFY = joinpath(SITE_ROOT, "scripts", "verify_contracts.jl")

include(VERIFY)

include(joinpath(@__DIR__, "f01_workflow_contract_test.jl"))
include(joinpath(@__DIR__, "public_copy_contract_test.jl"))
include(joinpath(@__DIR__, "navigation_contract_test.jl"))
include(joinpath(@__DIR__, "path_contract_test.jl"))
include(joinpath(@__DIR__, "pages_deployment_contract_test.jl"))

function write_fixture(root::AbstractString; run_path_present::Bool, canonical::AbstractString)
    public = joinpath(root, "public")
    student = joinpath(root, "student")
    mkpath(joinpath(public, "assignments"))
    mkpath(joinpath(student, "exercises", "F00_environment"))

    contract = """
    [assignments.F00]
    site_path = "assignments/F00.qmd"
    run_path = "exercises/F00_environment/run.jl"
    start_command = "julia --project=. scripts/course.jl preflight"
    canonical_url = "$canonical"
    """
    write(joinpath(public, "assignments", "contracts.toml"), contract)
    write(
        joinpath(public, "_quarto.yml"),
        "website:\n  navbar:\n    left:\n      - href: assignments/F00.qmd\n",
    )
    write(
        joinpath(public, "assignments", "F00.qmd"),
        """
        ---
        title: F00
        ---
        `exercises/F00_environment/run.jl`

        `julia --project=. scripts/course.jl preflight`
        """,
    )
    if run_path_present
        write(joinpath(student, "exercises", "F00_environment", "run.jl"), "# fixture\n")
    end
    return (
        contracts=joinpath(public, "assignments", "contracts.toml"),
        public,
        student,
    )
end

function verify_fixture(fixture)
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(SITE_ROOT) $(VERIFY) $(fixture.contracts) $(fixture.public) $(fixture.student)`
    output = PipeBuffer()
    process = run(pipeline(ignorestatus(command); stdout=output, stderr=output))
    return success(process), String(take!(output))
end

@testset "assignment link contract rejects invalid repositories" begin
    @test isfile(VERIFY)

    mktempdir() do root
        fixture = write_fixture(
            root;
            run_path_present=false,
            canonical="https://t2lab-it.github.io/thermofluid-exercise-2026/assignments/F00.html",
        )
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("missing run path", output)
    end

    mktempdir() do root
        fixture = write_fixture(
            root;
            run_path_present=true,
            canonical="https://example.invalid/assignments/F00.html",
        )
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("canonical URL mismatch", output)
    end
end


@testset "fixed public-site contract" begin
    quarto = read(joinpath(SITE_ROOT, "_quarto.yml"), String)
    apostrophe = string(Char(0x27))
    @test occursin("engines: [" * apostrophe * "julia" * apostrophe * "]", quarto)
    @test occursin("execute-dir: project", quarto)
    @test occursin("Copyright © 2026 荒木 亮（ARAKI, Ryo）", quarto)
    for path in (
        "index.qmd", "lessons/N01.qmd", "assignments/N01.qmd",
        "advanced/github-ssh.qmd", "advanced/github-cli.qmd",
        "advanced/cairomakie.qmd", "advanced/package-built-solvers.qmd",
        "LICENSE-CC-BY-4.0.txt", "LICENSE-MIT.txt",
    )
        @test isfile(joinpath(SITE_ROOT, path))
    end

    project = TOML.parsefile(joinpath(SITE_ROOT, "Project.toml"))
    @test project["compat"]["julia"] == "1.12.6"
    @test project["compat"]["Plots"] == "1.41.6"
    @test haskey(project["deps"], "QuartoNotebookRunner")
    @test !haskey(project["deps"], "CairoMakie")
    manifest = read(joinpath(SITE_ROOT, "Manifest.toml"), String)
    @test occursin("julia_version = \"1.12.6\"", manifest)
    @test !occursin("[[deps.CairoMakie]]", manifest)

    png_signature = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    for name in ("N01-upwind.png", "N01-centered-euler.png")
        path = joinpath(SITE_ROOT, "assets", "figures", name)
        @test isfile(path)
        @test 0 < filesize(path) <= 5 * 1024^2
        @test open(io -> read(io, 8), path) == png_signature
    end
end


@testset "assignment link contract rejects structural mismatches" begin
    canonical = "https://t2lab-it.github.io/thermofluid-exercise-2026/assignments/F00.html"

    mktempdir() do root
        fixture = write_fixture(root; run_path_present=true, canonical)
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("assignment ID set mismatch", output)
        @test occursin("N01", output)
    end

    mktempdir() do root
        fixture = write_fixture(root; run_path_present=true, canonical)
        contract = read(fixture.contracts, String)
        write(fixture.contracts, replace(contract, "[assignments.F00]" => "[assignments.F99]"))
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("unexpected=F99", output)
    end

    mktempdir() do root
        fixture = write_fixture(root; run_path_present=true, canonical)
        rm(joinpath(fixture.public, "assignments", "F00.qmd"))
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("missing site path", output)
    end

    mktempdir() do root
        fixture = write_fixture(root; run_path_present=true, canonical)
        write(joinpath(fixture.public, "_quarto.yml"), "website:\n")
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("missing lesson path for F00: lessons/F00.qmd", output)
    end

    mktempdir() do root
        fixture = write_fixture(root; run_path_present=true, canonical)
        page_path = joinpath(fixture.public, "assignments", "F00.qmd")
        page = read(page_path, String)
        write(page_path, replace(
            page,
            "julia --project=. scripts/course.jl preflight" =>
                "julia --project=. scripts/course.jl wrong",
        ))
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("site page start command mismatch", output)
    end

    mktempdir() do root
        fixture = write_fixture(root; run_path_present=true, canonical)
        page_path = joinpath(fixture.public, "assignments", "F00.qmd")
        page = read(page_path, String)
        write(page_path, replace(page, "`exercises/F00_environment/run.jl`\n\n" => ""))
        passed, output = verify_fixture(fixture)
        @test !passed
        @test occursin("site page run path mismatch", output)
    end
end
