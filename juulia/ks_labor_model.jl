#=
K+S Labor Market Model - Julia Implementation using Agents.jl v6.2
==================================================================

This is a replication of the K+S (Keynes+Schumpeter) labor market model
originally implemented in LSD (Laboratory for Simulation Development).

The model includes:
- Heterogeneous workers with skills and wage dynamics
- Capital-good firms (Sector 1) producing machines
- Consumption-good firms (Sector 2) producing consumer goods
- Banks providing credit
- Government with fiscal policy
- Central bank with monetary policy
- Decentralized labor market with search-and-match

Original model: Dosi et al. (2010-2020) series of papers
Original LSD code: Marcelo C. Pereira

References:
- Dosi et al. (2010). Schumpeter meeting Keynes. JEDC 34:1748-1767
- Dosi et al. (2017). When more flexibility yields more fragility. JEDC 81:162-186
=#

using Agents
using Random
using Statistics
using Distributions
using DataFrames

#=============================================================================
AGENT DEFINITIONS
=============================================================================#

# Worker agent type
@agent struct Worker(NoSpaceAgent)
    # Employment status (id is automatically provided by @agent)
    employed::Int  # 0=unemployed, 1=sector1, 2=sector2
    employer_id::Int  # ID of employing firm (0 if unemployed)
    
    # Worker characteristics
    age::Int  # Working age
    tenure::Int  # Time employed with current employer
    
    # Skills
    skill_vintage::Float64  # Learn-by-using vintage skills
    skill_tenure::Float64   # Learn-by-doing tenure skills
    skill_compound::Float64 # Combined skill level
    
    # Wages and income
    wage::Float64  # Current wage
    wage_reservation::Float64  # Minimum acceptable wage
    wage_history::Vector{Float64}  # Recent wage history
    
    # Job search
    applications::Int  # Number of job applications this period
    discouraged::Bool  # Search discouragement flag
    search_prob::Float64  # Probability of searching
    
    # Contract
    contract_term::Int  # Remaining contract periods
end

# Firm in capital-good sector (Sector 1)
@agent struct Firm1(NoSpaceAgent)
    # Identity
    sector::Int  # Always 1 for this type
    
    # Production
    production::Float64  # Actual production this period
    production_planned::Float64  # Planned production
    productivity::Float64  # Labor productivity
    
    # Technology
    tech_level::Float64  # Current technology generation
    rd_investment::Float64  # R&D investment
    
    # Workforce
    labor_demand::Float64  # Desired workers
    labor_actual::Float64  # Actual workers employed
    workers::Vector{Int}  # IDs of employed workers
    
    # Market
    orders::Float64  # Orders received
    sales::Float64  # Actual sales
    market_share::Float64  # Market share
    price::Float64  # Machine price
    
    # Finance
    net_worth::Float64  # Equity
    debt::Float64  # Outstanding debt
    liquidity::Float64  # Cash on hand
    profits::Float64  # Current profits
    
    # Banking
    bank_id::Int  # ID of bank relationship
    credit_limit::Float64  # Maximum credit available
end

# Firm in consumption-good sector (Sector 2)
@agent struct Firm2(NoSpaceAgent)
    # Identity
    sector::Int  # Always 2 for this type
    post_change::Bool  # Post-regime-change firm flag
    
    # Production
    production::Float64  # Actual production
    production_planned::Float64  # Planned production
    demand_expected::Float64  # Expected demand
    
    # Capital stock
    capital_stock::Float64  # Total capital
    capital_vintage::Dict{Int,Float64}  # Vintage composition
    productivity::Float64  # Average labor productivity
    
    # Workforce
    labor_demand::Float64  # Desired workers
    labor_actual::Float64  # Actual workers employed
    workers::Vector{Int}  # IDs of employed workers
    wage_offer::Float64  # Current wage offer
    
    # Market
    sales::Float64  # Actual sales
    market_share::Float64  # Market share
    price::Float64  # Product price
    markup::Float64  # Price markup
    competitiveness::Float64  # Market competitiveness
    inventories::Float64  # Unsold goods
    
    # Investment
    investment_desired::Float64  # Desired investment
    investment_actual::Float64  # Actual investment
    machine_orders::Dict{Int,Float64}  # Orders to Firm1 by ID
    
    # Finance
    net_worth::Float64  # Equity
    debt::Float64  # Outstanding debt
    liquidity::Float64  # Cash on hand
    profits::Float64  # Current profits
    
    # Banking
    bank_id::Int  # ID of bank relationship
    credit_limit::Float64  # Maximum credit available
end

# Bank agent
@agent struct Bank(NoSpaceAgent)
    # Assets
    loans::Float64  # Total loans outstanding
    reserves::Float64  # Reserves at central bank
    bonds::Float64  # Government bonds held
    
    # Liabilities
    deposits::Float64  # Total deposits
    equity::Float64  # Bank equity
    
    # Operations
    profits::Float64  # Current profits
    failed::Bool  # Bank failure flag
    
    # Client firms
    clients_sector1::Vector{Int}  # Firm1 client IDs
    clients_sector2::Vector{Int}  # Firm2 client IDs
    
    # Interest rates
    rate_loans::Float64  # Lending rate
    rate_deposits::Float64  # Deposit rate
end

#=============================================================================
MODEL PROPERTIES
=============================================================================#

# Model-level properties structure
mutable struct KSModelProperties
    # Time
    tick::Int  # Current time step
    
    # Macroeconomic variables
    gdp_real::Float64
    gdp_nominal::Float64
    unemployment_rate::Float64
    inflation::Float64
    
    # Sector aggregates
    total_employment::Float64
    total_wages::Float64
    wage_average::Float64
    
    sector1_production::Float64
    sector1_employment::Float64
    sector2_production::Float64
    sector2_employment::Float64
    
    # Government
    gov_expenditure::Float64
    tax_revenue::Float64
    public_debt::Float64
    deficit::Float64
    unemployment_benefit::Float64
    min_wage::Float64
    
    # Central bank
    interest_rate_prime::Float64
    interest_rate_policy::Float64
    inflation_target::Float64
    
    # Financial aggregates
    total_credit::Float64
    total_deposits::Float64
    
    # Labor market
    job_applications::Float64
    job_openings_sector1::Float64
    job_openings_sector2::Float64
    
    # Savings
    forced_savings::Float64
    accumulated_savings::Float64
    
    # Entry/Exit
    firm1_entries::Int
    firm1_exits::Int
    firm2_entries::Int
    firm2_exits::Int
    
    # Store parameters as a dict
    parameters::Dict{Symbol, Any}
