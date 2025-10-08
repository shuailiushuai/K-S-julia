# K+S Model: C Implementation vs Julia Implementation Comparison

## Overview
This document provides a comprehensive comparison between the original C/LSD implementation and the Julia/Agents.jl replication of the K+S (Keynes+Schumpeter) agent-based macroeconomic model.

## Model Structure

### C Implementation Files (Original)
- `fun_KS.cpp` - Main scheduling and initialization
- `fun_KS_class.h` - Class and macro definitions (5.8K)
- `fun_KS_country.h` - Country-level equations (21K)
- `fun_KS_financial.h` - Financial market (8.8K)
- `fun_KS_bank.h` - Bank behavior (12K)
- `fun_KS_capital.h` - Sector 1 (capital goods) (17K)
- `fun_KS_firm1.h` - Firm1 specific equations (16K)
- `fun_KS_consumption.h` - Sector 2 (consumption goods) (23K)
- `fun_KS_firm2.h` - Firm2 specific equations (37K)
- `fun_KS_labor.h` - Labor market (9.2K)
- `fun_KS_worker.h` - Worker behavior (15K)
- `fun_KS_vintage.h` - Machine vintages (3.8K)
- `fun_KS_stats.h` - Statistics and aggregation (25K)
- `fun_KS_support.h` - Support functions (40K)
- `fun_KS_test.h` - Testing and validation (69K)
- **Total: 367 equations**

### Julia Implementation Files
- `KSModel.jl` - Main module and exports
- `types.jl` - Agent type definitions
- `parameters.jl` - Model parameters
- `initialization.jl` - Model initialization
- `scheduling.jl` - Time-step scheduling
- `firm1_behavior.jl` - Capital-good firm behavior
- `firm2_behavior.jl` - Consumption-good firm behavior
- `worker_behavior.jl` - Worker/consumer behavior
- `bank_behavior.jl` - Bank behavior
- `government.jl` - Government and central bank
- `markets.jl` - Market mechanisms
- `statistics.jl` - Data collection and aggregation
- `visualization.jl` - Plotting functions

## Agent Types

### Worker (C: `_Worker` variables)
**C Model Fields:**
- `_ID`, `_age`, `_employed`, `_employer`, `_vintage`
- `_w`, `_wRes`, `_s`, `_sV`, `_sT`
- `_Te`, `_Tc`, `_Tu`, `_searchProb`, `_discouraged`
- `_appl`, `_Bon`, `_Q`

**Julia Implementation:**
```julia
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
```

**Status:** ✓ Complete - All essential fields mapped

### Firm1 (C: `_Firm1` variables)
**C Model Key Equations:**
- `_A1`, `_Atau`, `_B`, `_Btau` - Productivity levels
- `_c1`, `_p1`, `_mu1` - Cost, price, markup
- `_L1`, `_L1d`, `_L1rd` - Labor
- `_Q1`, `_Q1e`, `_D1`, `_S1`, `_N1` - Production and sales
- `_NW1`, `_Deb1`, `_Deb1max` - Finance
- `_RD`, `_inn`, `_imi` - R&D
- `_CS1`, `_CD1`, `_Div1` - Credit and dividends

**Julia Implementation:**
```julia
@agent struct Firm1(NoSpaceAgent) <: Firm
    A::Float64 = 1.0
    B::Float64 = 1.0
    Atau::Float64 = 1.0
    Btau::Float64 = 1.0
    f1::Float64 = 0.0
    L1::Int = 0
    L1d::Float64 = 0.0
    L1rd::Float64 = 0.0
    Q1::Float64 = 0.0
    Q1e::Float64 = 0.0
    D1::Float64 = 0.0
    S1::Float64 = 0.0
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
```

**Status:** ✓ Core fields complete, R&D implementation needs verification

