export LazyLowDimDiscretePost,
       ApproximatingDiscretePost

import LazySets.use_precise_ρ

"""
    LazyLowDimDiscretePost <: DiscretePost

Textbook implementation of a discrete post operator, but with lazy intersections.

### Fields

- `options` -- an `Options` structure that holds the algorithm-specific options

### Algorithm

The algorithm is based on [Flowpipe-Guard Intersection for Reachability
Computations with Support Functions](http://spaceex.imag.fr/sites/default/files/frehser_adhs2012.pdf).
"""
struct LazyLowDimDiscretePost <: DiscretePost
    options::Options

    function LazyLowDimDiscretePost(𝑂::Options)
        𝑂copy = copy(𝑂)
        # TODO: pass 𝑂 directly?
        check_aliases_and_add_default_value!(𝑂.dict, 𝑂copy.dict, [:check_invariant_intersection], false)
        check_aliases_and_add_default_value!(𝑂.dict, 𝑂copy.dict, [:overapproximation], Hyperrectangle)
        check_aliases_and_add_default_value!(𝑂.dict, 𝑂copy.dict, [:lazy_R⋂I], false)
        check_aliases_and_add_default_value!(𝑂.dict, 𝑂copy.dict, [:lazy_R⋂G], true)
        check_aliases_and_add_default_value!(𝑂.dict, 𝑂copy.dict, [:lazy_A⌜R⋂G⌟⋂I], true)
        return new(𝑂copy)
    end
end

# convenience constructor from pairs of symbols
LazyLowDimDiscretePost(𝑂::Pair{Symbol,<:Any}...) = LazyLowDimDiscretePost(Options(Dict{Symbol,Any}(𝑂)))

# default options for the LazyLowDimDiscretePost discrete post operator
LazyLowDimDiscretePost() = LazyLowDimDiscretePost(Options())

"""
    ApproximatingDiscretePost()

Textbook implementation of a discrete post operator, but with lazy intersections
followed by an overapproximation. This is a particular case of the
`LazyLowDimDiscretePost`.
"""
function ApproximatingDiscretePost()
    return LazyLowDimDiscretePost(:check_invariant_intersection=>false,
                            :overapproximation=>Hyperrectangle,
                            :lazy_R⋂I=>false,
                            :lazy_R⋂G=>false,
                            :lazy_A⌜R⋂G⌟⋂I=>false)
end

function ApproximatingDiscretePost(𝑂::Options)
    𝑂_default = Options(:lazy_R⋂I=>false,
                        :lazy_R⋂G=>false,
                        :lazy_A⌜R⋂G⌟⋂I=>false)
    merge!(𝑂_default, 𝑂)
    LazyLowDimDiscretePost(𝑂_default)
end

init(𝒫::LazyLowDimDiscretePost, 𝒮::AbstractSystem, 𝑂::Options) = init!(𝒫, 𝒮, copy(𝑂))

# TODO: use 𝑂 only?
function init!(𝒫::LazyLowDimDiscretePost, 𝒮::AbstractSystem, 𝑂::Options)
    𝑂[:n] = statedim(𝒮, 1)

    # solver-specific options (adds default values for unspecified options)
    𝑂out = validate_solver_options_and_add_default_values!(𝑂)

    # Input -> Output variable mapping
    𝑂out[:inout_map] = inout_map_reach(𝑂out[:partition], 𝑂out[:blocks], 𝑂out[:n])

    return 𝑂out
end

function tube⋂inv!(𝒫::LazyLowDimDiscretePost,
                   reach_tube::Vector{<:ReachSet{<:LazySet{N}}},
                   low_reach_tube::Vector{<:ReachSet{<:LazySet{N}}},
                   invariant,
                   Rsets,
                   low_temp_sets,
                   start_interval,
                   nonzero_vars
                  ) where {N}

    # TODO dirs = get_overapproximation_option(op, dim(invariant)) ?
    dirs = 𝒫.options[:overapproximation]

    # counts the number of sets R⋂I added to Rsets
    count = 0
    @inbounds for i = 1:length(low_reach_tube)
        invariant_proj = LazySets.Approximations.project(invariant, nonzero_vars, LinearMap)
        low_dim_reach_inter = overapproximate(invariant_proj ∩ low_reach_tube[i].X, dirs)
        if !isempty(low_dim_reach_inter)
            reach_set = reach_tube[i]
            R⋂I = Intersection(reach_set.X, invariant)
            if 𝒫.options[:check_invariant_intersection] && isempty(R⋂I)
                break
            end
            if !𝒫.options[:lazy_R⋂I]
                R⋂I = overapproximate(R⋂I, dirs)
            end
            push!(Rsets, ReachSet{LazySet{N}, N}(R⋂I,
                reach_set.t_start + start_interval[1],
                reach_set.t_end + start_interval[2]))
            push!(low_temp_sets, ReachSet{LazySet{N}, N}(low_dim_reach_inter,
                reach_set.t_start + start_interval[1],
                reach_set.t_end + start_interval[2]))
            count = count + 1
            end
        end
    end

    return count