end

#=============================================================================
MODEL PARAMETERS
=============================================================================#

# Default parameters based on LSD model configurations
function get_default_parameters()
    Dict(
        # Simulation
        :seed => 1234,
        :max_steps => 500,
        
        # Initial population sizes
        :n_workers => 1000,
        :n_firms1 => 50,  # Capital-good firms
        :n_firms2 => 200,  # Consumption-good firms
        :n_banks => 10,
        
        # Labor scaling
        :labor_scale => 1,  # Each Worker object represents this many workers
        
        # Labor market parameters
        :population_growth => 0.01,  # delta: labor force growth rate
        :retirement_age => 40,  # Tr: periods before retirement (0=no retirement)
        :contract_term => 12,  # Tc: work contract duration
        :training_cost => 0.1,  # GammaCost: training cost as fraction of wage
        :training_coverage => 0.5,  # Gamma: share of unemployed trained
        
        # Job search
        :applications_employed => 2,  # omega: applications when employed
        :applications_unemployed => 4,  # omegaU: applications when unemployed
        :search_mode => 1,  # 0=always, 1=unemployed only, 2=below avg wage
        :search_discouragement_kappa => 2.0,  # kappa: search intensity
        :search_discouragement_lambda => 1.0,  # lambda: individual intensity
        :job_change_threshold => 0.05,  # epsilon: min wage gain to switch
        
        # Wage parameters
        :initial_wage => 1.0,  # INIWAGE: initial notional wage
        :min_wage_floor => 0.8,  # w0min: absolute minimum wage
        :unemployment_benefit_ratio => 0.6,  # phi: benefit as fraction of avg wage
        :wage_inflation_pass => 0.5,  # psi1: inflation adjustment
        :wage_productivity_general => 0.5,  # psi2: general productivity adjustment
        :wage_productivity_firm => 0.5,  # psi4: firm productivity adjustment
        :wage_unemployment => -0.5,  # psi3: unemployment adjustment
        :wage_memory_periods => 4,  # Ts: periods for wage memory
        :wage_cap => 2.0,  # wCap: max wage change multiplier
        
        # Skills and learning
        :initial_skill => 1.0,  # INISKILL: initial skill level
        :public_skill_vintage => 0.5,  # sigma: public vintage skills
        :learning_tenure => 0.05,  # tauT: tenure learning factor
        :learning_training => 0.1,  # tauG: training learning factor
        :skill_deterioration_unemployed => 0.02,  # tauU: unemployed skill loss
        :worker_learning_mode => 3,  # 0=none, 1=vintage, 2=tenure, 3=both
        :worker_skill_effect => 3,  # Effect on productivity: 0=none, 1=vintage, 2=tenure, 3=both
        
        # Firm parameters - Sector 1
        :sector1_markup => 0.2,  # mu1: markup rate
        :sector1_labor_productivity => 1.0,  # m1: output per worker
        :sector1_rd_share => 0.04,  # nu: R&D as fraction of sales
        :sector1_innovation_share => 0.5,  # xi: share of R&D in innovation
        :sector1_customer_share => 0.3,  # gamma: share of new customers
        :sector1_dividend_rate => 0.5,  # d1: dividend payout rate
        
        # Firm parameters - Sector 2
        :sector2_markup_initial => 0.3,  # mu20: initial markup
        :sector2_labor_per_machine => 1.0,  # m2: labor units per machine
        :sector2_utilization => 0.75,  # u: planned capacity utilization
        :sector2_inventories_share => 0.1,  # iota: inventories as fraction of output
        :sector2_dividend_rate => 0.5,  # d2: dividend payout rate
        :sector2_payback_periods => 3,  # b: machine payback period
        :sector2_lifetime => 20,  # eta: machine lifetime
        
        # Market dynamics
        :replicator_selectivity => 1.0,  # chi: replicator dynamics parameter
        :competitiveness_price => 1.0,  # omega1: weight of price
        :competitiveness_unfilled => 1.0,  # omega2: weight of unfilled demand
        :competitiveness_quality => 0.0,  # omega3: weight of quality
        :markup_adjustment_speed => 0.02,  # upsilon: markup adjustment sensitivity
        
        # Expectations
        :expectation_mode => 1,  # 0=myopic, 1=adaptive, etc.
        :animal_spirits => 0.5,  # e0: weight of potential demand
        :expectation_weight1 => 0.4,  # e1: weight t-1
        :expectation_weight2 => 0.3,  # e2: weight t-2
        :expectation_weight3 => 0.2,  # e3: weight t-3
        :expectation_weight4 => 0.1,  # e4: weight t-4
        
        # Finance
        :n_banks => 10,  # B: number of banks
        :credit_multiplier => 3.0,  # Lambda: max credit as multiple of net worth
        :initial_debt_ratio_sector1 => 0.2,  # Deb10ratio: initial debt/equity
        :initial_debt_ratio_sector2 => 0.3,  # Deb20ratio: initial debt/equity
        :bank_capital_adequacy => 0.08,  # tauB: Basel-like CAR
        :bank_markup_loans => 0.03,  # muDeb: spread on loans
        :bank_markdown_deposits => 0.01,  # muD: markdown on deposits
        :interest_rate_target => 0.04,  # rT: target prime rate
        
        # Government
        :tax_rate => 0.2,  # tr: tax on profits
        :fiscal_rule => 2,  # 0=none, 1=balanced, 2=soft balanced, etc.
        :debt_gdp_limit => 0.6,  # DebRule: max debt/GDP
        :deficit_gdp_limit => 0.03,  # DefPrule: max deficit/GDP
        
        # Entry/Exit
        :sector1_min_firms => 30,  # F1min
        :sector1_max_firms => 100,  # F1max
        :sector2_min_firms => 100,  # F2min
        :sector2_max_firms => 500,  # F2max
        :min_market_share_exit => 0.001,  # f2min: exit if below this
        :entry_sensitivity => 0.3,  # omicron: entry sensitivity to conditions
        
        # Regime change
        :regime_change_time => 0,  # TregChg: 0=no change
        
        # Control flags
        :flag_heterogeneous_wage => 2,  # 0=central, 1=firm, 2=worker
        :flag_hire_order_sector1 => 0,  # Hiring priority
        :flag_hire_order_sector2 => 0,
        :flag_fire_order_sector1 => 0,  # Firing priority
        :flag_fire_order_sector2 => 0,
        :flag_fire_rule => 2,  # Firing rule: 2=only if downsizing
        :flag_wage_offer => 1,  # 0=premium, 1=based on requests
        :flag_hire_sequence => 0,  # Hiring sequence: 0=random
        :flag_add_workers => 1,  # Add workers on full employment
    )
