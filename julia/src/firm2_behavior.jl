"""
    firm2_behavior.jl

Behavioral functions for consumption-good firms (Firm2).
Implements expectation formation, investment, production, pricing, etc.
Corresponds to fun_KS_firm2.h in C model.
"""

"""
    firm2_form_expectations!(firm::Firm2, model)

Form adaptive demand expectations.
Matches C model _D2e equation with lifecycle awareness.
"""
function firm2_form_expectations!(firm::Firm2, model)
    params = model.params
    
    # Entrant with limited history uses optimistic expectations
    # Matches C model: if (life2cycle < 3) use max(D2d(t-1), D2e(t-1))
    if firm.age < 3
        # For very new entrants, use at least some minimal expected demand
        if firm.D2e <= 0.0
            firm.D2e = max(0.1, firm.D2_history[1])
        else
            firm.D2e = max(firm.D2_history[1], firm.D2e)
        end
        return
    end
    
    # Mix fulfilled and potential demand (animal spirits)
    e0 = params.e0
    demand_mix = Float64[]
    for i in 1:min(4, length(firm.D2_history))
        D_actual = firm.D2_history[i]
        D_desired = i == 1 ? firm.D2d : (i <= length(firm.D2_history) ? firm.D2_history[i] : D_actual)
        mixed = (1 - e0) * D_actual + e0 * D_desired
        push!(demand_mix, max(mixed, D_actual))
    end
    
    # Apply expectation rule
    expectation_mode = params.flagExpect
    
    if expectation_mode == 0  # Myopic 1-period
        firm.D2e = demand_mix[1]
        
    elseif expectation_mode == 1  # Myopic 4-period weighted average
        weights = [params.e1, params.e2, params.e3, params.e4]
        total_weight = 0.0
        weighted_sum = 0.0
        for i in 1:min(4, length(demand_mix))
            if demand_mix[i] > 0
                weighted_sum += weights[i] * demand_mix[i]
                total_weight += weights[i]
            end
        end
        firm.D2e = total_weight > 0 ? weighted_sum / total_weight : demand_mix[1]
        
    elseif expectation_mode == 2  # Accelerating growth
        if length(demand_mix) >= 2
            growth = (demand_mix[1] - demand_mix[2]) / max(demand_mix[2], 1e-10)
            acceleration = params.e5 * growth
            firm.D2e = demand_mix[1] * (1 + acceleration)
        else
            firm.D2e = demand_mix[1]
        end
        
    elseif expectation_mode == 3  # Adaptive expectations
        firm.D2e = params.e6 * firm.D2e + (1 - params.e6) * demand_mix[1]
        
    elseif expectation_mode == 4  # Extrapolative-accelerating
        if length(demand_mix) >= 3
            trend = params.e7 * (demand_mix[1] - demand_mix[2])
            accel = params.e8 * (demand_mix[1] - 2*demand_mix[2] + demand_mix[3])
            firm.D2e = demand_mix[1] + trend + accel
        else
            firm.D2e = demand_mix[1]
        end
    else
        firm.D2e = demand_mix[1]
    end
    
    # Ensure non-negative and not less than last period, with minimum floor
    firm.D2e = max(firm.D2e, demand_mix[1] * 0.5, 0.01)  # At least 50% of last actual demand
end

"""
    firm2_plan_production!(firm::Firm2, model)

Plan production based on expected demand.
Matches C model _Q2d and _Q2 equations.
"""
function firm2_plan_production!(firm::Firm2, model)
    params = model.params
    
    # Desired production with inventory buffer (considering inventories)
    # Matches C model: (1 + iota) * D2e - N(t-1)
    Q_desired = max((1 + params.iota) * firm.D2e - firm.N2, 0.0)
    
    # Production capacity based on capital stock
    # Matches C model: min(Q_desired, K)
    # Note: K represents machines, each can produce `u` units per period with avg productivity
    A_avg = firm2_average_productivity(firm)
    Q_capacity = firm.K * params.u * A_avg
    
    # Planned production limited by capital (before considering labor/finance)
    # Matches C model: min(desired, K)
    Q_planned = min(Q_desired, Q_capacity)
    
    # Ensure some minimum production if firm has capital and expects demand
    # This prevents labor demand from being zero
    if firm.K > 0 && firm.D2e > 0 && Q_planned < 0.01
        Q_planned = min(0.01, Q_capacity)
    end
    
    firm.Q2 = Q_planned
