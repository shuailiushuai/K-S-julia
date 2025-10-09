"""
    markets.jl

Market mechanisms and matching processes.
Implements labor market, capital goods market, consumption goods market.
"""

"""
    labor_market_matching!(model)

Execute labor market search and matching.
CRITICAL: Matches C model sequence:
1. Firing happens first (in both sectors)
2. Workers apply for jobs (to all Firm1, selected Firm2)
3. Sector 1 hires FIRST from shared application pool
4. Sector 2 hires SECOND from individual firm queues
"""
function labor_market_matching!(model)
    params = model.params
    
    # PHASE 1: FIRING
    # Fire workers who need to be fired (before hiring)
    for fid in model.firm1_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        if firm.L1 > firm.L1d
            fire_workers!(firm, model, Int(floor(firm.L1 - firm.L1d)))
        end
    end
    
    for fid in model.firm2_ids
        if !Agents.hasid(model, fid)
            continue
        end
        firm = model[fid]
        if firm.L2 > firm.L2d && can_fire(firm, model)
            fire_workers!(firm, model, Int(floor(firm.L2 - firm.L2d)))
        end
    end
    
    # PHASE 2: APPLICATIONS
    # Clear previous applications
    for fid in vcat(model.firm1_ids, model.firm2_ids)
        if Agents.hasid(model, fid)
            empty!(model[fid].applications)
        end
    end
    
    # Workers apply for jobs (to ALL Firm1, and selected Firm2)
    for wid in model.worker_ids
        worker = model[wid]
        worker_apply_for_jobs!(worker, model)
    end
    
    # PHASE 3: SECTOR 1 HIRING (Capital goods)
    # Firms in sector 1 share a common application pool
    # They hire in order based on flagHireSeq
    
    # Collect all unique applicants to sector 1
    sector1_applicants = Set{Int}()
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            union!(sector1_applicants, model[fid].applications)
        end
    end
    
    # Order sector 1 firms for hiring
    firm1_order = order_firms_for_hiring(model, model.firm1_ids)
    
    # Track which workers have been hired already (to avoid double hiring)
    hired_workers = Set{Int}()
    
    # Sector 1 firms hire from shared pool
    for fid in firm1_order
        if !Agents.hasid(model, fid)
            continue
        end
        
        firm = model[fid]
        n_needed = Int(ceil(firm.L1d - firm.L1))
        
        if n_needed > 0
            # Filter applications to only those still available
            available_apps = [wid for wid in firm.applications 
                            if wid ∉ hired_workers && Agents.hasid(model, wid)]
            
            if !isempty(available_apps)
                # Order applications based on hiring rule
                ordered_apps = order_applications_for_sector1(firm, model, available_apps)
                
                # Hire workers
                n_hired = hire_workers_from_list!(firm, model, ordered_apps, n_needed, hired_workers)
            end
        end
    end
    
    # PHASE 4: SECTOR 2 HIRING (Consumption goods)
    # Each firm has its own application queue
    firm2_order = order_firms_for_hiring(model, model.firm2_ids)
    
    for fid in firm2_order
        if !Agents.hasid(model, fid)
            continue
        end
        
        firm = model[fid]
        n_needed = Int(ceil(firm.L2d - firm.L2))
        
        if n_needed > 0
            # Filter applications to only those still available
            available_apps = [wid for wid in firm.applications 
                            if wid ∉ hired_workers && Agents.hasid(model, wid)]
            
            if !isempty(available_apps)
                # Order applications based on hiring rule
                ordered_apps = order_applications_for_sector2(firm, model, available_apps)
                
                # Hire workers
                n_hired = hire_workers_from_list!(firm, model, ordered_apps, n_needed, hired_workers)
            end
        end
    end
    
    # PHASE 5: UPDATE STATISTICS
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
    order_applications_for_sector1(firm, model, applicants)

