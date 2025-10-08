"""
    markets.jl

Market mechanisms and matching processes.
Implements labor market, capital goods market, consumption goods market.
"""

"""
    labor_market_matching!(model)

Execute labor market search and matching.
"""
function labor_market_matching!(model)
    params = model.params
    
    # Clear previous applications
    for fid in vcat(model.firm1_ids, model.firm2_ids)
        if Agents.hasid(model, fid)
            empty!(model[fid].applications)
        end
    end
    
    # Workers apply for jobs
    for wid in model.worker_ids
        worker = model[wid]
        worker_apply_for_jobs!(worker, model)
    end
    
    # Determine firm hiring order
    all_firms = vcat(model.firm1_ids, model.firm2_ids)
    hiring_order = order_firms_for_hiring(model, all_firms)
    
    # Process hiring and firing in order
    for fid in hiring_order
        if !Agents.hasid(model, fid)
            continue
        end
        
        firm = model[fid]
        is_firm1 = isa(firm, Firm1)
        
        # Current and desired labor
        L_current = is_firm1 ? firm.L1 : firm.L2
        L_desired = is_firm1 ? firm.L1d : firm.L2d
        
        if L_desired > L_current
            # Hiring
            hire_workers!(firm, model, Int(ceil(L_desired - L_current)))
        elseif L_desired < L_current
            # Firing (if allowed)
            if can_fire(firm, model)
                fire_workers!(firm, model, Int(floor(L_current - L_desired)))
            end
        end
    end
    
    # Update employment statistics
    update_employment_statistics!(model)
end

"""
    order_firms_for_hiring(model, firm_ids)

Order firms for hiring based on flagHireSeq.
"""
function order_firms_for_hiring(model, firm_ids)
    params = model.params
    
    if params.flagHireSeq == 0
        # Random order
        return Random.shuffle(Agents.abmrng(model), firm_ids)
        
    elseif params.flagHireSeq == 1
        # Higher wage firms first
        return sort(firm_ids, by = fid -> -(isa(model[fid], Firm1) ? model[fid].w1 : model[fid].w2))
        
    elseif params.flagHireSeq == 2
        # Firms without workers first, then random
        without = [fid for fid in firm_ids if (isa(model[fid], Firm1) ? model[fid].L1 : model[fid].L2) == 0]
        with_workers = setdiff(firm_ids, without)
        return vcat(Random.shuffle(Agents.abmrng(model), without), Random.shuffle(Agents.abmrng(model), with_workers))
        
    elseif params.flagHireSeq == 3
        # Firms without workers first, then by wage
        without = [fid for fid in firm_ids if (isa(model[fid], Firm1) ? model[fid].L1 : model[fid].L2) == 0]
        with_workers = setdiff(firm_ids, without)
        sorted_with = sort(with_workers, by = fid -> -(isa(model[fid], Firm1) ? model[fid].w1 : model[fid].w2))
        return vcat(Random.shuffle(Agents.abmrng(model), without), sorted_with)
    end
    
    return Random.shuffle(Agents.abmrng(model), firm_ids)
end

"""
    hire_workers!(firm, model, n_hire)

Hire workers from application queue.
"""
function hire_workers!(firm, model, n_hire)
    params = model.params
    is_firm1 = isa(firm, Firm1)
    
    # Compute wage offer
    w_offer = compute_wage_offer(firm, model)
    
    # Order applications based on hiring rule
    hire_order = is_firm1 ? params.flagHireOrder1 : params.flagHireOrder2
    ordered_apps = order_applications(firm, model, hire_order)
    
    hired = 0
    for wid in ordered_apps
        if hired >= n_hire
            break
        end
        
        if !Agents.hasid(model, wid)
            continue
        end
        
        worker = model[wid]
        
        # Check if worker accepts (wage offer >= reservation wage)
        if w_offer >= worker.wRes * (1 - 0.01)  # Small tolerance
            # Check if worker is already employed
            if worker.employed > 0
                # Worker must want to quit current job
                if w_offer < worker.w * (1 + params.epsilon)
                    continue  # Wage not high enough to switch
                end
                
                # Release from current employer
                old_employer = model[worker.employer]
                filter!(id -> id != wid, old_employer.worker_ids)
                if isa(old_employer, Firm1)
                    old_employer.L1 = max(0, old_employer.L1 - 1)
                else
                    old_employer.L2 = max(0, old_employer.L2 - 1)
                end
            end
            
            # Hire worker
            worker.employed = is_firm1 ? 1 : 2
            worker.employer = firm.id
            worker.w = w_offer
            worker.Te = 0
            worker.Tc = params.Tc
            
            push!(firm.worker_ids, wid)
            if is_firm1
                firm.L1 += 1
            else
                firm.L2 += 1
            end
            
            hired += 1
        end
    end
