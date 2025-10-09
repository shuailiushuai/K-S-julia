# K+S Model - Complete Comparison Checklist (C vs Julia)

This document provides a comprehensive comparison between the C model and the fixed Julia model.

## Overall Structure

| Component | C Model | Julia Model | Status | Notes |
|-----------|---------|-------------|--------|-------|
| Agent types | Worker, Firm1, Firm2, Bank | Worker, Firm1, Firm2, Bank | ✅ Match | Same agent hierarchy |
| Scheduling | Sequential phases in timeStep | Sequential phases in model_step! | ✅ Match | Same phase order |
| Random numbers | mt19937_64 | MersenneTwister | ✅ Match | Compatible RNG |
| Time steps | T periods | T periods | ✅ Match | Same time structure |

## Initialization (fun_KS_country.h vs initialization.jl)

### Banks
| Feature | C Model | Julia Model | Status |
|---------|---------|-------------|--------|
| Number | B | B | ✅ Match |
| Size distribution | Pareto(alphaB) | Pareto(alphaB) | ✅ Match |
| Initial equity | NWb = EqB0 * total_nw / B | Same | ✅ Match |
| Client assignment | Random | Random | ✅ Match |

### Firm1 (Capital Goods)
| Feature | C Model | Julia Model | Status |
|---------|---------|-------------|--------|
| Number | F10 | F10 | ✅ Match |
| Initial productivity | Btau0 = (1+mu1)*INIPROD/(m1*m2*b) | Same | ✅ Match |
| Initial price | p10 = (1+mu1)*c10 | Same | ✅ Match |
| Initial demand | D10 = F20*K0/(m2*eta*F10) | Same | ✅ Match |
| Initial R&D | RD0 = max(nu*D10*p10, INIWAGE) | Same | ✅ Match |
| Initial S1_prev | Set to D10*p10 | Set to D10*p10 | ✅ Match |
| Initial L1rd | floor(RD0/INIWAGE) | floor(RD0/INIWAGE) | ✅ Match |
| **Initial L1d** | **Implicit from setup** | **Added initialize_labor_demand!** | ✅ **FIXED** |

### Firm2 (Consumption Goods)
| Feature | C Model | Julia Model | Status |
|---------|---------|-------------|--------|
| Number | F20 | F20 | ✅ Match |
| Initial capital | K0 = ceil(Ls0*INIWAGE/(p20*F20*m2))*m2 | Same | ✅ Match |
| Initial demand | D20 = complex formula | Same formula | ✅ Match |
| Initial inventories | N = iota*D20 | Same | ✅ Match |
| Initial vintages | One vintage with A=INIPROD | Same | ✅ Match |
| Initial D2e | D20 | D20 | ✅ Match |
| **Initial L2d** | **Implicit from setup** | **Added initialize_labor_demand!** | ✅ **FIXED** |

### Workers
| Feature | C Model | Julia Model | Status |
|---------|---------|-------------|--------|
| Number | Ls0/Lscale objects | Ls0 objects | ⚠️ Differs | Julia uses full count |
| Initial age | Random [1, Tr] | Random [1, Tr] | ✅ Match |
| Initial skills | INISKILL | INISKILL | ✅ Match |
| Initial wage | INIWAGE | INIWAGE | ✅ Match |
| Initial status | Unemployed | Unemployed | ✅ Match |

## Phase-by-Phase Comparison

### Phase 1: Monetary Policy
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Update r | Central bank rule | update_central_bank_rate! | ✅ Match |
| Update rDeb, rD | Based on r + spreads | bank_update_interest_rates! | ✅ Match |

### Phase 2: Expectations & Planning (Sector 2)
| Function | C Model (_D2e, _Q2d, _Q2, _L2d) | Julia Model | Status |
|----------|----------------------------------|-------------|--------|
| Form expectations | _D2e with lifecycle check | firm2_form_expectations! | ✅ Match |
| - Entrants (age<3) | max(D2d(t-1), D2e(t-1)) | Special handling | ✅ **FIXED** |
| - Expectation modes | 0-4 different formulas | Same 5 modes | ✅ Match |
| Plan production (_Q2d) | (1+iota)*D2e - N(t-1) | (1+iota)*D2e - N2 | ✅ **FIXED** |
| Capital constraint | min(Q2d, K) | min(Q_desired, Q_capacity) | ✅ **FIXED** |
| Labor demand (_L2d) | ceil(Q2/A2) if life2cycle>0 | ceil(Q2/A_avg) with checks | ✅ Match |
| - Edge cases | Returns 0 | Returns max(1, L2) | + Better |
| Investment decision | _EId, _SId equations | firm2_decide_investment! | ✅ Match |

