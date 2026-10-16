using Test, TOML

@testset "optional time integration material" begin
    root = normpath(joinpath(@__DIR__, ".."))
    page_path = joinpath(root, "advanced", "numerical-schemes.qmd")
    @test isfile(page_path)
    if isfile(page_path)
        page = read(page_path, String)
        # Executable analysis consumes the actual summary format, without solving RK2 here.
        blocks = collect(eachmatch(r"```\{\.julia #time-integration-summary\}\n(.*?)\n```"s, page))
        @test length(blocks) == 1
        if length(blocks) == 1
            mktempdir() do temp
                mkpath(joinpath(temp, "scratch", "time-integration"))
                reference = joinpath(root,"assets","time-integration-reference","summary.toml")
                cp(reference,joinpath(temp,"scratch","time-integration","summary.toml"))
                data = TOML.parsefile(reference)
                @test data["schema_version"]==1 && data["example_id"]=="time-integration"
                expected = Dict("forward_euler"=>(0.85,1.15),"midpoint_rk2"=>(1.85,2.15),
                                "classical_rk4"=>(3.8,4.2),"backward_euler"=>(0.85,1.15))
                @test Set(row["method"] for row in data["time_convergence"])==Set(keys(expected))
                for row in data["time_convergence"]
                    low,high=expected[row["method"]]
                    @test all(low .< row["orders"] .< high)
                end
                @test Set((r["N"],r["Fo"]) for r in data["diffusion"])==Set([(128,0.03125),(4,1.0)])
                for name in ("time-convergence.png","diffusion-comparison.png","diffusion-cn.png")
                    image=joinpath(dirname(reference),name)
                    @test read(image)[1:8]==UInt8[0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]
                end
                cd(temp) do
                    include_string(Module(gensym(:SummaryExample)), only(blocks)[1], "published summary reader")
                end
            end
        end
        for path in ("lessons/N03.qmd", "assignments/N03.qmd", "advanced/index.qmd", "_quarto.yml")
            @test occursin("numerical-schemes.qmd", read(joinpath(root,path),String))
        end
        @test occursin("#time-integration-fetch",page)
        @test occursin("julia --project=. examples/time-integration/tests.jl",page)
        @test occursin("julia --project=. examples/time-integration/run.jl",page)
        # Keep the optional activity outside the current completion conditions.
        assignment = read(joinpath(root,"assignments","N03.qmd"),String)
        completion = split(assignment,"## 完了条件")[end]
        @test !occursin("rk2",lowercase(completion))
        @test !occursin("time-integration",completion)
    end
end
