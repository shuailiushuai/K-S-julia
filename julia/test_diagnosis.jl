"""
Minimal diagnostic test to trace what happens period-by-period
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents

println("="^60)
println("DIAGNOSTIC TEST - Tracing Period-by-Period Behavior")
println("="^60)
println()

# Tiny model for detailed trace
params = load_baseline_parameters()
params.T = 10
params.F10 = 2
params.F20 = 5
params.Ls0 = 20

println("Creating tiny model:")
println("  F10 = $(params.F10)")
println("  F20 = $(params.F20)")
println("  Ls0 = $(params.Ls0)")
println()

model = initialize_model(params)

# Helper function to print model state
function print_state(model, period_name)
    println("\n" * "="^60)
    println("$period_name (t=$(model.t))")
    println("="^60)
    
    println("\nMACRO:")
    println("  L=$(model.L)/$(model.Ls), Ue=$(round(model.Ue*100, digits=1))%, GDP=$(round(model.GDP, digits=3))")
    println("  wAvg=$(round(model.wAvg, digits=3)), CPI=$(round(model.CPI, digits=3))")
    
    println("\nFIRM1:")
    for fid in model.firm1_ids
        firm = model[fid]
        println("  F1[$fid]: L1=$(firm.L1)/$(round(firm.L1d, digits=1)), Q1=$(round(firm.Q1, digits=2)), D1=$(round(firm.D1, digits=2)), S1=$(round(firm.S1, digits=2))")
        println("           B=$(round(firm.B, digits=3)), p1=$(round(firm.p1, digits=3)), apps=$(length(firm.applications))")
    end
    
    println("\nFIRM2:")
    for fid in model.firm2_ids
        firm = model[fid]
        A_avg = KSModel.firm2_average_productivity(firm)
        println("  F2[$fid]: L2=$(firm.L2)/$(round(firm.L2d, digits=1)), Q2=$(round(firm.Q2, digits=2)), Q2e=$(round(firm.Q2e, digits=2))")
        println("           D2=$(round(firm.D2, digits=2)), D2e=$(round(firm.D2e, digits=2)), S2=$(round(firm.S2, digits=2))")
        println("           K=$(round(firm.K, digits=1)), A=$(round(A_avg, digits=3)), p2=$(round(firm.p2, digits=3))")
        println("           vintages=$(length(firm.vintages)), apps=$(length(firm.applications))")
    end
    
    # Check for potential issues
    println("\nCHECKS:")
    
    # Check if any firm has zero labor demand when it should have positive
    for fid in model.firm1_ids
        firm = model[fid]
        if firm.Q1 > 0 && firm.L1d <= 0
            println("  ⚠ F1[$fid] has Q1=$(firm.Q1) but L1d=$(firm.L1d)")
        end
    end
    
    for fid in model.firm2_ids
        firm = model[fid]
        if firm.K > 0 && firm.L2d <= 0
            println("  ⚠ F2[$fid] has K=$(firm.K) but L2d=$(firm.L2d)")
        end
        if firm.Q2 > 0 && firm.L2d <= 0
            println("  ⚠ F2[$fid] has Q2=$(firm.Q2) but L2d=$(firm.L2d)")
        end
        if isempty(firm.vintages) && firm.K > 0
            println("  ⚠ F2[$fid] has K=$(firm.K) but no vintages!")
        end
    end
    
    # Check total labor demand
    total_L1d = sum(model[fid].L1d for fid in model.firm1_ids)
    total_L2d = sum(model[fid].L2d for fid in model.firm2_ids)
    println("  Total L_demand: Sect1=$(round(total_L1d, digits=1)), Sect2=$(round(total_L2d, digits=1)), Total=$(round(total_L1d+total_L2d, digits=1))")
    
    if total_L1d + total_L2d < model.Ls * 0.5
        println("  ⚠ WARNING: Total labor demand is less than 50% of labor supply!")
    end
end

# Initial state
print_state(model, "INITIAL STATE")

# Run periods one by one
for period in 1:5
    println("\n" * "-"^60)
    println("EXECUTING PERIOD $period")
    println("-"^60)
    
    Agents.step!(model)
    
    print_state(model, "AFTER PERIOD $period")
    
    # Stop if GDP crashes
    if model.GDP <= 0 && period > 1
        println("\n⚠ GDP crashed to zero at period $period - stopping diagnostic")
        break
    end
end

println("\n" * "="^60)
println("DIAGNOSTIC COMPLETE")
println("="^60)
