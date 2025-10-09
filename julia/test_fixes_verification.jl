"""
Test the fixes for K+S Julia model - verify NaN and unemployment bugs are resolved
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Statistics
using Printf

println("="^70)
println("K+S Model Fix Verification Test")
println("="^70)
println()

# Load baseline parameters with smaller scale for faster testing
println("Loading baseline parameters (scaled down for testing)...")
params = load_baseline_parameters()
params.T = 100  # Test for 100 periods
params.F10 = 13  # Match problem statement
params.F20 = 90  # Match problem statement  
params.Ls0 = 1000  # Smaller for faster testing
params.seed = 42  # Fixed seed for reproducibility

println("Configuration:")
println("  Periods: $(params.T)")
println("  Firm1 (capital): $(params.F10)")
println("  Firm2 (consumption): $(params.F20)")
println("  Workers: $(params.Ls0)")
println()

# Initialize model
println("Initializing model...")
model = initialize_model(params)

println("✓ Model initialized successfully!")
println("  Total agents: $(Agents.nagents(model))")
println()

# Check initial state
println("Initial State (t=0):")
L0 = count(wid -> model[wid].employed > 0, model.worker_ids)
Ue0 = 100.0 * (1 - L0 / model.Ls)
println("  Employment: $L0 / $(model.Ls) ($(round(100*(L0/model.Ls), digits=1))%)")
println("  Unemployment: $(round(Ue0, digits=1))%")
println("  Firm1 count: $(length(model.firm1_ids))")
println("  Firm2 count: $(length(model.firm2_ids))")
println("  Average wage: $(round(model.wAvg, digits=2))")
println()

# Run simulation with detailed tracking
println("Running simulation for $(params.T) periods...")
println()

issues = Dict{String, Int}(
    "nan_gdp" => 0,
    "nan_wages" => 0,
    "zero_firms1" => 0,
    "zero_firms2" => 0,
    "high_unemployment" => 0,
    "negative_values" => 0
)

track_unemployment = Float64[]
track_gdp = Float64[]
track_firms1 = Int[]
track_firms2 = Int[]

for t in 1:params.T
    try
        Agents.step!(model, agent_step!, model_step!)
        
        # Collect statistics
        L = count(wid -> model[wid].employed > 0, model.worker_ids)
        Ue = 100.0 * (1 - L / model.Ls)
        F1 = length(model.firm1_ids)
        F2 = length(model.firm2_ids)
        
        push!(track_unemployment, Ue)
        push!(track_gdp, model.GDP)
        push!(track_firms1, F1)
        push!(track_firms2, F2)
        
        # Check for issues
        if isnan(model.GDP)
            issues["nan_gdp"] += 1
        end
        if isnan(model.wAvg)
            issues["nan_wages"] += 1
        end
        if F1 == 0
            issues["zero_firms1"] += 1
        end
        if F2 == 0
            issues["zero_firms2"] += 1
        end
        if Ue >= 95.0
            issues["high_unemployment"] += 1
        end
        if model.GDP < 0 || model.C < 0 || model.I < 0
            issues["negative_values"] += 1
        end
        
        # Periodic reporting
        if t % 10 == 0 || t == 1 || t == params.T
            @printf("  t=%3d: GDP=%10.2f, Ue=%5.1f%%, L=%5d/%5d, F1=%3d, F2=%3d, w=%.2f\n",
                    t, model.GDP, Ue, L, model.Ls, F1, F2, model.wAvg)
        end
        
    catch e
        println()
        println("✗ Error at period $t:")
        println("  ", e)
        
        # Print diagnostic information
        println()
        println("Model state at failure:")
        @printf("  Employment: %d / %d\n", model.L, model.Ls)
        @printf("  Firm1: %d\n", length(model.firm1_ids))
        @printf("  Firm2: %d\n", length(model.firm2_ids))
        @printf("  GDP: %.2f\n", model.GDP)
        @printf("  wAvg: %.2f\n", model.wAvg)
        @printf("  CPI: %.2f\n", model.CPI)
        
        # Check for NaN values
        if !isempty(model.firm1_ids)
            f1 = model[model.firm1_ids[1]]
            @printf("  Sample Firm1: p1=%.2f, L1=%d, L1d=%.2f, Q1=%.2f\n", 
                    f1.p1, f1.L1, f1.L1d, f1.Q1)
        end
        
        rethrow(e)
    end
end

println()
println("="^70)
println("SIMULATION RESULTS")
println("="^70)
println()

# Final state
L_final = count(wid -> model[wid].employed > 0, model.worker_ids)
Ue_final = 100.0 * (1 - L_final / model.Ls)

println("Final State (t=$(params.T)):")
@printf("  GDP:             %.2f\n", model.GDP)
@printf("  Consumption:     %.2f\n", model.C)
@printf("  Investment:      %.2f\n", model.I)
@printf("  Employment:      %d / %d (%.1f%%)\n", L_final, model.Ls, 100*(L_final/model.Ls))
@printf("  Unemployment:    %.1f%%\n", Ue_final)
@printf("  Average Wage:    %.2f\n", model.wAvg)
@printf("  CPI:             %.3f\n", model.CPI)
@printf("  Inflation:       %.2f%%\n", model.inflation * 100)
@printf("  Firm1 count:     %d\n", length(model.firm1_ids))
@printf("  Firm2 count:     %d\n", length(model.firm2_ids))
println()

# Average statistics
if !isempty(track_unemployment)
    avg_ue = mean(track_unemployment)
    std_ue = std(track_unemployment)
    
    # GDP growth (skip first few periods)
    gdp_growth = Float64[]
    for i in 6:length(track_gdp)
        if track_gdp[i-1] > 0 && isfinite(track_gdp[i]) && isfinite(track_gdp[i-1])
            push!(gdp_growth, 100 * (track_gdp[i] / track_gdp[i-1] - 1))
        end
    end
    
    println("Average Over Simulation:")
    @printf("  Unemployment:    %.2f%% (σ=%.2f%%)\n", avg_ue, std_ue)
    if !isempty(gdp_growth)
        @printf("  GDP Growth:      %.2f%% (σ=%.2f%%)\n", mean(gdp_growth), std(gdp_growth))
    end
    @printf("  Firm1:           %.1f (min=%d, max=%d)\n", 
            mean(track_firms1), minimum(track_firms1), maximum(track_firms1))
    @printf("  Firm2:           %.1f (min=%d, max=%d)\n",
            mean(track_firms2), minimum(track_firms2), maximum(track_firms2))
end
println()

# Issue summary
println("="^70)
println("DIAGNOSTICS")
println("="^70)
println()

total_issues = sum(values(issues))

if total_issues == 0
    println("✓ No critical issues detected!")
    println("  All values remained finite and positive throughout simulation")
    println("  Model appears to be functioning correctly")
else
    println("✗ Issues detected during simulation:")
    for (issue, count) in sort(collect(issues), by=x->x[2], rev=true)
        if count > 0
            @printf("  - %s: %d period(s)\n", replace(issue, "_" => " "), count)
        end
    end
end
println()

# Success criteria
println("="^70)
println("SUCCESS CRITERIA CHECK")
println("="^70)
println()

success = true
reasons = String[]

# Check 1: No NaN values
if issues["nan_gdp"] == 0 && issues["nan_wages"] == 0
    println("✓ No NaN values in GDP or wages")
else
    println("✗ NaN values detected")
    push!(reasons, "NaN values in critical variables")
    success = false
end

# Check 2: Firms survive
if issues["zero_firms1"] == 0 && issues["zero_firms2"] == 0
    println("✓ Firms survived throughout simulation")
else
    println("✗ All firms died in some periods")
    push!(reasons, "Complete firm extinction")
    success = false
end

# Check 3: Employment reasonable
if issues["high_unemployment"] < params.T * 0.5  # Allow some high unemployment periods
    println("✓ Employment remained at reasonable levels")
else
    println("✗ Excessive unemployment (>=95%) for extended periods")
    push!(reasons, "Chronic unemployment crisis")
    success = false
end

# Check 4: No negative values
if issues["negative_values"] == 0
    println("✓ All economic variables remained non-negative")
else
    println("✗ Negative values detected in economic variables")
    push!(reasons, "Invalid negative values")
    success = false
end

# Check 5: Final state reasonable
if !isnan(model.GDP) && model.GDP > 0 && Ue_final < 50.0
    println("✓ Final state is reasonable (GDP>0, Ue<50%)")
else
    println("✗ Final state is problematic")
    push!(reasons, "Bad final state")
    success = false
end

println()
if success
    println("="^70)
    println("✓✓✓ ALL TESTS PASSED! ✓✓✓")
    println("="^70)
    println()
    println("The K+S Julia model is now functioning correctly:")
    println("  - Workers are hired and employed")
    println("  - Firms produce and survive")
    println("  - GDP is positive and finite")
    println("  - Unemployment is at realistic levels")
    println("  - No NaN propagation issues")
    println()
else
    println("="^70)
    println("✗✗✗ TESTS FAILED ✗✗✗")
    println("="^70)
    println()
    println("Issues remaining:")
    for reason in reasons
        println("  - ", reason)
    end
    println()
end

println("="^70)
