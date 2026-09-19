using Test
using TOML

const REFERENCE_ARTIFACT_ROOT = normpath(joinpath(@__DIR__, ".."))

function png_dimensions(path)
    data = read(path)
    signature = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
    length(data) >= 24 && data[1:8] == signature || return nothing
    width = Int(ntoh(only(reinterpret(UInt32, data[17:20]))))
    height = Int(ntoh(only(reinterpret(UInt32, data[21:24]))))
    return (width=width, height=height)
end

@testset "N01 reference images are valid publication artifacts" begin
    for name in ("upwind.png", "centered-euler.png")
        path = joinpath(REFERENCE_ARTIFACT_ROOT, "assets", "n01-reference", name)
        @test isfile(path)
        isfile(path) || continue

        dimensions = png_dimensions(path)
        @test !isnothing(dimensions)
        isnothing(dimensions) && continue
        @test dimensions.width >= 600
        @test dimensions.height >= 400
        @test filesize(path) > 10_000
    end
end

@testset "N01 reference summary preserves numeric contracts" begin
    summary_path = joinpath(
        REFERENCE_ARTIFACT_ROOT,
        "assets",
        "n01-reference",
        "summary.toml",
    )
    @test isfile(summary_path)
    summary = TOML.parsefile(summary_path)

    @test Set(keys(summary)) == Set(["course_id", "grid", "upwind", "centered_euler"])
    @test summary["course_id"] == "N01"
    @test summary["grid"] == Dict("dx" => 0.025, "nx" => 81)

    for (name, scheme, unstable) in (
        ("upwind", "upwind-euler", false),
        ("centered_euler", "centered-euler", true),
    )
        method = summary[name]
        @test method["scheme"] == scheme
        @test method["cfl"] == 0.5
        @test method["dt"] == 0.0125
        @test method["steps"] == 40
        @test method["overshoot_occurred"] == unstable
        @test method["undershoot_occurred"] == unstable
        @test all(isfinite, Float64[
            method["minimum"],
            method["maximum"],
            method["overshoot"],
            method["undershoot"],
        ])
    end
end

@testset "N02 reference numeric and artifact contract" begin
    root=joinpath(REFERENCE_ARTIFACT_ROOT,"assets","n02-reference")
    names=("fixed-boundary.png","periodic.png","summary.toml")
    @test all(name -> isfile(joinpath(root,name)),names)
    if all(name -> isfile(joinpath(root,name)),names)
        @test sum(filesize(joinpath(root,n)) for n in names) <= 10*1024^2
        for name in names[1:2]
            p=joinpath(root,name)
            @test 10_000 < filesize(p) <= 5*1024^2
            @test png_dimensions(p) == (width=800,height=500)
        end
        s=TOML.parsefile(joinpath(root,"summary.toml"))
        @test s["course_id"]=="N02" && s["domain"]==[0.,2.]
        @test s["requested_cfl"]==s["t_final"]==0.5
        for (name,nx) in (("fixed",81),("periodic",80))
            r=s[name]
            @test r["nx"]==nx && r["steps"]==80
            @test r["dx"]==0.025 && r["dt"]==0.00625 && r["max_cfl"]==0.5
            @test all(isfinite,values(r))
            @test r["initial_minimum"]==r["minimum"]==1.
            @test r["initial_maximum"]==2.
            @test r["maximum"] ≈ 1.9687726868657076
            @test r["overshoot"]==r["undershoot"]==0.
        end
        @test !haskey(s["fixed"],"sum_change")
        p=s["periodic"]
        @test p["initial_sum"]==101.
        @test p["sum_change"]==p["final_sum"]-p["initial_sum"]
        @test abs(p["sum_change"]) <= 80*80*2*eps(Float64)
    end
end
