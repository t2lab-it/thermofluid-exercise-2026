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
    "guides/testing.qmd" => "参照・テストと数値検証",
    "lessons/F02.qmd" => "第3回・授業 1/2 · 課題ID: F02",
    "assignments/F02.qmd" => "第3回・課題 2/2 · 課題ID: F02",
    "lessons/F03.qmd" => "第4回・授業 1/2 · 課題ID: F03",
    "assignments/F03.qmd" => "第4回・課題 2/2 · 課題ID: F03",
    "lessons/F04.qmd" => "第5回・授業 1/2 · 課題ID: F04",
    "assignments/F04.qmd" => "第5回・課題 2/2 · 課題ID: F04",
    "lessons/N01.qmd" => "第6回・授業 1/2 · 課題ID: N01",
    "assignments/N01.qmd" => "第6回・課題 2/2 · 課題ID: N01",
    "guides/commands.qmd" => "参照・コマンド一覧",
    "guides/troubleshooting.qmd" => "参照・トラブル対応",
    "guides/glossary.qmd" => "参照・用語集",
    "advanced/github-ssh.qmd" => "任意・発展資料",
    "advanced/github-cli.qmd" => "任意・発展資料",
    "advanced/cairomakie.qmd" => "任意・発展資料",
    "advanced/package-built-solvers.qmd" => "任意・発展資料",
    "advanced/public-solver-methods.qmd" => "任意・発展資料",
)

const NO_ID_TITLE = Dict(
    "lessons/F00.qmd" => "ガイダンスと環境診断",
    "assignments/F00.qmd" => "環境診断",
    "lessons/F01.qmd" => "Julia・Git・GitHubの最小操作",
    "assignments/F01.qmd" => "最初のbranchとpull request",
    "lessons/F02.qmd" => "配列・関数・loop・テスト",
    "assignments/F02.qmd" => "Juliaの配列・関数・テスト",
    "lessons/F03.qmd" => "ベクトル解析",
    "assignments/F03.qmd" => "ベクトル解析の公式と自動微分",
    "lessons/F04.qmd" => "数値微分と格子収束",
    "assignments/F04.qmd" => "数値微分によるベクトル公式の検証",
    "lessons/N01.qmd" => "移流方程式と安定性",
    "assignments/N01.qmd" => "1次元線形移流方程式",
    "advanced/github-ssh.qmd" => "SSHでGitHubへ接続する",
    "advanced/github-cli.qmd" => "GitHub CLIでpull requestを操作する",
    "advanced/cairomakie.qmd" => "CairoMakieによる可視化",
    "advanced/package-built-solvers.qmd" => "パッケージを使ってPDEソルバを構築する",
    "advanced/public-solver-methods.qmd" => "公開Solverの数値手法を読み解く",
)

function section_body(source, heading)
    matched = match(Regex("(?ms)^## " * heading * "\\n\\n?(.*?)(?=^## |\\z)"), source)
    return isnothing(matched) ? nothing : matched.captures[1]
end

@testset "normal GitHub course repository onboarding" begin
    required_paths = [
        "setup/git-github.qmd", "setup/index.qmd", "setup/julia.qmd", "setup/agents.qmd",
        "lessons/F00.qmd", "assignments/F00.qmd", "advanced/index.qmd",
        "advanced/github-ssh.qmd", "advanced/github-cli.qmd",
    ]
    sources = Dict(path => read(joinpath(COPY_ROOT, path), String) for path in required_paths)
    setup = sources["setup/git-github.qmd"]
    for marker in (
        "第1回", "GitHubアカウント", "repository招待", "GitHubの通知またはメール",
        "private course repository", "YOUR_COURSE_REPOSITORY_URL", "第2回まで",
        "減点対象にしません",
    )
        @test occursin(marker, setup)
    end
    for (path, source) in sources
        @test !occursin("Classroom", source)
        @test !occursin("group assignment", lowercase(source))
    end
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
const EXPECTED_IMPLEMENTED_COURSE_LINKS = Dict(
    1 => ["lessons/F00.qmd", "assignments/F00.qmd"],
    2 => ["lessons/F01.qmd", "assignments/F01.qmd"],
    3 => ["lessons/F02.qmd", "assignments/F02.qmd"],
    4 => ["lessons/F03.qmd", "assignments/F03.qmd"],
    5 => ["lessons/F04.qmd", "assignments/F04.qmd"],
    6 => ["lessons/N01.qmd", "assignments/N01.qmd"],
    11 => ["assignments/final-project.qmd"],
    12 => ["assignments/final-project.qmd"],
    13 => ["assignments/final-project.qmd"],
    14 => ["assignments/final-project.qmd"],
)

