# =======================================
# Functionality to project the flowpipe
# =======================================
import LazySets.Approximations: project
using LazySets.Approximations: overapproximate

# add a "time" variable by taking the cartesian product of the flowpipe ℱ with each time lapse
function add_time(ℱ::Vector{ReachSet{Hyperrectangle{Float64}}})
    ℱ_with_time = Vector{ReachSet{Hyperrectangle{Float64}}}(undef, length(ℱ))
    @inbounds for i in eachindex(ℱ)
        t0, t1 = ℱ[i].t_start, ℱ[i].t_end
        radius = (t1 - t0)/2.0
        Xi = ℱ[i].X × Hyperrectangle([t0 + radius], [radius])
        Xi = convert(Hyperrectangle, Xi)
        ℱ_with_time[i] = ReachSet{Hyperrectangle{Float64}}(Xi, t0, t1)
    end
    return ℱ_with_time
end

function project(sol::ReachSolution{Hyperrectangle{Float64}})
    N = length(sol.Xk)  # number of reach sets
    n = dim(first(sol.Xk).X) # state space dimension
    options = copy(sol.options)
    πℱ = Vector{ReachSet{Hyperrectangle{Float64}}}(undef, N) # preallocated projected reachsets
    πvars = sol.options[:plot_vars] # variables for plotting
    @assert length(πvars) == 2

    if 0 ∈ πvars
        # add the time variable to the flowpipe (assuming it's not already
        # part of the model)
        ℱ = add_time(sol.Xk)
        n += 1
        options[:n] += 1 # TODO : remove when option is removed
        πvars = copy(πvars)
        πvars[first(indexin(0, πvars))] = n # time index is added in the end
    else
        ℱ = sol.Xk
    end

    M = sparse([1, 2], πvars, [1.0, 1.0], 2, n)
    for i in eachindex(ℱ)
        t0, t1 = ℱ[i].t_start, ℱ[i].t_end
        πℱ_i = overapproximate(M * ℱ[i].X, Hyperrectangle)
        πℱ[i] = ReachSet{Hyperrectangle{Float64}}(πℱ_i, t0, t1)
    end
    return ReachSolution(πℱ, options)
end