end

"""
    firm2_average_productivity(firm::Firm2)

Calculate average productivity across all vintages.
"""
function firm2_average_productivity(firm::Firm2)
    if isempty(firm.vintages)
        return 1.0
    end
    
    total_machines = sum(v.machines for v in values(firm.vintages))
    if total_machines == 0
        return 1.0
    end
    
    weighted_A = sum(v.A * v.machines for v in values(firm.vintages))
    return weighted_A / total_machines
end

"""
    firm2_decide_investment!(firm::Firm2, model)

Decide on investment (expansion and replacement).
Implements _EId, _SId equations from C model.
"""
function firm2_decide_investment!(firm::Firm2, model)
    params = model.params
    
    # Calculate desired capital (_Kd equation)
    # Desired capacity with slack and utilization, based on expectations/inventories
    A_avg = firm2_average_productivity(firm)
    firm.Kd = max((1 + params.iota) * firm.D2e - firm.N2, 0.0) / params.u
    
    # === EXPANSION INVESTMENT (_EId equation) ===
    K_current = firm.K
    m2 = params.m2
    
    if K_current < m2
        # No capital yet, invest to reach desired
        firm.EId = firm.Kd
    else
        kappaMin = params.kappaMin
        
        # Min rounded capital
        K_min = round((1 + kappaMin) * K_current / m2) * m2
        
        if firm.Kd > K_min
            if kappaMin > 0
                firm.EId = K_min - K_current
            else
                kappaMax = params.kappaMax
                K_max = round((1 + kappaMax) * K_current / m2) * m2
                
                if kappaMax > 0 && firm.Kd > K_max
                    firm.EId = K_max - K_current
                else
                    firm.EId = floor((firm.Kd - K_current) / m2) * m2
                end
            end
        else
            firm.EId = 0.0
        end
    end
    
    # === SUBSTITUTION INVESTMENT (_SId equation) ===
    # Replace obsolete machines based on payback period
    machines_to_scrap = 0.0
    current_cost = A_avg > 0 ? model.wAvg / A_avg : Inf
    
    vintages_to_remove = Int[]
    for (vid, vintage) in firm.vintages
        age = model.t - vintage.t0
        vintage_cost = vintage.A > 0 ? model.wAvg / vintage.A : Inf
        
        # Payback period calculation
        if vintage_cost > current_cost && vintage.price > 0
            payback = vintage.price / (vintage_cost - current_cost)
        else
            payback = Inf
        end
        
        # Scrap if old enough or payback period met
        if age >= params.eta || payback <= params.b
            machines_to_scrap += vintage.machines
            push!(vintages_to_remove, vid)
        end
    end
    
    # Remove old vintages
    for vid in vintages_to_remove
        delete!(firm.vintages, vid)
    end
    
    # Capital shrinkage desired?
    capital_shrink = max(K_current - firm.Kd, 0.0)
    machines_to_remove = floor(capital_shrink / m2)
    
    # Substitution investment (machines to scrap minus machines removed due to shrinkage)
    firm.SId = max(machines_to_scrap - machines_to_remove, 0.0) * m2
    
    # Total investment demand
    firm.Id = firm.EId + firm.SId
end

"""
    firm2_execute_investment!(firm::Firm2, model)

Execute investment with financing constraints.
Implements the invest() function from C model for both expansion and substitution.
Updates _EI, _SI fields and modifies firm's net worth and debt.
"""
function firm2_execute_investment!(firm::Firm2, model)
    params = model.params
    
    # Execute expansion investment first
    firm.EI = execute_investment_order(firm, firm.EId, model)
    
    # Execute substitution investment
    firm.SI = execute_investment_order(firm, firm.SId, model)
    
    # Update capital stock after investments
    # This will be done when machines are delivered
