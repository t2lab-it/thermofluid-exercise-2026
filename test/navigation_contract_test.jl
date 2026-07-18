using Test
using TOML

const NAVIGATION_SITE_ROOT = normpath(joinpath(@__DIR__, ".."))

const VISIBLE_NAMES = Dict(
    "F00" => (
        course="受講環境の準備",
        lesson="ガイダンスと環境診断",
        assignment="環境診断",
    ),
    "F01" => (
        course="GitHubを使った課題提出",
        lesson="Julia・Git・GitHubの最小操作",
        assignment="最初のbranchとpull request",
    ),
    "F02" => (
        course="Juliaチュートリアル",
        lesson="配列・関数・loop・テスト",
        assignment="Juliaの配列・関数・テスト",
    ),
    "F03" => (
        course="速習差分法",
        lesson="ベクトル解析・熱伝導・差分と添字",
        assignment="座標・添字・差分の数値計算入門",
    ),
    "N01" => (
        course="1次元線形移流方程式",
        lesson="移流方程式と安定性",
        assignment="1次元線形移流方程式",
    ),
)

const REQUIRED_COURSE_ORDER = ("F00", "F01", "F02", "F03", "N01")
const REQUIRED_SECTION_LABELS = (
    "セットアップ",
    "授業",
    "課題",
    "ガイド",
    "発展資料",
)

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
    nested = yaml_source_lines("""
    # website:
    #   page-navigation: true
    website:
      navbar:
        page-navigation: true
    sidebar:
      - id: course
    format:
      html:
        include-after-body:
          - assets/navigation.js
    """)
    @test isnothing(yaml_node(nested, ("website", "page-navigation")))
    @test isnothing(yaml_node(nested, ("website", "sidebar")))
    include_node = yaml_node(nested, ("format", "html", "include-after-body"))
    @test !isnothing(include_node)
    @test yaml_effective_values(nested, include_node) == ["assets/navigation.js"]
    @test isnothing(navigation_loader_path(nested))

    valid_loader_config = yaml_source_lines("""
    format:
      html:
        include-after-body:
          - assets/navigation-loader.html
    """)
    @test navigation_loader_path(valid_loader_config) == NAVIGATION_LOADER
    @test !is_module_navigation_loader("button.addEventListener('click', handler);")
    @test !is_module_navigation_loader("""
    <script type="module">
      button.addEventListener("click", handler);
    </script>
    """)
    @test !is_module_navigation_loader("<script src=\"assets/navigation.js\"></script>")
    @test is_module_navigation_loader(
        "<script type=\"module\" src=\"/thermofluid-exercise-2026/assets/navigation.js\"></script>",
    )
    @test is_module_navigation_loader("""
    <!-- loader metadata is harmless -->
    <div data-navigation-loader="enabled"></div>
    <script type="module" src="/thermofluid-exercise-2026/assets/navigation.js"></script>
    """)
    @test !is_module_navigation_loader("""
    <script type="module" src="assets/navigation.js"></script>
    <script type="module" src="assets/navigation.js?duplicate=1"></script>
    """)
    @test !is_module_navigation_loader("""
    <script type="module" src="assets/navigation.js"></script>
    const rawNavigation = true;
    """)

    valid_sidebar = yaml_source_lines("""
    website:
      sidebar:
        - id: course
          contents:
            - section: "第1回 受講環境の準備"
              contents:
                - text: "1/2 授業"
                  href: lessons/F00.qmd
                - text: "2/2 課題"
                  href: assignments/F00.qmd
    """)
    sidebar_node = yaml_node(valid_sidebar, ("website", "sidebar"))
    course_item = only(yaml_sequence_items(valid_sidebar, sidebar_node))
    @test yaml_item_field(valid_sidebar, course_item, "id").value == "course"
    course_contents = yaml_item_field(valid_sidebar, course_item, "contents").node
    section_item = only(yaml_sequence_items(valid_sidebar, course_contents))
    @test yaml_item_field(valid_sidebar, section_item, "section").value == "第1回 受講環境の準備"
    section_contents = yaml_item_field(valid_sidebar, section_item, "contents").node
    adjacent_entries = yaml_sequence_items(valid_sidebar, section_contents)
    @test length(adjacent_entries) == 2
    @test yaml_item_field(valid_sidebar, adjacent_entries[1], "href").value == "lessons/F00.qmd"
    @test yaml_item_field(valid_sidebar, adjacent_entries[2], "href").value == "assignments/F00.qmd"

    swapped_navbar = yaml_source_lines("""
    website:
      navbar:
        left:
          - text: 授業
            menu:
              - href: lessons/index.qmd
                text: 授業一覧
              - href: lessons/F01.qmd
                text: Julia・Git・GitHubの最小操作
              - href: lessons/F00.qmd
                text: ガイダンスと環境診断
    """)
    @test navbar_menu_pairs(swapped_navbar, "授業") == [
        ("lessons/index.qmd", "授業一覧"),
        ("lessons/F01.qmd", "Julia・Git・GitHubの最小操作"),
        ("lessons/F00.qmd", "ガイダンスと環境診断"),
    ]
    @test navbar_menu_pairs(swapped_navbar, "授業") != [
        ("lessons/index.qmd", "授業一覧"),
        ("lessons/F00.qmd", "ガイダンスと環境診断"),
        ("lessons/F01.qmd", "Julia・Git・GitHubの最小操作"),
    ]
