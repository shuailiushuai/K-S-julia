"""
    worker_behavior.jl

Behavioral functions for workers.
Implements job search, skill updating, consumption, etc.
Corresponds to fun_KS_worker.h in C model.
"""

"""
    worker_apply_for_jobs!(worker::Worker, model)

Worker submits job applications to firms.
CRITICAL: Matches C model where:
- ALL workers apply to a single sector 1 (capital) application pool
- Workers also apply to selected sector 2 (consumption) firms weighted by market share
"""
function worker_apply_for_jobs!(worker::Worker, model)
    params = model.params
    
    # Determine search intensity
    search_mode = params.flagSearchMode
    
    # Check if should search
    should_search = false
    if search_mode == 0  # Always search
        should_search = true
    elseif search_mode == 1  # Only if unemployed
        should_search = (worker.employed == 0)
    elseif search_mode == 2  # If unemployed or wage below average
        should_search = (worker.employed == 0 || worker.w < model.wAvg)
    end
    
    if !should_search
        return
    end
    
    # Number of applications to sector 2 firms (sector 1 always gets one)
    n_apply_sector2 = worker.employed == 0 ? params.omegaU : params.omega
    
    # Apply search probability (discouragement)
    n_apply_actual = n_apply_sector2 * worker.searchProb
    
    # Round to integer probabilistically
    n_apply_int = floor(Int, n_apply_actual)
    if rand(Agents.abmrng(model)) < (n_apply_actual - n_apply_int)
        n_apply_int += 1
    end
    
    if n_apply_int == 0
        worker.discouraged = true
        # Still apply to sector 1 even if discouraged for sector 2
        if !isempty(model.firm1_ids)
            for fid in model.firm1_ids
                if Agents.hasid(model, fid)
                    push!(model[fid].applications, worker.id)
                end
            end
        end
        return
    end
    
    worker.discouraged = false
    
    # CRITICAL: Apply to ALL Firm1 (sector 1) firms
    # This matches C model: EXEC_EXTS( GRANDPARENT, countryE, firm1appl, push_back, applData )
    for fid in model.firm1_ids
        if Agents.hasid(model, fid)
            push!(model[fid].applications, worker.id)
        end
    end
    
    # Apply to selected Firm2 (sector 2) firms weighted by market share
    # This matches C model: firms drawn with probability proportional to market share
    if !isempty(model.firm2_ids)
        # Weight by market share (f2), not by firm size
        weights = Float64[]
        firm2_valid = Int[]
        for fid in model.firm2_ids
            if Agents.hasid(model, fid)
                firm = model[fid]
                # Don't apply to current employer if in sector 2
                if worker.employed != 2 || worker.employer != fid
                    push!(weights, max(firm.f2, 0.001))  # Minimum weight to avoid zero
                    push!(firm2_valid, fid)
                end
            end
        end
        
        if !isempty(firm2_valid) && sum(weights) > 0
            # Sample firms proportional to market share
            n_sample = min(n_apply_int, length(firm2_valid))
            selected_firms = StatsBase.sample(Agents.abmrng(model), firm2_valid, 
                                            Weights(weights), n_sample, replace=false)
            
            # Add to firm application queues
            for fid in selected_firms
                push!(model[fid].applications, worker.id)
            end
        end
    end
end

"""
    worker_update_skills!(worker::Worker, model)

Update worker skills through learning or deterioration.
"""
function worker_update_skills!(worker::Worker, model)
    params = model.params
    
    if worker.employed == 0
        # Unemployed: skills deteriorate
        worker.sT = max(1.0, worker.sT * (1 - params.tauU))
        worker.sV = max(1.0, worker.sV * (1 - params.tauU))
        
        # Government training
        if rand(Agents.abmrng(model)) < params.Gamma
            worker.sT = min(worker.sT * (1 + params.tauG), worker.sT + params.tauG)
        end
        
    elseif worker.employed == 1
        # Employed in sector 1: learning depends on flagLearn1
        if params.flagLearn1 == 2 || params.flagLearn1 == 3
            # Learning
            worker.sT += params.tauT * (1 - worker.sT / 2)
        elseif params.flagLearn1 == 1
            # Deteriorating
            worker.sT = max(1.0, worker.sT * (1 - params.tauU))
        end
        
    elseif worker.employed == 2
        # Employed in sector 2: learning-by-doing (tenure)
        if params.flagWorkerLBU == 2 || params.flagWorkerLBU == 3
            worker.sT += params.tauT * (1 - worker.sT / 2)
        end
        
        # Learning-by-using (vintage)
        if params.flagWorkerLBU == 1 || params.flagWorkerLBU == 3
            if worker.vintage !== nothing
                # Get vintage skills
                employer = model[worker.employer]
                if haskey(employer.vintages, worker.vintage)
                    vintage = employer.vintages[worker.vintage]
                    skill_gap = vintage.sVp - worker.sV
                    if skill_gap > 0
                        worker.sV += params.sigma * skill_gap
                    end
                end
            end
        end
    end
    
    # Update composite skills
    worker.s = (worker.sT + worker.sV) / 2
end

"""
    worker_update_reservation_wage!(worker::Worker, model)

Update reservation wage based on past wages.
"""
function worker_update_reservation_wage!(worker::Worker, model)
    params = model.params
    
    # Update wage memory
    if length(worker.wage_memory) >= params.Ts
        popfirst!(worker.wage_memory)
    end
    push!(worker.wage_memory, worker.w)
    
    # Reservation wage is average of recent wages
    if !isempty(worker.wage_memory)
        worker.wRes = mean(worker.wage_memory)
    else
        worker.wRes = model.wMin
    end
    
    # Cannot be below minimum wage
    worker.wRes = max(worker.wRes, model.wMin)
end

"""
    worker_age!(worker::Worker, model)

Age worker and handle retirement/rebirth.
"""
function worker_age!(worker::Worker, model)
    params = model.params
    
    worker.age += 1
    
    # Retirement
    if params.Tr > 0 && worker.age >= params.Tr
        # "Reborn" as young worker
        worker.age = 1
        worker.employed = 0
        worker.employer = nothing
        worker.vintage = nothing
        worker.Te = 0
        worker.s = 1.0
        worker.sV = 1.0
        worker.sT = 1.0
        worker.w = model.wMin
        worker.wRes = model.wMin
        worker.wage_memory = fill(model.wMin, min(params.Ts, 1))
    end
end

"""
    worker_update_search_probability!(worker::Worker, model)

Update job search probability based on discouragement.
"""
function worker_update_search_probability!(worker::Worker, model)
    params = model.params
    
    if params.flagSearchDisc == 0
        # No discouragement
        worker.searchProb = 1.0
        
    elseif params.flagSearchDisc == 1
        # Global unemployment rate affects all
        worker.searchProb = 1 - params.kappa * model.Ue
        
    elseif params.flagSearchDisc == 2
        # Individual unemployment duration
        if worker.employed == 0
            # Increase discouragement with unemployment duration
            duration = worker.Te  # Counts periods unemployed when negative
            worker.searchProb = max(0.0, 1 - params.lambda * abs(duration) / 10)
        else
            worker.searchProb = 1.0
        end
    end
    
    worker.searchProb = clamp(worker.searchProb, 0.0, 1.0)
end