end

#=============================================================================
STEPPING FUNCTIONS (Defined before initialization for forward reference)
=============================================================================#

"""
Main model stepping function - orchestrates all phases of one time step
This implements the timeStep equation from the LSD model
"""
function model_step!(model)
    abmproperties(model).tick += 1
    t = abmproperties(model).tick
    
    # Phase 1: Central bank sets interest rates
    update_interest_rates!(model)
    
    # Phase 2: Firms plan production and labor demand
    # Sector 2 firms form expectations and plan production
    for firm in allagents(model)
        if firm isa Firm2
            plan_production_sector2!(firm, model)
        end
    end
    
    # Sector 1 firms receive orders and plan production
    for firm in allagents(model)
        if firm isa Firm1
            plan_production_sector1!(firm, model)
        end
    end
    
    # Phase 3: Labor market - job search and matching
    # Workers apply for jobs
    for worker in allagents(model)
        if worker isa Worker
            worker_job_search!(worker, model)
        end
    end
    
    # Firms post openings and hire
    firm_hiring!(model)
    
    # Phase 4: Production
    for firm in allagents(model)
        if firm isa Firm1
            produce_sector1!(firm, model)
        elseif firm isa Firm2
            produce_sector2!(firm, model)
        end
    end
    
    # Phase 5: Firms set prices
    for firm in allagents(model)
        if firm isa Firm1
            set_price_sector1!(firm, model)
        elseif firm isa Firm2
            set_price_sector2!(firm, model)
        end
    end
    
    # Phase 6: Consumption and goods market
    consumption_market!(model)
    
    # Phase 7: Finance and profits
    compute_profits!(model)
    
    # Phase 8: Government and taxes
    government_operations!(model)
    
    # Phase 9: Entry and exit
    entry_exit!(model)
    
    # Phase 10: Update aggregates
    update_aggregates!(model)
end

#=============================================================================
INITIALIZATION FUNCTIONS
=============================================================================#

"""
Initialize the K+S labor market model
"""
function initialize_ks_model(; parameters=get_default_parameters())
    # Extract key parameters
    n_workers = parameters[:n_workers]
    n_firms1 = parameters[:n_firms1]
    n_firms2 = parameters[:n_firms2]
    n_banks = parameters[:n_banks]
    seed = parameters[:seed]
    
    # Set random seed
    rng = Random.MersenneTwister(seed)
    
    # Create model properties
    properties = KSModelProperties(
        0,  # tick
        0.0, 0.0, 0.0, 0.0,  # GDP, unemployment, inflation
        0.0, 0.0, 0.0,  # employment, wages
        0.0, 0.0, 0.0, 0.0,  # sector production/employment
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,  # government
        0.04, 0.04, 0.02,  # central bank
        0.0, 0.0,  # financial
        0.0, 0.0, 0.0,  # labor market
        0.0, 0.0,  # savings
        0, 0, 0, 0,  # entry/exit
        parameters  # Store parameters in properties
    )
    
    # Create the model with NoSpaceAgent (abstract labor market)
    # In Agents.jl v6.2, model_step! must be provided as keyword argument
    model = StandardABM(
        Union{Worker, Firm1, Firm2, Bank}, nothing;  # Agent type and space
        properties=properties,
        rng=rng,
        scheduler=Schedulers.Randomly(),
        model_step! = model_step!,  # Required in Agents.jl v6.2
        warn = false  # Suppress union type warning for mixed agents
    )
    
    # Initialize banks first
    initialize_banks!(model, n_banks, parameters)
    
    # Initialize firms
    initialize_firms1!(model, n_firms1, parameters)
    initialize_firms2!(model, n_firms2, parameters)
    
    # Initialize workers
    initialize_workers!(model, n_workers, parameters)
    
    # Set initial government values
    abmproperties(model).min_wage = parameters[:min_wage_floor]
    abmproperties(model).interest_rate_prime = parameters[:interest_rate_target]
    
    return model
end

# Helper function to access parameters from model
@inline getparam(model, key) = abmproperties(model).parameters[key]

"""
Initialize banks in the model
"""
function initialize_banks!(model, n_banks, params)
    for i in 1:n_banks
        bank = Bank(
            Agents.nextid(model),
            0.0,  # loans
            0.0,  # reserves
            0.0,  # bonds
            0.0,  # deposits
            1000.0,  # initial equity
            0.0,  # profits
            false,  # not failed
            Int[],  # clients_sector1
            Int[],  # clients_sector2
            params[:interest_rate_target] + params[:bank_markup_loans],
            params[:interest_rate_target] - params[:bank_markdown_deposits]
        )
        add_agent!(bank, model)
    end
end

