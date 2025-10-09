"""
    debug_test.jl

Debug test to understand NaN propagation.
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents
using Printf

println("="^70)
println("K+S Model Debug Test")
println("="^70)
println()

# Load baseline parameters with smaller scale
params = load_baseline_parameters()
params.T = 5
params.F10 = 10
params.F20 = 40
params.Ls0 = 500
params.B = 5

println("Creating and initializing model...")
model = initialize_model(params)
println("✓ Model initialized")
println()

# Helper function to check for NaNs
function check_nans(label, values...)
    for (i, v) in enumerate(values)
        if isnan(v)
            println("  ✗ NaN detected in $label[$i]: $v")
            return true
        end
    end
    return false
end

println("INITIAL STATE (t=0):")
println("-"^70)
println("Firms:")
for (i, fid) in enumerate(model.firm1_ids[1:min(3, length(model.firm1_ids))])
    firm = model[fid]
    println("  Firm1[$i]: L1=$(firm.L1), L1d=$(firm.L1d), S1=$(firm.S1), S1_prev=$(firm.S1_prev), L1rd=$(firm.L1rd)")
end
for (i, fid) in enumerate(model.firm2_ids[1:min(3, length(model.firm2_ids))])
    firm = model[fid]
    println("  Firm2[$i]: L2=$(firm.L2), L2d=$(firm.L2d), Q2=$(firm.Q2), D2=$(firm.D2), K=$(firm.K)")
end
println()
println("Aggregates:")
println("  GDP=$(model.GDP), C=$(model.C), I=$(model.I), G=$(model.G)")
println("  CPI=$(model.CPI), PPI=$(model.PPI), p2avg=$(model.p2avg), p1avg=$(model.p1avg)")
println("  L=$(model.L), U=$(model.U), Ue=$(model.Ue)")
println()

# Run step by step with detailed output
for t in 1:3
    println("="^70)
    println("TIME STEP $t")
    println("="^70)
    
    # Step the model
    Agents.step!(model, 1)
    
    println("\nAfter step $t:")
    println("-"^70)
    
    # Check Firm1 state
    println("Sample Firm1 states:")
    for (i, fid) in enumerate(model.firm1_ids[1:min(3, length(model.firm1_ids))])
        if !Agents.hasid(model, fid)
            println("  Firm1[$i]: REMOVED")
            continue
        end
        firm = model[fid]
        println("  Firm1[$i]:")
        println("    L1=$(firm.L1), L1d=$(firm.L1d), L1rd=$(firm.L1rd), L1dRD=$(firm.L1dRD)")
        println("    Q1=$(firm.Q1), Q1e=$(firm.Q1e), S1=$(firm.S1), S1_prev=$(firm.S1_prev)")
        println("    D1=$(firm.D1), p1=$(firm.p1), c1=$(firm.c1)")
        println("    A=$(firm.A), B=$(firm.B), NW1=$(firm.NW1)")
        check_nans("Firm1[$i]", firm.L1d, firm.Q1, firm.Q1e, firm.S1, firm.p1, firm.c1, firm.A, firm.B, firm.NW1)
    end
    println()
    
    # Check Firm2 state
    println("Sample Firm2 states:")
    for (i, fid) in enumerate(model.firm2_ids[1:min(3, length(model.firm2_ids))])
        if !Agents.hasid(model, fid)
            println("  Firm2[$i]: REMOVED")
            continue
        end
        firm = model[fid]
        println("  Firm2[$i]:")
        println("    L2=$(firm.L2), L2d=$(firm.L2d), Q2=$(firm.Q2), Q2e=$(firm.Q2e)")
        println("    D2=$(firm.D2), D2e=$(firm.D2e), S2=$(firm.S2)")
        println("    p2=$(firm.p2), c2=$(firm.c2), K=$(firm.K)")
        println("    NW2=$(firm.NW2), Id=$(firm.Id), EI=$(firm.EI), SI=$(firm.SI)")
        check_nans("Firm2[$i]", firm.L2d, firm.Q2, firm.Q2e, firm.D2, firm.p2, firm.c2, firm.K, firm.NW2)
    end
    println()
    
    # Check aggregates
    println("Aggregates:")
    println("  GDP=$(model.GDP), GDPnom=$(model.GDPnom), GDPreal=$(model.GDPreal)")
    println("  C=$(model.C), Cd=$(model.Cd), I=$(model.I), G=$(model.G)")
    println("  S1=$(model.S1), S2=$(model.S2), Q1=$(model.Q1), Q2=$(model.Q2)")
    println("  CPI=$(model.CPI), PPI=$(model.PPI)")
    println("  p1avg=$(model.p1avg), p2avg=$(model.p2avg)")
    println("  L=$(model.L), U=$(model.U), Ue=$(model.Ue*100)%")
    println("  wAvg=$(model.wAvg)")
    
    has_nans = check_nans("Aggregates", model.GDP, model.GDPnom, model.GDPreal, 
                         model.C, model.I, model.G, model.CPI, model.PPI,
                         model.p1avg, model.p2avg, model.wAvg)
    
    if has_nans
        println("\n✗✗✗ NaN DETECTED - STOPPING ✗✗✗")
        break
    end
    
    println()
end

println("="^70)
println("Debug test completed")
println("="^70)
