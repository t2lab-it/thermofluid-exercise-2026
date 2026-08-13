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
    return [
        matched.captures[1]
        for matched in eachmatch(
            r"(?<!!)\[[^\]]+\]\(([^)\s#]+\.qmd)(?:#[^)]+)?\)",
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

const CONTRACT_SECTION_PATTERN = r"<!--\s*contract-section:\s*([a-z][a-z0-9_-]*)\s*-->"

function contract_section_ids(source::AbstractString)
    ids = [String(matched.captures[1]) for matched in eachmatch(CONTRACT_SECTION_PATTERN, source)]
    length(ids) == length(unique(ids)) ||
        throw(ArgumentError("contract-section IDs must be unique"))
    ids
end

function contract_section_body(source::AbstractString, id::AbstractString)
    text = String(source)
    matches = collect(eachmatch(CONTRACT_SECTION_PATTERN, text))
    ids = contract_section_ids(text)
    index = findfirst(==(String(id)), ids)
    isnothing(index) && throw(ArgumentError("missing contract-section: $id"))

    matched = matches[index]
    body_start = nextind(text, matched.offset, length(matched.match))
    body_start > ncodeunits(text) && return ""
    body_end = index == length(matches) ? lastindex(text) : prevind(text, matches[index + 1].offset)
    body_start > body_end && return ""
    strip(String(SubString(text, body_start, body_end)))
end
