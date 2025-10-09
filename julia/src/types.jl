"""
    types.jl

Agent type definitions for the K+S model.
Defines the four main agent types and their properties.
"""

# Abstract types for agent hierarchy
abstract type KSAgent <: AbstractAgent end
abstract type Firm <: KSAgent end

"""
    Worker <: KSAgent

Represents a worker/consumer in the K+S model.

# Fields (matching C model _Worker properties)
- `id::Int`: Unique identifier
- `employed::Int`: Employment status (0=unemployed, 1=sector1, 2=sector2)
- `employer::Union{Nothing,Int}`: ID of employer firm
- `vintage::Union{Nothing,Int}`: ID of machine vintage being operated
- `w::Float64`: Current wage
- `wRes::Float64`: Reservation wage
- `s::Float64`: Composite worker skills
- `sV::Float64`: Vintage-specific skills (learning-by-using)
- `sT::Float64`: Tenure skills (learning-by-doing)
- `Te::Int`: Time employed at current job
- `Tc::Int`: Contract term counter
- `age::Int`: Worker age
- `searchProb::Float64`: Job search probability
- `discouraged::Bool`: Discouragement status
- `wage_memory::Vector{Float64}`: Past wages for reservation wage
- `consumption::Float64`: Current period consumption
"""
@agent struct Worker(NoSpaceAgent) <: KSAgent
    employed::Int = 0
    employer::Union{Nothing,Int} = nothing
    vintage::Union{Nothing,Int} = nothing
    w::Float64 = 1.0
    wRes::Float64 = 1.0
    s::Float64 = 1.0
    sV::Float64 = 1.0
    sT::Float64 = 1.0
    Te::Int = 0
    Tc::Int = 0
    age::Int = 1
    searchProb::Float64 = 1.0
    discouraged::Bool = false
    wage_memory::Vector{Float64} = Float64[]
    consumption::Float64 = 0.0
end

"""
    Firm1 <: Firm

Represents a capital-good firm (sector 1) in the K+S model.

# Fields (matching C model _Firm1 properties)
- `id::Int`: Unique identifier  
- `A::Float64`: Final productivity of machines produced
- `B::Float64`: Production productivity (firm's own)
- `Atau::Float64`: Productivity of current technology
- `Btau::Float64`: Production productivity of current tech
- `f1::Float64`: Market share
- `L1::Int`: Employed workers
- `L1d::Float64`: Desired labor
- `L1rd::Float64`: Actual R&D workers hired (lagged for innovation calculation)
- `L1dRD::Float64`: Desired R&D workers for current period
- `Q1::Float64`: Production (machines)
- `Q1e::Float64`: Effective production
- `D1::Float64`: Demand (orders received)
- `S1::Float64`: Sales
- `N1::Float64`: Inventories
- `p1::Float64`: Price
- `c1::Float64`: Unit cost
- `mu1::Float64`: Markup
- `w1::Float64`: Average wage
- `NW1::Float64`: Net worth
- `Deb1::Float64`: Bank debt
- `bank_id::Int`: ID of bank relationship
- `client_ids::Vector{Int}`: IDs of brochure recipients (customers)
- `age::Int`: Firm age
- `exit_flag::Bool`: Marked for exit
"""
@agent struct Firm1(NoSpaceAgent) <: Firm
    A::Float64 = 1.0
    B::Float64 = 1.0
    Atau::Float64 = 1.0
    Btau::Float64 = 1.0
    f1::Float64 = 0.0
    L1::Int = 0
    L1d::Float64 = 0.0
    L1rd::Float64 = 0.0  # Actual R&D workers from previous period
    L1dRD::Float64 = 0.0  # Desired R&D workers for current period
    Q1::Float64 = 0.0
    Q1e::Float64 = 0.0
    D1::Float64 = 0.0
    S1::Float64 = 0.0
    S1_prev::Float64 = 0.0  # Previous period sales for R&D calculation
    N1::Float64 = 0.0
    p1::Float64 = 1.0
    c1::Float64 = 1.0
    mu1::Float64 = 0.0
    w1::Float64 = 1.0
    NW1::Float64 = 0.0
    Deb1::Float64 = 0.0
    bank_id::Int = 0
    client_ids::Vector{Int} = Int[]
    age::Int = 0
    exit_flag::Bool = false
    worker_ids::Vector{Int} = Int[]
    applications::Vector{Int} = Int[]
end

