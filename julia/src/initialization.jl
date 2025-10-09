"""
    initialization.jl

Model initialization functions.
Creates agents, establishes relationships, and sets initial conditions.
Corresponds to 'initCountry' and related initialization in C model.
"""

"""
    initialize_model(params::ModelParameters)

Initialize the K+S model with given parameters.
Creates all agents and establishes initial relationships.

Returns an ABM model object.
"""
function initialize_model(params::ModelParameters=load_baseline_parameters())
    # Set random seed
    Random.seed!(params.seed)
    
    # Create model properties (Country-level aggregates and state)
    properties = Dict{Symbol,Any}(
        # Parameters
        :params => params,
        :t => 0,  # Current time step
        
        # Macroeconomic aggregates
        :GDP => 0.0,
        :GDPnom => 0.0,
        :GDPreal => 0.0,
        :C => 0.0,
        :Cd => 0.0,
        :I => 0.0,
        :Id => 0.0,
        :G => 0.0,
        :Tax => 0.0,
        :Def => 0.0,
        :Deb => 0.0,
        :Div => 0.0,
        :SavAcc => 0.0,
        :Sav => 0.0,
        
        # Lagged variables for consumption calculation
        :Div_prev => 0.0,  # Previous period dividends
        :f2_prev => Dict{Int,Float64}(),  # Previous period market shares
        
        # Labor market
        :L => 0,
        :Ls => params.Ls0,
        :U => params.Ls0,
        :Ue => 1.0,
        :wAvg => 1.0,
        :wMin => params.w0min,
        :wU => 0.5,
        
        # Financial market
        :r => params.rT,
        :rDeb => params.rT + params.muDeb,
        :rD => params.rT - params.muD,
        :rRes => params.rT - params.muRes,
        :BS => 0.0,
        :Gbail => 0.0,
        :BondsCB => 0.0,
        
        # Sector 1 (Capital)
        :A1 => 1.0,
        :F1 => params.F10,
        :L1 => 0,
        :Q1 => 0.0,
        :S1 => 0.0,
        :D1 => 0.0,
        :PPI => 1.0,
        :p1avg => 1.0,
        
        # Sector 2 (Consumption)
        :A2 => 1.0,
        :F2 => params.F20,
        :L2 => 0,
        :Q2 => 0.0,
        :S2 => 0.0,
        :D2 => 0.0,
        :CPI => 1.0,
        :p2avg => 1.0,
        
        # Collections for efficient lookup
        :firm1_ids => Int[],
        :firm2_ids => Int[],
        :bank_ids => Int[],
        :worker_ids => Int[],
        
        # Wage offers for labor market
        :wage_offers => Dict{Int,Float64}(),
        
        # History for moving averages
        :GDP_history => Float64[],
        :CPI_history => Float64[],
        :inflation => 0.0,
    )
    
    # Create model with no space (agents don't move spatially)
    model = StandardABM(
        Union{Worker,Firm1,Firm2,Bank};
        agent_step! = agent_step!,
        model_step! = model_step!,
        properties = properties,
        rng = MersenneTwister(params.seed),
        warn = false
    )
    
    # Initialize agents
    initialize_banks!(model)
    initialize_firm1!(model)
    initialize_firm2!(model)
    initialize_workers!(model)
    
    # Establish relationships
    establish_bank_firm_relationships!(model)
    establish_firm_customer_relationships!(model)
    
    # Set initial market shares
    initialize_market_shares!(model)
    
    # Initialize lagged variables (pre-history)
    initialize_history!(model)
    
    # Initialize labor demand for all firms at t=0.
    # This ensures firms have proper L_d values before first hiring round.
    # Also ensures initial investment orders exist.
    initialize_labor_demand!(model)
    initialize_investment_demand!(model)
    
    # NOTE: In the C model, workers start unemployed and employment is established
    # naturally through the labor market matching in period 1. We follow the same pattern.
    # Initial employment statistics reflect all workers unemployed
    model.L = 0
    model.U = model.Ls
    model.Ue = 1.0
    
    return model
end

