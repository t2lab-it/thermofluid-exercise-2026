using Test
using TOML

const NAVIGATION_SITE_ROOT = normpath(joinpath(@__DIR__, ".."))

const REQUIRED_COURSE_ORDER = ("F00", "F01", "F02", "F03", "F04", "N01")
const REQUIRED_ASSIGNMENT_IDS = Set(REQUIRED_COURSE_ORDER)
const EXPECTED_PREPARATION_HREFS = Set([
    "setup/index.qmd", "setup/julia.qmd", "setup/git-github.qmd",
    "setup/agents.qmd", "guides/ai-usage.qmd", "guides/workflow.qmd",
])
const EXPECTED_COURSE_HREFS = [
    href
    for id in REQUIRED_COURSE_ORDER
    for href in ("lessons/$id.qmd", "assignments/$id.qmd")
]
const EXPECTED_GUIDE_HREFS = Set([
    "guides/testing.qmd", "guides/commands.qmd",
    "guides/troubleshooting.qmd", "guides/glossary.qmd",
])
const EXPECTED_ADVANCED_HREFS = Set([
    "advanced/github-ssh.qmd", "advanced/github-cli.qmd",
    "advanced/cairomakie.qmd", "advanced/package-built-solvers.qmd",
    "advanced/public-solver-methods.qmd",
])
const EXPECTED_TOPIC_HREFS = Set([
    "projects/final-project-topics/quasi-1d-nozzle.qmd",
    "projects/final-project-topics/stefan-problem.qmd",
    "projects/final-project-topics/shallow-water-dam-break.qmd",
    "projects/final-project-topics/natural-convection-cavity.qmd",
    "projects/final-project-topics/inverse-heat-source.qmd",
    "projects/final-project-topics/incompressible-navier-stokes.qmd",
    "projects/final-project-topics/profiling-and-optimization.qmd",
    "projects/final-project-topics/gpu-porting.qmd",
    "projects/final-project-topics/iterative-solvers.qmd",
    "projects/final-project-topics/waterlily-cylinder-flow.qmd",
    "projects/final-project-topics/trixi-shock-tube.qmd",
    "projects/final-project-topics/oceananigans-horizontal-convection.qmd",
    "projects/final-project-topics/open-proposal.qmd",
])

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

function navbar_item_by_rel(lines, marker)
    navbar_left = yaml_node(lines, ("website", "navbar", "left"))
    isnothing(navbar_left) && return nothing
    matches = [
        item for item in yaml_sequence_items(lines, navbar_left)
        if let rel = yaml_item_field(lines, item, "rel")
            !isnothing(rel) && marker in split(rel.value)
        end
    ]
    return length(matches) == 1 ? only(matches) : nothing
end

function navigation_entries(lines, node)
    isnothing(node) && return Tuple{String,Union{Nothing,String}}[]
    return [
        (
            something(yaml_item_field(lines, item, "text"), (value="",)).value,
            let href = yaml_item_field(lines, item, "href")
                isnothing(href) ? nothing : href.value
            end,
        )
        for item in yaml_sequence_items(lines, node)
    ]
end

function navbar_menu_entries(lines, item)
    isnothing(item) && return Tuple{String,Union{Nothing,String}}[]
    menu = yaml_item_field(lines, item, "menu")
    isnothing(menu) && return Tuple{String,Union{Nothing,String}}[]
    return navigation_entries(lines, menu.node)
end

function sidebar_sections(lines, sidebar_item)
    contents = yaml_item_field(lines, sidebar_item, "contents")
    isnothing(contents) && return []
    return [
        item for item in yaml_sequence_items(lines, contents.node)
        if !isnothing(yaml_item_field(lines, item, "section"))
    ]
end

function sidebar_section_entries(lines, section_item)
    contents = yaml_item_field(lines, section_item, "contents")
    isnothing(contents) && return Tuple{String,Union{Nothing,String}}[]
    return navigation_entries(lines, contents.node)
end

