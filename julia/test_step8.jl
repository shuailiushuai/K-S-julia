"""
    test_step8.jl

Find NaN source at step 8.
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel
using Agents
using Printf
using Statistics

params = load_baseline_parameters()
params.T = 10
params.F10 = 5
params.F20 = 20
params.Ls0 = 200
params.B = 3

println("Initializing model...")
model = initialize_model(params)

for t in 1:10
    Agents.step!(model, 1)
    
    # Check for NaN values at each step
    @printf("Step %2d: GDP=%.2f, C=%.2f, I=%.2f, G=%.2f, CPI=%.3f, p2avg=%.3f, Q2=%.2f, wAvg=%.3f\n",
            t, model.GDP, model.C, model.I, model.G, model.CPI, model.p2avg, model.Q2, model.wAvg)
    
    if t == 7 || t == 8
        println("  Detailed check at step $t:")
        println("    GDPnom=$(model.GDPnom), GDPreal=$(model.GDPreal)")
        println("    CPI_history[1]=$(model.CPI_history[1])")
        
        # Check all Firm2 prices
        nan_count = 0
        for fid in model.firm2_ids
            if Agents.hasid(model, fid)
                firm = model[fid]
                if isnan(firm.p2) || isnan(firm.w2)
                    nan_count += 1
                    if nan_count <= 3
                        println("    Firm2[$fid]: p2=$(firm.p2), w2=$(firm.w2), c2=$(firm.c2)")
                        println("      workers=$(length(firm.worker_ids)), L2=$(firm.L2)")
                        if !isempty(firm.worker_ids)
                            println("      First 3 workers:")
                            for wid in firm.worker_ids[1:min(3, length(firm.worker_ids))]
                                if Agents.hasid(model, wid)
                                    worker = model[wid]
                                    println("        Worker[$wid]: w=$(worker.w), employed=$(worker.employed)")
                                end
                            end
                        end
                    end
                end
            end
        end
        if nan_count > 0
            println("    Total firms with NaN: $nan_count")
        end
    end
    
    if isnan(model.GDP)
        println("  ✗✗✗ GDP became NaN at step $t ✗✗✗")
        break
    end
end
