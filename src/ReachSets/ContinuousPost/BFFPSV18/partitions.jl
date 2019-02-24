"""
    inout_map_property(𝑃::PROPERTY,
                       partition::AbstractVector{<:AbstractVector{Int}},
                       blocks::AbstractVector{Int},
                       n::Int
                      )::PROPERTY where {PROPERTY<:Property}

Map a property to the dimensions of analyzed blocks.

### Input

- `𝑃`         -- property
- `partition` -- block partition; elements are start and end indices of a block
- `blocks`    -- list of all output block indices in the partition
- `n`         -- total number of input dimensions

### Output

A new property of reduced dimension.

### Notes

If the dimension is not reduced, we return the original property.
Otherwise, the dimension reduction is implemented via a (lazy) `LinearMap`.
"""
function inout_map_property(𝑃::PROPERTY,
                            partition::AbstractVector{<:AbstractVector{Int}},
                            blocks::AbstractVector{Int},
                            n::Int
                           )::PROPERTY where {PROPERTY<:Property}
    proj = projection_map(partition, blocks)
    if length(proj) == n
        # no change in the dimension, return the original property
        return 𝑃
    else
        M = sparse(proj, proj, ones(length(proj)), n, n)
        return inout_map_property_helper(𝑃, M)
    end
end

function inout_map_property_helper(𝑃::Conjunction, M::AbstractMatrix)
    new_conjuncts = similar(𝑃.conjuncts)
    for (i, conjunct) in enumerate(𝑃.conjuncts)
        new_conjuncts[i] = inout_map_property_helper(conjunct, M)
    end
    return Conjunction(new_conjuncts)
end

function inout_map_property_helper(𝑃::Disjunction, M::AbstractMatrix)
    new_disjuncts = similar(𝑃.disjuncts)
    for (i, disjunct) in enumerate(𝑃.disjuncts)
        new_disjuncts[i] = inout_map_property_helper(disjunct, M)
    end
    return Disjunction(new_disjuncts)
end

function inout_map_property_helper(𝑃::IntersectionProperty, M::AbstractMatrix)
    @assert dim(𝑃.bad) == size(M, 2) "the property has dimension " *
        "$(dim(𝑃.bad)) but should have dimension $(size(M, 2))"
    return IntersectionProperty(M * 𝑃.bad)
end

function inout_map_property_helper(𝑃::SubsetProperty, M::AbstractMatrix)
    @assert dim(𝑃.safe) == size(M, 2) "the property has dimension " *
        "$(dim(𝑃.safe)) but should have dimension $(size(M, 2))"
    return SubsetProperty(M * 𝑃.safe)
end

"""
    inout_map_property(𝑃::LinearConstraintProperty{N},
                       partition::AbstractVector{<:AbstractVector{Int}},
                       blocks::AbstractVector{Int},
                       n::Int
                      )::LinearConstraintProperty{N} where {N<:Real}

Map a `LinearConstraintProperty` to the dimensions of analyzed blocks.

### Input

- `𝑃`         -- property
- `partition` -- block partition; elements are start and end indices of a block
- `blocks`    -- list of all output block indices in the partition
- `n`         -- total number of input dimensions

### Output

A new property of reduced dimension.
"""
function inout_map_property(𝑃::LinearConstraintProperty{N},
                            partition::AbstractVector{<:AbstractVector{Int}},
                            blocks::AbstractVector{Int},
                            n::Int
                           )::LinearConstraintProperty{N} where {N<:Real}
    # sanity check: do not project away non-zero dimensions
    function check_projection(a, proj)
        p = 1
        for i in 1:length(a)
            if p <= length(proj) && i == proj[p]
                # dimension is not projected away
                p += 1
            elseif a[i] != 0
                # dimension is projected away; entry is non-zero
                return false
            end
        end
        return true
    end

    @assert dim(𝑃.clauses[1].atoms[1]) == n "the property has dimension $(dim(𝑃.clauses[1].atoms[1])) but should have dimension $n"

    proj = projection_map(partition, blocks)

    # create modified property
    clauses = Vector{Clause{N}}(undef, length(𝑃.clauses))
    for (ic, c) in enumerate(𝑃.clauses)
        atoms = Vector{LinearConstraint{N}}(undef, length(c.atoms))
        for (ia, atom) in enumerate(c.atoms)
            @assert check_projection(atom.a, proj) "blocks incompatible with property"
            atoms[ia] = LinearConstraint{N}(atom.a[proj], atom.b)
        end
        clauses[ic] = Clause(atoms)
    end
    return LinearConstraintProperty(clauses)
end

"""
    projection_map(partition::AbstractVector{<:AbstractVector{Int}},
                   blocks::AbstractVector{Int}
                  )::Vector{Int}

Create a sorted list of all dimensions in `blocks`.

### Input

- `partition` -- block partition; elements are start and end indices of a block
- `blocks`    -- list of all output block indices in the partition

### Output

A sorted list containing all output dimensions.
"""
function projection_map(partition::AbstractVector{<:AbstractVector{Int}},
                        blocks::AbstractVector{Int}
                       )::Vector{Int}
    proj = Vector{Int}()
    for bi in blocks
        for i in partition[bi]
            push!(proj, i)
        end
    end
    return proj
end
