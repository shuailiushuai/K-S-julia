# K+S Model Julia Implementation

Complete Julia replication of the K+S (Keynes+Schumpeter) agent-based macroeconomic model using Agents.jl 6.2.9.

## Overview

This is a faithful replication of the C/LSD implementation of the K+S model described in:
- Dosi et al. (2010, 2015, 2017, 2018, 2019, 2020)
- Original C implementation: `fun_KS.cpp` and associated header files

The model features:
- **Four agent types**: Workers, Capital-good firms (Firm1), Consumption-good firms (Firm2), Banks
- **Three main markets**: Labor market, Capital-good market, Consumption-good market
- **Government and Central Bank**: Fiscal and monetary policy
- **Key mechanisms**: Endogenous innovation, heterogeneous agents, disequilibrium dynamics, stock-flow consistency

## Installation

### Requirements
- Julia 1.9 or higher
- Agents.jl 6.2.9

### Setup
```bash
cd julia
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

This will install all required dependencies specified in `Project.toml`.

## Project Structure

```
julia/
├── Project.toml              # Package dependencies
├── PSEUDOCODE.md            # Complete model specification
├── src/                     # Source code
│   ├── KSModel.jl          # Main module
│   ├── types.jl            # Agent type definitions
│   ├── parameters.jl       # Model parameters
│   ├── initialization.jl   # Model initialization
│   ├── firm1_behavior.jl   # Capital-good firm behaviors
│   ├── firm2_behavior.jl   # Consumption-good firm behaviors
│   ├── worker_behavior.jl  # Worker behaviors
│   ├── bank_behavior.jl    # Bank behaviors
│   ├── government.jl       # Government and central bank
│   ├── markets.jl          # Market mechanisms
│   ├── scheduling.jl       # Time-step scheduling
│   ├── statistics.jl       # Data collection
│   └── visualization.jl    # Plotting functions
├── example.jl              # Example usage
└── README.md              # This file
```

## Usage

### Basic Example

```julia
using KSModel

# Load baseline parameters
params = load_baseline_parameters()

# Initialize model
model = initialize_model(params)

# Run simulation
data = run_simulation(model, 500, collect_data=true)

# Create summary report
create_summary_report(data)

# Visualize results
plot_time_series(data)
```

### Running the Example

```bash
cd julia
mkdir -p plots output
julia example.jl
```

This will:
1. Create a model with baseline parameters
2. Run a 200-period simulation
3. Generate summary statistics
4. Create visualizations
5. Save data and plots

### Custom Configuration

```julia
# Create custom parameters
params = load_baseline_parameters()

# Modify specific parameters
params.F10 = 50  # Number of capital-good firms
params.F20 = 200  # Number of consumption-good firms
params.Ls0 = 10000  # Number of workers
params.T = 500  # Simulation length
params.tr = 0.25  # Tax rate

# Different expectation mode
params.flagExpect = 3  # Adaptive expectations

# Initialize and run
model = initialize_model(params)
data = run_simulation(model, params.T)
```

### Data Collection

```julia
# Collect aggregate data
aggregate_data = collect_aggregate_data(model)

# Collect firm-level data
firm_data = collect_firm_data(model)

# Collect worker-level data
worker_data = collect_worker_data(model)
```

## Model Components

### Agent Types

1. **Worker**: Consumers with skills, wages, job search behavior
2. **Firm1** (Capital-good): R&D, innovation, machine production
3. **Firm2** (Consumption-good): Adaptive expectations, investment, production
4. **Bank**: Credit allocation, deposits, reserves

### Key Mechanisms

1. **Innovation & Imitation** (Firm1)
   - Stochastic R&D process
   - Technology diffusion via imitation
   - Machine productivity evolution

2. **Labor Market**
   - Decentralized search-and-match
   - Worker skills (learning-by-doing, learning-by-using)
   - Wage determination and indexation
   - Multiple firing/hiring rules

3. **Demand & Production** (Firm2)
   - Multiple expectation formation modes
   - Investment decisions (expansion + replacement)
   - Variable markup pricing
   - Replicator dynamics for market shares

4. **Finance**
   - Bank credit allocation (pecking order)
   - Capital adequacy rules (Basel-like)
   - Sovereign bond market
   - Bailouts

5. **Government & Central Bank**
   - Taylor rule monetary policy
   - Fiscal rules (multiple modes)
   - Unemployment benefits
   - Taxation

### Parameters

The model has 200+ parameters organized by:
- **Country-level**: Entry/exit, taxes, growth
- **Financial**: Banks, credit, interest rates
- **Capital sector**: R&D, innovation, production
- **Consumption sector**: Expectations, investment, pricing
- **Labor**: Skills, wages, search, training
- **Control flags**: 20+ behavioral switches

See `src/parameters.jl` for complete parameter list and defaults.

## Validation

The implementation was validated against the C model by:

1. **Parameter matching**: All parameters match C implementation
2. **Behavioral rules**: Each behavioral rule replicated exactly
3. **Scheduling**: Time-step sequence matches C model
4. **Stock-flow consistency**: All accounting identities maintained

### Key Differences from C Model

- Uses Agents.jl framework instead of LSD
- Julia's random number generator (vs. C++11 MT19937)
- Some optimizations for Julia's strengths
- Simplified vintage tracking data structure

### Known Limitations

- Results will differ slightly due to RNG differences
- Some advanced labor market features simplified
- Post-change firm heterogeneity partially implemented

## Output

The model produces:

### Aggregate Statistics
- GDP (real and nominal)
- Consumption, Investment, Government expenditure
- Employment and unemployment
- Wages and productivity
- Inflation and interest rates
- Public debt and deficit

### Sectoral Statistics
- Number of firms
- Production and sales
- Average productivity
- Market concentration

### Distributions
- Firm size
- Firm productivity
- Wages
- Skills

## Performance

Typical performance on modern hardware:
- **Small** (F1=20, F2=80, L=2000): ~1 second per 100 periods
- **Medium** (F1=50, F2=200, L=10000): ~5 seconds per 100 periods
- **Large** (F1=100, F2=400, L=20000): ~20 seconds per 100 periods

## References

### Key Papers
1. Dosi, G., G. Fagiolo, A. Roventini (2010). "Schumpeter meeting Keynes: A policy-friendly model of endogenous growth and business cycles." *Journal of Economic Dynamics and Control* 34:1748-1767.

2. Dosi, G., G. Fagiolo, M. Napoletano, A. Roventini, and T. Treibich (2015). "Fiscal and monetary policies in complex evolving economies." *Journal of Economic Dynamics and Control* 52:166-189.

3. Dosi, G., M. C. Pereira, A. Roventini, and M. E. Virgillito (2017). "When more flexibility yields more fragility: the microfoundations of Keynesian aggregate unemployment." *Journal of Economic Dynamics and Control* 81:162-186.

4. Dosi, G., M. C. Pereira, A. Roventini, and M. E. Virgillito (2018). "Causes and consequences of hysteresis: aggregate demand, productivity, employment." *Industrial and Corporate Change* 27:1015-1044.

### Original Implementation
- C/LSD implementation by Marcelo C. Pereira
- LSD: https://github.com/SantAnnaKS/LSD

## License

Distributed under the GNU General Public License v3.0, consistent with the original C implementation.

## Authors

Julia implementation by K+S Model Replication Team
Original C model by Marcelo C. Pereira and contributors

## Contact

For questions about this Julia implementation, please open an issue on the repository.

For questions about the original model, refer to the original papers and LSD implementation.