"""
Initialize capital-good firms (Sector 1)
"""
function initialize_firms1!(model, n_firms, params)
    banks = [a for a in allagents(model) if a isa Bank]
    
    if isempty(banks)
        @warn "No banks available for Firm1 initialization"
        return
    end
    
    # Calculate initial equilibrium (from C code logic)
    Ls0 = params[:n_workers] * params[:labor_scale]
    initial_wage = params[:initial_wage]
    initial_prod = params[:sector1_labor_productivity]
    
    # Initial demand for machines (simplified)
    initial_demand_per_firm = Ls0 * initial_wage * 0.1 / n_firms
    initial_production = initial_demand_per_firm
    initial_labor = initial_production / initial_prod
    
    for i in 1:n_firms
        # Assign to random bank
        bank_id = rand(abmrng(model), banks).id
        
        # Initial values
        initial_nw = 100.0
        initial_debt = initial_nw * params[:initial_debt_ratio_sector1]
        
        firm = Firm1(
            Agents.nextid(model),
            1,  # sector
            initial_production,  # production
            initial_production,  # production_planned
            initial_prod,  # productivity
            1.0,  # tech_level
            initial_production * initial_wage / initial_prod * params[:sector1_rd_share],  # rd_investment
            initial_labor,  # labor_demand
            0.0,  # labor_actual (will be filled by hiring)
            Int[],  # workers
            initial_demand_per_firm,  # orders
            initial_production * 0.9,  # sales
            1.0 / n_firms,  # market_share
            initial_wage / initial_prod * (1 + params[:sector1_markup]),  # price
            initial_nw,  # net_worth
            initial_debt,  # debt
            initial_nw,  # liquidity
            0.0,  # profits
            bank_id,
            initial_nw * params[:credit_multiplier]  # credit_limit
        )
        add_agent!(firm, model)
        
        # Register with bank
        bank = model[bank_id]
        push!(bank.clients_sector1, firm.id)
    end
end

"""
Initialize consumption-good firms (Sector 2)
"""
function initialize_firms2!(model, n_firms, params)
    banks = [a for a in allagents(model) if a isa Bank]
    
    if isempty(banks)
        @warn "No banks available for Firm2 initialization"
        return
    end
    
    # Calculate initial equilibrium values (from C code)
    # This sets up a coherent initial state with production and employment
    Ls0 = params[:n_workers] * params[:labor_scale]
    phi = params[:unemployment_benefit_ratio]
    trW = params[:tax_rate]
    mu20 = params[:sector2_markup_initial]
    
    # Initial aggregate values  
    initial_wage = params[:initial_wage]
    initial_prod = params[:sector1_labor_productivity]  # INIPROD
    
    # Firm-level initial values (simplified)
    initial_nw = 200.0
    initial_debt = initial_nw * params[:initial_debt_ratio_sector2]
    initial_capital = 50.0 * n_firms  # Total capital to support economy
    initial_demand = Ls0 * initial_wage * 0.8 / n_firms  # Initial demand per firm
    initial_production = initial_demand / (1 + params[:sector2_markup_initial])
    initial_labor = initial_production / initial_prod
    
    for i in 1:n_firms
        # Assign to random bank
        bank_id = rand(abmrng(model), banks).id
        
        firm = Firm2(
            Agents.nextid(model),
            2,  # sector
            false,  # post_change
            initial_production,  # production
            initial_production,  # production_planned
            initial_demand,  # demand_expected
            initial_capital / n_firms,  # capital_stock
            Dict(1 => initial_capital / n_firms),  # capital_vintage (vintage 1)
            initial_prod,  # productivity
            initial_labor,  # labor_demand
            0.0,  # labor_actual (will be filled by hiring)
            Int[],  # workers
            initial_wage,  # wage_offer
            initial_production * 0.9,  # sales (slightly less than production)
            1.0 / n_firms,  # market_share
            initial_wage / initial_prod * (1 + params[:sector2_markup_initial]),  # price
            params[:sector2_markup_initial],  # markup
            0.5,  # competitiveness
            initial_production * 0.1,  # inventories
            0.0,  # investment_desired
            0.0,  # investment_actual
            Dict{Int,Float64}(),  # machine_orders
            initial_nw,  # net_worth
            initial_debt,  # debt
            initial_nw,  # liquidity
            0.0,  # profits
            bank_id,
            initial_nw * params[:credit_multiplier]  # credit_limit
        )
        add_agent!(firm, model)
        
        # Register with bank
        bank = model[bank_id]
        push!(bank.clients_sector2, firm.id)
    end
end

"""
Initialize workers in the model
"""
function initialize_workers!(model, n_workers, params)
    for i in 1:n_workers
        # Random initial age
        initial_age = params[:retirement_age] > 0 ? rand(abmrng(model), 1:params[:retirement_age]) : rand(abmrng(model), 1:30)
        
        worker = Worker(
            Agents.nextid(model),
            0,  # unemployed initially
            0,  # no employer
            initial_age,
            0,  # tenure
            params[:initial_skill],  # skill_vintage
            params[:initial_skill],  # skill_tenure
            params[:initial_skill],  # skill_compound
            params[:initial_wage],  # wage
            params[:min_wage_floor],  # wage_reservation
            fill(params[:initial_wage], 8),  # wage_history
            0,  # applications
            false,  # not discouraged
            1.0,  # search_prob
            params[:contract_term]  # contract_term
        )
        add_agent!(worker, model)
    end
end


#=============================================================================
PHASE 1: INTEREST RATES
=============================================================================#

"""
Central bank sets prime rate using Taylor rule
"""
function update_interest_rates!(model)
    # Simple Taylor rule: r = r* + γ_π(π - π*) + γ_u(u - u*)
    # For simplicity, use target rate for now
    abmproperties(model).interest_rate_prime = getparam(model, :interest_rate_target)
    
    # Update bank rates
    for bank in allagents(model)
        if bank isa Bank
            bank.rate_loans = abmproperties(model).interest_rate_prime + getparam(model, :bank_markup_loans)
            bank.rate_deposits = abmproperties(model).interest_rate_prime - getparam(model, :bank_markdown_deposits)
        end
    end
end

#=============================================================================
PHASE 2: PRODUCTION PLANNING
=============================================================================#

