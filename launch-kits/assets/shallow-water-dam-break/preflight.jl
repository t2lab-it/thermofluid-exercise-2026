using DelimitedFiles

const GRAVITY = 9.81
const EXPECTED_HEADER = ["x", "time", "depth", "velocity"]
const REFERENCE_PATH = joinpath(@__DIR__, "stoker-reference.csv")
const STATE_TOLERANCE = 1.0e-10

function fail(message)
    println(stderr, "shallow-water-dam-break preflight failed: ", message)
    exit(1)
end

isfile(REFERENCE_PATH) || fail("stoker-reference.csv is missing")

data, header = try
    readdlm(REFERENCE_PATH, ',', Float64, '\n'; header=true)
catch error
    fail("reference CSV cannot be read: $(sprint(showerror, error))")
end

vec(String.(header)) == EXPECTED_HEADER ||
    fail("reference CSV header must be $(join(EXPECTED_HEADER, ','))")
size(data, 2) == 4 || fail("reference CSV must have exactly four columns")
size(data, 1) >= 8 || fail("reference CSV must contain all four wave regions")
all(isfinite, data) || fail("reference CSV fields must be finite")

x = data[:, 1]
time = data[:, 2]
depth = data[:, 3]
velocity = data[:, 4]

all(>(0), time) || fail("time must be positive")
all(>(0), depth) || fail("depth must be positive for the wet-bed reference")
all(>(0), diff(x)) || fail("x must be strictly increasing")
all(==(first(time)), time) || fail("all rows must use one reference time")

left_depth = first(depth)
right_depth = last(depth)
left_depth > right_depth || fail("upstream depth must exceed downstream depth")

moving = findall(>(STATE_TOLERANCE), abs.(velocity))
isempty(moving) && fail("reference must contain the moving rarefaction and middle state")
first(moving) > 1 || fail("reference must include the stationary left state")
last(moving) < length(x) || fail("reference must include the stationary right state")

left_indices = 1:(first(moving) - 1)
right_indices = (last(moving) + 1):length(x)
all(isapprox.(depth[left_indices], left_depth; atol=STATE_TOLERANCE, rtol=0)) ||
    fail("left state depth must be constant before the rarefaction")
all(abs.(velocity[left_indices]) .<= STATE_TOLERANCE) ||
    fail("left state velocity must be zero")
all(isapprox.(depth[right_indices], right_depth; atol=STATE_TOLERANCE, rtol=0)) ||
    fail("right state depth must be constant after the shock")
all(abs.(velocity[right_indices]) .<= STATE_TOLERANCE) ||
    fail("right state velocity must be zero")

ordered_indices = (first(moving) - 1):last(moving)
all(diff(depth[ordered_indices]) .<= STATE_TOLERANCE) ||
    fail("depth must not increase through the rarefaction and middle state")
all(diff(velocity[ordered_indices]) .>= -STATE_TOLERANCE) ||
    fail("velocity must not decrease through the rarefaction and middle state")

middle_depth = minimum(depth[moving])
middle_velocity = maximum(velocity[moving])
plateau = findall(
    isapprox.(depth, middle_depth; atol=STATE_TOLERANCE, rtol=0) .&
    isapprox.(velocity, middle_velocity; atol=STATE_TOLERANCE, rtol=0),
)
length(plateau) >= 2 || fail("reference must resolve the constant middle state")

head_speed = -sqrt(GRAVITY * left_depth)
tail_speed = middle_velocity - sqrt(GRAVITY * middle_depth)
shock_speed = middle_depth * middle_velocity / (middle_depth - right_depth)
head_speed < tail_speed < shock_speed ||
    fail("wave ordering must be rarefaction head < tail < shock")

reference_time = first(time)
head_position = head_speed * reference_time
tail_position = tail_speed * reference_time
shock_position = shock_speed * reference_time
first(x) < head_position < tail_position < shock_position < last(x) ||
    fail("reference domain must contain all wave positions")

last(left_indices) < first(moving) ||
    fail("left state must precede the rarefaction")
maximum(x[left_indices]) <= head_position + STATE_TOLERANCE ||
    fail("left-state samples must not cross the rarefaction head")
minimum(x[moving]) >= head_position - STATE_TOLERANCE ||
    fail("moving samples must follow the rarefaction head")
maximum(x[plateau]) <= shock_position + STATE_TOLERANCE ||
    fail("middle-state samples must precede the shock")
minimum(x[right_indices]) >= shock_position - STATE_TOLERANCE ||
    fail("right-state samples must follow the shock")

println(
    "shallow-water-dam-break preflight passed: rows=$(size(data, 1)), ",
    "depth_ratio=$(left_depth / right_depth), ",
    "wave_positions=($(head_position), $(tail_position), $(shock_position))",
)