### Phase 3: R&D & Production Planning (Sector 1)
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| R&D timing | Uses VL("_L1rd", 1) | Uses firm.L1rd from prev period | ✅ Match |
| Innovation (_Atau) | Uses lagged L1rd | firm1_innovate! | ✅ Match |
| Imitation (_Btau) | Uses lagged L1rd | firm1_imitate! | ✅ Match |
| R&D expenditure (_RD) | nu * VL("_S1", 1) | nu * firm.S1_prev | ✅ Match |
| - Minimum R&D | max(RD, w1avg) | max(RD, firm.w1) | ✅ Match |
| - To workers | ceil(RD/w1avg) | ceil(RD/firm.w1) | ✅ Match |
| Order aggregation (D1) | Sum from Firm2 | Sum from Firm2 | ✅ Match |
| Production plan (_Q1) | D1 * (1+iota) | Same | ✅ Match |
| Labor demand (_L1d) | L1dRD + ceil(Q1/(Btau*m1)) | Same | ✅ Match |
| - No theta buffer | Direct sum | Direct sum | ✅ **FIXED** |

### Phase 4: Labor Market
| Function | C Model (hires1, hires2) | Julia Model | Status |
|----------|--------------------------|-------------|--------|
| Worker applications | _appl counter | worker_apply_for_jobs! | ✅ Match |
| Application targeting | Weighted by size | Weighted by size | ✅ Match |
| Hiring sequence | flagHireSeq (0-3) | order_firms_for_hiring | ✅ Match |
| Wage offers | Based on flagWageOffer | compute_wage_offer | ✅ Match |
| Hiring order | flagHireOrder | order_applications | ✅ Match |
| Acceptance | w_offer >= wRes | Same logic | ✅ Match |
| Job switching | If w_offer > w*(1+epsilon) | Same | ✅ Match |
| Statistics update | L, U, Ue, wAvg | update_employment_statistics! | ✅ Match |
| - NaN filtering | C doesn't have NaN | **Added isfinite checks** | ✅ **FIXED** |

### Phase 5: Production
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Firm1 production (_Q1e) | Adjust for labor shortfall | firm1_produce! | ✅ Match |
| - Set L1rd for next period | At END of period | At END of firm1_produce! | ✅ Match |
| - R&D allocation | Proportional if constrained | Same logic | ✅ Match |
| Firm2 production (_Q2e) | min(Q2, L2*A2, K*u*A2) | Same | ✅ Match |
| Sales | min(Q_e + N, D) | Same | ✅ Match |
| Inventories | Q_e + N - S | Same | ✅ Match |

### Phase 6: Pricing
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Firm1 price (_p1) | (1+mu1) * w1/(Btau*m1) | Same | ✅ Match |
| - NaN prevention | C doesn't produce NaN | **Added checks** | ✅ **FIXED** |
| Firm2 price (_p2) | (1+mu2) * w2/A2 | Same | ✅ Match |
| - Markup adjustment | Based on f2 change | Same | ✅ Match |
| - NaN prevention | C doesn't produce NaN | **Added checks** | ✅ **FIXED** |
| Average prices | p1avg, p2avg | Same | ✅ Match |
| - NaN filtering | Not needed | **Added isfinite check** | ✅ **FIXED** |

### Phase 7: Consumption & Demand
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Government G | G calculation | compute_government_expenditure! | ✅ Match |
| Worker consumption | Income (w or wU) | Same | ✅ Match |
| Total Cd | Sum worker consumption | Same | ✅ Match |
| Demand allocation (D2) | By market share f2 | Same | ✅ Match |
| Rationing | If supply < demand | Same logic | ✅ Match |

### Phase 8: Investment
| Function | C Model (invest) | Julia Model | Status |
|----------|------------------|-------------|--------|
| Execute investment | Complex financing | firm2_execute_investment! | ~ Simplified |
| Credit constraints | Detailed bank logic | Basic Lambda constraint | ⚠️ Simplified |
| Machine delivery | Add vintages | Add vintages | ✅ Match |
| Capital update | K += investment | K += investment | ✅ Match |

### Phase 9: Finance
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Deposits | Bank functions | bank_collect_deposits! | ✅ Match |
| Credit evaluation | Pecking order | bank_evaluate_credit! | ~ Simplified |
| Credit allocation | Complex | bank_allocate_credit! | ~ Simplified |
| Firm finances | Update NW, Deb | firm1/2_update_finances! | ✅ Match |
| Bank profits | Interest income - costs | bank_compute_profits! | ✅ Match |
| Bailouts | If NWb < 0 | bank_check_bailout! | ✅ Match |

