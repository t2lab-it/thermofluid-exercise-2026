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

function body_after_frontmatter(source)
    lines = split(source, '\n'; keepempty=true)
    first(lines) == "---" || return source
    closing = findnext(==("---"), lines, 2)
    isnothing(closing) && return source
    return lstrip(join(lines[(closing + 1):end], '\n'))
end

const MACHINE_ID_PATTERN = r"(?<![A-Za-z0-9])(?:F|N)[0-9]{2}(?![A-Za-z0-9])"
const MARKDOWN_LINK_PATTERN = r"(?<!!)\[([^\]]+)\]\([^)]+\)"

function list_link_texts(source)
    texts = String[]
    for line in split(source, '\n')
        startswith(lstrip(line), "- ") || continue
        for matched in eachmatch(MARKDOWN_LINK_PATTERN, line)
            push!(texts, matched.captures[1])
        end
    end
    return texts
end

function machine_ids(text)
    return [matched.match for matched in eachmatch(MACHINE_ID_PATTERN, text)]
end

function visible_course_map_machine_ids(source)
    block = match(r"(?ms)^::: \{\.course-map\}\s*\n(.*?)^:::\s*$", source)
    isnothing(block) && return String[]

    ids = String[]
    for line in split(block.captures[1], '\n')
        startswith(strip(line), "|") || continue
        visible = replace(line, MARKDOWN_LINK_PATTERN => s"\1")
        visible = replace(visible, r"`[^`]*`" => "")
        visible = replace(visible, r"https?://\S+" => "")
        visible = replace(
            visible,
            r"(?:[A-Za-z0-9_.-]+/)+[FN][0-9]{2}\.[A-Za-z0-9_.-]+" => "",
        )
        visible = replace(visible, r"課題ID\s*[:：]\s*[FN][0-9]{2}" => "")
        append!(ids, machine_ids(visible))
    end
    return unique(ids)
end

function prefixed_list_link_texts(source)
    return [
        text for text in list_link_texts(source)
        if occursin(r"^(?:[FN][0-9]{2}|任意)\s*:", text)
    ]
end

function visible_list_link_machine_ids(source)
    ids = String[]
    for text in list_link_texts(source)
        append!(ids, machine_ids(text))
    end
    return unique(ids)
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

    mutated_map = """
    ::: {.course-map}
    | 回 | 内容 | 教材・課題 |
    |---:|---|---|
    | 5 | 一次元線形・非線形移流 | [移流方程式と安定性](lessons/N01.qmd)・N02（予定） |
    | 6 | 一次元拡散・移流拡散 | N03・N04（予定） |
    :::
    """
    @test visible_course_map_machine_ids(mutated_map) == ["N02", "N03", "N04"]
    @test isempty(visible_course_map_machine_ids(replace(
        mutated_map,
        "・N02（予定）" => "",
        "N03・N04（予定）" => "一次元拡散方程式・移流拡散方程式（予定）",
    )))
    allowed_context_map = """
    ::: {.course-map}
    | 回 | 内容 | 教材・課題 |
    |---:|---|---|
    | 5 | 許可文脈 | [具体名](lessons/N01.qmd)・課題ID: F00・`N05`・assignments/F01.qmd・https://example.test/assignments/N01.html |
    :::
    """
    @test isempty(visible_course_map_machine_ids(allowed_context_map))

    mutated_hub = """
    - [F00: ガイダンスと環境診断](F00.qmd)
    - [任意: CairoMakieによる可視化](cairomakie.qmd)
    """
    @test prefixed_list_link_texts(mutated_hub) == [
        "F00: ガイダンスと環境診断",
        "任意: CairoMakieによる可視化",
    ]
end

@testset "public copy positions and visible titles" begin
    styles = copy_source("assets/styles.css")
    @test occursin(r"(?s)\.course-position\s*\{[^}]*text-align\s*:\s*right\s*;", styles)
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
    @test startswith(body_after_frontmatter(home), "## この演習で身につけること\n")
    @test !occursin("::: {.eyebrow}", home)
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
    @test isempty(visible_course_map_machine_ids(home))
    cta = "[受講環境の準備へ進む](setup/index.qmd){.start-button}"
    @test length(findall(cta, home)) == 1
    necessary_environment = findfirst("## 必要な環境", home)
    troubleshooting = findfirst("[トラブル対応](guides/troubleshooting.qmd)", home)
    cta_position = findfirst(cta, home)
    license = findfirst("## 公開利用とライセンス", home)
    @test all(!isnothing, (necessary_environment, troubleshooting, cta_position, license))
    if all(!isnothing, (necessary_environment, troubleshooting, cta_position, license))
        @test first(necessary_environment) < first(troubleshooting) < first(cta_position) < first(license)
    end
    @test occursin("$cta\n\n## 公開利用とライセンス", home)

    for path in ("lessons/index.qmd", "assignments/index.qmd", "guides/index.qmd", "advanced/index.qmd")
        hub = copy_source(path)
        @test !occursin("::: {.eyebrow}", hub)
        @test isempty(prefixed_list_link_texts(hub))
        @test isempty(visible_list_link_machine_ids(hub))
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
