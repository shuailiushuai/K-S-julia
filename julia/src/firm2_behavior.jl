"""
    firm2_behavior.jl

Behavioral functions for consumption-good firms (Firm2).
Implements expectation formation, investment, production, pricing, etc.
Corresponds to fun_KS_firm2.h in C model.
"""

"""
    firm2_form_expectations!(firm::Firm2, model)

Form adaptive demand expectations.
"""
function firm2_form_expectations!(firm::Firm2, model)
    params = model.params
    
    # Entrant with limited history uses optimistic expectations
    if firm.age < 3
        firm.D2e = max(firm.D2_history[1], firm.D2e)
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
    
    # Ensure non-negative and not less than last period
    firm.D2e = max(firm.D2e, demand_mix[1], 0.0)
end

"""
    firm2_plan_production!(firm::Firm2, model)

Plan production based on expected demand.
"""
function firm2_plan_production!(firm::Firm2, model)
    params = model.params
    
    # Desired production with inventory buffer
    Q_desired = firm.D2e * (1 + params.iota)
    
    # Production capacity
    A_avg = firm2_average_productivity(firm)
    Q_capacity = firm.K * params.u * A_avg
    
    # Planned production
    firm.Q2 = min(Q_desired, Q_capacity)
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
"""
function firm2_decide_investment!(firm::Firm2, model)
    params = model.params
    
    # Expansion investment
    A_avg = firm2_average_productivity(firm)
    K_needed = firm.D2e * (1 + params.iota) / (params.u * A_avg)
    expansion = max(0.0, K_needed - firm.K)
    
    # Replacement investment (payback rule)
    replacement = 0.0
    current_cost = model.wAvg / A_avg
    
    vintages_to_remove = Int[]
    for (vid, vintage) in firm.vintages
        age = model.t - vintage.t0
        vintage_cost = model.wAvg / vintage.A
        
        # Payback period
        if vintage_cost > current_cost
            payback = vintage.price / (vintage_cost - current_cost)
        else
            payback = Inf
        end
        
        # Scrap if old enough or payback period met
        if age >= params.eta || payback <= params.b
            replacement += vintage.machines
            push!(vintages_to_remove, vid)
        end
    end
    
    # Remove old vintages
    for vid in vintages_to_remove
        delete!(firm.vintages, vid)
    end
    
    # Total investment demand
    firm.Id = expansion + replacement
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
    firm.c2 = firm.w2 / firm2_average_productivity(firm)
    
    # Adjust markup based on market share change
    if firm.age > 0
        # Market share growth
        f2_growth = firm.f2 - get(model.properties, :f2_prev, Dict{Int,Float64}())[firm.id]
        
        # Adjust markup: increase if gaining share, decrease if losing
        markup_change = params.upsilon * f2_growth
        firm.mu2 = clamp(firm.mu2 + markup_change, 0.0, 1.0)
    end
    
    # Price
    firm.p2 = (1 + firm.mu2) * firm.c2
end

"""
    firm2_compute_labor_demand!(firm::Firm2, model)

Compute desired labor for production.
"""
function firm2_compute_labor_demand!(firm::Firm2, model)
    params = model.params
    
    # Labor needed for desired production
    A_avg = firm2_average_productivity(firm)
    if A_avg > 0
        L_needed = firm.Q2 / A_avg
        
        # Add slack for hiring buffer
        firm.L2d = L_needed * (1 + params.theta)
    else
        firm.L2d = 0.0
    end
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
        avg_profit_rate = get(model.properties, :Pi2rateAvg, 0.0)
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
            if haskey(model.agents, wid)
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
