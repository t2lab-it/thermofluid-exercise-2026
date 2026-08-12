using Test
using TOML

const NAVIGATION_SITE_ROOT = normpath(joinpath(@__DIR__, ".."))

const VISIBLE_NAMES = Dict(
    "F00" => (lesson="ガイダンスと環境診断", assignment="環境診断"),
    "F01" => (lesson="Julia・Git・GitHubの最小操作", assignment="最初のbranchとpull request"),
    "F02" => (lesson="配列・関数・loop・テスト", assignment="Juliaの配列・関数・テスト"),
    "F03" => (lesson="ベクトル解析", assignment="ベクトル解析の公式と自動微分"),
    "F04" => (lesson="数値微分と格子収束", assignment="数値微分によるベクトル公式の検証"),
    "N01" => (lesson="移流方程式と安定性", assignment="1次元線形移流方程式"),
)

const REQUIRED_COURSE_ORDER = ("F00", "F01", "F02", "F03", "F04", "N01")
const REQUIRED_SECTION_LABELS = ("ガイド", "発展資料")
const EXPECTED_PREPARATION_LINKS = [
    ("setup/index.qmd", "受講環境の準備"),
    ("setup/julia.qmd", "Julia・VS Code"),
    ("setup/git-github.qmd", "Git・GitHub"),
    ("setup/agents.qmd", "Coding Agent"),
    ("guides/workflow.qmd", "課題ワークフロー"),
]
const EXPECTED_SESSION_ENTRIES = [
    ("第1回 授業: ガイダンス、アカウント、環境診断", "lessons/F00.qmd"),
    ("第1回 課題: 環境診断", "assignments/F00.qmd"),
    ("第2回 授業: Julia・Git・GitHubの最小操作", "lessons/F01.qmd"),
    ("第2回 課題: 最初のbranchとpull request", "assignments/F01.qmd"),
    ("第3回 授業: 配列・関数・ループ、テスト", "lessons/F02.qmd"),
    ("第3回 課題: Juliaの配列・関数・テスト", "assignments/F02.qmd"),
    ("第4回 授業: ベクトル解析", "lessons/F03.qmd"),
    ("第4回 課題: ベクトル解析の公式と自動微分", "assignments/F03.qmd"),
    ("第5回 授業: 数値微分と格子収束", "lessons/F04.qmd"),
    ("第5回 課題: 数値微分によるベクトル公式の検証", "assignments/F04.qmd"),
    ("第6回 授業: 一次元線形・非線形移流", "lessons/N01.qmd"),
    ("第6回 課題: 1次元線形移流方程式", "assignments/N01.qmd"),
    ("第7回 一次元拡散・移流拡散", nothing),
    ("第8回 授業: 共通化から二次元移流へ", nothing),
    ("第9回 授業: 二次元拡散・移流拡散", nothing),
    ("第10回 授業: Laplace／Poissonと反復法", nothing),
    ("第11回 最終プロジェクト: 計画・成立性レビュー", "assignments/final-project.qmd"),
    ("第12回 最終プロジェクト: 結果・再現性レビュー", "assignments/final-project.qmd"),
    ("第13回 最終プレゼンテーション 1", "assignments/final-project.qmd"),
    ("第14回 最終プレゼンテーション 2・試験案内", "assignments/final-project.qmd"),
    ("第15回 到達度確認試験", nothing),
]
const EXPECTED_FINAL_PROJECT_TOPIC_SECTIONS = [
    (
        "solverを構築する",
        [
            ("準一次元ノズル流れ", "projects/final-project-topics/quasi-1d-nozzle.qmd"),
            ("一次元Stefan問題", "projects/final-project-topics/stefan-problem.qmd"),
            ("Wet-bed dam break", "projects/final-project-topics/shallow-water-dam-break.qmd"),
            ("二次元自然対流キャビティ", "projects/final-project-topics/natural-convection-cavity.qmd"),
            ("温度場からの熱源位置・強度推定", "projects/final-project-topics/inverse-heat-source.qmd"),
            ("二次元非圧縮性Navier–Stokes", "projects/final-project-topics/incompressible-navier-stokes.qmd"),
        ],
    ),
    (
        "自作solverを再利用する",
        [
            ("Profilingと性能最適化", "projects/final-project-topics/profiling-and-optimization.qmd"),
            ("GPU移植と性能測定", "projects/final-project-topics/gpu-porting.qmd"),
            ("反復解法と前処理", "projects/final-project-topics/iterative-solvers.qmd"),
        ],
    ),
    (
        "公開solverを利用する",
        [
            ("WaterLily.jlによる円柱まわり流れ", "projects/final-project-topics/waterlily-cylinder-flow.qmd"),
            ("Trixi.jlによる一次元shock tube", "projects/final-project-topics/trixi-shock-tube.qmd"),
            ("Oceananigans.jlによるhorizontal convection", "projects/final-project-topics/oceananigans-horizontal-convection.qmd"),
        ],
    ),
    (
        "自由提案",
        [("自由提案", "projects/final-project-topics/open-proposal.qmd")],
    ),
]

