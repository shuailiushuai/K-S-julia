# Critical Fixes Summary for K+S Julia Model

## Issue Analysis

The Julia model had a **critical initialization and calculation order bug** that caused:
- NaN values for GDP, wages, and other aggregate variables
- 100% unemployment (0 employment)
- `InexactError: Int64(NaN)` crash in `firm1_produce!` at line 163

## Root Causes Identified

### 1. **R&D Labor Calculation Using Wrong Time Period (CRITICAL)**

**Problem**: The R&D labor demand was calculated using CURRENT period sales `S1` instead of LAGGED sales `S1_prev`.

**C Model** (`fun_KS_firm1.h` line ~336):
```c
v[1] = VL( "_S1", 1 );  // sales in previous period (LAG 1)
if ( v[1] > 0 )
    v[0] = v[2] * v[1];  // R&D = nu * S1(t-1)
else
    v[0] = min( CURRENT, v[2] * VL( "_NW1", 1 ) );  // Use net worth if no sales
```

**Julia Model Before Fix** (`firm1_behavior.jl`):
```julia
revenue = firm.S1 * firm.p1  # WRONG: Uses current period S1
L_rd = min(params.nu * revenue / firm.w1, params.L1rdMax * L_prod)
```

**Impact**: 
- In the first period, `S1` is 0 before `firm1_produce!` is called
- This makes `L_rd = 0`, then `L1d = L_prod + 0`
- When `L1d` is 0 or NaN, the calculation `firm.L1rd * firm.L1 / max(1, firm.L1d)` can produce NaN
- `floor(Int, NaN)` throws `InexactError`

**Julia Model After Fix**:
```julia
# Added S1_prev field to Firm1 struct
if firm.S1_prev > 0
    RD = params.nu * firm.S1_prev  # Use lagged sales
else
    RD = params.nu * firm.NW1  # Fallback to net worth
end
RD = max(RD, firm.w1)  # Minimum constraint
L_rd = ceil(RD / firm.w1)
```

### 2. **Labor Demand Calculation Missing Safety Checks**

**Problem**: Division by zero and NaN propagation when `L1d` or `firm.B` are 0 or NaN.

**C Model** (`fun_KS_firm1.h` line ~420):
```c
v[5] = v[2] > v[4] ? 1 - ( v[1] - v[3] ) / ( v[2] - v[4] ) : 1;
```

**Julia Model Before Fix**:
```julia
L_prod_actual = firm.L1 - floor(Int, firm.L1rd * firm.L1 / max(1, firm.L1d))
# Problem: If L1d is NaN, this produces NaN, then floor(Int, NaN) crashes
```

**Julia Model After Fix**:
```julia
if firm.L1 >= firm.L1d || firm.L1d <= 0
    firm.Q1e = firm.Q1  # No adjustment needed
else
    # Safe calculation with explicit checks
    if firm.L1d > 0
        L_rd_actual = min(firm.L1rd, firm.L1 * firm.L1rd / firm.L1d)
    else
        L_rd_actual = 0.0
    end
    L_prod_actual = max(0.0, firm.L1 - L_rd_actual)
    # ... rest of calculation
end
```

### 3. **Incorrect Labor Buffer in Labor Demand**

**Problem**: Julia model added `theta` buffer to labor demand, but C model doesn't use it.

**C Model** (`fun_KS_firm1.h` line ~394):
```c
EQUATION( "_L1d" )
RESULT( V( "_L1dRD" ) + ceil( V( "_Q1" ) / ( V( "_Btau" ) * VS( PARENT, "m1" ) ) ) )
// No theta buffer!
```

**Julia Model Before Fix**:
```julia
firm.L1d = (L_prod + L_rd) * (1 + params.theta)  # WRONG
```

**Julia Model After Fix**:
```julia
firm.L1d = L_prod + L_rd  # Correct - no buffer
```

Same issue existed in `firm2_compute_labor_demand!` - also fixed.

### 4. **Missing Previous Period Sales Tracking**

**Problem**: Julia model had no mechanism to track lagged variables like `S1(t-1)`.

