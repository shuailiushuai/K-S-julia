"""
    firm1_behavior.jl

Behavioral functions for capital-good firms (Firm1).
Implements R&D, innovation, imitation, production, pricing, etc.
Corresponds to fun_KS_firm1.h in C model.
"""

"""
    firm1_innovate!(firm::Firm1, model)

Innovation process for capital-good firm.
Returns true if innovation succeeded.
"""
function firm1_innovate!(firm::Firm1, model)
    params = model.params
    
    # Normalized R&D workers from PREVIOUS period (lagged)
    # This matches C model: VL("_L1rd", 1)
    # firm.L1rd was set at end of previous period's production
    L1rdN = firm.L1rd * params.Ls0 / model.Ls
    
    # Innovation success probability
    prob_inn = 1 - exp(-params.zeta1 * params.xi * L1rdN)
    
    if rand(Agents.abmrng(model)) < prob_inn
        # Draw innovation magnitude
        draw = rand(Agents.abmrng(model), Beta(params.alpha1, params.beta1))
        improvement = params.x1inf + draw * (params.x1sup - params.x1inf)
        
        # New technology
        A_new = firm.Atau * (1 + improvement)
        B_new = firm.Btau * (1 + improvement)
        
        # Adopt if better (lower cost or higher productivity)
        w1avg = model.wAvg
        c_old = w1avg / firm.Atau
        c_new = w1avg / A_new
        
        if c_new < c_old
            firm.Atau = A_new
            firm.Btau = B_new
            firm.A = A_new
            firm.B = B_new
            return true
        end
    end
    
    return false
end

"""
    firm1_imitate!(firm::Firm1, model)

Imitation process for capital-good firm.
Returns true if imitation succeeded.
"""
function firm1_imitate!(firm::Firm1, model)
    params = model.params
    
    # Normalized R&D workers from PREVIOUS period (lagged)
    # This matches C model: VL("_L1rd", 1)
    L1rdN = firm.L1rd * params.Ls0 / model.Ls
    
    # Imitation success probability
    prob_imi = 1 - exp(-params.zeta2 * (1 - params.xi) * L1rdN)
    
    if rand(Agents.abmrng(model)) < prob_imi
        # Calculate distances to all competitors
        w1avg = model.wAvg
        competitors = Int[]
        distances = Float64[]
        
        for fid in model.firm1_ids
            if fid == firm.id
                continue
            end
            
            competitor = model[fid]
            
            # Price and cost of competitor's technology
            p_comp = (1 + params.mu1) * w1avg / competitor.Btau / params.m1
            c_comp = w1avg / competitor.Atau
            
            # Current firm's metrics
            p_self = firm.p1
            c_self = w1avg / firm.Atau
            
            # Euclidean distance in normalized space
            dist = sqrt((p_comp - p_self)^2 / model.p1avg^2 + 
                       (c_comp - c_self)^2 / (w1avg / model.A2)^2)
            
            if dist > 0
                push!(competitors, fid)
                push!(distances, 1.0 / dist)  # Inverse distance as probability weight
            end
        end
        
        if !isempty(competitors)
            # Weighted sampling by inverse distance
            weights = Weights(distances)
            target_id = StatsBase.sample(Agents.abmrng(model), competitors, weights)
            target = model[target_id]
            
            # Adopt target's technology if better
            c_target = w1avg / target.Atau
            c_self = w1avg / firm.Atau
            
            if c_target < c_self
                firm.Atau = target.Atau
                firm.Btau = target.Btau
                firm.A = target.Atau
                firm.B = target.Btau
                return true
            end
        end
    end
    
    return false
end

"""
    firm1_rd!(firm::Firm1, model)

Execute R&D for capital-good firm (both innovation and imitation).
CRITICAL: This function uses L1rd from PREVIOUS period (lagged),
which was set at the END of the previous time step after labor allocation.
"""
function firm1_rd!(firm::Firm1, model)
    # Innovation and imitation use firm.L1rd which contains
    # the ACTUAL R&D workers hired in the PREVIOUS period
    # This is correct - it matches C model: VL("_L1rd", 1)
    innovated = firm1_innovate!(firm, model)
    if !innovated
        firm1_imitate!(firm, model)
    end