end

"""
    compute_wage_offer(firm, model)

Compute firm's wage offer to new hires.
"""
function compute_wage_offer(firm, model)
    params = model.params
    is_firm1 = isa(firm, Firm1)
    
    # Base wage (average or minimum)
    base_wage = is_firm1 ? firm.w1 : firm.w2
    
    if params.flagWageOffer == 0
        # Propose premium based on productivity/profit
        premium = 0.0
        if params.flagWagePremium == 1
            # Indexation mechanism
            premium = params.psi2 * 0.01  # Small productivity-based premium
        elseif params.flagWagePremium == 2
            # Endogenous based on vacancies
            L_current = is_firm1 ? firm.L1 : firm.L2
            L_desired = is_firm1 ? firm.L1d : firm.L2d
            if L_desired > 0
                vacancy_rate = max(0.0, (L_desired - L_current) / L_desired)
                premium = params.psi5 * vacancy_rate
            end
        end
        
        w_offer = base_wage * (1 + premium)
        
    else  # flagWageOffer == 1
        # Consider applicants' reservation wages
        min_res_wage = model.wMin
        for wid in firm.applications
            if Agents.hasid(model, wid)
                worker = model[wid]
                min_res_wage = max(min_res_wage, worker.wRes)
            end
        end
        w_offer = min_res_wage
    end
    
    # Cap wage change
    if params.wCap > 0
        w_offer = clamp(w_offer, base_wage / params.wCap, base_wage * params.wCap)
    end
    
    return max(w_offer, model.wMin)
end

"""
    order_applications(firm, model, order_rule)

Order job applications based on hiring rule.
"""
function order_applications(firm, model, order_rule)
    if isempty(firm.applications)
        return Int[]
    end
    
    if order_rule == 0
        # Random
        return Random.shuffle(Agents.abmrng(model), firm.applications)
    elseif order_rule == 1 || order_rule == 2
        # By wage
        reverse = (order_rule == 1)  # 1=high first, 2=low first
        return sort(firm.applications, by = wid -> model[wid].w, rev=reverse)
    elseif order_rule == 3 || order_rule == 4
        # By skills
        reverse = (order_rule == 3)  # 3=high first, 4=low first
        return sort(firm.applications, by = wid -> model[wid].s, rev=reverse)
    elseif order_rule == 7 || order_rule == 8
        # By tenure
        reverse = (order_rule == 7)  # 7=old first, 8=new first
        return sort(firm.applications, by = wid -> model[wid].Te, rev=reverse)
    end
    
    return Random.shuffle(Agents.abmrng(model), firm.applications)
end

"""
    can_fire(firm, model)

Check if firm can fire workers based on firing rule.
"""
function can_fire(firm, model)
    params = model.params
    
    if !isa(firm, Firm2)
        return true  # Sector 1 can always fire
    end
    
    rule = params.flagFireRule
    
    if rule == 0
        return false  # Never fire (Japanese mode)
    elseif rule == 1
        return false  # Never fire with sharing (German mode)
    elseif rule == 2
        # Only if downsizing (French mode)
        return firm.L2 > firm.L2d
    elseif rule == 3
        # Only if losses (Italian mode)
        return firm.NW2 < get(model.properties, Symbol("NW2_prev_$(firm.id)"), firm.NW2)
    elseif rule >= 4
        return true  # Can fire (American/Brazilian mode)
    end
    
    return true
end

