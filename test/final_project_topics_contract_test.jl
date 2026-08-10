const TOPIC_ROOT = joinpath(SITE_ROOT, "projects", "final-project-topics")
const BUILD_SOLVER_TOPICS = [
    "quasi-1d-nozzle", "stefan-problem", "shallow-water-dam-break",
    "natural-convection-cavity", "inverse-heat-source", "incompressible-navier-stokes",
]
const TOPIC_HEADINGS = [
    "## 現象と問題", "## 問いを決める", "## 比較軸", "## 推奨する最小scope",
    "## 評価指標", "## 二層検証", "## 過大scope", "## 手法・package",
    "## 計算負荷", "## 相談事項",
]

@testset "build-a-solver topic pages" begin
    for slug in BUILD_SOLVER_TOPICS
        path = joinpath(TOPIC_ROOT, "$slug.qmd")
        @test isfile(path)
        source = isfile(path) ? read(path, String) : ""
        @test all(heading -> occursin(heading, source), TOPIC_HEADINGS)
        @test !occursin("このテーマの詳細を見る", source)
        @test !occursin("完成solver", source)
    end
end