end

"""
    firm1_plan_production!(firm::Firm1, model)

Plan production based on orders and labor.
Production is initially based on demand, then adjusted after hiring.
"""
function firm1_plan_production!(firm::Firm1, model)
    params = model.params
    
    # Planned production based on demand (orders) plus inventory buffer
    # This is what firm WANTS to produce, not constrained by current labor
    firm.Q1 = firm.D1 * (1 + params.iota)
end

"""
    firm1_produce!(firm::Firm1, model)

Execute production for capital-good firm.
Adjusts planned production (Q1) to effective production (Q1e) based on actual labor hired.
CRITICAL: Sets L1rd at END of period for use in NEXT period's innovation.
"""
function firm1_produce!(firm::Firm1, model)
    params = model.params
    
    # Check if we got all desired workers
    if firm.L1 >= firm.L1d || firm.L1d <= 0
        # Got all desired workers (or no demand)
        # Produce as planned
        firm.Q1e = firm.Q1
        # All desired R&D workers hired
        L_rd_actual = firm.L1dRD
    else
        # Labor constrained - need to adjust production
        # Matches C model logic in _Q1e equation
        
        # Calculate adjustment factor for production
        # C model: v[5] = v[2] > v[4] ? 1 - (v[1] - v[3]) / (v[2] - v[4]) : 1
        # where v[1]=L1, v[2]=L1d, v[3]=L1rd, v[4]=L1dRD
        
        L_prod_desired = max(0.0, firm.L1d - firm.L1dRD)
        
        # Allocate R&D workers first (proportionally if needed)
        if firm.L1d > 0 && firm.L1dRD > 0
            # R&D workers get proportional share
            L_rd_actual = min(firm.L1dRD, firm.L1 * firm.L1dRD / firm.L1d)
        else
            L_rd_actual = 0.0
        end
        
        # Remaining workers go to production
        L_prod_actual = max(0.0, firm.L1 - L_rd_actual)
        
        # Adjust production based on available production workers
        if L_prod_desired > 0
            adjustment_factor = L_prod_actual / L_prod_desired
            firm.Q1e = max(0.0, firm.Q1 * adjustment_factor)
        else
            firm.Q1e = 0.0
        end
    end
    
    # CRITICAL: Save actual R&D workers for NEXT period's innovation calculation
    # This matches C model: VL("_L1rd", 1) in _Atau equation
    # Innovation at time t+1 will use this value (lagged)
    firm.L1rd = L_rd_actual
    
    # Sales are minimum of available output (production + inventory) and demand
    firm.S1 = min(firm.Q1e + firm.N1, firm.D1)
    
    # Update inventories
    firm.N1 = max(0.0, firm.Q1e + firm.N1 - firm.S1)
end

"""
    firm1_set_price!(firm::Firm1, model)

Set machine price using cost-plus markup.
"""
function firm1_set_price!(firm::Firm1, model)
    params = model.params
    
    # Unit cost (wage / productivity / modularity)
    firm.c1 = firm.w1 / firm.B / params.m1
    
    # Price with fixed markup
    firm.p1 = (1 + params.mu1) * firm.c1
end

"""
    firm1_compute_labor_demand!(firm::Firm1, model)

Compute desired labor for production and R&D.
CRITICAL: This matches C model's _L1d and _L1dRD equations.
R&D is computed BEFORE this using S1_prev in the scheduling sequence.
"""
function firm1_compute_labor_demand!(firm::Firm1, model)
    params = model.params
    
    # Production labor needed for planned production Q1
    # Matches C model: ceil( V("_Q1") / ( V("_Btau") * VS(PARENT, "m1") ) )
    if firm.B > 0 && params.m1 > 0
        L_prod = ceil(firm.Q1 / (params.m1 * firm.B))
    else
        L_prod = 0.0
    end
    
    # R&D workers needed (computed from R&D expenditure)
    # This is already computed in compute_rd_expenditure! and stored in L1dRD
    # We just use it here
    L_rd = firm.L1dRD
    
    # Total desired labor (no theta buffer - C model doesn't have it)
    # Matches C model: V("_L1dRD") + ceil(V("_Q1") / (V("_Btau") * VS(PARENT, "m1")))
    firm.L1d = L_rd + L_prod