const EXPECTED_COURSE_DATES = [
    "9/11（金）",
    "9/18（金）",
    "9/25（金）",
    "10/2（金）",
    "10/9（金）",
    "10/16（金）",
    "10/23（金）",
    "10/30（金）",
    "11/6（金）",
    "11/13（金）",
    "11/27（金）",
    "12/4（金）",
    "12/11（金）",
    "12/18（金）",
    "2027/1/8（金）",
]

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

function course_map_table(source)
    block = match(r"(?ms)^::: \{\.course-map\}\s*\n(.*?)^:::\s*$", source)
    return isnothing(block) ? nothing : strip(block.captures[1])
end

function course_map_rows(source)
    table = course_map_table(source)
    isnothing(table) && return NamedTuple[]
    rows = NamedTuple[]
    for line in split(table, '\n')
        startswith(strip(line), "|") || continue
        cells = strip.(split(strip(line), '|'; keepempty=true)[2:(end - 1)])
        length(cells) == 4 || continue
        number = tryparse(Int, cells[1])
        isnothing(number) && continue
        links = [matched.captures[2] for matched in eachmatch(r"\[([^\]]+)\]\(([^)]+)\)", line)]
        push!(rows, (number=number, date=cells[2], links=links))
    end
    return rows
end

function png_dimensions(path)
    data = read(path)
    signature = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    length(data) >= 24 && data[1:8] == signature || return nothing
    width = Int(ntoh(only(reinterpret(UInt32, data[17:20]))))
    height = Int(ntoh(only(reinterpret(UInt32, data[21:24]))))
    return (width=width, height=height)
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

function learner_copy_id_led_lines(source)
    violations = Tuple{Int,String}[]
    in_frontmatter = false
    in_fence = false
    for (line_number, raw_line) in enumerate(split(source, '\n'; keepempty=true))
        line = strip(raw_line)
        if line_number == 1 && line == "---"
            in_frontmatter = true
            continue
        elseif in_frontmatter
            line == "---" && (in_frontmatter = false)
            continue
        end
        if occursin(r"^(?:```|~~~)", line)
            in_fence = !in_fence
            continue
        end
        in_fence && continue
        isempty(line) && continue

        visible_line = replace(line, r"^(?:>\s*)+" => "")
        is_heading = occursin(r"^#{1,6}\s+", visible_line)
        visible_line = replace(visible_line, r"^#{1,6}\s+" => "")
        is_list = occursin(r"^(?:[-*+]\s+|[0-9]+[.)]\s+)", visible_line)
        visible_line = replace(
            visible_line,
            r"^(?:[-*+]\s+|[0-9]+[.)]\s+)" => "",
        )
        is_table = startswith(visible_line, "|") && endswith(visible_line, "|")
        is_normal_paragraph = !occursin(
            r"^(?:#|:::|\$\$|\\|<)",
            visible_line,
        )
        (is_heading || is_list || is_table || is_normal_paragraph) || continue

        fragments = is_table ?
            strip.(split(visible_line, '|'; keepempty=true)[2:(end - 1)]) :
            [visible_line]
        for fragment in fragments
            occursin(r"^:?-{3,}:?$", fragment) && continue
            visible = replace(fragment, MARKDOWN_LINK_PATTERN => s"\1")
            visible = replace(visible, r"`[^`]*`" => "")
            visible = replace(visible, r"https?://\S+" => "")
            visible = replace(
                visible,
                r"(?:[A-Za-z0-9_.-]+/)*[FN][0-9]{2}\.[A-Za-z0-9_.-]+" => "",
            )
            visible = replace(visible, r"課題ID\s*[:：]\s*[FN][0-9]{2}" => "")
            visible = strip(visible, [' ', '\t', '*', '_'])
            if occursin(
                r"(?:^|[。！？])\s*(?:F|N)[0-9]{2}(?![A-Za-z0-9])",
                visible,
            )
                push!(violations, (line_number, raw_line))
                break
            end
        end
    end
    return violations
end