"""
    initialize_banks!(model)

Create initial bank population.
"""
function initialize_banks!(model)
    params = model.params
    
    # Calculate size distribution using Pareto
    total_nw = params.NW10 * params.F10 + params.NW20 * params.F20
    bank_nw = params.EqB0 * total_nw / params.B
    
    for i in 1:params.B
        # Size heterogeneity using Pareto distribution
        size_factor = rand(Agents.abmrng(model), Pareto(params.alphaB))
        nw = bank_nw * size_factor / params.B
        
        bank = Bank(
            id = Agents.nextid(model),
            NWb = nw,
            r = params.rT,
            rDeb = params.rT + params.muDeb,
            rD = params.rT - params.muD
        )
        Agents.add_agent!(bank, model)
        push!(model.bank_ids, bank.id)
    end
end

"""
    initialize_firm1!(model)

Create initial capital-good firm population with proper initial demand.
Matches C model logic from entry_firm1() in fun_KS_support.h.
"""
function initialize_firm1!(model)
    params = model.params
    
    # Calculate initial productivity in sector 1 matching C model
    # Btau0 = (1 + mu1) * INIPROD / (m1 * m2 * b)
    INIPROD = 1.0  # Initial notional machine productivity
    INIWAGE = 1.0  # Initial notional wage
    Btau0 = (1 + params.mu1) * INIPROD / (params.m1 * params.m2 * params.b)
    
    # Initial cost and price in sector 1
    c10 = INIWAGE / (Btau0 * params.m1)
    p10 = (1 + params.mu1) * c10
    
    # Calculate initial demand for sector 1 (from full employment)
    c20 = INIWAGE / INIPROD
    p20 = (1 + params.mu20) * c20
    K0 = ceil(params.Ls0 * INIWAGE / p20 / params.F20 / params.m2) * params.m2
    
    # Initial demand per firm (fair share of total substitution investment)
    D10 = params.F20 * K0 / params.m2 / params.eta / params.F10
    
    # Initial R&D expense
    RD0 = max(params.nu * D10 * p10, INIWAGE)
    
    for i in 1:params.F10
        # Initial technology
        A = INIPROD
        B = Btau0
        
        # Initial net worth with heterogeneity
        nw_factor = params.Phi3 + rand(Agents.abmrng(model)) * (params.Phi4 - params.Phi3)
        nw = params.NW10 * nw_factor
        
        # Initial debt
        deb = nw * params.Deb10ratio / (1 - params.Deb10ratio)
        
        firm = Firm1(
            id = Agents.nextid(model),
            A = A,
            B = B,
            Atau = A,
            Btau = B,
            NW1 = nw,
            Deb1 = deb,
            mu1 = params.mu1,
            w1 = INIWAGE,
            c1 = c10,
            p1 = p10,
            D1 = D10,  # Initialize with expected demand
            S1 = D10 * p10,  # Initialize with expected sales
            S1_prev = D10 * p10,  # Initialize previous sales for R&D calculation
            f1 = 1.0 / params.F10,  # Fair initial market share
            L1rd = floor(RD0 / INIWAGE),  # Initial actual R&D workers (as if hired)
            L1dRD = floor(RD0 / INIWAGE)  # Initial desired R&D workers
        )
        Agents.add_agent!(firm, model)
        push!(model.firm1_ids, firm.id)
    end
end

