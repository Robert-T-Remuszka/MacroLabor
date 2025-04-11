using Distributions, Parameters, Plots, LaTeXStrings
include("PS02.jl")
P1 = Params(ψₑ = 0.05, ψᵤ = 0.5)
Eqm1 = PartialEqm(μ_w = 0.5)
@unpack_Params P1
@unpack_PartialEqm Eqm1

BwInduct()

# Plot the distribution of initial human capital draws
bar(h_grid, G, grid = false, label = L"\mu = " * "$μ, " * L"\sigma = " * "$σ", xlabel = L"h", ylabel = "PMF", 
title = "Discretized " * L"G\sim" * "N")

# Plot the discretized wage offer distribution
bar(w_grid, F, grid = false, label = L"\mu = " * "$μ_w, " * L"\sigma = " * "$σ_w", xlabel = L"w", ylabel = "PMF",
title = "Discretized Wage Offer Dbn")

# Plot the search policy funciton
plot(h_grid, S[:,end -1])