"""
Simple test to debug the K+S model initialization and first step.
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Random

println("="^60)
println("K+S Model Simple Test")
println("="^60)
println()

# Load parameters with very small numbers for debugging
params = load_baseline_parameters()
params.T = 5  # Only 5 periods
params.F10 = 5  # Very few firms
params.F20 = 10
params.Ls0 = 100  # Few workers
params.seed = 123

println("Parameters loaded:")
println("  F10 = $(params.F10)")
println("  F20 = $(params.F20)")
println("  Ls0 = $(params.Ls0)")
println()

# Initialize model
println("Initializing model...")
try
    model = initialize_model(params)
    println("Model initialized successfully!")
    println("  Agents: $(Agents.nagents(model))")
    println("  Firm1: $(length(model.firm1_ids))")
    println("  Firm2: $(length(model.firm2_ids))")
    println("  Workers: $(length(model.worker_ids))")
    println()
    
    # Check initial state
    println("Initial state:")
    println("  L = $(model.L) (employed)")
    println("  U = $(model.U) (unemployed)")
    println("  Ls = $(model.Ls) (labor force)")
    println()
    
    # Check a firm1
    if !isempty(model.firm1_ids)
        fid = model.firm1_ids[1]
        firm = model[fid]
        println("Firm1 $(firm.id):")
        println("  L1 = $(firm.L1)")
        println("  L1d = $(firm.L1d)")
        println("  L1rd = $(firm.L1rd)")
        println("  Q1 = $(firm.Q1)")
        println("  D1 = $(firm.D1)")
        println("  S1 = $(firm.S1)")
        println("  S1_prev = $(firm.S1_prev)")
        println("  p1 = $(firm.p1)")
        println("  w1 = $(firm.w1)")
        println("  B = $(firm.B)")
        println("  NW1 = $(firm.NW1)")
        println()
    end
    
    # Try one step
    println("Attempting first model step...")
    try
        Agents.step!(model, 1)
        println("Step 1 completed successfully!")
        println()
        
        println("After step 1:")
        println("  L = $(model.L) (employed)")
        println("  U = $(model.U) (unemployed)")
        println("  GDP = $(model.GDP)")
        println()
        
        # Check the same firm
        if !isempty(model.firm1_ids)
            fid = model.firm1_ids[1]
            firm = model[fid]
            println("Firm1 $(firm.id) after step:")
            println("  L1 = $(firm.L1)")
            println("  L1d = $(firm.L1d)")
            println("  L1rd = $(firm.L1rd)")
            println("  Q1 = $(firm.Q1)")
            println("  Q1e = $(firm.Q1e)")
            println("  D1 = $(firm.D1)")
            println("  S1 = $(firm.S1)")
            println("  S1_prev = $(firm.S1_prev)")
            println()
        end
        
    catch e
        println("ERROR during step 1:")
        println(e)
        if isa(e, ErrorException) || isa(e, InexactError)
            for (exc, bt) in Base.catch_stack()
                showerror(stdout, exc, bt)
                println()
            end
        end
    end
    
catch e
    println("ERROR during initialization:")
    println(e)
    if isa(e, ErrorException)
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
    end
end

println()
println("="^60)
println("Test completed")
println("="^60)
