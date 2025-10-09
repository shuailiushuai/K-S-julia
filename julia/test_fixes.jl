"""
    test_fixes.jl

Simple test to verify the critical fixes for R&D timing and NaN errors.
"""

# Add the package to the path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents
using Printf

println("="^70)
println("K+S Model Critical Fixes Test")
println("="^70)
println()

# Load baseline parameters with smaller scale for faster testing
println("Loading baseline parameters...")
params = load_baseline_parameters()

# Use smaller scale for quick testing
params.T = 10  # Just 10 periods for initial test
params.F10 = 10  # 10 capital-good firms
params.F20 = 40  # 40 consumption-good firms
params.Ls0 = 500  # 500 workers
params.B = 5  # 5 banks

println("Creating model with:")
println("  - $(params.F10) capital-good firms")
println("  - $(params.F20) consumption-good firms")
println("  - $(params.B) banks")
println("  - $(params.Ls0) workers")
println()

# Initialize model
println("Initializing model...")
try
    model = initialize_model(params)
    println("✓ Model initialized successfully!")
    println("  - Total agents: $(Agents.nagents(model))")
    println()
    
    # Check initial state
    println("Checking initial state...")
    
    # Check Firm1 initialization
    firm1 = model[model.firm1_ids[1]]
    println("  Sample Firm1:")
    println("    - S1 = $(firm1.S1)")
    println("    - S1_prev = $(firm1.S1_prev)")
    println("    - L1rd = $(firm1.L1rd)")
    println("    - L1dRD = $(firm1.L1dRD)")
    println("    - L1d = $(firm1.L1d)")
    println("    - A = $(firm1.A)")
    println("    - B = $(firm1.B)")
    
    if firm1.S1_prev > 0
        println("  ✓ S1_prev properly initialized")
    else
        println("  ✗ WARNING: S1_prev is zero!")
    end
    
    if firm1.L1rd > 0
        println("  ✓ L1rd properly initialized")
    else
        println("  ✗ WARNING: L1rd is zero!")
    end
    println()
    
    # Run first time step
    println("Running first time step...")
    try
        Agents.step!(model, 1)
        println("✓ First time step completed without error!")
        println()
        
        # Check results after first step
        println("After first step:")
        println("  - GDP = $(model.GDP)")
        println("  - Employment = $(model.L)")
        println("  - Unemployment Rate = $(model.Ue * 100)%")
        println("  - Average Wage = $(model.wAvg)")
        println("  - CPI = $(model.CPI)")
        println("  - PPI = $(model.PPI)")
        println()
        
        # Check for NaNs
        has_nan = false
        if isnan(model.GDP)
            println("  ✗ ERROR: GDP is NaN!")
            has_nan = true
        end
        if isnan(model.wAvg)
            println("  ✗ ERROR: Average wage is NaN!")
            has_nan = true
        end
        if model.L == 0
            println("  ✗ ERROR: Zero employment!")
        end
        
        if !has_nan && model.L > 0
            println("  ✓ No NaN values detected!")
            println("  ✓ Employment is positive!")
        end
        println()
        
        # Try running a few more steps
        println("Running 9 more time steps...")
        for t in 2:10
            try
                Agents.step!(model, 1)
                @printf("  Step %2d: GDP=%.2f, L=%d, Ue=%.1f%%, wAvg=%.3f\n", 
                       t, model.GDP, model.L, model.Ue*100, model.wAvg)
            catch e
                println("  ✗ ERROR at step $t: $e")
                rethrow(e)
            end
        end
        println()
        println("✓ All 10 steps completed successfully!")
        println()
        
    catch e
        println("✗ ERROR during first time step:")
        println("  $e")
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
        return
    end
    
catch e
    println("✗ ERROR during model initialization:")
    println("  $e")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    return
end

println("="^70)
println("Test completed!")
println("="^70)
