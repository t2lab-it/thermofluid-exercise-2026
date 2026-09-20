using Test
using TOML

const ASSIGNMENT_INTERFACE_ROOT = normpath(joinpath(@__DIR__, ".."))
isdefined(@__MODULE__, :parse_qmd_document) ||
    include(joinpath(@__DIR__, "support", "qmd_contracts.jl"))

const ASSIGNMENT_IDENTIFIERS = Dict(
    "N04" => ["SELECTED_MODEL", "advective_flux", "stable_timestep", "advection_diffusion_step!", "analytic_solution", "conserved_integral", "simulate", "main", "exercises/N04_advection_diffusion/tests.jl"],
    "N03" => ["diffusion_step!", "apply_boundary!", "thermal_content", "exercises/N03_diffusion/tests.jl"],
    "N02" => ["burgers_flux", "periodic_left_index", "nonlinear_upwind_step!", "exercises/N02_nonlinear_advection/tests.jl"],
    "F00" => String[],
    "F01" => ["student_greeting", "exercises/F01_first_pull_request/tests.jl"],
    "F02" => ["mean_temperature", "temperature_anomaly", "exercises/F02_julia_arrays_and_tests/tests.jl"],
    "F03" => [
        "gradient_scalar", "curl_vector", "divergence_vector",
        "gradient_divergence_vector", "laplacian_vector",
    ],
    "F04" => [
        "forward_difference", "backward_difference", "centered_difference",
        "centered_partial", "product_divergence_residual", "curl_curl_residual",
        "verify_vector_identities", "exercises/F03-F04_vector_calculus/tests.jl",
    ],
    "N01" => [
        "rectangular_initial_condition", "upwind_step!", "centered_step!",
        "exercises/N01_linear_advection/tests.jl",
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
