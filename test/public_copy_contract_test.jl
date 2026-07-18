using Test
using TOML

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

@testset "setup follows one forward sequence" begin
    setup = copy_source("setup/index.qmd")
    @test !occursin("## ライセンス", setup)
    @test !occursin("Pkg.instantiate", setup)
    @test !occursin("scripts/course.jl preflight", setup)

    guide_index = copy_source("guides/index.qmd")
    @test !occursin("(workflow.qmd)", guide_index)

    julia_setup = copy_source("setup/julia.qmd")
    @test !occursin("## 課題用 Julia 環境を復元する", julia_setup)
    @test !occursin("Pkg.instantiate", julia_setup)
    @test !occursin("scripts/course.jl preflight", julia_setup)
    @test occursin("[Git・GitHub・Classroom リポジトリ](git-github.qmd)", julia_setup)

    git_setup = copy_source("setup/git-github.qmd")
    @test occursin("## 最初の環境診断で確認する範囲", git_setup)
    @test !occursin("## F00 で確認する範囲", git_setup)
    clone = findfirst("git clone YOUR_CLASSROOM_REPOSITORY_URL", git_setup)
    instantiate = findfirst("Pkg.instantiate", git_setup)
    preflight = findfirst("scripts/course.jl preflight", git_setup)
    @test all(!isnothing, (clone, instantiate, preflight))
    if all(!isnothing, (clone, instantiate, preflight))
        @test first(clone) < first(instantiate) < first(preflight)
    end
    @test occursin("最初の環境診断（課題ID: F00）", git_setup)
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

function snippets_in_order(source, snippets)
    next_start = firstindex(source)
    for snippet in snippets
        matched = findnext(snippet, source, next_start)
        isnothing(matched) && return false
        next_start = nextind(source, last(matched))
    end
    return true
end

function section_has_ordered_snippets(source, heading, snippets)
    body = section_body(source, heading)
    return !isnothing(body) && snippets_in_order(body, snippets)
end

function swap_first(source, first_snippet, second_snippet)
    marker = "__PUBLIC_COPY_SWAP_MARKER__"
    swapped = replace(source, first_snippet => marker; count = 1)
    swapped = replace(swapped, second_snippet => first_snippet; count = 1)
    return replace(swapped, marker => second_snippet; count = 1)
end

