using ITensorGaussianMPS
using LinearAlgebra
using ITensors

# Electrons

# Half filling
N = 50
Nf = N

@show N, Nf

# Maximum MPS link dimension
_maxlinkdim = 200

@show _maxlinkdim

# DMRG cutoff
_cutoff = 1e-8

# Hopping
t = 1.0

# Electron-electron on-site interaction
U = 1.0

@show t, U

# Make the free fermion Hamiltonian for the up spins
ampo_up = AutoMPO()
for n in 1:(N - 1)
  ampo_up .+= -t, "Cdagup", n, "Cup", n + 1
  ampo_up .+= -t, "Cdagup", n + 1, "Cup", n
end

# Make the free fermion Hamiltonian for the down spins
ampo_dn = AutoMPO()
for n in 1:(N - 1)
  ampo_dn .+= -t, "Cdagdn", n, "Cdn", n + 1
  ampo_dn .+= -t, "Cdagdn", n + 1, "Cdn", n
end

# Hopping Hamiltonian with 2*N spinless fermions,
# alternating up and down spins
h = hopping_hamiltonian(ampo_up, ampo_dn)

# Get the Slater determinant
Φ = slater_determinant_matrix(h, Nf)

# Create an MPS from the slater determinant.
# In this example, we will turn off spin conservation (so this would
# work with a Hamiltonian that mixed the up and down spin sectors)
s = siteinds("Electron", N; conserve_qns=true, conserve_sz=false)
println("Making free fermion starting MPS")
@time ψ0 = slater_determinant_to_mps(
  s, Φ; eigval_cutoff=1e-4, cutoff=_cutoff, maxdim=_maxlinkdim
)
@show maxlinkdim(ψ0)

@show U
ampo = ampo_up + ampo_dn
for n in 1:N
  ampo .+= U, "Nupdn", n
end
H = MPO(ampo, s)

# Random starting state
ψr = randomMPS(s, n -> n ≤ Nf ? (isodd(n) ? "↑" : "↓") : "0")

println("Random starting state energy")
@show flux(ψr)
@show inner(ψr, H, ψr)
println()
println("Free fermion starting state energy")
@show flux(ψ0)
@show inner(ψ0, H, ψ0)

println("\nStart from product state")
sweeps = Sweeps(10)
maxdim!(sweeps, 10, 20, _maxlinkdim)
cutoff!(sweeps, _cutoff)
@time dmrg(H, ψr, sweeps)

println("\nStart from free fermion state")
sweeps = Sweeps(5)
maxdim!(sweeps, _maxlinkdim)
cutoff!(sweeps, _cutoff)
@time dmrg(H, ψ0, sweeps)

nothing
