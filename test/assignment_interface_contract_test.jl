using Test
using TOML

const ASSIGNMENT_INTERFACE_ROOT = normpath(joinpath(@__DIR__, ".."))
isdefined(@__MODULE__, :parse_qmd_document) ||
    include(joinpath(@__DIR__, "support", "qmd_contracts.jl"))

const ASSIGNMENT_IDENTIFIERS = Dict(
    "F00" => String[],
    "F01" => ["student_greeting", "test/student/F01.jl"],
    "F02" => ["mean_temperature", "temperature_anomaly", "test/student/F02.jl"],
    "F03" => [
        "gradient_scalar", "curl_vector", "laplacian_scalar",
    ],
    "F04" => [
        "forward_difference", "backward_difference", "centered_difference",
        "centered_partial", "verify_vector_identities", "test/student/F04.jl",
    ],
    "N01" => [
        "rectangular_initial_condition", "upwind_step!", "centered_step!",
        "test/student/N01.jl",
    ],
)

@testset "assignment identifiers survive prose rewrites" begin
    rewritten = "A new explanation mentions `student_api` and `test/student/F99.jl`."
    @test isempty(missing_required_identifiers(
        rewritten,
        ["student_api", "test/student/F99.jl"],
    ))
    @test missing_required_identifiers(rewritten, ["student_api", "missing_api"]) == [
        "missing_api",
    ]
end

@testset "assignment pages preserve student-facing identifiers" begin
    contracts = TOML.parsefile(
        joinpath(ASSIGNMENT_INTERFACE_ROOT, "assignments", "contracts.toml"),
    )["assignments"]

    for (id, contract) in contracts
        source = read(joinpath(ASSIGNMENT_INTERFACE_ROOT, contract["site_path"]), String)
        required = get(ASSIGNMENT_IDENTIFIERS, id, String[])
        @test isempty(missing_required_identifiers(source, required))
    end
end

@testset "removed machine identifier is reported" begin
    source = read(joinpath(ASSIGNMENT_INTERFACE_ROOT, "assignments", "F01.qmd"), String)
    rewritten = replace(source, "student_greeting" => "replacement_api")
    @test missing_required_identifiers(rewritten, ASSIGNMENT_IDENTIFIERS["F01"]) == [
        "student_greeting",
    ]
end
