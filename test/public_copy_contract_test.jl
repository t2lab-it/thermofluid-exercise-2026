using Test

const COPY_ROOT = normpath(joinpath(@__DIR__, ".."))
copy_source(path) = read(joinpath(COPY_ROOT, path), String)

const POSITION_LABELS = Dict(
    "setup/index.qmd" => "準備 1/5",
    "setup/julia.qmd" => "準備 2/5",
    "setup/git-github.qmd" => "準備 3/5",
    "setup/agents.qmd" => "準備 4/5",
    "guides/workflow.qmd" => "準備 5/5",
    "lessons/F00.qmd" => "第1回・授業 1/2 · 課題ID: F00",
    "assignments/F00.qmd" => "第1回・課題 2/2 · 課題ID: F00",
    "lessons/F01.qmd" => "第2回・授業 1/2 · 課題ID: F01",
    "assignments/F01.qmd" => "第2回・課題 2/2 · 課題ID: F01",
    "guides/testing.qmd" => "第2回後・必読",
    "lessons/F02.qmd" => "第3回・授業 1/2 · 課題ID: F02",
    "assignments/F02.qmd" => "第3回・課題 2/2 · 課題ID: F02",
    "lessons/F03.qmd" => "第4回・授業 1/2 · 課題ID: F03",
    "assignments/F03.qmd" => "第4回・課題 2/2 · 課題ID: F03",
    "lessons/N01.qmd" => "第5回・授業 1/2 · 課題ID: N01",
    "assignments/N01.qmd" => "第5回・課題 2/2 · 課題ID: N01",
    "guides/commands.qmd" => "参照・コマンド一覧",
    "guides/troubleshooting.qmd" => "参照・トラブル対応",
    "guides/glossary.qmd" => "参照・用語集",
    "advanced/cairomakie.qmd" => "任意・発展資料",
)

const NO_ID_TITLE = Dict(
    "lessons/F00.qmd" => "ガイダンスと環境診断",
    "assignments/F00.qmd" => "環境診断",
    "lessons/F01.qmd" => "Julia・Git・GitHubの最小操作",
    "assignments/F01.qmd" => "最初のbranchとpull request",
    "lessons/F02.qmd" => "配列・関数・loop・テスト",
    "assignments/F02.qmd" => "Juliaの配列・関数・テスト",
    "lessons/F03.qmd" => "ベクトル解析・熱伝導・差分と添字",
    "assignments/F03.qmd" => "座標・添字・差分の数値計算入門",
    "lessons/N01.qmd" => "移流方程式と安定性",
    "assignments/N01.qmd" => "1次元線形移流方程式",
    "advanced/cairomakie.qmd" => "CairoMakieによる可視化",
)

function section_body(source, heading)
    matched = match(Regex("(?ms)^## " * heading * "\\n(.*?)(?=^## |\\z)"), source)
    return isnothing(matched) ? nothing : matched.captures[1]
end
function frontmatter_title(source)
    lines = split(source, '\n'; keepempty=true)
    first(lines) == "---" || return nothing
    closing = findnext(==("---"), lines, 2)
    isnothing(closing) && return nothing
    titles = filter(!isnothing, [match(r"^title:\s*\"([^\"]+)\"\s*$", line) for line in lines[2:(closing - 1)]])
    length(titles) == 1 || return nothing
    return only(titles).captures[1]
end

function public_qmd_paths()
    paths = ["index.qmd"]
    for directory in ("setup", "lessons", "assignments", "guides", "advanced")
        for (root, _, files) in walkdir(joinpath(COPY_ROOT, directory))
            for file in files
                endswith(file, ".qmd") || continue
                push!(paths, relpath(joinpath(root, file), COPY_ROOT))
            end
        end
    end
    return sort!(paths)
end

const MINUTE_RANGE_PATTERN = r"[0-9]+\s*[-–—〜~～]\s*[0-9]+\s*分"