function yaml_source_lines(source::AbstractString)
    lines = NamedTuple{(:indent, :text),Tuple{Int,String}}[]
    for raw_line in split(source, '\n')
        startswith(strip(raw_line), "#") && continue
        uncommented = replace(raw_line, r"\s+#.*$" => "")
        isempty(strip(uncommented)) && continue
        push!(lines, (
            indent=length(uncommented) - length(lstrip(uncommented)),
            text=strip(uncommented),
        ))
    end
    return lines
end

function first_matching_index(predicate, indices)
    for index in indices
        predicate(index) && return index
    end
    return nothing
end

function yaml_node(lines, path)
    first_line = 1
    last_line = length(lines)
    parent_indent = -1
    found = nothing

    for key in path
        direct_indents = [
            lines[index].indent for index in first_line:last_line
            if lines[index].indent > parent_indent
        ]
        isempty(direct_indents) && return nothing
        direct_indent = minimum(direct_indents)
        pattern = Regex("^" * key * raw":(?:\s*(.*))?$")
        found = first_matching_index(first_line:last_line) do index
            lines[index].indent == direct_indent && !isnothing(match(pattern, lines[index].text))
        end
        isnothing(found) && return nothing

        node_indent = lines[found].indent
        next_sibling = first_matching_index((found + 1):last_line) do index
            lines[index].indent <= node_indent
        end
        last_line = isnothing(next_sibling) ? last_line : next_sibling - 1
        first_line = found + 1
        parent_indent = node_indent
    end

    return (line=found, first=found + 1, last=last_line, indent=lines[found].indent)
end

function yaml_scalar(lines, node)
    node === nothing && return nothing
    value = strip(split(lines[node.line].text, ':'; limit=2)[2])
    if length(value) >= 2 && first(value) == last(value) && first(value) in ('"', '\'')
        return value[2:(end - 1)]
    end
    return value
end

function yaml_sequence_items(lines, node)
    node === nothing && return []
    child_lines = [index for index in node.first:node.last if lines[index].indent > node.indent]
    isempty(child_lines) && return []
    item_indent = minimum(lines[index].indent for index in child_lines)
    starts = [
        index for index in child_lines
        if lines[index].indent == item_indent && startswith(lines[index].text, "- ")
    ]
    return [
        (
            line=start,
            first=start + 1,
            last=position == length(starts) ? node.last : starts[position + 1] - 1,
            indent=item_indent,
        )
        for (position, start) in enumerate(starts)
    ]
end

