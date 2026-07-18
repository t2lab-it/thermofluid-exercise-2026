using Test

const SITE_ROOT = normpath(joinpath(@__DIR__, ".."))
const F01_ASSIGNMENT = read(joinpath(SITE_ROOT, "assignments", "F01.qmd"), String)
const WORKFLOW_GUIDE = read(joinpath(SITE_ROOT, "guides", "workflow.qmd"), String)

@testset "public F01 progress and student-test workflow" begin
    @testset "first branch assignment acknowledges the intentional diagnosis progress diff" begin
        @test occursin("最初の環境診断からこの課題へ", F01_ASSIGNMENT)
        @test occursin("`course_progress.toml`だけ", F01_ASSIGNMENT)
        @test occursin("最初のbranch課題で初めてcommit", F01_ASSIGNMENT)
        @test !occursin("`Current: F01`、変更なし", F01_ASSIGNMENT)
    end

    @testset "student test is edited, staged, and reviewed" begin
        @test occursin("`test/student/F01.jl`のsmoke TODO", F01_ASSIGNMENT)
        @test occursin("代表的な挨拶", F01_ASSIGNMENT)
        @test occursin(
            "git add course_progress.toml exercises/F01_first_pull_request/run.jl test/student/F01.jl learning_logs/F01.md",
            F01_ASSIGNMENT,
        )
        @test occursin("`test/student/F01.jl`", F01_ASSIGNMENT)
        @test occursin("完了", F01_ASSIGNMENT)
    end

    @testset "common guide documents the first-branch dirty-main exception" begin
        @test occursin("最初の環境診断からbranchとpull request課題へ", WORKFLOW_GUIDE)
        @test occursin("`course_progress.toml`だけ", WORKFLOW_GUIDE)
        @test occursin("最初のbranch課題で初めてcommit", WORKFLOW_GUIDE)
        @test occursin(
            "次の配列・関数・テスト課題（課題ID: F02）以降はcleanなmain",
            WORKFLOW_GUIDE,
        )
    end
end
