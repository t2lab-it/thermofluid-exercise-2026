const VISIBLE_NAMES = Dict(
    "F00" => "受講環境の準備",
    "F01" => "GitHubを使った課題提出",
    "F02" => "Juliaチュートリアル",
    "F03" => "速習差分法",
    "N01" => "1次元線形移流方程式",
)

const REQUIRED_COURSE_ORDER = ("F00", "F01", "F02", "F03", "N01")

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

function normalized_javascript(source::AbstractString)
    known_strings = Dict(
        "click" => "__JSSTR_CLICK__",
        "keydown" => "__JSSTR_KEYDOWN__",
        "pointerenter" => "__JSSTR_POINTERENTER__",
        "aria-expanded" => "__JSSTR_ARIA_EXPANDED__",
        "Escape" => "__JSSTR_ESCAPE__",
        "Enter" => "__JSSTR_ENTER__",
        " " => "__JSSTR_SPACE__",
        "Spacebar" => "__JSSTR_SPACEBAR__",
        "true" => "__JSSTR_TRUE__",
        "false" => "__JSSTR_FALSE__",
    )
    bytes = codeunits(source)
    output = IOBuffer()
    index = 1

    while index <= length(bytes)
        if bytes[index] == UInt8('/') && index < length(bytes) && bytes[index + 1] == UInt8('/')
            index += 2
            while index <= length(bytes) && bytes[index] != UInt8('\n')
                index += 1
            end
        elseif bytes[index] == UInt8('/') && index < length(bytes) && bytes[index + 1] == UInt8('*')
            index += 2
            while index < length(bytes) && !(bytes[index] == UInt8('*') && bytes[index + 1] == UInt8('/'))
                index += 1
            end
            index = min(index + 2, length(bytes) + 1)
        elseif bytes[index] in (UInt8('"'), UInt8('\''), UInt8('`'))
            delimiter = bytes[index]
            index += 1
            value = IOBuffer()
            while index <= length(bytes) && bytes[index] != delimiter
                if bytes[index] == UInt8('\\') && index < length(bytes)
                    index += 1
                end
                write(value, bytes[index])
                index += 1
            end
            index += index <= length(bytes)
            write(output, get(known_strings, String(take!(value)), "__JSSTR_OTHER__"))
        else
            write(output, bytes[index])
            index += 1
        end
    end

    return String(take!(output))
end

function listener_count(javascript::AbstractString, event::AbstractString)
    pattern = Regex("\\.addEventListener\\(\\s*__JSSTR_" * event * "__\\s*,")
    return count(_ -> true, eachmatch(pattern, javascript))
end

const ARIA_STATE_UPDATE =
    r"\.setAttribute\(\s*__JSSTR_ARIA_EXPANDED__\s*,\s*(?:String\(\s*[A-Za-z_$][\w$]*\s*\)|[A-Za-z_$][\w$]*\s*\?\s*__JSSTR_TRUE__\s*:\s*__JSSTR_FALSE__)"

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

    inert_javascript = normalized_javascript("""
    // button.addEventListener("click", handler);
    const dead = '.addEventListener("click", handler)';
    """)
    active_javascript = normalized_javascript("""
    button.addEventListener("click", handler);
    button.addEventListener("keydown", handler);
    button.addEventListener("pointerenter", handler);
    """)
    @test listener_count(inert_javascript, "CLICK") == 0
    @test listener_count(active_javascript, "CLICK") == 1
    @test listener_count(active_javascript, "KEYDOWN") == 1
    @test listener_count(active_javascript, "POINTERENTER") == 1

    inert_aria = normalized_javascript("const dead = '.setAttribute(\"aria-expanded\", String(open))';")
    active_aria = normalized_javascript("button.setAttribute(\"aria-expanded\", String(open));")
    @test !occursin(ARIA_STATE_UPDATE, inert_aria)
    @test occursin(ARIA_STATE_UPDATE, active_aria)

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
end

@testset "reviewed course navigation contract" begin
    public_root = SITE_ROOT
    quarto = read(joinpath(public_root, "_quarto.yml"), String)
    yaml = yaml_source_lines(quarto)
    contracts = TOML.parsefile(joinpath(public_root, "assignments", "contracts.toml"))
    assignment_ids = Set(keys(contracts["assignments"]))

    @test assignment_ids == Set(keys(VISIBLE_NAMES))

    page_navigation = yaml_node(yaml, ("website", "page-navigation"))
    @test !isnothing(page_navigation)
    !isnothing(page_navigation) && @test yaml_scalar(yaml, page_navigation) == "true"

    sidebar = yaml_node(yaml, ("website", "sidebar"))
    @test !isnothing(sidebar)

    navigation_include = yaml_node(yaml, ("format", "html", "include-after-body"))
    @test !isnothing(navigation_include)
    !isnothing(navigation_include) && @test "assets/navigation.js" in yaml_effective_values(yaml, navigation_include)

    for path in (
        "lessons/index.qmd",
        "assignments/index.qmd",
        "guides/index.qmd",
        "guides/commands.qmd",
        "guides/troubleshooting.qmd",
        "guides/glossary.qmd",
        "advanced/index.qmd",
        "assets/navigation.js",
    )
        @test isfile(joinpath(public_root, path))
    end

    styles_path = joinpath(public_root, "assets", "styles.css")
    styles_exist = isfile(styles_path)
    @test styles_exist
    if styles_exist
        styles = replace(read(styles_path, String), r"(?s)/\*.*?\*/" => "")
        @test occursin(r"font-family\s*:\s*[\"']Noto Sans JP[\"']\s*,", styles)
    end

    lesson_paths = [joinpath(public_root, "lessons", "$id.qmd") for id in REQUIRED_COURSE_ORDER]
    for path in lesson_paths
        lesson_exists = isfile(path)
        @test lesson_exists
        lesson_exists && @test !occursin("90分の流れ", read(path, String))
    end

    if !isnothing(sidebar)
        sidebar_items = yaml_sequence_items(yaml, sidebar)
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
                        if occursin(VISIBLE_NAMES[id], entry.section.value)
                    ]
                    @test length(matching_ids) <= 1
                    length(matching_ids) == 1 && push!(reviewed_section_ids, only(matching_ids))
                end
                @test reviewed_section_ids == collect(REQUIRED_COURSE_ORDER)

                for id in REQUIRED_COURSE_ORDER
                    matching_sections = [entry for entry in sections if occursin(VISIBLE_NAMES[id], entry.section.value)]
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
    if navigation_exists
        navigation = normalized_javascript(read(navigation_path, String))
        @test listener_count(navigation, "CLICK") >= 2
        @test listener_count(navigation, "KEYDOWN") >= 1
        @test listener_count(navigation, "POINTERENTER") >= 1
        @test occursin(r"\.key\s*={2,3}\s*__JSSTR_ESCAPE__", navigation)
        @test occursin(r"\.key\s*={2,3}\s*__JSSTR_ENTER__", navigation)
        @test occursin(r"\.key\s*={2,3}\s*(?:__JSSTR_SPACE__|__JSSTR_SPACEBAR__)", navigation)
        @test occursin(ARIA_STATE_UPDATE, navigation)
    end
end
