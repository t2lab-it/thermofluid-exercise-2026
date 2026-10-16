using Test

@testset "Pages validates before rendering and deploying" begin
    workflow = read(joinpath(SITE_ROOT, ".github/workflows/pages.yml"), String)
    @test occursin("branches:\n      - main", workflow) && occursin("workflow_dispatch:", workflow)
    @test all(occursin(value, workflow) for value in ("contents: read", "pages: write", "id-token: write"))
    tests = findfirst("test/runtests.jl", workflow)
    render = findfirst("quarto render", workflow)
    deploy = findfirst("actions/deploy-pages@", workflow)
    @test !isnothing(tests) && !isnothing(render) && !isnothing(deploy)
    if !isnothing(tests) && !isnothing(render) && !isnothing(deploy)
        @test first(tests) < first(render) < first(deploy)
    end
    @test occursin("path: _site", workflow)
end

@testset "fork PR checks stay read-only and package only after render" begin
    workflow = read(joinpath(SITE_ROOT, ".github/workflows/check-pages.yml"), String)
    yaml = yaml_source_lines(workflow)
    @test !isnothing(yaml_node(yaml, ("on", "pull_request")))
    @test isnothing(yaml_node(yaml, ("on", "pull_request_target")))
    @test yaml_scalar(yaml, yaml_node(yaml, ("permissions", "contents"))) == "read"
    @test !occursin(r"(?:pages|id-token):\s*write|secrets\.|deploy-pages@|upload-pages-artifact@|instructors-2026", workflow)
    @test occursin("persist-credentials: false", workflow)
    phases = [findfirst(value, workflow) for value in (
        "test/runtests.jl", "quarto render", "project_showcase.py package", "actions/upload-artifact@",
    )]
    @test all(!isnothing, phases)
    @test issorted(first.(phases))
    @test occursin("github.event.pull_request.head.sha", workflow)
    @test occursin("git rev-parse HEAD", workflow)
    @test occursin("html-math-method:mathml", workflow)
    @test occursin("if-no-files-found: error", workflow)
end
