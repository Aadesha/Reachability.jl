#=
    reach_blocks!(ϕ, Xhat0, U, n, b, N, overapproximate, blocks, res)

Reachability computation of a given number of two-dimensional blocks of an
affine system with undeterministic inputs.

The variants have the following structure:

INPUT:

- `ϕ` -- sparse matrix of a discrete affine system
- `Xhat0` -- initial set as a cartesian product over 2d blocks
- `U` -- input set of undeterministic inputs
- `n` -- ambient dimension
- `N` -- number of sets computed
- `overapproximate` -- function for overapproximation
- `blocks` -- the block indices to be computed
- `partition` -- the partition into blocks
- `res` -- storage space for the result, a linear array of CartesianProductArray

OUTPUT:

Array of the cartesian product of two-dimensional sets for the given block
indices, and ZeroSet's for the rest of them.
It is obtained by reachability computation of a discrete affine system with
nondeterministic inputs.
=#

# helper function
@inline G0(bi::AbstractVector{Int}, n::Int) =
        sparse(1:length(bi), bi, ones(length(bi)), length(bi), n)

# sparse, with input
function reach_blocks!(ϕ::SparseMatrixCSC{NUM, Int},
                                Xhat0::Vector{<:LazySet{NUM}},
                                U::ConstantNonDeterministicInput,
                                overapproximate::Function,
                                n::Int,
                                N::Int,
                                blocks::AbstractVector{Int},
                                partition::AbstractVector{<:AbstractVector{Int}},
                                res::Vector{CartesianProductArray{NUM}}
                               )::Void where {NUM}
    res[1] = CartesianProductArray(Xhat0[blocks])
    if N == 1
        return nothing
    end

    b = length(blocks)
    Xhatk = Vector{LazySet{NUM}}(b)
    Whatk = Vector{LazySet{NUM}}(b)

    inputs = next_set(U)
    @inbounds for i in 1:b
        bi = partition[blocks[i]]
        Whatk[i] = overapproximate(blocks[i], G0(bi, n) * inputs)
    end
    ϕpowerk = copy(ϕ)

    k = 2
    @inbounds while true
        for i in 1:b
            bi = partition[blocks[i]]
            Xhatk_bi = ZeroSet(length(bi))
            for (j, bj) in enumerate(partition)
                if findfirst(ϕpowerk[bi, bj]) != 0
                    Xhatk_bi = Xhatk_bi + ϕpowerk[bi, bj] * Xhat0[j]
                end
            end
            Xhatk[i] = overapproximate(blocks[i], Xhatk_bi + Whatk[i])
        end
        res[k] = CartesianProductArray(copy(Xhatk))

        if k == N
            break
        end

        for i in 1:b
            bi = partition[blocks[i]]
            Whatk[i] =
                overapproximate(blocks[i], Whatk[i] + ϕpowerk[bi, :] * inputs)
        end
        ϕpowerk = ϕpowerk * ϕ
        k += 1
    end

    return nothing
end


# sparse, no input
function reach_blocks!(ϕ::SparseMatrixCSC{NUM, Int},
                                Xhat0::Vector{<:LazySet{NUM}},
                                overapproximate::Function,
                                n::Int,
                                N::Int,
                                blocks::AbstractVector{Int},
                                partition::AbstractVector{<:AbstractVector{Int}},
                                res::Vector{CartesianProductArray{NUM}}
                               )::Void where {NUM}
    res[1] = CartesianProductArray(Xhat0[blocks])
    if N == 1
        return nothing
    end

    b = length(blocks)
    Xhatk = Vector{LazySet{NUM}}(b)

    ϕpowerk = copy(ϕ)

    k = 2
    @inbounds while true
        for i in 1:b
            bi = partition[blocks[i]]
            Xhatk_bi = ZeroSet(length(bi))
            for (j, bj) in enumerate(partition)
                if findfirst(ϕpowerk[bi, bj]) != 0
                    Xhatk_bi = Xhatk_bi + ϕpowerk[bi, bj] * Xhat0[j]
                end
            end
            Xhatk[i] = overapproximate(blocks[i], Xhatk_bi)
        end
        res[k] = CartesianProductArray(copy(Xhatk))

        if k == N
            break
        end

        ϕpowerk = ϕpowerk * ϕ
        k += 1
    end

    return nothing
end


# dense, with input
function reach_blocks!(ϕ::AbstractMatrix{NUM},
                                Xhat0::Vector{<:LazySet{NUM}},
                                U::ConstantNonDeterministicInput,
                                overapproximate::Function,
                                n::Int,
                                N::Int,
                                blocks::AbstractVector{Int},
                                partition::AbstractVector{<:AbstractVector{Int}},
                                res::Vector{CartesianProductArray{NUM}}
                               )::Void where {NUM}
    res[1] = CartesianProductArray(Xhat0[blocks])
    if N == 1
        return nothing
    end

    b = length(blocks)
    Xhatk = Vector{LazySet{NUM}}(b)
    Whatk = Vector{LazySet{NUM}}(b)

    inputs = next_set(U)
    @inbounds for i in 1:b
        bi = partition[blocks[i]]
        Whatk[i] = overapproximate(blocks[i], G0(bi, n) * inputs)
    end
    ϕpowerk = copy(ϕ)

    arr_length = length(partition) + 1
    arr = Vector{LazySet{NUM}}(arr_length)
    k = 2
    @inbounds while true
        for i in 1:b
            bi = partition[blocks[i]]
            for (j, bj) in enumerate(partition)
                arr[j] = ϕpowerk[bi, bj] * Xhat0[j]
            end
            arr[arr_length] = Whatk[i]
            Xhatk[i] = overapproximate(blocks[i], MinkowskiSumArray(arr))
        end
        res[k] = CartesianProductArray(copy(Xhatk))

        if k == N
            break
        end

        for i in 1:b
            bi = partition[blocks[i]]
            Whatk[i] =
                overapproximate(blocks[i], Whatk[i] + ϕpowerk[bi, :] * inputs)
        end
        ϕpowerk = ϕpowerk * ϕ
        k += 1
    end

    return nothing
