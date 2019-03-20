export GLGM06

struct GLGM06 <: ContinuousPost
    options::TwoLayerOptions

    function GLGM06(𝑂::Options)
        𝑂new = validate_and_wrap_options(𝑂, options_GLGM06())
        return new(𝑂new)
    end
end

# convenience constructor from pairs of symbols
GLGM06(𝑂::Pair{Symbol,<:Any}...) = GLGM06(Options(Dict{Symbol,Any}(𝑂)))

# default options (they are added in the function validate_and_wrap_options)
GLGM06() = GLGM06(Options())

include("init.jl")
include("post.jl")
include("reach.jl")
include("check.jl")

# =======================================
# Functionality to project the flowpipe
# =======================================
import LazySets.Approximations: project

# add a "time" variable by taking the cartesian product of a flowpipe with
# each time lapse
function add_time(sol::ReachSolution{Zonotope})
    N = length(sol.Xk)
    sol_with_time = Vector{ReachSet{Zonotope{Float64}, Float64}}(undef, N)
    @inbounds for i in eachindex(sol.Xk)
        t0, t1 = sol.Xk[i].t_start, sol.Xk[i].t_end
        radius = (t1 - t0)/2.0
        Xk_i = sol.Xk[i].X × Zonotope([t0 + radius], hcat(radius)) # BallInf([t0 + radius], radius)
        Xk_i = convert(Zonotope, Xk_i)
        sol_with_time[i] = ReachSet(Xk_i, t0, t1)
    end
    options = copy(sol.options)
    options[:n] += 1 # update state space dimension
    return ReachSolution(sol_with_time, options)
end

function project(sol::ReachSolution{Zonotope})
    N = length(sol.Xk)  # number of reach sets
    πsol = Vector{Zonotope}(undef, N) # preallocated projected reachsets
    πvars = sol.options[:plot_vars] # variables for plotting
    @assert length(πvars) == 2

    if 0 ∈ πvars
        # add the time variable to the model (it is assumed it is not already
        # a variable in the model)
        sol = add_time(sol)
        πvars[first(indexin(0, πvars))] = sol.options[:n]  # time index is added in the end
    end
    n = sol.options[:n] # state space dimension (possibly enlarged in add_time)

    for i in eachindex(sol.Xk)
        M = sparse([1, 2], πvars, [1.0, 1.0], 2, n)
        πsol[i] = linear_map(M, sol.Xk[i].X)
    end
    return πsol
end