@testset "prerequisite pages provide an executable reading order" begin
    f00_lesson = copy_source("lessons/F00.qmd")
    progression = section_body(f00_lesson, "課題へ進む条件")
    @test !isnothing(progression)
    if !isnothing(progression)
        bullets = [line for line in split(progression, '\n') if startswith(line, "- ")]
        @test length(bullets) == 3
        @test occursin("Julia 1.12.6", progression)
        @test occursin("Git", progression)
        @test occursin("GitHub", progression)
        @test occursin("Classroom", progression)
        @test occursin("Coding Agent", progression)
        @test occursin("scripts/course.jl preflight", progression)
        @test occursin("[環境診断の完了条件](../assignments/F00.qmd#完了条件)", progression)
    end

    guided_paths = (
        "lessons/F02.qmd", "assignments/F02.qmd",
        "lessons/F03.qmd", "assignments/F03.qmd",
        "lessons/N01.qmd", "assignments/N01.qmd",
    )
    for path in guided_paths
        source = copy_source(path)
        for heading in ("このページの進め方", "次へ進む条件")
            @test !isnothing(section_body(source, heading))
            mutation = replace(source, "## $heading" => "## 見出し削除"; count = 1)
            @test isnothing(section_body(mutation, heading))
        end
    end

    f02_lesson = copy_source("lessons/F02.qmd")
    f02_lesson_sequence = (
        "julia> values = [10.0, 20.0, 30.0]\n3-element Vector{Float64}:\n 10.0\n 20.0\n 30.0",
        "julia> values[2]\n20.0",
        "julia> for value in values\n           println(value - 20.0)\n       end\n-10.0\n0.0\n10.0",
        "julia> function double_values(values)\n           result = similar(values)\n           for i in eachindex(values)\n               result[i] = 2 * values[i]\n           end\n           return result\n       end\ndouble_values (generic function with 1 method)",
        "julia> double_values([1.0, 2.0, 3.0])\n3-element Vector{Float64}:\n 2.0\n 4.0\n 6.0",
        "julia> using Test",
        "julia> @test double_values([1.0, 2.0, 3.0]) == [2.0, 4.0, 6.0]\nTest Passed",
    )
    @test section_has_ordered_snippets(
        f02_lesson, "配列・loop・関数・テストを順に動かす", f02_lesson_sequence,
    )
    for snippet in f02_lesson_sequence
        mutation = replace(f02_lesson, snippet => "[removed example]"; count = 1)
        @test !section_has_ordered_snippets(
            mutation, "配列・loop・関数・テストを順に動かす", f02_lesson_sequence,
        )
    end
    contract_explanation = findfirst("## 関数境界に契約を置く", f02_lesson)
    function_example = findfirst("julia> function double_values", f02_lesson)
    @test !isnothing(contract_explanation)
    @test !isnothing(function_example)
    if !isnothing(contract_explanation) && !isnothing(function_example)
        @test first(function_example) < first(contract_explanation)
    end

    f02_assignment = copy_source("assignments/F02.qmd")
    f02_assignment_sequence = (
        "julia> rectangle_areas(widths, height) = [width * height for width in widths]\nrectangle_areas (generic function with 1 method)",
        "julia> rectangle_areas([1.0, 2.0, 3.0], 2.0)\n3-element Vector{Float64}:\n 2.0\n 4.0\n 6.0",
        "julia> using Test",
        "julia> @test rectangle_areas([1.0, 2.0, 3.0], 2.0) == [2.0, 4.0, 6.0]\nTest Passed",
    )
    @test section_has_ordered_snippets(
        f02_assignment, "課題前のウォームアップ", f02_assignment_sequence,
    )
    for snippet in f02_assignment_sequence
        mutation = replace(f02_assignment, snippet => "[removed warm-up]"; count = 1)
        @test !section_has_ordered_snippets(
            mutation, "課題前のウォームアップ", f02_assignment_sequence,
        )
    end
    warmup = section_body(f02_assignment, "課題前のウォームアップ")
    @test !isnothing(warmup)
    if !isnothing(warmup)
        @test !occursin("mean_temperature", warmup)
        @test !occursin("temperature_anomaly", warmup)
    end

    f03_lesson = copy_source("lessons/F03.qmd")
    f03_repl_sequence = (
        "julia> x = [0.0, 0.5, 1.0]\n3-element Vector{Float64}:\n 0.0\n 0.5\n 1.0",
        "julia> u = [1.0, 2.0, 4.0]\n3-element Vector{Float64}:\n 1.0\n 2.0\n 4.0",
        "julia> (x[2], u[2])\n(0.5, 2.0)",
    )
    @test section_has_ordered_snippets(
        f03_lesson, "最初に動かす座標と値", f03_repl_sequence,
    )
    for snippet in f03_repl_sequence
        mutation = replace(f03_lesson, snippet => "[removed coordinate example]"; count = 1)
        @test !section_has_ordered_snippets(
            mutation, "最初に動かす座標と値", f03_repl_sequence,
        )
    end

    mapping = section_body(f03_lesson, "1次元線形移流方程式のコードとの対応")
    @test !isnothing(mapping)
    accurate_boundary_row =
        "| 有効添字 | 内部点loopと、左端固定・右端ゼロ勾配の境界処理 |"
    accurate_mapping(source) =
        occursin(accurate_boundary_row, source) && !occursin("周期境界", source)
    if !isnothing(mapping)
        @test accurate_mapping(mapping)
        for row in (
            "| `uniform_grid` | `x`、`dx`、`u[i]`の対応 |",
            "| 後退差分 | 正の速度でのupwind更新 |",
            "| 中心差分 | 意図的なcentered + Euler比較 |",
        )
            @test occursin(row, mapping)
        end
        periodic_mutation = replace(
            mapping,
            accurate_boundary_row => "| 有効添字 | 周期境界の扱い |";
            count = 1,
        )
        @test !accurate_mapping(periodic_mutation)
        @test occursin("import", mapping)
    end

    n01_lesson = copy_source("lessons/N01.qmd")
    n01_assignment = copy_source("assignments/N01.qmd")
    lesson_order = section_body(n01_lesson, "このページの進め方")
    assignment_order = section_body(n01_assignment, "このページの進め方")
    lesson_sequence = (
        "この授業ページ", "[課題ページ]", "学生リポジトリ", "TASK.md", "run.jl",
    )
    assignment_sequence = (
        "[授業ページ]", "この課題ページ", "学生リポジトリ",
        "TASK.md", "run.jl", "提供テスト", "3つのTODOだけ",
    )
    @test !isnothing(lesson_order)
    @test !isnothing(assignment_order)
    if !isnothing(lesson_order)
        @test snippets_in_order(lesson_order, lesson_sequence)
        reordered = swap_first(lesson_order, "この授業ページ", "学生リポジトリ")
        @test !snippets_in_order(reordered, lesson_sequence)
    end
    if !isnothing(assignment_order)
        @test snippets_in_order(assignment_order, assignment_sequence)
        reordered = swap_first(assignment_order, "[授業ページ]", "学生リポジトリ")
        @test !snippets_in_order(reordered, assignment_sequence)
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

