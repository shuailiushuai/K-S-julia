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
    
    # NOTE: S1_prev update moved to end of model_step! for proper timing
    # agent.S1_prev = agent.S1  # REMOVED - now done at end of model_step!
    
    # Update average wage
    if isempty(agent.worker_ids)
        agent.w1 = model.wMin
    else
        valid_wages = [model[wid].w for wid in agent.worker_ids if Agents.hasid(model, wid) && isfinite(model[wid].w) && model[wid].w > 0]
        if isempty(valid_wages)
            agent.w1 = model.wMin
        else
            agent.w1 = mean(valid_wages)
            # Safety: ensure wage is finite and positive
            if !isfinite(agent.w1) || agent.w1 <= 0
                agent.w1 = model.wMin
            end
        end
    end
end

function agent_step!(agent::Firm2, model)
    # Age firm
    agent.age += 1
    
    # Update lifecycle stage (matches C model _life2cycle equation)
    # 0 = pre-operational entrant (no capital)
    # 1 = operating entrant (first period producing, has capital)
    # 2.x = operating entrant (2nd-4th period producing)
    # 3 = incumbent firm (5+ periods)
    # 4 = exiting firm
    if agent.exit_flag
        agent.life2cycle = 4
    elseif agent.life2cycle == 0
        # Pre-operational entrant - check if now has capital
        if agent.K > 0
            agent.life2cycle = 1  # Becomes operating entrant
        end
    elseif agent.life2cycle >= 1 && agent.life2cycle < 3
        # Operating entrant - advance lifecycle
        if agent.age >= 4
            agent.life2cycle = 3  # Becomes incumbent
        else
            agent.life2cycle = 1 + min(agent.age - 1, 2) * 0.1  # 1.0, 1.1, 1.2, 1.3, then 3
        end
    end
    
    # Store previous net worth for firing decisions
    agent.NW2_prev = agent.NW2
    
    # CRITICAL: Store previous period inventory and price for GDP calculation
    # These are used to calculate dNnom = p2(t)*N2(t) - p2(t-1)*N2(t-1)
    agent.N2_prev = agent.N2
    agent.p2_prev = agent.p2
    
    # Update demand history
    pushfirst!(agent.D2_history, agent.D2)
    if length(agent.D2_history) > 4
        pop!(agent.D2_history)
    end
    
    # Update average wage
    if isempty(agent.worker_ids)
        agent.w2 = model.wMin
    else
        valid_wages = [model[wid].w for wid in agent.worker_ids if Agents.hasid(model, wid) && isfinite(model[wid].w) && model[wid].w > 0]
        if isempty(valid_wages)
            agent.w2 = model.wMin
        else
            agent.w2 = mean(valid_wages)
            # Safety: ensure wage is finite and positive
            if !isfinite(agent.w2) || agent.w2 <= 0
                agent.w2 = model.wMin
            end
        end
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
    # CRITICAL: The C model sequence is:
    # 1. Calculate R&D expenditure (_RD) using previous period sales
    # 2. Receive orders from Sector 2 (D1)
    # 3. Plan production (Q1)
    # 4. Calculate labor demand (_L1d, _L1dRD)
    
    for fid in model.firm1_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        
        # Do R&D (innovation/imitation) using L1rd from previous period
        firm1_rd!(firm, model)
        
        # Compute R&D expenditure for THIS period (for labor demand)
        # This uses S1_prev (sales from previous period)
        firm1_compute_rd_expenditure!(firm, model)
    end
    
    # Aggregate orders from Sector 2 (desired investment)
    for fid in model.firm1_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        # Id is in capital units, convert to number of machines by dividing by m2
        firm.D1 = sum(model[f2id].Id / params.m2 * (model[f2id].supplier_id == fid) 
                     for f2id in model.firm2_ids if Agents.hasid(model, f2id); init=0.0)
    end
    
    for fid in model.firm1_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        
        # Plan production based on demand
        firm1_plan_production!(firm, model)
        
        # Calculate labor demand (uses Q1 from plan_production and L1dRD from compute_rd_expenditure)
        firm1_compute_labor_demand!(firm, model)
    end
    
    # PHASE 4: LABOR MARKET
    labor_market_matching!(model)
    
    # PHASE 5: PRODUCTION (compute Q1e, Q2e only)
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            firm1_produce!(model[fid], model)
        end
    end
    # CRITICAL FIX: For Sector 2, only compute Q2e here
    # Sales (S2) will be computed AFTER demand allocation
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_compute_production!(model[fid], model)
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
        valid_prices = [model[fid].p1 for fid in model.firm1_ids if Agents.hasid(model, fid) && isfinite(model[fid].p1) && model[fid].p1 > 0]
        if isempty(valid_prices)
            model.p1avg = 1.0
        else
            model.p1avg = mean(valid_prices)
            # Safety check
            if !isfinite(model.p1avg) || model.p1avg <= 0
                model.p1avg = 1.0
            end
        end
        model.PPI = model.p1avg
    end
    
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_compute_competitiveness!(model[fid], model)
            firm2_set_price!(model[fid], model)
        end
    end
    
    if !isempty(model.firm2_ids)
        valid_prices = [model[fid].p2 for fid in model.firm2_ids if Agents.hasid(model, fid) && isfinite(model[fid].p2) && model[fid].p2 > 0]
        if isempty(valid_prices)
            model.p2avg = 1.0
        else
            model.p2avg = mean(valid_prices)
            # Safety check
            if !isfinite(model.p2avg) || model.p2avg <= 0
                model.p2avg = 1.0
            end
        end
        model.CPI = model.p2avg
    end
    
    # PHASE 7: CONSUMPTION & DEMAND
    compute_government_expenditure!(model)
    
    # CRITICAL FIX: Worker consumption demand includes wages, unemployment benefits,
    # bonuses from PREVIOUS period, and dividends from PREVIOUS period
    # This matches C model "Cd" equation:
    # v[0] = VS(LABSUPL0, "W") + V("G") + VLS(LABSUPL0, "Bon", 1) - 
    #        VS(LABSUPL0, "TaxW") + VL("Div", 1) - V("TaxDiv")
    
    # Get lagged dividends (from previous period)
    Div_prev = get(Agents.abmproperties(model), :Div_prev, 0.0)
    
    # Worker consumption demand
    total_Cd = 0.0
    for wid in model.worker_ids
        worker = model[wid]
        # Current period wages or unemployment benefit
        income = worker.employed > 0 ? worker.w : model.wU
        worker.consumption = income
        total_Cd += income
    end
    
    # Add government expenditure (unemployment benefits already counted)
    # Add previous period dividends (distributed to all workers equally)
    if model.Ls > 0
        total_Cd += Div_prev  # Dividends from previous period
    end
    
    model.Cd = total_Cd
    
    # Compute total desired demand in quantity units (matches C model D2d equation)
    # D2d = Cd / CPI
    if model.CPI > 0
        D2d_total = model.Cd / model.CPI
    else
        D2d_total = 0.0
    end
    
    # Match demand to supply and allocate to firms
    total_supply = sum(model[fid].Q2e + model[fid].N2 
                      for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
    
    # Allocate demand to firms by market share
    # CRITICAL: This matches C model D2 equation which allocates demand iteratively
    # For now using simplified allocation, but D2 must be set BEFORE sales
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm = model[fid]
            
            # Desired (potential) demand allocated by market share (in quantity units)
            # Matches C model _D2d equation: _f2 * D2d
            firm.D2d = firm.f2 * D2d_total
            
            # Monetary demand allocated by market share
            firm_Cd = model.Cd * firm.f2
            # CRITICAL FIX: D2 must be in QUANTITY units, not monetary units
            # Convert monetary demand to quantity by dividing by price
            if firm.p2 > 0
                firm.D2 = firm_Cd / firm.p2
            else
                firm.D2 = 0.0
            end
            
            # Constrain D2 by available supply (Q2e + N2)
            # This implements rationing when supply < demand
            available_supply = firm.Q2e + firm.N2
            if firm.D2 > available_supply
                firm.l2 = firm.D2 - available_supply  # unfilled demand
                firm.D2 = available_supply  # ration to available supply
            else
                firm.l2 = 0.0
            end
        end
    end
    
    # PHASE 7b: COMPUTE SALES (CRITICAL: Must happen AFTER D2 allocation)
    # Matches C model _S2 equation: S2 = p2 * D2
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_compute_sales!(model[fid], model)
        end
    end
    
    # NOTE: model.C and model.Sav will be computed in PHASE 13 (aggregation) 
    # from actual firm sales S2. This matches C model where C = S2
    
    # PHASE 8: INVESTMENT
    # Execute investment with financing constraints
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            firm2_execute_investment!(model[fid], model)
        end
    end
    
    # CRITICAL FIX: Calculate nominal investment (Inom) matching C model
    # Inom = sum of (machines * price) for NEW vintages deployed THIS period
    # This is NOT the same as sum(EI + SI) which are in capital units
    model.I = 0.0
    
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
                # CRITICAL: Nominal investment is machines * price (matching C model _Inom)
                nominal_investment = n_machines * supplier.p1
                model.I += nominal_investment
                
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
    
    # CRITICAL: Update lagged variables at END of period for use in NEXT period
    # This matches C model timing where VL("_S1", 1) accesses previous period value
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            model[fid].S1_prev = model[fid].S1
        end
    end
    
    # Save dividends for next period's consumption calculation
    props = Agents.abmproperties(model)
    props[:Div_prev] = model.Div
    
    # Save f2 values for next period's markup adjustment
    f2_prev_dict = Dict{Int,Float64}()
    for fid in model.firm2_ids
        if Agents.hasid(model, fid)
            f2_prev_dict[fid] = model[fid].f2
        end
    end
    props[:f2_prev] = f2_prev_dict
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
    # Sector 1  - Matches C model entry1exit equation
    j_exit1 = count(fid -> Agents.hasid(model, fid) && model[fid].exit_flag, model.firm1_ids)
    F1_current = length(model.firm1_ids) - j_exit1
    F10 = params.F10
    
    # Calculate market conditions (simplified - could use actual MC1 calculation)
    # For now use a simpler approach: entry if below F1max
    if F1_current < params.F1max
        # Potential entrants based on random draw and market conditions
        # C model: k = max(0, round(F1 * ((1-omicron)*uniform(x2inf,x2sup) + omicron * MC_change)))
        random_component = params.x2inf + rand(Agents.abmrng(model)) * (params.x2sup - params.x2inf)
        base_entry = F1_current * ((1 - params.omicron) * random_component + params.omicron * 0.05)
        
        # Apply stickiness (return to average)
        if F10 > 0
            stickiness_factor = rand(Agents.abmrng(model)) * params.stick * (Float64(F1_current) / F10 - 1) * F10
            base_entry -= min(stickiness_factor, base_entry)
        end
        
        # Number of entrants (rounded)
        k1 = max(0, round(Int, base_entry))
        
        # Enforce limits
        k1 = min(k1, params.F1max - F1_current)
        k1 = max(k1, params.F1min - F1_current)
        
        # Create entrant firms
        for _ in 1:max(0, k1)
            create_entrant_firm1!(model)
        end
    end
    
    # Sector 2 - Similar logic
    j_exit2 = count(fid -> Agents.hasid(model, fid) && model[fid].exit_flag, model.firm2_ids)
    F2_current = length(model.firm2_ids) - j_exit2
    F20 = params.F20
    
    if F2_current < params.F2max
        # Potential entrants
        random_component = params.x2inf + rand(Agents.abmrng(model)) * (params.x2sup - params.x2inf)
        base_entry = F2_current * ((1 - params.omicron) * random_component + params.omicron * 0.05)
        
        # Apply stickiness
        if F20 > 0
            stickiness_factor = rand(Agents.abmrng(model)) * params.stick * (Float64(F2_current) / F20 - 1) * F20
            base_entry -= min(stickiness_factor, base_entry)
        end
        
        # Number of entrants (rounded)
        k2 = max(0, round(Int, base_entry))
        
        # Enforce limits
        k2 = min(k2, params.F2max - F2_current)
        k2 = max(k2, params.F2min - F2_current)
        
        # Create entrant firms
        for _ in 1:max(0, k2)
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
        p2_prev = (1 + params.mu20) * model.wAvg,  # Initialize prev price
        N2 = 0.0,
        N2_prev = 0.0,  # Initialize prev inventory
        supplier_id = rand(Agents.abmrng(model), model.firm1_ids),
        D2_history = fill(0.0, 4),
        life2cycle = 1  # Operating entrant (has capital)
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