end

"""
    firm1_compute_rd_expenditure!(firm::Firm1, model)

Compute R&D expenditure and desired R&D workers.
CRITICAL: This must be called BEFORE labor demand calculation.
Matches C model's _RD equation which uses VL("_S1", 1).
"""
function firm1_compute_rd_expenditure!(firm::Firm1, model)
    params = model.params
    
    # R&D expenditure based on PREVIOUS period's sales (lagged)
    # Matches C model: v[1] = VL("_S1", 1); v[0] = v[2] * v[1]
    if firm.S1_prev > 0
        # Use previous period's sales
        RD = params.nu * firm.S1_prev
    else
        # Fallback: use net worth if no previous sales
        # Matches C model: min(CURRENT, v[2] * VL("_NW1", 1))
        RD = params.nu * firm.NW1
    end
    
    # Always hire at least one worker's worth of R&D (minimum constraint)
    # Matches C model: max(v[0], VLS(PARENT, "w1avg", 1))
    RD = max(RD, firm.w1)
    
    # Convert R&D expenditure to workers
    # Matches C model: ceil(V("_RD") / VLS(PARENT, "w1avg", 1))
    if firm.w1 > 0
        L_rd = ceil(RD / firm.w1)
    else
        L_rd = 1.0  # At least 1 worker
    end
    
    # Store desired R&D workers for use in labor demand calculation
    firm.L1dRD = L_rd
end

"""
    firm1_send_brochures!(firm::Firm1, model)

Send brochures (product information) to customers and potential customers.
"""
function firm1_send_brochures!(firm::Firm1, model)
    params = model.params
    
    # Keep existing customers
    existing = firm.client_ids
    
    # Add new potential customers
    n_new = Int(round(params.gamma * length(model.firm2_ids)))
    if n_new > 0
        # Sample from firms not yet customers
        non_customers = setdiff(model.firm2_ids, existing)
        if !isempty(non_customers)
            n_sample = min(n_new, length(non_customers))
            new_customers = StatsBase.sample(Agents.abmrng(model), collect(non_customers), n_sample, replace=false)
            firm.client_ids = unique(vcat(existing, new_customers))
        end
    end
end

"""
    firm1_update_finances!(firm::Firm1, model)

Update financial position of capital-good firm.
"""
function firm1_update_finances!(firm::Firm1, model)
    params = model.params
    
    # Revenue
    revenue = firm.S1 * firm.p1
    
    # Costs
    wage_cost = firm.L1 * firm.w1
    interest_cost = firm.Deb1 * model.rDeb
    
    # Profits
    profit = revenue - wage_cost - interest_cost
    
    # Tax
    tax = max(0.0, profit * params.tr)
    
    # Net profit
    net_profit = profit - tax
    
    # Dividends
    dividend = max(0.0, net_profit * params.d1)
    
    # Retained earnings
    retained = net_profit - dividend
    
    # Update net worth
    firm.NW1 += retained
    
    # Debt repayment (fraction of debt)
    if firm.Deb1 > 0
        repayment = min(firm.Deb1, params.deltaB * firm.Deb1)
        if retained > 0
            actual_repayment = min(repayment, retained)
            firm.Deb1 -= actual_repayment
            firm.NW1 -= actual_repayment
        end
    end
end

"""
    firm1_check_exit!(firm::Firm1, model)

Check if firm should exit (bankruptcy or low market share).
"""
function firm1_check_exit!(firm::Firm1, model)
    params = model.params
    
    # Exit if negative net worth or market share too low
    if firm.NW1 < 0 || firm.f1 < params.f2min / 10  # Use stricter threshold for sector 1
        firm.exit_flag = true
        
        # Release workers
        for wid in firm.worker_ids
            if hasid(model, wid)
                worker = model[wid]
                worker.employed = 0
                worker.employer = nothing
            end
        end
        empty!(firm.worker_ids)
        
        # Default on debt
        if firm.Deb1 > 0 && firm.bank_id > 0
            bank = model[firm.bank_id]
            bank.BadDeb1 += firm.Deb1
            bank.Loans1 -= firm.Deb1
            bank.Loans -= firm.Deb1
        end
        
        return true
    end
    
    return false
end