end

function post(𝒫::LazyLowDimDiscretePost,
              HS::HybridSystem,
              waiting_list::Vector{Tuple{Int, ReachSet{LazySet{N}, N}, Int}},
              passed_list,
              source_loc_id,
              tube⋂inv,
              low_temp_sets,
              count_Rsets,
              jumps,
              nonzero_vars[loc_id]
              options
             ) where {N}
    jumps += 1
    # TODO? dirs = 𝒫.options[:overapproximation]
    dirs = get_overapproximation_option(𝒫, options[:n])
    source_invariant = HS.modes[source_loc_id].X
    inv_isa_Hrep, inv_isa_H_polytope = get_Hrep_info(source_invariant)

    for trans in out_transitions(HS, source_loc_id)
        info("Considering transition: $trans")
        target_loc_id = target(HS, trans)
        target_loc = HS.modes[target(HS, trans)]
        target_invariant = target_loc.X
        trans_annot = HS.resetmaps[symbol(HS, trans)]
        guard = trans_annot.X
        assignment = trans_annot.A

        if inv_isa_Hrep
            guard_isa_Hrep, guard_isa_H_polytope = get_Hrep_info(guard)
        end
        combine_constraints = inv_isa_Hrep && guard_isa_Hrep && 𝒫.options[:lazy_R⋂I]
        if combine_constraints # combine the constraints of invariant and guard
            T = inv_isa_H_polytope || guard_isa_H_polytope ? HPolytope : HPolyhedron
            # TODO: remove redundant constraints => use intersection(..)
            invariant_guard = T([constraints_list(source_invariant);
                                 constraints_list(guard)])
            proj_invariant_guard = LazySets.Approximations.project(invariant_guard, nonzero_vars, LinearMap)

        else
            proj_guard = LazySets.Approximations.project(guard, nonzero_vars, LinearMap)
        end

        # perform jumps
        post_jump = Vector{ReachSet{LazySet{N}, N}}()
        sizehint!(post_jump, count_Rsets)

        #tube⋂inv[length(tube⋂inv) - count_Rsets + 1 : end]
        for i=1:length(low_temp_sets)
            low_reach_set = low_temp_sets[i]
            high_reach_set = tube⋂inv[length(tube⋂inv) - count_Rsets + i]
            # check intersection with guard
            taken_intersection = false
            if combine_constraints
                low_dim_reach_inter = overapproximate(proj_invariant_guard ∩ low_reach_set.X.X, dirs)
                if !isempty(low_dim_reach_inter)
                    R⋂G = Intersection(high_reach_set.X.X, invariant_guard)
                    taken_intersection = true
                end
            end
            if !taken_intersection
                low_dim_reach_inter = overapproximate(proj_guard ∩ low_reach_set.X.X, dirs)
                if !isempty(low_dim_reach_inter)
                    R⋂G = Intersection(reach_set.X, guard)
                end
            end
            if isempty(R⋂G) || isempty(low_dim_reach_inter)
                continue
            end

            # apply assignment
            A⌜R⋂G⌟ = LinearMap(assignment, R⋂G)
            if !𝒫.options[:lazy_R⋂G]
               A⌜R⋂G⌟ = overapproximate(A⌜R⋂G⌟, dirs)
            end

            # intersect with target invariant
            A⌜R⋂G⌟⋂I = Intersection(target_invariant, A⌜R⋂G⌟)

            # check if the final set is empty
            if isempty(A⌜R⋂G⌟⋂I)
                continue
            end

            # overapproximate final set once more
            if !𝒫.options[:lazy_A⌜R⋂G⌟⋂I]
                res = overapproximate(A⌜R⋂G⌟⋂I, dirs)
            else
                res = A⌜R⋂G⌟⋂I
            end

            # store result
            push!(post_jump, ReachSet{LazySet{N}, N}(res,
                                                     reach_set.t_start,
                                                     reach_set.t_end))
        end

        postprocess(𝒫, HS, post_jump, options, waiting_list, passed_list,
            target_loc_id, jumps)
    end
end

function get_Hrep_info(set::LazySet)
    return (false, false)
end

function get_Hrep_info(set::HPolytope)
    return (true, true)
end

function get_Hrep_info(set::HPolyhedron)
    return (true, false)
end

# --- line search policies ---

# usually do not use line search
function use_precise_ρ(𝒫::LazyLowDimDiscretePost,
                       cap::Intersection{N})::Bool where N<:Real
    return false
end

# use line search for the outermost level, which is a LinearMap
function use_precise_ρ(𝒫::LazyLowDimDiscretePost,
                       cap::Intersection{N, <:LinearMap{N}}
                       )::Bool where N<:Real
    return true
end
