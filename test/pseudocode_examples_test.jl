using Test

# Execute only the published control flow. Recorded states contain no advection
# formula or student TODO solution; the boundary stand-in marks completion.
function run_pseudocode_excerpt(code; steps=2, scheme=:upwind, failure=:none)
    scope = Module(gensym(:PseudocodeExcerpt))
    harness = raw"""
    function run_case(steps, scheme, failure)
        initial = [1., 2., 4., 2., 1.]
        states = scheme == :upwind ?
            ([1., 3., 5., 2., -99.], [1., 1., 3., 4., -99.]) :
            ([1., 4., 2., 3., -99.], [1., -1., 4., 2., -99.])
        completed_states = [vcat(state[1:end-1], state[end-1]) for state in states]
        x = collect(0.:0.5:2.)
        c, dt, dx = 1., 0.25, 0.5
        events, buffers, boundary_inputs = [], [], []
        update_count = 0
        function rectangular_initial_condition(x)
            push!(events, (:initial, 0))
            failure == :initial && error("未実装 N01: rectangular_initial_condition")
            copy(initial)
        end
        function update!(new, old, selected)
            update_count += 1
            push!(buffers, (; new, old, input=copy(old), independent=!Base.mightalias(new, old)))
            push!(events, (selected, update_count))
            failure == :validation && throw(ArgumentError("step inputs"))
            failure == :todo && error("未実装 N01: $(selected)_step!")
            new .= states[update_count]
            new
        end
        upwind_step!(new, old, c, dt, dx) = update!(new, old, :upwind)
        centered_step!(new, old, c, dt, dx) = update!(new, old, :centered)
        function apply_boundary!(new)
            push!(events, (:boundary, update_count))
            push!(boundary_inputs, copy(new))
            failure == :boundary && error("boundary failure")
            new[1] = 1.
            new[end] = new[end-1]
            new
        end
        u0 = u_old = u_new = nothing
        caught = nothing
        completed = false
        try
    """ * code * raw"""
            completed = true
        catch err
            caught = err
        end
        (; initial, u0, states, completed_states, u_old, u_new,
           buffers, boundary_inputs, events, caught, completed)
    end
    """
    include_string(scope, harness, "published N01 excerpt")
    Base.invokelatest(() -> getfield(scope, :run_case)(steps, scheme, failure))
end

function excerpt_flow_matches(result, steps, scheme)
    result.completed || return false
    result.u0 == result.initial || return false
    length(result.buffers) == steps || return false
    all(b -> b.independent, result.buffers) || return false
    first_buffer = result.buffers[1]
    first_buffer.input == result.initial || return false
    !Base.mightalias(first_buffer.old, result.u0) || return false
    !Base.mightalias(first_buffer.new, result.u0) || return false
    result.u_old === result.buffers[end].new || return false
    result.u_new === result.buffers[end].old || return false
    result.u_old == result.completed_states[steps] || return false
    result.boundary_inputs == collect(result.states[1:steps]) || return false
    if steps == 2
        second = result.buffers[2]
        second.old === first_buffer.new || return false
        second.new === first_buffer.old || return false
        second.input == result.completed_states[1] || return false
    end
    expected_events = [(:initial, 0)]
    for step in 1:steps
        append!(expected_events, [(scheme, step), (:boundary, step)])
    end
    result.events == expected_events
end

@testset "published N01 control flow (not a numerical solver test)" begin
    path = joinpath(@__DIR__, "..", "advanced", "pseudocode.qmd")
    source = isfile(path) ? read(path, String) : ""
    blocks = collect(eachmatch(r"(?ms)^```\{\.julia #n01-time-loop\}\n(.*?)^```", source))
    @test length(blocks) == 1
    if length(blocks) == 1
        code = only(blocks).captures[1]
        for scheme in (:upwind, :centered)
            for steps in (1, 2)
                @test excerpt_flow_matches(run_pseudocode_excerpt(code; steps, scheme), steps, scheme)
            end
            initial_failure = run_pseudocode_excerpt(code; scheme, failure=:initial)
            @test !initial_failure.completed
            @test initial_failure.caught isa ErrorException
            @test initial_failure.events == [(:initial, 0)]
            @test isempty(initial_failure.buffers)
            @test initial_failure.u_old === nothing
            for failure in (:validation, :todo, :boundary)
                result = run_pseudocode_excerpt(code; scheme, failure)
                @test !result.completed
                @test result.caught isa (failure == :validation ? ArgumentError : ErrorException)
                @test result.u0 == result.initial
                @test length(result.buffers) == 1
                @test result.u_old === result.buffers[1].old
                @test result.u_new === result.buffers[1].new
                @test result.u_old == result.initial
                expected = [(:initial, 0), (scheme, 1)]
                failure == :boundary && push!(expected, (:boundary, 1))
                @test result.events == expected
                @test length(result.boundary_inputs) == (failure == :boundary ? 1 : 0)
            end
            swap = "u_old, u_new = u_new, u_old"
            @test occursin(swap, code)
            removed = replace(code, swap => "nothing")
            premature = replace(removed, "apply_boundary!(u_new)" => swap * "\n    apply_boundary!(u_new)")
            no_boundary = replace(code, "apply_boundary!(u_new)" => "nothing")
            @test !excerpt_flow_matches(run_pseudocode_excerpt(removed; scheme), 2, scheme)
            @test !excerpt_flow_matches(run_pseudocode_excerpt(premature; scheme), 2, scheme)
            @test !excerpt_flow_matches(run_pseudocode_excerpt(no_boundary; scheme), 2, scheme)
        end
    end
end
