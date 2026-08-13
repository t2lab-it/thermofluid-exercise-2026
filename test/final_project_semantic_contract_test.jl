using Test

const FINAL_PROJECT_SITE_ROOT = normpath(joinpath(@__DIR__, ".."))

isdefined(@__MODULE__, :parse_qmd_document) ||
    include(joinpath(@__DIR__, "support", "qmd_contracts.jl"))

@testset "final project semantic markers survive heading rewrites" begin
    fixture = """
    <!-- contract-section: participation -->
    ## 任意の見出し
    1人または2人
    <!-- contract-section: scoring -->
    ## 別の任意見出し
    70点と30点
    """
    @test contract_section_ids(fixture) == ["participation", "scoring"]
    @test occursin("1人", contract_section_body(fixture, "participation"))
    @test_throws ArgumentError contract_section_body(
        replace(fixture, "<!-- contract-section: scoring -->" => ""),
        "scoring",
    )
end

@testset "final project page semantic contract" begin
    source = read(joinpath(FINAL_PROJECT_SITE_ROOT, "assignments", "final-project.qmd"), String)
    required = [
        "participation",
        "repository_boundary",
        "validation",
        "third_party_review",
        "scoring",
        "presentation",
    ]

    @test contract_section_ids(source) == required
    @test all(
        value -> occursin(value, contract_section_body(source, "participation")),
        ["1", "2"],
    )
    @test all(
        value -> occursin(value, contract_section_body(source, "scoring")),
        ["70", "30", "100"],
    )
    @test occursin("PDF", contract_section_body(source, "presentation"))
end
