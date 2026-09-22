using TOML

const CANONICAL_BASE = "https://t2lab-it.github.io/thermofluid-exercise-2026/"
const REQUIRED_IDS = Set(["F00", "F01", "F02", "F03", "F04", "N01", "N02", "N03", "N04", "N05", "N06", "N07"])
const SELF_CONTAINED_ASSIGNMENT_IDS = Set(["F00", "F01"])
const F03_F04_START_COMMAND = "julia --project=. scripts/course.jl start F03-F04"

const N05_N06_START_COMMAND = "julia --project=. scripts/course.jl start N05-N06"
const COMBINED_START_COMMANDS = Dict(
    ("F03", "F04") => F03_F04_START_COMMAND,
    ("N05", "N06") => N05_N06_START_COMMAND,
)

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

    for (pair, expected_command) in COMBINED_START_COMMANDS
        if all(id -> haskey(assignments,id) && assignments[id] isa AbstractDict, pair)
            if any(id -> get(assignments[id],"start_command",nothing) != expected_command, pair)
                ok &= fail("$(join(pair, " and ")) must share the combined start command")
            end
        end
    end

    required = ("site_path", "run_path", "start_command", "canonical_url")
    workflow_file = path_inside(public_root, joinpath("guides", "workflow.qmd"))
    workflow = if workflow_file === nothing || !isfile(workflow_file)
        ok &= fail("missing workflow page: guides/workflow.qmd")
        nothing
    else
        read(workflow_file, String)
    end
    if workflow !== nothing
        occursin("julia --project=. scripts/course.jl start TASK_ID", workflow) ||
            (ok &= fail("missing workflow start command template"))
    end
    seen_site = Set{String}()
    seen_run = Set{String}()
    seen_url = Set{String}()
    seen_start = Dict{String,String}()

    for id in sort!(collect(keys(assignments)))
        entry = assignments[id]
        if !(entry isa AbstractDict) || !all(key -> haskey(entry, key), required)
            ok &= fail("missing fields for assignment ID $id")
            continue
        end
        site_path = string(entry["site_path"])
        run_path = string(entry["run_path"])
        command = string(entry["start_command"])
        canonical = string(entry["canonical_url"])
        lesson_path = joinpath("lessons", "$id.qmd")

        if haskey(seen_start, command)
            first_id = seen_start[command]
            combined_pair = (first_id, String(id))
            if get(COMBINED_START_COMMANDS, combined_pair, nothing) != command
                ok &= fail("duplicate start command at assignment ID $id (already used by $first_id)")
            end
        else
            seen_start[command] = String(id)
        end

        if site_path in seen_site || run_path in seen_run || canonical in seen_url
            ok &= fail("duplicate IDs or paths at assignment ID $id")
        end
        push!(seen_site, site_path)
        push!(seen_run, run_path)
        push!(seen_url, canonical)

        site_file = path_inside(public_root, site_path)
        run_file = path_inside(student_root, run_path)
        lesson_file = path_inside(public_root, lesson_path)
        if site_file === nothing || !isfile(site_file)
            ok &= fail("missing site path for $id: $site_path")
        end
        if run_file === nothing || !isfile(run_file)
            ok &= fail("missing run path for $id: $run_path")
        end
        if lesson_file === nothing || !isfile(lesson_file)
            ok &= fail("missing lesson path for $id: $lesson_path")
        end

        expected = expected_canonical(site_path)
        if canonical != expected
            ok &= fail("canonical URL mismatch for $id: expected $expected, got $canonical")
        end

        if site_file !== nothing && isfile(site_file)
            page = read(site_file, String)
            occursin(run_path, page) ||
                (ok &= fail("site page run path mismatch for $id"))
            # F00/F01 are self-contained; later assignment pages delegate
            # to the shared start TASK_ID template in guides/workflow.qmd.
            if id in SELF_CONTAINED_ASSIGNMENT_IDS
                occursin(command, page) ||
                    (ok &= fail("site page start command mismatch for $id"))
            end
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
