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
        size_factor = rand(abmrng(model), Pareto(params.alphaB))
        nw = bank_nw * size_factor / params.B
        
        bank = Bank(
            id = nextid(model),
            NWb = nw,
            r = params.rT,
            rDeb = params.rT + params.muDeb,
            rD = params.rT - params.muD
        )
        add_agent!(bank, model)
        push!(model.bank_ids, bank.id)
    end
end

"""
    initialize_firm1!(model)

Create initial capital-good firm population.
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
    
    for i in 1:params.F10
        # Initial technology
        A = INIPROD
        B = Btau0
        
        # Initial net worth with heterogeneity
        nw_factor = params.Phi3 + rand(abmrng(model)) * (params.Phi4 - params.Phi3)
        nw = params.NW10 * nw_factor
        
        # Initial debt
        deb = nw * params.Deb10ratio / (1 - params.Deb10ratio)
        
        firm = Firm1(
            id = nextid(model),
            A = A,
            B = B,
            Atau = A,
            Btau = B,
            NW1 = nw,
            Deb1 = deb,
            mu1 = params.mu1,
            w1 = INIWAGE,
            c1 = c10,
            p1 = p10
        )
        add_agent!(firm, model)
        push!(model.firm1_ids, firm.id)
    end
end

"""
    initialize_firm2!(model)

Create initial consumption-good firm population.
"""
function initialize_firm2!(model)
    params = model.params
    
    for i in 1:params.F20
        # Initial net worth with heterogeneity
        nw_factor = params.Phi1 + rand(abmrng(model)) * (params.Phi2 - params.Phi1)
        nw = params.NW20 * nw_factor
        
        # Initial debt
        deb = nw * params.Deb20ratio / (1 - params.Deb20ratio)
        
        # Initial capital stock (machines)
        k = nw / 10.0  # Simple initial capital
        
        firm = Firm2(
            id = nextid(model),
            K = k,
            NW2 = nw,
            Deb2 = deb,
            mu2 = params.mu20,
            w2 = 1.0,
            p2 = (1 + params.mu20) * 1.0,
            N2 = k * params.iota  # Initial inventories
        )
        
        # Initialize vintage with initial technology
        vintage_id = 1
        firm.vintages[vintage_id] = (
            t0 = 0,
            supplier_id = 0,
            A = 1.0,
            sVp = 1.0,
            sVavg = 1.0,
            machines = round(Int, k),
            price = model.p1avg
        )
        
        add_agent!(firm, model)
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
            id = nextid(model),
            employed = 0,
            w = 1.0,
            wRes = 1.0,
            s = 1.0,
            sV = 1.0,
            sT = 1.0,
            age = rand(abmrng(model), 1:params.Tr),
            Tc = params.Tc,
            wage_memory = fill(1.0, params.Ts)
        )
        add_agent!(worker, model)
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
        bank_id = rand(abmrng(model), bank_ids)
        firm.bank_id = bank_id
        bank = model[bank_id]
        push!(bank.client1_ids, fid)
    end
    
    # Assign Firm2 to banks
    for fid in model.firm2_ids
        firm = model[fid]
        bank_id = rand(abmrng(model), bank_ids)
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
        firm.supplier_id = rand(abmrng(model), firm1_ids)
    end
    
    # Each Firm1 builds initial customer list
    for fid in model.firm1_ids
        firm = model[fid]
        # Start with firms that chose this supplier
        customers = [f2id for f2id in model.firm2_ids if model[f2id].supplier_id == fid]
        # Add some random additional potential customers
        n_extra = Int(round(params.gamma * length(model.firm2_ids)))
        extras = sample(abmrng(model), model.firm2_ids, min(n_extra, length(model.firm2_ids)), replace=false)
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
    
    # Initialize GDP history for moving averages
    initial_gdp = params.NW10 * params.F10 + params.NW20 * params.F20
    model.GDP_history = fill(initial_gdp, params.mPer)
    model.GDP = initial_gdp
    model.GDPnom = initial_gdp
    model.GDPreal = initial_gdp
    
    # Initialize CPI history
    model.CPI_history = fill(1.0, params.mPer)
    model.CPI = 1.0
    
    # Initialize firm histories
    for fid in model.firm2_ids
        firm = model[fid]
        firm.D2_history = fill(0.0, 4)
    end
end
