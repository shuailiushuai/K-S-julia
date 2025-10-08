"""
Example: Running the K+S Labor Market Model

This script demonstrates how to run the K+S model with different configurations
and analyze the results.
"""

include("ks_labor_model.jl")

println("="^80)
println("K+S Labor Market Model - Example Simulations")
println("="^80)

# Example 1: Quick test run with default parameters
println("\n" * "="^80)
println("Example 1: Default Configuration (100 steps)")
println("="^80)

params1 = get_default_parameters()
params1[:max_steps] = 100
params1[:n_workers] = 500
params1[:n_firms1] = 30
params1[:n_firms2] = 100

println("\nRunning simulation...")
model1, adf1, mdf1 = run_simulation(n_steps=100, parameters=params1)
print_summary(mdf1)

# Example 2: Higher unemployment benefits
println("\n" * "="^80)
println("Example 2: Higher Unemployment Benefits (phi = 0.8)")
println("="^80)

params2 = get_default_parameters()
params2[:max_steps] = 100
params2[:n_workers] = 500
params2[:n_firms1] = 30
params2[:n_firms2] = 100
params2[:unemployment_benefit_ratio] = 0.8  # Higher benefits

println("\nRunning simulation...")
model2, adf2, mdf2 = run_simulation(n_steps=100, parameters=params2)
print_summary(mdf2)

# Example 3: More flexible labor market
println("\n" * "="^80)
println("Example 3: Flexible Labor Market (search mode = always)")
println("="^80)

params3 = get_default_parameters()
params3[:max_steps] = 100
params3[:n_workers] = 500
params3[:n_firms1] = 30
params3[:n_firms2] = 100
params3[:search_mode] = 0  # Always search
params3[:applications_employed] = 3  # More applications

println("\nRunning simulation...")
model3, adf3, mdf3 = run_simulation(n_steps=100, parameters=params3)
print_summary(mdf3)

# Compare results
println("\n" * "="^80)
println("Comparison of Scenarios")
println("="^80)

println("\nAverage Unemployment Rate:")
println("  Default configuration:     ", round(mean(mdf1.unemployment_rate) * 100, digits=2), "%")
println("  Higher UI benefits:        ", round(mean(mdf2.unemployment_rate) * 100, digits=2), "%")
println("  Flexible labor market:     ", round(mean(mdf3.unemployment_rate) * 100, digits=2), "%")

println("\nAverage Real GDP:")
println("  Default configuration:     ", round(mean(mdf1.gdp_real), digits=2))
println("  Higher UI benefits:        ", round(mean(mdf2.gdp_real), digits=2))
println("  Flexible labor market:     ", round(mean(mdf3.gdp_real), digits=2))

println("\nAverage Wage:")
println("  Default configuration:     ", round(mean(mdf1.wage_average), digits=2))
println("  Higher UI benefits:        ", round(mean(mdf2.wage_average), digits=2))
println("  Flexible labor market:     ", round(mean(mdf3.wage_average), digits=2))

println("\n" * "="^80)
println("Examples completed!")
println("="^80)

# Optional: Save data to CSV
println("\nTo save results to CSV, uncomment the following lines:")
println("# using CSV")
println("# CSV.write(\"scenario1_model_data.csv\", mdf1)")
println("# CSV.write(\"scenario2_model_data.csv\", mdf2)")
println("# CSV.write(\"scenario3_model_data.csv\", mdf3)")

println("\nTo create plots, you can use:")
println("# using Plots")
println("# plot(mdf1.step, mdf1.unemployment_rate, label=\"Default\")")
println("# plot!(mdf2.step, mdf2.unemployment_rate, label=\"High UI\")")
println("# plot!(mdf3.step, mdf3.unemployment_rate, label=\"Flexible\")")
println("# xlabel!(\"Time\"); ylabel!(\"Unemployment Rate\")")
