# K+S Agent-Based Model - Python/Mesa 3.0 Implementation

## Overview

This is a complete Python reproduction of the K+S (Keynes meets Schumpeter) agent-based macroeconomic model using Mesa 3.0 framework. The original model was implemented in C++/LSD by Marcelo C. Pereira, University of Campinas.

## Model Description

The K+S model is a general disequilibrium, stock-and-flow consistent, agent-based model with heterogeneous agents operating in interconnected markets:

### Agent Types

1. **Workers/Consumers** - Search for jobs, earn wages, consume goods, update skills
2. **Capital-Good Firms (Firm1)** - Invest in R&D, produce heterogeneous machines
3. **Consumption-Good Firms (Firm2)** - Produce consumer goods using machines and labor
4. **Banks** - Take deposits, provide loans, manage reserves
5. **Central Bank** - Sets interest rates via Taylor rule
6. **Government** - Taxes, unemployment benefits, fiscal policy

### Key Features

- **Endogenous innovation** via R&D in capital-good sector
- **Heterogeneous firms** with different technologies and strategies
- **Adaptive expectations** for demand formation
- **Labor market** with job search, hiring/firing rules
- **Financial sector** with bank lending, credit rationing
- **Replicator dynamics** for market share evolution
- **Stock-flow consistency** throughout the model
- **Entry and exit** of firms based on performance
- **Regime changes** at specified times

## File Structure

```
python/
├── PSEUDOCODE.md          # Complete pseudocode documentation
├── agents.py              # Worker, Firm base, Firm1 classes
├── agents_extended.py     # Firm2, Bank classes
├── model.py               # Main KSModel class
├── run_simulation.py      # Simulation runner and visualization
├── README.md              # This file
└── requirements.txt       # Python dependencies
```

## Installation

### Requirements

- Python 3.8 or higher
- Mesa 3.0
- NumPy
- Pandas
- Matplotlib

### Install Dependencies

```bash
pip install -r requirements.txt
```

## Usage

### Basic Simulation

```python
from model import KSModel

# Create model with default parameters
model = KSModel(
    F10=20,      # Capital-good firms
    F20=100,     # Consumption-good firms
    Ls0=1000,    # Workers
    B=10,        # Banks
    seed=42      # Random seed
)

# Run for 100 time steps
for i in range(100):
    model.step()
    
# Access results
results = model.datacollector.get_model_vars_dataframe()
```

### Run with Visualization

```bash
python run_simulation.py
```

This will:
1. Run the simulation for 100 time steps
2. Print summary statistics
3. Generate visualization plots
4. Export results to CSV

### Custom Parameters

```python
from model import KSModel

model = KSModel(
    # Labor parameters
    Ls0=2000,              # More workers
    omega=5,               # More job applications
    phi=0.6,               # Higher unemployment benefits
    
    # Firm parameters
    F10=30,                # More capital-good firms
    F20=150,               # More consumption-good firms
    nu=0.15,               # Higher R&D investment
    
    # Financial parameters
    Lambda=2.5,            # Higher credit multiple
    tauB=0.10,             # Stricter capital requirements
    
    # Control flags
    flagExpect=1,          # Different expectation mode
    flagFireRule=4,        # American firing rule
    
    seed=123
)
```

## Parameters

### Main Parameter Categories

1. **Country-level**: Tax rates, regime change, entry dynamics
2. **Financial**: Banks, credit rules, interest rates, fiscal policy
3. **Capital Sector (Firm1)**: R&D, innovation, production
4. **Consumption Sector (Firm2)**: Production, pricing, investment
5. **Labor Market**: Job search, hiring/firing, wages, skills
6. **Control Flags**: Behavioral modes and rules

See `PSEUDOCODE.md` for complete parameter list and descriptions.

## Model Scheduling

Each time step follows this sequence:

