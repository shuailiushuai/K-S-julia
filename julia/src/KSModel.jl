"""
    KSModel.jl

Main module for the K+S (Keynes+Schumpeter) agent-based macroeconomic model.
This is a complete Julia replication of the C/LSD implementation using Agents.jl 6.2.9.

The model includes:
- Workers (consumers)
- Capital-good firms (Firm1)
- Consumption-good firms (Firm2)  
- Banks
- Government and Central Bank

References:
- Dosi et al. (2010, 2015, 2017, 2018, 2019, 2020)
- Original C implementation: fun_KS.cpp and associated header files
"""
module KSModel

using Agents
using Distributions
using Random
using Statistics
using StatsBase
using DataFrames

# Export main types and functions
export Worker, Firm1, Firm2, Bank
export KSModelSpace, initialize_model, model_step!, agent_step!
export run_simulation, collect_data

# Include sub-modules
include("types.jl")
include("parameters.jl")
include("initialization.jl")
include("firm1_behavior.jl")
include("firm2_behavior.jl")
include("worker_behavior.jl")
include("bank_behavior.jl")
include("government.jl")
include("markets.jl")
include("scheduling.jl")
include("statistics.jl")
include("visualization.jl")

end # module
