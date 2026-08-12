const TOPIC_ROOT = joinpath(SITE_ROOT, "projects", "final-project-topics")
const BUILD_SOLVER_TOPICS = [
    "quasi-1d-nozzle", "stefan-problem", "shallow-water-dam-break",
    "natural-convection-cavity", "inverse-heat-source", "incompressible-navier-stokes",
]
const REUSE_SOLVER_TOPICS = [
    "profiling-and-optimization", "gpu-porting", "iterative-solvers",
]
const GUIDED_TOPICS = [
    "waterlily-cylinder-flow", "trixi-shock-tube", "oceananigans-horizontal-convection",
]
const TOPIC_HEADINGS = [
    "## 現象と問題", "## 問いを決める", "## 比較軸", "## 推奨する最小scope",
    "## 評価指標", "## 二層検証", "## 過大scope", "## 手法・package",
    "## 計算負荷", "## 相談事項",
]
const OPEN_PROPOSAL_HEADINGS = [
    "## 対象", "## 計画へのフィードバック", "## 共有する内容",
    "## 教員・TAの支援", "## 日程", "## fallback", "## 評価原則",
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

@testset "natural-convection page reports only measured validation" begin
    source = read(joinpath(TOPIC_ROOT, "natural-convection-cavity.qmd"), String)
    for phrase in (
        "Pr=0.71",
        "65×65",
        "129×129",
        "2×10^-8",
        "de-vahl-davis-reference.csv",
        "Linux",
        "506.57",
        "公開可能",
        "platform waiver",
        "status=ready",
        "publishable=yes",
        "互換性を主張しません",
        "2026-08-12",
    )
        @test occursin(phrase, source)
    end
    @test occursin("macOS", source)
    @test occursin("Windows", source)
    @test !occursin("公開準備中", source)
end

@testset "quasi-1d nozzle Linux-only publication waiver" begin
    source = read(joinpath(TOPIC_ROOT, "quasi-1d-nozzle.qmd"), String)
    for phrase in (
        "Linux",
        "macOS",
        "Windows",
        "platform waiver",
        "status=ready",
        "publishable=yes",
        "互換性を主張しません",
        "2026-08-12",
    )
        @test occursin(phrase, source)
    end
end

@testset "solver-reuse topic pages" begin
    for slug in REUSE_SOLVER_TOPICS
        path = joinpath(TOPIC_ROOT, "$slug.qmd")
        @test isfile(path)
        source = isfile(path) ? read(path, String) : ""
        @test all(heading -> occursin(heading, source), TOPIC_HEADINGS)
        @test occursin("自分のsolver", source)
        @test occursin("回帰検証", source)
        @test !occursin("完成solver", source)
    end
end

@testset "package-guided topic pages" begin
    for slug in GUIDED_TOPICS
        path = joinpath(TOPIC_ROOT, "$slug.qmd")
        @test isfile(path)
        source = isfile(path) ? read(path, String) : ""
        @test all(heading -> occursin(heading, source), TOPIC_HEADINGS)
        for phrase in ("公式example", "固定version", "二層検証", "solver本体の改造は必須ではありません")
            @test occursin(phrase, source)
        end
    end
end

@testset "open proposal page" begin
    path = joinpath(TOPIC_ROOT, "open-proposal.qmd")
    @test isfile(path)
    source = isfile(path) ? read(path, String) : ""
    @test all(heading -> occursin(heading, source), OPEN_PROPOSAL_HEADINGS)
    @test occursin("審査・選抜ではありません", source)
    @test occursin("固定上限を設けません", source)
end