function yaml_item_field(lines, item, key)
    first_text = lines[item.line].text[3:end]
    first_match = match(Regex("^" * key * raw":(?:\s*(.*))?$"), first_text)
    if !isnothing(first_match)
        value = isnothing(first_match.captures[1]) ? "" : strip(first_match.captures[1])
        return (value=strip(value, ['"', '\'']), node=item)
    end

    child_lines = [index for index in item.first:item.last if lines[index].indent > item.indent]
    isempty(child_lines) && return nothing
    field_indent = minimum(lines[index].indent for index in child_lines)
    pattern = Regex("^" * key * raw":(?:\s*(.*))?$")
    field_line = first_matching_index(item.first:item.last) do index
        lines[index].indent == field_indent && !isnothing(match(pattern, lines[index].text))
    end
    isnothing(field_line) && return nothing

    captured = match(pattern, lines[field_line].text).captures[1]
    value = isnothing(captured) ? "" : strip(captured)
    next_field = first_matching_index((field_line + 1):item.last) do index
        lines[index].indent <= field_indent
    end
    field_last = isnothing(next_field) ? item.last : next_field - 1
    return (
        value=strip(value, ['"', '\'']),
        node=(line=field_line, first=field_line + 1, last=field_last, indent=field_indent),
    )
end

function yaml_effective_values(lines, node)
    inline = yaml_scalar(lines, node)
    !isnothing(inline) && !isempty(inline) && return [inline]
    return [strip(lines[item.line].text[3:end], ['"', '\'']) for item in yaml_sequence_items(lines, node)]
end

function navbar_menu_pairs(lines, section_label)
    navbar_left = yaml_node(lines, ("website", "navbar", "left"))
    isnothing(navbar_left) && return Tuple{String,String}[]
    section_items = [
        item for item in yaml_sequence_items(lines, navbar_left)
        if something(yaml_item_field(lines, item, "text"), (value="",)).value == section_label
    ]
    length(section_items) == 1 || return Tuple{String,String}[]

    menu = yaml_item_field(lines, only(section_items), "menu")
    isnothing(menu) && return Tuple{String,String}[]
    pairs = Tuple{String,String}[]
    for entry in yaml_sequence_items(lines, menu.node)
        href = yaml_item_field(lines, entry, "href")
        text = yaml_item_field(lines, entry, "text")
        (isnothing(href) || isnothing(text)) && return Tuple{String,String}[]
        push!(pairs, (href.value, text.value))
    end
    return pairs
end

function navbar_item(lines, label)
    navbar_left = yaml_node(lines, ("website", "navbar", "left"))
    isnothing(navbar_left) && return nothing
    matches = [
        item for item in yaml_sequence_items(lines, navbar_left)
        if something(yaml_item_field(lines, item, "text"), (value="",)).value == label
    ]
    return length(matches) == 1 ? only(matches) : nothing
end

function sidebar_section_entries(lines, sidebar_item, section_label)
    contents = yaml_item_field(lines, sidebar_item, "contents")
    isnothing(contents) && return []
    matches = [
        item for item in yaml_sequence_items(lines, contents.node)
        if something(yaml_item_field(lines, item, "section"), (value="",)).value == section_label
    ]
    length(matches) == 1 || return []
    section_contents = yaml_item_field(lines, only(matches), "contents")
    isnothing(section_contents) && return []
    return [
        (
            something(yaml_item_field(lines, item, "text"), (value="",)).value,
            let href = yaml_item_field(lines, item, "href")
                isnothing(href) ? nothing : href.value
            end,
        )
        for item in yaml_sequence_items(lines, section_contents.node)
    ]
end

const NAVIGATION_LOADER = "assets/navigation-loader.html"
const NAVIGATION_BEHAVIOR_TEST = joinpath(@__DIR__, "navigation_behavior_test.js")

function navigation_loader_path(lines)
    include_node = yaml_node(lines, ("format", "html", "include-after-body"))
    isnothing(include_node) && return nothing
    values = yaml_effective_values(lines, include_node)
    length(values) == 1 || return nothing
    only(values) == NAVIGATION_LOADER || return nothing
    return only(values)
end

