__precompile__()
"""
This is the main module and provides interfaces for specifying and solving reachability problems.
"""
module Reachability

using Reexport, RecipesBase, Memento, MathematicalSystems, HybridSystems,
      Compat, Suppressor
@reexport using LazySets
using LazySets.Approximations: overapproximate

import LazySets.use_precise_ρ
import LazySets.LinearMap
 
include("logging.jl")
include("Options/dictionary.jl")
include("Options/validation.jl")
include("Options/default_options.jl")
include("Utils/Utils.jl")
include("Properties/Properties.jl")
include("ReachSets/ReachSets.jl")

@reexport using Reachability.Utils,
                Reachability.ReachSets,
                Reachability.Properties

export project

include("solve.jl")
include("plot_recipes.jl")

# specify behavior of line search algorithm by dispatching on post operator
global discrete_post_operator = ConcreteDiscretePost()

@suppress_err begin
    function use_precise_ρ(cap::Intersection{N})::Bool where N<:Real
        return use_precise_ρ(discrete_post_operator, cap)
    end
end

end # module
