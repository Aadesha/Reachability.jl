"""
    Clause{N<:Real}

Type that represents a disjunction of linear constraints.

### Fields

- `atoms` -- a vector of linear constraints
"""
struct Clause{N<:Real}
    atoms::AbstractVector{LinearConstraint{N}}
end
# constructor from a single atom
Clause(atom::LinearConstraint{N}) where {N<:Real} = Clause{N}([atom])

"""
    LinearConstraintProperty{N<:Real} <: Property

Type that represents a property consisting of a Boolean function of linear
constraints.
The function is given in CNF (conjunctive normal form), i.e., a conjunction of
disjunctions of linear constraints.

### Fields

- `clauses` -- a vector of `Clause` objects
"""
struct LinearConstraintProperty{N<:Real} <: Property
    clauses::AbstractVector{Clause{N}}
end
# constructor from a single clause
LinearConstraintProperty(clause::Clause{N}) where {N<:Real} =
    LinearConstraintProperty{N}([clause])
# constructor from a single constraint
LinearConstraintProperty(linConst::LinearConstraint{N}) where {N<:Real} =
    LinearConstraintProperty{N}([Clause(linConst)])
# constructor from a single constraint in raw form ax+b
LinearConstraintProperty(linComb::AbstractVector{N}, bound::N) where {N<:Real} =
    LinearConstraintProperty{N}([Clause(LinearConstraint{N}(linComb, bound))])

"""
    check(prop::LinearConstraintProperty, set::LazySet)::Bool

Checks whether a convex set satisfies a property of linear constraints.

### Input

- `prop` -- property of linear constraints
- `set`  -- convex set

### Output

`true` iff the convex set satisfies the property of linear constraints.
"""
@inline function check(prop::LinearConstraintProperty, set::LazySet)::Bool
    @assert (length(prop.clauses) > 0) "empty properties are not allowed"
    for clause in prop.clauses
        @assert (length(clause.atoms) > 0) "empty clauses are not allowed"
        clause_sat = false
        for atom in clause.atoms
            if ρ(atom.a, set) < atom.b
                clause_sat = true
                break
            end
        end
        if !clause_sat
            return false
        end
    end
    return true
end
