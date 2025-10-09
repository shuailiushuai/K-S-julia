"""
Test the current state of the K+S Julia model
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Statistics

println("="^60)
println("Testing Current State of K+S Julia Model")
println("="^60)
println()

# Load baseline parameters
println("Loading baseline parameters...")
params = load_baseline_parameters()

# Small test for faster execution
params.T = 50
params.F10 = 10
params.F20 = 40
params.Ls0 = 500

println("Initializing model...")
try
    model = initialize_model(params)
    println("✓ Model initialized successfully!")
    println("  Total agents: $(Agents.nagents(model))")
    println()
    
    println("Running 50 periods...")
    for t in 1:50
        try
            Agents.step!(model, agent_step!, model_step!)
            
            if t % 10 == 0 || t == 1
                L = count(wid -> model[wid].employed > 0, model.worker_ids)
                Ue = 100.0 * (1 - L / model.Ls)
                println("  t=$t: GDP=$(round(model.GDP, digits=2)), Ue=$(round(Ue, digits=1))%, L=$L/$(model.Ls), F1=$(length(model.firm1_ids)), F2=$(length(model.firm2_ids))")
            end
        catch e
            println("✗ Error at t=$t:")
            println(e)
            println()
            println("Model state at failure:")
            println("  Firm1 count: $(length(model.firm1_ids))")
            println("  Firm2 count: $(length(model.firm2_ids))")
            println("  Worker count: $(length(model.worker_ids))")
            
            # Check for NaN values
            println("\nChecking for NaN/Inf values:")
            if !isempty(model.firm1_ids)
                f1 = model[model.firm1_ids[1]]
                println("  First Firm1: p1=$(f1.p1), Q1=$(f1.Q1), L1=$(f1.L1), L1d=$(f1.L1d)")
            end
            if !isempty(model.firm2_ids)
                f2 = model[model.firm2_ids[1]]
                println("  First Firm2: p2=$(f2.p2), Q2=$(f2.Q2), L2=$(f2.L2), L2d=$(f2.L2d)")
            end
            println("  Model: GDP=$(model.GDP), CPI=$(model.CPI), wAvg=$(model.wAvg)")
            
            rethrow(e)
        end
    end
    
    println()
    println("="^60)
    println("FINAL STATE")
    println("="^60)
    
    L = count(wid -> model[wid].employed > 0, model.worker_ids)
    Ue = 100.0 * (1 - L / model.Ls)
    
    println("GDP:              $(round(model.GDP, digits=2))")
    println("Consumption:      $(round(model.C, digits=2))")
    println("Investment:       $(round(model.I, digits=2))")
    println("Employment:       $L / $(model.Ls)")
    println("Unemployment:     $(round(Ue, digits=1))%")
    println("Average Wage:     $(round(model.wAvg, digits=2))")
    println("CPI:              $(round(model.CPI, digits=3))")
    println("Inflation:        $(round(model.inflation * 100, digits=2))%")
    println("Firm1 count:      $(length(model.firm1_ids))")
    println("Firm2 count:      $(length(model.firm2_ids))")
    
    # Check for issues
    println()
    println("="^60)
    println("DIAGNOSTICS")
    println("="^60)
    
    issues = String[]
    
    if isnan(model.GDP)
        push!(issues, "GDP is NaN")
    end
    if Ue >= 99.0
        push!(issues, "Unemployment ~100%")
    end
    if L == 0
        push!(issues, "No workers employed")
    end
    if isnan(model.wAvg)
        push!(issues, "Average wage is NaN")
    end
    
    # Check firm states
    nan_firms1 = count(fid -> isnan(model[fid].p1) || isnan(model[fid].L1d), 
                       filter(fid -> Agents.hasid(model, fid), model.firm1_ids))
    nan_firms2 = count(fid -> isnan(model[fid].p2) || isnan(model[fid].L2d), 
                       filter(fid -> Agents.hasid(model, fid), model.firm2_ids))
    
    if nan_firms1 > 0
        push!(issues, "$nan_firms1 Firm1 with NaN values")
    end
    if nan_firms2 > 0
        push!(issues, "$nan_firms2 Firm2 with NaN values")
    end
    
    if isempty(issues)
        println("✓ No major issues detected!")
        println("  Model appears to be functioning correctly.")
    else
        println("✗ Issues found:")
        for issue in issues
            println("  - $issue")
        end
    end
    
catch e
    println("✗ Failed to initialize model:")
    println(e)
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end

println()
println("="^60)
