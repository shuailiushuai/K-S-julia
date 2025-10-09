# K+S Model Complete Pseudocode Documentation

## Model Overview

The K+S (Keynes meets Schumpeter) model is a stock-flow consistent, agent-based macroeconomic model with heterogeneous agents operating in three interconnected sectors:

1. **Capital-Good Sector (Sector 1)**: Firms invest in R&D and produce heterogeneous machines
2. **Consumption-Good Sector (Sector 2)**: Firms produce consumer goods using machines and labor
3. **Financial Sector**: Banks provide credit, Central Bank sets interest rates
4. **Labor Market**: Workers search for jobs, firms hire/fire based on demand
5. **Government**: Taxes, unemployment benefits, training, fiscal policy

## Agent Types

### 1. Worker Agent
**Attributes:**
- `ID`: Unique identifier
- `age`: Working age
- `employed`: Employment status (0=unemployed, 1=sector1, 2=sector2)
- `w`: Current wage
- `wRes`: Reservation wage (minimum acceptable)
- `Te`: Tenure (time employed in current firm)
- `Tc`: Contract term duration
- `sV`: Vintage skills (machine-specific, learning-by-using)
- `sT`: Tenure skills (firm-specific, learning-by-doing)
- `employer`: Reference to employing firm (if employed)
- `vintage`: Reference to machine vintage working with
- `searchProb`: Individual job search probability

**Behaviors:**
```
PROCEDURE worker_init(age_range, initial_skills, reservation_wage):
    Draw random age from age_range
    Set initial skills = initial_skills
    Set employed = 0
    Set wRes = reservation_wage
    Set Te = 0
END

PROCEDURE apply_for_jobs():
    IF flagSearchMode == 0:  // always search
        num_applications = omega * searchProb
    ELIF flagSearchMode == 1:  // only if unemployed
        num_applications = omegaU * searchProb IF unemployed ELSE 0
    ELIF flagSearchMode == 2:  // if unemployed or low wage
        num_applications = omega * searchProb IF (unemployed OR w < wAvg) ELSE 0
    
    IF flagSearchDisc == 1:  // global discouragement
        searchProb = kappa * exp(-kappa * unemployment_rate)
    ELIF flagSearchDisc == 2:  // individual discouragement
        searchProb = exp(-lambda * individual_unemployment_duration)
    
    // Select firms proportional to their size
    FOR i in 1 to num_applications:
        firm = select_firm_weighted_by_size()
        requested_wage = calculate_requested_wage()
        application = {worker: self, wage: requested_wage, skills: (sV, sT), tenure: Te}
        firm.add_application(application)
    
    RETURN num_applications
END

PROCEDURE calculate_requested_wage():
    IF Ts == 0:  // no memory
        RETURN wRes
    ELSE:  // memory of past Ts periods
        wage_memory = [w(t-1), w(t-2), ..., w(t-Ts)]
        RETURN max(wage_memory)
    END
END

PROCEDURE update_skills():
    IF employed in sector 2:
        // Vintage skills (learning-by-using)
        IF flagWorkerLBU == 1 OR flagWorkerLBU == 3:
            sV = sV + (sV_public_vintage - sV) * learning_rate
        
        // Tenure skills (learning-by-doing)
        IF flagWorkerLBU == 2 OR flagWorkerLBU == 3:
            sT = sT * (1 + tauT)
    
    IF unemployed:
        // Skills deterioration
        sV = sV * (1 - tauU)
        sT = sT * (1 - tauU)
        
        // Government training
        IF receives_training (prob = Gamma):
            sV = sV * (1 + tauG)
            sT = sT * (1 + tauG)
END

PROCEDURE age_worker():
    age = age + 1
    IF age >= Tr:  // retirement
        age = 1  // "reborn" as new worker
        employed = 0
        Reset skills to initial
        Te = 0
    END
END

PROCEDURE produce():
    IF employed AND vintage != NULL:
        output = sV * sT * vintage.productivity
        RETURN output
    RETURN 0
END
```