"""
Sector 2 firms form demand expectations and plan production
"""
function plan_production_sector2!(firm::Firm2, model)
    # Simple adaptive expectations
    past_sales = firm.sales
    if past_sales == 0.0
        past_sales = firm.production
    end
    
    # Expected demand with animal spirits
    e0 = getparam(model, :animal_spirits)
    e1 = getparam(model, :expectation_weight1)
    firm.demand_expected = e0 * past_sales * (1 + getparam(model, :population_growth)) + 
                          (1 - e0) * past_sales
    
    # Planned production includes expected demand plus inventory target
    target_inventories = firm.demand_expected * getparam(model, :sector2_inventories_share)
    firm.production_planned = firm.demand_expected + target_inventories - firm.inventories
    firm.production_planned = max(0.0, firm.production_planned)
    
    # Labor demand based on productivity
    if firm.productivity > 0
        firm.labor_demand = firm.production_planned / firm.productivity
    else
        firm.labor_demand = 0.0
    end
    
    # Desired investment for capacity expansion
    desired_capacity = firm.demand_expected / getparam(model, :sector2_utilization)
    capacity_gap = desired_capacity - firm.capital_stock
    
    if capacity_gap > 0
        firm.investment_desired = capacity_gap
    else
        firm.investment_desired = 0.0
    end
end

"""
Sector 1 firms receive orders and plan machine production
"""
function plan_production_sector1!(firm::Firm1, model)
    # Aggregate orders from Sector 2
    firm.orders = 0.0
    for firm2 in allagents(model)
        if firm2 isa Firm2 && haskey(firm2.machine_orders, firm.id)
            firm.orders += firm2.machine_orders[firm.id]
        end
    end
    
    # Planned production equals orders
    firm.production_planned = firm.orders
    
    # Labor demand
    if firm.productivity > 0
        firm.labor_demand = firm.production_planned / firm.productivity
    else
        firm.labor_demand = 0.0
    end
end

#=============================================================================
PHASE 3: LABOR MARKET
=============================================================================#

"""
Worker searches for jobs and submits applications
"""
function worker_job_search!(worker::Worker, model)
    worker.applications = 0
    
    # Determine if worker searches
    search = should_search(worker, model)
    if !search
        worker.discouraged = true
        return
    end
    worker.discouraged = false
    
    # Number of applications
    n_apps = worker.employed > 0 ? 
             getparam(model, :applications_employed) : 
             getparam(model, :applications_unemployed)
    
    # Apply search probability
    search_prob = compute_search_probability(worker, model)
    if rand(abmrng(model)) > search_prob
        return
    end
    
    n_apps = round(Int, n_apps * search_prob)
    n_apps = max(1, n_apps)
    
    worker.applications = n_apps
    
    # Update wage request
    worker.wage_reservation = compute_wage_request(worker, model)
end

"""
Determine if worker should search based on search mode
"""
function should_search(worker::Worker, model)
    mode = getparam(model, :flag_heterogeneous_wage) == 0 ? 0 : getparam(model, :search_mode)
    
    if mode == 0  # Always search
        return true
    elseif mode == 1  # Search only if unemployed
        return worker.employed == 0
    elseif mode == 2  # Search if unemployed or below average wage
        if worker.employed == 0
            return true
        end
        # Only check avg wage if we have meaningful data
        avg_wage = abmproperties(model).wage_average
        if avg_wage > 0 && worker.wage > 0
            return worker.wage < avg_wage
        end
        return worker.employed == 0  # Default to unemployed search if no wage data
    end
    
    return true
end

"""
Compute global or individual search probability
"""
function compute_search_probability(worker::Worker, model)
    # Global discouragement based on unemployment
    kappa = getparam(model, :search_discouragement_kappa)
    u_rate = abmproperties(model).unemployment_rate
    
    prob = kappa * exp(-kappa * u_rate)
    return min(1.0, max(0.0, prob))
end

"""
Compute worker's wage request/reservation wage
"""
function compute_wage_request(worker::Worker, model)
    if getparam(model, :flag_heterogeneous_wage) == 0
        # Centralized wage
        return compute_centralized_wage(model)
    end
    
    if worker.employed == 0
        # Unemployed: use reservation wage with adjustment
        return max(abmproperties(model).min_wage, worker.wage_reservation)
    end
    
    # Employed: adjust based on inflation, productivity, unemployment
    current_wage = worker.wage
    
    # Wage indexation
    psi1 = getparam(model, :wage_inflation_pass)
    psi2 = getparam(model, :wage_productivity_general)
    psi3 = getparam(model, :wage_unemployment)
    
    # Simplified adjustment
    inflation = abmproperties(model).inflation
    productivity_growth = 0.01  # Simplified
    unemployment_change = 0.0  # Simplified
    
    adjustment = 1.0 + (psi1 * inflation + psi2 * productivity_growth + 
                       psi3 * unemployment_change)
    
    new_wage = current_wage * adjustment
    
    # Apply wage cap
    wage_cap = getparam(model, :wage_cap)
    if wage_cap > 0
        max_change = current_wage * wage_cap
        min_change = current_wage / wage_cap
        new_wage = clamp(new_wage, min_change, max_change)
    end
    
    # Minimum wage floor
    new_wage = max(new_wage, abmproperties(model).min_wage)
    
    return new_wage
end

"""
Compute centralized wage for all workers
"""
function compute_centralized_wage(model)
    # Based on average productivity and inflation
    base_wage = getparam(model, :initial_wage)
    
    # Simple adjustment
    inflation = abmproperties(model).inflation
    psi1 = getparam(model, :wage_inflation_pass)
    
    wage = base_wage * (1 + psi1 * inflation)
    wage = max(wage, abmproperties(model).min_wage)
    
    return wage
end