### Firm2 (C: `_Firm2` variables)
**C Model Key Equations:**
- `_A2`, `_A2p`, `_c2`, `_p2`, `_mu2` - Productivity, cost, price
- `_L2`, `_L2d` - Labor
- `_Q2`, `_Q2e`, `_Q2d`, `_D2`, `_D2e`, `_D2d`, `_S2`, `_N2` - Production
- `_K`, `_Kd`, `_EI`, `_EId`, `_SI`, `_SId`, `_Id` - Capital and investment
- `_NW2`, `_Deb2`, `_Deb2max` - Finance
- `_f2`, `_E` - Market share and competitiveness
- Vintage management

**Julia Implementation:**
```julia
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
    N2::Float64 = 0.0
    K::Float64 = 0.0
    Kd::Float64 = 0.0
    vintages::Dict{Int,NamedTuple} = Dict{Int,NamedTuple}()
    p2::Float64 = 1.0
    c2::Float64 = 1.0
    mu2::Float64 = 0.0
    w2::Float64 = 1.0
    competitiveness::Float64 = 0.0
    NW2::Float64 = 0.0
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
```

**Status:** ✓ Core fields complete, investment logic implemented

### Bank (C: `_Bank` variables)
**C Model Key Equations:**
- `_NWb`, `_Depo`, `_Loans`, `_Loans1`, `_Loans2` - Balance sheet
- `_BadDeb`, `_BadDeb1`, `_BadDeb2` - Non-performing loans
- `_Res`, `_ExRes`, `_BondsB`, `_LoansCB` - Reserves and assets
- `_r`, `_rDeb`, `_rD` - Interest rates
- Client management and pecking order

**Julia Implementation:**
```julia
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
```

**Status:** ✓ Core fields complete

## Key Behaviors Comparison

### 1. Firm2 Investment Logic

#### C Model (`fun_KS_firm2.h`)
```c
EQUATION( "_EI" )
// Effective expansion investment
V( "_Q2" );  // make sure production decided
V( "_supplier" );  // ensure supplier is selected
RESULT( invest( THIS, V( "_EId" ) ) )

EQUATION( "_EId" )
// Desired expansion investment
v[1] = V( "_Kd" );  // desired capital
v[2] = VL( "_K", 1 );  // available capital stock
v[3] = VS( PARENT, "m2" );  // machine output per period
// ... payback and threshold logic
RESULT( v[0] )

EQUATION( "_SI" )
// Effective substitution investment
V( "_EI" );  // make sure expansion done
RESULT( invest( THIS, V( "_SId" ) ) )

// invest() function handles financing constraints
```

#### Julia Implementation (`firm2_behavior.jl`)
```julia
function firm2_decide_investment!(firm::Firm2, model)
    # Calculate desired capital (_Kd equation)
    A_avg = firm2_average_productivity(firm)
    firm.Kd = max((1 + params.iota) * firm.D2e - firm.N2, 0.0) / params.u
    
    # === EXPANSION INVESTMENT (_EId equation) ===
    # ... threshold and rounding logic
    
    # === SUBSTITUTION INVESTMENT (_SId equation) ===
    # ... payback period calculation and vintage scrapping
    
    firm.Id = firm.EId + firm.SId
end

function firm2_execute_investment!(firm::Firm2, model)
    # Execute with financing constraints
    firm.EI = execute_investment_order(firm, firm.EId, model)
    firm.SI = execute_investment_order(firm, firm.SId, model)
end

function execute_investment_order(firm::Firm2, desired::Float64, model)
    # Implements invest() function from C model
    # Handles credit limits and net worth constraints
    # ... financing logic
    return actual_investment
end
```

**Status:** ✓ Implemented - Logic matches C model structure

### 2. Worker Job Search

#### C Model (`fun_KS_worker.h`)
```c
EQUATION( "_appl" )
// Worker job search and application
// Uses hooks (HOOK) to track relationships
// Implements search probability and discouragement
```

