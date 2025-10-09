"""
    test_price_nan.jl

Focused test to find where prices become NaN.
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents
using Printf
using Statistics

params = load_baseline_parameters()
params.T = 3
params.F10 = 5
params.F20 = 20
params.Ls0 = 200
params.B = 3

println("Initializing model...")
model = initialize_model(params)

println("\n=== STEP 0 (Initial) ===")
println("Firm2[1] before any steps:")
firm = model[model.firm2_ids[1]]
println("  vintages: $(length(firm.vintages))")
for (vid, v) in firm.vintages
    println("    [$vid]: machines=$(v.machines), A=$(v.A), age=0")
end
println("  K=$(firm.K), w2=$(firm.w2)")
println("  p2=$(firm.p2), c2=$(firm.c2), mu2=$(firm.mu2)")

Agents.step!(model, 1)

println("\n=== STEP 1 ===")
println("After step 1:")
firm = model[model.firm2_ids[1]]
println("  vintages: $(length(firm.vintages))")
for (vid, v) in firm.vintages
    println("    [$vid]: machines=$(v.machines), A=$(v.A), age=$(model.t - v.t0)")
end
println("  K=$(firm.K), w2=$(firm.w2)")
A_avg = KSModel.firm2_average_productivity(firm)
println("  A_avg=$(A_avg)")
println("  c2=$(firm.c2), p2=$(firm.p2), mu2=$(firm.mu2)")
println("  Model p2avg=$(model.p2avg), CPI=$(model.CPI)")

Agents.step!(model, 1)

println("\n=== STEP 2 ===")
println("After step 2:")
firm = model[model.firm2_ids[1]]
println("  vintages: $(length(firm.vintages))")
for (vid, v) in firm.vintages
    println("    [$vid]: machines=$(v.machines), A=$(v.A), age=$(model.t - v.t0)")
end
println("  K=$(firm.K), w2=$(firm.w2)")
A_avg = KSModel.firm2_average_productivity(firm)
println("  A_avg=$(A_avg)")
if A_avg > 0
    println("  c2 would be: $(firm.w2 / A_avg)")
else
    println("  c2 would be: Inf (A_avg is 0!)")
end
println("  c2=$(firm.c2), p2=$(firm.p2), mu2=$(firm.mu2)")
println("  Model p2avg=$(model.p2avg), CPI=$(model.CPI)")

println("\n=== Checking all Firm2 prices at step 2 ===")
all_prices = Float64[]
for (i, fid) in enumerate(model.firm2_ids)
    if !Agents.hasid(model, fid)
        println("Firm2[$i] (id=$fid): REMOVED")
        continue
    end
    local firm = model[fid]
    local A_avg = KSModel.firm2_average_productivity(firm)
    println("Firm2[$i] (id=$fid): vintages=$(length(firm.vintages)), A_avg=$A_avg, p2=$(firm.p2), c2=$(firm.c2), w2=$(firm.w2)")
    if isnan(firm.p2)
        println("    ^^^ NaN price found!")
        println("    mu2=$(firm.mu2)")
        println("    vintages details:")
        for (vid, v) in firm.vintages
            println("      [$vid]: machines=$(v.machines), A=$(v.A)")
        end
    end
    push!(all_prices, firm.p2)
end
println("\nAll prices: $(length(all_prices)) firms")
println("Mean of all prices: $(mean(all_prices))")
println("Any NaN? $(any(isnan, all_prices))")
println("\nmodel.firm2_ids length: $(length(model.firm2_ids))")
println("Active Firm2 count: $(sum(Agents.hasid(model, fid) for fid in model.firm2_ids))")