### 2. Firm1 Agent (Capital-Good Sector)
**Attributes:**
- `ID`: Unique identifier
- `NW1`: Net worth
- `Deb1`: Total debt
- `S1`: Sales revenue
- `Pi1`: Profits
- `Q1`: Production quantity (machines)
- `p1`: Machine price
- `Atau`: Current technology productivity (A)
- `Btau`: Production technology productivity (B)
- `L1`: Number of workers
- `L1rd`: Workers in R&D
- `f1`: Market share
- `clients`: List of client firms (Firm2)
- `bank`: Reference to bank
- `wage_offer`: Current wage offer

**Behaviors:**
```
PROCEDURE firm1_init(initial_NW, initial_debt_ratio):
    NW1 = initial_NW
    Deb1 = initial_NW * initial_debt_ratio / (1 - initial_debt_ratio)
    Atau = INIPROD
    Btau = INIPROD
    L1 = calculate_initial_labor()
    clients = []
    bank = assign_bank()
    f1 = 1.0 / F10  // equal initial market share
END

PROCEDURE rd_innovation_imitation():
    L1rdN = L1rd * Ls0 / Ls  // normalized R&D workers
    
    // INNOVATION
    prob_innovation = 1 - exp(-zeta1 * xi * L1rdN)
    IF bernoulli(prob_innovation):
        draw = beta_distribution(alpha1, beta1)
        Ainn = Atau * (1 + x1inf + draw * (x1sup - x1inf))
        Binn = Btau * (1 + x1inf + draw * (x1sup - x1inf))
        pInn = (1 + mu1) * w1avg / Binn / m1
        cInn = w2avg / Ainn
    
    // IMITATION
    prob_imitation = 1 - exp(-zeta2 * (1 - xi) * L1rdN)
    IF bernoulli(prob_imitation):
        // Select firm to imitate based on euclidean distance
        FOR each other_firm1:
            p_other = (1 + mu1) * w1avg / other_firm1.Btau / m1
            c_other = w2avg / other_firm1.Atau
            distance = sqrt(((p_other - p1) / p1avg)^2 + ((c_other - c1) / c2avg)^2)
            prob_imitate[other_firm1] = 1 / distance (normalized)
        
        selected = choose(other_firms, probs=prob_imitate)
        Aimi = selected.Atau
        Bimi = selected.Btau
    
    // Select best technology
    IF innovation_successful OR imitation_successful:
        technologies = [(Atau, Btau, p1), (Ainn, Binn, pInn), (Aimi, Bimi, pImi)]
        best = select_by_payback_period(technologies, b, w2avg, m2)
        Atau = best.A
        Btau = best.B
END

PROCEDURE receive_orders():
    D1 = SUM(client.order for client in clients)
    
    // Acquire new clients
    num_new_clients = gamma * COUNT(Firm2)
    FOR i in 1 to num_new_clients:
        potential_client = random_firm2_not_client()
        send_brochure(potential_client)
END

PROCEDURE plan_production():
    Q1 = D1  // produce to order
    L1d = Q1 / (m1 * Btau)  // desired production labor
    L1dRD = nu * S1(-1) / w1avg  // desired R&D labor
    
    // Limit R&D labor
    L1dRD = min(L1dRD, L1rdMax * (L1d + L1dRD))
    
    L1d_total = L1d + L1dRD
END

PROCEDURE hire_fire_workers():
    L1shortage = max(L1d_total - L1, 0)
    L1surplus = max(L1 - L1d_total, 0)
    
    // Hire
    IF L1shortage > 0 AND L1shortage / L1d_total <= L1shortMax:
        applications = get_applications()
        applications = sort_by_hiring_order(applications, flagHireOrder1)
        
        wage_offer = calculate_wage_offer(applications)
        
        FOR app in applications:
            IF hired_count < L1shortage:
                IF app.wage <= wage_offer:
                    hire_worker(app.worker, wage_offer)
                    hired_count += 1
    
    // Fire
    IF L1surplus > 0:
        workers = sort_by_firing_order(workers, flagFireOrder1)
        FOR worker in workers[0:L1surplus]:
            fire_worker(worker)
END

PROCEDURE set_price():
    p1 = (1 + mu1) * w1avg / Btau / m1
END

PROCEDURE produce():
    L1e = COUNT(workers)  // effective workers
    Q1e = min(Q1, L1e * m1 * Btau)  // actual production
    
    // Distribute production to clients
    FOR client in clients:
        deliver = min(client.order, Q1e * client.order / D1)
        client.receive_machines(deliver)
        Q1e -= deliver
END

PROCEDURE compute_financials():
    S1 = p1 * Q1e  // sales
    W1 = w1avg * L1  // wage bill
    
    Pi1 = S1 - W1  // profits (simplified)
    Tax1 = max(tr * Pi1, 0)
    
    NW1 = NW1(-1) + Pi1 - Tax1 - Div1
    
    // Update debt
    Deb1max = Lambda * max(NW1, S1 - W1)
    IF Deb1 > Deb1max:
        request_credit(Deb1max - Deb1)
END

PROCEDURE exit_condition():
    RETURN (f1 < f1min) OR (NW1 < 0)
END
```