"""
Firms hire workers through decentralized matching
"""
function firm_hiring!(model)
    # Collect all workers searching for jobs
    searching_workers = [w for w in allagents(model) if w isa Worker && w.applications > 0]
    
    if isempty(searching_workers)
        return
    end
    
    # Collect firms with openings
    hiring_firms = []
    for firm in allagents(model)
        if firm isa Firm1 || firm isa Firm2
            openings = firm.labor_demand - firm.labor_actual
            if openings > 0.5  # At least half a worker needed
                push!(hiring_firms, firm)
            end
        end
    end
    
    if isempty(hiring_firms)
        return
    end
    
    # Build application lists for each firm
    firm_applications = Dict{Int, Vector{Int}}()
    for firm in hiring_firms
        firm_applications[firm.id] = Int[]
    end
    
    # Workers apply to random subset of firms
    for worker in searching_workers
        # Select random firms to apply to
        n_apps = min(worker.applications, length(hiring_firms))
        target_firms = rand(abmrng(model), hiring_firms, n_apps)
        
        for firm in target_firms
            push!(firm_applications[firm.id], worker.id)
        end
    end
    
    # Firms hire from their applicant pool
    for firm in hiring_firms
        applicants = firm_applications[firm.id]
        if isempty(applicants)
            continue
        end
        
        # Determine how many to hire
        openings = ceil(Int, firm.labor_demand - firm.labor_actual)
        
        # Compute wage offer
        wage_offer = compute_firm_wage_offer(firm, applicants, model)
        
        # Store wage offer for Firm2
        if firm isa Firm2
            firm.wage_offer = wage_offer
        end
        
        # Match workers to firm
        hired = 0
        for worker_id in shuffle(abmrng(model), applicants)
            if hired >= openings
                break
            end
            
            worker = model[worker_id]
            
            # Check if worker accepts
            if wage_offer >= worker.wage_reservation
                # Accept job
                hire_worker!(firm, worker, wage_offer, model)
                hired += 1
            end
        end
    end
end

"""
Compute firm's wage offer to applicants
"""
function compute_firm_wage_offer(firm::Union{Firm1, Firm2}, applicants::Vector{Int}, model)
    if getparam(model, :flag_wage_offer) == 0
        # Wage premium: offer current average plus premium
        if firm isa Firm2
            return firm.wage_offer * 1.05
        else
            return abmproperties(model).wage_average * 1.05
        end
    end
    
    # Based on worker requests
    if isempty(applicants)
        return abmproperties(model).wage_average
    end
    
    # Get minimum requested wage from applicants
    min_request = Inf
    for worker_id in applicants
        worker = model[worker_id]
        min_request = min(min_request, worker.wage_reservation)
    end
    
    # Offer slightly above minimum request
    wage_offer = min_request * 1.02
    wage_offer = max(wage_offer, abmproperties(model).min_wage)
    
    return wage_offer
end

"""
Hire a worker to a firm
"""
function hire_worker!(firm::Union{Firm1, Firm2}, worker::Worker, wage::Float64, model)
    # Fire worker from previous employer if any
    if worker.employed > 0
        fire_worker!(worker, model)
    end
    
    # Hire worker
    worker.employed = firm.sector
    worker.employer_id = firm.id
    worker.wage = wage
    worker.tenure = 0
    worker.contract_term = getparam(model, :contract_term)
    
    # Add to firm's workforce
    push!(firm.workers, worker.id)
    firm.labor_actual += getparam(model, :labor_scale)
    
    # Update worker wage history
    push!(worker.wage_history, wage)
    if length(worker.wage_history) > 8
        popfirst!(worker.wage_history)
    end
end

"""
Fire a worker from their current employer
"""
function fire_worker!(worker::Worker, model)
    if worker.employed == 0
        return
    end
    
    # Find employer
    employer = model[worker.employer_id]
    
    # Remove from firm
    filter!(id -> id != worker.id, employer.workers)
    employer.labor_actual -= getparam(model, :labor_scale)
    
    # Update worker status
    worker.employed = 0
    worker.employer_id = 0
    worker.tenure = 0
end

#=============================================================================
PHASE 4: PRODUCTION
=============================================================================#

"""
Sector 1 produces machines
"""
function produce_sector1!(firm::Firm1, model)
    # Actual production limited by labor
    max_production = firm.labor_actual * firm.productivity
    firm.production = min(firm.production_planned, max_production)
    
    # Sales equal production (made to order)
    firm.sales = firm.production
end

"""
Sector 2 produces consumption goods
"""
function produce_sector2!(firm::Firm2, model)
    # Actual production limited by labor and capital
    labor_capacity = firm.labor_actual * firm.productivity
    capital_capacity = firm.capital_stock * getparam(model, :sector2_utilization)
    
    max_production = min(labor_capacity, capital_capacity)
    firm.production = min(firm.production_planned, max_production)
end

#=============================================================================
PHASE 5: PRICING
=============================================================================#

"""
Set prices for capital goods
"""
function set_price_sector1!(firm::Firm1, model)
    # Cost-plus pricing
    if firm.productivity > 0
        unit_cost = abmproperties(model).wage_average / firm.productivity
        firm.price = unit_cost * (1.0 + getparam(model, :sector1_markup))
    end
end

"""
Set prices for consumption goods
"""
function set_price_sector2!(firm::Firm2, model)
    # Variable markup based on competitiveness
    if firm.productivity > 0
        unit_cost = abmproperties(model).wage_average / firm.productivity
        
        # Adjust markup based on market share dynamics
        if firm.market_share > 1.0 / length([a for a in allagents(model) if a isa Firm2])
            firm.markup = min(firm.markup * 1.01, 0.5)
        else
            firm.markup = max(firm.markup * 0.99, 0.05)
        end
        
        firm.price = unit_cost * (1.0 + firm.markup)
    end
end

#=============================================================================
PHASE 6: CONSUMPTION MARKET
=============================================================================#

"""
Consumption market clearing
"""
function consumption_market!(model)
    # Total desired consumption (wages + benefits)
    total_wages = sum(w.wage for w in allagents(model) if w isa Worker && w.employed > 0; init=0.0)
    unemployed = sum(1 for w in allagents(model) if w isa Worker && w.employed == 0; init=0)
    unemployment_benefits = unemployed * abmproperties(model).unemployment_benefit
    
    desired_consumption = (total_wages + unemployment_benefits) * getparam(model, :labor_scale)
    
    # Total supply
    total_supply = sum(f.production + f.inventories for f in allagents(model) if f isa Firm2; init=0.0)
    
    # Allocate demand to firms based on competitiveness
    firms2 = [f for f in allagents(model) if f isa Firm2]
    
    if isempty(firms2) || total_supply <= 0
        return
    end
    
    # Compute competitiveness
    for firm in firms2
        omega1 = getparam(model, :competitiveness_price)
        omega2 = getparam(model, :competitiveness_unfilled)
        
        # Price competitiveness (lower is better)
        avg_price = mean(f.price for f in firms2)
        price_comp = avg_price > 0 ? avg_price / firm.price : 1.0
        
        # Unfilled demand competitiveness (lower unfilled is better)
        unfilled_comp = 1.0  # Simplified
        
        firm.competitiveness = omega1 * price_comp + omega2 * unfilled_comp
    end
    
    # Normalize competitiveness to market shares using replicator dynamics
    total_comp = sum(f.competitiveness for f in firms2; init=0.0)
    if total_comp > 0
        for firm in firms2
            firm.market_share = firm.competitiveness / total_comp
        end
    end
    
    # Allocate demand
    for firm in firms2
        firm_demand = desired_consumption * firm.market_share
        available = firm.production + firm.inventories
        
        firm.sales = min(firm_demand, available)
        firm.inventories = max(0.0, available - firm.sales)
    end
    
    # Calculate forced savings if supply insufficient
    total_sales = sum(f.sales for f in firms2; init=0.0)
    abmproperties(model).forced_savings = max(0.0, desired_consumption - total_sales)
