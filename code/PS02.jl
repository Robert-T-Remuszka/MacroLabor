@with_kw struct Params

    r::Float64 = 0.04
    β::Float64 = (1 + r)^(-1/12)
    δ::Float64 = 0.033
    κ::Float64 = 0.5                # The marginal disuility of search
    φ::Float64 = 0.5                # Controls the degree of diminishing returns to search
    b::Float64 = 0.10               # Value of unemployment insurance
    ψₑ::Float64 = 0.5               # Probability of hc increase (in employment)
    ψᵤ::Float64 = 0.25              # Probability of hc decrease (in unemployment)

end

#===============================================================================================
                                    EQUILIBRIUM DEFINITIONS
===============================================================================================#
abstract type Equilibrium end
"""
We implement a partial equilibrium exercise in the problem set.
"""
@with_kw mutable struct PartialEqm <: Equilibrium

    # Set up the human capital grid
    h_start::Float64 = 1.
    h_stop::Float64 = 2.
    n_h::Int64 = 41
    T::Int64 = 360
    h_grid::Vector{Float64} = collect(range(h_start,h_stop,n_h))
    Δ::Float64 = (h_stop - h_start)/convert(Float64,n_h)
    μ::Float64 = 1.2
    σ::Float64 = 0.05
    G::Vector{Float64} = Discretize(h_grid,μ,σ,n_h, "Norm")                      # PMF of initial human capital draws

    # Set up the wage grid
    w_start::Float64 = -0.4
    w_stop::Float64 = 1.4
    n_w::Int64 = 41
    w_grid::Vector{Float64} = collect(range(w_start,w_stop,n_w))
    μ_w::Float64 = 0.5
    σ_w::Float64 = 0.3
    F::Vector{Float64} = Discretize(w_grid, μ_w, σ_w, n_w, "Norm")

    # Value functions
    U::Matrix{Float64} = zeros(n_h, T)
    W::Array{Float64} = zeros(n_h, T, n_w)

    # Policy functions
    S::Matrix{Float64} = zeros(n_h,T)

end

#===============================================================================================
                                    FUNCTION DEFINITIONS
===============================================================================================#
"""
Discretize the initial human capital distribution. We will do this by creating bins from a log normal
distribution.
"""
function Discretize(grid::Vector{Float64},μ::Float64,σ::Float64, n::Int64, dbn::String = "LogNorm")
    
    if dbn == "LogNorm"
        G_cts = LogNormal(μ,σ)
    else
        G_cts = Normal(μ,σ)
    end

    Cdf_Vals = cdf.(G_cts,grid)
    Pmf = pushfirst!([Cdf_Vals[i] - Cdf_Vals[i-1] for i in 2:n], Cdf_Vals[1]) / Cdf_Vals[n]

    return Pmf
end

"""
The utility cost of search. It is a linear function of
search intensity.
"""
function c(s;P::Params = P1)
    
    @unpack κ = P
    return κ * s

end

"""
The probability of finding a job for a given search
intensity.
"""
function π(s; P::Params = P1)
    
    @unpack φ = P
    return min(s^φ,1.)
    
end

"""
We can get optimal polcies in closed form once we have the policy functions.
This is what this funciton computes.
"""
function s(ExpSurp; P::Params = P1)

    @unpack_Params P
    s_star = ((β * φ / κ) * ExpSurp)^(1/(1-φ))
    return min(s_star,1.)

end

"""
The backward induction of U and W
"""
function BwInduct(; P::Params = P1, Eqm::Equilibrium = Eqm1)

    @unpack_PartialEqm Eqm
    @unpack_Params P
    
    # Fill in the terminal values first
    U[:,T] .= b
    for (h_index, h) in enumerate(h_grid)
        
        for (w_index, w) in enumerate(w_grid)

            W[h_index,T,w_index] = w * h

        end

    end

    # Now go backward from there
    for t in T-1:-1:1

        for (h_index, h) in enumerate(h_grid)
            
            SurpMax = max.(W[h_index, t+1,:] .- U[h_index,t+1],  zero(n_w)) # Maximum surplus in the event of no hc loss
            SurpW = U[h_index,t+1] .- W[h_index,t+1,:]
            U_tick = U[h_index,t + 1]
            W_tick = W[h_index,t+1, :]

            if h_index != 1 # Maximum surplus in the event of hc loss
                SurpMax⁻ = max.(W[h_index - 1, t+1,:] .- U[h_index - 1,t+1], zeros(n_w))
                U_tick⁻ = U[h_index - 1,t+1]
            else
                SurpMax⁻ = max.(W[h_index, t+1,:] .- U[h_index, t+1], zeros(n_w)) # Maximum surplus in the event of no hc loss
                U_tick⁻ = U[h_index,t+1]
            end

            if h_index != n_h
                SurpW⁺ = U[h_index + 1,t + 1] .- W[h_index + 1,t + 1,:]
                W_tick⁺ = W[h_index + 1, t + 1, :]
            else
                SurpW⁺ = U[h_index,t+1] .- W[h_index,t+1,:]
                W_tick⁺ = W[h_index, t + 1, :]
            end

            ExpSurpMax = (ψᵤ * SurpMax⁻' * F + (1 - ψᵤ) * SurpMax' * F)
            ExpSurpW = ψₑ * δ * SurpW⁺ + (1 - ψₑ) * δ * SurpW
            ExpU = ψᵤ * U_tick⁻ + (1 - ψᵤ) * U_tick
            ExpW = ψₑ * W_tick⁺ + (1 - ψₑ) * W_tick

            # Update search policy
            Eqm.S[h_index,t] = s(ExpSurpMax; P = P) 

            # Update value functions
            Eqm.U[h_index,t] = b - c(Eqm.S[h_index,t]) + β * (π(Eqm.S[h_index,t]) * ExpSurpMax + ExpU)
            Eqm.W[h_index,t,:] = w_grid * h  + β * (ExpSurpW + ExpW)

        end
    end
end