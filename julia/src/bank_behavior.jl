"""
    bank_behavior.jl

Behavioral functions for banks.
Implements credit allocation, reserve management, etc.
Corresponds to fun_KS_bank.h in C model.
"""

"""
    bank_update_interest_rates!(bank::Bank, model)

Update interest rates based on central bank prime rate.
"""
function bank_update_interest_rates!(bank::Bank, model)
    params = model.params
    
    bank.r = model.r
    bank.rDeb = model.r + params.muDeb
    bank.rD = model.r - params.muD
end

"""
    bank_evaluate_credit!(bank::Bank, model)

Evaluate credit requests and create pecking order.
"""
function bank_evaluate_credit!(bank::Bank, model)
    # Build pecking order based on liquidity-to-sales ratio
    pecking_order = Tuple{Int,Float64}[]
    
    # Evaluate sector 1 clients
    for fid in bank.client1_ids
        if hasid(model, fid)
            firm = model[fid]
            score = firm.NW1 > 0 ? firm.NW1 / max(firm.S1, 1.0) : 0.0
            push!(pecking_order, (fid, score))
        end
    end
    
    # Evaluate sector 2 clients
    for fid in bank.client2_ids
        if hasid(model, fid)
            firm = model[fid]
            score = firm.NW2 > 0 ? firm.NW2 / max(firm.S2, 1.0) : 0.0
            push!(pecking_order, (fid, score))
        end
    end
    
    # Sort by score (descending)
    sort!(pecking_order, by=x->x[2], rev=true)
    bank.pecking_order = pecking_order
end

"""
    bank_allocate_credit!(bank::Bank, model)

Allocate credit to firms according to pecking order.
"""
function bank_allocate_credit!(bank::Bank, model)
    params = model.params
    
    # Compute available credit supply
    if params.flagCreditRule == 0
        # No limit
        credit_available = Inf
    elseif params.flagCreditRule == 1
        # Deposit multiplier
        credit_available = params.Lambda * bank.Depo
    else  # flagCreditRule == 2
        # Basel-like capital adequacy
        credit_available = bank.NWb / params.tauB - bank.Loans
    end
    
    credit_available = max(0.0, credit_available)
    
    # Allocate to firms in pecking order
    for (fid, score) in bank.pecking_order
        if credit_available <= 0
            break
        end
        
        if !hasid(model, fid)
            continue
        end
        
        firm = model[fid]
        
        # Firm's credit demand and maximum
        if isa(firm, Firm1)
            # Firm1: need credit for production
            revenue = firm.S1 * firm.p1
            cost = firm.L1 * firm.w1
            credit_need = max(0.0, cost - firm.NW1)
            credit_max = params.Lambda * max(firm.NW1, revenue - cost) - firm.Deb1
            credit_max = max(credit_max, params.Lambda0)
            
        else  # Firm2
            # Firm2: need credit for production and investment
            revenue = firm.S2 * firm.p2
            cost = firm.L2 * firm.w2
            investment_cost = firm.Id * model.p1avg
            credit_need = max(0.0, cost + investment_cost - firm.NW2)
            credit_max = params.Lambda * max(firm.NW2, revenue - cost) - firm.Deb2
            credit_max = max(credit_max, params.Lambda0)
        end
        
        # Credit granted
        credit_granted = min(credit_need, credit_max, credit_available)
        
        if credit_granted > 0
            # Update firm
            if isa(firm, Firm1)
                firm.Deb1 += credit_granted
                firm.NW1 += credit_granted
            else
                firm.Deb2 += credit_granted
                firm.NW2 += credit_granted
            end
            
            # Update bank
            if isa(firm, Firm1)
                bank.Loans1 += credit_granted
            else
                bank.Loans2 += credit_granted
            end
            bank.Loans += credit_granted
            credit_available -= credit_granted
        end
    end
end

"""
    bank_collect_deposits!(bank::Bank, model)

Collect deposits from firms.
"""
function bank_collect_deposits!(bank::Bank, model)
    total_deposits = 0.0
    
    # Sector 1 deposits
    for fid in bank.client1_ids
        if hasid(model, fid)
            firm = model[fid]
            deposit = max(0.0, firm.NW1 - firm.Deb1)
            total_deposits += deposit
        end
    end
    
    # Sector 2 deposits
    for fid in bank.client2_ids
        if hasid(model, fid)
            firm = model[fid]
            deposit = max(0.0, firm.NW2 - firm.Deb2)
            total_deposits += deposit
        end
    end
    
    bank.Depo = total_deposits
end

"""
    bank_manage_reserves!(bank::Bank, model)

Manage required and excess reserves.
"""
function bank_manage_reserves!(bank::Bank, model)
    params = model.params
    
    # Required reserves (fraction of deposits)
    bank.Res = params.tauB * bank.Depo
    
    # Excess reserves (free cash)
    cash_flow = bank.Depo - bank.Loans
    bank.ExRes = max(0.0, cash_flow - bank.Res)
end

"""
    bank_trade_bonds!(bank::Bank, model)

Trade sovereign bonds to manage liquidity.
"""
function bank_trade_bonds!(bank::Bank, model)
    params = model.params
    
    # Try to minimize excess reserves by trading bonds
    if bank.ExRes > 0
        # Buy bonds with excess reserves
        bonds_available = model.BS + model.BondsCB / params.thetaBonds
        bond_demand = bank.ExRes
        bonds_bought = min(bond_demand, bonds_available * 0.1)  # Limited share
        
        bank.BondsB += bonds_bought
        bank.ExRes -= bonds_bought
        
    elseif bank.ExRes < 0
        # Sell bonds to cover shortfall
        bonds_to_sell = min(-bank.ExRes, bank.BondsB)
        bank.BondsB -= bonds_to_sell
        bank.ExRes += bonds_to_sell
    end
    
    # If still illiquid, get loan from central bank
    if bank.ExRes < 0
        bank.LoansCB += -bank.ExRes
        bank.ExRes = 0.0
    end
    
    # Repay central bank loans if possible
    if bank.ExRes > 0 && bank.LoansCB > 0
        repayment = min(bank.ExRes, bank.LoansCB)
        bank.LoansCB -= repayment
        bank.ExRes -= repayment
    end
end

"""
    bank_compute_profits!(bank::Bank, model)

Compute bank profits.
"""
function bank_compute_profits!(bank::Bank, model)
    params = model.params
    
    # Interest income from loans
    interest_income = bank.Loans * bank.rDeb
    
    # Interest paid on deposits
    interest_paid = bank.Depo * bank.rD
    
    # Interest paid to central bank
    cb_interest = bank.LoansCB * model.r
    
    # Net interest margin
    profit = interest_income - interest_paid - cb_interest
    
    # Bad debt losses
    profit -= bank.BadDeb
    
    return profit
end

"""
    bank_check_bailout!(bank::Bank, model)

Check if bank needs bailout and execute if needed.
"""
function bank_check_bailout!(bank::Bank, model)
    params = model.params
    
    if params.flagCreditRule == 2
        # Check capital adequacy
        if bank.NWb < 0
            # Bailout needed
            bailout_amount = -bank.NWb + params.PhiB * mean([model[b].NWb for b in model.bank_ids])
            
            bank.NWb += bailout_amount
            model.Gbail += bailout_amount
            
            # Reset bad debt
            bank.BadDeb = 0.0
            bank.BadDeb1 = 0.0
            bank.BadDeb2 = 0.0
            
            return true
        end
    end
    
    return false
end
