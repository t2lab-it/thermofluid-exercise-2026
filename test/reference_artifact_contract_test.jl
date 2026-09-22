using Test
using TOML
using SHA

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
        @test s["requested_cfl"]==0.5 && s["t_final"]==1.0
        for (name,nx) in (("fixed",81),("periodic",80))
            r=s[name]
            @test r["nx"]==nx && r["steps"]==160
            @test r["dx"]==0.025 && r["dt"]==0.00625 && r["max_cfl"]==0.5
            @test all(isfinite,values(r))
            @test r["initial_minimum"]==1. && 1. <= r["minimum"] < 1.000001
            @test r["initial_maximum"]==2.
            @test r["maximum"] ≈ (name=="fixed" ? 1.4942095043070338 : 1.8163945680355078)
            @test r["overshoot"]==r["undershoot"]==0.
        end
        @test !haskey(s["fixed"],"sum_change")
        p=s["periodic"]
        @test p["initial_sum"]==101.
        @test p["sum_change"]==p["final_sum"]-p["initial_sum"]
        @test abs(p["sum_change"]) <= p["steps"]*p["nx"]*2*eps(Float64)
    end
end

@testset "N03 reference numerics and artifacts" begin
    root=joinpath(REFERENCE_ARTIFACT_ROOT,"assets","n03-reference")
    names=("boundary-comparison.png","heat-content.png","convergence.png","summary.toml")
    @test all(n->isfile(joinpath(root,n)),names)
    if all(n->isfile(joinpath(root,n)),names)
        @test sum(filesize(joinpath(root,n)) for n in names)<=10*1024^2
        for n in names[1:3]
            @test 10_000<filesize(joinpath(root,n))<=5*1024^2
            @test png_dimensions(joinpath(root,n))==(width=800,height=500)
        end
        s=TOML.parsefile(joinpath(root,"summary.toml"))
        @test s["course_id"]=="N03" && s["domain"]==[0.,2.]
        @test s["diffusivity"]==0.1 && s["requested_fo"]==0.4 && s["t_final"]==1.
        @test occursin("dimensionless",s["units"])
        for b in ("fixed","insulated")
            r=s[b]; c=s["convergence"][b]
            @test r["nx"]==81 && r["steps"]==400
            @test r["dx"]==0.025 && r["dt"]==0.0025 && r["fo"]≈0.4
            @test all(isfinite,values(r))
            @test r["initial_heat"]≈0.525
            @test r["heat_change"]==r["final_heat"]-r["initial_heat"]
            @test 0<=r["minimum"]<=r["maximum"]<=1.
            @test c["nx"]==[41,81,161]
            @test 0<c["errors"][3]<c["errors"][2]<c["errors"][1]
            @test all(p->1.8<p<2.2,c["orders"])
            @test c["orders"]≈log2.(c["errors"][1:2]./c["errors"][2:3])
        end
        @test s["fixed"]["final_heat"]≈0.461840713264 atol=1e-12
        @test abs(s["insulated"]["heat_change"])<1e-12
    end
end

@testset "N04 both model reference contracts" begin
    for (model,reference_errors) in (("linear",[0.0353795761290,0.0199421663399,0.0106714557243]),
        ("nonlinear",[0.0235384925365,0.0133952214002,0.0072268027443]))
        root=joinpath(REFERENCE_ARTIFACT_ROOT,"assets","n04-reference",model)
        names=("comparison.png","conservation.png","convergence.png","summary.toml")
        @test all(n->isfile(joinpath(root,n)),names)
        all(n->isfile(joinpath(root,n)),names) || continue
        for n in names[1:3]
            @test png_dimensions(joinpath(root,n))==(width=800,height=500)
        end
        s=TOML.parsefile(joinpath(root,"summary.toml"))
        @test s["course_id"]=="N04" && s["model"]==model && s["boundary"]=="periodic"
        @test s["domain"]==[0.,2.] && s["initial"]=="pulse" && s["t_final"]==1.
        @test occursin("dimensionless",s["units"])
        @test s["convergence"]["nx"]==[40,80,160]
        @test s["convergence"]["errors"]≈reference_errors atol=1e-12
        @test all(p->0.8<p<1.2,s["convergence"]["orders"])
        @test s["advection_only"]["dt"]==s["diffusion_only"]["dt"]==s["combined"]["dt"]
        for key in ("advection_only","diffusion_only","combined")
            r=s[key]
            @test r["model"]==model && r["nx"]==80 && r["dx"]==0.025
            @test r["initial_integral"]≈2.525 && abs(r["integral_change"])<1e-11
            @test r["max_stability_number"]<=0.8+1e-12
            @test r["diffusivity"]==(key=="advection_only" ? 0. : 0.1)
            @test r["advection"]==(key!="diffusion_only")
        end
    end
