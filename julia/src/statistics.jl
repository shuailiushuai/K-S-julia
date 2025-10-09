"""
    statistics.jl

Statistical computation and data collection functions.
Corresponds to fun_KS_stats.h in C model.
"""

"""
    compute_aggregates!(model)

Compute macroeconomic aggregates and sectoral statistics.
"""
function compute_aggregates!(model)
    params = model.params
    
    # Sector 1 aggregates
    model.F1 = length(model.firm1_ids)
    model.L1 = sum(model[fid].L1 for fid in model.firm1_ids if Agents.hasid(model, fid); init=0)
    model.Q1 = sum(model[fid].Q1e for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    model.S1 = sum(model[fid].S1 for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    model.D1 = sum(model[fid].D1 for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    
    # Average productivity sector 1
    if !isempty(model.firm1_ids)
        valid_firms = [model[fid].A for fid in model.firm1_ids if Agents.hasid(model, fid)]
        model.A1 = isempty(valid_firms) ? 1.0 : mean(valid_firms)
    end
    
    # Sector 2 aggregates
    model.F2 = length(model.firm2_ids)
    model.L2 = sum(model[fid].L2 for fid in model.firm2_ids if Agents.hasid(model, fid); init=0)
    model.Q2 = sum(model[fid].Q2e for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    model.S2 = sum(model[fid].S2 for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    model.D2 = sum(model[fid].D2 for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    
    # CRITICAL FIX: Consumption equals actual sales revenue from sector 2
    # This matches C model: C = S2
    model.C = model.S2
    
    # Recalculate savings based on actual consumption vs desired
    # Sav = Cd - C (forced savings when supply < demand)
    if model.Cd > model.C
        model.Sav = model.Cd - model.C
    else
        model.Sav = 0.0
    end
    
    # Average productivity sector 2
    if !isempty(model.firm2_ids)
        total_k = sum(model[fid].K for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
        if total_k > 0
            weighted_A = sum(model[fid].K * firm2_average_productivity(model[fid]) 
                            for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
            model.A2 = weighted_A / total_k
        end
    end
    
    # GDP
    model.GDPnom = model.C + model.I + model.G
    
    # Real GDP - use current CPI as deflator, not historical
    # CRITICAL FIX: Use current CPI, not historical CPI from CPI_history
    deflator = max(model.CPI, 0.01)
    
    # Real GDP based on nominal GDP deflated by CPI
    # Alternative: could use actual output Q2 * p2avg / deflator
    model.GDPreal = model.GDPnom / deflator
    
    # Safety checks for GDP
    if !isfinite(model.GDPreal) || model.GDPreal < 0
        # Fallback: use actual production
        model.GDPreal = model.Q2 * model.p2avg / deflator
    end
    if !isfinite(model.GDPnom) || model.GDPnom < 0
        model.GDPnom = model.GDPreal * deflator
    end
    
    model.GDP = model.GDPreal
    
    # Dividends
    model.Div = sum(max(0.0, (model[fid].NW1 * params.d1)) 
                   for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
    model.Div += sum(max(0.0, (model[fid].NW2 * params.d2)) 
                    for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
end

"""
    collect_firm_data(model)

Collect firm-level data for analysis.
Returns a DataFrame.
"""
function collect_firm_data(model)
    firm_data = DataFrame(
        t = Int[],
        firm_id = Int[],
        sector = Int[],
        age = Int[],
        L = Int[],
        Q = Float64[],
        S = Float64[],
        p = Float64[],
        NW = Float64[],
        Deb = Float64[],
        f = Float64[],
        A = Float64[]
    )
    
    # Sector 1 firms
    for fid in model.firm1_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        push!(firm_data, (
            t = model.t,
            firm_id = fid,
            sector = 1,
            age = firm.age,
            L = firm.L1,
            Q = firm.Q1e,
            S = firm.S1,
            p = firm.p1,
            NW = firm.NW1,
            Deb = firm.Deb1,
            f = firm.f1,
            A = firm.A
        ))
    end
    
    # Sector 2 firms
    for fid in model.firm2_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        push!(firm_data, (
            t = model.t,
            firm_id = fid,
            sector = 2,
            age = firm.age,
            L = firm.L2,
            Q = firm.Q2e,
            S = firm.S2,
            p = firm.p2,
            NW = firm.NW2,
            Deb = firm.Deb2,
            f = firm.f2,
            A = firm2_average_productivity(firm)
        ))
    end
    
    return firm_data
end

"""
    collect_worker_data(model)

Collect worker-level data for analysis.
Returns a DataFrame.
"""
function collect_worker_data(model)
    worker_data = DataFrame(
        t = Int[],
        worker_id = Int[],
        employed = Int[],
        age = Int[],
        w = Float64[],
        s = Float64[],
        sV = Float64[],
        sT = Float64[],
        Te = Int[]
    )
    
    for wid in model.worker_ids
        if !Agents.hasid(model, wid)
            continue
        end
        worker = model[wid]
        push!(worker_data, (
            t = model.t,
            worker_id = wid,
            employed = worker.employed,
            age = worker.age,
            w = worker.w,
            s = worker.s,
            sV = worker.sV,
            sT = worker.sT,
            Te = worker.Te
        ))
    end
    
    return worker_data
end

"""
    collect_aggregate_data(model)

Collect aggregate macroeconomic data.
Returns a named tuple.
"""
function collect_aggregate_data(model)
    return (
        t = model.t,
        GDP = model.GDP,
        GDPnom = model.GDPnom,
        GDPreal = model.GDPreal,
        C = model.C,
        I = model.I,
        G = model.G,
        L = model.L,
        U = model.U,
        Ue = model.Ue,
        wAvg = model.wAvg,
        inflation = model.inflation,
        r = model.r,
        Deb = model.Deb,
        Tax = model.Tax,
        F1 = model.F1,
        F2 = model.F2,
        A1 = model.A1,
        A2 = model.A2,
        PPI = model.PPI,
        CPI = model.CPI
    )
end

"""
    run_simulation(model, n_steps; collect_data=true)

Run the model for n_steps time periods.
Optionally collect data at each step.
"""
function run_simulation(model, n_steps::Int; collect_data=true)
    if collect_data
        aggregate_data = []
        
        for step in 1:n_steps
            Agents.step!(model, 1)
            push!(aggregate_data, collect_aggregate_data(model))
            
            # Print progress every 50 steps
            if step % 50 == 0
                println("Step $step / $n_steps completed. GDP=$(round(model.GDP, digits=2)), Ue=$(round(model.Ue*100, digits=2))%")
            end
        end
        
        # Convert to DataFrame
        return DataFrame(aggregate_data)
    else
        Agents.step!(model, n_steps)
        return nothing
    end
end
