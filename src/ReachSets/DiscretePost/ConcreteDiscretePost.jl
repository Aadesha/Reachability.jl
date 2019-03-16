export ConcreteDiscretePost

"""
    ConcreteDiscretePost <: DiscretePost

Textbook implementation of a discrete post operator, using concrete polyhedra
intersections.

### Fields

- `options` -- an `Options` structure that holds the algorithm-specific options

### Notes

This operator requires that the `Polyhedra` library is loaded,
because some concrete operations between polytopes are used.

Currently, we assume that source invariants, target invariants and guards are
polytopes in constraint representation resp. half-spaces.

### Algorithm

The algorithm is based on [Flowpipe-Guard Intersection for Reachability
Computations with Support Functions](http://spaceex.imag.fr/sites/default/files/frehser_adhs2012.pdf).
"""
struct ConcreteDiscretePost <: DiscretePost
    options::Options

    function ConcreteDiscretePost(𝑂::Options)
        𝑂copy = copy(𝑂)
        check_aliases_and_add_default_value!(𝑂.dict, 𝑂copy.dict, [:check_invariant_intersection], false)
        check_aliases_and_add_default_value!(𝑂.dict, 𝑂copy.dict, [:overapproximation], Hyperrectangle)
        return new(𝑂copy)
    end
end

# convenience constructor from pairs of symbols
ConcreteDiscretePost(𝑂::Pair{Symbol,<:Any}...) = ConcreteDiscretePost(Options(Dict{Symbol,Any}(𝑂)))

# default options for the LazyDiscretePost discrete post operator
ConcreteDiscretePost() = ConcreteDiscretePost(Options())

init(𝒫::ConcreteDiscretePost, 𝒮::AbstractSystem, 𝑂::Options) = init!(𝒫, 𝒮, copy(𝑂))

function init!(𝒫::ConcreteDiscretePost, 𝒮::AbstractSystem, 𝑂::Options)
    @assert isdefined(Main, :Polyhedra) "this algorithm needs the package " *
            "'Polyhedra' to be loaded"

    𝑂.dict[:n] = statedim(𝒮, 1)

    # solver-specific options (adds default values for unspecified options)
    𝑂out = validate_solver_options_and_add_default_values!(𝑂)

    return 𝑂out
end

function tube⋂inv!(𝒫::ConcreteDiscretePost,
                   reach_tube::Vector{<:ReachSet{<:LazySet{N}}},
                   invariant,
                   Rsets,
                   start_interval
                  ) where {N}
    # take intersection with source invariant

    # TODO First check for empty intersection, which can be more efficient.
    #      However, we need to make sure that the emptiness check does not just
    #      compute the concrete intersection; otherwise, we would do the work
    #      twice. This is currently the case for 'Polyhedra' polytopes.

    # counts the number of sets R⋂I added to Rsets
    count = 0
    for reach_set in reach_tube
        rs = reach_set.X
        @assert rs isa CartesianProductArray
        if length(array(rs)) == 1
            # TODO workaround for lazy X0
            rs_converted = Approximations.overapproximate(rs,
                Approximations.BoxDirections(dim(rs)))
        else
            rs_converted = HPolytope(constraints_list(rs))
        end
        R⋂I = intersection(invariant, rs_converted)
        if 𝒫.options[:check_invariant_intersection] && isempty(R⋂I)
            break
        end
        push!(Rsets, ReachSet{LazySet{N}, N}(R⋂I,
            reach_set.t_start + start_interval[1],
            reach_set.t_end + start_interval[2]))
        count = count + 1
    end

    return count
end

function post(𝒫::ConcreteDiscretePost,
              HS::HybridSystem,
              waiting_list::Vector{Tuple{Int, ReachSet{LazySet{N}, N}, Int}},
              passed_list,
              source_loc_id,
              tube⋂inv,
              count_Rsets,
              jumps,
              options
             ) where {N}
    jumps += 1
    for trans in out_transitions(HS, source_loc_id)
        info("Considering transition: $trans")
        target_loc_id = target(HS, trans)
        target_loc = HS.modes[target(HS, trans)]
        target_invariant = target_loc.X
        constrained_map = resetmap(HS, trans)
        guard = stateset(constrained_map)

        # perform jumps
        post_jump = Vector{ReachSet{LazySet{N}, N}}()
        sizehint!(post_jump, count_Rsets)
        for reach_set in tube⋂inv[length(tube⋂inv) - count_Rsets + 1 : end]
            # check intersection with guard
            R⋂G = intersection(guard, HPolytope(constraints_list(reach_set.X)))
            if isempty(R⋂G)
                continue
            end

            # apply assignment
            A⌜R⋂G⌟ = apply_assignment(𝒫, constrained_map, R⋂G)

            # intersect with target invariant
            A⌜R⋂G⌟⋂I = intersection(target_invariant, A⌜R⋂G⌟)
            if isempty(A⌜R⋂G⌟⋂I)
                continue
            end

            # store result
            push!(post_jump, ReachSet{LazySet{N}, N}(A⌜R⋂G⌟⋂I,
                                                     reach_set.t_start,
                                                     reach_set.t_end))
        end

        postprocess(𝒫, HS, post_jump, options, waiting_list, passed_list,
            target_loc_id, jumps)
    end
end

# --- handling assignments ---

function apply_assignment(𝒫::ConcreteDiscretePost,
                          constrained_map::ConstrainedLinearMap,
                          R⋂G::LazySet;
                          kwargs...)
    return linear_map(constrained_map.A, R⋂G)
end

function apply_assignment(𝒫::ConcreteDiscretePost,
                          constrained_map::ConstrainedResetMap,
                          R⋂G::LazySet;
                          kwargs...)
    old_c = constraints_list(R⋂G)
    new_c = Vector{eltype(old_c)}()
    sizehint!(new_c, length(old_c))
    resets = constrained_map.dict
    reset_dimensions = [k for k in keys(resets)]
    for (i, c) in enumerate(old_c)
        # find out if all or none of the constrained dimensions are reset
        # 0: unknown
        # 1: no constrained dims are reset
        # 2: only constrained dims are reset
        # 3: mixture
        status = 0
        for d in constrained_dimensions(c)
            if d in reset_dimensions
                if status == 1
                    status = 3
                    break
                else
                    status = 2
                end
            else
                if status == 2
                    status = 3
                    break
                else
                    status = 1
                end
            end
        end

        if status == 1
            # use old constraint
            push!(new_c, c)
        elseif status == 2
            # add new equality constraints
            for d in constrained_dimensions(c)
                hyperplane = Hyperplane(sparsevec([d], [1.]), resets[d])
                append!(new_c, constraints_list(hyperplane))
            end
        elseif status == 3
            # fall back to default implementation
            new_c = constraints_list(LazySets.ResetMap(R⋂G, resets))
            break
        else
            # no constrained dimension at all -> keep this constraint
            push!(new_c, c)
        end
    end
    return HPolytope(new_c)
end
