# K+S Model Complete Pseudocode Specification

## Model Overview
The K+S (Keynes+Schumpeter) model is an agent-based macroeconomic model with:
- **4 Agent Types**: Workers, Capital-good Firms (Firm1), Consumption-good Firms (Firm2), Banks
- **3 Main Markets**: Labor market, Capital-good market, Consumption-good market
- **Government & Central Bank**: Fiscal and monetary policy
- **Key Features**: Endogenous innovation, heterogeneous agents, disequilibrium dynamics

## Agent Types and Properties

### Worker Agent
```
Properties:
  - ID: unique identifier
  - employed: employment status (0=unemployed, 1=sector1, 2=sector2)
  - employer: pointer to current employer firm (if employed)
  - vintage: pointer to machine vintage being operated (if in sector2)
  - w: current wage
  - wRes: reservation wage
  - s: worker skills (composite)
  - sV: vintage-specific skills (learning-by-using)
  - sT: tenure skills (learning-by-doing)
  - Te: time employed at current job
  - Tc: contract term counter
  - age: worker age
  - searchProb: job search probability
  - discouraged: discouragement status
  
Behaviors:
  - apply_for_jobs(): Submit applications to firms
  - update_skills(): Learning-by-doing and learning-by-using
  - update_reservation_wage(): Based on past wages
  - retire_or_reborn(): Handle retirement and reentry
  - consume(): Spend wage on consumption goods
```

### Firm1 Agent (Capital-Good Sector)
```
Properties:
  - ID: unique identifier
  - A: productivity of machines produced (final)
  - B: production productivity (firm's own)
  - Atau: productivity of current technology
  - Btau: production productivity of current tech
  - f1: market share
  - L1: employed workers
  - L1d: desired labor
  - L1rd: workers in R&D
  - Q1: production (machines)
  - Q1e: effective production
  - D1: demand (orders received)
  - S1: sales
  - N1: inventories
  - p1: price
  - c1: unit cost
  - mu1: markup
  - w1: average wage
  - NW1: net worth
  - Deb1: bank debt
  - bank: pointer to bank relationship
  - brochures: list of customers
  - age: firm age
  
Behaviors:
  - innovate(): R&D for new technology
  - imitate(): Copy competitors' technology
  - produce_machines(): Production based on orders
  - set_price(): Cost-plus pricing
  - send_brochures(): Market machines to customers
  - hire_workers(): Labor demand and hiring
  - fire_workers(): Labor adjustment
  - update_finances(): Cash flow, debt, net worth
  - entry_exit_decision(): Bankruptcy or exit
```

### Firm2 Agent (Consumption-Good Sector)
```
Properties:
  - ID: unique identifier
  - f2: market share
  - L2: employed workers
  - L2d: desired labor
  - Q2: production (goods)
  - Q2e: effective production
  - D2: actual demand
  - D2e: expected demand
  - D2d: desired demand (orders)
  - S2: sales
  - N2: inventories
  - K: capital stock (machines)
  - vintages: map of machine vintages
  - p2: price
  - c2: unit cost
  - mu2: markup (variable)
  - w2: average wage
  - competitiveness: market competitiveness
  - NW2: net worth
  - Deb2: bank debt
  - bank: pointer to bank
  - supplier: pointer to machine supplier (Firm1)
  - postChg: post-change firm type flag
  - age: firm age
  
Behaviors:
  - form_expectations(): Adaptive demand expectations
  - plan_production(): Based on expectations
  - decide_investment(): Expansion and replacement
  - order_machines(): From capital-good firms
  - produce_goods(): Using capital and labor
  - set_price(): Variable markup based on market share
  - compete(): Replicator dynamics for market share
  - hire_workers(): Labor demand and hiring
  - fire_workers(): Labor adjustment based on rules
  - update_finances(): Cash flow, debt, net worth
  - entry_exit_decision(): Bankruptcy or exit
```

### Bank Agent
```
Properties:
  - ID: unique identifier
  - NWb: net worth
  - Depo: deposits from firms
  - Loans: total loans outstanding
  - Loans1: loans to sector 1
  - Loans2: loans to sector 2
  - BadDeb: bad debt (defaults)
  - Res: required reserves
  - ExRes: excess reserves
  - BondsB: sovereign bonds held
  - LoansCB: loans from central bank
  - r: prime interest rate
  - rDeb: lending rate
  - rD: deposit rate
  - pecking_order: ranked list of clients
  
Behaviors:
  - accept_deposits(): From firms
  - evaluate_credit(): Credit scoring
  - allocate_credit(): Pecking order allocation
  - update_interest_rates(): From central bank rate
  - handle_defaults(): Bad debt from bankruptcies
  - manage_reserves(): Required and excess reserves
  - trade_bonds(): Sovereign bond market
  - compute_profits(): Banking profits
  - check_bailout(): Capital adequacy and bailout
```

## Temporal Dynamics (Time Step Sequence)

```
INITIALIZATION (t=0):
  1. Create initial population of agents
  2. Initialize agent properties
  3. Establish initial relationships
  4. Set initial market shares
  5. Initialize lagged variables

EACH TIME STEP (t=1..T):
  Phase 1: MONETARY POLICY
  Phase 2: EXPECTATION & PLANNING (Sector 2)
  Phase 3: R&D & PRODUCTION PLANNING (Sector 1)
  Phase 4: LABOR MARKET
  Phase 5: PRODUCTION
  Phase 6: PRICING
  Phase 7: CONSUMPTION & DEMAND
  Phase 8: INVESTMENT
  Phase 9: FINANCE
  Phase 10: GOVERNMENT
  Phase 11: MARKET DYNAMICS
  Phase 12: ENTRY/EXIT
  Phase 13: AGGREGATION & STATISTICS
  Phase 14: REGIME CHANGE (if t == TregChg)
```

See full specification in code comments for detailed behavioral rules.
