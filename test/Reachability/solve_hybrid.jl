import Polyhedra # needed for some algorithms
using Reachability: constrained_dimensions

include("models/bouncing_ball.jl")
include("models/thermostat.jl")

models = [bouncing_ball, thermostat]

for model in models
    system, options = model()

    # --- reachability algorithms ---

    # default algorithm
    sol = solve(system, options)

    # --- BFFPSV18

    opC = BFFPSV18(:δ=>0.1)

    # concrete discrete-post operator
    sol = solve(system, options, opC, ConcreteDiscretePost())

    # lazy discrete-post operator
    sol = solve(system, options, opC, LazyDiscretePost())

    # overapproximating discrete-post operator
    sol = solve(system, options, opC, ApproximatingDiscretePost())

    # --- GLGM06

    opC = GLGM06(:δ=>0.1)

    # concrete discrete-post operator
    if model == bouncing_ball  # currently this crashes for the thermostat
        opD = ConcreteDiscretePost(:check_invariant_intersection => true)
        sol = solve(system, options, opC, opD);
    end

    # lazy discrete-post operator
    opD = LazyDiscretePost(:check_invariant_intersection => true)
    sol = solve(system, options, opC, opD);

    # --- model analysis ---

    # constrained_dimensions
    HS = system.s
    if model == bouncing_ball
        @test constrained_dimensions(HS) == Dict{Int,Vector{Int}}(1=>[1, 2])
    elseif model == thermostat
        @test constrained_dimensions(HS) == Dict{Int,Vector{Int}}(1=>[1], 2=>[1])
    end
end
