using Test

const PUBLIC_COLLAB_ROOT = normpath(joinpath(@__DIR__, ".."))
read_public(relative) = read(joinpath(PUBLIC_COLLAB_ROOT, relative), String)

@testset "public collaboration contract" begin
    git_setup = read_public("setup/git-github.qmd")
    workflow = read_public("guides/workflow.qmd")
    glossary = read_public("guides/glossary.qmd")
    combined = join((git_setup, workflow), '\n')

    for term in ("原則公開", "非公開の例外", "noreply", "LMS", "CC BY 4.0", "MIT")
        @test occursin(term, combined)
    end
    for term in ("GitHubユーザー名", "活動", "減点")
        @test occursin(term, combined)
    end
    @test occursin("合理的配慮", combined)
    @test occursin(r"AIとの全対話ログ[^。\n]*(?:commitしません|commitせず)", combined)
    @test occursin("判断理由", workflow) && occursin("要約", workflow)
    @test occursin("個人課題用", glossary)
    @test !occursin("個人課題用の非公開", glossary)
end
