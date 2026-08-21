using Test

const PUBLIC_COLLAB_ROOT = normpath(joinpath(@__DIR__, ".."))
read_public(relative) = read(joinpath(PUBLIC_COLLAB_ROOT, relative), String)

@testset "public collaboration contract" begin
    git_setup = read_public("setup/git-github.qmd")
    workflow = read_public("guides/workflow.qmd")
    ai_guidance = read_public("guides/ai-usage.qmd")
    glossary = read_public("guides/glossary.qmd")

    public_scope_match = match(r"(?ms)^##\s+[^\n]*公開範囲\s*\n(?:(?!^##\s).)*", git_setup)
    @test !isnothing(public_scope_match)
    public_scope = isnothing(public_scope_match) ? "" : public_scope_match.match
    for term in ("リポジトリ", "公開", "GitHubユーザー名", "活動")
        @test occursin(term, public_scope)
    end
    for term in ("CC BY 4.0", "MIT")
        @test occursin(term, git_setup)
    end
    @test occursin(r"AIとの全対話ログ[^。\n]*commit", public_scope)
    for term in ("学習ログ", "判断")
        @test occursin(term, workflow)
    end
    for term in ("依頼内容", "提案", "採用", "修正", "却下", "判断理由")
        @test occursin(term, ai_guidance)
    end
    @test occursin("学生リポジトリ", glossary)
    @test occursin("公開範囲", glossary)
end