function glossary_rows(source)
    rows = Tuple{String,String}[]
    for line in split(source, '\n')
        startswith(strip(line), "|") || continue
        cells = strip.(split(strip(line), '|'; keepempty=true)[2:(end - 1)])
        length(cells) == 2 || continue
        first(cells) in ("用語", "---") && continue
        push!(rows, (cells[1], cells[2]))
    end
    return rows
end

const EXPECTED_GLOSSARY_TERMS = [
    "branch", "commit", "diff", "pull request", "merge", "Actions", "local",
    "repository", "test", "smoke test", "regression test", "tolerance", "preflight",
    "canonical", "self-contained", "Agent / Coding Agent",
]

function glossary_rows_contract(source)
    rows = glossary_rows(source)
    terms = first.(rows)
    return terms == EXPECTED_GLOSSARY_TERMS &&
           length(unique(terms)) == length(terms) &&
           all(!isempty(strip(description)) for (_, description) in rows) &&
           all(isnothing(match(r"（[^（）]+）", term)) for term in terms) &&
           length(findall("略称 PR", source)) == 1
end

const MINUTE_RANGE_PATTERN = r"[0-9]+\s*[-–—〜~～]\s*[0-9]+\s*分"


@testset "public learning-copy contract" begin
@testset "copy-source parsers reject misleading placement" begin
    @test frontmatter_title("---\ntitle: \"正しいタイトル\"\n---\ntitle: \"本文の偽物\"\n") == "正しいタイトル"
    @test !isnothing(match(MINUTE_RANGE_PATTERN, "0–15 分"))

    mutated_map = """
    ::: {.course-map}
    | 回 | 内容 | 課題 |
    |---:|---|---|
    | 5 | 一次元線形・非線形移流 | [移流方程式と安定性](lessons/N01.qmd)・N02（予定） |
    :::
    """
    @test visible_course_map_machine_ids(mutated_map) == ["N02"]
    @test learner_copy_id_led_lines("F02では配列と関数を学びます。\n") == [
        (1, "F02では配列と関数を学びます。"),
    ]
    @test isempty(learner_copy_id_led_lines("""
    課題ID: F00 は進捗表示の補助情報です。
    `F01`はコマンド引数として入力します。
    assignments/F02.qmd は公開ページのpathです。
    """))
end

@testset "learner-facing headings and paragraphs use concrete names" begin
    violations = Tuple{String,Int,String}[]
    for path in public_qmd_paths()
        for (line_number, line) in learner_copy_id_led_lines(copy_source(path))
            push!(violations, (path, line_number, line))
        end
    end
    @test isempty(violations)
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
    rows = course_map_rows(home)
    @test length(rows) == 15
    @test getproperty.(rows, :number) == collect(1:15)
    @test getproperty.(rows, :date) == EXPECTED_COURSE_DATES
    for row in rows
        @test row.links == get(EXPECTED_IMPLEMENTED_COURSE_LINKS, row.number, String[])
    end
    expected_summary = "熱流体力学は、物質の性質、エンジンや熱交換器の設計、環境・エネルギー問題、人類の特殊環境への進出を理解するために欠かせない分野です。本演習では、熱力学1・2、伝熱工学、流体力学1・2で学んだ内容への理解を深めるため、基礎的・応用的な問題を解析的・数値的に解き、応用力と問題解決力を養います。"
    expected_audience = "熱力学1・2と流体力学1・2の内容を復習している受講者を対象とします。伝熱工学を履修していることが望まれます。授業と自習では教科書の例題や演習問題にも取り組み、受講時にはノートPCを持参してください。"
    @test startswith(body_after_frontmatter(home), "## 概要\n\n$expected_summary\n")
    @test section_body(home, "概要") == expected_summary * "\n\n"
    @test section_body(home, "対象者・前提") == expected_audience * "\n\n"
    headings = [matched.captures[1] for matched in eachmatch(r"(?m)^## (.+)$", home)]
    required_headings = ["概要", "対象者・前提", "全15回のコースマップ", "公開利用とライセンス"]
    positions = [findfirst(==(heading), headings) for heading in required_headings]
    @test all(!isnothing, positions)
    all(!isnothing, positions) && @test issorted(something.(positions))
    @test isempty(visible_course_map_machine_ids(home))
    @test occursin("| — | 11/20（金） | 授業なし | 最終プロジェクト予備計算 |", home)
    @test occursin("| 11 | 11/27（金） | [最終プロジェクト・スタジオ1]", home)
    @test occursin("| 12 | 12/4（金） | [最終プロジェクト・スタジオ2]", home)
    @test !occursin("| 11 | 11/27（金） | PDE分類、Laplace方程式", home)
    @test !occursin("| 12 | 12/4（金） | Poisson方程式", home)

    final_project_path = joinpath(COPY_ROOT, "assignments", "final-project.qmd")
    @test isfile(final_project_path)
    final_project = isfile(final_project_path) ? read(final_project_path, String) : ""
    expected_project_headings = [
        "目的", "個人とペア", "全テーマ共通要件", "テーマの選び方", "通常課題",
        "公開solverを用いた数値実験", "自由提案", "project repositoryと成果物",
        "11月27日：計画へのフィードバック",
        "12月4日：結果・再現性へのフィードバック", "最終発表", "完了条件",
    ]
    project_headings = [matched.captures[1] for matched in eachmatch(r"(?m)^## (.+)$", final_project)]
    @test project_headings == expected_project_headings
    for private_marker in ("90分の流れ", "口頭質問", "復帰コード", "配点")
        @test !occursin(private_marker, final_project)
    end


    for path in ("lessons/index.qmd", "assignments/index.qmd", "guides/index.qmd", "advanced/index.qmd")
        hub = copy_source(path)
        @test isempty(prefixed_list_link_texts(hub))
        @test isempty(visible_list_link_machine_ids(hub))
    end
