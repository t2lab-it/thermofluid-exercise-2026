using Test

# Only the published control flow is executed. The updater writes predetermined
# values and deliberately contains no diffusion formula or student TODO solution.
function run_pseudocode_excerpt(code; steps=2, failure=:none)
    scope = Module(gensym(:PseudocodeExcerpt))
    harness = raw"""
    function run_case(steps, failure)
        u0 = [0., 1., 4., 2., 0.]
        original = copy(u0)
        states = ([0., 3., 5., 2., 0.], [-1., 1., 3., 2., 0.])
        dt, dx, diffusivity, effective_fo = 0.25, 1., 1., 0.25
        t_final, boundary = steps * dt, :fixed
        events = []
        buffers = []
        update_count = 0
        function diffusion_step!(new, old, dt, dx, diffusivity; boundary)
            update_count += 1
            # Seed unused history slots so early failure cannot silently record a value.
            update_count == 1 && (heat_history[2:end] .= -12345.)
            push!(buffers, (; new, old, input=copy(old), independent=!Base.mightalias(new, old)))
            push!(events, (:update, update_count))
            failure == :todo && error("未実装 N03: diffusion_step!")
            new .= states[update_count]
            failure == :field_nan && (new[3] = NaN)
            new
        end
        function thermal_content(u, dx)
            push!(events, (:heat, update_count))
            # An unrelated diagnostic stand-in; only data flow is under test.
            failure == :heat_nan && update_count > 0 && return NaN
            sum(u) * dx
        end
        function ensure_finite(values, step, t, fo)
            tag = step == 0 ? :initial_check : values isa Tuple ? :heat_check : :field_check
            push!(events, (tag, step))
            all(isfinite, values) || error("step=$step time=$t fo=$fo")
        end
        u_old = u_new = nothing
        heat_history = Float64[]
        low = high = NaN
        caught = nothing
        completed = false
        try
    """ * code * raw"""
            completed = true
        catch err
            caught = err
        end
        (; u0, original, states, u_old, u_new, heat_history, low, high,
           buffers, events, caught, completed)
    end
    """
    include_string(scope, harness, "published N03 excerpt")
    Base.invokelatest(() -> getfield(scope, :run_case)(steps, failure))
end

function excerpt_flow_matches(result, steps)
    result.completed || return false
    result.u0 == result.original || return false
    length(result.buffers) == steps || return false
    all(b -> b.independent, result.buffers) || return false
    first_buffer = result.buffers[1]
    first_buffer.input == result.original || return false
    !Base.mightalias(first_buffer.old, result.u0) || return false
    !Base.mightalias(first_buffer.new, result.u0) || return false
    result.u_old === result.buffers[end].new || return false
    result.u_new === result.buffers[end].old || return false
    result.u_old == result.states[steps] || return false
    if steps == 2
        second = result.buffers[2]
        second.old === first_buffer.new || return false
        second.new === first_buffer.old || return false
        second.input == result.states[1] || return false
    end
    expected_events = [(:heat, 0), (:initial_check, 0)]
    for step in 1:steps
        append!(expected_events, [(:update, step), (:field_check, step),
                                  (:heat, step), (:heat_check, step)])
    end
    result.events == expected_events || return false
    result.heat_history == vcat(sum(result.original), [sum(result.states[s]) for s in 1:steps]) || return false
    result.low == minimum(vcat(result.original, result.states[1:steps]...)) || return false
    result.high == maximum(vcat(result.original, result.states[1:steps]...))
end

@testset "published N03 control flow (not a numerical solver test)" begin
    path = joinpath(@__DIR__, "..", "advanced", "pseudocode.qmd")
    source = isfile(path) ? read(path, String) : ""
    blocks = collect(eachmatch(r"(?ms)^```\{\.julia #n03-time-loop\}\n(.*?)^```", source))
    @test length(blocks) == 1
    if length(blocks) == 1
        code = only(blocks).captures[1]
        for steps in (1, 2)
            @test excerpt_flow_matches(run_pseudocode_excerpt(code; steps), steps)
        end
        for failure in (:todo, :field_nan, :heat_nan)
            result = run_pseudocode_excerpt(code; failure)
            @test !result.completed
            @test result.caught isa ErrorException
            @test result.u0 == result.original
            @test length(result.buffers) == 1
            # Failure must occur before swap, next update, or normal completion.
            @test result.u_old === result.buffers[1].old
            @test result.u_new === result.buffers[1].new
            @test result.u_old == result.original
            @test result.heat_history == [sum(result.original), -12345., -12345.]
            @test result.low == minimum(result.original)
            @test result.high == maximum(result.original)
            expected = [(:heat, 0), (:initial_check, 0), (:update, 1)]
            failure != :todo && push!(expected, (:field_check, 1))
            failure == :heat_nan && append!(expected, [(:heat, 1), (:heat_check, 1)])
            @test result.events == expected
            message = sprint(showerror, result.caught)
            if failure == :todo
                @test occursin("未実装 N03", message)
            else
                @test all(part -> occursin(part, message), ("step=1", "time=0.25", "fo=0.25"))
            end
        end
        swap = "u_old, u_new = u_new, u_old"
        @test occursin(swap, code)
        removed = replace(code, swap => "nothing")
        premature = replace(removed,
            "ensure_finite(u_new, step" => swap * "\n        ensure_finite(u_new, step")
        @test !excerpt_flow_matches(run_pseudocode_excerpt(removed), 2)
        @test !excerpt_flow_matches(run_pseudocode_excerpt(premature), 2)
    end
end
