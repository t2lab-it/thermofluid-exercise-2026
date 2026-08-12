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