end

#=============================================================================
PHASE 7: PROFITS
=============================================================================#

"""
Compute profits for all firms
"""
function compute_profits!(model)
    # Sector 1 firms
    for firm in allagents(model)
        if firm isa Firm1
            revenue = firm.sales * firm.price
            wage_bill = sum(model[wid].wage for wid in firm.workers; init=0.0) * getparam(model, :labor_scale)
            interest = firm.debt * abmproperties(model).interest_rate_prime
            
            firm.profits = revenue - wage_bill - interest - firm.rd_investment
            firm.liquidity += firm.profits
            
        elseif firm isa Firm2
            revenue = firm.sales * firm.price
            wage_bill = sum(model[wid].wage for wid in firm.workers; init=0.0) * getparam(model, :labor_scale)
            interest = firm.debt * abmproperties(model).interest_rate_prime
            
            firm.profits = revenue - wage_bill - interest
            firm.liquidity += firm.profits
        end
    end
end

#=============================================================================
PHASE 8: GOVERNMENT
=============================================================================#

"""
Government operations: spending, taxes, debt
"""
function government_operations!(model)
    # Count unemployed
    unemployed = sum(1 for w in allagents(model) if w isa Worker && w.employed == 0; init=0.0)
    
    # Unemployment benefits
    abmproperties(model).unemployment_benefit = getparam(model, :unemployment_benefit_ratio) * 
                                           abmproperties(model).wage_average
    
    gov_expenditure = unemployed * abmproperties(model).unemployment_benefit * getparam(model, :labor_scale)
    
    # Collect taxes on profits
    tax_revenue = 0.0
    for firm in allagents(model)
        if (firm isa Firm1 || firm isa Firm2) && firm.profits > 0
            tax = firm.profits * getparam(model, :tax_rate)
            tax_revenue += tax
            firm.liquidity -= tax
        end
    end
    
    abmproperties(model).gov_expenditure = gov_expenditure
    abmproperties(model).tax_revenue = tax_revenue
    abmproperties(model).deficit = gov_expenditure - tax_revenue
    abmproperties(model).public_debt += abmproperties(model).deficit
end

#=============================================================================
PHASE 9: ENTRY AND EXIT
=============================================================================#

"""
Handle firm entry and exit
"""
function entry_exit!(model)
    abmproperties(model).firm1_exits = 0
    abmproperties(model).firm2_exits = 0
    abmproperties(model).firm1_entries = 0
    abmproperties(model).firm2_entries = 0
    
    # Exit firms with negative net worth or low market share
    for firm in collect(allagents(model))
        if firm isa Firm1
            if firm.net_worth < 0 || firm.market_share < getparam(model, :min_market_share_exit)
                # Fire all workers
                for wid in copy(firm.workers)
                    fire_worker!(model[wid], model)
                end
                remove_agent!(firm, model)
                abmproperties(model).firm1_exits += 1
            end
        elseif firm isa Firm2
            if firm.net_worth < 0 || firm.market_share < getparam(model, :min_market_share_exit)
                # Fire all workers
                for wid in copy(firm.workers)
                    fire_worker!(model[wid], model)
                end
                remove_agent!(firm, model)
                abmproperties(model).firm2_exits += 1
            end
        end
    end
    
    # Entry: simplified rule based on sector size
    n_firms1 = length([a for a in allagents(model) if a isa Firm1])
    n_firms2 = length([a for a in allagents(model) if a isa Firm2])
    
    # Sector 1 entry
    if n_firms1 < getparam(model, :sector1_max_firms)
        if rand(abmrng(model)) < 0.02  # 2% entry probability
            initialize_firms1!(model, 1, abmproperties(model).parameters)
            abmproperties(model).firm1_entries += 1
        end
    end
    
    # Sector 2 entry
    if n_firms2 < getparam(model, :sector2_max_firms)
        if rand(abmrng(model)) < 0.02
            initialize_firms2!(model, 1, abmproperties(model).parameters)
            abmproperties(model).firm2_entries += 1
        end
    end
end

#=============================================================================
PHASE 10: AGGREGATES
=============================================================================#