"""
    Firm2 <: Firm

Represents a consumption-good firm (sector 2) in the K+S model.

# Fields (matching C model _Firm2 properties)
- `id::Int`: Unique identifier
- `f2::Float64`: Market share
- `L2::Int`: Employed workers
- `L2d::Float64`: Desired labor
- `Q2::Float64`: Production (goods)
- `Q2e::Float64`: Effective production
- `D2::Float64`: Actual demand
- `D2e::Float64`: Expected demand
- `D2d::Float64`: Desired demand (orders)
- `S2::Float64`: Sales
- `N2::Float64`: Inventories
- `K::Float64`: Capital stock (machines)
- `vintages::Dict{Int,NamedTuple}`: Machine vintages (ID => (count, productivity, skills, age))
- `p2::Float64`: Price
- `c2::Float64`: Unit cost
- `mu2::Float64`: Variable markup
- `w2::Float64`: Average wage
- `competitiveness::Float64`: Market competitiveness
- `NW2::Float64`: Net worth
- `Deb2::Float64`: Bank debt
- `bank_id::Int`: ID of bank
- `supplier_id::Int`: ID of machine supplier (Firm1)
- `postChg::Bool`: Post-change firm type
- `age::Int`: Firm age
- `exit_flag::Bool`: Marked for exit
"""
@agent struct Firm2(NoSpaceAgent) <: Firm
    f2::Float64 = 0.0
    L2::Int = 0
    L2d::Float64 = 0.0
    Q2::Float64 = 0.0
    Q2e::Float64 = 0.0
    D2::Float64 = 0.0
    D2e::Float64 = 0.0
    D2d::Float64 = 0.0
    D2_history::Vector{Float64} = Float64[]
    S2::Float64 = 0.0
    l2::Float64 = 0.0  # Unfilled demand in quantity units
    N2::Float64 = 0.0
    N2_prev::Float64 = 0.0  # Previous period inventory for GDP calculation
    p2_prev::Float64 = 1.0  # Previous period price for GDP calculation
    K::Float64 = 0.0
    Kd::Float64 = 0.0
    vintages::Dict{Int,NamedTuple} = Dict{Int,NamedTuple}()
    p2::Float64 = 1.0
    c2::Float64 = 1.0
    mu2::Float64 = 0.0
    w2::Float64 = 1.0
    competitiveness::Float64 = 0.0
    NW2::Float64 = 0.0
    NW2_prev::Float64 = 0.0
    Deb2::Float64 = 0.0
    Id::Float64 = 0.0
    EId::Float64 = 0.0
    SId::Float64 = 0.0
    EI::Float64 = 0.0
    SI::Float64 = 0.0
    bank_id::Int = 0
    supplier_id::Int = 0
    postChg::Bool = false
    age::Int = 0
    exit_flag::Bool = false
    worker_ids::Vector{Int} = Int[]
    applications::Vector{Int} = Int[]
end

"""
    Bank <: KSAgent

Represents a bank in the K+S model.

# Fields (matching C model _Bank properties)
- `id::Int`: Unique identifier
- `NWb::Float64`: Net worth
- `Depo::Float64`: Deposits from firms
- `Loans::Float64`: Total loans outstanding
- `Loans1::Float64`: Loans to sector 1
- `Loans2::Float64`: Loans to sector 2
- `BadDeb::Float64`: Bad debt (defaults)
- `BadDeb1::Float64`: Bad debt from sector 1
- `BadDeb2::Float64`: Bad debt from sector 2
- `Res::Float64`: Required reserves
- `ExRes::Float64`: Excess reserves
- `BondsB::Float64`: Sovereign bonds held
- `LoansCB::Float64`: Loans from central bank
- `r::Float64`: Prime interest rate
- `rDeb::Float64`: Lending rate
- `rD::Float64`: Deposit rate
- `client1_ids::Vector{Int}`: Sector 1 client IDs
- `client2_ids::Vector{Int}`: Sector 2 client IDs
- `pecking_order::Vector{Tuple{Int,Float64}}`: (firm_id, credit_score) sorted
"""
@agent struct Bank(NoSpaceAgent) <: KSAgent
    NWb::Float64 = 0.0
    Depo::Float64 = 0.0
    Loans::Float64 = 0.0
    Loans1::Float64 = 0.0
    Loans2::Float64 = 0.0
    BadDeb::Float64 = 0.0
    BadDeb1::Float64 = 0.0
    BadDeb2::Float64 = 0.0
    Res::Float64 = 0.0
    ExRes::Float64 = 0.0
    BondsB::Float64 = 0.0
    LoansCB::Float64 = 0.0
    r::Float64 = 0.0
    rDeb::Float64 = 0.0
    rD::Float64 = 0.0
    client1_ids::Vector{Int} = Int[]
    client2_ids::Vector{Int} = Int[]
    pecking_order::Vector{Tuple{Int,Float64}} = Tuple{Int,Float64}[]
end

"""
    Vintage

Structure representing a machine vintage in Firm2.
Matches the vintage struct in fun_KS_class.h.
"""
struct Vintage
    t0::Int  # Period of creation
    supplier_id::Int  # ID of Firm1 that produced it
    A::Float64  # Productivity
    sVp::Float64  # Public skills for vintage
    sVavg::Float64  # Average skills for vintage
    machines::Int  # Number of machines of this vintage
    price::Float64  # Purchase price
end
