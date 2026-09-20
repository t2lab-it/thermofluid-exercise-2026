using DelimitedFiles
using TOML

const EXPECTED_HEADER = [
    "rayleigh",
    "nusselt_average",
    "u_max",
    "y_at_u_max",
    "v_max",
    "x_at_v_max",
]
const EXPECTED_RAYLEIGH = [1.0e3, 1.0e4]
const EXPECTED_BENCHMARK = [
    1000.0 1.118 3.649 0.813 3.697 0.178
    10000.0 2.243 16.178 0.823 19.617 0.119
]
const REFERENCE_PATH = joinpath(@__DIR__, "de-vahl-davis-reference.csv")
const README_PATH = joinpath(@__DIR__, "README.md")

function fail(message)
    println(stderr, "natural-convection-cavity preflight failed: ", message)
    exit(1)
end

isfile(REFERENCE_PATH) || fail("de-vahl-davis-reference.csv is missing")
isfile(README_PATH) || fail("README.md is missing")

data, header = try
    readdlm(REFERENCE_PATH, ',', Float64, '\n'; header=true)
catch error
    fail("reference CSV cannot be read: $(sprint(showerror, error))")
end

vec(String.(header)) == EXPECTED_HEADER ||
    fail("reference CSV header must be $(join(EXPECTED_HEADER, ','))")
size(data) == (2, 6) || fail("reference CSV must contain exactly two rows and six columns")
all(isfinite, data) || fail("all benchmark values must be finite")
data[:, 1] == EXPECTED_RAYLEIGH ||
    fail("reference CSV must contain ordered Rayleigh rows 1000 and 10000")
data == EXPECTED_BENCHMARK ||
    fail("reference CSV values must match de Vahl Davis Table V")
all(>(0), data[:, 2]) || fail("average Nusselt values must be positive")
all(>(0), data[:, 3]) || fail("u_max values must be positive")
all(>(0), data[:, 5]) || fail("v_max values must be positive")
all(value -> 0 <= value <= 1, data[:, 4]) ||
    fail("y_at_u_max values must lie inside the cavity")
all(value -> 0 <= value <= 1, data[:, 6]) ||
    fail("x_at_v_max values must lie inside the cavity")

readme = read(README_PATH, String)
contract_match = match(r"(?s)<!-- preflight-contract\s*\n(.*?)\n-->", readme)
contract_match === nothing &&
    fail("README.md must contain the machine-readable preflight contract")
contract = try
    TOML.parse(only(contract_match.captures))
catch error
    fail("README preflight contract is invalid TOML: $(sprint(showerror, error))")
end

get(contract, "schema_version", nothing) == 1 ||
    fail("README preflight schema_version must be 1")
get(contract, "prandtl", nothing) == 0.71 ||
    fail("README benchmark Prandtl number must be 0.71")
get(contract, "domain", nothing) == [0.0, 1.0, 0.0, 1.0] ||
    fail("README domain must be the unit square")
get(contract, "grid_nodes", nothing) == [65, 129] ||
    fail("README verified grids must be 65 by 65 and 129 by 129 nodes")
get(contract, "grid_includes_boundaries", nothing) === true ||
    fail("README grid convention must include boundary nodes")
get(contract, "grid_spacing", nothing) == "h=1/(N-1)" ||
    fail("README grid spacing must be h=1/(N-1)")
get(contract, "coordinate_origin", nothing) == "bottom-left" ||
    fail("README coordinate origin must be bottom-left")
get(contract, "left_temperature", nothing) == 1.0 ||
    fail("README left wall temperature must be one")
get(contract, "right_temperature", nothing) == 0.0 ||
    fail("README right wall temperature must be zero")
get(contract, "horizontal_temperature_boundary", nothing) == "adiabatic" ||
    fail("README horizontal walls must be adiabatic")
get(contract, "velocity_boundary", nothing) == "no-slip" ||
    fail("README velocity boundary must be no-slip")

println(
    "natural-convection-cavity preflight passed: rows=$(size(data, 1)), ",
    "rayleigh=$(Int.(data[:, 1])), Pr=$(contract["prandtl"]), ",
    "grid_nodes=$(contract["grid_nodes"])",
)
