"""
Test the fixes for NaN errors and 100% unemployment
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Statistics

println("="^60)
println("Testing Fixed K+S Julia Model")
println("="^60)
println()

# Load baseline parameters (small test)
params = load_baseline_parameters()
params.T = 200
params.F10 = 100
params.F20 = 400
params.Ls0 = 5000

println("Parameters:")
println("  T = $(params.T)")
println("  F10 = $(params.F10)")
println("  F20 = $(params.F20)")
println("  Ls0 = $(params.Ls0)")
println()

println("Initializing model...")
model = initialize_model(params)

println("Initial State (t=0):")
println("  Firm1: $(length(model.firm1_ids)) firms")
println("  Firm2: $(length(model.firm2_ids)) firms")
println("  Workers: $(length(model.worker_ids))")
println("  Employment: $(model.L) / $(model.Ls) (Ue=$(round(model.Ue*100, digits=1))%)")
println("  All workers start UNEMPLOYED (matching C model)")
println()

println("Running simulation for $(params.T) periods...")
println()

# Track some key metrics
gdp_track = Float64[]
ue_track = Float64[]
w_track = Float64[]

try
    for t in 1:params.T
        Agents.step!(model, 1)
        
        push!(gdp_track, model.GDP)
        push!(ue_track, model.Ue * 100)
        push!(w_track, model.wAvg)
        
        if t % 50 == 0
            L = model.L
            Ue = model.Ue * 100
            println("Step $t / $(params.T) completed. GDP=$(round(model.GDP, digits=2)), Ue=$(round(Ue, digits=1))%")
        end
    end
    
    println()
    println("="^60)
    println("SIMULATION COMPLETED SUCCESSFULLY!")
    println("="^60)
    println()
    
    # Final statistics
    println("MACROECONOMIC AGGREGATES (Final Period)")
    println("-"^60)
    println("GDP:                 $(round(model.GDP, digits=2))")
    println("Consumption:         $(round(model.C, digits=2))")
    println("Investment:          $(round(model.I, digits=2))")
    println("Government:          $(round(model.G, digits=2))")
    println()
    
    println("LABOR MARKET")
    println("-"^60)
    println("Employment:          $(model.L)")
    println("Unemployment Rate:   $(round(model.Ue * 100, digits=1))%")
    println("Average Wage:        $(round(model.wAvg, digits=2))")
    println()
    
    println("PRODUCTIVITY")
    println("-"^60)
    println("Sector 1:            $(round(model.A1, digits=3))")
    println("Sector 2:            $(round(model.A2, digits=3))")
    println()
    
    println("FINANCIAL VARIABLES")
    println("-"^60)
    println("Interest Rate:       $(round(model.r * 100, digits=1))%")
    println("Inflation:           $(round(model.inflation * 100, digits=1))%")
    println("Debt/GDP:            $(round(model.Deb / max(model.GDP, 0.01), digits=3))")
    println()
    
    println("FIRM DYNAMICS")
    println("-"^60)
    println("Sector 1 Firms:      $(length(model.firm1_ids))")
    println("Sector 2 Firms:      $(length(model.firm2_ids))")
    println()
    
    # Average values
    println("AVERAGE VALUES (Full Period)")
    println("-"^60)
    
    # Filter valid values (non-NaN, non-zero for growth rates)
    valid_gdp = filter(x -> isfinite(x) && x > 0, gdp_track)
    valid_ue = filter(isfinite, ue_track)
    valid_w = filter(x -> isfinite(x) && x > 0, w_track)
    
    if length(valid_gdp) > 1
        gdp_growth = [(valid_gdp[i] - valid_gdp[i-1]) / valid_gdp[i-1] * 100 
                     for i in 2:length(valid_gdp)]
        valid_growth = filter(isfinite, gdp_growth)
        avg_growth = isempty(valid_growth) ? 0.0 : mean(valid_growth)
        println("GDP Growth Rate:     $(round(avg_growth, digits=2))%")
        
        growth_volatility = isempty(valid_growth) ? 0.0 : std(valid_growth)
        println("GDP Growth Vol:      $(round(growth_volatility, digits=2))%")
    else
        println("GDP Growth Rate:     N/A (insufficient data)")
    end
    
    avg_ue = isempty(valid_ue) ? 100.0 : mean(valid_ue)
    println("Unemployment Rate:   $(round(avg_ue, digits=2))%")
    
    ue_volatility = isempty(valid_ue) ? 0.0 : std(valid_ue)
    println("Unemployment Vol:    $(round(ue_volatility, digits=2))%")
    println()
    
    # Check for success criteria
    println("="^60)
    println("SUCCESS CRITERIA CHECK")
    println("="^60)
    
    success = true
    issues = String[]
    
    if isnan(model.GDP)
        push!(issues, "✗ GDP is NaN")
        success = false
    else
        println("✓ GDP is finite: $(round(model.GDP, digits=2))")
    end
    
    if model.Ue >= 0.99
        push!(issues, "✗ Unemployment ~100%: $(round(model.Ue*100, digits=1))%")
        success = false
    else
        println("✓ Unemployment < 100%: $(round(model.Ue*100, digits=1))%")
    end
    
    if model.L == 0
        push!(issues, "✗ No workers employed")
        success = false
    else
        println("✓ Workers employed: $(model.L) / $(model.Ls)")
    end
    
    if isnan(model.wAvg)
        push!(issues, "✗ Average wage is NaN")
        success = false
    else
        println("✓ Average wage is finite: $(round(model.wAvg, digits=2))")
    end
    
    if avg_ue > 50.0
        push!(issues, "⚠ Average unemployment quite high: $(round(avg_ue, digits=1))%")
    else
        println("✓ Average unemployment reasonable: $(round(avg_ue, digits=1))%")
    end
    
    println()
    
    if success && isempty(issues)
        println("="^60)
        println("✓✓✓ ALL CHECKS PASSED! ✓✓✓")
        println("="^60)
        println()
        println("The model is now functioning correctly!")
        println("- GDP is calculated properly")
        println("- Workers are finding employment")
        println("- No NaN errors")
    else
        println("="^60)
        println("ISSUES FOUND:")
        println("="^60)
        for issue in issues
            println("  $issue")
        end
    end
    
catch e
    println()
    println("="^60)
    println("✗ ERROR DURING SIMULATION")
    println("="^60)
    println()
    println("Error: ", e)
    println()
    println("Stack trace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
    end
    
    # Show model state at failure
    println()
    println("Model state at failure:")
    println("  t = $(model.t)")
    println("  GDP = $(model.GDP)")
    println("  Employment = $(model.L) / $(model.Ls)")
    println("  Unemployment = $(round(model.Ue * 100, digits=1))%")
    println("  wAvg = $(model.wAvg)")
    println("  CPI = $(model.CPI)")
    println("  Firm1 count = $(length(model.firm1_ids))")
    println("  Firm2 count = $(length(model.firm2_ids))")
end

println()
