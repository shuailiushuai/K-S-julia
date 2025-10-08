# K+S Model Julia Implementation - Quick Start Guide

## 🚀 Quick Start (5 minutes)

### 1. Installation
```bash
cd julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

### 2. Run Example
```bash
julia --project=. example.jl
```

### 3. View Results
- Check `plots/` folder for visualizations
- Check `output/` folder for data files
- See console for summary statistics

## 📊 Basic Usage

### Minimal Example
```julia
using KSModel

# Create model with default parameters
model = initialize_model()

# Run for 100 periods
data = run_simulation(model, 100, collect_data=true)

# View summary
create_summary_report(data)
```

### Custom Parameters
```julia
# Load baseline parameters
params = load_baseline_parameters()

# Adjust as needed
params.F10 = 30         # Capital-good firms
params.F20 = 120        # Consumption-good firms
params.Ls0 = 5000       # Workers
params.tr = 0.25        # Tax rate
params.flagExpect = 3   # Adaptive expectations

# Create and run
model = initialize_model(params)
data = run_simulation(model, 500)
```

## 🎯 Key Features

### Agent Types
- **Worker**: Job search, skills, consumption
- **Firm1**: R&D, innovation, machine production
- **Firm2**: Expectations, investment, goods production
- **Bank**: Credit allocation, reserves management

### Markets
- **Labor**: Search-and-match, hiring/firing
- **Capital**: Machine orders, technology diffusion
- **Consumption**: Market shares, replicator dynamics

### Policies
- **Monetary**: Taylor rule, interest rate structure
- **Fiscal**: Multiple rules, taxation, expenditure

## 📈 Output Variables

### Macroeconomic
- `GDP`, `C`, `I`, `G`: National accounts
- `Ue`: Unemployment rate
- `wAvg`: Average wage
- `inflation`: Inflation rate
- `r`: Interest rate

### Sectoral
- `F1`, `F2`: Number of firms
- `A1`, `A2`: Average productivity
- `L1`, `L2`: Employment by sector

## 🔧 Configuration Flags

### Expectations (`flagExpect`)
- 0: Myopic (1-period)
- 1: Myopic (4-period weighted)
- 2: Accelerating growth
- 3: Adaptive
- 4: Extrapolative-accelerating

### Labor Search (`flagSearchMode`)
- 0: Always search
- 1: Only if unemployed
- 2: If unemployed or wage below average

### Fiscal Policy (`flagFiscalRule`)
- 0: No rule
- 1: Deficit rule
- 2: Soft deficit rule
- 3: Debt and deficit rule
- 4: Soft debt and deficit rule

## 📚 Documentation

- **README.md**: Full user guide
- **PSEUDOCODE.md**: Complete model specification
- **VERIFICATION.md**: Implementation checklist
- **SUMMARY.md**: Project overview

## 🐛 Troubleshooting

### Package Installation Issues
```bash
julia --project=. -e 'using Pkg; Pkg.update(); Pkg.instantiate()'
```

### Out of Memory
Reduce model size:
```julia
params.F10 = 10   # Fewer firms
params.F20 = 40
params.Ls0 = 1000  # Fewer workers
```

### Slow Execution
- Reduce simulation length: `params.T = 100`
- Disable data collection: `run_simulation(model, 100, collect_data=false)`

## 📖 References

### Key Papers
1. Dosi et al. (2010) JEDC - Original model
2. Dosi et al. (2015) JEDC - Policy analysis
3. Dosi et al. (2017, 2018, 2019, 2020) - Extensions

### Original Implementation
- C/LSD by Marcelo C. Pereira
- https://github.com/SantAnnaKS/LSD

## 💡 Tips

1. **Start Small**: Begin with small model (F10=10, F20=40, Ls0=500)
2. **Check Output**: Monitor console for progress and any warnings
3. **Save Often**: Data collection is automatic but save important results
4. **Experiment**: Try different flags and parameters
5. **Compare**: Run multiple scenarios and compare results

## 🎓 Learning Path

### Beginner
1. Run `example.jl` with defaults
2. Modify basic parameters (firm counts, worker counts)
3. Try different expectation modes

### Intermediate
1. Experiment with policy rules (fiscal, monetary)
2. Analyze firm and worker level data
3. Create custom visualizations

### Advanced
1. Modify behavioral rules
2. Add new mechanisms
3. Conduct policy experiments
4. Compare with empirical data

## 🔗 Quick Links

- **Agents.jl Documentation**: https://juliadynamics.github.io/Agents.jl/stable/
- **Julia Documentation**: https://docs.julialang.org/
- **LSD (Original)**: https://github.com/SantAnnaKS/LSD

## ✨ Example Output

After running `example.jl`, you'll get:

```
K+S MODEL SIMULATION SUMMARY
============================================================

Simulation Period: t = 1 to 200

MACROECONOMIC AGGREGATES (Final Period)
------------------------------------------------------------
GDP:                 12345.67
Consumption:         8901.23
Investment:          2345.67
Government:          1098.77

LABOR MARKET
------------------------------------------------------------
Employment:          1850
Unemployment Rate:   7.50%
Average Wage:        1.23

PRODUCTIVITY
------------------------------------------------------------
Sector 1:            1.450
Sector 2:            1.380

...
```

Plus plots showing:
- GDP growth over time
- Unemployment dynamics
- Productivity evolution
- Sectoral firm counts
- Financial variables

## 🎯 Next Steps

1. ✅ Installation complete
2. ✅ Example running
3. 📊 Analyze your results
4. 🔧 Try custom configurations
5. 📈 Run policy experiments
6. 📝 Document your findings

Happy modeling! 🚀