end

@testset "setup follows one forward sequence" begin
    julia_setup = copy_source("setup/julia.qmd")
    @test occursin("[Git・GitHub・割り当てられた個人用course repository](git-github.qmd)", julia_setup)
    for required in (
        "LinearAlgebra",
        "ForwardDiff",
        "JuliaFormatter",
        "OrdinaryDiffEqLowOrderRK",
        "Project.toml",
        "Manifest.toml",
        "Pkg.instantiate()",
        "julia --project=.",
        "Julia: Start REPL",
        "Julia: Run File in New Process",
        "Pkg.test()",
        "julialang.language-julia",
        "MS-CEINTL.vscode-language-pack-ja",
        "scripts/format.jl",
        "formatter",
        "linter",
        "tests",
    )
        @test occursin(required, julia_setup)
    end

    setup_order = findfirst.((
        "## パッケージ環境を復元する",
        "## Juliaコードを実行する",
        "## VS Codeを授業用に整える",
        "## pull request前に整形とテストを行う",
    ), Ref(julia_setup))
    @test all(!isnothing, setup_order)
    all(!isnothing, setup_order) &&
        @test issorted(first.(something.(setup_order)))

    git_setup = copy_source("setup/git-github.qmd")
    account_heading = findfirst("## GitHub アカウントを作成する", git_setup)
    git_heading = findfirst("## Git を導入する", git_setup)
    config_heading = findfirst("## 最初の設定", git_setup)
    @test all(!isnothing, (git_heading, account_heading, config_heading))
    all(!isnothing, (git_heading, account_heading, config_heading)) &&
        @test first(git_heading) < first(account_heading) < first(config_heading)

    account_setup = section_body(git_setup, "GitHub アカウントを作成する")
    @test !isnothing(account_setup)
    if !isnothing(account_setup)
        for required_copy in (
            "第1回授業",
            "時間を分け",
            "登録を制限される場合",
            "本人が継続して管理できるメールアドレス",
            "メールアドレスを確認",
            "ログインできることを確認",
            "パスワードや確認コード",
            "GitHub 公式のアカウント作成手順",
        )
            @test occursin(required_copy, account_setup)
        end
        @test occursin(
            "::: {.callout-warning title=\"教室で一斉に作成しない\"}",
            account_setup,
        )
    end

    @test occursin("## 最初の環境診断で確認する範囲", git_setup)
    clone = findfirst("git clone YOUR_COURSE_REPOSITORY_URL", git_setup)
    instantiate = findfirst("Pkg.instantiate", git_setup)
    preflight = findfirst("scripts/course.jl preflight", git_setup)
    @test all(!isnothing, (clone, instantiate, preflight))
    all(!isnothing, (clone, instantiate, preflight)) &&
        @test first(clone) < first(instantiate) < first(preflight)