Order job applications for sector 1 firms based on hiring rule.
"""
function order_applications_for_sector1(firm, model, applicants)
    params = model.params
    order_rule = params.flagHireOrder1
    return order_applications_by_rule(model, applicants, order_rule)
end

"""
    order_applications_for_sector2(firm, model, applicants)

Order job applications for sector 2 firms based on hiring rule.
"""
function order_applications_for_sector2(firm, model, applicants)
    params = model.params
    # Check if post-change firm (would use flagHireOrder2Chg)
    order_rule = firm.postChg ? params.flagHireOrder2 : params.flagHireOrder2  # Simplified
    return order_applications_by_rule(model, applicants, order_rule)
end

"""
    order_applications_by_rule(model, applicants, order_rule)

Order applications based on specified rule.
"""
function order_applications_by_rule(model, applicants, order_rule)
    if isempty(applicants)
        return Int[]
    end
    
    if order_rule == 0
        # Random
        return Random.shuffle(Agents.abmrng(model), applicants)
    elseif order_rule == 1 || order_rule == 2
        # By wage
        reverse = (order_rule == 1)  # 1=high first, 2=low first
        return sort(applicants, by = wid -> model[wid].w, rev=reverse)
    elseif order_rule == 3 || order_rule == 4
        # By skills
        reverse = (order_rule == 3)  # 3=high first, 4=low first
        return sort(applicants, by = wid -> model[wid].s, rev=reverse)
    elseif order_rule == 7 || order_rule == 8
        # By tenure
        reverse = (order_rule == 7)  # 7=old first, 8=new first
        return sort(applicants, by = wid -> model[wid].Te, rev=reverse)
    end
    
    return Random.shuffle(Agents.abmrng(model), applicants)
end

"""
    hire_workers_from_list!(firm, model, applicants, n_needed, hired_set)

Hire workers from an ordered list of applicants.
Returns number of workers actually hired.
Updates hired_set to track which workers have been hired.
"""
function hire_workers_from_list!(firm, model, applicants, n_needed, hired_set)
    params = model.params
    is_firm1 = isa(firm, Firm1)
    
    # Compute wage offer
    w_offer = compute_wage_offer(firm, model)
    
    hired = 0
    for wid in applicants
        if hired >= n_needed
            break
        end
        
        if !Agents.hasid(model, wid) || wid ∈ hired_set
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
            
            # Mark as hired
            push!(hired_set, wid)
            hired += 1
        end
    end
    
    return hired
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
    
    # Safety: ensure base wage is finite and positive
    if !isfinite(base_wage) || base_wage <= 0
        base_wage = model.wMin
    end
    
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
                if isfinite(worker.wRes) && worker.wRes > 0
                    min_res_wage = max(min_res_wage, worker.wRes)
                end
            end
        end
        w_offer = min_res_wage
    end
    
    # Cap wage change
    if params.wCap > 0 && params.wCap >= 1.0
        w_offer = clamp(w_offer, base_wage / params.wCap, base_wage * params.wCap)
    end
    
    # Final safety checks
    w_offer = max(w_offer, model.wMin)
    if !isfinite(w_offer) || w_offer <= 0
        w_offer = model.wMin
    end
    
    return w_offer
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
        return firm.NW2 < firm.NW2_prev
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
    
    # Safety check: avoid division by zero
    if model.Ls > 0
        model.Ue = model.U / model.Ls
    else
        model.Ue = 1.0  # All unemployed if no labor force
    end
    
    # Average wage (only from employed workers with finite wages)
    wages = [model[wid].w for wid in model.worker_ids 
             if model[wid].employed > 0 && isfinite(model[wid].w)]
    model.wAvg = isempty(wages) ? model.wMin : mean(wages)
    
    # Safety check: ensure wAvg is finite and positive
    if !isfinite(model.wAvg) || model.wAvg <= 0
        model.wAvg = model.wMin
    end
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
        valid_comp = [model[fid].competitiveness for fid in model.firm2_ids if Agents.hasid(model, fid)]
        E_avg = isempty(valid_comp) ? 0.0 : mean(valid_comp)
        
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