end

"""
    execute_investment_order(firm::Firm2, desired::Float64, model)

Execute a single investment order (expansion or substitution) with financing.
Returns the actual investment achieved.
"""
function execute_investment_order(firm::Firm2, desired::Float64, model)
    params = model.params
    
    if desired <= 0
        return 0.0
    end
    
    m2 = params.m2
    
    # Get supplier price
    if firm.supplier_id > 0 && Agents.hasid(model, firm.supplier_id)
        supplier = model[firm.supplier_id]
        p1 = supplier.p1
    else
        p1 = model.p1avg
    end
    
    # Investment cost
    inv_cost = p1 * desired / m2
    
    # Available financing (simplified - full model would include bank credit limits)
    available_credit = max(0.0, firm.NW2 * params.Lambda - firm.Deb2)
    
    # Determine actual investment
    actual_investment = 0.0
    loan = 0.0
    
    if inv_cost <= firm.NW2
        # Can invest with own funds
        actual_investment = desired
        firm.NW2 -= inv_cost
    elseif inv_cost <= firm.NW2 + available_credit
        # Can finance with debt
        actual_investment = desired
        loan = inv_cost - firm.NW2
        firm.Deb2 += loan
        firm.NW2 = 0.0
    else
        # Credit constrained - invest what's possible
        total_funds = firm.NW2 + available_credit
        actual_investment = max(floor(total_funds / p1) * m2, 0.0)
        
        if actual_investment > 0
            inv_cost = p1 * actual_investment / m2
            if inv_cost <= firm.NW2
                firm.NW2 -= inv_cost
            else
                loan = inv_cost - firm.NW2
                firm.Deb2 += loan
                firm.NW2 = 0.0
            end
        end
    end
    
    # Place order with supplier (machines will be delivered in phase 8)
    # Note: D1 is already aggregated in phase 3 from Id, so we don't modify it here
    
    return actual_investment
end

"""
    firm2_produce!(firm::Firm2, model)

Execute production for consumption-good firm.
"""
function firm2_produce!(firm::Firm2, model)
    params = model.params
    
    # Effective production limited by labor
    A_avg = firm2_average_productivity(firm)
    Q_labor = firm.L2 * A_avg
    Q_capital = firm.K * params.u * A_avg
    
    firm.Q2e = min(firm.Q2, Q_labor, Q_capital)
    
    # Sales (match to demand, limited by production + inventory)
    available = firm.Q2e + firm.N2
    firm.S2 = min(available, firm.D2)
    
    # Update inventories
    firm.N2 = max(0.0, available - firm.S2)
end

"""
    firm2_set_price!(firm::Firm2, model)

Set price using variable markup based on market share dynamics.
"""
function firm2_set_price!(firm::Firm2, model)
    params = model.params
    
    # Unit cost
    A_avg = firm2_average_productivity(firm)
    if A_avg > 0
        firm.c2 = firm.w2 / A_avg
    else
        firm.c2 = firm.w2 / 1.0  # Fallback
    end
    
    # Safety: ensure c2 is finite and positive
    if !isfinite(firm.c2) || firm.c2 <= 0
        firm.c2 = firm.w2
    end
    
    # Adjust markup based on market share change
    if firm.age > 0
        # Market share growth
        props = Agents.abmproperties(model)
        f2_prev_dict = get(props, :f2_prev, Dict{Int,Float64}())
        f2_prev = get(f2_prev_dict, firm.id, firm.f2)
        f2_growth = firm.f2 - f2_prev
        
        # Adjust markup: increase if gaining share, decrease if losing
        markup_change = params.upsilon * f2_growth
        firm.mu2 = clamp(firm.mu2 + markup_change, 0.0, 1.0)
    end
    
    # Price (ensure positive and finite)
    firm.p2 = (1 + firm.mu2) * firm.c2
    
    # Final safety checks
    if !isfinite(firm.p2) || firm.p2 <= 0
        firm.p2 = max(model.wMin * 2, 0.01)  # Fallback price
    end
end

