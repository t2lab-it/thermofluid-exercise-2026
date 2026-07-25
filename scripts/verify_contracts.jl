using TOML

const CANONICAL_BASE = "https://t2lab-it.github.io/thermofluid-exercise-2026/"
const REQUIRED_IDS = Set(["F00", "F01", "F02", "F03", "F04", "N01"])

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

    required = ("site_path", "run_path", "start_command", "canonical_url")
    seen_site = Set{String}()
    seen_run = Set{String}()
    seen_url = Set{String}()

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
            occursin(command, page) ||
                (ok &= fail("site page start command mismatch for $id"))
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
