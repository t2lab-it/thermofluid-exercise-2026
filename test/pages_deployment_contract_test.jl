using Test

@testset "GitHub Pages deployment workflow contract" begin
    workflow_path = joinpath(SITE_ROOT, ".github", "workflows", "pages.yml")
    @test isfile(workflow_path)

    if isfile(workflow_path)
        workflow = read(workflow_path, String)

        @test occursin("push:", workflow)
        @test occursin("branches:\n      - main", workflow)
        @test occursin("workflow_dispatch:", workflow)
        @test occursin("contents: read", workflow)
        @test occursin("pages: write", workflow)
        @test occursin("id-token: write", workflow)
        @test occursin("julia-actions/setup-julia@v2", workflow)
        @test occursin("version: '1.12.6'", workflow)
        @test occursin("quarto-dev/quarto-actions/setup@v2", workflow)
        @test occursin("version: '1.9.31'", workflow)
        setup_quarto = findfirst("      - name: Set up Quarto", workflow)
        run_tests = findfirst("      - name: Run tests", workflow)
        @test first(setup_quarto) < first(run_tests)
        @test occursin("QUARTO_JULIA_PROJECT: \".\"", workflow)
        @test occursin("actions/configure-pages@v5", workflow)
        @test occursin("actions/upload-pages-artifact@v3", workflow)
        @test occursin("path: _site", workflow)
        @test occursin("actions/deploy-pages@v4", workflow)
        @test occursin("environment:\n      name: github-pages", workflow)
    end
end