#### Julia Implementation (`worker_behavior.jl`)
```julia
function worker_search_job!(worker::Worker, model)
    # Implements search probability
    # Handles discouragement
    # Application to firms based on omega parameter
end
```

**Status:** ⚠ Partially implemented - needs verification against C model

### 3. Labor Market Matching

#### C Model (`fun_KS_support.h`)
```c
// Functions: hiring(), firing()
// Complex worker allocation to vintages
// Hooks for tracking firm-worker relationships
```

#### Julia Implementation (`markets.jl`)
```julia
function labor_market_matching!(model)
    # Wage offers, applications, hiring, firing
    # Simplified vintage allocation
end
```

**Status:** ⚠ Simplified - needs complete vintage allocation logic

## Parameters

### Parameter Coverage
**C Model:** ~200+ parameters defined in `description.txt`

**Julia Model:** 
- ✓ Country-level parameters (Crec, TregChg, gG, etc.)
- ✓ Financial parameters (B, Lambda, tauB, etc.)
- ✓ Capital market parameters (F10, mu1, nu, etc.)
- ✓ Consumer market parameters (F20, b, e0-e8, etc.)
- ✓ Labor parameters (Ls0, Tc, Tr, psi1-6, etc.)
- ✓ Control flags (flagCons, flagExpect, etc.)

**Status:** ✓ All major parameters mapped

## Critical Functions to Verify

### From C Model `fun_KS_support.h`
1. ✓ `invest()` - Investment financing (implemented as execute_investment_order)
2. ⚠ `cash_flow()` - Firm cash flow management (partially in firm2_update_finances)
3. ⚠ `hiring()` - Worker hiring process (in labor_market_matching)
4. ⚠ `firing()` - Worker firing process (in labor_market_matching)
5. ⚠ Worker allocation to vintages (simplified)
6. ⚠ Skills evolution (sV, sT) - basic implementation
7. ⚠ Bank credit evaluation and pecking order (partially implemented)

## Simplifications in Julia Model

### Known Simplifications
1. **Vintage Management:** Simplified compared to C model's detailed vintage tracking with hooks
2. **Worker-Vintage Assignment:** C model has complex allocation; Julia has simplified version
3. **Skills Evolution:** Learning-by-doing and learning-by-using partially implemented
4. **Bank Credit:** Pecking order structure exists but credit evaluation simplified
5. **Entry/Exit:** Basic implementation; C model has more sophisticated rules
6. **Statistics:** Core statistics implemented; some detailed metrics missing

## Testing Status

### Unit Tests
- [ ] Worker behavior tests
- [ ] Firm1 behavior tests
- [ ] Firm2 behavior tests
- [ ] Bank behavior tests
- [ ] Market matching tests
- [ ] Investment logic tests

### Integration Tests
- [ ] Full model initialization
- [ ] Multi-period simulation
- [ ] Parameter sensitivity
- [ ] Regime change handling

### Validation
- [ ] Compare aggregate outputs with C model
- [ ] Verify microeconomic behaviors
- [ ] Check statistical distributions

## Next Steps

### Priority 1: Core Behavior Verification
1. Review and complete worker skill evolution
2. Verify Firm1 R&D logic against C model
3. Complete bank credit evaluation
4. Implement full vintage allocation logic

### Priority 2: Market Mechanisms
1. Complete labor market matching
2. Verify capital goods market
3. Verify consumption goods market
4. Test entry/exit dynamics

### Priority 3: Statistics and Validation
1. Implement all statistics from fun_KS_stats.h
2. Add comprehensive logging
3. Create validation tests
4. Document remaining differences

## References
- Original C/LSD Model: fun_KS.cpp and associated .h files
- Model Description: description.txt
- Parameters: Cent_wage-Baseline_v2.lsd

## Revision History
- 2025-01-XX: Initial comparison document created
- 2025-01-XX: Completed API compatibility fixes
- 2025-01-XX: Implemented investment logic
