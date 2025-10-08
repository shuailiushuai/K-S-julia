"""
    visualization.jl

Visualization functions for model results.
"""

using Plots

"""
    plot_time_series(data::DataFrame)

Plot key macroeconomic time series.
"""
function plot_time_series(data::DataFrame)
    p1 = plot(data.t, data.GDP, label="GDP", title="Real GDP", xlabel="Time", ylabel="GDP")
    p2 = plot(data.t, data.Ue .* 100, label="Unemployment", title="Unemployment Rate", xlabel="Time", ylabel="%")
    p3 = plot(data.t, data.inflation .* 100, label="Inflation", title="Inflation Rate", xlabel="Time", ylabel="%")
    p4 = plot(data.t, data.A2, label="Productivity", title="Sector 2 Productivity", xlabel="Time", ylabel="A2")
    
    plot(p1, p2, p3, p4, layout=(2,2), size=(1200, 800))
end

"""
    plot_growth_rates(data::DataFrame)

Plot growth rates of key variables.
"""
function plot_growth_rates(data::DataFrame)
    # Compute growth rates
    gdp_growth = diff(log.(data.GDP))
    prod_growth = diff(log.(data.A2))
    
    p1 = plot(data.t[2:end], gdp_growth .* 100, label="GDP Growth", title="GDP Growth Rate", xlabel="Time", ylabel="%")
    p2 = plot(data.t[2:end], prod_growth .* 100, label="Productivity Growth", title="Productivity Growth", xlabel="Time", ylabel="%")
    
    plot(p1, p2, layout=(1,2), size=(1200, 400))
end

"""
    plot_sectoral_dynamics(data::DataFrame)

Plot sectoral variables.
"""
function plot_sectoral_dynamics(data::DataFrame)
    p1 = plot(data.t, data.F1, label="Sector 1", title="Number of Firms")
    plot!(p1, data.t, data.F2, label="Sector 2")
    
    p2 = plot(data.t, data.A1, label="Sector 1", title="Average Productivity")
    plot!(p2, data.t, data.A2, label="Sector 2")
    
    plot(p1, p2, layout=(1,2), size=(1200, 400))
end

"""
    plot_labor_market(data::DataFrame)

Plot labor market dynamics.
"""
function plot_labor_market(data::DataFrame)
    p1 = plot(data.t, data.Ue .* 100, label="Unemployment Rate", title="Labor Market", ylabel="%")
    p2 = plot(data.t, data.wAvg, label="Average Wage", title="Wages")
    
    plot(p1, p2, layout=(1,2), size=(1200, 400))
end

"""
    plot_financial_variables(data::DataFrame)

Plot financial and fiscal variables.
"""
function plot_financial_variables(data::DataFrame)
    p1 = plot(data.t, data.r .* 100, label="Interest Rate", title="Financial Variables", ylabel="%")
    p2 = plot(data.t, data.Deb ./ data.GDPnom, label="Debt/GDP", title="Public Debt Ratio")
    
    plot(p1, p2, layout=(1,2), size=(1200, 400))
end

"""
    create_summary_report(data::DataFrame)

Create a comprehensive summary report of simulation results.
"""
function create_summary_report(data::DataFrame)
    println("="^60)
    println("K+S MODEL SIMULATION SUMMARY")
    println("="^60)
    println()
    
    println("Simulation Period: t = $(data.t[1]) to $(data.t[end])")
    println()
    
    println("MACROECONOMIC AGGREGATES (Final Period)")
    println("-"^60)
    println("GDP:                 ", round(data.GDP[end], digits=2))
    println("Consumption:         ", round(data.C[end], digits=2))
    println("Investment:          ", round(data.I[end], digits=2))
    println("Government:          ", round(data.G[end], digits=2))
    println()
    
    println("LABOR MARKET")
    println("-"^60)
    println("Employment:          ", data.L[end])
    println("Unemployment Rate:   ", round(data.Ue[end] * 100, digits=2), "%")
    println("Average Wage:        ", round(data.wAvg[end], digits=2))
    println()
    
    println("PRODUCTIVITY")
    println("-"^60)
    println("Sector 1:            ", round(data.A1[end], digits=3))
    println("Sector 2:            ", round(data.A2[end], digits=3))
    println()
    
    println("FINANCIAL VARIABLES")
    println("-"^60)
    println("Interest Rate:       ", round(data.r[end] * 100, digits=2), "%")
    println("Inflation:           ", round(data.inflation[end] * 100, digits=2), "%")
    println("Debt/GDP:            ", round(data.Deb[end] / data.GDPnom[end], digits=3))
    println()
    
    println("FIRM DYNAMICS")
    println("-"^60)
    println("Sector 1 Firms:      ", data.F1[end])
    println("Sector 2 Firms:      ", data.F2[end])
    println()
    
    # Compute averages
    println("AVERAGE VALUES (Full Period)")
    println("-"^60)
    println("GDP Growth Rate:     ", round(mean(diff(log.(data.GDP))) * 100, digits=2), "%")
    println("Unemployment Rate:   ", round(mean(data.Ue) * 100, digits=2), "%")
    println("Inflation Rate:      ", round(mean(data.inflation) * 100, digits=2), "%")
    println()
    
    # Volatility
    println("VOLATILITY (Standard Deviation)")
    println("-"^60)
    println("GDP Growth:          ", round(std(diff(log.(data.GDP))) * 100, digits=2), "%")
    println("Unemployment:        ", round(std(data.Ue) * 100, digits=2), "%")
    println()
    
    println("="^60)
end
