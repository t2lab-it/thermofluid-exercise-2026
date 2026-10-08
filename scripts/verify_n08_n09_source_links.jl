module N08N09SourceLinks

export source_links, check_links

const PAGES = ("lessons/N08.qmd", "lessons/N09.qmd",
               "assignments/N08.qmd", "assignments/N09.qmd")
include(joinpath(@__DIR__, "verify_student_source_links.jl"))

"""Extract single-line and range-linked symbols, preserving name/line/ref fields."""
function source_links(source)
    [merge(link, (; name=last(split(first(split(strip(link.label, '`'), '(')), '.'))))
     for link in StudentSourceLinks.source_links(source)
     if link.fragment !== nothing && startswith(link.label, "`") && endswith(link.label, "`")]
end

"""Verify main definition starts or complete ranges, using a ref-aware reader."""
function check_links(source, page, read_source; io=devnull, revision="fixture")
    links = source_links(source)
    errors = StudentSourceLinks.check_links(source, page, read_source; io, revision,
                                           strict_ranges=false, line_only=true)
    isempty(links) && push!(errors, "$page: no student definition links")
    errors
end

"""Read-only audit against local student main; synchronize it before running.
Usage: julia --project=. scripts/verify_n08_n09_source_links.jl STUDENT_ROOT [PUBLIC_ROOT].
"""
function main(args)
    if !(1 <= length(args) <= 2)
        println(stderr, "Usage: verify_n08_n09_source_links.jl STUDENT_ROOT [PUBLIC_ROOT]")
        return 2
    end
    student = abspath(args[1])
    public = length(args) == 2 ? abspath(args[2]) : normpath(joinpath(@__DIR__, ".."))
    # Resolve main once for a consistent audit and record the tested revision.
    revision = strip(read(`git -C $student rev-parse --verify "refs/heads/main^{commit}"`, String))
    println("Student main checked at $revision (local main; synchronize before running).")
    cache = Dict{String,String}()
    read_source = (ref, path) -> get!(cache, path) do
        read(`git -C $student show $(revision * ":" * path)`, String)
    end
    errors = String[]
    count = 0
    for page in PAGES
        source = read(joinpath(public, page), String)
        append!(errors, check_links(source, page, read_source; io=stdout, revision))
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