end

@testset "navigation behavior harness fixture" begin
    behavior_test_exists = isfile(NAVIGATION_BEHAVIOR_TEST)
    @test behavior_test_exists
    quarto = Sys.which("quarto")
    @test !isnothing(quarto)
    if behavior_test_exists && !isnothing(quarto)
        for fixture in ("--self-test", "--insert-before-self-test")
            passed, details = run_navigation_behavior(quarto, fixture)
            @test passed
            if !passed
                @info "navigation behavior harness self-test failed" fixture details
            end
        end
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

    navbar_left = yaml_node(yaml, ("website", "navbar", "left"))
    @test !isnothing(navbar_left)
    if !isnothing(navbar_left)
        navbar_items = yaml_sequence_items(yaml, navbar_left)
        marked_labels = [
            something(yaml_item_field(yaml, item, "text"), (value="",)).value
            for item in navbar_items
            if something(yaml_item_field(yaml, item, "rel"), (value="",)).value == "split-navigation"
        ]
        @test marked_labels == collect(REQUIRED_SECTION_LABELS)
        home_items = [
            item for item in navbar_items
            if something(yaml_item_field(yaml, item, "text"), (value="",)).value == "ホーム"
        ]
        @test length(home_items) == 1
        length(home_items) == 1 && @test isnothing(yaml_item_field(yaml, only(home_items), "rel"))

        for (section_label, field, href_prefix, index_text) in (
            ("授業", :lesson, "lessons", "授業一覧"),
            ("課題", :assignment, "assignments", "課題一覧"),
        )
            expected = [
                ("$href_prefix/index.qmd", index_text),
                [
                    ("$href_prefix/$id.qmd", getproperty(VISIBLE_NAMES[id], field))
                    for id in REQUIRED_COURSE_ORDER
                ]...,
            ]
            @test navbar_menu_pairs(yaml, section_label) == expected
        end

        @test navbar_menu_pairs(yaml, "セットアップ") == [
            ("setup/index.qmd", "セットアップ概要"),
            ("setup/julia.qmd", "Julia"),
            ("setup/git-github.qmd", "Git・GitHub"),
            ("setup/agents.qmd", "Coding Agent"),
            ("guides/workflow.qmd", "課題ワークフロー"),
        ]
        @test navbar_menu_pairs(yaml, "ガイド") == [
            ("guides/index.qmd", "ガイド一覧"),
            ("guides/testing.qmd", "テスト"),
            ("guides/commands.qmd", "コマンド"),
            ("guides/troubleshooting.qmd", "トラブル対応"),
            ("guides/glossary.qmd", "用語集"),
        ]
    end

    page_navigation = yaml_node(yaml, ("website", "page-navigation"))
    @test !isnothing(page_navigation)
    !isnothing(page_navigation) && @test yaml_scalar(yaml, page_navigation) == "true"

    sidebar = yaml_node(yaml, ("website", "sidebar"))
    @test !isnothing(sidebar)

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
        styles = replace(read(styles_path, String), r"(?s)/\*.*?\*/" => "")
        @test occursin(
            r"font-family\s*:\s*(?:[\"']Noto Sans JP[\"']|Noto\s+Sans\s+JP)\s*,",
            styles,
        )
    end

    lesson_paths = [joinpath(public_root, "lessons", "$id.qmd") for id in REQUIRED_COURSE_ORDER]
    for path in lesson_paths
        lesson_exists = isfile(path)
        @test lesson_exists
        lesson_exists && @test !occursin("90分の流れ", read(path, String))
    end

    if !isnothing(sidebar)
        sidebar_items = yaml_sequence_items(yaml, sidebar)

        guide_matches = [
            item for item in sidebar_items
            if something(yaml_item_field(yaml, item, "id"), (value="",)).value == "guides"
        ]
        @test length(guide_matches) == 1
        if length(guide_matches) == 1
            guide_contents = yaml_item_field(yaml, only(guide_matches), "contents")
            @test !isnothing(guide_contents)
            if !isnothing(guide_contents)
                guide_hrefs = [
                    something(yaml_item_field(yaml, item, "href"), (value="",)).value
                    for item in yaml_sequence_items(yaml, guide_contents.node)
                ]
                @test !in("guides/workflow.qmd", guide_hrefs)
            end
        end

        course_matches = [
            item for item in sidebar_items
            if something(yaml_item_field(yaml, item, "id"), (value="",)).value == "course"
        ]
        @test length(course_matches) == 1

        if length(course_matches) == 1
            course = course_matches[1]
            course_contents = yaml_item_field(yaml, course, "contents")
            @test !isnothing(course_contents)
            if !isnothing(course_contents)
                course_items = yaml_sequence_items(yaml, course_contents.node)
                sections = [
                    (item=item, section=yaml_item_field(yaml, item, "section"))
                    for item in course_items if !isnothing(yaml_item_field(yaml, item, "section"))
                ]

                reviewed_section_ids = String[]
                for entry in sections
                    matching_ids = [
                        id for id in REQUIRED_COURSE_ORDER
                        if occursin(VISIBLE_NAMES[id].course, entry.section.value)
                    ]
                    @test length(matching_ids) <= 1
                    length(matching_ids) == 1 && push!(reviewed_section_ids, only(matching_ids))
                end
                @test reviewed_section_ids == collect(REQUIRED_COURSE_ORDER)

                for id in REQUIRED_COURSE_ORDER
                    matching_sections = [entry for entry in sections if occursin(VISIBLE_NAMES[id].course, entry.section.value)]
                    @test length(matching_sections) == 1
                    if length(matching_sections) == 1
                        section_contents = yaml_item_field(yaml, matching_sections[1].item, "contents")
                        @test !isnothing(section_contents)
                        if !isnothing(section_contents)
                            entries = yaml_sequence_items(yaml, section_contents.node)
                            @test length(entries) == 2
                            if length(entries) == 2
                                lesson_text = yaml_item_field(yaml, entries[1], "text")
                                lesson_href = yaml_item_field(yaml, entries[1], "href")
                                assignment_text = yaml_item_field(yaml, entries[2], "text")
                                assignment_href = yaml_item_field(yaml, entries[2], "href")
                                @test !isnothing(lesson_text) && occursin("授業", lesson_text.value)
                                @test !isnothing(lesson_href) && lesson_href.value == "lessons/$id.qmd"
                                @test !isnothing(assignment_text) && occursin("課題", assignment_text.value)
                                @test !isnothing(assignment_href) && assignment_href.value == "assignments/$id.qmd"
                            end
                        end
                    end
                end

                course_lines = yaml[course.line:course.last]
                @test !any(occursin("advanced/cairomakie.qmd", line.text) for line in course_lines)
            end
        end
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
