"""
Debug initialization and first period to find NaN source
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Statistics

println("="^60)
println("Debugging K+S Initialization and First Period")
println("="^60)
println()

# Small test
params = load_baseline_parameters()
params.T = 5
params.F10 = 5
params.F20 = 20
params.Ls0 = 100

println("Initializing model...")
model = initialize_model(params)

println("\nInitial State (t=0):")
println("  Firm1 count: $(length(model.firm1_ids))")
println("  Firm2 count: $(length(model.firm2_ids))")
println("  Worker count: $(length(model.worker_ids))")
println("  Employment: $(model.L) / $(model.Ls)")
println("  Unemployment: $(round(model.Ue * 100, digits=1))%")
println()

# Check firm states
println("Firm1 States:")
for (i, fid) in enumerate(model.firm1_ids[1:min(3, end)])
    firm = model[fid]
    println("  F1[$i]: L1=$(firm.L1), L1d=$(firm.L1d), p1=$(round(firm.p1, digits=3)), w1=$(round(firm.w1, digits=3)), B=$(round(firm.B, digits=3))")
end

println("\nFirm2 States:")
for (i, fid) in enumerate(model.firm2_ids[1:min(3, end)])
    firm = model[fid]
    A_avg = KSModel.firm2_average_productivity(firm)
    println("  F2[$i]: L2=$(firm.L2), L2d=$(firm.L2d), p2=$(round(firm.p2, digits=3)), w2=$(round(firm.w2, digits=3)), A=$(round(A_avg, digits=3)), K=$(round(firm.K, digits=1))")
end

println("\nWorker States (first 5):")
employed_count = 0
for (i, wid) in enumerate(model.worker_ids[1:min(5, end)])
    worker = model[wid]
    if worker.employed > 0
        employed_count += 1
    end
    println("  W[$i]: employed=$(worker.employed), w=$(round(worker.w, digits=3)), wRes=$(round(worker.wRes, digits=3))")
end
println("  Total employed: $employed_count / $(model.Ls)")

println("\n" * "="^60)
println("Running Period 1...")
println("="^60)

try
    Agents.step!(model, agent_step!, model_step!)
    
    println("\nAfter Period 1:")
    println("  GDP: $(round(model.GDP, digits=2))")
    println("  CPI: $(round(model.CPI, digits=3))")
    println("  Employment: $(model.L) / $(model.Ls)")
    println("  Unemployment: $(round(model.Ue * 100, digits=1))%")
    println("  wAvg: $(round(model.wAvg, digits=3))")
    
    # Check for NaN values
    println("\nChecking for NaN/Inf:")
    
    nan_firms1 = 0
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm = model[fid]
            if isnan(firm.p1) || isnan(firm.L1d) || isnan(firm.w1)
                nan_firms1 += 1
                println("  Firm1[$fid]: p1=$(firm.p1), L1d=$(firm.L1d), w1=$(firm.w1), L1=$(firm.L1)")
            end
        end
    end
    
    nan_firms2 = 0
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm = model[fid]
            if isnan(firm.p2) || isnan(firm.L2d) || isnan(firm.w2)
                nan_firms2 += 1
                println("  Firm2[$fid]: p2=$(firm.p2), L2d=$(firm.L2d), w2=$(firm.w2), L2=$(firm.L2)")
            end
        end
    end
    
    if nan_firms1 == 0 && nan_firms2 == 0 && !isnan(model.GDP)
        println("  ✓ No NaN values detected!")
    else
        println("  ✗ Found NaN values: $nan_firms1 Firm1, $nan_firms2 Firm2")
    end
    
    # Check employment transitions
    println("\nEmployment Details:")
    println("  Firm1 total L: $(sum(model[fid].L1 for fid in model.firm1_ids if Agents.hasid(model, fid); init=0))")
    println("  Firm2 total L: $(sum(model[fid].L2 for fid in model.firm2_ids if Agents.hasid(model, fid); init=0))")
    println("  Total employed workers: $(model.L)")
    
catch e
    println("\n✗ Error during period 1:")
    println(e)
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end

println("\n" * "="^60)
