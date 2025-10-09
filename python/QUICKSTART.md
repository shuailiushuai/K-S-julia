# K+S Model Quick Start Guide

## Installation (5 minutes)

```bash
# Navigate to python directory
cd python/

# Install dependencies
pip install -r requirements.txt
```

## Run Your First Simulation (30 seconds)

```bash
# Run baseline simulation with visualization
python run_simulation.py
```

This will:
- Run 100 time steps
- Print summary statistics
- Generate 6 plots showing GDP, unemployment, inflation, etc.
- Export results to CSV

## Try Different Scenarios (2 minutes)

```bash
# Run 4 different scenarios and compare
python examples.py
```

This demonstrates:
- Baseline scenario
- High innovation scenario
- Flexible labor market
- Tight credit conditions
- Parameter sensitivity analysis

## Validate Implementation (1 minute)

```bash
# Check implementation completeness
python validate.py
```

This validates:
- Agent class structure
- Model components
- Scheduling sequence
- Parameter coverage
- Critical equations

## Custom Simulation (Python)

```python
from model import KSModel

# Create model with custom parameters
model = KSModel(
    F10=20,              # Capital-good firms
    F20=100,             # Consumption-good firms
    Ls0=1000,            # Workers
    B=10,                # Banks
    nu=0.15,             # Higher R&D (vs 0.1 default)
    Lambda=2.0,          # Credit multiple
    flagExpect=1,        # Expectation mode
    seed=42              # Random seed
)

# Run simulation
for i in range(100):
    model.step()
    
# Get results
results = model.datacollector.get_model_vars_dataframe()
print(results.head())

# Access final values
print(f"Final GDP: {model.GDPreal:.2f}")
print(f"Unemployment: {model.Ue:.2%}")
print(f"Inflation: {model.dCPI:.2%}")
```

## Key Parameters to Experiment With

### Innovation & Technology
- `nu` (0.05-0.20): R&D investment share
- `zeta1` (1.0-2.5): Innovation success rate
- `xi` (0.3-0.7): Innovation vs imitation share

### Labor Market
- `omega` (2-8): Job applications per worker
- `phi` (0.3-0.7): Unemployment benefit rate
- `flagFireRule` (0-5): Firing rule strictness

### Financial System
- `Lambda` (1.0-3.0): Credit multiple
- `tauB` (0.05-0.15): Bank capital requirement
- `flagCreditRule` (0-2): Credit constraint type

### Firm Behavior
- `flagExpect` (0-4): Demand expectation mode
- `mu1`, `mu20`: Initial markups
- `chi` (0.5-2.0): Market share dynamics speed

## Documentation Files

- **README.md**: Complete usage guide and reference
- **PSEUDOCODE.md**: Detailed algorithm documentation
- **CROSS_CHECK.md**: C++ vs Python comparison
- **SUMMARY.md**: Project completion report

## Need Help?

1. Check README.md for detailed documentation
2. Look at examples.py for usage patterns
3. Read PSEUDOCODE.md for algorithm details
4. Review CROSS_CHECK.md for implementation verification

## Common Issues

**Import Error**: Install Mesa with `pip install mesa>=3.0.0`
**Slow Performance**: Reduce number of agents (F10, F20, Ls0)
**Memory Error**: Reduce simulation steps or agent count
**Plot Not Showing**: Ensure matplotlib backend is configured

## Next Steps

1. ✓ Run baseline simulation
2. ✓ Try example scenarios
3. ✓ Modify parameters
4. → Design your own experiments
5. → Analyze results
6. → Publish findings!

## Performance Tips

- Start with small agent counts for testing
- Use `seed` parameter for reproducibility
- Save results to CSV for analysis
- Profile with cProfile if slow

## Citation

If you use this implementation in research:

```bibtex
@software{ks_mesa_2024,
  title={K+S Agent-Based Model: Python/Mesa Implementation},
  author={Based on Pereira, Marcelo C.},
  year={2024},
  note={Python reproduction of K+S model},
  url={https://github.com/shuailiushuai/K-S-julia}
}
```

Original papers:
- Dosi et al. (2010) JEDC
- Dosi et al. (2015) JEDC
- Dosi et al. (2017, 2018, 2019, 2020) Various

---

**Ready to go? Start with `python run_simulation.py`!** 🚀