end

@testset "public lesson outcomes have bounded bullet counts" begin
    for id in ("F00", "F01", "F02", "F03", "F04", "N01")
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

@testset "advanced GitHub guides publish one optional sequence" begin
    advanced_index = copy_source("advanced/index.qmd")
    @test snippets_in_order(
        advanced_index,
        (
            "[SSHでGitHubへ接続する](github-ssh.qmd)",
            "[GitHub CLIでpull requestを操作する](github-cli.qmd)",
            "[CairoMakieによる可視化](cairomakie.qmd)",
            "[パッケージを使ってPDEソルバを構築する](package-built-solvers.qmd)",
        ),
    )
end

@testset "public solver methods guide has a bounded learner-facing scope" begin
    source = copy_source("advanced/public-solver-methods.qmd")

    for package in (
        "WaterLily.jl", "Trixi.jl", "Oceananigans.jl", "GeophysicalFlows.jl",
        "DispersiveShallowWater.jl", "TrixiShallowWater.jl",
    )
        @test occursin(package, source)
    end
    for marker in (
        "標準guided route",
        "相談・発展route",
        "埋め込み境界法と非圧縮性流れ",
        "高次不連続Galerkin法と双曲型保存則",
        "有限体積法とBoussinesq流体",
        "Fourier擬スペクトル法と地球流体",
        "SBP法と分散性浅水波",
    )
        @test occursin(marker, source)
    end
    @test !occursin("```", source)

    project = TOML.parsefile(joinpath(COPY_ROOT, "Project.toml"))
    manifest = copy_source("Manifest.toml")
    for package in (
        "WaterLily", "Trixi", "Oceananigans", "GeophysicalFlows",
        "DispersiveShallowWater", "TrixiShallowWater",
    )
        @test !haskey(project["deps"], package)
        @test !occursin("[[deps.$package]]", manifest)
    end
end

@testset "advanced SSH guide preserves existing keys and the standard path" begin
    setup = copy_source("setup/git-github.qmd")
    ssh = copy_source("advanced/github-ssh.qmd")

    @test occursin(
        "[SSHでGitHubへ接続する](../advanced/github-ssh.qmd)",
        setup,
    )
    @test snippets_in_order(
        setup,
        (
            "git clone YOUR_COURSE_REPOSITORY_URL",
            "[SSHでGitHubへ接続する](../advanced/github-ssh.qmd)",
        ),
    )

    for required_copy in (
        "標準のHTTPS cloneと最初のpull requestを完了",
        "既存の鍵ファイルを削除・上書きしない",
        "パスフレーズ",
        "秘密鍵",
        "共有PC",
        "ssh -T git@github.com",
        "id_ed25519_github",
        "ssh-add -l",
        "git remote set-url origin",
        "git fetch origin",
        "Permission denied (publickey)",
    )
        @test occursin(required_copy, ssh)
    end

    @test snippets_in_order(
        ssh,
        (
            "## SSHを使えると何が嬉しいか",
            "fetchやpushのたびに認証方法を選び直さずに済む",
            "秘密鍵を自分のPCから出さない形で認証できる",
            "GitHub CLIやCoding Agentとの協働へ進みやすくなる",
            "## このページの到達点",
        ),
    )
end

@testset "advanced GitHub CLI guide keeps humans in control of PR creation" begin
    f01 = copy_source("assignments/F01.qmd")
    cli = copy_source("advanced/github-cli.qmd")

    @test snippets_in_order(
        f01,
        (
            "この課題のbranch、PR、学習ログがそれぞれ一つあり",
            "[SSHでGitHubへ接続する](../advanced/github-ssh.qmd)",
            "[GitHub CLIでpull requestを操作する](../advanced/github-cli.qmd)",
        ),
    )

    for required_copy in (
        "ブラウザでpull requestを一度作成・確認・merge",
        "gh --version",
        "gh auth login",
        "gh auth status",
        "gh repo view",
        "gh pr list --state all",
        "gh pr view",
        "gh pr diff",
        "gh pr checks",
        "git push -u origin",
        "scratch/pr-body.md",
        "--base main",
        "--body-file scratch/pr-body.md",
        "mergeは標準手順",
        "token",
    )
        @test occursin(required_copy, cli)
    end

    @test snippets_in_order(
        cli,
        (
            "## GitHub CLIを使えると何が嬉しいか",
            "terminal中心の一連の流れで進められる",
            "ブラウザとの行き来を減らせる",
            "人が確認しながらCoding Agentへ作業を依頼しやすくなる",
            "## このページの到達点",
        ),
    )

    push = findfirst("git push -u origin", cli)
    create = findfirst("gh pr create", cli)
    @test all(!isnothing, (push, create))
    all(!isnothing, (push, create)) && @test first(push) < first(create)
