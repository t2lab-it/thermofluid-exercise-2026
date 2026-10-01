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
