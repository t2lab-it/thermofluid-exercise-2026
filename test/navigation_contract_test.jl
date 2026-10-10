using Test
using TOML

const NAVIGATION_SITE_ROOT = normpath(joinpath(@__DIR__, ".."))
isdefined(@__MODULE__, :qmd_link_targets) ||
    include(joinpath(@__DIR__, "support", "qmd_contracts.jl"))
const F03_F04_START_COMMAND = "julia --project=. scripts/course.jl start F03-F04"
const N05_N06_START_COMMAND = "julia --project=. scripts/course.jl start N05-N06"
const F03_F04_FORBIDDEN_TERMS = (
    "Forward" * "Diff",
    "自動" * "微分",
    "automatic" * "_reference",
    "T" * "BA",
)

const REQUIRED_COURSE_ORDER = ("F00", "F01", "F02", "F03", "F04", "N01", "N02", "N03", "N04", "N05", "N06", "N07", "N08", "N09")
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
    "guides/julia-environment.qmd",
    "guides/testing.qmd", "guides/commands.qmd",
    "guides/troubleshooting.qmd", "guides/glossary.qmd",
    "guides/links.qmd",
    "guides/final-project-handoff.qmd",
])
const EXPECTED_ADVANCED_HREFS = Set([
    "advanced/terminal-prompt.qmd",
    "advanced/github-ssh.qmd", "advanced/github-cli.qmd",
    "advanced/git-tips.qmd", "advanced/git-stash.qmd", "advanced/git-worktree.qmd",
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

function regular_course_hrefs(targets, kind)
    return filter(targets) do target
        startswith(target, "$kind/") && occursin(r"^[FN][0-9]+\.qmd$", basename(target))
    end
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



@testset "student environment guide connects preparation and restoration" begin
    guide = joinpath(NAVIGATION_SITE_ROOT, "guides", "julia-environment.qmd")
    restoration = joinpath(NAVIGATION_SITE_ROOT, "assignments", "F00.qmd")
    restoration_source = read(restoration, String)
    restoration_section = match(r"(?ms)^## [^\n]*\{#julia環境を復元する\}\s*\n(.*?)(?=^## |\z)", restoration_source)
    @test !isnothing(restoration_section)
    for relative in ("guides/index.qmd", "setup/julia.qmd", "assignments/F00.qmd",
                     "guides/workflow.qmd", "guides/commands.qmd", "guides/troubleshooting.qmd")
        path = joinpath(NAVIGATION_SITE_ROOT, relative)
        source = read(path, String)
        if path == restoration
            source = isnothing(restoration_section) ? "" : restoration_section.captures[1]
        end
        @test guide in resolve_qmd_target.(Ref(path), qmd_link_targets(source))
    end
    @test isfile(guide)
    if isfile(guide)
        source = read(guide, String)
        for anchor in ("environment-files", "select-environment", "restore-environment", "environment-failures")
            @test occursin(Regex("(?m)^## [^\\n]*\\{#" * anchor * "\\}"), source)
        end
        links = [m.captures[1] for m in eachmatch(r"(?<!!)\[[^\]]+\]\(([^)\s]+\.qmd#[^)\s]+)\)", source)]
        @test any(links) do link
            target, fragment = split(link, '#'; limit=2)
            resolve_qmd_target(guide, target) == restoration &&
                fragment == "julia環境を復元する" &&
                occursin("{#" * fragment * "}", restoration_source)
        end
    end
end

@testset "optional Git materials retain their routes and order" begin
    expected = ["advanced/git-tips.qmd", "advanced/git-stash.qmd", "advanced/git-worktree.qmd"]
    yaml = yaml_source_lines(read(joinpath(NAVIGATION_SITE_ROOT, "_quarto.yml"), String))
    menu = navbar_item_by_rel(yaml, "split-navigation-advanced")
    navbar_hrefs = entry_hrefs(navbar_menu_entries(yaml, menu))
    @test filter(href -> href in expected, navbar_hrefs) == expected

    sidebars = yaml_sequence_items(yaml, yaml_node(yaml, ("website", "sidebar")))
    advanced = filter(sidebars) do item
        something(yaml_item_field(yaml, item, "id"), (value="",)).value == "advanced"
    end
    @test length(advanced) == 1
    if length(advanced) == 1
        contents = yaml_item_field(yaml, only(advanced), "contents")
        hrefs = isnothing(contents) ? String[] : entry_hrefs(navigation_entries(yaml, contents.node))
        @test filter(href -> href in expected, hrefs) == expected
    end

    index = joinpath(NAVIGATION_SITE_ROOT, "advanced", "index.qmd")
    index_hrefs = [relpath(resolve_qmd_target(index, target), NAVIGATION_SITE_ROOT)
                   for target in qmd_link_targets(read(index, String))]
    @test filter(href -> href in expected, index_hrefs) == expected
    commands = joinpath(NAVIGATION_SITE_ROOT, "guides", "commands.qmd")
    @test joinpath(NAVIGATION_SITE_ROOT, first(expected)) in
          resolve_qmd_target.(Ref(commands), qmd_link_targets(read(commands, String)))

    for relative in expected[1:2]
        path = joinpath(NAVIGATION_SITE_ROOT, relative)
        @test isfile(path)
        if isfile(path)
            source = read(path, String)
            @test occursin(r"(?m)^sidebar: advanced$", split(source, "---"; limit=3)[2])
            targets = resolve_qmd_target.(Ref(path), qmd_link_targets(source))
            @test joinpath(NAVIGATION_SITE_ROOT, "guides", "workflow.qmd") in targets
            @test joinpath(NAVIGATION_SITE_ROOT, "advanced", "git-worktree.qmd") in targets
            other = relative == first(expected) ? expected[2] : expected[1]
            @test joinpath(NAVIGATION_SITE_ROOT, other) in targets
        end
    end
end

@testset "reviewed course navigation contract" begin
    public_root = NAVIGATION_SITE_ROOT
    quarto = read(joinpath(public_root, "_quarto.yml"), String)
    yaml = yaml_source_lines(quarto)
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

            hub_source = read(joinpath(public_root, "assignments", "final-project.qmd"), String)
            hub_hrefs = Set(
                relpath(
                    resolve_qmd_target(
                        joinpath(public_root, "assignments", "final-project.qmd"),
                        target,
                    ),
                    public_root,
                )
                for target in qmd_link_targets(hub_source)
                if startswith(target, "../projects/final-project-topics/")
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

                home_source = read(joinpath(public_root, "index.qmd"), String)
                course_map = match(r"(?ms)^::: \{\.course-map\}\s*\n(.*?)^:::\s*$", home_source)
                @test !isnothing(course_map)
                map_hrefs = isnothing(course_map) ? String[] : qmd_link_targets(course_map.captures[1])
                for kind in ("lessons", "assignments")
                    @testset "$kind index and course map follow the sidebar" begin
                        expected = regular_course_hrefs(hrefs, kind)
                        @test regular_course_hrefs(map_hrefs, kind) == expected
                        source_path = joinpath(public_root, kind, "index.qmd")
                        index_hrefs = [
                            relpath(resolve_qmd_target(source_path, target), public_root)
                            for target in qmd_link_targets(read(source_path, String))
                        ]
                        expected_index = kind == "assignments" ?
                            vcat(expected, ["assignments/final-project.qmd"]) : expected
                        regular_hrefs = regular_course_hrefs(index_hrefs, kind)
                        listed_pages = filter(index_hrefs) do target
                            target in regular_hrefs || target == "assignments/final-project.qmd"
                        end
                        @test listed_pages == expected_index
                    end
                end
            end
        end
    end


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

@testset "optional worktree comparison is reachable from the shared workflow" begin
    tutorial = joinpath(NAVIGATION_SITE_ROOT, "advanced", "git-worktree.qmd")
    @test isfile(tutorial)
    for relative in ("advanced/index.qmd", "guides/workflow.qmd")
        path = joinpath(NAVIGATION_SITE_ROOT, relative)
        source = read(path, String)
        if relative == "guides/workflow.qmd"
            section = match(r"(?ms)^## [^\n]*\{#exercise-work\}\s*\n(.*?)(?=^## |\z)", source)
            @test !isnothing(section)
            source = isnothing(section) ? "" : section.captures[1]
        end
        targets = qmd_link_targets(source)
        @test tutorial in resolve_qmd_target.(Ref(path), targets)
    end
    if isfile(tutorial)
        source = read(tutorial, String)
        targets = resolve_qmd_target.(Ref(tutorial), qmd_link_targets(source))
        for relative in ("guides/workflow.qmd", "guides/testing.qmd", "assignments/N01.qmd", "assignments/F00.qmd")
            @test joinpath(NAVIGATION_SITE_ROOT, relative) in targets
        end
    end
end

@testset "assignment instructions link to the shared workflow" begin
    workflow = normpath(joinpath(NAVIGATION_SITE_ROOT, "guides", "workflow.qmd"))
    for id in ("F01", "F02", "F03", "F04", "N01", "N02", "N03", "N04", "N05", "N06", "N07", "N08", "N09")
        path = joinpath(NAVIGATION_SITE_ROOT, "assignments", "$id.qmd")
        targets = qmd_link_targets(read(path, String))
        @test any(target -> normpath(resolve_qmd_target(path, target)) == workflow, targets)
    end
end

@testset "N07 refreshes prior source provenance before progress tests" begin
    workflow=read(joinpath(NAVIGATION_SITE_ROOT,"guides","workflow.qmd"),String)
    section=split(workflow,"{#n07-stages}";limit=2)[2]
    regression=findfirst("julia --project=. exercises/N05-N06_common_package_2d_advection/N05.jl verify",section)
    pkg=findfirst("using Pkg; Pkg.test()",section)
    @test !isnothing(regression)
    @test !isnothing(pkg) && !isnothing(regression) && first(regression)<first(pkg)
end

@testset "F03 and F04 retain the combined submission navigation contract" begin
    contracts = TOML.parsefile(
        joinpath(NAVIGATION_SITE_ROOT, "assignments", "contracts.toml"),
    )["assignments"]
    @test contracts["F03"]["start_command"] == F03_F04_START_COMMAND
    @test contracts["F04"]["start_command"] == F03_F04_START_COMMAND
    @test contracts["F03"]["run_path"] == "exercises/F03-F04_vector_calculus/F03.jl"
    @test contracts["F04"]["run_path"] == "exercises/F03-F04_vector_calculus/run.jl"

    quarto_source = read(joinpath(NAVIGATION_SITE_ROOT, "_quarto.yml"), String)
    @test occursin("ベクトル解析の証明と数値微分", quarto_source)

    for (directory, id, paired_id) in (
        ("lessons", "F03", "F04"),
        ("assignments", "F03", "F04"),
        ("lessons", "F04", "F03"),
        ("assignments", "F04", "F03"),
    )
        source = read(joinpath(NAVIGATION_SITE_ROOT, directory, "$id.qmd"), String)
        if directory == "assignments"
            @test occursin("提出単位: `F03-F04`", source)
        end
        @test occursin("$paired_id.qmd", source)
    end

    # F03の到達点は課題ページに集約し，授業ページから参照する．
    assignment_path = joinpath(NAVIGATION_SITE_ROOT, "assignments", "F03.qmd")
    assignment = read(assignment_path, String)
    for name in ("forward_difference", "backward_difference", "centered_difference")
        @test occursin(name, assignment)
    end
    @test all(fragment -> occursin(fragment, assignment), ("二次関数", "三つの差分", "必須"))
    @test occursin("一つのbranchを，第5回の完了まで使います", assignment)
    @test occursin("PRの確認・mergeはF04の完了条件を満たしてから行います", assignment)
    lesson_path = joinpath(NAVIGATION_SITE_ROOT, "lessons", "F03.qmd")
    @test any(qmd_link_targets(read(lesson_path, String))) do target
        normpath(resolve_qmd_target(lesson_path, target)) == assignment_path
    end
end


@testset "N05 and N06 share submission but keep distinct content routes" begin
    contracts=TOML.parsefile(joinpath(NAVIGATION_SITE_ROOT,"assignments","contracts.toml"))["assignments"]
    for (id,entry,other) in (("N05","N05.jl","N06"),("N06","simulate.jl","N05"))
        @test contracts[id]["start_command"] == N05_N06_START_COMMAND
        @test contracts[id]["run_path"] == "exercises/N05-N06_common_package_2d_advection/$entry"
        for directory in ("lessons","assignments")
            source=read(joinpath(NAVIGATION_SITE_ROOT,directory,"$id.qmd"),String)
            @test "$other.qmd" in qmd_link_targets(source)
        end
    end
end

@testset "N08 and N09 preserve a shared submission and independent classroom check" begin
    contracts=TOML.parsefile(joinpath(NAVIGATION_SITE_ROOT,"assignments","contracts.toml"))["assignments"]
    @test contracts["N08"]["start_command"]==contracts["N09"]["start_command"]=="julia --project=. scripts/course.jl start N08-N09"
    @test endswith(contracts["N08"]["run_path"],"simulate.jl")
    @test endswith(contracts["N09"]["run_path"],"run.jl")
    for id in ("N08","N09")
        page=read(joinpath(NAVIGATION_SITE_ROOT,"assignments",id*".qmd"),String)
        @test all(occursin(word,page) for word in ("N08-check","自作2群","公式12出力","LETUS","src/N08N09Elliptic.jl"))
    end
end
