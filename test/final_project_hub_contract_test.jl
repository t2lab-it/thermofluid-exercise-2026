const FINAL_PROJECT_HUB = read(joinpath(SITE_ROOT, "assignments", "final-project.qmd"), String)
const TOPIC_SLUGS = [
    "quasi-1d-nozzle", "stefan-problem", "shallow-water-dam-break",
    "natural-convection-cavity", "inverse-heat-source", "profiling-and-optimization",
    "gpu-porting", "iterative-solvers", "incompressible-navier-stokes",
    "waterlily-cylinder-flow", "trixi-shock-tube",
    "oceananigans-horizontal-convection", "open-proposal",
]

@testset "final project hub" begin
    for slug in TOPIC_SLUGS
        @test occursin("../projects/final-project-topics/$slug.qmd", FINAL_PROJECT_HUB)
    end
    for banned in ("2〜3人", "実施単位", "このテーマの詳細を見る", "前日17:00")
        @test !occursin(banned, FINAL_PROJECT_HUB)
    end
    @test occursin("11月13日", FINAL_PROJECT_HUB)
    @test occursin("11月27日", FINAL_PROJECT_HUB)
    @test occursin("12月4日", FINAL_PROJECT_HUB)
end
