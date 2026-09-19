using DelimitedFiles

const DENSITY = 1000.0
const HEAT_CAPACITY = 1000.0
const CONDUCTIVITY = 1.0
const LATENT_HEAT = 100_000.0
const DOMAIN_LENGTH = 0.1
const MELTING_TEMPERATURE = 0.0
const LEFT_TEMPERATURE = 10.0
const RIGHT_TEMPERATURE = 0.0
const THERMAL_DIFFUSIVITY = CONDUCTIVITY / (DENSITY * HEAT_CAPACITY)
const STEFAN_NUMBER =
    HEAT_CAPACITY * (LEFT_TEMPERATURE - MELTING_TEMPERATURE) / LATENT_HEAT
const EXPECTED_HEADER = [
    "time",
    "interface_position",
    "left_temperature",
    "right_temperature",
]
const REFERENCE_PATH = joinpath(@__DIR__, "similarity-reference.csv")

function fail(message)
    println(stderr, "stefan-problem preflight failed: ", message)
    exit(1)
end

function erf_series(x::Float64)
    0.0 <= x <= 1.0 || throw(ArgumentError("erf_series expects 0 <= x <= 1"))
    term = x
    total = x
    for n in 1:100
        term *= -x^2 / n
        addition = term / (2n + 1)
        total += addition
        abs(addition) <= eps(Float64) * max(1.0, abs(total)) &&
            return 2total / sqrt(pi)
    end
    error("erf series did not converge")
end

function similarity_lambda(stefan_number::Float64)
    stefan_number > 0 || throw(ArgumentError("Stefan number must be positive"))
    residual(lambda) =
        sqrt(pi) * lambda * exp(lambda^2) * erf_series(lambda) - stefan_number
    lower, upper = 0.0, 1.0
    residual(upper) > 0 || error("similarity root is not bracketed")
    for _ in 1:100
        midpoint = (lower + upper) / 2
        if residual(midpoint) > 0
            upper = midpoint
        else
            lower = midpoint
        end
    end
    (lower + upper) / 2
end

isfile(REFERENCE_PATH) || fail("similarity-reference.csv is missing")

data, header = try
    readdlm(REFERENCE_PATH, ',', Float64, '\n'; header=true)
catch error
    fail("reference CSV cannot be read: $(sprint(showerror, error))")
end

vec(String.(header)) == EXPECTED_HEADER ||
    fail("reference CSV header must be $(join(EXPECTED_HEADER, ','))")
size(data, 2) == 4 || fail("reference CSV must have exactly four columns")
size(data, 1) > 1 || fail("reference CSV must contain at least two data rows")
all(isfinite, data) || fail("reference CSV values must be finite")

time = data[:, 1]
interface_position = data[:, 2]
left_temperature = data[:, 3]
right_temperature = data[:, 4]
all(>(0), time) || fail("time must be positive")
all(>(0), interface_position) || fail("interface position must be positive")
all(>(0), diff(time)) || fail("time must be strictly increasing")
all(>(0), diff(interface_position)) ||
    fail("interface position must be strictly increasing")
all(==(LEFT_TEMPERATURE), left_temperature) ||
    fail("left boundary temperature does not match the fixed problem")
all(==(RIGHT_TEMPERATURE), right_temperature) ||
    fail("right boundary temperature does not match the fixed problem")
maximum(interface_position) < DOMAIN_LENGTH ||
    fail("reference interface leaves the fixed domain")

lambda = similarity_lambda(STEFAN_NUMBER)
similarity_residual =
    abs(sqrt(pi) * lambda * exp(lambda^2) * erf_series(lambda) - STEFAN_NUMBER)
expected_interface = 2lambda .* sqrt.(THERMAL_DIFFUSIVITY .* time)
maximum(abs.(interface_position .- expected_interface)) <= 1.0e-14 ||
    fail("interface positions do not match the one-phase similarity solution")
similarity_residual <= 1.0e-14 ||
    fail("Stefan similarity parameter residual exceeds tolerance")

left_theta =
    (left_temperature .- MELTING_TEMPERATURE) ./
    (LEFT_TEMPERATURE - MELTING_TEMPERATURE)
right_theta =
    (right_temperature .- MELTING_TEMPERATURE) ./
    (LEFT_TEMPERATURE - MELTING_TEMPERATURE)
all(==(1.0), left_theta) || fail("left dimensionless temperature must be one")
all(==(0.0), right_theta) || fail("right dimensionless temperature must be zero")

println(
    "stefan-problem preflight passed: rows=$(size(data, 1)), ",
    "Ste=$(STEFAN_NUMBER), lambda=$(lambda), ",
    "max_interface_residual=$(maximum(abs.(interface_position .- expected_interface)))",
)