entry_hrefs(entries) = [href for (_, href) in entries if !isnothing(href)]

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
    @test entry_hrefs([
        ("Any rewritten label", "lessons/F00.qmd"),
        ("Another label", nothing),
        ("自由な表示名", "assignments/F00.qmd"),
    ]) == ["lessons/F00.qmd", "assignments/F00.qmd"]

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
    section = only(sidebar_sections(sidebar, course))
    @test sidebar_section_entries(sidebar, section) == [
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
    @test assignment_ids == REQUIRED_ASSIGNMENT_IDS

    language = yaml_node(yaml, ("lang",))
    @test !isnothing(language)
    !isnothing(language) && @test yaml_scalar(yaml, language) == "ja"

    site_title = yaml_node(yaml, ("website", "title"))
    @test !isnothing(site_title)
    !isnothing(site_title) && @test !isempty(strip(yaml_scalar(yaml, site_title)))

    navbar_left = yaml_node(yaml, ("website", "navbar", "left"))
    @test !isnothing(navbar_left)
    if !isnothing(navbar_left)
        navbar_items = yaml_sequence_items(yaml, navbar_left)
        @test all(navbar_items) do item
            label = yaml_item_field(yaml, item, "text")
            !isnothing(label) && !isempty(strip(label.value))
        end
        for (marker, expected_hrefs) in (
            ("split-navigation-guides", EXPECTED_GUIDE_HREFS),
            ("split-navigation-advanced", EXPECTED_ADVANCED_HREFS),
        )
            item = navbar_item_by_rel(yaml, marker)
            @test !isnothing(item)
            if !isnothing(item)
                @test isnothing(yaml_item_field(yaml, item, "href"))
                entries = navbar_menu_entries(yaml, item)
                @test all(entry -> !isempty(strip(first(entry))), entries)
                @test Set(entry_hrefs(entries)) == expected_hrefs
            end
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
            title = yaml_item_field(yaml, final_project, "title")
            @test !isnothing(title)
            !isnothing(title) && @test !isempty(strip(title.value))
            @test yaml_item_field(yaml, final_project, "style").value == "docked"
            @test yaml_item_field(yaml, final_project, "collapse-level").value == "2"

            contents = yaml_item_field(yaml, final_project, "contents")
            @test !isnothing(contents)
            if !isnothing(contents)
                top_level = yaml_sequence_items(yaml, contents.node)
                hub = first(top_level)
                @test !isempty(strip(yaml_item_field(yaml, hub, "text").value))
                @test yaml_item_field(yaml, hub, "href").value == "assignments/final-project.qmd"
            end

            listed_topics = reduce(vcat, [
                sidebar_section_entries(yaml, section)
                for section in sidebar_sections(yaml, final_project)
            ]; init=Tuple{String,Union{Nothing,String}}[])
            @test all(entry -> !isempty(strip(first(entry))), listed_topics)
            @test length(listed_topics) == 13
            @test Set(entry_hrefs(listed_topics)) == EXPECTED_TOPIC_HREFS
            @test length(unique(entry_hrefs(listed_topics))) == 13

            hub_source = read(joinpath(public_root, "assignments", "final-project.qmd"), String)
            hub_hrefs = Set(
                "projects/final-project-topics/" * match.captures[2]
                for match in eachmatch(
                    r"(?m)^(?:- )?\[([^\]]+)\]\(\.\./projects/final-project-topics/([^)]+\.qmd)\)",
                    hub_source,
                )
            )
            @test hub_hrefs == EXPECTED_TOPIC_HREFS
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
                entries = navigation_entries(yaml, contents.node)
                @test all(entry -> !isempty(strip(first(entry))), entries)
                @test Set(entry_hrefs(entries)) == union(
                    EXPECTED_ADVANCED_HREFS,
                    Set(["advanced/index.qmd"]),
                )
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
                @test !isempty(strip(yaml_item_field(yaml, home, "text").value))
            end

            sections = sidebar_sections(yaml, course)
            section_entries = [sidebar_section_entries(yaml, section) for section in sections]
            preparation_matches = filter(
                entries -> Set(entry_hrefs(entries)) == EXPECTED_PREPARATION_HREFS,
                section_entries,
            )
            @test length(preparation_matches) == 1
            course_sections = filter(entries -> entries ∉ preparation_matches, section_entries)
            @test length(course_sections) == 1
            if length(course_sections) == 1
                entries = only(course_sections)
                @test all(entry -> !isempty(strip(first(entry))), entries)
                hrefs = entry_hrefs(entries)
                @test hrefs == vcat(
                    EXPECTED_COURSE_HREFS,
                    fill("assignments/final-project.qmd", 4),
                )
                for href in EXPECTED_COURSE_HREFS
                    @test count(==(href), hrefs) == 1
                end
                @test !("guides/testing.qmd" in hrefs)
                @test !("advanced/cairomakie.qmd" in hrefs)
            end
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
        "guides/ai-usage.qmd",
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
