function parse_qmd_document(source::AbstractString)
    lines = split(source, '\n'; keepempty=true)
    isempty(lines) && return nothing
    first(lines) == "---" || return nothing
    closing = findnext(==("---"), lines, 2)
    isnothing(closing) && return nothing

    title_matches = [
        match(r"^title:\s*(.*?)\s*$", line)
        for line in lines[2:(closing - 1)]
    ]
    filter!(!isnothing, title_matches)
    length(title_matches) == 1 || return nothing
    raw_title = strip(only(title_matches).captures[1])
    title = strip(raw_title, ['"', Char(0x27)])
    body = strip(join(lines[(closing + 1):end], '\n'))
    isempty(title) && return nothing
    isempty(body) && return nothing
    return (title=title, body=body)
end

has_level2_heading(body::AbstractString) = occursin(r"(?m)^##\s+\S", body)

function qmd_link_targets(source::AbstractString)
    source = replace(source, r"(?s)<!--.*?-->" => "")
    source = replace(source, r"(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$" => "")
    return [
        matched.captures[1]
        for matched in eachmatch(
            r"(?<!!)\[[^\]]+\]\(((?![a-zA-Z][a-zA-Z0-9+.-]*:|//)[^)\s#]+\.qmd)(?:#[^)]+)?\)",
            source,
        )
    ]
end

function resolve_qmd_target(source_path::AbstractString, target::AbstractString)
    return normpath(joinpath(dirname(source_path), target))
end

function missing_required_identifiers(source::AbstractString, required)
    return [identifier for identifier in required if !occursin(identifier, source)]
end

function missing_required_definition_links(source::AbstractString, required)
    names = Set{String}()
    for m in eachmatch(r"\[`([^`]+)`\]\(https://github\.com/t2lab-it/thermofluid-exercise-student-2026/blob/main/[^)]+#L[0-9]+(?:-L[0-9]+)?\)", source)
        symbol = first(split(m[1], '('))
        push!(names, symbol)
        push!(names, last(split(symbol, '.')))
    end
    [name for name in required if !(name in names)]
end

has_one_understanding_check(source::AbstractString) =
    count("{{< include /assignments/_understanding-check.qmd >}}", source) == 1
