using TOML

const CANONICAL_BASE = "https://t2lab-it.github.io/thermofluid-exercise-2026/"
const REQUIRED_IDS = Set(["F00", "F01", "F02", "F03", "N01"])

function fail(message::AbstractString)
    println(stderr, "contract error: ", message)
    return false
end

function canonical_existing_path(path::AbstractString)
    try
        return realpath(path)
    catch error
        error isa Base.IOError || error isa SystemError || error isa ArgumentError || rethrow()
        return nothing
    end
end

function path_inside(root::AbstractString, relative::AbstractString)
    isabspath(relative) && return nothing
    canonical_root = canonical_existing_path(root)
    isnothing(canonical_root) && return nothing
    candidate = canonical_existing_path(normpath(joinpath(root, relative)))
    isnothing(candidate) && return nothing
    separator = string(Base.Filesystem.path_separator)
    root_prefix = canonical_root * (endswith(canonical_root, separator) ? "" : separator)
    candidate == canonical_root && return nothing
    startswith(candidate, root_prefix) || return nothing
    return candidate
end

function expected_canonical(site_path::AbstractString)
    endswith(site_path, ".qmd") || return ""
    return CANONICAL_BASE * replace(site_path, r"\.qmd$" => ".html")
end

function markdown_without_inert_blocks(markdown::AbstractString)
    uncommented = replace(markdown, r"<!--.*?-->"s => "")
    visible = String[]
    fence_character = nothing
    fence_length = 0

    for line in split(uncommented, '\n'; keepempty=true)
        stripped = lstrip(line)
        leading_spaces = length(line) - length(stripped)
        marker = match(r"^(`{3,}|~{3,})", stripped)

        if isnothing(fence_character)
            if leading_spaces <= 3 && marker !== nothing
                fence_character = first(marker.match)
                fence_length = length(marker.match)
            else
                push!(visible, line)
            end
        elseif leading_spaces <= 3 &&
               !isempty(stripped) &&
               first(stripped) == fence_character &&
               length(match(Regex("^" * string(fence_character) * "+"), stripped).match) >= fence_length
            fence_character = nothing
            fence_length = 0
        end
    end

    return join(visible, '\n')
end

# A fragment on the exact assignment path is valid; alternate suffixes and titles are not.
function has_assignment_markdown_link(markdown::AbstractString, target::AbstractString)
    visible = markdown_without_inert_blocks(markdown)
    for link in eachmatch(r"(?<!!)\[[^\]\n]+\]\(\s*([^\s\)]+)\s*\)", visible)
        destination = link.captures[1]
        (destination == target || startswith(destination, target * "#")) && return true
    end
    return false
end

function verify_contracts(contracts_path, public_root, student_root)
    parsed = try
        TOML.parsefile(contracts_path)
    catch error
        return fail("invalid or duplicate contract IDs: $(sprint(showerror, error))")
    end
    assignments = get(parsed, "assignments", nothing)
    assignments isa AbstractDict || return fail("missing [assignments] table")
    isempty(assignments) && return fail("no assignment IDs declared")

    actual_ids = Set(String.(keys(assignments)))
    missing_ids = sort!(collect(setdiff(REQUIRED_IDS, actual_ids)))
    unexpected_ids = sort!(collect(setdiff(actual_ids, REQUIRED_IDS)))
    ok = true
    if !isempty(missing_ids) || !isempty(unexpected_ids)
        ok &= fail(
            "assignment ID set mismatch: missing=" * join(missing_ids, ", ") *
            "; unexpected=" * join(unexpected_ids, ", "),
        )
    end

    required = ("site_path", "student_path", "start_command", "canonical_url")
    seen_site = Set{String}()
    seen_student = Set{String}()
    seen_url = Set{String}()

    for id in sort!(collect(keys(assignments)))
        entry = assignments[id]
        if !(entry isa AbstractDict) || !all(key -> haskey(entry, key), required)
            ok &= fail("missing fields for assignment ID $id")
            continue
        end
        site_path = string(entry["site_path"])
        student_path = string(entry["student_path"])
        command = string(entry["start_command"])
        canonical = string(entry["canonical_url"])
        lesson_path = joinpath("lessons", "$id.qmd")
        assignment_target = "../$site_path"

        if site_path in seen_site || student_path in seen_student || canonical in seen_url
            ok &= fail("duplicate IDs or paths at assignment ID $id")
        end
        push!(seen_site, site_path)
        push!(seen_student, student_path)
        push!(seen_url, canonical)

        site_file = path_inside(public_root, site_path)
        student_file = path_inside(student_root, student_path)
        lesson_file = path_inside(public_root, lesson_path)
        if site_file === nothing || !isfile(site_file)
            ok &= fail("missing site path for $id: $site_path")
        end
        if student_file === nothing || !isfile(student_file)
            ok &= fail("missing student path for $id: $student_path")
        end
        if lesson_file === nothing || !isfile(lesson_file)
            ok &= fail("missing lesson path for $id: $lesson_path")
        end

        expected = expected_canonical(site_path)
        if canonical != expected
            ok &= fail("canonical URL mismatch for $id: expected $expected, got $canonical")
        end

        if lesson_file !== nothing && isfile(lesson_file)
            lesson = read(lesson_file, String)
            has_assignment_markdown_link(lesson, assignment_target) ||
                (ok &= fail("lesson assignment link missing for $id: $assignment_target"))
        end

        if site_file !== nothing && isfile(site_file)
            page = read(site_file, String)
            occursin(student_path, page) ||
                (ok &= fail("site page student path mismatch for $id"))
            occursin(command, page) ||
                (ok &= fail("site page start command mismatch for $id"))
        end
        if student_file !== nothing && isfile(student_file)
            task = read(student_file, String)
            occursin(canonical, task) ||
                (ok &= fail("canonical backlink mismatch for $id"))
        end
    end
    return ok
end

function main(args=ARGS)
    length(args) == 3 || begin
        println(stderr, "usage: verify_contracts.jl CONTRACTS PUBLIC_ROOT STUDENT_ROOT")
        return 2
    end
    contracts, public_root, student_root = abspath.(args)
    isfile(contracts) || return (fail("missing contracts file: $contracts"); 1)
    isdir(public_root) || return (fail("missing public root: $public_root"); 1)
    isdir(student_root) || return (fail("missing student root: $student_root"); 1)
    verify_contracts(contracts, public_root, student_root) || return 1
    println("assignment contracts verified")
    return 0
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(main())
end
