module StudentSourceLinks

export source_links, check_links, public_pages, audit

const BASE = "https://github.com/t2lab-it/thermofluid-exercise-student-2026"
const URL = Regex(replace(BASE, "." => raw"\.") * raw"[^\s<>)\]\"`]*")
const TARGET = r"^/(blob|tree)/([^/]+)/([^#]+)(?:#(.*))?$"
const FRAGMENT = r"^L([0-9]+)(?:-L([0-9]+))?$"
# These split source files are included within ThermofluidExercise.
const INCLUDED_MODULES = Set(["src/N06Advection.jl", "src/N07Transport.jl", "src/N08N09Elliptic.jl"])
const ALIASES = Dict(
    ("guides/workflow.qmd", "exercises/N05-N06_common_package_2d_advection/N05.jl", "N05.jl verify") => "N05Regression.verify",
    ("lessons/N05.qmd", "exercises/N01_linear_advection/run.jl", "exercises/N01_linear_advection/run.jl") => "N01LinearAdvection.apply_boundary!",
)

"""Inventory every student URL, even unsupported references and fragments."""
function source_links(source)
    links = NamedTuple[]
    for m in eachmatch(URL, source)
        before = source[firstindex(source):prevind(source, m.offset)]
        label = ""
        if endswith(before, "](")
            opening = findlast('[', before)
            opening === nothing || (label = String(before[nextind(before, opening):prevind(before, lastindex(before), 2)]))
        end
        tail = String(m.match[nextind(m.match, lastindex(BASE)):end])
        target = match(TARGET, tail)
        kind, ref, path, fragment = isempty(tail) ? ("repository", "main", "", nothing) :
            target === nothing ? ("unsupported", "", "", nothing) : target.captures
        selection = fragment === nothing ? nothing : match(FRAGMENT, fragment)
        line = selection === nothing ? nothing : tryparse(Int, selection[1])
        finish = selection === nothing ? nothing : selection[2] === nothing ? line : tryparse(Int, selection[2])
        push!(links, (; label, url=String(m.match), kind=String(kind), ref=String(ref), path=String(path),
                       fragment, line, finish, page_line=count(==('\n'), before) + 1,
                       paragraph=length(collect(eachmatch(r"\n[ \t]*\n", before)))))
    end
    links
end

# Parse only: never include or evaluate student source.
function definitions(source)
    starts = [1; [nextind(source, i) for i in findall(==('\n'), source)]]
    result = NamedTuple[]
    function add(kind, name, scope, line)
        expr, after = Meta.parse(source, starts[line]; raise=true)
        expr === nothing && error("no expression at line $line")
        chunk = rstrip(source[starts[line]:prevind(source, after)])
        finish = line + count(==('\n'), chunk)
        push!(result, (; kind, name=String(name), symbol=join([scope; String(name)], '.'), line, finish))
    end
    function signature_name(sig)
        sig isa Symbol && return String(sig)
        sig isa Expr || return nothing
        sig.head in (:call, :where, :(::)) && return signature_name(sig.args[1])
        nothing
    end
    function visit(expr, scope, line)
        expr isa Expr || return
        if expr.head in (:error, :incomplete)
            error("invalid Julia syntax near line $line")
        elseif expr.head in (:toplevel, :block)
            for arg in expr.args
                if arg isa LineNumberNode
                    line = arg.line
                else
                    visit(arg, scope, line)
                end
            end
        elseif expr.head == :module
            body = expr.args[3]
            start = first(a.line for a in body.args if a isa LineNumberNode)
            add(:module, expr.args[2], scope, start)
            visit(body, [scope; String(expr.args[2])], start)
        elseif expr.head == :function || (expr.head == :(=) && expr.args[1] isa Expr && expr.args[1].head in (:call, :where, :(::)))
            name = signature_name(expr.args[1])
            name === nothing && error("unsupported function signature at $line")
            body = expr.args[2]
            start = body isa Expr && body.head == :block ? first(a.line for a in body.args if a isa LineNumberNode) : line
            add(:function, name, scope, start)
        elseif expr.head == :const
            assignment = only(expr.args)
            assignment isa Expr && assignment.head == :(=) && assignment.args[1] isa Symbol || error("unsupported constant at $line")
            add(:const, assignment.args[1], scope, line)
        elseif expr.head == :macrocall && expr.args[1] isa GlobalRef && expr.args[1].name == Symbol("@doc")
            # The documented function/module carries its own real definition line.
            target = expr.args[end]
            target isa Expr && target.head == :const && error("documented constants are unsupported")
            visit(target, scope, line)
        end
    end
    visit(Meta.parseall(source), String[], 1)
    result
