using Test

const PUBLIC_STRUCTURE_ROOT = normpath(joinpath(@__DIR__, ".."))
isdefined(@__MODULE__, :parse_qmd_document) ||
    include(joinpath(@__DIR__, "support", "qmd_contracts.jl"))

const EXPECTED_PUBLISHED_DATES = [
    "9/11（金）", "9/18（金）", "9/25（金）", "10/2（金）", "10/9（金）",
    "10/16（金）", "10/23（金）", "10/30（金）", "11/6（金）", "11/13（金）",
    "11/27（金）", "12/4（金）", "12/11（金）", "12/18（金）", "2027/1/8（金）",
]
const F03_F04_PUBLIC_PAGES = [
    "lessons/F03.qmd", "assignments/F03.qmd",
    "lessons/F04.qmd", "assignments/F04.qmd",
]
const F03_F04_FORBIDDEN_PUBLIC_TERMS = (
    "Forward" * "Diff",
    "自動" * "微分",
    "automatic" * "_reference",
    "T" * "BA",
)

is_public_qmd_path(path::AbstractString) =
    endswith(path, ".qmd") && !startswith(basename(path), "_")

function tracked_public_qmd_paths()
    paths = readlines(`git -C $(PUBLIC_STRUCTURE_ROOT) ls-files -- lessons assignments projects/final-project-topics`)
    return sort(filter(is_public_qmd_path, paths))
end

@testset "tracked public QMD paths exclude include fragments" begin
    include_fragment = "lessons/_understanding-check.qmd"
    @test isfile(joinpath(PUBLIC_STRUCTURE_ROOT, include_fragment))
    @test include_fragment ∉ tracked_public_qmd_paths()
    @test "lessons/F02.qmd" ∈ tracked_public_qmd_paths()
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

@testset "QMD structure parser permits editorial rewrites" begin
    first_version = """
    ---
    title: "Original title"
    ---

    ## Original heading

    Original explanation with `student_api`.

    ## Second heading

    [Next](../assignments/F02.qmd)
    """
    rewritten = """
    ---
    title: Rewritten title
    ---

    ## Completely different second section

    A replacement example and explanation with `student_api`.

    ## Renamed first section

    [Continue](../assignments/F02.qmd)
    """

    for source in (first_version, rewritten)
        document = parse_qmd_document(source)
        @test !isnothing(document)
        @test !isempty(document.title)
        @test !isempty(document.body)
        @test has_level2_heading(document.body)
        @test qmd_link_targets(source) == ["../assignments/F02.qmd"]
    end
end

@testset "QMD structure parser rejects missing structure" begin
    @test isnothing(parse_qmd_document("## no frontmatter\n"))
    @test isnothing(parse_qmd_document("---\ntitle: \"\"\n---\n\n## body\n"))
    @test isnothing(parse_qmd_document("---\ntitle: valid\n---\n"))
    @test !has_level2_heading("Paragraph without a section heading.")
end

@testset "AI guidance has one canonical public page" begin
    guide_path = normpath(joinpath(PUBLIC_STRUCTURE_ROOT, "guides", "ai-usage.qmd"))
    @test isfile(guide_path)
    for relative in ("setup/agents.qmd", "guides/workflow.qmd")
        source_path = joinpath(PUBLIC_STRUCTURE_ROOT, relative)
        targets = qmd_link_targets(read(source_path, String))
        @test any(targets) do target
            normpath(resolve_qmd_target(source_path, target)) == guide_path
        end
    end
end

@testset "tracked public QMD pages preserve machine structure" begin
    paths = tracked_public_qmd_paths()
    @test !isempty(paths)

    for relative_path in paths
        source_path = joinpath(PUBLIC_STRUCTURE_ROOT, relative_path)
        source = read(source_path, String)
        document = parse_qmd_document(source)

        @test !isnothing(document)
        isnothing(document) && continue
        @test !isempty(document.title)
        @test !isempty(document.body)
        if basename(relative_path) != "index.qmd"
            @test has_level2_heading(document.body)
        end

        for target in qmd_link_targets(source)
            @test isfile(resolve_qmd_target(source_path, target))
        end
    end
end

@testset "final-project hub links every topic page" begin
    topic_root = joinpath(PUBLIC_STRUCTURE_ROOT, "projects", "final-project-topics")
    topic_paths = Set(
        relpath(joinpath(topic_root, name), PUBLIC_STRUCTURE_ROOT)
        for name in readdir(topic_root)
        if endswith(name, ".qmd")
    )
    hub_path = joinpath(PUBLIC_STRUCTURE_ROOT, "assignments", "final-project.qmd")
    linked_topic_paths = Set(
        relpath(resolve_qmd_target(hub_path, target), PUBLIC_STRUCTURE_ROOT)
        for target in qmd_link_targets(read(hub_path, String))
        if startswith(target, "../projects/final-project-topics/")
    )

    @test linked_topic_paths == topic_paths
end

@testset "course map preserves published dates" begin
    index_source = read(joinpath(PUBLIC_STRUCTURE_ROOT, "index.qmd"), String)
    @test published_course_dates(index_source) == EXPECTED_PUBLISHED_DATES
end

@testset "F03-F04 public pages exclude retired implementation vocabulary" begin
    for relative_path in F03_F04_PUBLIC_PAGES
        source = read(joinpath(PUBLIC_STRUCTURE_ROOT, relative_path), String)
        @test all(term -> !occursin(term, source), F03_F04_FORBIDDEN_PUBLIC_TERMS)
    end
end

@testset "F04 Taylor derivation exposes fourth-order cancellation" begin
    source = read(joinpath(PUBLIC_STRUCTURE_ROOT, "lessons", "F04.qmd"), String)
    @test count(raw"\frac{h^4}{24}f''''(x)", source) == 4
    @test occursin(raw"\frac{h^4}{24}f''''(x)-\frac{h^4}{24}f''''(x)=0", source)
end
