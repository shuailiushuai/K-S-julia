"""
    government.jl

Government and central bank functions.
Implements fiscal policy, monetary policy, taxation, etc.
"""

"""
    update_central_bank_rate!(model)

Update prime interest rate using Taylor rule.
"""
function update_central_bank_rate!(model)
    params = model.params
    
    # Taylor rule: r = rT + gammaPi*(pi - piT) + gammaU*(U - Ut)
    inflation_gap = model.inflation - params.piT
    unemployment_gap = model.Ue - params.Ut
    
    r_target = params.rT + params.gammaPi * inflation_gap + params.gammaU * unemployment_gap
    
    # Adjust gradually
    r_change = r_target - model.r
    if abs(r_change) > params.rAdj
        r_change = sign(r_change) * params.rAdj
    end
    
    model.r = max(0.001, model.r + r_change)
    
    # Update interest rate structure
    model.rDeb = model.r + params.muDeb
    model.rD = model.r - params.muD
    model.rRes = model.r - params.muRes
end

"""
    compute_government_expenditure!(model)

Compute total government expenditure.
"""
function compute_government_expenditure!(model)
    params = model.params
    
    G = 0.0
    
    # Unemployment benefits
    wU = params.phi * model.wAvg
    model.wU = max(wU, params.w0min)
    G += model.U * model.wU
    
    # Training costs
    n_trained = Int(round(params.Gamma * model.U))
    G += n_trained * params.GammaCost * model.wAvg
    
    # Fixed government expenditure
    if params.flagGovExp >= 1
        G_fixed = get(model.properties, :G_fixed, 0.0)
        if model.t > 1
            G_fixed *= (1 + params.gG)
        else
            G_fixed = 0.1 * model.GDPnom  # Initial value
        end
        model.properties[:G_fixed] = G_fixed
        G += G_fixed
    end
    
    # Bailouts
    G += model.Gbail
    
    # Interest on public debt
    G += model.Deb * model.r
    
    model.G = G
end

"""
    collect_taxes!(model)

Collect taxes from firms and workers.
"""
function collect_taxes!(model)
    params = model.params
    
    total_tax = 0.0
    
    # Taxes from firms
    for fid in model.firm1_ids
        if haskey(model.agents, fid)
            firm = model[fid]
            revenue = firm.S1 * firm.p1
            cost = firm.L1 * firm.w1 + firm.Deb1 * model.rDeb
            profit = max(0.0, revenue - cost)
            tax = profit * params.tr
            total_tax += tax
        end
    end
    
    for fid in model.firm2_ids
        if haskey(model.agents, fid)
            firm = model[fid]
            revenue = firm.S2 * firm.p2
            cost = firm.L2 * firm.w2 + firm.Deb2 * model.rDeb
            profit = max(0.0, revenue - cost)
            tax = profit * params.tr
            total_tax += tax
        end
    end
    
    # Taxes from banks
    for bid in model.bank_ids
        bank = model[bid]
        profit = bank_compute_profits!(bank, model)
        tax = max(0.0, profit * params.tr)
        total_tax += tax
    end
    
    # Taxes from workers (if flagTax == 1)
    if params.flagTax == 1
        for wid in model.worker_ids
            worker = model[wid]
            if worker.employed > 0
                wage_tax = worker.w * params.tr
                total_tax += wage_tax
            end
        end
    end
    
    model.Tax = total_tax
end

"""
    update_public_finances!(model)

Update government deficit and debt.
"""
function update_public_finances!(model)
    params = model.params
    
    # Deficit
    model.Def = model.G - model.Tax
    
    # Debt
    model.Deb = max(0.0, model.Deb + model.Def)
    
    # Apply fiscal rules if needed
    if model.t >= params.Trule && params.flagFiscalRule > 0
        apply_fiscal_rules!(model)
    end
    
    # Bond supply
    model.BS = model.Deb / params.thetaBonds
end

"""
    apply_fiscal_rules!(model)

Apply fiscal consolidation rules if needed.
"""
function apply_fiscal_rules!(model)
    params = model.params
    
    debt_gdp_ratio = model.Deb / max(model.GDPnom, 1.0)
    deficit_gdp_ratio = model.Def / max(model.GDPnom, 1.0)
    
    # Check if rules are violated
    violated = false
    
    if params.flagFiscalRule == 1 || params.flagFiscalRule == 2
        # Deficit rule
        if deficit_gdp_ratio > params.DefPrule
            violated = true
        end
    end
    
    if params.flagFiscalRule == 3 || params.flagFiscalRule == 4
        # Debt and deficit rule
        if debt_gdp_ratio > params.DebRule || deficit_gdp_ratio > params.DefPrule
            violated = true
        end
    end
    
    # Soft rules (only if GDP not growing)
    if params.flagFiscalRule == 2 || params.flagFiscalRule == 4
        if length(model.GDP_history) >= 2
            gdp_growth = (model.GDP - model.GDP_history[end-1]) / model.GDP_history[end-1]
            if gdp_growth > 0
                violated = false  # Don't apply if growing
            end
        end
    end
    
    # If violated, reduce expenditure or increase taxes
    if violated
        # Reduce debt by fraction
        debt_reduction = params.deltaDeb * model.Deb
        model.Deb = max(0.0, model.Deb - debt_reduction)
    end
end

"""
    update_minimum_wage!(model)

Update minimum wage with indexation.
"""
function update_minimum_wage!(model)
    params = model.params
    
    if params.flagIndexMinWage > 0
        # Index to inflation and productivity
        indexation = params.flagIndexMinWage
        
        productivity_growth = 0.0
        if length(model.GDP_history) >= 2
            productivity_growth = (model.A2 - get(model.properties, :A2_prev, model.A2)) / get(model.properties, :A2_prev, 1.0)
        end
        
        wage_growth = indexation * (params.psi1 * model.inflation + params.psi2 * productivity_growth)
        
        model.wMin = max(params.w0min, model.wMin * (1 + wage_growth))
    end
end