function is_module_navigation_loader(source::AbstractString)
    script_pattern = r"(?is)<script\b([^>]*)>(.*?)</script\s*>"
    scripts = collect(eachmatch(script_pattern, source))

    is_navigation_module(script) = begin
        attributes = script.captures[1]
        body = script.captures[2]
        module_type = occursin(r"(?i)\btype\s*=\s*[\"']module[\"']", attributes)
        navigation_source = occursin(
            r"(?i)\bsrc\s*=\s*[\"'][^\"']*assets/navigation\.js(?:\?[^\"']*)?[\"']",
            attributes,
        )
        module_type && navigation_source && isempty(strip(body))
    end

    navigation_modules = filter(is_navigation_module, scripts)
    length(navigation_modules) == 1 || return false

    for script in scripts
        attributes = script.captures[1]
        body = script.captures[2]
        references_navigation = occursin(r"(?i)navigation\.js", attributes) ||
                                occursin(r"(?i)navigation\.js", body)
        references_navigation && !is_navigation_module(script) && return false
        !isempty(strip(body)) && return false
    end

    outside_scripts = replace(source, script_pattern => "")
    outside_comments = replace(outside_scripts, r"(?is)<!--.*?-->" => "")
    outside_text = replace(outside_comments, r"(?is)<[^>]+>" => "")
    raw_javascript = occursin(
        r"(?is)(?:\b(?:import|export|const|let|var|function)\b|=>|addEventListener\s*\(|\b(?:document|window)\s*\.)",
        outside_text,
    )
    return !raw_javascript
end

function run_navigation_behavior(quarto, module_path)
    output = PipeBuffer()
    command = `$quarto run $NAVIGATION_BEHAVIOR_TEST $module_path`
    process = run(pipeline(ignorestatus(command); stdout=output, stderr=output))
    return success(process), String(take!(output))
end

@testset "navigation source parsers reject inert configuration" begin
    commented = yaml_source_lines("""
    # website:
    #   page-navigation: true
    website:
      navbar:
        page-navigation: true
    """)
    @test isnothing(yaml_node(commented, ("website", "page-navigation")))

    valid = yaml_source_lines("""
    format:
      html:
        include-after-body:
          - assets/navigation-loader.html
    """)
    @test navigation_loader_path(valid) == NAVIGATION_LOADER
    @test is_module_navigation_loader(
        "<script type=\"module\" src=\"/thermofluid-exercise-2026/assets/navigation.js\"></script>",
    )
    @test !is_module_navigation_loader("<script src=\"assets/navigation.js\"></script>")

    sidebar = yaml_source_lines("""
    website:
      sidebar:
        - id: course
          contents:
            - section: "全15回"
              contents:
                - text: "第1回 ガイダンス、アカウント、環境診断"
                  href: lessons/F00.qmd
                - text: "第6回 一次元拡散・移流拡散"
    """)
    sidebar_node = yaml_node(sidebar, ("website", "sidebar"))
    course = only(yaml_sequence_items(sidebar, sidebar_node))
    @test sidebar_section_entries(sidebar, course, "全15回") == [
        ("第1回 ガイダンス、アカウント、環境診断", "lessons/F00.qmd"),
        ("第6回 一次元拡散・移流拡散", nothing),
    ]
end

@testset "navigation behavior harness fixture" begin
    behavior_test_exists = isfile(NAVIGATION_BEHAVIOR_TEST)
    @test behavior_test_exists
    quarto = Sys.which("quarto")
    @test !isnothing(quarto)
    if behavior_test_exists && !isnothing(quarto)
        passed, details = run_navigation_behavior(quarto, "--self-test")
        @test passed
        !passed && @info "navigation behavior harness self-test failed" details
    end
end

