"""
    example.jl

Example usage of the K+S model Julia implementation.
Demonstrates basic model setup, execution, and analysis.
"""

# Add the package to the path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Plots
using DataFrames
using Statistics

println("K+S Model Julia Implementation Example")
println("="^60)
println()

# Load baseline parameters
println("Loading baseline parameters...")
params = load_baseline_parameters()

# Adjust for faster execution in example
params.T = 200  # Shorter simulation
params.F10 = 20  # Fewer firms
params.F20 = 80
params.Ls0 = 2000  # Fewer workers

println("Creating model with:")
println("  - $(params.F10) capital-good firms")
println("  - $(params.F20) consumption-good firms")
println("  - $(params.B) banks")
println("  - $(params.Ls0) workers")
println()

# Initialize model
println("Initializing model...")
model = initialize_model(params)

println("Model initialized successfully!")
println("  - Total agents: $(nagents(model))")
println()

# Run simulation
println("Running simulation for $(params.T) periods...")
println()

data = run_simulation(model, params.T, collect_data=true)

println()
println("Simulation completed!")
println()

# Generate summary report
create_summary_report(data)

# Create visualizations
println("Generating visualizations...")
println()

# Time series plots
p1 = plot_time_series(data)
savefig(p1, joinpath(@__DIR__, "plots", "time_series.png"))
println("Saved: plots/time_series.png")

# Growth rates
p2 = plot_growth_rates(data)
savefig(p2, joinpath(@__DIR__, "plots", "growth_rates.png"))
println("Saved: plots/growth_rates.png")

# Sectoral dynamics
p3 = plot_sectoral_dynamics(data)
savefig(p3, joinpath(@__DIR__, "plots", "sectoral_dynamics.png"))
println("Saved: plots/sectoral_dynamics.png")

# Labor market
p4 = plot_labor_market(data)
savefig(p4, joinpath(@__DIR__, "plots", "labor_market.png"))
println("Saved: plots/labor_market.png")

# Financial variables
p5 = plot_financial_variables(data)
savefig(p5, joinpath(@__DIR__, "plots", "financial_variables.png"))
println("Saved: plots/financial_variables.png")

println()
println("All visualizations saved!")
println()

# Save data
println("Saving simulation data...")
using CSV
CSV.write(joinpath(@__DIR__, "output", "simulation_data.csv"), data)
println("Saved: output/simulation_data.csv")
println()

println("="^60)
println("Example completed successfully!")
println("="^60)