**Solution**: Added `S1_prev::Float64` field to `Firm1` struct and updated it in `agent_step!`:
```julia
function agent_step!(agent::Firm1, model)
    agent.age += 1
    agent.S1_prev = agent.S1  # Save previous period sales
    # ...
end
```

### 5. **Incomplete Initialization**

**Problem**: Firms were created with `S1 = 0.0`, which meant the first R&D calculation had no basis.

**Solution**: Initialize firms with expected initial sales:
```julia
S1 = D10 * p10,  # Expected initial sales
S1_prev = D10 * p10,  # For R&D calculation
```

## Files Modified

1. **types.jl**
   - Added `S1_prev::Float64` field to `Firm1` struct

2. **firm1_behavior.jl**
   - Fixed `firm1_compute_labor_demand!` to use `S1_prev` instead of `S1`
   - Added minimum R&D constraint (`max(RD, firm.w1)`)
   - Fixed `firm1_produce!` to avoid `floor(Int, NaN)` error
   - Added safety checks for division by zero

3. **firm2_behavior.jl**
   - Removed incorrect `theta` buffer from `firm2_compute_labor_demand!`

4. **scheduling.jl**
   - Updated `agent_step!(agent::Firm1, model)` to save `S1_prev`
   - Updated `create_entrant_firm1!` to initialize `S1` and `S1_prev`

5. **initialization.jl**
   - Initialize `S1` and `S1_prev` for all Firm1 agents

## Comparison with C Model

### Correct Lag Variable Usage

| Variable | C Model | Julia Model (Fixed) |
|----------|---------|-------------------|
| R&D Sales Base | `VL("_S1", 1)` | `firm.S1_prev` |
| R&D Fallback | `VL("_NW1", 1)` | `firm.NW1` |
| Minimum R&D | `VLS(PARENT, "w1avg", 1)` | `firm.w1` |

### Labor Demand Equations

| Sector | C Model | Julia Model (Fixed) |
|--------|---------|-------------------|
| Firm1 | `_L1dRD + ceil(_Q1 / (_Btau * m1))` | `L_rd + ceil(Q1 / (B * m1))` |
| Firm2 | `ceil(_Q2 / _A2)` | `ceil(Q2 / A_avg)` |
| Buffer | **None** | **None** (removed) |

### Production Adjustment Factor

C Model calculates adjustment when labor is short:
```c
v[5] = v[2] > v[4] ? 1 - (v[1] - v[3]) / (v[2] - v[4]) : 1;
```

Where:
- `v[1]` = actual labor
- `v[2]` = total labor demand
- `v[3]` = actual R&D workers
- `v[4]` = desired R&D workers

Julia equivalent (fixed):
```julia
L_rd_actual = min(firm.L1rd, firm.L1 * firm.L1rd / firm.L1d)
L_prod_actual = max(0.0, firm.L1 - L_rd_actual)
adjustment_factor = L_prod_actual / L_prod_desired
```

## Testing Requirements

To verify the fixes work:

1. **Initialization Test**: Check that firms have valid initial values
   - `S1 > 0` and `S1_prev > 0` for all Firm1
   - `L1d > 0` after initialization
   - `L1rd >= 1` (minimum R&D workers)

2. **First Period Test**: Check that first step completes without errors
   - No `InexactError` in `firm1_produce!`
   - Employment > 0 after labor market matching
   - GDP > 0 and not NaN

3. **Steady State Test**: Run for 50-100 periods and check:
   - Unemployment rate < 100%
   - GDP growth is finite and reasonable
   - All aggregate variables are non-NaN

## Expected Outcomes After Fixes

- ✓ Model should initialize without errors
- ✓ First time step should complete successfully
- ✓ Workers should be hired (employment > 0)
- ✓ GDP and other aggregates should have valid values (not NaN)
- ✓ Simulation should run for full 200 periods without crashes
- ✓ Unemployment should be realistic (not 100%)

## Remaining Known Issues

While the critical NaN errors are fixed, there may still be calibration issues:
- Market matching efficiency
- Initial parameter values
- Wage adjustment dynamics
- Investment/credit constraints

These would require comparison of simulation results with the C model's output to fine-tune.
