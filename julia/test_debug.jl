"""
Debug test to trace exactly what happens in initialization and first step.
"""

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using KSModel

println("="^60)
println("K+S Model Debug Test")
println("="^60)
println()

# Load parameters
params = load_baseline_parameters()
params.T = 3  # Only 3 periods for debugging
params.F10 = 3  # Very few firms
params.F20 = 5
params.Ls0 = 50  # Few workers
params.seed = 123

println("Parameters:")
println("  F10 = $(params.F10), F20 = $(params.F20), Ls0 = $(params.Ls0)")
println("  m1 = $(params.m1), m2 = $(params.m2)")
println("  nu = $(params.nu), mu1 = $(params.mu1), mu20 = $(params.mu20)")
println()

# Initialize model
println("Initializing model...")
model = initialize_model(params)
println("✓ Model initialized")
println("  Agents: $(Agents.nagents(model))")
println("  Firm1: $(length(model.firm1_ids))")
println("  Firm2: $(length(model.firm2_ids))")
println("  Workers: $(length(model.worker_ids))")
println()

# Check initial state
println("Initial state (t=0):")
println("  L = $(model.L) (employed)")
println("  U = $(model.U) (unemployed)")
println("  Ls = $(model.Ls) (labor force)")
println("  wAvg = $(model.wAvg)")
println()

# Check Firm1s
println("Firm1 initial state:")
for (i, fid) in enumerate(model.firm1_ids)
    firm = model[fid]
    println("  Firm1-$i (id=$(firm.id)):")
    println("    A=$(round(firm.A, digits=3)), B=$(round(firm.B, digits=3))")
    println("    L1=$(firm.L1), L1d=$(round(firm.L1d, digits=2)), L1rd=$(round(firm.L1rd, digits=2)), L1dRD=$(round(firm.L1dRD, digits=2))")
    println("    Q1=$(round(firm.Q1, digits=2)), D1=$(round(firm.D1, digits=2))")
    println("    S1=$(round(firm.S1, digits=2)), S1_prev=$(round(firm.S1_prev, digits=2))")
    println("    p1=$(round(firm.p1, digits=3)), c1=$(round(firm.c1, digits=3))")
    println("    w1=$(round(firm.w1, digits=3))")
    println("    NW1=$(round(firm.NW1, digits=2))")
end
println()

# Check Firm2s
println("Firm2 initial state:")
for (i, fid) in enumerate(model.firm2_ids[1:min(3, length(model.firm2_ids))])
    firm = model[fid]
    println("  Firm2-$i (id=$(firm.id)):")
    println("    K=$(round(firm.K, digits=2)), Kd=$(round(firm.Kd, digits=2))")
    println("    L2=$(firm.L2), L2d=$(round(firm.L2d, digits=2))")
    println("    Q2=$(round(firm.Q2, digits=2)), D2=$(round(firm.D2, digits=2)), D2e=$(round(firm.D2e, digits=2))")
    println("    Id=$(round(firm.Id, digits=2)), EId=$(round(firm.EId, digits=2)), SId=$(round(firm.SId, digits=2))")
    println("    supplier_id=$(firm.supplier_id)")
    println("    #vintages=$(length(firm.vintages))")
end
println()

# Try first step
println("="^60)
println("EXECUTING FIRST MODEL STEP (t=1)")
println("="^60)
println()

try
    # Call agent_step for all agents first
    println("Phase: Agent stepping...")
    for agent in Agents.allagents(model)
        try
            Agents.agent_step!(agent, model)
        catch e
            println("ERROR in agent_step! for agent $(agent.id):")
            println("  Type: $(typeof(agent))")
            println("  Error: $e")
            rethrow(e)
        end
    end
    println("✓ Agent stepping completed")
    println()
    
    # Call model_step
    println("Phase: Model stepping...")
    model_step!(model)
    println("✓ Model step completed")
    println()
    
    println("After step 1:")
    println("  t = $(model.t)")
    println("  L = $(model.L) (employed)")
    println("  U = $(model.U) (unemployed)")
    println("  GDP = $(round(model.GDP, digits=2))")
    println("  C = $(round(model.C, digits=2))")
    println("  I = $(round(model.I, digits=2))")
    println()
    
    # Check Firm1s after step
    println("Firm1 after step 1:")
    for (i, fid) in enumerate(model.firm1_ids)
        if !Agents.hasid(model, fid)
            println("  Firm1-$i: EXITED")
            continue
        end
        firm = model[fid]
        println("  Firm1-$i (id=$(firm.id)):")
        println("    L1=$(firm.L1), L1d=$(round(firm.L1d, digits=2)), L1rd=$(round(firm.L1rd, digits=2)), L1dRD=$(round(firm.L1dRD, digits=2))")
        println("    D1=$(round(firm.D1, digits=2)), Q1=$(round(firm.Q1, digits=2)), Q1e=$(round(firm.Q1e, digits=2))")
        println("    S1=$(round(firm.S1, digits=2)), S1_prev=$(round(firm.S1_prev, digits=2))")
    end
    println()
    
    # Check if any NaN values
    println("Checking for NaN values...")
    nan_found = false
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm = model[fid]
            for field in fieldnames(Firm1)
                val = getfield(firm, field)
                if val isa Number && isnan(val)
                    println("  WARNING: Firm1 $(firm.id).$field = NaN")
                    nan_found = true
                end
            end
        end
    end
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm = model[fid]
            for field in fieldnames(Firm2)
                val = getfield(firm, field)
                if val isa Number && isnan(val)
                    println("  WARNING: Firm2 $(firm.id).$field = NaN")
                    nan_found = true
                end
            end
        end
    end
    
    if !nan_found
        println("✓ No NaN values found")
    end
    println()
    
    println("="^60)
    println("✓ Test completed successfully!")
    println("="^60)
    
catch e
    println()
    println("="^60)
    println("ERROR during execution:")
    println("="^60)
    println(e)
    println()
    println("Stack trace:")
    for (exc, bt) in Base.catch_stack()
        showerror(stdout, exc, bt)
        println()
        println()
    end
end