### 3. Firm2 Agent (Consumption-Good Sector)
**Attributes:**
- `ID`: Unique identifier
- `NW2`: Net worth
- `Deb2`: Total debt
- `S2`: Sales revenue
- `Pi2`: Profits
- `Q2`: Production quantity
- `Q2e`: Effective production
- `D2`: Actual demand fulfilled
- `D2d`: Desired demand
- `D2e`: Expected demand
- `p2`: Product price
- `mu2`: Mark-up
- `f2`: Market share
- `E`: Competitiveness
- `L2`: Number of workers
- `K`: Capital stock (number of machines)
- `N`: Inventories
- `vintages`: List of machine vintages
- `supplier`: Current machine supplier (Firm1)
- `bank`: Reference to bank
- `c2`: Unit cost
- `A2`: Average productivity

**Behaviors:**
```
PROCEDURE firm2_init(initial_NW, initial_debt_ratio):
    NW2 = initial_NW
    Deb2 = initial_NW * initial_debt_ratio / (1 - initial_debt_ratio)
    mu2 = mu20
    L2 = calculate_initial_labor()
    K = initial_capital_stock
    vintages = initialize_vintages()
    supplier = select_supplier()
    bank = assign_bank()
    f2 = 1.0 / F20
    N = 0
END

PROCEDURE form_expectations():
    IF life_cycle < 3:  // entrant
        D2e = max(D2d(-1), D2e(-1))  // optimistic
    ELSE:
        e0_param = e0  // animal spirits
        
        SWITCH flagExpect:
            CASE 0:  // myopic 1-period
                D2e = (1 - e0_param) * D2(-1) + e0_param * D2d(-1)
            
            CASE 1:  // myopic 4-period weighted
                D2e = weighted_average([D2(-i) for i in 1..4], [e1, e2, e3, e4])
            
            CASE 2:  // accelerating
                growth = (D2(-1) - D2(-2)) / D2(-2)
                D2e = D2(-1) * (1 + e5 * growth)
            
            CASE 3:  // adaptive
                D2e = D2e(-1) + e6 * (D2(-1) - D2e(-1))
            
            CASE 4:  // extrapolative-accelerating
                D2e = D2(-1) * (1 + e7 * growth + e8 * growth^2)
END

PROCEDURE plan_production():
    Q2 = D2e + iota * D2e - N  // desired production with inventory target
    Q2 = max(Q2, 0)
    
    // Calculate labor demand
    A2 = calculate_average_productivity()
    L2d = Q2 / A2  // desired labor
    L2d = L2d * (1 + theta)  // add slack for capacity
    
    // Calculate investment demand (new machines)
    Kd = Q2 / (u * m2 * A2)  // desired capital
    Id = max(Kd - K, 0)  // expansion investment
    
    // Add replacement investment (machines exceeding payback)
    FOR vintage in vintages:
        IF vintage.age >= b:  // payback period exceeded
            Id += vintage.machines
            remove_vintage(vintage)
    
    // Limit investment by financial constraints
    available_finance = NW2 + Deb2max - Deb2
    Id = min(Id, available_finance / p1avg)
    
    // Order machines from supplier
    IF Id > 0:
        supplier.place_order(Id)
END

PROCEDURE hire_fire_workers():
    L2shortage = max(L2d - L2, 0)
    L2surplus = max(L2 - L2d, 0)
    
    // Hiring sequence
    IF flagHireSeq == 0:
        firms_order = random_shuffle(all_firm2)
    ELIF flagHireSeq == 1:
        firms_order = sort_by_wage_offer(all_firm2, descending=True)
    ELIF flagHireSeq == 2:
        firms_order = [firms_without_workers, random_shuffle(others)]
    ELIF flagHireSeq == 3:
        firms_order = [firms_without_workers, sort_by_wage_offer(others)]
    
    FOR firm in firms_order:
        IF firm == self:
            // My turn to hire
            IF L2shortage > 0:
                applications = get_applications()
                applications = sort_by_hiring_order(applications, flagHireOrder2)
                
                wage_offer = calculate_wage_offer(applications, flagWageOffer)
                
                FOR app in applications:
                    IF hired_count < L2shortage:
                        IF app.wage <= wage_offer:
                            hire_worker(app.worker, wage_offer, vintage)
                            hired_count += 1
    
    // Firing rule
    IF L2surplus > 0:
        SWITCH flagFireRule:
            CASE 0:  // never fire (Japanese)
                pass
            CASE 1:  // work sharing (German)
                reduce_hours_all_workers()
            CASE 2:  // only if downsizing (French)
                IF K < K(-1):
                    fire_surplus_workers()
            CASE 3:  // only if losses (Italian)
                IF Pi2 < 0:
                    fire_surplus_workers()
            CASE 4:  // payback rule (American)
                workers_by_payback = calculate_worker_payback()
                fire_low_payback_workers(L2surplus)
            CASE 5:  // always fire (Brazilian)
                fire_surplus_workers()
END

PROCEDURE produce():
    L2e = COUNT(workers)
    
    // Calculate production by vintage
    Q2e = 0
    FOR vintage in vintages:
        workers_in_vintage = vintage.workers
        skills_avg = average_skills(workers_in_vintage)
        productivity = vintage.A * skills_avg
        output = min(vintage.machines * m2, workers_in_vintage * productivity)
        Q2e += output
    
    Q2e = min(Q2e, Q2)  // don't exceed planned
END

PROCEDURE set_price():
    c2 = W2 / Q2e  // unit cost
    
    // Adaptive markup
    IF f2(-1) > f2(-2):
        mu2 = mu2(-1) * (1 + upsilon)
    ELIF f2(-1) < f2(-2):
        mu2 = mu2(-1) * (1 - upsilon)
    
    mu2 = max(mu2, 0)
    p2 = (1 + mu2) * c2
END

PROCEDURE update_competitiveness():
    E = omega1 * (1 - p2_normalized) + 
        omega2 * (1 - unfilled_demand_ratio) +
        omega3 * quality_index
END

PROCEDURE compute_financials():
    S2 = p2 * D2  // sales (fulfilled demand)
    W2 = w2avg * L2  // wage bill
    
    Pi2 = S2 - W2 - depreciation - interest_payments
    Tax2 = max(tr * Pi2, 0)
    
    // Bonuses (profit sharing)
    IF Pi2 > Pi2avg AND L2 > 0:
        Bon2 = psi6 * (Pi2 - Tax2)
    
    NW2 = NW2(-1) + Pi2 - Tax2 - Div2 - Bon2
    
    // Update inventories
    N = N(-1) + Q2e - D2
END

PROCEDURE select_supplier():
    // Receive brochures from suppliers
    brochures = receive_brochures()
    
    // Select best supplier by payback period
    best_supplier = NULL
    best_payback = INFINITY
    
    FOR brochure in brochures:
        A = brochure.productivity
        p = brochure.price
        payback = (p / m2) / (p2 * A / w2avg - c2)
        
        IF payback < best_payback:
            best_payback = payback
            best_supplier = brochure.firm
    
    supplier = best_supplier
END

PROCEDURE exit_condition():
    RETURN (f2 < f2min) OR (NW2 < 0)
END
```