"""
    firm2_compute_labor_demand!(firm::Firm2, model)

Compute desired labor for production.
Matches C model _L2d equation: ceil(Q2 / A2) when life2cycle > 0
"""
function firm2_compute_labor_demand!(firm::Firm2, model)
    params = model.params
    
    # Get average productivity
    A_avg = firm2_average_productivity(firm)
    
    # Safety checks to prevent zero/NaN labor demand
    if A_avg <= 0 || firm.Q2 <= 0
        # If no productivity or no planned production, still maintain minimal employment
        # This matches the C model's lifecycle check - inactive firms have L2d = 0
        # but we keep at least current employment to prevent mass firing
        firm.L2d = max(1.0, Float64(firm.L2))
        return
    end
    
    # Labor needed for planned production
    # Matches C model: ceil(Q2 / A2)
    L_needed = firm.Q2 / A_avg
    
    # Desired labor (rounded up, with minimum of 1)
    firm.L2d = max(ceil(L_needed), 1.0)
end

"""
    firm2_compute_competitiveness!(firm::Firm2, model)

Compute firm competitiveness for replicator dynamics.
"""
function firm2_compute_competitiveness!(firm::Firm2, model)
    params = model.params
    
    # Normalize price (lower is better)
    price_norm = 1 - (firm.p2 - model.p2avg) / max(model.p2avg, 1e-10)
    
    # Unfilled demand (lower is better)
    unfilled = firm.D2 > 0 ? (firm.D2 - firm.S2) / firm.D2 : 0.0
    unfilled_norm = 1 - unfilled
    
    # Quality (not implemented in basic version, set to 0)
    quality_norm = 0.0
    
    # Weighted competitiveness
    firm.competitiveness = (params.omega1 * price_norm + 
                           params.omega2 * unfilled_norm + 
                           params.omega3 * quality_norm)
end

"""
    firm2_update_finances!(firm::Firm2, model)

Update financial position of consumption-good firm.
"""
function firm2_update_finances!(firm::Firm2, model)
    params = model.params
    
    # Revenue
    revenue = firm.S2 * firm.p2
    
    # Costs
    wage_cost = firm.L2 * firm.w2
    interest_cost = firm.Deb2 * model.rDeb
    
    # Profits
    profit = revenue - wage_cost - interest_cost
    
    # Tax
    tax = max(0.0, profit * params.tr)
    
    # Net profit
    net_profit = profit - tax
    
    # Bonuses (if high profit)
    bonus = 0.0
    if net_profit > 0 && firm.K > 0
        profit_rate = net_profit / firm.K
        props = Agents.abmproperties(model)
        avg_profit_rate = get(props, :Pi2rateAvg, 0.0)
        if profit_rate > avg_profit_rate && firm.L2 > 0
            bonus = params.psi6 * net_profit
        end
    end
    
    # Dividends
    dividend = max(0.0, (net_profit - bonus) * params.d2)
    
    # Retained earnings
    retained = net_profit - bonus - dividend
    
    # Update net worth
    firm.NW2 += retained
    
    # Debt repayment
    if firm.Deb2 > 0 && retained > 0
        repayment = min(firm.Deb2, params.deltaB * firm.Deb2, retained)
        firm.Deb2 -= repayment
        firm.NW2 -= repayment
    end
end

"""
    firm2_check_exit!(firm::Firm2, model)

Check if firm should exit.
"""
function firm2_check_exit!(firm::Firm2, model)
    params = model.params
    
    # Exit if negative net worth or market share too low
    if firm.NW2 < 0 || firm.f2 < params.f2min
        firm.exit_flag = true
        
        # Release workers
        for wid in firm.worker_ids
            if Agents.hasid(model, wid)
                worker = model[wid]
                worker.employed = 0
                worker.employer = nothing
                worker.vintage = nothing
            end
        end
        empty!(firm.worker_ids)
        
        # Default on debt
        if firm.Deb2 > 0 && firm.bank_id > 0
            bank = model[firm.bank_id]
            bank.BadDeb2 += firm.Deb2
            bank.Loans2 -= firm.Deb2
            bank.Loans -= firm.Deb2
        end
        
        return true
    end
    
    return false
end