"""
    fire_workers!(firm, model, n_fire)

Fire workers from firm.
"""
function fire_workers!(firm, model, n_fire)
    params = model.params
    is_firm1 = isa(firm, Firm1)
    
    if n_fire <= 0 || isempty(firm.worker_ids)
        return
    end
    
    # Order workers for firing
    fire_order = is_firm1 ? params.flagFireOrder1 : params.flagFireOrder2
    ordered = order_workers_for_firing(firm, model, fire_order)
    
    fired = 0
    for wid in ordered
        if fired >= n_fire
            break
        end
        
        if !Agents.hasid(model, wid)
            continue
        end
        
        worker = model[wid]
        
        # Check if protected from firing
        if params.Tp > 0 && worker.Te < params.Tp
            continue
        end
        
        # Fire worker
        worker.employed = 0
        worker.employer = nothing
        worker.vintage = nothing
        
        filter!(id -> id != wid, firm.worker_ids)
        if is_firm1
            firm.L1 = max(0, firm.L1 - 1)
        else
            firm.L2 = max(0, firm.L2 - 1)
        end
        
        fired += 1
    end
end

"""
    order_workers_for_firing(firm, model, order_rule)

Order workers for firing based on rule.
"""
function order_workers_for_firing(firm, model, order_rule)
    if isempty(firm.worker_ids)
        return Int[]
    end
    
    if order_rule == 0
        return Random.shuffle(Agents.abmrng(model), firm.worker_ids)
    elseif order_rule == 1 || order_rule == 2
        reverse = (order_rule == 2)  # 2=low wage first (LIFO)
        return sort(firm.worker_ids, by = wid -> model[wid].w, rev=reverse)
    elseif order_rule == 3 || order_rule == 4
        reverse = (order_rule == 4)  # 4=low skill first
        return sort(firm.worker_ids, by = wid -> model[wid].s, rev=reverse)
    elseif order_rule == 7 || order_rule == 8
        reverse = (order_rule == 8)  # 8=recent hires first (LIFO)
        return sort(firm.worker_ids, by = wid -> model[wid].Te, rev=reverse)
    end
    
    return Random.shuffle(Agents.abmrng(model), firm.worker_ids)
end

"""
    update_employment_statistics!(model)

Update aggregate employment statistics.
"""
function update_employment_statistics!(model)
    employed = sum(1 for wid in model.worker_ids if model[wid].employed > 0; init=0)
    model.L = employed
    model.U = model.Ls - employed
    model.Ue = model.U / model.Ls
    
    # Average wage
    wages = [model[wid].w for wid in model.worker_ids if model[wid].employed > 0]
    model.wAvg = isempty(wages) ? model.wMin : mean(wages)
end

"""
    update_market_shares!(model)

Update firm market shares using replicator dynamics.
"""
function update_market_shares!(model)
    params = model.params
    
    # Sector 2: replicator dynamics
    if !isempty(model.firm2_ids)
        # Average competitiveness
        E_avg = mean(model[fid].competitiveness for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
        
        # Update market shares
        for fid in model.firm2_ids
            if Agents.hasid(model, fid)
                firm = model[fid]
                # Replicator dynamics
                f2_new = firm.f2 * (1 + params.chi * (firm.competitiveness - E_avg))
                firm.f2 = max(0.0, f2_new)
            end
        end
        
        # Renormalize
        total_f2 = sum(model[fid].f2 for fid in model.firm2_ids if Agents.hasid(model, fid); init=0.0)
        if total_f2 > 0
            for fid in model.firm2_ids
                if Agents.hasid(model, fid)
                    model[fid].f2 /= total_f2
                end
            end
        end
    end
    
    # Sector 1: simpler market share dynamics
    if !isempty(model.firm1_ids)
        total_s1 = sum(model[fid].S1 for fid in model.firm1_ids if Agents.hasid(model, fid); init=0.0)
        if total_s1 > 0
            for fid in model.firm1_ids
                if Agents.hasid(model, fid)
                    model[fid].f1 = model[fid].S1 / total_s1
                end
            end
        else
            # Equal shares
            n = length([fid for fid in model.firm1_ids if Agents.hasid(model, fid)])
            if n > 0
                for fid in model.firm1_ids
                    if Agents.hasid(model, fid)
                        model[fid].f1 = 1.0 / n
                    end
                end
            end
        end
    end
end
