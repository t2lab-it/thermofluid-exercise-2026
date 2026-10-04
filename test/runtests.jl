using Test
using TOML

const SITE_ROOT = normpath(joinpath(@__DIR__, ".."))
const VERIFY = joinpath(SITE_ROOT, "scripts", "verify_contracts.jl")

include(VERIFY)

include(joinpath(@__DIR__, "f02_tutorial_examples_test.jl"))
include(joinpath(@__DIR__, "n05_tutorial_examples_test.jl"))
include(joinpath(@__DIR__, "troubleshooting_examples_test.jl"))

include(joinpath(@__DIR__, "public_structure_contract_test.jl"))
include(joinpath(@__DIR__, "public_collaboration_contract_test.jl"))
include(joinpath(@__DIR__, "assignment_interface_contract_test.jl"))
include(joinpath(@__DIR__, "n08_n09_source_links_test.jl"))
include(joinpath(@__DIR__, "reference_artifact_contract_test.jl"))
include(joinpath(@__DIR__, "navigation_contract_test.jl"))
include(joinpath(@__DIR__, "pages_deployment_contract_test.jl"))
function write_complete_contract_fixture(root::AbstractString)
    public = joinpath(root, "public")
    student = joinpath(root, "student")
    mkpath(joinpath(public, "assignments"))
    mkpath(joinpath(public, "lessons"))
    mkpath(joinpath(public, "guides"))

    contracts_source = joinpath(SITE_ROOT, "assignments", "contracts.toml")
    contracts = TOML.parsefile(contracts_source)["assignments"]
    contracts_path = joinpath(public, "assignments", "contracts.toml")
    cp(contracts_source, contracts_path)

    for (id, contract) in contracts
        run_path = contract["run_path"]
        mkpath(dirname(joinpath(student, run_path)))
        write(joinpath(student, run_path), "# fixture\n")
        write(joinpath(public, "lessons", "$id.qmd"), "# $id lesson\n")

        page = "`$run_path`\n"
        if id in ("F00", "F01")
            page *= "\n`$(contract["start_command"])`\n"
        end
        write(joinpath(public, contract["site_path"]), page)
    end
    write(
        joinpath(public, "guides", "workflow.qmd"),
        "`julia --project=. scripts/course.jl start TASK_ID`\n",
    )

    return (; contracts=contracts_path, public, student)
end

function verify_fixture(fixture)
    mktemp() do _, io
        passed = redirect_stdout(io) do
            redirect_stderr(io) do
                main([fixture.contracts, fixture.public, fixture.student]) == 0
            end
        end
        seekstart(io)
        return passed, read(io, String)
    end
end

function edit_contract!(fixture, change!)
    parsed = TOML.parsefile(fixture.contracts)
    change!(parsed["assignments"])
    open(io -> TOML.print(io, parsed), fixture.contracts, "w")
end

@testset "contract verifier rejects broken assignment routing" begin
    cases = (
        ("missing run path", f -> rm(joinpath(f.student, "exercises/F00_environment/run.jl"))),
        ("missing site path", f -> rm(joinpath(f.public, "assignments/F00.qmd"))),
        ("missing lesson path", f -> rm(joinpath(f.public, "lessons/F00.qmd"))),
        ("missing workflow page", f -> rm(joinpath(f.public, "guides/workflow.qmd"))),
        ("missing workflow start command template", f -> write(joinpath(f.public, "guides/workflow.qmd"), "status")),
        ("site page start command mismatch", f -> write(joinpath(f.public, "assignments/F01.qmd"), "exercises/F01_first_pull_request/run.jl")),
        ("site page run path mismatch", f -> write(joinpath(f.public, "assignments/F00.qmd"), "julia --project=. scripts/course.jl preflight")),
        ("canonical URL mismatch", f -> edit_contract!(f, a -> (a["F00"]["canonical_url"] = "https://example.invalid/F00.html"))),
        ("assignment ID set mismatch", f -> edit_contract!(f, a -> (a["F99"] = pop!(a, "N03")))),
        ("combined start command", f -> edit_contract!(f, a -> (a["N06"]["start_command"] = "wrong"))),
        ("duplicate start command", f -> edit_contract!(f, a -> (a["F02"]["start_command"] = a["F03"]["start_command"]))),
        ("missing fields", f -> edit_contract!(f, a -> (a["F03"] = "invalid"))),
        ("duplicate IDs or paths", f -> edit_contract!(f, a -> (a["F02"]["run_path"] = a["F01"]["run_path"]))),
    )
    mktempdir() do root
        @test first(verify_fixture(write_complete_contract_fixture(root)))
    end
    for (diagnostic, damage!) in cases
        mktempdir() do root
            f = write_complete_contract_fixture(root)
            damage!(f)
            passed, output = verify_fixture(f)
            @test !passed && occursin(diagnostic, output)
        end
    end
end

include(joinpath(@__DIR__, "path_contract_test.jl"))
