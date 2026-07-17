const VISIBLE_NAMES = Dict(
    "F00" => "受講環境の準備",
    "F01" => "GitHubを使った課題提出",
    "F02" => "Juliaチュートリアル",
    "F03" => "速習差分法",
    "N01" => "1次元線形移流方程式",
)

const REQUIRED_COURSE_ORDER = ("F00", "F01", "F02", "F03", "N01")

function yaml_block(source::AbstractString, key::AbstractString)
    lines = split(source, '\n')
    start = findfirst(line -> strip(line) == "$key:", lines)
    isnothing(start) && return ""

    base_indent = length(lines[start]) - length(lstrip(lines[start]))
    stop = findfirst((start + 1):length(lines)) do line_number
        line = lines[line_number]
        !isempty(strip(line)) && length(line) - length(lstrip(line)) <= base_indent
    end
    last_line = isnothing(stop) ? length(lines) : stop - 1
    return join(lines[start:last_line], '\n')
end

@testset "reviewed course navigation contract" begin
    public_root = SITE_ROOT
    quarto = read(joinpath(public_root, "_quarto.yml"), String)
    contracts = TOML.parsefile(joinpath(public_root, "assignments", "contracts.toml"))
    assignment_ids = Set(keys(contracts["assignments"]))

    @test assignment_ids == Set(keys(VISIBLE_NAMES))
    @test occursin("page-navigation: true", quarto)
    @test count(==("sidebar:"), strip.(split(strip(quarto), '\n'))) >= 1

    for path in (
        "lessons/index.qmd",
        "assignments/index.qmd",
        "guides/index.qmd",
        "guides/commands.qmd",
        "guides/troubleshooting.qmd",
        "guides/glossary.qmd",
        "advanced/index.qmd",
        "assets/navigation.js",
    )
        @test isfile(joinpath(public_root, path))
    end

    @test occursin("Noto Sans JP", read(joinpath(public_root, "assets", "styles.css"), String))

    lesson_paths = [joinpath(public_root, "lessons", "$id.qmd") for id in REQUIRED_COURSE_ORDER]
    @test all(isfile, lesson_paths)
    @test !any(occursin("90分の流れ", read(path, String)) for path in lesson_paths)

    sidebar = yaml_block(quarto, "sidebar")
    for id in REQUIRED_COURSE_ORDER
        @test occursin(VISIBLE_NAMES[id], sidebar)
    end

    course_paths = [
        match.match for match in eachmatch(
            r"(?:lessons|assignments)/(?:F00|F01|F02|F03|N01)\.qmd",
            sidebar,
        )
    ]
    expected_paths = reduce(vcat, (["lessons/$id.qmd", "assignments/$id.qmd"] for id in REQUIRED_COURSE_ORDER))
    @test course_paths == expected_paths
    @test !occursin("advanced/cairomakie.qmd", sidebar)

    navigation_path = joinpath(public_root, "assets", "navigation.js")
    if isfile(navigation_path)
        navigation = read(navigation_path, String)
        for token in ("aria-expanded", "Escape", "pointerenter", "click", "keydown")
            @test occursin(token, navigation)
        end
        @test occursin("assets/navigation.js", quarto)
    end
end