end

function section_has_ordered_snippets(source, heading, snippets)
    body = section_body(source, heading)
    return !isnothing(body) && snippets_in_order(body, snippets)
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
        @test occursin("course repository", progression)
        @test occursin("Coding Agent", progression)
        @test occursin("scripts/course.jl preflight", progression)
        @test occursin("ページ下部の［次へ］から環境診断課題へ進み", progression)
    end

    guided_paths = (
        "lessons/F02.qmd", "assignments/F02.qmd",
        "lessons/F03.qmd", "assignments/F03.qmd",
        "lessons/F04.qmd", "assignments/F04.qmd",
        "lessons/N01.qmd", "assignments/N01.qmd",
    )
    for path in guided_paths
        source = copy_source(path)
        for heading in ("このページの進め方", "次へ進む条件")
            @test !isnothing(section_body(source, heading))
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
    warmup = section_body(f02_assignment, "課題前のウォームアップ")
    @test !isnothing(warmup)
    if !isnothing(warmup)
        @test !occursin("mean_temperature", warmup)
        @test !occursin("temperature_anomaly", warmup)
    end

    f03_lesson = copy_source("lessons/F03.qmd")
    f03_assignment = copy_source("assignments/F03.qmd")
    f03_pages = f03_lesson * "\n" * f03_assignment
    for identity in (
        raw"\nabla\times(\nabla\phi)=\boldsymbol{0}",
        raw"\nabla\cdot(\nabla\times\boldsymbol{A})=0",
        raw"\nabla\cdot(\nabla\phi)=\nabla^2\phi",
    )
        @test occursin(identity, f03_lesson)
        @test occursin(identity, f03_assignment)
    end
    for api in ("gradient_scalar", "curl_vector", "laplacian_scalar")
        @test occursin(api, f03_assignment)
    end
    @test occursin("ForwardDiff", f03_pages)
    @test occursin("automatic_reference", f03_assignment)
    @test !occursin("centered_partial", f03_pages)
    @test !occursin("n=9", f03_pages)
    @test !occursin("n=17", f03_pages)
    @test occursin("exercises/F03_vector_calculus/run.jl", f03_assignment)

    f04_lesson = copy_source("lessons/F04.qmd")
    f04_assignment = copy_source("assignments/F04.qmd")
    f04_pages = f04_lesson * "\n" * f04_assignment
    for api in (
        "forward_difference", "backward_difference", "centered_difference",
        "centered_partial", "verify_vector_identities",
    )
        @test occursin(api, f04_assignment)
    end
    @test occursin("exercises/F04_numerical_differentiation/run.jl", f04_assignment)
    @test occursin("julia --project=. scripts/course.jl start F04", f04_assignment)
    @test occursin("n=9", f04_assignment)
    @test occursin("n=17", f04_assignment)
    @test occursin("3.0", f04_assignment)
    @test occursin("4.8", f04_assignment)
    @test occursin("centered_difference", f04_lesson)
    @test occursin("F03", f04_pages)
    @test occursin("公式出力を作りません", f04_assignment)

    n01_lesson = copy_source("lessons/N01.qmd")
    n01_assignment = copy_source("assignments/N01.qmd")
    lesson_order = section_body(n01_lesson, "このページの進め方")
    assignment_order = section_body(n01_assignment, "このページの進め方")
    lesson_sequence = (
        "この授業ページ", "ページ下部の［次へ］", "課題ページ",
        "学生リポジトリ", "run.jl", "提供テスト", "自分のテスト", "3つの実装箇所",
    )
    assignment_sequence = (
        "ページ下部の［前へ］", "授業ページ", "この課題ページ", "学生リポジトリ",
        "run.jl", "提供テスト", "自分のテスト", "3つの実装箇所",
    )
    @test !isnothing(lesson_order)
    @test !isnothing(assignment_order)
    if !isnothing(lesson_order)
        @test snippets_in_order(lesson_order, lesson_sequence)
    end
    if !isnothing(assignment_order)
        @test snippets_in_order(assignment_order, assignment_sequence)
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
    for syntax in (
        "`value::T`", "`{<:Real}`", "`:upwind`",
        "`condition ? true_value : false_value`", "named tuple",
    )
        @test occursin(syntax, lesson)
    end

    for source in (lesson, copy_source("assignments/N01.qmd"))
        for core in (
            raw"\Delta x=\frac{x_{\max}-x_{\min}}{n_x-1}",
            raw"x_i=x_{\min}+(i-1)\Delta x",
            "(u[i] - u[i - 1]) / dx",
            "(u[i + 1] - u[i - 1]) / (2 * dx)",
        )
            @test occursin(core, source)
        end
    end
    @test occursin("i = 2, ..., length(u)", lesson)
    @test occursin("i = 2, ..., length(u)-1", lesson)

    assignment = copy_source("assignments/N01.qmd")
    @test occursin("## 座標・添字・差分の確認", assignment)
    @test occursin("数値微分課題（課題ID: F04）", assignment)
    @test !occursin("前の座標・添字・差分課題", assignment)
    @test occursin("3つのTODOだけ", assignment)
    @test occursin("学習対象ではありません", assignment)
    for source in (lesson, assignment)
        for required_boundary in (
            "provided_support.jl",
            "おまじない",
            "読解・編集する必要はありません",
            "実行時の入力条件",
            "教材側の包括的な確認",
            "自分で選んだ代表例",
        )
            @test occursin(required_boundary, source)
        end
    end
    for required_copy in (
        "`@test false`を削除",
        "保証することと保証しないこと",
        "buffer交換を学習ログ",
        "完成コード全体の生成",
        "個人情報・秘密情報",
        "関数名、引数、scheme、出力ファイル名、summaryのキー",
    )
        @test occursin(required_copy, assignment)
    end