### 4. Bank Agent
**Attributes:**
- `ID`: Unique identifier
- `NWb`: Bank net worth
- `Depo`: Total deposits
- `Loans`: Total loans
- `LoansCB`: Loans from central bank
- `Res`: Required reserves
- `ExRes`: Excess reserves
- `BondsB`: Government bonds held
- `clients1`: List of Firm1 clients
- `clients2`: List of Firm2 clients
- `PiB`: Bank profits
- `fB`: Market share (in clients)

**Behaviors:**
```
PROCEDURE bank_init(initial_equity):
    NWb = initial_equity
    Depo = 0
    Loans = 0
    clients1 = []
    clients2 = []
END

PROCEDURE collect_deposits():
    Depo = 0
    
    // Worker deposits
    Depo += fD * SavAcc  // share of total worker savings
    
    // Firm deposits
    FOR client in clients1 + clients2:
        Depo += max(client.NW, 0)
END

PROCEDURE evaluate_credit_requests():
    // Create pecking order based on liquidity ratios
    rank1 = []
    rank2 = []
    
    FOR client in clients1:
        ratio = client.NW / client.S
        rank1.append((client, ratio))
    
    FOR client in clients2:
        ratio = client.NW / client.S
        rank2.append((client, ratio))
    
    rank1 = sort(rank1, by=ratio, descending=True)
    rank2 = sort(rank2, by=ratio, descending=True)
    
    // Assign credit classes (quartiles)
    FOR i, (client, ratio) in enumerate(rank1):
        IF i < len(rank1) * 0.25:
            client.qc1 = 1
        ELIF i < len(rank1) * 0.5:
            client.qc1 = 2
        ELIF i < len(rank1) * 0.75:
            client.qc1 = 3
        ELSE:
            client.qc1 = 4
    
    // Similar for rank2...
END

PROCEDURE supply_credit():
    // Total credit supply limit
    IF flagCreditRule == 0:
        credit_limit = INFINITY
    ELIF flagCreditRule == 1:
        credit_limit = Lambda * Depo
    ELIF flagCreditRule == 2:
        credit_limit = Depo / tauB  // Basel-like
    
    credit_available = credit_limit - Loans
    
    // Allocate credit by pecking order
    FOR client in pecking_order:
        credit_requested = min(client.CD, client.Debmax - client.Deb)
        credit_class = client.qc
        
        // Interest rate premium by credit class
        r_client = rDeb + kConst * credit_class
        
        credit_supplied = min(credit_requested, credit_available)
        
        IF credit_supplied > 0:
            client.Deb += credit_supplied
            client.CS = credit_supplied
            Loans += credit_supplied
            credit_available -= credit_supplied
        
        IF credit_supplied < credit_requested:
            client.CD_constrained = True
END

PROCEDURE compute_financials():
    // Interest income from loans
    iLb = calculate_interest_income(Loans, rDeb)
    
    // Interest payments on deposits
    iDb = calculate_interest_payments(Depo, rD)
    
    // Interest payments to CB
    iCBb = rRes * Res + r * LoansCB
    
    // Bad debt from bankruptcies
    BadDeb = sum_bad_debt_from_exits()
    
    PiB = iLb - iDb - iCBb - BadDeb
    
    TaxB = max(tr * PiB, 0)
    
    NWb = NWb(-1) + PiB - TaxB - DivB
END

PROCEDURE manage_reserves():
    Res = tauB * Depo  // required reserves
    
    ExRes = calculate_excess_reserves()
    
    // Trade bonds to minimize excess reserves
    IF ExRes < 0:
        // Sell bonds or request CB loan
        bonds_to_sell = min(-ExRes, BondsB)
        BondsB -= bonds_to_sell
        ExRes += bonds_to_sell
        
        IF ExRes < 0:
            LoansCB += -ExRes
            ExRes = 0
    
    ELIF ExRes > 0:
        // Buy bonds
        bonds_available = fB * bond_supply
        bonds_to_buy = min(ExRes, bonds_available)
        BondsB += bonds_to_buy
        ExRes -= bonds_to_buy
END

PROCEDURE bailout_condition():
    RETURN NWb < 0
END
```