@testset "guides publish the concrete workflow and N01 baseline" begin
    workflow = copy_source("guides/workflow.qmd")
    @test occursin("```{mermaid}", workflow)
    @test occursin("課題を読む] --> B[branchを作る", workflow)
    @test occursin("[mainブランチで作業してしまったら](troubleshooting.qmd#mainブランチで作業してしまったら)", workflow)
    @test !occursin("## mainへ直接pushしたとき", workflow)

    troubleshooting = copy_source("guides/troubleshooting.qmd")
    @test occursin("## mainブランチで作業してしまったら", troubleshooting)
    @test occursin("force push", troubleshooting)

    testing = copy_source("guides/testing.qmd")
    @test occursin("../assets/n01-reference/upwind.png", testing)
    @test occursin("../assets/n01-reference/centered-euler.png", testing)
    @test occursin("13.492726642559711", testing)
    @test occursin("-10.420010468371677", testing)
    signs = findfirst("符号", testing)
    ranges = findfirst("範囲", testing)
    flags = findfirst("フラグ", testing)
    decimals = findfirst("小数", testing)
    @test all(!isnothing, (signs, ranges, flags, decimals))
    if all(!isnothing, (signs, ranges, flags, decimals))
        @test first(signs) < first(decimals)
        @test first(ranges) < first(decimals)
        @test first(flags) < first(decimals)
    end

    for path in (
        "assets/n01-reference/upwind.png",
        "assets/n01-reference/centered-euler.png",
        "assets/n01-reference/summary.toml",
    )
        @test isfile(joinpath(COPY_ROOT, path))
    end
    summary_path = joinpath(COPY_ROOT, "assets/n01-reference/summary.toml")
    if isfile(summary_path)
        summary = TOML.parsefile(summary_path)
        @test summary["grid"] == Dict("dx" => 0.025, "nx" => 81)
        @test summary["upwind"]["minimum"] == 1.0
        @test summary["upwind"]["maximum"] == 1.9993204517450067
        @test summary["upwind"]["overshoot_occurred"] === false
        @test summary["upwind"]["undershoot_occurred"] === false
        @test summary["centered_euler"]["minimum"] == -10.420010468371677
        @test summary["centered_euler"]["maximum"] == 13.492726642559711
        @test summary["centered_euler"]["overshoot_occurred"] === true
        @test summary["centered_euler"]["undershoot_occurred"] === true
    end

    commands = copy_source("guides/commands.qmd")
    command_blocks = collect(eachmatch(r"(?ms)```bash\n(.*?)```", commands))
    @test !isempty(command_blocks)
    for matched in command_blocks
        lines = split(chomp(matched.captures[1]), '\n')
        for (index, line) in pairs(lines)
            isempty(strip(line)) && continue
            startswith(strip(line), "#") && continue
            @test index > 1 && startswith(strip(lines[index - 1]), "#")
        end
    end
    @test occursin("新しい必須コマンド", commands)
    @test occursin("セットアップまたは公開済みの課題", commands)

    glossary = copy_source("guides/glossary.qmd")
    @test occursin("括弧内は日本語訳", glossary)
    for translated in (
        "branch（分岐）", "commit（記録）", "repository（保管場所）",
        "self-contained（自己完結）",
    )
        @test occursin(translated, glossary)
    end
end
end