@testset "reviewed course navigation contract" begin
    public_root = NAVIGATION_SITE_ROOT
    quarto = read(joinpath(public_root, "_quarto.yml"), String)
    yaml = yaml_source_lines(quarto)
    contracts = TOML.parsefile(joinpath(public_root, "assignments", "contracts.toml"))
    assignment_ids = Set(keys(contracts["assignments"]))

    @test assignment_ids == Set(keys(VISIBLE_NAMES))

    language = yaml_node(yaml, ("lang",))
    @test !isnothing(language)
    !isnothing(language) && @test yaml_scalar(yaml, language) == "ja"

    site_title = yaml_node(yaml, ("website", "title"))
    @test !isnothing(site_title)
    !isnothing(site_title) && @test yaml_scalar(yaml, site_title) == "熱流体力学演習 2026"

    navbar_left = yaml_node(yaml, ("website", "navbar", "left"))
    @test !isnothing(navbar_left)
    if !isnothing(navbar_left)
        navbar_items = yaml_sequence_items(yaml, navbar_left)
        labels = [
            something(yaml_item_field(yaml, item, "text"), (value="",)).value
            for item in navbar_items
        ]
        @test labels == collect(REQUIRED_SECTION_LABELS)
        for (label, parent_href, expected_menu) in (
            (
                "ガイド",
                "guides/index.qmd",
                [
                    ("guides/testing.qmd", "テスト"),
                    ("guides/commands.qmd", "コマンド"),
                    ("guides/troubleshooting.qmd", "トラブル対応"),
                    ("guides/glossary.qmd", "用語集"),
                ],
            ),
            (
                "発展資料",
                "advanced/index.qmd",
                [
                    ("advanced/github-ssh.qmd", "SSHでGitHubへ接続する"),
                    ("advanced/github-cli.qmd", "GitHub CLIでpull requestを操作する"),
                    ("advanced/cairomakie.qmd", "CairoMakieによる可視化"),
                    ("advanced/package-built-solvers.qmd", "パッケージを使ってPDEソルバを構築する"),
                    ("advanced/public-solver-methods.qmd", "公開Solverの数値手法を読み解く"),
                    ("advanced/juliacon-2026-pde-cfd.qmd", "JuliaCon 2026から学ぶPDE・CFD計算"),
                ],
            ),
        )
            item = navbar_item(yaml, label)
            @test !isnothing(item)
            if !isnothing(item)
                @test isnothing(yaml_item_field(yaml, item, "href"))
                expected_marker = label == "ガイド" ? "split-navigation-guides" : "split-navigation-advanced"
                @test yaml_item_field(yaml, item, "rel").value == "split-navigation $expected_marker"
            end
            @test navbar_menu_pairs(yaml, label) == expected_menu
            @test all(first(pair) != parent_href for pair in expected_menu)
        end
    end

    page_navigation = yaml_node(yaml, ("website", "page-navigation"))
    @test !isnothing(page_navigation)
    !isnothing(page_navigation) && @test yaml_scalar(yaml, page_navigation) == "true"

    light_theme = yaml_node(yaml, ("format", "html", "theme", "light"))
    dark_theme = yaml_node(yaml, ("format", "html", "theme", "dark"))
    @test !isnothing(light_theme)
    @test !isnothing(dark_theme)
    !isnothing(light_theme) && @test yaml_scalar(yaml, light_theme) == "cosmo"
    !isnothing(dark_theme) && @test yaml_scalar(yaml, dark_theme) == "darkly"

    sidebar = yaml_node(yaml, ("website", "sidebar"))
    @test !isnothing(sidebar)
    if !isnothing(sidebar)
        sidebar_items = yaml_sequence_items(yaml, sidebar)
        final_project_matches = [
            item for item in sidebar_items
            if something(yaml_item_field(yaml, item, "id"), (value="",)).value ==
               "final-project-topics"
        ]
        @test length(final_project_matches) == 1
        if length(final_project_matches) == 1
            final_project = only(final_project_matches)
            @test yaml_item_field(yaml, final_project, "title").value == "最終プロジェクト課題案"
            @test yaml_item_field(yaml, final_project, "style").value == "docked"
            @test yaml_item_field(yaml, final_project, "collapse-level").value == "2"

            contents = yaml_item_field(yaml, final_project, "contents")
            @test !isnothing(contents)
            if !isnothing(contents)
                top_level = yaml_sequence_items(yaml, contents.node)
                hub = first(top_level)
                @test yaml_item_field(yaml, hub, "text").value == "最終プロジェクト"
                @test yaml_item_field(yaml, hub, "href").value == "assignments/final-project.qmd"
            end

            listed_topics = Tuple{String,String}[]
            for (section, expected_entries) in EXPECTED_FINAL_PROJECT_TOPIC_SECTIONS
                actual_entries = sidebar_section_entries(yaml, final_project, section)
                @test actual_entries == expected_entries
                append!(listed_topics, actual_entries)
            end
            @test length(listed_topics) == 13
            @test length(unique(last.(listed_topics))) == 13

            hub_source = read(joinpath(public_root, "assignments", "final-project.qmd"), String)
            hub_entries = [
                (match.captures[1], "projects/final-project-topics/" * match.captures[2])
                for match in eachmatch(
                    r"(?m)^(?:- )?\[([^\]]+)\]\(\.\./projects/final-project-topics/([^)]+\.qmd)\)",
                    hub_source,
                )
            ]
            @test hub_entries == listed_topics
        end

        topic_metadata_path = joinpath(
            public_root, "projects", "final-project-topics", "_metadata.yml",
        )
        @test isfile(topic_metadata_path)
        if isfile(topic_metadata_path)
            topic_metadata = yaml_source_lines(read(topic_metadata_path, String))
            topic_sidebar = yaml_node(topic_metadata, ("sidebar",))
            @test !isnothing(topic_sidebar)
            !isnothing(topic_sidebar) &&
                @test yaml_scalar(topic_metadata, topic_sidebar) == "final-project-topics"
        end

        hub_source = read(joinpath(public_root, "assignments", "final-project.qmd"), String)
        hub_parts = split(hub_source, "---"; limit=3)
        @test length(hub_parts) == 3
        length(hub_parts) == 3 && @test occursin(r"(?m)^sidebar:\s*course\s*$", hub_parts[2])

        advanced_matches = [
            item for item in sidebar_items
            if something(yaml_item_field(yaml, item, "id"), (value="",)).value == "advanced"
        ]
        @test length(advanced_matches) == 1
        if length(advanced_matches) == 1
            advanced = only(advanced_matches)
            contents = yaml_item_field(yaml, advanced, "contents")
            @test !isnothing(contents)
            if !isnothing(contents)
                advanced_sidebar_entries = [
                    (
                        something(yaml_item_field(yaml, item, "text"), (value="",)).value,
                        something(yaml_item_field(yaml, item, "href"), (value="",)).value,
                    )
                    for item in yaml_sequence_items(yaml, contents.node)
                ]
                @test advanced_sidebar_entries == [
                    ("発展資料一覧", "advanced/index.qmd"),
                    ("SSHでGitHubへ接続する", "advanced/github-ssh.qmd"),
                    ("GitHub CLIでpull requestを操作する", "advanced/github-cli.qmd"),
                    ("CairoMakieによる可視化", "advanced/cairomakie.qmd"),
                    ("パッケージを使ってPDEソルバを構築する", "advanced/package-built-solvers.qmd"),
                    ("公開Solverの数値手法を読み解く", "advanced/public-solver-methods.qmd"),
                    ("JuliaCon 2026から学ぶPDE・CFD計算", "advanced/juliacon-2026-pde-cfd.qmd"),
                ]
            end
        end
        course_matches = [
            item for item in sidebar_items
            if something(yaml_item_field(yaml, item, "id"), (value="",)).value == "course"
        ]
        @test length(course_matches) == 1
        if length(course_matches) == 1
            course = only(course_matches)
            collapse_level = yaml_item_field(yaml, course, "collapse-level")
            @test !isnothing(collapse_level)
            !isnothing(collapse_level) && @test collapse_level.value == "2"
            contents = yaml_item_field(yaml, course, "contents")
            @test !isnothing(contents)
            if !isnothing(contents)
                top_level = yaml_sequence_items(yaml, contents.node)
                home = first(top_level)
                @test yaml_item_field(yaml, home, "href").value == "index.qmd"
                @test yaml_item_field(yaml, home, "text").value == "ホーム"
            end
            @test sidebar_section_entries(yaml, course, "受講準備・共通ガイド") == [
                (text, href) for (href, text) in EXPECTED_PREPARATION_LINKS
            ]
            @test sidebar_section_entries(yaml, course, "全15回") == EXPECTED_SESSION_ENTRIES
            course_lines = yaml[course.line:course.last]
            @test count(occursin("assignments/", line.text) for line in course_lines) == 10
            @test count(occursin("guides/testing.qmd", line.text) for line in course_lines) == 0
            @test !any(occursin("advanced/cairomakie.qmd", line.text) for line in course_lines)
        end
    end

    assignment_metadata_path = joinpath(public_root, "assignments", "_metadata.yml")
    @test !isfile(assignment_metadata_path)

    loader_path = navigation_loader_path(yaml)
    @test loader_path == NAVIGATION_LOADER
    loader_exists = !isnothing(loader_path) && isfile(joinpath(public_root, loader_path))
    @test loader_exists
    if loader_exists
        @test is_module_navigation_loader(read(joinpath(public_root, loader_path), String))
    end

    for path in (
        "lessons/index.qmd",
        "assignments/index.qmd",
        "guides/index.qmd",
        "guides/commands.qmd",
        "guides/troubleshooting.qmd",
        "guides/glossary.qmd",
        "advanced/index.qmd",
        NAVIGATION_LOADER,
        "assets/navigation.js",
    )
        @test isfile(joinpath(public_root, path))
    end

    styles_path = joinpath(public_root, "assets", "styles.css")
    styles_exist = isfile(styles_path)
    @test styles_exist
    if styles_exist
        styles = replace(read(styles_path, String), r"(?s)\/\*.*?\*\/" => "")
        @test occursin(r"body\.quarto-light\s*\{", styles)
        @test occursin(r"body\.quarto-dark\s*\{", styles)
        for variable in ("--tf-accent", "--tf-accent-strong", "--tf-soft", "--tf-border", "--tf-focus")
            @test count(occursin(variable), split(styles, '\n')) >= 2
        end
        @test occursin(":focus-visible", styles)
        @test occursin(r"@media\s*\(max-width:\s*991\.98px\)", styles)
        @test occursin(
            r"(?s)\.navbar\s*\{[^}]*padding-block\s*:\s*0\.5rem\s*;",
            styles,
        )
        @test !occursin("🌙", styles)
        @test !occursin(r"\.quarto-color-scheme-toggle\s+\.bi::before", styles)
        @test occursin(r"\.tf-theme-switch\s*\{", styles)
        @test occursin(
            r"(?s)\.tf-theme-icon\s*\{[^}]*inline-size\s*:\s*1rem\s*;[^}]*block-size\s*:\s*1rem\s*;",
            styles,
        )
        @test occursin(
            r"(?s)\.tf-theme-switch-track\s*\{[^}]*inline-size\s*:\s*2\.25rem\s*;[^}]*block-size\s*:\s*1\.25rem\s*;",
            styles,
        )
        @test occursin(
            r"(?s)\.tf-theme-switch\.alternate\s+\.tf-theme-switch-thumb\s*\{[^}]*transform\s*:\s*translateX\(1rem\)\s*;",
            styles,
        )
        @test occursin(
            r"(?s)body\.quarto-dark\s+:not\(pre\)\s*>\s*code\s*\{[^}]*color\s*:\s*#f8f9fa\s*;[^}]*background-color\s*:\s*#343a40\s*;",
            styles,
        )
        @test !occursin(r"body\.quarto-dark\s+pre\s+code", styles)
    end

    navigation_path = joinpath(public_root, "assets", "navigation.js")
    navigation_exists = isfile(navigation_path)
    @test navigation_exists

    behavior_test_exists = isfile(NAVIGATION_BEHAVIOR_TEST)
    @test behavior_test_exists
    quarto = Sys.which("quarto")
    @test !isnothing(quarto)
    if behavior_test_exists && !isnothing(quarto)
        passed, details = run_navigation_behavior(quarto, navigation_path)
        @test passed
        if !passed
            @info "navigation behavior contract failed" details
        end
    end
end

@testset "lesson and assignment pages use sidebar navigation only" begin
    for id in REQUIRED_COURSE_ORDER
        lesson = read(joinpath(NAVIGATION_SITE_ROOT, "lessons", "$id.qmd"), String)
        assignment = read(joinpath(NAVIGATION_SITE_ROOT, "assignments", "$id.qmd"), String)
        @test !occursin("../assignments/", lesson)
        @test !occursin("../lessons/", assignment)
    end
end
