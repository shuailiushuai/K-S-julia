"""
Diagnostic trace to understand why GDP drops to 0
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents
using Statistics

# Create minimal test
params = load_baseline_parameters()
params.T = 10
params.F10 = 3
params.F20 = 10
params.Ls0 = 50

println("\n" * "="^80)
println("DIAGNOSTIC TRACE - Minimal Model")
println("="^80)
println("\nParameters:")
println("  F10 = $(params.F10), F20 = $(params.F20), Ls0 = $(params.Ls0)")
println("  mu1 = $(params.mu1), mu20 = $(params.mu20)")
println("  m1 = $(params.m1), m2 = $(params.m2)")
println("  b = $(params.b), eta = $(params.eta)")
println("  iota = $(params.iota), phi = $(params.phi)")
println("  nu = $(params.nu)")

model = initialize_model(params)

# Function to print diagnostic info
function print_diagnostics(model, t)
    println("\n" * "-"^80)
    println("PERIOD $t")
    println("-"^80)
    
    # Employment
    println("\nEMPLOYMENT:")
    println("  Total: $(model.L) / $(model.Ls) (Ue=$(round(model.Ue*100, digits=1))%)")
    println("  Sector 1: $(model.L1)")
    println("  Sector 2: $(model.L2)")
    
    # Wages
    println("\nWAGES:")
    println("  wAvg: $(round(model.wAvg, digits=3))")
    println("  wMin: $(round(model.wMin, digits=3))")
    println("  wU: $(round(model.wU, digits=3))")
    
    # Prices
    println("\nPRICES:")
    println("  p1avg (PPI): $(round(model.p1avg, digits=3))")
    println("  p2avg (CPI): $(round(model.p2avg, digits=3))")
    
    # Demand and Production
    println("\nDEMAND & PRODUCTION:")
    println("  Consumption demand (Cd): $(round(model.Cd, digits=2))")
    println("  Consumption actual (C): $(round(model.C, digits=2))")
    println("  Investment (I): $(round(model.I, digits=2))")
    println("  Total Q1: $(round(model.Q1, digits=2))")
    println("  Total Q2: $(round(model.Q2, digits=2))")
    println("  Total S2: $(round(model.S2, digits=2))")
    
    # GDP
    println("\nGDP:")
    println("  GDP: $(round(model.GDP, digits=2))")
    println("  GDPnom: $(round(model.GDPnom, digits=2))")
    println("  GDPreal: $(round(model.GDPreal, digits=2))")
    
    # Firm1 details
    println("\nFIRM1 DETAILS:")
    for (i, fid) in enumerate(model.firm1_ids)
        if Agents.hasid(model, fid)
            f = model[fid]
            println("  F1[$i]: L=$(f.L1)/$(round(f.L1d,digits=1)), Q=$(round(f.Q1,digits=1)), D=$(round(f.D1,digits=1)), S=$(round(f.S1,digits=2)), p=$(round(f.p1,digits=3)), w=$(round(f.w1,digits=3)), NW=$(round(f.NW1,digits=1))")
        end
    end
    
    # Firm2 details (first 5)
    println("\nFIRM2 DETAILS (first 5):")
    for (i, fid) in enumerate(model.firm2_ids[1:min(5, end)])
        if Agents.hasid(model, fid)
            f = model[fid]
            A = KSModel.firm2_average_productivity(f)
            println("  F2[$i]: L=$(f.L2)/$(round(f.L2d,digits=1)), Q=$(round(f.Q2,digits=1)), D=$(round(f.D2,digits=1)), S=$(round(f.S2,digits=1)), K=$(round(f.K,digits=1)), A=$(round(A,digits=3)), p=$(round(f.p2,digits=3)), w=$(round(f.w2,digits=3)), NW=$(round(f.NW2,digits=1))")
        end
    end
    
    # Check for problems
    println("\nPROBLEM CHECKS:")
    if model.Ue >= 0.99
        println("  ⚠ PROBLEM: Very high unemployment ($(round(model.Ue*100,digits=1))%)")
    end
    if model.GDP < 1.0
        println("  ⚠ PROBLEM: GDP very low ($(round(model.GDP,digits=2)))")
    end
    if model.C < 1.0
        println("  ⚠ PROBLEM: Consumption very low ($(round(model.C,digits=2)))")
    end
    
    nan_firms = 0
    for fid in vcat(model.firm1_ids, model.firm2_ids)
        if Agents.hasid(model, fid)
            f = model[fid]
            if isa(f, KSModel.Firm1)
                if isnan(f.p1) || isnan(f.w1) || f.p1 <= 0
                    println("  ⚠ PROBLEM: Firm1[$fid] has invalid p1=$(f.p1) or w1=$(f.w1)")
                    nan_firms += 1
                end
            else
                if isnan(f.p2) || isnan(f.w2) || f.p2 <= 0
                    println("  ⚠ PROBLEM: Firm2[$fid] has invalid p2=$(f.p2) or w2=$(f.w2)")
                    nan_firms += 1
                end
            end
        end
    end
    
    if nan_firms == 0
        println("  ✓ No NaN or invalid prices/wages in firms")
    end
end

# Print initial state
print_diagnostics(model, 0)

# Run simulation with diagnostics
for t in 1:10
    try
        Agents.step!(model)
        print_diagnostics(model, t)
        
        # Stop if GDP goes to 0
        if model.GDP <= 0
            println("\n" * "!"^80)
            println("STOPPING: GDP dropped to 0 at period $t")
            println("!"^80)
            break
        end
    catch e
        println("\n" * "!"^80)
        println("ERROR at period $t:")
        println(e)
        println("!"^80)
        rethrow(e)
    end
end

println("\n" * "="^80)
println("END OF DIAGNOSTIC TRACE")
println("="^80)
