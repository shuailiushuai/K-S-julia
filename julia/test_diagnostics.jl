"""
Diagnostic test to understand the investment and hiring dynamics
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents
using Statistics

println("="^70)
println("DIAGNOSTIC TEST FOR INVESTMENT AND HIRING")
println("="^70)
println()

# Use parameters similar to the full test
params = load_baseline_parameters()
params.T = 10  # Just run 10 periods for diagnostics
params.F10 = 10  # Smaller for easier analysis
params.F20 = 40
params.Ls0 = 500

println("Parameters:")
println("  T = $(params.T)")
println("  F10 = $(params.F10)")
println("  F20 = $(params.F20)")
println("  Ls0 = $(params.Ls0)")
println("  eta = $(params.eta)")
println("  m2 = $(params.m2)")
println()

model = initialize_model(params)

println("="^70)
println("INITIAL STATE (t=0)")
println("="^70)
println()

println("Model aggregates:")
println("  GDP = $(round(model.GDP, digits=2))")
println("  L = $(model.L)")
println("  Ls = $(model.Ls)")
println("  Ue = $(round(model.Ue * 100, digits=1))%")
println()

# Check initial firm values
total_K = sum(model[fid].K for fid in model.firm2_ids)
total_Id = sum(model[fid].Id for fid in model.firm2_ids)
total_D1 = sum(model[fid].D1 for fid in model.firm1_ids)
total_L1d = sum(model[fid].L1d for fid in model.firm1_ids)
total_L2d = sum(model[fid].L2d for fid in model.firm2_ids)

println("Firm2 aggregates:")
println("  Total K = $(round(total_K, digits=1))")
println("  Total Id = $(round(total_Id, digits=1))")
println("  Total L2d = $(round(total_L2d, digits=1))")
println()

println("Firm1 aggregates:")
println("  Total D1 = $(round(total_D1, digits=1))")
println("  Total L1d = $(round(total_L1d, digits=1))")
println()

# Run model for several periods with detailed diagnostics
for t in 1:params.T
    println("="^70)
    println("PERIOD $t")
    println("="^70)
    
    # Step the model
    Agents.step!(model, 1)
    
    # Collect statistics
    total_K = sum(model[fid].K for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    total_Kd = sum(model[fid].Kd for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    total_EId = sum(model[fid].EId for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    total_SId = sum(model[fid].SId for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    total_Id = sum(model[fid].Id for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    total_D1 = sum(model[fid].D1 for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    total_L1d = sum(model[fid].L1d for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    total_L2d = sum(model[fid].L2d for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    total_Q1e = sum(model[fid].Q1e for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    total_Q2e = sum(model[fid].Q2e for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    total_S1 = sum(model[fid].S1 for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    total_S2 = sum(model[fid].S2 for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    
    println()
    println("Investment and Capital:")
    println("  Total K = $(round(total_K, digits=1))")
    println("  Total Kd = $(round(total_Kd, digits=1))")
    println("  Total EId = $(round(total_EId, digits=1))")
    println("  Total SId = $(round(total_SId, digits=1))")
    println("  Total Id = $(round(total_Id, digits=1))")
    println()
    
    println("Production and Sales:")
    println("  Sector 1 D1 = $(round(total_D1, digits=1))")
    println("  Sector 1 Q1e = $(round(total_Q1e, digits=1))")
    println("  Sector 1 S1 = $(round(total_S1, digits=1))")
    println("  Sector 2 Q2e = $(round(total_Q2e, digits=1))")
    println("  Sector 2 S2 = $(round(total_S2, digits=1))")
    println()
    
    println("Labor:")
    println("  L1 = $(model.L1), L1d = $(round(total_L1d, digits=1))")
    println("  L2 = $(model.L2), L2d = $(round(total_L2d, digits=1))")
    println("  L = $(model.L) / $(model.Ls)")
    println("  Ue = $(round(model.Ue * 100, digits=1))%")
    println()
    
    println("Aggregates:")
    println("  GDP = $(round(model.GDP, digits=2))")
    println("  C = $(round(model.C, digits=2))")
    println("  I = $(round(model.I, digits=2))")
    println("  Cd = $(round(model.Cd, digits=2))")
    println("  CPI = $(round(model.CPI, digits=3))")
    println("  wAvg = $(round(model.wAvg, digits=3))")
    println()
    
    # Check for problems
    if model.Ue > 0.95
        println("⚠ WARNING: High unemployment!")
    end
    if total_Id < 1.0
        println("⚠ WARNING: Very low investment demand!")
    end
    if total_D1 < 0.1
        println("⚠ WARNING: Very low orders to Sector 1!")
    end
    if model.GDP < 10.0
        println("⚠ WARNING: Very low GDP!")
    end
end

println()
println("="^70)
println("TEST COMPLETE")
println("="^70)