"""
    initialize_firm2!(model)

Create initial consumption-good firm population with proper initial demand.
Matches C model logic from entry_firm2() in fun_KS_support.h.
"""
function initialize_firm2!(model)
    params = model.params
    
    # Calculate initial steady-state demand (matching C model)
    INIPROD = 1.0
    INIWAGE = 1.0
    Btau0 = (1 + params.mu1) * INIPROD / (params.m1 * params.m2 * params.b)
    c10 = INIWAGE / (Btau0 * params.m1)
    p10 = (1 + params.mu1) * c10
    c20 = INIWAGE / INIPROD
    p20 = (1 + params.mu20) * c20
    trW = params.flagTax > 0 ? params.tr : 0.0
    
    # Full employment capital required per firm
    K0 = ceil(params.Ls0 * INIWAGE / p20 / params.F20 / params.m2) * params.m2
    
    # Substitution investment (real)
    SIr0 = params.F20 * K0 / params.m2 / params.eta
    
    # Initial R&D expense
    RD0 = params.nu * SIr0 * p10
    
    # Initial steady-state demand per firm (from full employment equilibrium)
    D20 = ((SIr0 * c10 + RD0) * (1 - params.phi - trW) + 
           params.Ls0 * INIWAGE * params.phi) / 
          (params.mu20 + params.phi + trW) * c20 / params.F20
    
    for i in 1:params.F20
        # Initial net worth with heterogeneity
        nw_factor = params.Phi1 + rand(Agents.abmrng(model)) * (params.Phi2 - params.Phi1)
        
        # Initial capital stock
        K = K0
        
        # Initial productivity (from first capital-good firm)
        A = INIPROD
        
        # Initial unit cost and price
        c2 = INIWAGE / A
        p2 = (1 + params.mu20) * c2
        
        # Initial free cash (to cover production for one period)
        NW2f = (1 + params.iota) * D20 * c2
        NW2f = max(NW2f, nw_factor * params.NW20)
        
        # Total initial net worth (capital + free cash)
        nw = p10 * K / params.m2 + NW2f
        
        # Initial debt
        deb = nw * params.Deb20ratio
        
        # Initial inventories
        N = params.iota * D20
        
        firm = Firm2(
            id = Agents.nextid(model),
            K = K,
            NW2 = nw,
            NW2_prev = nw,
            Deb2 = deb,
            mu2 = params.mu20,
            w2 = INIWAGE,
            c2 = c2,
            p2 = p2,
            p2_prev = p2,  # Initialize prev price to current
            N2 = N,
            N2_prev = N,  # Initialize prev inventory to current
            D2 = D20,
            D2e = D20,
            D2d = D20,
            D2_history = fill(D20, 4),  # Initialize history with steady-state demand
            f2 = 1.0 / params.F20,  # Fair initial market share
            competitiveness = 1.0,
            life2cycle = 1  # CRITICAL: Start as operating entrant (has capital)
        )
        
        # Initialize vintage with initial technology
        vintage_id = 1
        firm.vintages[vintage_id] = (
            t0 = 0,
            supplier_id = 0,
            A = A,
            sVp = 1.0,
            sVavg = 1.0,
            machines = round(Int, K / params.m2),
            price = p10
        )
        
        Agents.add_agent!(firm, model)
        push!(model.firm2_ids, firm.id)
    end
end

"""
    initialize_workers!(model)

Create initial worker population.
"""
function initialize_workers!(model)
    params = model.params
    
    for i in 1:params.Ls0
        worker = Worker(
            id = Agents.nextid(model),
            employed = 0,
            w = 1.0,
            wRes = 1.0,
            s = 1.0,
            sV = 1.0,
            sT = 1.0,
            age = rand(Agents.abmrng(model), 1:params.Tr),
            Tc = params.Tc,
            wage_memory = fill(1.0, params.Ts)
        )
        Agents.add_agent!(worker, model)
        push!(model.worker_ids, worker.id)
    end
    
    model.U = params.Ls0
    model.L = 0
end

"""
    establish_bank_firm_relationships!(model)

Randomly assign each firm to a bank.
"""
function establish_bank_firm_relationships!(model)
    bank_ids = model.bank_ids
    
    # Assign Firm1 to banks
    for fid in model.firm1_ids
        firm = model[fid]
        bank_id = rand(Agents.abmrng(model), bank_ids)
        firm.bank_id = bank_id
        bank = model[bank_id]
        push!(bank.client1_ids, fid)
    end
    
    # Assign Firm2 to banks
    for fid in model.firm2_ids
        firm = model[fid]
        bank_id = rand(Agents.abmrng(model), bank_ids)
        firm.bank_id = bank_id
        bank = model[bank_id]
        push!(bank.client2_ids, fid)
    end
end

"""
    establish_firm_customer_relationships!(model)

Each Firm2 randomly selects a Firm1 supplier.
Each Firm1 randomly selects initial customers.
"""
function establish_firm_customer_relationships!(model)
    params = model.params
    firm1_ids = model.firm1_ids
    
    # Each Firm2 chooses a supplier
    for fid in model.firm2_ids
        firm = model[fid]
        firm.supplier_id = rand(Agents.abmrng(model), firm1_ids)
    end
    
    # Each Firm1 builds initial customer list
    for fid in model.firm1_ids
        firm = model[fid]
        # Start with firms that chose this supplier
        customers = [f2id for f2id in model.firm2_ids if model[f2id].supplier_id == fid]
        # Add some random additional potential customers
        n_extra = Int(round(params.gamma * length(model.firm2_ids)))
        extras = StatsBase.sample(Agents.abmrng(model), model.firm2_ids, min(n_extra, length(model.firm2_ids)), replace=false)
        firm.client_ids = unique(vcat(customers, extras))
    end
