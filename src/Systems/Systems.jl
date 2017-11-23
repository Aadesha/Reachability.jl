__precompile__()
"""
Module to handle systems of affine ODEs with nondeterministic inputs.
"""
module Systems

using LazySets

export AbstractSystem,
       ContinuousSystem,
       DiscreteSystem,
       NonDeterministicInput,
       ConstantNonDeterministicInput,
       TimeVaryingNonDeterministicInput,
       get_set

import Base: *

#=
Nondeterministic inputs
=#


"""
Abstract type representing a nondeterministic input. The input can be either
constant or time-varying. In both cases it is represented by an iterator.
"""
abstract type NonDeterministicInput end

Base.start(::NonDeterministicInput) = 1
Base.eltype(::Type{NonDeterministicInput}) = LazySet


"""
    ConstantNonDeterministicInput <: NonDeterministicInput

Type that represents a constant nondeterministic input.

The iteration over this set is such that its `state` is a tuple
(`set`, `index`), where `set` is the value of the input, represented as a
`LazySet`, and `index` counts the number of times this iterator was called. Its
length is infinite, since the input is defined for all times. The index of the
input state is always constantly 1.

### Fields

- `U` -- `LazySet`

### Examples

`ConstantNonDeterministicInput(U::LazySet)` -- default constructor
"""
struct ConstantNonDeterministicInput <: NonDeterministicInput
    # input
    U::LazySet
end

Base.next(inputs::ConstantNonDeterministicInput, state) = (inputs.U, state + 1)
Base.done(inputs::ConstantNonDeterministicInput, state) = state > 1
Base.length(inputs::ConstantNonDeterministicInput) = 1
get_set(inputs::ConstantNonDeterministicInput, index::Int64) = inputs.U
# convenience function with no index
get_set(inputs::ConstantNonDeterministicInput) = inputs.U


function *(M::AbstractMatrix{<:Real}, input::ConstantNonDeterministicInput)
    return ConstantNonDeterministicInput(M * input.U)
end


"""
    TimeVaryingNonDeterministicInput <: NonDeterministicInput

Type that represents a time-varying nondeterministic input.

The iteration over this set is such that its `state` is a tuple
(`set`, `index`), where `set` is the value of the input, represented as an array
of `LazySet`s, and `index` counts the number of times this iterator was called.
Its length corresponds to the number of elements in the given array. The index
of the input state increases from 1 and corresponds at each time to the array
index in the input array.

### Fields

- `U` -- array containing `LazySet`s

### Examples

`TimeVaryingNonDeterministicInput(U::Vector{<:LazySet})` -- constructor from a
vector of sets
"""
struct TimeVaryingNonDeterministicInput <: NonDeterministicInput
    # input sequence
    U::Vector{<:LazySet}
end

Base.next(inputs::TimeVaryingNonDeterministicInput, state) =
    (inputs.U[state.index], state + 1)
Base.done(inputs::TimeVaryingNonDeterministicInput, state) =
    (state > length(inputs.U))
Base.length(inputs::TimeVaryingNonDeterministicInput) = length(inputs.U)
get_set(inputs::TimeVaryingNonDeterministicInput, index::Int64) =
    inputs.U[index]


#=
Systems
=#


"""
Abstract type representing a system of affine ODEs.
"""
abstract type AbstractSystem end


"""
    ContinuousSystem <: AbstractSystem

Type that represents a system of continuous-time affine ODEs with
nondeterministic inputs,

``x'(t) = Ax(t) + u(t)``,

where:

- ``A`` is a square matrix
- ``x(0) ∈ \\mathcal{X}_0`` and ``\\mathcal{X}_0`` is a convex set
- ``u(t) ∈ \\mathcal{U}(t)``, where ``\\mathcal{U}(\\cdot)`` is a
  piecewise-constant set-valued function, i.e. we consider that it can be
  approximated by a possibly time-varying discrete sequence
  ``\\{\\mathcal{U}_k \\}_k``

### Fields

- `A`  -- square matrix
- `X0` -- set of initial states
- `U`  -- nondeterministic inputs

### Examples

- `ContinuousSystem(A::AbstractMatrix{Float64},
                    X0::LazySet,
                    U::NonDeterministicInput)` -- default constructor
- `ContinuousSystem(A::AbstractMatrix{Float64},
                    X0::LazySet)` -- constructor with no inputs
- `ContinuousSystem(A::AbstractMatrix{Float64},
                    X0::LazySet,
                    U::LazySet)` -- constructor that creates a
  `ConstantNonDeterministicInput`
- `ContinuousSystem(A::AbstractMatrix{Float64},
                    X0::LazySet,
                    U::Vector{<:LazySet})` -- constructor that creates a
  `TimeVaryingNonDeterministicInput`
"""
struct ContinuousSystem <: AbstractSystem
    # system's matrix
    A::AbstractMatrix{Float64}
    # initial states
    X0::LazySet
    # nondeterministic inputs
    U::NonDeterministicInput

    # default constructor
    ContinuousSystem(A::AbstractMatrix{Float64},
                     X0::LazySet,
                     U::NonDeterministicInput) =
        new(A, X0, U)
