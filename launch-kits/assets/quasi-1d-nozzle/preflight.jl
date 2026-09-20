using DelimitedFiles

const GAMMA = 1.4
const MAX_RESIDUAL = 1.0e-10
const EXPECTED_HEADER = ["area_ratio", "mach_subsonic", "mach_supersonic"]
const REFERENCE_PATH = joinpath(@__DIR__, "area-mach-reference.csv")

area_ratio_from_mach(mach) = (
    (2 / (GAMMA + 1) * (1 + (GAMMA - 1) / 2 * mach^2))^
    ((GAMMA + 1) / (2 * (GAMMA - 1)))
) / mach

function fail(message)
    println(stderr, "quasi-1d-nozzle preflight failed: ", message)
    exit(1)
end

isfile(REFERENCE_PATH) || fail("area-mach-reference.csv is missing")

data, header = try
    readdlm(REFERENCE_PATH, ',', Float64, '\n'; header=true)
catch error
    fail("reference CSV cannot be read: $(sprint(showerror, error))")
end

vec(String.(header)) == EXPECTED_HEADER ||
    fail("reference CSV header must be $(join(EXPECTED_HEADER, ','))")
size(data, 2) == 3 || fail("reference CSV must have exactly three columns")
size(data, 1) > 0 || fail("reference CSV must contain at least one data row")
all(isfinite, data) || fail("reference CSV values must be finite")
all(>(0), data) || fail("reference CSV values must be positive")

area_ratio = data[:, 1]
mach_subsonic = data[:, 2]
mach_supersonic = data[:, 3]
all(>(0), diff(area_ratio)) || fail("area_ratio must be strictly increasing")
all(<(1), mach_subsonic) || fail("subsonic branch must have Mach < 1")
all(>(1), mach_supersonic) || fail("supersonic branch must have Mach > 1")

subsonic_residual = abs.(area_ratio_from_mach.(mach_subsonic) .- area_ratio)
supersonic_residual = abs.(area_ratio_from_mach.(mach_supersonic) .- area_ratio)
maximum(subsonic_residual) <= MAX_RESIDUAL ||
    fail("subsonic area-Mach residual exceeds $(MAX_RESIDUAL)")
maximum(supersonic_residual) <= MAX_RESIDUAL ||
    fail("supersonic area-Mach residual exceeds $(MAX_RESIDUAL)")

println(
    "quasi-1d-nozzle preflight passed: rows=$(size(data, 1)), ",
    "max_residual=$(max(maximum(subsonic_residual), maximum(supersonic_residual)))",
)