### 5. Central Bank (Government Entity)
**Behaviors:**
```
PROCEDURE set_interest_rate():
    // Taylor rule
    piT_target = piT
    Ut_target = Ut
    
    pi_actual = CPI_growth
    U_actual = unemployment_rate
    
    // Dual mandate
    r_new = r + gammaPi * (pi_actual - piT_target) + 
            gammaU * (U_actual - Ut_target)
    
    // Minimum adjustment step
    IF abs(r_new - r) < rAdj:
        r = r  // no change
    ELSE:
        r = r_new
    
    // Interest rate structure
    rDeb = r + muDeb  // loan rate
    rD = r * (1 - muD)  // deposit rate
    rRes = r * (1 - muRes)  // reserves rate
    rBonds = r * (1 - muBonds)  // bonds rate
END

PROCEDURE bailout_banks():
    FOR bank in banks:
        IF bank.NWb < 0:
            bailout_amount = -bank.NWb + PhiB * average_bank_NWb
            bank.NWb = PhiB * average_bank_NWb
            government.G += bailout_amount
            government.bailout_costs += bailout_amount
END
```

### 6. Government Entity
**Behaviors:**
```
PROCEDURE collect_taxes():
    Tax = Tax1 + Tax2 + TaxB + TaxW
    
    TaxW = 0
    IF flagTax == 1:
        FOR worker in workers:
            IF worker.employed:
                TaxW += tr * (worker.w + worker.bonus)
END

PROCEDURE government_expenditure():
    G = 0
    
    // Minimum subsistence
    IF flagGovExp >= 0:
        G += w0min * COUNT(unemployed_workers)
    
    // Fixed government expenditure
    IF flagGovExp >= 1:
        G += G_fixed * (1 + gG)
    
    // Unemployment benefits
    IF flagGovExp >= 2:
        G += wU * COUNT(unemployed_workers)
    
    // Training
    G += Gtrain
    
    // Bank bailouts
    G += bailout_costs
    
    // Surplus spending
    IF flagGovExp >= 3 AND Deb <= 0:
        G += surplus
END

PROCEDURE fiscal_policy():
    Def = G - Tax  // primary deficit
    Deb = Deb(-1) + Def + interest_on_debt
    
    // Fiscal rules
    IF flagFiscalRule > 0 AND t > Trule:
        debt_ratio = Deb / GDP
        deficit_ratio = Def / GDP
        
        IF flagFiscalRule == 1 OR flagFiscalRule == 3:
            // Balanced budget rule
            IF deficit_ratio > DefPrule:
                cut_expenditure()
            
            IF flagFiscalRule == 3 AND debt_ratio > DebRule:
                increase_taxes()
                repay_debt()
        
        ELIF flagFiscalRule == 2 OR flagFiscalRule == 4:
            // Soft rule (only if GDP growing)
            IF GDP_growth > 0:
                IF deficit_ratio > DefPrule:
                    cut_expenditure()
                
                IF flagFiscalRule == 4 AND debt_ratio > DebRule:
                    increase_taxes()
                    repay_debt()
END
```

