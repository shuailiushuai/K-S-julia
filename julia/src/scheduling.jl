"""
    scheduling.jl

Time-step scheduling and agent stepping functions.
Implements the main time-step sequence from fun_KS.cpp.
"""

"""
    agent_step!(agent, model)

Execute one time step for an individual agent.
Called automatically by Agents.jl for each agent.
"""
function agent_step!(agent::Worker, model)
    worker_update_search_probability!(agent, model)
    worker_update_reservation_wage!(agent, model)
    worker_update_skills!(agent, model)
    worker_age!(agent, model)
    
    # Update tenure
    if agent.employed > 0
        agent.Te += 1
    else
        agent.Te = min(0, agent.Te - 1)  # Track unemployment duration
    end
end

function agent_step!(agent::Firm1, model)
    # Age firm
    agent.age += 1
    
    # Store previous period sales for R&D calculation
    agent.S1_prev = agent.S1
    
    # Update average wage
    if isempty(agent.worker_ids)
        agent.w1 = model.wMin
    else
        valid_wages = [model[wid].w for wid in agent.worker_ids if Agents.hasid(model, wid)]
        agent.w1 = isempty(valid_wages) ? model.wMin : mean(valid_wages)
    end
end

function agent_step!(agent::Firm2, model)
    # Age firm
    agent.age += 1
    
    # Store previous net worth for firing decisions
    agent.NW2_prev = agent.NW2
    
    # Update demand history
    pushfirst!(agent.D2_history, agent.D2)
    if length(agent.D2_history) > 4
        pop!(agent.D2_history)
    end
    
    # Update average wage
    if isempty(agent.worker_ids)
        agent.w2 = model.wMin
    else
        valid_wages = [model[wid].w for wid in agent.worker_ids if Agents.hasid(model, wid)]
        agent.w2 = isempty(valid_wages) ? model.wMin : mean(valid_wages)
    end
end

function agent_step!(agent::Bank, model)
    # Banks are passive, updated in model_step!
    nothing
end

