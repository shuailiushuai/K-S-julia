"""
    test_comprehensive_fixes.jl

Test script to verify all critical fixes are working.
This script tests the model with progressively longer simulations.
"""

# Add the package to the path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents
using Printf
using Statistics

println("="^80)
println("K+S Model - Comprehensive Fixes Verification Test")
println("="^80)
println()

# Test 1: Initialization
println("TEST 1: Model Initialization")
println("-"^80)

params = load_baseline_parameters()
params.T = 10
params.F10 = 8
params.F20 = 30
params.Ls0 = 500
params.B = 5

println("Creating model...")
try
    model = initialize_model(params)
    println("✓ Model created successfully")
    println("  Total agents: $(Agents.nagents(model))")
    println()
    
    # Check initial conditions
    println("Checking initial conditions at t=0...")
    
    # Check Firm1
    firm1_issues = 0
    for fid in model.firm1_ids
        firm = model[fid]
        if firm.S1_prev <= 0
            println("  ✗ Firm1[$fid]: S1_prev = $(firm.S1_prev) (should be > 0)")
            firm1_issues += 1
        end
        if firm.L1rd <= 0
            println("  ✗ Firm1[$fid]: L1rd = $(firm.L1rd) (should be > 0)")
            firm1_issues += 1
        end
        if firm.L1dRD <= 0
            println("  ✗ Firm1[$fid]: L1dRD = $(firm.L1dRD) (should be > 0)")
            firm1_issues += 1
        end
        if firm.L1d <= 0
            println("  ✗ Firm1[$fid]: L1d = $(firm.L1d) (should be > 0)")
            firm1_issues += 1
        end
    end
    
    if firm1_issues == 0
        println("  ✓ All Firm1 initialized correctly")
    else
        println("  ✗ Found $firm1_issues issues in Firm1 initialization")
    end
    
    # Check Firm2
    firm2_issues = 0
    for fid in model.firm2_ids
        firm = model[fid]
        if firm.D2e <= 0
            println("  ✗ Firm2[$fid]: D2e = $(firm.D2e) (should be > 0)")
            firm2_issues += 1
        end
        if firm.K <= 0
            println("  ✗ Firm2[$fid]: K = $(firm.K) (should be > 0)")
            firm2_issues += 1
        end
        if firm.L2d <= 0
            println("  ✗ Firm2[$fid]: L2d = $(firm.L2d) (should be > 0)")
            firm2_issues += 1
        end
    end
    
    if firm2_issues == 0
        println("  ✓ All Firm2 initialized correctly")
    else
        println("  ✗ Found $firm2_issues issues in Firm2 initialization")
    end
    
    # Check history
    if length(model.CPI_history) == params.mPer && all(isfinite, model.CPI_history)
        println("  ✓ CPI history initialized (length=$(length(model.CPI_history)))")
    else
        println("  ✗ CPI history issue: length=$(length(model.CPI_history)), finite=$(all(isfinite, model.CPI_history))")
    end
    
    if length(model.GDP_history) == params.mPer && all(isfinite, model.GDP_history)
        println("  ✓ GDP history initialized (length=$(length(model.GDP_history)))")
    else
        println("  ✗ GDP history issue: length=$(length(model.GDP_history)), finite=$(all(isfinite, model.GDP_history))")
    end
    
    println()
    
    # Test 2: First time step
    println("TEST 2: First Time Step")
    println("-"^80)
    
    println("Running step 1...")
    try
        Agents.step!(model, 1)
        println("✓ Step 1 completed without crash")
        println()
        
        # Check results
        println("Results after step 1:")
        @printf("  GDP:         %.2f %s\n", model.GDP, isfinite(model.GDP) ? "✓" : "✗ NaN/Inf")
        @printf("  Employment:  %d\n", model.L)
        @printf("  Unemployment: %.1f%%\n", model.Ue * 100)
        @printf("  Avg Wage:    %.3f %s\n", model.wAvg, isfinite(model.wAvg) ? "✓" : "✗ NaN/Inf")
        @printf("  CPI:         %.3f %s\n", model.CPI, isfinite(model.CPI) && model.CPI > 0 ? "✓" : "✗")
        @printf("  PPI:         %.3f %s\n", model.PPI, isfinite(model.PPI) && model.PPI > 0 ? "✓" : "✗")
        println()
        
        # Critical checks
        issues = 0
        if !isfinite(model.GDP)
            println("  ✗ CRITICAL: GDP is NaN/Inf")
            issues += 1
        end
        if !isfinite(model.wAvg) || model.wAvg <= 0
            println("  ✗ CRITICAL: Average wage is invalid")
            issues += 1
        end
        if model.L == 0
            println("  ✗ CRITICAL: Zero employment")
            issues += 1
        end
        if model.Ue >= 1.0
            println("  ✗ CRITICAL: 100% unemployment")
            issues += 1
        end
        if !isfinite(model.CPI) || model.CPI <= 0
            println("  ✗ CRITICAL: CPI is invalid")
            issues += 1
        end
        
        if issues == 0
            println("  ✓ All critical checks passed")
        else
            println("  ✗ Found $issues critical issues")
        end
        println()
        
        # Test 3: Multiple steps
        println("TEST 3: Multiple Steps (2-10)")
        println("-"^80)
        
        all_ok = true
        for t in 2:10
            try
                Agents.step!(model, 1)
                
                # Check for issues
                if !isfinite(model.GDP) || !isfinite(model.wAvg) || model.L == 0
                    @printf("  ✗ Step %2d: GDP=%.2f, L=%d, Ue=%.1f%%, wAvg=%.3f\n",
                           t, model.GDP, model.L, model.Ue*100, model.wAvg)
                    all_ok = false
                    break
                else
                    @printf("  ✓ Step %2d: GDP=%.2f, L=%d, Ue=%.1f%%, wAvg=%.3f\n",
                           t, model.GDP, model.L, model.Ue*100, model.wAvg)
                end
            catch e
                println("  ✗ ERROR at step $t: $e")
                all_ok = false
                break
            end
        end
        println()
        
        if all_ok
            println("✓ All 10 steps completed successfully!")
            println()
            
            # Summary statistics
            println("SUMMARY STATISTICS")
            println("-"^80)
            @printf("Final GDP:           %.2f\n", model.GDP)
            @printf("Final Employment:    %d (%.1f%%)\n", model.L, (1-model.Ue)*100)
            @printf("Final Avg Wage:      %.3f\n", model.wAvg)
            @printf("Final CPI:           %.3f\n", model.CPI)
            @printf("Final Inflation:     %.2f%%\n", model.inflation*100)
            @printf("Sector 1 Firms:      %d\n", model.F1)
            @printf("Sector 2 Firms:      %d\n", model.F2)
            @printf("Sector 1 Productivity: %.3f\n", model.A1)
            @printf("Sector 2 Productivity: %.3f\n", model.A2)
            println()
            
            println("="^80)
            println("✓ ALL TESTS PASSED!")
            println("="^80)
            println()
            println("The model is working correctly. You can now run longer simulations.")
            println("Try: julia example.jl")
            
        else
            println("="^80)
            println("✗ TESTS FAILED")
            println("="^80)
            println()
            println("Some tests failed. Please review the output above for details.")
        end
        
    catch e
        println("✗ ERROR during first time step:")
        println("  $e")
        println()
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println()
        end
    end
    
catch e
    println("✗ ERROR during model initialization:")
    println("  $e")
    println()
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
end
