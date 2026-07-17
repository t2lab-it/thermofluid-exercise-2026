using Test

const SITE_ROOT = normpath(joinpath(@__DIR__, ".."))
const F01_ASSIGNMENT = read(joinpath(SITE_ROOT, "assignments", "F01.qmd"), String)
const WORKFLOW_GUIDE = read(joinpath(SITE_ROOT, "guides", "workflow.qmd"), String)

@testset "public F01 progress and student-test workflow" begin
    @testset "F01 assignment acknowledges the intentional F00 progress diff" begin
        @test occursin("F00からF01", F01_ASSIGNMENT)
        @test occursin("`course_progress.toml`だけ", F01_ASSIGNMENT)
        @test occursin("F01で初めてcommit", F01_ASSIGNMENT)
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

    @testset "common guide documents the F01-only dirty-main exception" begin
        @test occursin("F00からF01", WORKFLOW_GUIDE)
        @test occursin("`course_progress.toml`だけ", WORKFLOW_GUIDE)
        @test occursin("F01で初めてcommit", WORKFLOW_GUIDE)
        @test occursin("F02以降はcleanなmain", WORKFLOW_GUIDE)
    end
end