## Main Model Scheduling

```
PROCEDURE initialize_model():
    // Create agents
    FOR i in 1 to F10:
        create_firm1()
    
    FOR i in 1 to F20:
        create_firm2()
    
    FOR i in 1 to B:
        create_bank()
    
    FOR i in 1 to Ls0:
        create_worker()
    
    // Initialize connections
    FOR firm1 in all_firm1:
        firm1.bank = random_bank()
        firm1.clients = sample(all_firm2, gamma * F20)
    
    FOR firm2 in all_firm2:
        firm2.bank = random_bank()
        firm2.supplier = random_firm1()
    
    // Initialize variables
    initialize_macro_statistics()
END

PROCEDURE time_step(t):
    // 1. Regime change check
    IF t == TregChg:
        apply_regime_change()
    
    // 2. Central bank monetary policy
    central_bank.set_interest_rate()
    
    // 3. Consumption-good firms form expectations and plan production
    FOR firm2 in all_firm2:
        firm2.form_expectations()
        firm2.plan_production()
    
    // 4. Capital-good firms do R&D and receive orders
    FOR firm1 in all_firm1:
        firm1.rd_innovation_imitation()
        firm1.receive_orders()
        firm1.plan_production()
    
    // 5. Labor market: job applications
    FOR worker in all_workers:
        worker.apply_for_jobs()
    
    // 6. Firms post job openings
    FOR firm1 in all_firm1:
        firm1.post_job_openings()
    
    FOR firm2 in all_firm2:
        firm2.post_job_openings()
    
    // 7. Hiring process (sequential for firm2, random for firm1)
    FOR firm1 in all_firm1:
        firm1.hire_fire_workers()
    
    FOR firm2 in all_firm2 (ordered by flagHireSeq):
        firm2.hire_fire_workers()
    
    // 8. Production
    FOR firm1 in all_firm1:
        firm1.produce()
    
    FOR firm2 in all_firm2:
        firm2.produce()
    
    // 9. Price setting
    FOR firm1 in all_firm1:
        firm1.set_price()
    
    FOR firm2 in all_firm2:
        firm2.set_price()
    
    // 10. Government expenditure decision
    government.government_expenditure()
    
    // 11. Consumption demand
    Cd = calculate_consumption_demand()
    
    // 12. Market matching (consumption goods)
    match_consumption_market()
    
    // 13. Update competitiveness and market shares
    FOR firm2 in all_firm2:
        firm2.update_competitiveness()
    
    update_market_shares()
    
    // 14. Compute financial results
    FOR firm1 in all_firm1:
        firm1.compute_financials()
    
    FOR firm2 in all_firm2:
        firm2.compute_financials()
    
    FOR bank in all_banks:
        bank.compute_financials()
    
    // 15. Credit market
    FOR bank in all_banks:
        bank.evaluate_credit_requests()
        bank.supply_credit()
    
    // 16. Government finances
    government.collect_taxes()
    government.fiscal_policy()
    
    // 17. Bank reserve management
    FOR bank in all_banks:
        bank.manage_reserves()
    
    // 18. Bailouts
    central_bank.bailout_banks()
    
    // 19. Entry and exit
    process_exits()
    process_entries()
    
    // 20. Worker aging and skills update
    FOR worker in all_workers:
        worker.update_skills()
        worker.age_worker()
    
    // 21. Update statistics
    update_macro_statistics()
END

PROCEDURE match_consumption_market():
    // Replicator dynamics for market share
    E_sum = SUM(firm2.f2 * firm2.E for firm2 in all_firm2)
    
    FOR firm2 in all_firm2:
        f2_new = firm2.f2 * (1 + chi * (firm2.E - E_sum))
        firm2.f2 = max(f2_new, 0)
    
    // Normalize market shares
    f2_total = SUM(firm2.f2 for firm2 in all_firm2)
    FOR firm2 in all_firm2:
        firm2.f2 = firm2.f2 / f2_total
    
    // Allocate demand
    D2_total = Cd
    FOR firm2 in all_firm2:
        firm2.D2d = firm2.f2 * D2_total
        firm2.D2 = min(firm2.D2d, firm2.Q2e + firm2.N)
        firm2.unfilled = firm2.D2d - firm2.D2
    
    // Handle forced savings
    D2_fulfilled = SUM(firm2.D2 for firm2 in all_firm2)
    SavForced = max(D2_total - D2_fulfilled, 0)
END

PROCEDURE process_exits():
    FOR firm1 in all_firm1:
        IF firm1.exit_condition():
            // Fire all workers
            FOR worker in firm1.workers:
                worker.employed = 0
                worker.employer = NULL
            
            // Bad debt to bank
            firm1.bank.add_bad_debt(firm1.Deb1)
            
            // Remove from market
            remove_firm1(firm1)
    
    FOR firm2 in all_firm2:
        IF firm2.exit_condition():
            // Fire all workers
            FOR worker in firm2.workers:
                worker.employed = 0
                worker.employer = NULL
            
            // Bad debt to bank
            firm2.bank.add_bad_debt(firm2.Deb2)
            
            // Remove from market
            remove_firm2(firm2)
END

PROCEDURE process_entries():
    // Entry condition (omicron sensitivity)
    entry_condition1 = (NW1_total / Deb1_total) vs target
    entry_condition2 = (NW2_total / Deb2_total) vs target
    
    // Sector 1 entry
    F1_target = F10 * (1 + stick * (entry_condition1 - 1))
    F1_entry = max(round(F1_target - COUNT(firm1)), 0)
    F1_entry = min(F1_entry, F1max - COUNT(firm1))
    
    FOR i in 1 to F1_entry:
        entrant = create_firm1_entrant()
        all_firm1.append(entrant)
    
    // Sector 2 entry
    F2_target = F20 * (1 + stick * (entry_condition2 - 1))
    F2_entry = max(round(F2_target - COUNT(firm2)), 0)
    F2_entry = min(F2_entry, F2max - COUNT(firm2))
    
    // Post-change type entry proportion
    IF t < TregChg + ent2HldPer:
        post_chg_prob = ent2HldShr
    ELSE:
        post_chg_prob = f2_postchg_market_share
    
    FOR i in 1 to F2_entry:
        is_postchg = bernoulli(post_chg_prob)
        entrant = create_firm2_entrant(is_postchg)
        all_firm2.append(entrant)
END
```