1. Regime change check (if applicable)
2. Central bank sets interest rate
3. Firm2: Form expectations, plan production
4. Firm1: R&D, receive orders, plan production
5. Workers: Apply for jobs
6. Firms: Hire/fire workers
7. Production (both sectors)
8. Price setting
9. Government expenditure decision
10. Consumption market matching
11. Update competitiveness and market shares
12. Compute financial results
13. Credit market operations
14. Government finances
15. Bank reserve management
16. Bailouts (if needed)
17. Entry and exit
18. Worker aging and skill updates
19. Statistics collection

## Validation

The implementation follows the C++/LSD original as closely as possible:

- Same agent structures and attributes
- Same behavioral equations
- Same scheduling sequence
- Compatible parameter sets
- Stock-flow consistency maintained

Key differences:
- Mesa 3.0 framework instead of LSD
- Python instead of C++
- Some simplifications in complex edge cases
- Different random number generator (but seeded)

## Output and Visualization

### Standard Outputs

1. **Time series plots**: GDP, unemployment, inflation, wages, etc.
2. **Firm dynamics**: Number of firms, market concentration
3. **Financial indicators**: Interest rates, public debt
4. **Summary statistics**: Means, growth rates, volatilities

### Data Export

Results are exported to CSV with columns:
- GDP (real)
- Unemployment rate
- Inflation rate
- Number of firms (by sector)
- Average wages
- Interest rate
- Public debt

## Extending the Model

### Adding New Agents

```python
from agents import Firm

class NewAgentType(Firm):
    def __init__(self, unique_id, model):
        super().__init__(unique_id, model)
        # Add custom attributes
        
    def step(self):
        # Define behavior
        pass
```

### Modifying Behaviors

Edit the relevant method in the agent classes:
- `agents.py` for Worker, Firm1
- `agents_extended.py` for Firm2, Bank
- `model.py` for model-level operations

### Custom Statistics

Add to datacollector in `model.py`:

```python
self.datacollector = mesa.DataCollector(
    model_reporters={
        "Custom_Stat": lambda m: m.calculate_custom_stat(),
    }
)
```

## Performance

### Typical Performance
- 100 steps with 20 Firm1, 100 Firm2, 1000 Workers: ~10-30 seconds
- Memory usage: ~100-500 MB

### Optimization Tips
1. Reduce number of agents for faster runs
2. Use `Lscale` parameter to scale worker population
3. Disable detailed tracking if not needed
4. Use vectorized operations where possible

## Known Limitations

1. Some complex financial market features simplified
2. Skill learning mechanics simplified from C++ version
3. Entry dynamics less sophisticated than full model
4. No multi-country support yet
5. Visualization limited to basic time series

## References

### Original Papers

- Dosi, G., Fagiolo, G., Roventini, A. (2010). Schumpeter meeting Keynes. JEDC 34:1748-1767.
- Dosi, G., et al. (2015). Fiscal and monetary policies in complex evolving economies. JEDC 52:166-189.
- Dosi, G., et al. (2017). When more flexibility yields more fragility. JEDC 81:162-186.
- Dosi, G., et al. (2018). Causes and consequences of hysteresis. ICC 27:1015-1044.
- Dosi, G., et al. (2019). What if supply-side policies are not enough? JEBO 162:360-388.
- Dosi, G., et al. (2020). The impact of deunionization. ICC dtaa025.

### Original Implementation

Original C++/LSD code: `fun_KS*.cpp` and `fun_KS*.h` files in repository root.

## License

This implementation follows the original license:
- Original: Copyright Marcelo C. Pereira, GNU General Public License
- Python/Mesa version: GNU General Public License

## Contact

For questions about:
- Original model: Marcelo C. Pereira, University of Campinas
- Python implementation: See repository issues

## Changelog

### Version 1.0 (Initial Release)
- Complete agent classes (Worker, Firm1, Firm2, Bank)
- Full model scheduling implementation
- Basic visualization and statistics
- Parameter configuration
- Documentation and examples