"""
Update aggregate statistics
"""
function update_aggregates!(model)
    # Employment
    workers = [w for w in allagents(model) if w isa Worker]
    employed = [w for w in workers if w.employed > 0]
    
    abmproperties(model).total_employment = length(employed) * getparam(model, :labor_scale)
    total_labor_force = length(workers) * getparam(model, :labor_scale)
    abmproperties(model).unemployment_rate = (total_labor_force - abmproperties(model).total_employment) / 
                                         max(1.0, total_labor_force)
    
    # Wages
    if !isempty(employed)
        abmproperties(model).wage_average = mean(w.wage for w in employed)
        abmproperties(model).total_wages = sum(w.wage for w in employed; init=0.0) * getparam(model, :labor_scale)
    else
        abmproperties(model).wage_average = getparam(model, :initial_wage)
        abmproperties(model).total_wages = 0.0
    end
    
    # Production
    firms1 = [f for f in allagents(model) if f isa Firm1]
    firms2 = [f for f in allagents(model) if f isa Firm2]
    
    abmproperties(model).sector1_production = sum(f.production for f in firms1; init=0.0)
    abmproperties(model).sector2_production = sum(f.production for f in firms2; init=0.0)
    
    abmproperties(model).sector1_employment = sum(f.labor_actual for f in firms1; init=0.0)
    abmproperties(model).sector2_employment = sum(f.labor_actual for f in firms2; init=0.0)
    
    # GDP (simplified)
    abmproperties(model).gdp_real = abmproperties(model).sector1_production + 
                                abmproperties(model).sector2_production
    abmproperties(model).gdp_nominal = sum(f.sales * f.price for f in firms1; init=0.0) +
                                   sum(f.sales * f.price for f in firms2; init=0.0)
    
    # Inflation (simplified)
    avg_price = !isempty(firms2) ? mean(f.price for f in firms2) : 1.0
    abmproperties(model).inflation = 0.02  # Simplified constant
    
    # Update worker skills and age
    for worker in workers
        worker.age += 1
        
        # Handle retirement
        if getparam(model, :retirement_age) > 0 && worker.age > getparam(model, :retirement_age)
            worker.age = 1  # "Rebirth"
            if worker.employed > 0
                fire_worker!(worker, model)
            end
            worker.skill_vintage = getparam(model, :initial_skill)
            worker.skill_tenure = getparam(model, :initial_skill)
            worker.skill_compound = getparam(model, :initial_skill)
        end
        
        # Update skills
        if worker.employed > 0
            worker.tenure += 1
            # Learning-by-doing
            if getparam(model, :learning_tenure) > 0
                worker.skill_tenure *= (1 + getparam(model, :learning_tenure))
            end
        else
            # Skill deterioration when unemployed
            if getparam(model, :skill_deterioration_unemployed) > 0
                worker.skill_tenure *= (1 - getparam(model, :skill_deterioration_unemployed))
                worker.skill_vintage *= (1 - getparam(model, :skill_deterioration_unemployed))
            end
        end
        
        # Update compound skill
        worker.skill_compound = (worker.skill_vintage + worker.skill_tenure) / 2.0
    end
end

#=============================================================================
DATA COLLECTION
=============================================================================#

"""
Define data collection functions for the model
"""
function setup_data_collection()
    # Agent-level data to collect
    adata = [
        # Workers
        (:employed, w -> w isa Worker),
        (:wage, w -> w isa Worker),
        (:skill_compound, w -> w isa Worker),
        
        # Firms
        (:production, f -> f isa Firm1 || f isa Firm2),
        (:profits, f -> f isa Firm1 || f isa Firm2),
        (:market_share, f -> f isa Firm1 || f isa Firm2),
    ]
    
    # Model-level data to collect
    mdata = [
        :gdp_real,
        :gdp_nominal,
        :unemployment_rate,
        :wage_average,
        :total_employment,
        :sector1_production,
        :sector2_production,
        :inflation,
        :public_debt,
        :deficit,
    ]
    
    return adata, mdata
end

#=============================================================================
VISUALIZATION AND ANALYSIS
=============================================================================#

"""
Run a simulation and collect data
"""
function run_simulation(; n_steps=100, parameters=get_default_parameters())
    # Initialize model
    model = initialize_ks_model(parameters=parameters)
    
    # Set up data collection
    adata, mdata = setup_data_collection()
    
    # Run simulation with data collection
    # In Agents.jl v6.2, model_step! is stored in the model, so we don't pass it here
    # Since we only have model_step! (no agent_step!), we can pass dummystep or nothing
    adf, mdf = run!(model, n_steps; adata, mdata)
    
    return model, adf, mdf
end

"""
Print summary statistics from a simulation run
"""
function print_summary(mdf::DataFrame)
    println("\n" * "="^70)
    println("K+S Labor Market Model - Simulation Summary")
    println("="^70)
    
    println("\nMacroeconomic Indicators:")
    println("-" * "="^69)
    println("  Average GDP (real):           ", round(mean(mdf.gdp_real), digits=2))
    println("  Average GDP (nominal):        ", round(mean(mdf.gdp_nominal), digits=2))
    println("  Average Unemployment Rate:    ", round(mean(mdf.unemployment_rate) * 100, digits=2), "%")
    println("  Average Inflation:            ", round(mean(mdf.inflation) * 100, digits=2), "%")
    println("  Average Wage:                 ", round(mean(mdf.wage_average), digits=2))
    
    println("\nSector Performance:")
    println("-" * "="^69)
    println("  Sector 1 Avg Production:      ", round(mean(mdf.sector1_production), digits=2))
    println("  Sector 2 Avg Production:      ", round(mean(mdf.sector2_production), digits=2))
    println("  Total Employment:             ", round(mean(mdf.total_employment), digits=2))
    
    println("\nGovernment:")
    println("-" * "="^69)
    println("  Final Public Debt:            ", round(mdf.public_debt[end], digits=2))
    println("  Average Deficit:              ", round(mean(mdf.deficit), digits=2))
    
    println("\n" * "="^70)
end

#=============================================================================
MAIN EXECUTION
=============================================================================#

"""
Main function to run the K+S model simulation
"""
function main()
    println("Initializing K+S Labor Market Model...")
    println("="^70)
    
    # Get parameters
    params = get_default_parameters()
    
    println("\nModel Configuration:")
    println("  Workers:                      ", params[:n_workers])
    println("  Capital-good firms (Sector 1):", params[:n_firms1])
    println("  Consumption firms (Sector 2): ", params[:n_firms2])
    println("  Banks:                        ", params[:n_banks])
    println("  Simulation steps:             ", params[:max_steps])
    println("  Random seed:                  ", params[:seed])
    
    # Run simulation
    println("\nRunning simulation...")
    model, adf, mdf = run_simulation(n_steps=params[:max_steps], parameters=params)
    
    # Print summary
    print_summary(mdf)
    
    # Save results
    println("\nSaving results...")
    # Note: Uncomment to save CSV files
    # using CSV
    # CSV.write("ks_model_data.csv", mdf)
    # CSV.write("ks_agent_data.csv", adf)
    
    println("\nSimulation complete!")
    
    return model, adf, mdf
end

# Run the main function when script is executed
if abspath(PROGRAM_FILE) == @__FILE__
    model, adf, mdf = main()
end

#=============================================================================
END OF K+S LABOR MARKET MODEL
=============================================================================#