"""
    model_step!(model)

Execute one complete time step of the model.
Implements the scheduling sequence from timeStep equation in fun_KS.cpp.
"""
function model_step!(model)
    params = model.params
    model.t += 1
    
    # Reset bailouts
    model.Gbail = 0.0
    
    # PHASE 1: MONETARY POLICY
    update_central_bank_rate!(model)
    for bid in model.bank_ids
        bank = model[bid]
        bank_update_interest_rates!(bank, model)
    end
    
    # PHASE 2: EXPECTATION & PLANNING (Sector 2)
    for fid in model.firm2_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        firm2_form_expectations!(firm, model)
        firm2_plan_production!(firm, model)
        firm2_compute_labor_demand!(firm, model)
        firm2_decide_investment!(firm, model)
    end
    
    # PHASE 3: R&D & PRODUCTION PLANNING (Sector 1)
    for fid in model.firm1_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        firm1_rd!(firm, model)
        # Aggregate orders from Sector 2
        firm.D1 = sum(model[f2id].Id * (model[f2id].supplier_id == fid) 
                     for f2id in model.firm2_ids if Agents.hasid(model, f2id); init=0.0)
        firm1_compute_labor_demand!(firm, model)
        firm1_plan_production!(firm, model)
    end
    
    # PHASE 4: LABOR MARKET
    labor_market_matching!(model)
    
    # PHASE 5: PRODUCTION
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm1_produce!(model[fid], model)
        end
    end
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_produce!(model[fid], model)
        end
    end
    
    # PHASE 6: PRICING
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm1_set_price!(model[fid], model)
        end
    end
    
    # Update average prices
    if !isempty(model.firm1_ids)
        valid_prices = [model[fid].p1 for fid in model.firm1_ids if Agents.hasid(model, fid)]
        model.p1avg = isempty(valid_prices) ? 1.0 : mean(valid_prices)
        model.PPI = model.p1avg
    end
    
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_compute_competitiveness!(model[fid], model)
            firm2_set_price!(model[fid], model)
        end
    end
    
    if !isempty(model.firm2_ids)
        valid_prices = [model[fid].p2 for fid in model.firm2_ids if Agents.hasid(model, fid)]
        model.p2avg = isempty(valid_prices) ? 1.0 : mean(valid_prices)
        model.CPI = model.p2avg
    end
    
    # PHASE 7: CONSUMPTION & DEMAND
    compute_government_expenditure!(model)
    
    # Worker consumption demand
    total_Cd = 0.0
    for wid in model.worker_ids
        worker = model[wid]
        income = worker.employed > 0 ? worker.w : model.wU
        worker.consumption = income
        total_Cd += income
    end
    model.Cd = total_Cd
    
    # Match demand to supply
    total_supply = sum(model[fid].Q2e + model[fid].N2 
                      for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    
    if total_supply >= model.Cd
        # Supply sufficient
        model.C = model.Cd
        model.Sav = 0.0
        # Allocate demand to firms by market share
        for fid in model.firm2_ids
            if Agents.hasid(model, fid)
                firm = model[fid]
                firm.D2 = model.Cd * firm.f2
            end
        end
    else
        # Rationing
        model.C = total_supply
        model.Sav = model.Cd - total_supply
        model.SavAcc += model.Sav
        for fid in model.firm2_ids
            if Agents.hasid(model, fid)
                firm = model[fid]
                firm.D2 = total_supply * firm.f2
            end
        end
    end
    
    # PHASE 8: INVESTMENT
    # Execute investment with financing constraints
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_execute_investment!(model[fid], model)
        end
    end
    
    model.I = sum((model[fid].EI + model[fid].SI) 
                  for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    
    # Add new vintages for successful investments
    for fid in model.firm2_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        total_investment = firm.EI + firm.SI
        if total_investment > 0 && firm.supplier_id > 0 && Agents.hasid(model, firm.supplier_id)
            # Add new vintage
            supplier = model[firm.supplier_id]
            n_machines = round(Int, total_investment / params.m2)
            if n_machines > 0
                vintage_id = model.t * 10000 + firm.supplier_id
                firm.vintages[vintage_id] = (
                    t0 = model.t,
                    supplier_id = firm.supplier_id,
                    A = supplier.A,
                    sVp = 1.0,
                    sVavg = 1.0,
                    machines = n_machines,
                    price = supplier.p1
                )
                firm.K += total_investment
            end
        end
    end
    
    # PHASE 9: FINANCE
    for bid in model.bank_ids
        bank = model[bid]
        bank_collect_deposits!(bank, model)
        bank_evaluate_credit!(bank, model)
    end
    
    for bid in model.bank_ids
        bank_allocate_credit!(model[bid], model)
    end
    
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm1_update_finances!(model[fid], model)
        end
    end
    
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_update_finances!(model[fid], model)
        end
    end
    
    for bid in model.bank_ids
        bank = model[bid]
        bank_manage_reserves!(bank, model)
        bank_trade_bonds!(bank, model)
        profit = bank_compute_profits!(bank, model)
        bank.NWb += profit * (1 - params.dB)
        bank_check_bailout!(bank, model)
    end
    
    # PHASE 10: GOVERNMENT
    collect_taxes!(model)
    update_public_finances!(model)
    update_minimum_wage!(model)
    
    # PHASE 11: MARKET DYNAMICS
    update_market_shares!(model)
    
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm1_send_brochures!(model[fid], model)
        end
    end
    
    # PHASE 12: ENTRY/EXIT
    execute_entry_exit!(model)
    
    # PHASE 13: AGGREGATION & STATISTICS
    compute_aggregates!(model)
    
    # PHASE 14: REGIME CHANGE
    if model.t == params.TregChg && params.TregChg > 0
        execute_regime_change!(model)
    end
    
    # Update history
    push!(model.GDP_history, model.GDP)
    if length(model.GDP_history) > params.mPer
        popfirst!(model.GDP_history)
    end
    
    push!(model.CPI_history, model.CPI)
    if length(model.CPI_history) > params.mPer
        popfirst!(model.CPI_history)
    end
    
    # Compute inflation
    if length(model.CPI_history) >= 2
        model.inflation = (model.CPI - model.CPI_history[end-1]) / model.CPI_history[end-1]
    end
end

"""
    execute_entry_exit!(model)

Handle firm entry and exit.
"""
function execute_entry_exit!(model)
    params = model.params
    
    # Exit firms marked for exit
    for fid in model.firm1_ids
        if Agents.hasid(model, fid) && model[fid].exit_flag
            Agents.remove_agent!(model[fid], model)
            filter!(id -> id != fid, model.firm1_ids)
        end
    end
    
    for fid in model.firm2_ids
        if Agents.hasid(model, fid) && model[fid].exit_flag
            Agents.remove_agent!(model[fid], model)
            filter!(id -> id != fid, model.firm2_ids)
        end
    end
    
    # Check remaining firms for exit
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm1_check_exit!(model[fid], model)
        end
    end
    
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_check_exit!(model[fid], model)
        end
    end
    
    # Entry (stochastic based on market conditions)
    # Sector 1
    if length(model.firm1_ids) < params.F1max
        entry_prob = params.omicron * 0.1  # Simplified
        if rand(Agents.abmrng(model)) < entry_prob
            create_entrant_firm1!(model)
        end
    end
    
    # Sector 2
    if length(model.firm2_ids) < params.F2max
        entry_prob = params.omicron * 0.1  # Simplified
        if rand(Agents.abmrng(model)) < entry_prob
            create_entrant_firm2!(model)
        end
    end
end

"""
    create_entrant_firm1!(model)

Create a new entrant firm in sector 1.
"""
function create_entrant_firm1!(model)
    params = model.params
    
    # Technology close to frontier
    A = model.A1 * (1 + params.x5 * rand(Agents.abmrng(model)))
    nw_factor = params.Phi3 + rand(Agents.abmrng(model)) * (params.Phi4 - params.Phi3)
    nw = params.NW10 * nw_factor
    
    # Initial price based on productivity
    c1 = model.wAvg / (A * params.m1)
    p1 = (1 + params.mu1) * c1
    
    # Initial demand (1 machine per client under fair share entry)
    D1 = length(model.firm2_ids) / max(1, length(model.firm1_ids))
    
    # Initial R&D based on expected sales
    RD = max(params.nu * D1 * p1, model.wAvg)
    
    firm = Firm1(
        id = Agents.nextid(model),
        A = A,
        B = A,
        Atau = A,
        Btau = A,
        NW1 = nw,
        mu1 = params.mu1,
        w1 = model.wAvg,
        c1 = c1,
        p1 = p1,
        D1 = D1,
        S1 = D1 * p1,
        S1_prev = D1 * p1,
        L1rd = floor(RD / model.wAvg),
        L1dRD = floor(RD / model.wAvg)
    )
    
    Agents.add_agent!(firm, model)
    push!(model.firm1_ids, firm.id)
    
    # Assign to random bank
    firm.bank_id = rand(Agents.abmrng(model), model.bank_ids)
    push!(model[firm.bank_id].client1_ids, firm.id)
end

"""
    create_entrant_firm2!(model)

Create a new entrant firm in sector 2.
"""
function create_entrant_firm2!(model)
    params = model.params
    
    nw_factor = params.Phi1 + rand(Agents.abmrng(model)) * (params.Phi2 - params.Phi1)
    nw = params.NW20 * nw_factor
    k = nw / 10.0
    
    firm = Firm2(
        id = Agents.nextid(model),
        K = k,
        NW2 = nw,
        mu2 = params.mu20,
        w2 = model.wAvg,
        p2 = (1 + params.mu20) * model.wAvg,
        supplier_id = rand(Agents.abmrng(model), model.firm1_ids),
        D2_history = fill(0.0, 4)
    )
    
    # Initial vintage
    vintage_id = model.t * 10000
    firm.vintages[vintage_id] = (
        t0 = model.t,
        supplier_id = firm.supplier_id,
        A = model.A1,
        sVp = 1.0,
        sVavg = 1.0,
        machines = round(Int, k),
        price = model.p1avg
    )
    
    Agents.add_agent!(firm, model)
    push!(model.firm2_ids, firm.id)
    
    # Assign to random bank
    firm.bank_id = rand(Agents.abmrng(model), model.bank_ids)
    push!(model[firm.bank_id].client2_ids, firm.id)
end

"""
    execute_regime_change!(model)

Execute regime change at specified time.
"""
function execute_regime_change!(model)
    params = model.params
    
    # Update parameters to post-change values
    # (This would update various parameters marked with "Chg" suffix)
    # For simplicity, we just mark that change occurred
    props = Agents.abmproperties(model)
    props[:regime_changed] = true
end
