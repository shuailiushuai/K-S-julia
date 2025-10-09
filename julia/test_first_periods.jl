"""
Debug first few periods to ensure hiring works
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Statistics

println("="^60)
println("Debugging First Few Periods")
println("="^60)
println()

# Small test for detailed debugging
params = load_baseline_parameters()
params.T = 5
params.F10 = 3
params.F20 = 10
params.Ls0 = 50

println("Creating small model for debugging:")
println("  F10 = $(params.F10)")
println("  F20 = $(params.F20)")
println("  Ls0 = $(params.Ls0)")
println()

model = initialize_model(params)

println("="^60)
println("INITIAL STATE (t=0)")
println("="^60)
println()

println("Employment: $(model.L) / $(model.Ls) (should be 0 / $(model.Ls))")
println("Unemployment: $(round(model.Ue * 100, digits=1))%")
println()

println("Firm1 labor demand:")
for (i, fid) in enumerate(model.firm1_ids)
    firm = model[fid]
    println("  F1[$i]: L1=$(firm.L1), L1d=$(round(firm.L1d, digits=1)), L1dRD=$(round(firm.L1dRD, digits=1))")
end
println()

println("Firm2 labor demand:")
for (i, fid) in enumerate(model.firm2_ids[1:min(5, end)])
    firm = model[fid]
    A = KSModel.firm2_average_productivity(firm)
    println("  F2[$i]: L2=$(firm.L2), L2d=$(round(firm.L2d, digits=1)), K=$(round(firm.K, digits=1)), A=$(round(A, digits=3))")
end
println()

println("Total labor demand:")
total_L1d = sum(model[fid].L1d for fid in model.firm1_ids)
total_L2d = sum(model[fid].L2d for fid in model.firm2_ids)
println("  Sector 1: $(round(total_L1d, digits=1))")
println("  Sector 2: $(round(total_L2d, digits=1))")
println("  Total:    $(round(total_L1d + total_L2d, digits=1))")
println()

println("="^60)
println("RUNNING PERIOD 1")
println("="^60)
println()

Agents.step!(model, agent_step!, model_step!)

println("After period 1:")
println("  Employment: $(model.L) / $(model.Ls)")
println("  Unemployment: $(round(model.Ue * 100, digits=1))%")
println("  GDP: $(round(model.GDP, digits=2))")
println("  wAvg: $(round(model.wAvg, digits=3))")
println("  CPI: $(round(model.CPI, digits=3))")
println()

println("Firm1 employment:")
for (i, fid) in enumerate(model.firm1_ids)
    firm = model[fid]
    println("  F1[$i]: L1=$(firm.L1) (desired: $(round(firm.L1d, digits=1))), applications=$(length(firm.applications))")
end
println()

println("Firm2 employment (first 5):")
for (i, fid) in enumerate(model.firm2_ids[1:min(5, end)])
    firm = model[fid]
    println("  F2[$i]: L2=$(firm.L2) (desired: $(round(firm.L2d, digits=1))), applications=$(length(firm.applications))")
end
println()

# Count employed workers
employed_s1 = sum(1 for wid in model.worker_ids if model[wid].employed == 1)
employed_s2 = sum(1 for wid in model.worker_ids if model[wid].employed == 2)
println("Worker distribution:")
println("  Sector 1: $employed_s1")
println("  Sector 2: $employed_s2")
println("  Unemployed: $(model.U)")
println()

# Check for NaN
nan_count = 0
for fid in vcat(model.firm1_ids, model.firm2_ids)
    if Agents.hasid(model, fid)
        firm = model[fid]
        if isa(firm, KSModel.Firm1)
            if isnan(firm.p1) || isnan(firm.w1)
                println("  ✗ Firm1[$fid] has NaN: p1=$(firm.p1), w1=$(firm.w1)")
                nan_count += 1
            end
        else
            if isnan(firm.p2) || isnan(firm.w2)
                println("  ✗ Firm2[$fid] has NaN: p2=$(firm.p2), w2=$(firm.w2)")
                nan_count += 1
            end
        end
    end
end

if nan_count == 0
    println("✓ No NaN values in firms")
else
    println("✗ Found $nan_count firms with NaN values")
end

if isnan(model.GDP)
    println("✗ GDP is NaN")
else
    println("✓ GDP is finite: $(round(model.GDP, digits=2))")
end

println()

if model.L > 0 && !isnan(model.GDP)
    println("="^60)
    println("✓ SUCCESS! Workers found jobs in period 1!")
    println("="^60)
    println()
    println("Running a few more periods...")
    println()
    
    for t in 2:5
        Agents.step!(model, agent_step!, model_step!)
        println("Period $t: Employment=$(model.L)/$(model.Ls) ($(round((1-model.Ue)*100, digits=1))%), GDP=$(round(model.GDP, digits=2))")
    end
else
    println("="^60)
    println("✗ PROBLEM: Still no employment or NaN GDP")
    println("="^60)
end

println()