## Key Statistics Collection

```
PROCEDURE update_macro_statistics():
    // Real GDP (value added)
    GDPreal = (Q1e + Q2e) / (p1avg + p2avg)
    
    // Nominal GDP
    GDPnom = S1 + S2
    
    // Unemployment
    L = COUNT(employed_workers)
    Ls = COUNT(all_workers)
    Ue = (Ls - L) / Ls
    
    // Wages
    wAvg = AVERAGE(worker.w for worker in employed_workers)
    
    // Productivity
    A = (Q1e + Q2e) / L
    
    // Inflation
    CPI = (p1avg + p2avg) / 2
    dCPI = (CPI - CPI(-1)) / CPI(-1)
    
    // Financial aggregates
    NW1_total = SUM(firm1.NW1 for firm1 in all_firm1)
    NW2_total = SUM(firm2.NW2 for firm2 in all_firm2)
    Deb1_total = SUM(firm1.Deb1 for firm1 in all_firm1)
    Deb2_total = SUM(firm2.Deb2 for firm2 in all_firm2)
    
    // Firm statistics
    F1 = COUNT(all_firm1)
    F2 = COUNT(all_firm2)
    
    // Market concentration (HHI)
    HHI1 = SUM(firm1.f1^2 for firm1 in all_firm1)
    HHI2 = SUM(firm2.f2^2 for firm2 in all_firm2)
END
```

