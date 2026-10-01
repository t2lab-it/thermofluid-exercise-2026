module N08N09SourceLinks

export source_links, check_links

const PAGES = ("lessons/N08.qmd", "lessons/N09.qmd",
               "assignments/N08.qmd", "assignments/N09.qmd")
const LINK = r"\[`([^`]+)`\]\((https://github\.com/t2lab-it/thermofluid-exercise-student-2026/blob/([^/]+)/([^#)]+)#L([0-9]+))\)"
const LINE_URL = r"https://github\.com/t2lab-it/thermofluid-exercise-student-2026/blob/[^)\s]+#L[0-9]+"

"""Extract every line-linked student symbol, including the Elliptic module."""
function source_links(source)
    [ (; name=last(split(first(split(m[1], '(')), '.')),
         url=String(m[2]), commit=String(m[3]), path=String(m[4]),
         line=parse(Int, m[5])) for m in eachmatch(LINK, source) ]
end

function definition_name(line)
    for pattern in (r"^\s*function\s+([A-Za-z_][A-Za-z_0-9!]*)\s*\(",
                    r"^\s*([A-Za-z_][A-Za-z_0-9!]*)\s*\(.*\)\s*=",
                    r"^\s*(?:baremodule|module)\s+([A-Za-z_][A-Za-z_0-9]*)\s*$")
        matched = match(pattern, line)
        matched === nothing || return matched[1]
    end
    nothing
end

"""Verify labels against exact definition lines, using a commit-aware reader."""
function check_links(source, page, read_source; io=devnull)
    errors = String[]
    links = source_links(source)
    isempty(links) && push!(errors, "$page: no student definition links")
    length(links) == length(collect(eachmatch(LINE_URL, source))) ||
        push!(errors, "$page: unsupported student definition link format")
    for link in links
        if !occursin(r"^[0-9a-f]{40}$", link.commit)
            push!(errors, "$page: $(link.name): immutable full commit required: $(link.url)")
            continue
        end
        try
            lines = split(read_source(link.commit, link.path), '\n')
            if !(1 <= link.line <= length(lines))
                push!(errors, "$page: $(link.name): line out of range: $(link.url)")
            elseif definition_name(lines[link.line]) != link.name
                push!(errors, "$page: $(link.name): definition mismatch at $(link.url): $(lines[link.line])")
            else
                println(io, "$page | $(link.name) | $(link.url) | $(strip(lines[link.line]))")
            end
        catch error
            push!(errors, "$page: $(link.name): cannot read $(link.commit):$(link.path): $(sprint(showerror, error))")
        end
    end
    errors
end

"""Read-only audit: julia --project=. scripts/verify_n08_n09_source_links.jl STUDENT_ROOT [PUBLIC_ROOT]."""
function main(args)
    if !(1 <= length(args) <= 2)
        println(stderr, "Usage: verify_n08_n09_source_links.jl STUDENT_ROOT [PUBLIC_ROOT]")
        return 2
    end
    student = abspath(args[1])
    public = length(args) == 2 ? abspath(args[2]) : normpath(joinpath(@__DIR__, ".."))
    cache = Dict{Tuple{String,String},String}()
    read_source = (commit, path) -> get!(cache, (commit, path)) do
        # Read the immutable Git blob; never use the worktree or mutable main.
        read(`git -C $student show $(commit * ":" * path)`, String)
    end
    errors = String[]
    count = 0
    for page in PAGES
        source = read(joinpath(public, page), String)
        append!(errors, check_links(source, page, read_source; io=stdout))
        count += length(source_links(source))
    end
    foreach(error -> println(stderr, error), errors)
    println("Checked $count definition links; $(length(errors)) errors.")
    isempty(errors) ? 0 : 1
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(N08N09SourceLinks.main(ARGS))
end
