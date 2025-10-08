"""
    parameters.jl

Model parameters for the K+S model.
All parameters match the C implementation in description.txt.
Default values from baseline configuration files (.lsd).
"""

"""
    ModelParameters

Container for all K+S model parameters.
Organized by category matching the C implementation.
"""
@kwdef mutable struct ModelParameters
    # === COUNTRY-LEVEL PARAMETERS (object Country) ===
    Crec::Float64 = 0.5  # Unfilled past consumption recover limit
    TregChg::Int = 0  # Regime change period (0=no change)
    gG::Float64 = 0.0  # Growth rate of fixed public expenditure
    mLim::Float64 = 0.0  # Absolute cap on moving-average growth
    mPer::Int = 4  # Number of periods on moving-average growth
    omicron::Float64 = 0.5  # Sensitivity of entry to market conditions
    stick::Float64 = 0.1  # Stickiness of the number of firms
    tr::Float64 = 0.2  # Tax rate (pre-change)
    trChg::Float64 = 0.2  # Tax rate (post-change)
    x2inf::Float64 = -0.1  # Lower support for entry draw distribution
    x2sup::Float64 = 0.1  # Upper support for entry draw distribution
    
    # === FINANCIAL MARKET PARAMETERS (object Financial) ===
    B::Int = 10  # Number of heterogeneous banks
    DebRule::Float64 = 1.5  # Maximum government debt on GDP ratio
    DefPrule::Float64 = 0.05  # Maximum government primary deficit on GDP ratio
    EqB0::Float64 = 1.0  # Initial equity of bank as multiple of firms total net worth
    Lambda::Float64 = 2.0  # Multiple of net assets for credit limit (pre-change)
    LambdaChg::Float64 = 2.0  # Multiple of net assets for credit limit (post-change)
    Lambda0::Float64 = 10.0  # Credit limit initial absolute floor
    PhiB::Float64 = 0.1  # Fraction of incumbent banks net worth for bailed-out bank
    Trule::Int = 50  # Time to start enforcing fiscal rules
    Ut::Float64 = 0.05  # Target unemployment rate for central bank
    alphaB::Float64 = 2.0  # Pareto distribution shape parameter for bank size
    betaB::Float64 = 0.5  # Bank sensitivity to financial fragility
    dB::Float64 = 0.5  # Dividend rate on net profits for banks
    deltaB::Float64 = 0.1  # Desired share of outstanding firm debt to pay
    deltaDeb::Float64 = 0.1  # Share of government debt to pay when rule is binding
    gammaPi::Float64 = 0.5  # Central bank Taylor rule sensitivity to inflation
    gammaU::Float64 = 0.5  # Central bank Taylor rule sensitivity to unemployment
    kConst::Float64 = 0.1  # Interest rate ramping parameter
    mPerB::Int = 4  # Number of periods on banks moving-average
    muBonds::Float64 = 0.01  # Sovereign bonds spread
    muD::Float64 = 0.01  # Bank spread (mark-down) on deposits
    muDeb::Float64 = 0.02  # Bank spread (mark-up) on debt
    muRes::Float64 = 0.005  # Central bank spread (mark-down) on reserves (pre-change)
    muResChg::Float64 = 0.005  # Central bank spread on reserves (post-change)
    piT::Float64 = 0.02  # Target inflation rate by central bank
    rAdj::Float64 = 0.001  # Prime rate minimum adjustment step
    rT::Float64 = 0.04  # Target prime interest rate (pre-change)
    rTchg::Float64 = 0.04  # Target prime interest rate (post-change)
    rhoBonds::Float64 = 0.0  # Sovereign bonds risk premium
    tauB::Float64 = 0.08  # Minimum bank capital adequacy rate (pre-change)
    tauBchg::Float64 = 0.08  # Minimum bank capital adequacy rate (post-change)
    thetaBonds::Float64 = 10.0  # Average maturity periods of sovereign bonds
    
    # === CAPITAL MARKET PARAMETERS (object Capital) ===
    Deb10ratio::Float64 = 0.0  # Debt-to-equity initial ratio in sector 1
    F10::Int = 50  # Initial number of firms in sector 1
    F1max::Int = 100  # Maximum number of firms in sector 1
    F1min::Int = 10  # Minimum number of firms in sector 1
    L1rdMax::Float64 = 0.2  # Maximum share of workers in R&D
    L1shortMax::Float64 = 0.2  # Maximum labor shortage allowed in sector 1
    NW10::Float64 = 100.0  # Average initial net worth in sector 1
    Phi3::Float64 = 0.1  # Lower support for capital-good entrant net worth share
    Phi4::Float64 = 0.9  # Upper support for capital-good entrant net worth share
    alpha1::Float64 = 3.0  # Beta distribution alpha for innovation
    beta1::Float64 = 3.0  # Beta distribution beta for innovation
    alpha2::Float64 = 3.0  # Beta distribution alpha for imitation
    beta2::Float64 = 4.0  # Beta distribution beta for imitation
    d1::Float64 = 0.5  # Dividend rate in capital-good sector
    gamma::Float64 = 0.5  # New customer share for firm in sector 1
    m1::Float64 = 0.1  # Worker output in capital-good units per period
    mu1::Float64 = 0.08  # Mark-up of firms in the capital-good sector
    n1::Int = 4  # Number of periods for evaluating market share in sector 1
    nu::Float64 = 0.04  # Share of revenue applied in R&D
    x1inf::Float64 = -0.15  # Lower support for new machine productivity change
    x1sup::Float64 = 0.15  # Upper support for new machine productivity change
    x5::Float64 = 0.5  # Upper share limit for productivity improvement of entrant
    xi::Float64 = 0.5  # Share of R&D expenses in innovation
    zeta1::Float64 = 0.3  # Expected elasticity of R&D expense in innovation success
    zeta2::Float64 = 0.3  # Expected elasticity of R&D expense in imitation success
    
    # === CONSUMER MARKET PARAMETERS (object Consumption) ===
    Deb20ratio::Float64 = 0.0  # Debt-to-equity initial ratio in sector 2
    F20::Int = 200  # Initial number of firms in sector 2
    F2max::Int = 400  # Maximum number of firms in sector 2
    F2min::Int = 50  # Minimum number of firms in sector 2
    NW20::Float64 = 50.0  # Average minimum initial net worth in sector 2
    Phi1::Float64 = 0.1  # Lower support for consumption-good entrant net worth
    Phi2::Float64 = 0.9  # Upper support for consumption-good entrant net worth
    b::Float64 = 3.0  # Number of pay-back periods before machine scrapping (pre-change)
    bChg::Float64 = 3.0  # Pay-back periods (post-change)
    chi::Float64 = 1.0  # Replicator dynamics selectivity coefficient
    d2::Float64 = 0.5  # Dividend rate in consumption-good sector
    e0::Float64 = 0.5  # Weight of potential demand on expectations (pre-change)
    e0Chg::Float64 = 0.5  # Weight of potential demand (post-change)
    e1::Float64 = 0.4  # Weight of t-1 demand on myopic expectations
    e2::Float64 = 0.3  # Weight of t-2 demand
    e3::Float64 = 0.2  # Weight of t-3 demand
    e4::Float64 = 0.1  # Weight of t-4 demand
    e5::Float64 = 0.5  # Acceleration rate on expected demand growth
    e6::Float64 = 0.5  # First order adaptive expectation factor
    e7::Float64 = 0.5  # First order extrapolative expectation factor
    e8::Float64 = 0.5  # Second order extrapolative expectation factor
    ent2HldPer::Int = 50  # Periods after TregChg to hold fixed proportion
    ent2HldShr::Float64 = 0.5  # Share of post-change entrants during hold period
    eta::Float64 = 20.0  # Technical lifetime of machines
    f2min::Float64 = 0.001  # Minimum market share to stay in sector 2
    f2minPosChg::Float64 = 0.1  # Minimum probability of new post-change-type firm
    f2trdChg::Float64 = 0.0  # Minimum market share of post-change-type firms
    iota::Float64 = 0.1  # Share of inventories on planned output
    kappaMax::Float64 = 0.5  # Capital max threshold share growth
    kappaMin::Float64 = 0.0  # Capital min threshold share growth
    m2::Float64 = 40.0  # Machine output in consumption-good units per period
    mu20::Float64 = 0.2  # Initial mark-up in consumption-good sector (pre-change)
    mu20Chg::Float64 = 0.2  # Initial mark-up (post-change)
    n2::Int = 4  # Number of periods for evaluating market share in sector 2
    omega1::Float64 = 1.0  # Competitiveness weight of price
    omega2::Float64 = 1.0  # Competitiveness weight of unfilled demand
    omega3::Float64 = 0.0  # Competitiveness weight of quality
    u::Float64 = 0.75  # Planned utilization of machinery
    upsilon::Float64 = 0.04  # Sensitivity of mark-up adjustment
    
    # === LABOR SUPPLY PARAMETERS (object Labor) ===
    Gamma::Float64 = 0.5  # Share of unemployed covered by government training
    GammaCost::Float64 = 0.1  # Share of average wage cost per worker for training
    Ls0::Int = 250000  # Initial number of workers in labor market
    Lscale::Int = 1  # Scale of one Worker object (workers per object)
    Tc::Int = 4  # Work contract term (periods)
    Tp::Int = 2  # Number of periods after firing is not allowed
    Tr::Int = 40  # Number of periods a worker stays before retiring
    Ts::Int = 4  # Number of periods to define requested wage (pre-change)
    TsChg::Int = 4  # Number of periods to define requested wage (post-change)
    delta::Float64 = 0.01  # Labor force growth rate
    epsilon::Float64 = 0.02  # Minimum wage increment to change jobs
    kappa::Float64 = 0.5  # Overall intensity for job searching of discouraged workers
    lambda::Float64 = 0.5  # Individual for job searching intensity
    omega::Float64 = 3.0  # Average number of firms employed workers apply for jobs
    omegaPreChg::Float64 = 3.0  # Avg # job applications per worker in pre-change firm
    omegaPosChg::Float64 = 3.0  # Avg # job applications per worker in post-change firm
    omegaU::Float64 = 5.0  # Average number of job applications by unemployed worker
    phi::Float64 = 0.5  # Unemployment benefit as share of average wage (pre-change)
    phiChg::Float64 = 0.5  # Unemployment benefit as share of average wage (post-change)
    psi1::Float64 = 0.5  # Share of inflation passed to wages
    psi2::Float64 = 0.5  # Elasticity of wages to aggregate productivity growth
    psi3::Float64 = -0.5  # Elasticity of wages to the unemployment rate
    psi4::Float64 = 0.5  # Elasticity of wages to firm-level productivity growth
    psi5::Float64 = 0.5  # Elasticity of wages to firm past vacancy rate
    psi6::Float64 = 0.3  # Share of firm free cash flow paid as bonus
    rho::Float64 = 0.5  # Labor sharing parameter for flagFireRule=1
    sigma::Float64 = 0.5  # Degree of learning-by-doing on public skill level
    tauG::Float64 = 0.5  # Learning factor for workers under government training
    tauT::Float64 = 0.01  # Tenure learning factor for employed workers
    tauU::Float64 = 0.01  # Skills deterioration rate for unemployed workers
    theta::Float64 = 0.1  # Share of extra capacity (slack) when hiring
    w0min::Float64 = 10.0  # Social benefit absolute floor (subsistence)
    wCap::Float64 = 2.0  # Wage change multiple cap on offers, requests, adjustments
    
    # === CONTROL FLAGS ===
    flagCons::Int = 2  # Consumption composition (0-2)
    flagGovExp::Int = 2  # Government expenditure (0-3)
    flagTax::Int = 1  # Taxation (0-1)
    flagCreditRule::Int = 2  # Bank total credit supply rule (0-2)
    flagFiscalRule::Int = 1  # Government fiscal rule (0-4)
    flagAllFirmsChg::Int = 0  # Capital-good sector regime change (0-1)
    flagExpect::Int = 0  # Firm expectation in consumption-good sector (0-4)
    flagAddWorkers::Int = 0  # Additional workers on full employment (0-1)
    flagSearchMode::Int = 0  # Job search mode (0-2)
    flagSearchModeChg::Int = 0  # Job search mode post-change
    flagSearchDisc::Int = 0  # Job search discouragement (0-2)
    flagHireSeq::Int = 0  # Consumption-good sector hiring sequence (0-3)
    flagHireSeqChg::Int = 0  # Hiring sequence post-change
    flagHireOrder1::Int = 0  # Hiring order sector 1 (0-8)
    flagHireOrder1Chg::Int = 0  # Hiring order sector 1 post-change
    flagHireOrder2::Int = 0  # Hiring order sector 2 (0-8)
    flagHireOrder2Chg::Int = 0  # Hiring order sector 2 post-change
    flagFireOrder1::Int = 0  # Firing order sector 1 (0-8)
    flagFireOrder1Chg::Int = 0  # Firing order sector 1 post-change
    flagFireOrder2::Int = 0  # Firing order sector 2 (0-8)
    flagFireOrder2Chg::Int = 0  # Firing order sector 2 post-change
    flagFireRule::Int = 2  # Consumption-good sector firing rule (0-6)
    flagFireRuleChg::Int = 2  # Firing rule post-change
    flagHeterWage::Int = 0  # Wage indexation heterogeneity (0-2)
    flagWageOffer::Int = 0  # Wage offer mode (0-1)
    flagWageOfferChg::Int = 0  # Wage offer mode post-change
    flagWagePremium::Int = 1  # Wage premium mode (0-2)
    flagIndexWage::Int = 1  # Wage indexation (0-2)
    flagIndexWageChg::Int = 1  # Wage indexation post-change
    flagIndexMinWage::Int = 1  # Minimum wage indexation (0-1, or fraction)
    flagIndexMinWageChg::Float64 = 1.0  # Minimum wage indexation post-change
    flagLearn1::Int = 0  # Worker-level learning in capital-good sector (0-3)
    flagWorkerLBU::Int = 0  # Worker-level learning cumulativeness (0-3)
    flagWorkerSkProd::Int = 0  # Worker skills effect on productivity in sector 2 (0-3)
    
    # === SIMULATION CONTROL ===
    T::Int = 500  # Number of time steps
    seed::Int = 1  # Random seed
end

"""
    load_baseline_parameters()

Load baseline parameter configuration.
Matches "Cent_wage-Baseline_v2.lsd" configuration.
"""
function load_baseline_parameters()
    return ModelParameters()
end

"""
    load_benchmark_parameters()

Load benchmark parameter configuration.
Matches "Cent_wage-Benchmark_v1.lsd" configuration.
"""
function load_benchmark_parameters()
    params = ModelParameters()
    # Simpler financial market (1 bank, fixed rates)
    params.B = 1
    params.flagCreditRule = 0
    params.F10 = 20
    params.F20 = 80
    return params
end
