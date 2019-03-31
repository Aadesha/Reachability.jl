# out-of-place initialization
init(𝒜::ASB08, 𝑃::InitialValueProblem, 𝑂::Options) = init!(𝒜, 𝑃, copy(𝑂))

function options_ASB08()

    𝑂spec = Vector{OptionSpec}()

    # step size
    push!(𝑂spec, OptionSpec(:δ, 1e-2, domain=Float64, aliases=[:sampling_time],
                            domain_check=(v  ->  v > 0.), info="time step"))
 
    # discretization
    push!(𝑂spec, OptionSpec(:discretization, "forward", domain=String,
                            info="model for bloating/continuous time analysis"))
            
    push!(𝑂spec, OptionSpec(:sih_method, "concrete", domain=String,
                            info="method to compute the symmetric interval hull in discretization"))

    push!(𝑂spec, OptionSpec(:exp_method, "base", domain=String,
                            info="method to compute the matrix exponential"))

    # approximation options
    push!(𝑂spec, OptionSpec(:max_order, 10, domain=Int,
                            info="maximum allowed order of zonotopes"))

    push!(𝑂spec, OptionSpec(:taylor_terms, 4, domain=Int,
                            info="number of taylor terms considered in the linearization"))

    push!(𝑂spec, OptionSpec(:opC, info="continuous post-operator"))

    push!(𝑂spec, OptionSpec(:θ, info="expansion vector"))

    return 𝑂spec
end

# in-place initialization
function init!(𝒜::ASB08, 𝑃::InitialValueProblem, 𝑂::Options)

    # state dimension
    𝑂[:n] = statedim(𝑃)

    # adds default values for unspecified options
    𝑂init = validate_solver_options_and_add_default_values!(𝑂)

    return 𝑂init
end