end


function label_symbol(link, page)
    startswith(link.label, "`") && endswith(link.label, "`") || error("line link requires a code label")
    label = strip(link.label, '`')
    get(ALIASES, (page, link.path, label)) do
        symbol = first(split(label, '('))
        startswith(symbol, ".") ? symbol[2:end] : symbol
    end
end

function resolve_definition(link, page, defs, context)
    symbol = label_symbol(link, page)
    candidates = filter(defs) do d
        d.symbol == symbol || (occursin('.', symbol) ? endswith(d.symbol, "." * symbol) : d.name == symbol)
    end
    if length(candidates) > 1 && !occursin('.', symbol) && context !== nothing
        candidates = filter(d -> d.symbol == context * "." * symbol, candidates)
    end
    length(candidates) == 1 || error("unresolved or ambiguous symbol $symbol ($(length(candidates)) definitions)")
    only(candidates)
end

function selection_matches(link, definition; strict_ranges=true)
    start, finish = link.line, link.finish
    start == definition.line || return false
    definition.kind == :const && return finish == start
    if definition.kind == :module
        # N01–N04 explanatory links select the whole namespace. The other
        # existing module links identify the declaration's location.
        if link.path == "src/ThermofluidExercise.jl" && definition.name in ("N01", "N02", "N03", "N04")
            return finish == definition.finish
        elseif link.path in INCLUDED_MODULES
            return finish == start
        end
        return finish in (start, definition.finish)
    end
    !strict_ranges && link.fragment == "L$start" && return true
    finish == definition.finish
end

"""Read-only source audit; readers map URL main to one fixed Git snapshot.

The general auditor requires entire function definitions. The legacy N08/N09
API also accepts a single definition-start line, while validating complete ranges.
"""
function check_links(source, page, read_source; read_kind=(ref, path) -> "blob",
                     io=devnull, revision="fixture", strict_ranges=true, line_only=false)
    errors = String[]
    cache = Dict{String,Any}()
    contexts = Dict{Tuple{Int,String},String}()
    for link in source_links(source)
        line_only && link.fragment === nothing && continue
        try
            link.kind != "unsupported" || error("unsupported student URL")
            link.ref == "main" || error("student main required")
            link.kind == "repository" && (println(io, "$page | repository | $(link.url) | $revision"); continue)
            actual_kind = read_kind(link.ref, link.path)
            actual_kind == link.kind || error("Git object kind mismatch: expected $(link.kind), got $actual_kind")
            if link.fragment === nothing
                println(io, "$page | $(link.path) | $(link.kind) | $(link.url) | $revision")
                continue
            end
            link.kind == "blob" || error("line fragment requires a blob")
            link.line !== nothing && link.finish !== nothing || error("unsupported line fragment")
            canonical = link.line == link.finish ? "L$(link.line)" : "L$(link.line)-L$(link.finish)"
            link.fragment == canonical || error("noncanonical line fragment")
            data = get!(cache, link.path) do
                text = read_source(link.ref, link.path)
                defs = definitions(text)
                if link.path in INCLUDED_MODULES
                    defs = [merge(d, (; symbol="ThermofluidExercise." * d.symbol)) for d in defs]
                end
                (; lines=split(text, '\n'), defs)
            end
            1 <= link.line <= link.finish <= length(data.lines) || error("line range out of bounds")
            key = (link.paragraph, link.path)
            definition = resolve_definition(link, page, data.defs, get(contexts, key, nothing))
            selection_matches(link, definition; strict_ranges) ||
                error("definition range mismatch for $(definition.symbol): expected $(definition.line)-$(definition.finish)")
            definition.kind == :module && (contexts[key] = definition.symbol)
            println(io, "$page:$(link.page_line) | $(link.path) | $(definition.symbol) | $(link.url) | $revision")
        catch err
            push!(errors, "$page:$(link.page_line): $(link.url): $(sprint(showerror, err))")
        end
    end
    errors
