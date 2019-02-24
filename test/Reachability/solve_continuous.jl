# ===============================
# Test minimal (default) options
# ===============================

# linear ODE: x' = Ax
A = [ 0.0509836  0.168159  0.95246   0.33644
      0.42377    0.67972   0.129232  0.126662
      0.518654   0.981313  0.489854  0.588326
      0.38318    0.616014  0.518412  0.778765]

# initial set
X0 = BallInf(ones(4), 0.1)

# default options (computes all variables)
s = solve(InitialValueProblem(LinearContinuousSystem(A), X0), :T=>0.1)
@test dim(s.Xk[1].X) == 4

# two variables and custom partition
s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1),
          op=BFFPSV18(:vars=>[1,3], :partition=>[1:2, 3:4]))
@test dim(s.Xk[1].X) == 4

# the default partition is used.
s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1),
          op=BFFPSV18(:vars=>[1,3]))
@test dim(s.Xk[1].X) == 2

# ===============================
# Test projection
# ===============================
s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1, :project_reachset=>false),
          op=BFFPSV18(:vars=>[1,3], :partition=>[1:2, 3:4]))
ps = project(s)

# ===============
# Test check mode
# ===============

A = [ 0.0509836  0.168159  0.95246   0.33644
      0.42377    0.67972   0.129232  0.126662
      0.518654   0.981313  0.489854  0.588326
      0.38318    0.616014  0.518412  0.778765]

# check that x1 + x2 <= 2 doesn't hold
s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1, :mode=>"check",
          :property=>SafeStatesProperty(LinearConstraint([1., 1., 0., 0.], 2.))),
          op=BFFPSV18(:vars=>[1,2,3], :partition=>[1:2, 3:4]))
@test s.violation == 1

# check that x1 - x2 <= 2 holds
s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1, :mode=>"check",
          :property=>SafeStatesProperty(LinearConstraint([1., -1., 0., 0.], 2.))),
          op=BFFPSV18(:vars=>[1,2,3], :partition=>[1:2, 3:4]))
@test s.violation == -1

# ===============================
# Test reachability options
# ===============================

# template directions (eg. :box, :oct, :octbox)
s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1, :ε_proj=>1e-5, :set_type_proj=>HPolygon),
          op=BFFPSV18(:vars=>[1,3], :partition=>[1:4],
                      :template_directions => :oct))

s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1),
          op=BFFPSV18(:vars=>[1,3], :partition=>[1:2, 3:4], :lazy_sih=>true))

s = solve(ContinuousSystem(A, X0),
          Options(:T=>0.1),
          op=BFFPSV18(:vars=>[1,3], :partition=>[1:2, 3:4], :lazy_sih=>false))

s = solve(ContinuousSystem(sparse(A), X0),
          Options(:T=>0.1),
          op=BFFPSV18(:vars=>[1,3], :partition=>[1:2, 3:4], :lazy_expm=>true,
                      :lazy_expm_discretize=>true, :assume_sparse=>false))

s = solve(ContinuousSystem(sparse(A), X0),
          Options(:T=>0.1),
          op=BFFPSV18(:vars=>[1,3], :partition=>[1:2, 3:4], :lazy_expm=>true,
                      :lazy_expm_discretize=>true, :assume_sparse=>true))

# uses Interval for set_type_init and set_type_iter but Hyperrectangle for
# set_type_proj
s = solve(ContinuousSystem(sparse(A), X0),
          Options(:T=>0.1),
          op=BFFPSV18(:vars=>[1,3], :partition=>[[i] for i in 1:4],
                      :lazy_expm=>true, :lazy_expm_discretize=>true,
                      :set_type=>Interval))

# ===============================
# System with an odd dimension
# ===============================
A = randn(5, 5); X0 = BallInf(ones(5), 0.1)
s = solve(ContinuousSystem(A, X0), Options(:T=>0.1),
    op=BFFPSV18(:vars=>[1,3], :partition=>[1:2, 3:4, [5]], :block_types=>
                Dict{Type{<:LazySet}, AbstractVector{<:AbstractVector{Int}}}(
                    HPolygon=>[1:2, 3:4], Interval=>[[5]])))

# ===============================
# System with an odd dimension
# ===============================
A = [1 2 1.; 0 0. 1; -2 1 4]
X0 = BallInf(ones(3), 0.1)
system = ContinuousSystem(A, X0)
s = solve(system, Options(:T=>0.1),
          op=BFFPSV18(:vars=>1:3, :partition=>[1:2, 3:3]))

# =======================================================
# Affine ODE with a nondeterministic input, x' = Ax + Bu
# =======================================================
# linear ODE: x' = Ax + Bu
A = [ 0.0509836  0.168159  0.95246   0.33644
      0.42377    0.67972   0.129232  0.126662
      0.518654   0.981313  0.489854  0.588326
      0.38318    0.616014  0.518412  0.778765]

B = [0.866688  0.771231
    0.065935  0.349839
    0.109643  0.904222
    0.292474  0.227857]

# non-deterministic inputs
U = Interval(0.99, 1.01) × Interval(0.99, 1.01)

# initial set
X0 = BallInf(ones(4), 0.1)

# dense identity matrix
E = Matrix{Float64}(I, size(A))

# instantiate system
Δ = ConstrainedLinearControlContinuousSystem(A, E, nothing, ConstantInput(B*U))
𝒮 = InitialValueProblem(Δ, X0)

# default options (computes all variables)
s = solve(𝒮, :T=>0.1)