end

@testset "F01 completion routes to the F02 lesson" begin
    f01_assignment = copy_source("assignments/F01.qmd")
    f02_lesson = copy_source("lessons/F02.qmd")
    testing = copy_source("guides/testing.qmd")
    f02_assignment = copy_source("assignments/F02.qmd")

    @test occursin(
        "ページ下部の［次へ］から第3回授業「配列・関数・loop・テスト」へ進んでください。",
        f01_assignment,
    )
    @test !occursin("scripts/course.jl start F02", f01_assignment)
    @test occursin("参照・テストと数値検証", testing)
    @test !occursin("F01）を終えた直後の必読資料", testing)
    @test !occursin("## 次の授業へ", testing)
    for required_copy in (
        "手計算できる具体例",
        "複数の入力に共通する性質",
        "契約外入力の失敗条件",
        "配列・関数・テスト課題（課題ID: F02）では、自分で選んだ代表例を学生テストへ追加",
        "テストがpassしても、数値的・物理的な妥当性のすべてを保証するわけではありません。",
        "[テストと数値検証](../guides/testing.qmd)",
    )
        @test occursin(required_copy, f02_lesson)
    end
    @test occursin("julia --project=. scripts/course.jl start F02", f02_assignment)
end

@testset "guides publish the concrete workflow and N01 baseline" begin
    workflow = copy_source("guides/workflow.qmd")
    recovery_link = "[mainブランチで作業してしまったら](troubleshooting.qmd#mainブランチで作業してしまったら)"
    @test length(findall(recovery_link, workflow)) == 1
    @test length(findall("自分で履歴を書き換えず", workflow)) == 1
    common_contract = section_body(workflow, "共通契約")
    @test !isnothing(common_contract)
    if !isnothing(common_contract)
        numbered_steps = [
            line for line in split(common_contract, '\n')
            if occursin(r"^[0-9]+\. ", line)
        ]
        @test length(numbered_steps) == 12
        @test snippets_in_order(
            join(numbered_steps, '\n'),
            ("branch", "実装", "ローカルテスト", "公式出力", "学習ログ", "commit",
             "push", "PR", "Actions", "diff", "セルフレビュー", "merge"),
        )
    end
    merge_after = section_body(workflow, "merge後")
    @test !isnothing(merge_after)
    if !isnothing(merge_after)
        @test occursin("変更のないmain", merge_after)
        @test occursin(recovery_link, merge_after)
    end

    troubleshooting = copy_source("guides/troubleshooting.qmd")
    @test occursin("## mainブランチで作業してしまったら", troubleshooting)
    @test occursin("force push", troubleshooting)

    testing = copy_source("guides/testing.qmd")
    @test occursin("../assets/n01-reference/upwind.png", testing)
    @test occursin("../assets/n01-reference/centered-euler.png", testing)
    @test occursin(
        "`nx=81`、`dx=0.025`、`cfl=0.5`、`dt=0.0125`、`steps=40`",
        testing,
    )
    markdown_rows = [
        strip.(split(strip(line), '|'; keepempty=true)[2:(end - 1)])
        for line in split(testing, '\n')
        if startswith(strip(line), "|") && endswith(strip(line), "|")
    ]
    for (method, expected_values) in (
        ("upwind + Euler", [1.0, 1.9993204517450067, 0.0, 0.0]),
        (
            "centered + Euler",
            [-10.420010468371677, 13.492726642559711,
             11.492726642559711, 11.420010468371677],
        ),
    )
        matching_rows = filter(row -> !isempty(row) && first(row) == method, markdown_rows)
        @test length(matching_rows) == 1
        length(matching_rows) == 1 || continue
        cells = only(matching_rows)
        @test length(cells) == 5
        length(cells) == 5 || continue
        parsed_values = tryparse.(Float64, cells[2:end])
        @test all(!isnothing, parsed_values)
        all(!isnothing, parsed_values) || continue
        @test [something(value) for value in parsed_values] == expected_values
    end
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

    for path in ("assets/n01-reference/upwind.png", "assets/n01-reference/centered-euler.png")
        full_path = joinpath(COPY_ROOT, path)
        @test isfile(full_path)
        if isfile(full_path)
            dimensions = png_dimensions(full_path)
            @test !isnothing(dimensions)
            !isnothing(dimensions) && @test dimensions.width >= 600 && dimensions.height >= 400
            @test filesize(full_path) > 10_000
        end
    end
    summary_path = joinpath(COPY_ROOT, "assets/n01-reference/summary.toml")
    @test isfile(summary_path)
    if isfile(summary_path)
        summary = TOML.parsefile(summary_path)
        @test Set(keys(summary)) == Set(["course_id", "grid", "upwind", "centered_euler"])
        @test summary["course_id"] == "N01"
        @test summary["grid"] == Dict("dx" => 0.025, "nx" => 81)
        for (name, scheme, unstable) in (
            ("upwind", "upwind-euler", false),
            ("centered_euler", "centered-euler", true),
        )
            method = summary[name]
            @test method["scheme"] == scheme
            @test method["cfl"] == 0.5
            @test method["dt"] == 0.0125
            @test method["steps"] == 40
            @test method["overshoot_occurred"] == unstable
            @test method["undershoot_occurred"] == unstable
            @test all(isfinite, Float64[method["minimum"], method["maximum"], method["overshoot"], method["undershoot"]])
        end
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
    @test glossary_rows_contract(glossary)