end

"""
    initialize_market_shares!(model)

Set initial market shares to equal for all firms in each sector.
"""
function initialize_market_shares!(model)
    # Sector 1
    f1 = 1.0 / length(model.firm1_ids)
    for fid in model.firm1_ids
        model[fid].f1 = f1
    end
    
    # Sector 2
    f2 = 1.0 / length(model.firm2_ids)
    for fid in model.firm2_ids
        model[fid].f2 = f2
    end
end

"""
    initialize_history!(model)

Initialize historical data for moving averages and lagged variables.
"""
function initialize_history!(model)
    params = model.params
    
    # CRITICAL FIX: Calculate correct initial GDP from actual firm values
    # GDP = C + I + dNnom, where initially C ≈ steady-state consumption
    # and I ≈ steady-state investment
    
    # Calculate initial GDP from actual initialized values
    # C initial ≈ total worker wages at full employment
    initial_C = params.Ls0 * 1.0  # INIWAGE = 1.0
    
    # I initial ≈ replacement investment for all Firm2 capital
    total_K = sum(model[fid].K for fid in model.firm2_ids; init=0.0)
    initial_I = total_K / params.eta  # Steady-state replacement
    
    # Initial GDP (real)
    initial_gdp = initial_C + initial_I
    
    model.GDP_history = fill(initial_gdp, params.mPer)
    model.GDP = initial_gdp
    model.GDPnom = initial_gdp
    model.GDPreal = initial_gdp
    
    # Initialize CPI history
    model.CPI_history = fill(1.0, params.mPer)
    model.CPI = 1.0
    
    # Note: Firm histories are already initialized in initialize_firm2!
end

"""
    initialize_labor_demand!(model)

Initialize labor demand for all firms at t=0.
This ensures firms have proper L_d values before first hiring round.
Matches C model initial conditions.
"""
function initialize_labor_demand!(model)
    params = model.params
    
    # Sector 1: Initialize labor demand based on expected production
    for fid in model.firm1_ids
        firm = model[fid]
        
        # Initial production planning based on initial demand
        firm.Q1 = firm.D1 * (1 + params.iota)
        
        # R&D labor (already set in initialization)
        # Production labor
        if firm.B > 0 && params.m1 > 0
            L_prod = max(ceil(firm.Q1 / (params.m1 * firm.B)), 0.0)
        else
            L_prod = 1.0
        end
        
        # Total labor demand
        firm.L1d = max(firm.L1dRD + L_prod, 1.0)
    end
    
    # Sector 2: Initialize labor demand based on expected production
    for fid in model.firm2_ids
        firm = model[fid]
        
        # Plan initial production
        Q_desired = max((1 + params.iota) * firm.D2e - firm.N2, 0.0)
        A_avg = firm2_average_productivity(firm)
        Q_capacity = firm.K * params.u * A_avg
        firm.Q2 = min(Q_desired, Q_capacity)
        
        # Calculate labor demand
        if A_avg > 0 && firm.Q2 > 0
            L_needed = firm.Q2 / A_avg
            firm.L2d = max(ceil(L_needed), 1.0)
        else
            firm.L2d = 1.0
        end
    end
end

"""
    initialize_investment_demand!(model)

Initialize investment demand for Firm2 at t=0.
This ensures Firm1 receives initial orders in period 1.
"""
function initialize_investment_demand!(model)
    params = model.params
    
    # Sector 2: Initialize investment based on expected demand and capital
    for fid in model.firm2_ids
        firm = model[fid]
        
        # Calculate initial desired capital
        A_avg = firm2_average_productivity(firm)
        firm.Kd = max((1 + params.iota) * firm.D2e - firm.N2, 0.0) / params.u
        
        # Initial expansion investment (for new firms with initial capital)
        # Most firms will have K ≈ Kd initially, so minimal expansion
        # But ensure some baseline investment for steady state
        if firm.K < firm.Kd
            firm.EId = min(firm.Kd - firm.K, firm.K * 0.1)  # Max 10% expansion initially
        else
            firm.EId = 0.0
        end
        
        # Initial substitution investment (1/eta of capital stock for replacement)
        # This maintains steady-state replacement
        firm.SId = firm.K / params.eta
        
        # Total investment demand
        firm.Id = firm.EId + firm.SId
    end
end