## Parameters Summary

**Country-level**: tr, TregChg, gG, mPer, mLim, omicron, stick, Crec, x2inf, x2sup

**Financial**: B, Lambda, tauB, rT, muD, muDeb, muRes, muBonds, alphaB, betaB, dB, deltaB, deltaDeb, EqB0, Lambda0, PhiB, kConst, Ut, piT, gammaPi, gammaU, rAdj, Trule, DebRule, DefPrule, thetaBonds, rhoBonds, mPerB

**Capital (Firm1)**: F10, F1max, F1min, NW10, Deb10ratio, mu1, nu, m1, xi, zeta1, zeta2, alpha1, beta1, alpha2, beta2, x1inf, x1sup, x5, gamma, d1, n1, L1rdMax, L1shortMax, Phi3, Phi4

**Consumption (Firm2)**: F20, F2max, F2min, NW20, Deb20ratio, mu20, b, m2, iota, u, eta, chi, upsilon, e0, e1-e8, d2, n2, omega1, omega2, omega3, kappaMin, kappaMax, f2min, f2trdChg, f2minPosChg, ent2HldPer, ent2HldShr, Phi1, Phi2

**Labor**: Ls0, Lscale, Tr, Tc, Tp, Ts, delta, omega, omegaU, omegaPreChg, omegaPostChg, phi, w0min, wCap, epsilon, psi1-psi6, rho, sigma, tauT, tauU, tauG, Gamma, GammaCost, theta, kappa, lambda

**Control flags**: flagCons, flagGovExp, flagTax, flagCreditRule, flagFiscalRule, flagAllFirmsChg, flagExpect, flagAddWorkers, flagSearchMode, flagSearchDisc, flagHireSeq, flagHireOrder1/2, flagFireOrder1/2, flagFireRule, flagHeterWage, flagWageOffer, flagWagePremium, flagIndexWage, flagIndexMinWage, flagLearn1, flagWorkerLBU, flagWorkerSkProd

## Implementation Notes

1. **Time Scale**: Each time step represents one period (quarter or year depending on calibration)

2. **Random Numbers**: Use same random seed for reproducibility, matching C++ mt19937_64 engine

3. **Initialization**: Special care for initial conditions to ensure stock-flow consistency

4. **Performance**: Use vectorization where possible, avoid nested loops in agent iterations

5. **Validation**: Compare aggregate time series, distributions, and correlations with C++ version

6. **Extensions**: Model supports regime changes at specified time, allowing policy experiments