end


# dense, no input
function reach_blocks!(ϕ::AbstractMatrix{NUM},
                                Xhat0::Vector{<:LazySet{NUM}},
                                overapproximate::Function,
                                n::Int,
                                N::Int,
                                blocks::AbstractVector{Int},
                                partition::AbstractVector{<:AbstractVector{Int}},
                                res::Vector{CartesianProductArray{NUM}}
                               )::Void where {NUM}
    res[1] = CartesianProductArray(Xhat0[blocks])
    if N == 1
        return nothing
    end

    b = length(blocks)
    Xhatk = Vector{LazySet{NUM}}(b)

    ϕpowerk = copy(ϕ)

    arr = Vector{LazySet{NUM}}(length(partition))
    k = 2
    @inbounds while true
        for i in 1:b
            bi = partition[blocks[i]]
            for (j, bj) in enumerate(partition)
                arr[j] = ϕpowerk[bi, bj] * Xhat0[j]
            end
            Xhatk[i] = overapproximate(blocks[i], MinkowskiSumArray(arr))
        end
        res[k] = CartesianProductArray(copy(Xhatk))

        if k == N
            break
        end

        ϕpowerk = ϕpowerk * ϕ
        k += 1
    end

    return nothing
end


# lazymexp, no input
function reach_blocks!(ϕ::SparseMatrixExp{NUM},
                                Xhat0::Vector{<:LazySet{NUM}},
                                overapproximate::Function,
                                n::Int,
                                N::Int,
                                blocks::AbstractVector{Int},
                                partition::AbstractVector{<:AbstractVector{Int}},
                                res::Vector{CartesianProductArray{NUM}}
                               )::Void where {NUM}
    res[1] = CartesianProductArray(Xhat0[blocks])
    if N == 1
        return nothing
    end

    b = length(blocks)
    Xhatk = Vector{LazySet{NUM}}(b)

    ϕpowerk = SparseMatrixExp(ϕ.M)

    k = 2
    @inbounds while true
        for i in 1:b
            bi = partition[blocks[i]]
            ϕpowerk_πbi = get_rows(ϕpowerk, bi)
            Xhatk_bi = ZeroSet(length(bi))
            for (j, bj) in enumerate(partition)
                πbi = ϕpowerk_πbi[:, bj]
                if findfirst(πbi) != 0
                    Xhatk_bi = Xhatk_bi + πbi * Xhat0[j]
                end
            end
            Xhatk[i] = overapproximate(blocks[i], Xhatk_bi)
        end
        res[k] = CartesianProductArray(copy(Xhatk))

        if k == N
            break
        end

        ϕpowerk.M .= ϕpowerk.M + ϕ.M
        k += 1
    end

    return nothing
end


# lazymexp, with input
function reach_blocks!(ϕ::SparseMatrixExp{NUM},
                                Xhat0::Vector{<:LazySet{NUM}},
                                U::ConstantNonDeterministicInput,
                                overapproximate::Function,
                                n::Int,
                                N::Int,
                                blocks::AbstractVector{Int},
                                partition::AbstractVector{<:AbstractVector{Int}},
                                res::Vector{CartesianProductArray{NUM}}
                               )::Void where {NUM}
    res[1] = CartesianProductArray(Xhat0[blocks])
    if N == 1
        return nothing
    end

    b = length(blocks)
    Xhatk = Vector{LazySet{NUM}}(b)
    Whatk = Vector{LazySet{NUM}}(b)

    inputs = next_set(U)
    @inbounds for i in 1:b
        bi = partition[blocks[i]]
        Whatk[i] = overapproximate(blocks[i], G0(bi, n) * inputs)
    end
    ϕpowerk = SparseMatrixExp(ϕ.M)

    k = 2
    @inbounds while true
        for i in 1:b
            bi = partition[blocks[i]]
            ϕpowerk_πbi = get_rows(ϕpowerk, bi)
            Xhatk_bi = ZeroSet(length(bi))
            for (j, bj) in enumerate(partition)
                πbi = ϕpowerk_πbi[:, bj]
                if findfirst(πbi) != 0
                    Xhatk_bi = Xhatk_bi + πbi * Xhat0[j]
                end
            end
            Xhatk[i] = overapproximate(blocks[i], Xhatk_bi + Whatk[i])
            Whatk[i] =
                overapproximate(blocks[i], Whatk[i] + ϕpowerk_πbi * inputs)
        end
        res[k] = CartesianProductArray(copy(Xhatk))

        if k == N
            break
        end

        ϕpowerk.M .= ϕpowerk.M + ϕ.M
        k += 1
    end

    return nothing
end