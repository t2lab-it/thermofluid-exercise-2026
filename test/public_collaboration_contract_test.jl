using Test

const PUBLIC_COLLAB_ROOT = normpath(joinpath(@__DIR__, ".."))
read_public(relative) = read(joinpath(PUBLIC_COLLAB_ROOT, relative), String)

@testset "public collaboration contract" begin
    git_setup = read_public("setup/git-github.qmd")
    workflow = read_public("guides/workflow.qmd")
    ai_guidance = read_public("guides/ai-usage.qmd")
    understanding_check = read_public("assignments/_understanding-check.qmd")
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
    for term in ("LETUS", "UTF-8", "対話全文")
        @test occursin(term, understanding_check)
    end
    @test occursin("[AI利用と安全](/guides/ai-usage.qmd)", understanding_check)
    @test occursin("{#understanding-check}", understanding_check)
    @test occursin("lessons/{{< meta lesson-id >}}.html", understanding_check)
    @test occursin("understanding-check-{{< meta lesson-id >}}.txt", understanding_check)
    @test occursin(r"対話全文を学生リポジトリ[^。\n]*含めず", ai_guidance)
    for term in ("LETUS", "理解度チェック", "全文")
        @test occursin(term, ai_guidance)
    end
    @test occursin("学生リポジトリ", glossary)
    @test occursin("公開範囲", glossary)
end

@testset "each assignment owns its lesson understanding check" begin
    for id in ("F00", "F01", "F02", "F03", "F04", "N01", "N02", "N03")
        assignment = read_public("assignments/$id.qmd")
        lesson = read_public("lessons/$id.qmd")
        @test occursin(Regex("(?m)^lesson-id: " * id * "\$"), assignment)
        @test occursin(r"(?m)^understanding-check-points:\n(?:  - .+\n)+", assignment)
        @test count("{{< include /assignments/_understanding-check.qmd >}}", assignment) == 1
        @test occursin("../lessons/$id.qmd", assignment)
        @test occursin("../assignments/$id.qmd#understanding-check", lesson)
        # The assignment must expose the check in its completion criteria too.
        @test occursin(r"(?m)^- .*\[.*\]\(#understanding-check\).*LETUS", assignment)
    end
end