end
@testset "assignment pages are the only assignment prose source" begin
    pages = Dict(
        "F00" => copy_source("assignments/F00.qmd"),
        "F01" => copy_source("assignments/F01.qmd"),
        "F02" => copy_source("assignments/F02.qmd"),
        "F03" => copy_source("assignments/F03.qmd"),
        "F04" => copy_source("assignments/F04.qmd"),
        "N01" => copy_source("assignments/N01.qmd"),
    )
    removed_task_name = "TASK" * ".md"
    @test all(!occursin(removed_task_name, page) for page in values(pages))
    @test occursin("--confirm-github --confirm-agent copilot", pages["F00"])
    @test occursin("--confirm-github --confirm-agent codex", pages["F00"])
    @test occursin("--confirm-github --confirm-agent amazon-q", pages["F00"])
    @test occursin("Hello, name!", pages["F01"])
    @test occursin("空白だけの名前", pages["F01"])
    @test occursin("test/student/F02.jl", pages["F02"])
    @test occursin("gradient_scalar", pages["F03"])
    @test !occursin("centered_partial", pages["F03"])
    @test occursin("centered_partial", pages["F04"])
    @test occursin("verify_vector_identities", pages["F04"])
    @test occursin("results/N01/summary.toml", pages["N01"])
end

end
