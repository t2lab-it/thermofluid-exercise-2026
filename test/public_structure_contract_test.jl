using Test

const PUBLIC_STRUCTURE_ROOT = normpath(joinpath(@__DIR__, ".."))
isdefined(@__MODULE__, :parse_qmd_document) ||
    include(joinpath(@__DIR__, "support", "qmd_contracts.jl"))
isdefined(@__MODULE__, :StudentSourceLinks) ||
    include(joinpath(@__DIR__, "..", "scripts", "verify_student_source_links.jl"))
using .StudentSourceLinks: public_pages

const EXPECTED_PUBLISHED_DATES = [
    "9/11（金）", "9/18（金）", "9/25（金）", "10/2（金）", "10/9（金）",
    "10/16（金）", "10/23（金）", "10/30（金）", "11/6（金）", "11/13（金）",
    "11/27（金）", "12/4（金）", "12/11（金）", "12/18（金）", "2027/1/8（金）",
]

@testset "structure checks follow render scope before git add" begin
    mktempdir() do root
        run(`git -C $root init --quiet`)
        write(joinpath(root, "_quarto.yml"), "project:\n  render:\n    - guides/*.qmd\n    - lessons/*.qmd\n    - assignments/*.qmd\n")
        for page in ("guides/new.qmd", "lessons/new.qmd", "assignments/new.qmd",
                     "guides/_partial.qmd", "assignments/drafts/private.qmd")
            path = joinpath(root, page)
            mkpath(dirname(path))
            write(path, "---\ntitle: Example\n---\n\n## Content\n")
        end
        @test public_pages(root) == ["assignments/new.qmd", "guides/new.qmd", "lessons/new.qmd"]
    end
end


function published_course_dates(source::AbstractString)
    block = match(r"(?ms)^::: \{\.course-map\}\s*\n(.*?)^:::\s*$", source)
    isnothing(block) && return String[]

    dates = String[]
    for line in split(block.captures[1], '\n')
        cells = strip.(split(strip(line), '|'; keepempty=true))
        length(cells) == 6 || continue
        isnothing(tryparse(Int, cells[2])) && continue
        push!(dates, cells[3])
    end
    return dates
end



@testset "workflow links to the canonical AI guidance page" begin
    guide_path = normpath(joinpath(PUBLIC_STRUCTURE_ROOT, "guides", "ai-usage.qmd"))
    source_path = joinpath(PUBLIC_STRUCTURE_ROOT, "guides", "workflow.qmd")
    targets = qmd_link_targets(read(source_path, String))
    @test any(targets) do target
        normpath(resolve_qmd_target(source_path, target)) == guide_path
    end
end

@testset "rendered public QMD pages preserve machine structure" begin
    paths = public_pages(PUBLIC_STRUCTURE_ROOT)
    @test !isempty(paths)

    for relative_path in paths
        source_path = joinpath(PUBLIC_STRUCTURE_ROOT, relative_path)
        source = read(source_path, String)
        document = parse_qmd_document(source)

        @test !isnothing(document)
        isnothing(document) && continue
        if startswith(relative_path, r"(lessons|assignments|projects)/") && basename(relative_path) != "index.qmd"
            @test has_level2_heading(document.body)
        end

        for target in qmd_link_targets(source)
            @test isfile(resolve_qmd_target(source_path, target))
        end
    end
end


@testset "course map preserves published dates" begin
    index_source = read(joinpath(PUBLIC_STRUCTURE_ROOT, "index.qmd"), String)
    @test published_course_dates(index_source) == EXPECTED_PUBLISHED_DATES
end