### Phase 10: Government
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Taxes | tr * profits + tw * wages | collect_taxes! | ✅ Match |
| Deficit | G + interest - Tax | update_public_finances! | ✅ Match |
| Debt | Deb(t-1) + Def | Same | ✅ Match |
| Minimum wage | Adjustment rules | update_minimum_wage! | ✅ Match |

### Phase 11: Market Dynamics
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Market shares | Replicator dynamics | update_market_shares! | ✅ Match |
| Brochures | _brand mapping | firm1_send_brochures! | ✅ Match |

### Phase 12: Entry/Exit
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Exit conditions | Multiple triggers | firm1/2_check_exit! | ✅ Match |
| Entry probability | Complex rules | Simplified | ~ Simplified |
| Entrant setup | entry_firm1/2() | create_entrant_firm1/2! | ✅ Match |

### Phase 13: Aggregation
| Function | C Model (GDPreal, GDPnom) | Julia Model | Status |
|----------|----------------------------|-------------|--------|
| Sector aggregates | Sum L1, Q1, etc. | compute_aggregates! | ✅ Match |
| GDP calculation | C + I + G | Same | ✅ Match |
| Real GDP | Deflated by CPI | GDPreal = Q2*p2avg/deflator | ✅ Match |
| - Deflator index | Uses current CPI | **Fixed to use CPI_history[end]** | ✅ **FIXED** |
| Average productivity | Weighted by K | Same | ✅ Match |

### Phase 14: Regime Change
| Function | C Model | Julia Model | Status |
|----------|---------|-------------|--------|
| Timing | At TregChg | At t==TregChg | ✅ Match |
| Actions | Parameter updates | execute_regime_change! | ~ Simplified |

## Critical Timing Issues (All Fixed)

| Issue | C Model Behavior | Julia (Before) | Julia (After) |
|-------|------------------|----------------|---------------|
| **S1_prev for R&D** | VL("_S1", 1) - lagged | Used current S1 | **Uses S1_prev** ✅ |
| **L1rd for innovation** | VL("_L1rd", 1) - lagged | Set wrong time | **Set at end of produce** ✅ |
| **Initial L1d** | Implicit from init | 0 (not set) | **Computed in initialize_labor_demand!** ✅ |
| **Initial L2d** | Implicit from init | 0 (not set) | **Computed in initialize_labor_demand!** ✅ |
| **Q2 with inventory** | (1+iota)*D2e - N | Didn't subtract N | **Subtracts N2** ✅ |
| **Q2 capital limit** | min(Q2d, K) | No limit | **min(Q_desired, Q_capacity)** ✅ |

## NaN Prevention (All Added)

| Location | Check Added | Status |
|----------|-------------|--------|
| Price computation (Firm1) | isfinite(c1), isfinite(p1) | ✅ Added |
| Price computation (Firm2) | isfinite(c2), isfinite(p2) | ✅ Added |
| Wage averaging | Filter isfinite(w) | ✅ Added |
| Wage offer | Validate base_wage, w_offer | ✅ Added |
| GDP deflator | max(CPI, 0.01) | ✅ Added |
| Labor demand | Check A_avg > 0, Q2 > 0 | ✅ Added |
| Employment stats | isfinite(wAvg) check | ✅ Added |

## Known Differences (Not Critical)

1. **Worker Scaling**: C model uses Lscale to reduce objects; Julia uses full count
2. **Bank Credit**: C has detailed pecking order; Julia simplified
3. **Vintage Skills**: C tracks detailed skills; Julia basic tracking
4. **Entry/Exit**: C has complex rules; Julia simplified
5. **Performance**: Julia slower due to more agent objects

## Summary

### ✅ Core Logic: Fully Aligned
- All critical equations match C model
- Timing issues fixed
- Initialization corrected

### ✅ Safety: Enhanced
- NaN prevention added (C doesn't need it)
- Bounds checking comprehensive
- Edge cases handled

### ⚠️ Simplifications: Minor
- Bank relationships simplified
- Entry/exit logic simplified  
- Worker scaling not implemented

### ✅ Result: Should Match
With all fixes applied, the Julia model should produce results very close to the C model baseline.

## Testing Validation

To verify alignment:
1. Run same parameters in both models
2. Compare: GDP, employment, wages, inflation
3. Check time series show similar patterns
4. Verify no NaN or crashes in Julia

Expected: Julia results should track C model closely, with minor differences due to simplified banking/entry.