end

@testset "N06 three grid reference fields and diagnostics" begin
    root=joinpath(REFERENCE_ARTIFACT_ROOT,"assets","n06-reference")
    names=("fields.png","diagnostics.png","convergence.png","summary.toml","plots.toml")
    @test all(n->isfile(joinpath(root,n)),names)
    @test !any(n->endswith(n,".h5"),readdir(root))
    @test sum(filesize(joinpath(root,n)) for n in names)<=10*1024^2
    for name in names[1:3]
        @test 10_000 < filesize(joinpath(root,name)) <= 5*1024^2
        dims=png_dimensions(joinpath(root,name))
        @test dims == (name=="fields.png" ? (width=1100,height=660) : name=="diagnostics.png" ? (width=1000,height=400) : (width=700,height=460))
    end
    s=TOML.parsefile(joinpath(root,"summary.toml")); plots=TOML.parsefile(joinpath(root,"plots.toml"))
    @test s["schema_version"]==1 && s["diagnostics_complete"]
    @test s["conditions"]["cx"]==1. && s["conditions"]["cy"]==.5
    @test s["conditions"]["boundary_x"]==s["conditions"]["boundary_y"]=="periodic"
    @test plots["source_fields_sha256"]==s["source_fields_sha256"]
    @test occursin(r"^[a-f0-9]{64}$",s["source_fields_sha256"])
    for (id,nx,ny) in (("n040x030",40,30),("n080x060",80,60),("n160x120",160,120))
        c=s["cases"][id]
        @test (c["nx"],c["ny"])==(nx,ny)
        @test c["dx"]==2/nx && c["dy"]==1/ny
        @test c["time"]==[0.,.25,.5,.75,1.]
        @test maximum(abs.(c["mass"].-2.))<=2e-12
        @test all(isfinite,c["variance"]) && all(>=(0.),c["variance"])
        @test c["segment_dt"].*c["segment_steps"]≈fill(.25,4)
    end
    c=s["convergence"]
    @test c["errors"]≈[.04586691138478507,.02406462411492619,.012332831539922874] atol=1e-12
    @test c["errors"][1]>c["errors"][2]>c["errors"][3]>0
    @test c["orders"]≈log2.(c["errors"][1:2]./c["errors"][2:3])
    @test all(p->.8<=p<=1.2,c["orders"])
end

@testset "N07 reference provenance and analytic convergence" begin
    root=joinpath(REFERENCE_ARTIFACT_ROOT,"assets","n07-reference")
    pngs=("temperature_comparison.png","boundary_heat.png","burgers_fields.png","convergence.png")
    @test Set(readdir(root))==Set((pngs...,"summary.toml","plots.toml"))
    s=TOML.parsefile(joinpath(root,"summary.toml"));p=TOML.parsefile(joinpath(root,"plots.toml"))
    @test s["schema_version"]==1 && s["task_id"]=="N07" && s["diagnostics_complete"]
    @test s["source_sha256"]==p["source_sha256"] && s["run_id"]==p["run_id"]
    @test p["source_summary_sha256"]==bytes2hex(sha256(read(joinpath(root,"summary.toml"))))
    @test p["temperature_color_limits"]==[0.,1.6] && p["display_grid"]=="n080x060"
    for name in pngs
        @test p["figure_sha256"][name]==bytes2hex(sha256(read(joinpath(root,name))))
        @test 10_000<filesize(joinpath(root,name))<=5*1024^2
    end
    @test Set(keys(s["convergence"]))==Set(("periodic_advection","periodic_diffusion","periodic_combined","periodic_burgers"))
    for (id,c) in s["convergence"]
        lo,hi=id=="periodic_diffusion" ? (1.8,2.2) : (.8,1.2)
        @test length(c["errors"])==3 && all(diff(c["errors"]).<0)
        @test c["orders"]≈log2.(c["errors"][1:2]./c["errors"][2:3])
        @test all(lo .<= c["orders"] .<= hi)
    end
    for id in ("channel_fixed","channel_insulated")
        c=s["cases"][id]["n080x060"]
        @test c["time"]==[0.,.25,.5,.75,1.]
        @test maximum(abs,c["residual"])<1e-12
        @test c["heat"]-fill(first(c["heat"]),5)≈c["cumulative_input"]+c["residual"] atol=1e-12
    end
end