end
# constructor with no inputs
ContinuousSystem(A::AbstractMatrix{Float64},
                 X0::LazySet) =
    ContinuousSystem(A, X0, ConstantNonDeterministicInput(VoidSet(size(A, 1))))

# constructor that creates a ConstantNonDeterministicInput
ContinuousSystem(A::AbstractMatrix{Float64},
                 X0::LazySet,
                 U::LazySet) =
    ContinuousSystem(A, X0, ConstantNonDeterministicInput(U))

# constructor that creates a TimeVaryingNonDeterministicInput
ContinuousSystem(A::AbstractMatrix{Float64},
                 X0::LazySet,
                 U::Vector{<:LazySet}) =
    ContinuousSystem(A, X0, TimeVaryingNonDeterministicInput(U))


"""
    dim(S)

Dimension of a continuous system.

### Input

- `S` -- continuous system

### Output

The dimension of the system.
"""
function dim(S::ContinuousSystem)
    return size(S.A, 1)
end


"""
    DiscreteSystem <: AbstractSystem

Type that represents a system of discrete-time affine ODEs with nondeterministic
inputs,

``x_{k+1} = A x_{k} + u_{k}``

where:

- ``A`` is a square matrix
- ``x(0) ∈ \\mathcal{X}_0`` and ``\\mathcal{X}_0`` is a convex set
- ``u_{k} ∈ \\mathcal{U}_{k}``, where ``\\{\\mathcal{U}_{k}\\}_k`` is a
  set-valued sequence defined over ``[0, δ], ..., [(N-1)δ, N δ]`` for some
  ``δ>0``

### Fields

- `A`  -- square matrix, possibly of type `SparseMatrixExp`
- `X0` -- set of initial states
- `U`  -- nondeterministic inputs
- `δ`  -- discretization step

### Examples

- `DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
                   X0::LazySet,
                   δ::Float64,
                   U::NonDeterministicInput)` -- default constructor
- `DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
               X0::LazySet,
               δ::Float64)` -- constructor with no inputs
- `DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
               X0::LazySet,
               δ::Float64,
               U::LazySet)` -- constructor that creates a
  `ConstantNonDeterministicInput`
- `DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
               X0::LazySet,
               δ::Float64,
               U::Vector{<:LazySet})` -- constructor that creates a
  `TimeVaryingNonDeterministicInput`
"""
struct DiscreteSystem <: AbstractSystem
    # system's matrix
    A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}}
    # initial states
    X0::LazySet
    # nondeterministic inputs
    U::NonDeterministicInput
    # discretization step
    δ::Float64

    # default constructor that checks for nonnegative δ
    DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
                   X0::LazySet,
                   δ::Float64,
                   U::NonDeterministicInput) =
        (δ < 0.
         ? throw(DomainError())
         : new(A, X0, U, δ))
end

# constructor with no inputs
DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
               X0::LazySet,
               δ::Float64) =
    DiscreteSystem(A, X0, δ, ConstantNonDeterministicInput(VoidSet(size(A, 1))))

# constructor that creates a ConstantNonDeterministicInput
DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
               X0::LazySet,
               δ::Float64,
               U::LazySet) =
    DiscreteSystem(A, X0, δ, ConstantNonDeterministicInput(U))

# constructor that creates a TimeVaryingNonDeterministicInput
DiscreteSystem(A::Union{AbstractMatrix{Float64}, SparseMatrixExp{Float64}},
               X0::LazySet,
               δ::Float64,
               U::Vector{<:LazySet}) =
    DiscreteSystem(A, X0, δ, TimeVaryingNonDeterministicInput(U))


"""
    dim(S)

Dimension of a discrete system.

### Input

- `S` -- discrete system

### Output

The dimension of the system.
"""
function dim(S::DiscreteSystem)
    return size(S.A, 1)
end

end  # module