end

"""Read project.render's QMD globs from _quarto.yml; fail on unsupported syntax.
No YAML dependency or recursive scan of unpublished documents is required.
"""
function public_pages(root)
    patterns = String[]
    in_project = false
    in_render = false
    for line in eachline(joinpath(root, "_quarto.yml"))
        isempty(strip(line)) && continue
        startswith(strip(line), "#") && continue
        if !startswith(line, " ")
            in_project = line == "project:"
            in_render = false
        elseif in_project && line == "  render:"
            in_render = true
        elseif in_render
            if startswith(line, "    - ")
                pattern = strip(strip(line[7:end]), ['\"', '\''])
                occursin(r"^[A-Za-z0-9_./*?-]+\.qmd$", pattern) || error("unsupported render pattern $pattern")
                push!(patterns, pattern)
            elseif startswith(line, "  ") && !startswith(line, "    ")
                in_render = false
            else
                error("unsupported project.render syntax: $line")
            end
        end
    end
    isempty(patterns) && error("project.render has no supported QMD patterns")
    regexes = [Regex("^" * replace(replace(replace(p, "." => "\\."), "*" => "[^/]*"), "?" => "[^/]") * "\$") for p in patterns]
    pages = String[]
    for (dir, children, files) in walkdir(root)
        filter!(d -> !startswith(d, ".") && d != "_site", children)
        for file in files
            endswith(file, ".qmd") && !startswith(file, "_") || continue
            path = relpath(joinpath(dir, file), root)
            any(r -> occursin(r, path), regexes) && push!(pages, path)
        end
    end
    sort!(pages)
end

function audit(student, public, revision; io=devnull)
    errors = String[]
    links = NamedTuple[]
    resolved = ""
    try
        occursin(r"^[0-9a-fA-F]{40}$", revision) || error("student revision must be a full commit SHA")
        resolved = strip(read(`git -C $student rev-parse --verify $(revision * "^{commit}")`, String))
        kinds = Dict{String,String}()
        sources = Dict{String,String}()
        read_kind = (ref, path) -> get!(kinds, path) do
            strip(read(`git -C $student cat-file -t $(resolved * ":" * path)`, String))
        end
        read_source = (ref, path) -> get!(sources, path) do
            read(`git -C $student show $(resolved * ":" * path)`, String)
        end
        for page in public_pages(public)
            source = read(joinpath(public, page), String)
            append!(links, [merge(link, (; page)) for link in source_links(source)])
            append!(errors, check_links(source, page, read_source; read_kind, io, revision=resolved))
        end
    catch err
        push!(errors, "audit: $(sprint(showerror, err))")
    end
    (; revision=resolved, links, errors)
end

function main(args)
    if length(args) != 4 || args[3] != "--student-revision"
        println(stderr, "Usage: verify_student_source_links.jl STUDENT_ROOT PUBLIC_ROOT --student-revision SHA")
        return 2
    end
    report = audit(abspath(args[1]), abspath(args[2]), args[4]; io=stdout)
    println("Student main checked at $(report.revision)")
    foreach(error -> println(stderr, error), report.errors)
    counts = Dict(kind => count(l -> l.kind == kind && l.fragment === nothing, report.links)
                  for kind in ("blob", "tree", "repository"))
    line_count = count(l -> l.fragment !== nothing, report.links)
    println("Checked $(length(report.links)) links: $line_count line, $(counts["blob"]) file, $(counts["tree"]) directory, $(counts["repository"]) repository; $(length(report.errors)) errors.")
    isempty(report.errors) ? 0 : 1
end

end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(StudentSourceLinks.main(ARGS))
end