@testset "public learning-copy contract" begin
@testset "copy-source parsers reject misleading placement" begin
    @test frontmatter_title("---\ntitle: \"正しいタイトル\"\n---\ntitle: \"本文の偽物\"\n") == "正しいタイトル"
    @test isnothing(frontmatter_title("title: \"frontmatter外\"\n"))
    for fixture in ("0-15分", "0–15 分", "0〜15分", "0～15分", "0~15分")
        @test !isnothing(match(MINUTE_RANGE_PATTERN, fixture))
    end
end

@testset "public copy positions and visible titles" begin
    for (path, label) in POSITION_LABELS
        source = copy_source(path)
        @test occursin("::: {.course-position}\n$label\n:::", source)
    end
    for (path, title) in NO_ID_TITLE
        @test frontmatter_title(copy_source(path)) == title
    end
end

@testset "public entry pages use concrete visible names" begin
    home = copy_source("index.qmd")
    for removed in (
        "Juliaで理解・実装・検証・調査をつなぐ",
        "この公開教材は、熱流体力学の式を読み",
        "受講環境の準備から始める",
    )
        @test !occursin(removed, home)
    end
    for link_text in (
        "[ガイダンスと環境診断](lessons/F00.qmd)",
        "[環境診断](assignments/F00.qmd)",
        "[Julia・Git・GitHubの最小操作](lessons/F01.qmd)",
        "[最初のbranchとpull request](assignments/F01.qmd)",
    )
        @test occursin(link_text, home)
    end
    @test !occursin(r"\[[FN][0-9]{2}\s+(?:授業|課題)\]", home)
    @test occursin("[受講環境の準備へ進む](setup/index.qmd){.start-button}", home)

    for path in ("lessons/index.qmd", "assignments/index.qmd", "guides/index.qmd", "advanced/index.qmd")
        hub = copy_source(path)
        @test !occursin("::: {.eyebrow}", hub)
    end
end


@testset "public lesson outcomes have bounded bullet counts" begin
    for id in ("F00", "F01", "F02", "F03", "N01")
        source = copy_source("lessons/$id.qmd")
        outcomes = section_body(source, "この回の到達点")
        @test !isnothing(outcomes)
        if !isnothing(outcomes)
            bullets = [line for line in split(outcomes, '\n') if startswith(line, "- ")]
            @test 3 <= length(bullets) <= 5
        end
    end
end

@testset "all public QMD content omits minute schedules" begin
    for path in public_qmd_paths()
        source = copy_source(path)
        @test !occursin("90分の流れ", source)
        @test isnothing(match(MINUTE_RANGE_PATTERN, source))
    end
end

@testset "N01 follows the novice-facing learning boundary" begin
    lesson = copy_source("lessons/N01.qmd")
    required_headings = [
        "## この回の到達点", "## Julia構文の復習", "## 偏微分方程式が表すこと",
        "## 格子と添字", "## 初期条件", "## 境界条件", "## upwind + Euler",
        "## centered + Euler", "## 時間loop", "## buffer交換",
        "## CFLと最終時刻", "## 二つの方法を比較する",
        "## テストで確かめる", "## 課題へ進む",
    ]
    positions = [findfirst(heading, lesson) for heading in required_headings]
    @test all(!isnothing, positions)
    all(!isnothing, positions) && @test issorted(first.(positions))
    @test occursin("isapprox(steps * dt, t_final; atol=100eps())", lesson)
    @test !occursin("steps * dt == t_final", lesson)
    for todo in ("rectangular_initial_condition", "upwind_step!", "centered_step!")
        @test occursin(todo, lesson)
    end
    for supplied in ("TOML", "Plots", "module", "export", "詳細な入力検証")
        @test occursin(supplied, lesson)
    end
    @test occursin("完成要件ではありません", lesson)
    @test occursin("Julia以外のプログラミング経験", lesson)

    assignment = copy_source("assignments/N01.qmd")
    @test occursin("3つのTODOだけ", assignment)
    @test occursin("学習対象ではありません", assignment)
end
end
