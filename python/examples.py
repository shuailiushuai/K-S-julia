"""
K+S Model Example Scenarios
============================

This script demonstrates different scenarios and experiments with the K+S model.
"""

import numpy as np
import matplotlib.pyplot as plt
from model import KSModel


def scenario_baseline(steps=100):
    """Baseline scenario with default parameters"""
    print("="*70)
    print("SCENARIO 1: BASELINE")
    print("="*70)
    
    model = KSModel(
        F10=20,
        F20=100,
        Ls0=1000,
        B=10,
        seed=42
    )
    
    print("Running baseline simulation...")
    for i in range(steps):
        model.step()
        if (i + 1) % 20 == 0:
            print(f"  Step {i+1}/{steps}")
    
    return model


def scenario_high_innovation(steps=100):
    """Scenario with higher R&D investment and innovation"""
    print("\n" + "="*70)
    print("SCENARIO 2: HIGH INNOVATION")
    print("="*70)
    
    model = KSModel(
        F10=20,
        F20=100,
        Ls0=1000,
        B=10,
        nu=0.15,  # Higher R&D investment (vs 0.1 baseline)
        zeta1=2.0,  # Higher innovation success (vs 1.5)
        x1sup=0.20,  # Larger innovation jumps (vs 0.15)
        seed=42
    )
    
    print("Running high innovation simulation...")
    for i in range(steps):
        model.step()
        if (i + 1) % 20 == 0:
            print(f"  Step {i+1}/{steps}")
    
    return model


def scenario_flexible_labor(steps=100):
    """Scenario with flexible labor market (low protection)"""
    print("\n" + "="*70)
    print("SCENARIO 3: FLEXIBLE LABOR MARKET")
    print("="*70)
    
    model = KSModel(
        F10=20,
        F20=100,
        Ls0=1000,
        B=10,
        flagFireRule=4,  # American firing rule (payback-based)
        phi=0.3,  # Lower unemployment benefits (vs 0.5)
        omega=5,  # More job applications (vs 3)
        seed=42
    )
    
    print("Running flexible labor simulation...")
    for i in range(steps):
        model.step()
        if (i + 1) % 20 == 0:
            print(f"  Step {i+1}/{steps}")
    
    return model


def scenario_tight_credit(steps=100):
    """Scenario with tighter credit constraints"""
    print("\n" + "="*70)
    print("SCENARIO 4: TIGHT CREDIT")
    print("="*70)
    
    model = KSModel(
        F10=20,
        F20=100,
        Ls0=1000,
        B=10,
        Lambda=1.5,  # Lower credit multiple (vs 2.0)
        tauB=0.10,  # Higher capital requirements (vs 0.08)
        flagCreditRule=2,  # Basel-like rules
        seed=42
    )
    
    print("Running tight credit simulation...")
    for i in range(steps):
        model.step()
        if (i + 1) % 20 == 0:
            print(f"  Step {i+1}/{steps}")
    
    return model


def compare_scenarios(models, labels, metric='GDP', save_path=None):
    """Compare multiple scenarios"""
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))
    fig.suptitle('K+S Model: Scenario Comparison', fontsize=16, fontweight='bold')
    
    metrics = [
        ('GDP', 'Real GDP'),
        ('Unemployment', 'Unemployment Rate'),
        ('Inflation', 'Inflation Rate'),
        ('Wages', 'Average Wages')
    ]
    
    for idx, (metric, title) in enumerate(metrics):
        ax = axes[idx // 2, idx % 2]
        
        for model, label in zip(models, labels):
            data = model.datacollector.get_model_vars_dataframe()
            if metric in data.columns:
                ax.plot(data[metric], label=label, linewidth=2)
        
        ax.set_title(title, fontweight='bold')
        ax.set_xlabel('Time')
        ax.set_ylabel(title)
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Format percentage axes
        if metric in ['Unemployment', 'Inflation']:
            ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: f'{y:.1%}'))
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"\nComparison figure saved to {save_path}")
    
    plt.show()
    
    return fig


def print_scenario_comparison(models, labels):
    """Print comparison statistics"""
    print("\n" + "="*70)
    print("SCENARIO COMPARISON STATISTICS")
    print("="*70)
    
    print(f"\n{'Scenario':<25} {'GDP Growth':>12} {'Avg Unempl':>12} {'Avg Inflat':>12}")
    print("-" * 70)
    
    for model, label in zip(models, labels):
        data = model.datacollector.get_model_vars_dataframe()
        
        gdp_growth = (data['GDP'].iloc[-1] / data['GDP'].iloc[0] - 1) * 100
        avg_unempl = data['Unemployment'].mean() * 100
        avg_inflat = data['Inflation'].mean() * 100
        
        print(f"{label:<25} {gdp_growth:>11.1f}% {avg_unempl:>11.1f}% {avg_inflat:>11.1f}%")
    
    print("-" * 70)


def run_parameter_sensitivity(param_name, param_values, steps=100):
    """Run sensitivity analysis on a parameter"""
    print("\n" + "="*70)
    print(f"PARAMETER SENSITIVITY: {param_name}")
    print("="*70)
    
    results = []
    
    for value in param_values:
        print(f"\nTesting {param_name} = {value}...")
        
        params = {
            'F10': 20,
            'F20': 100,
            'Ls0': 1000,
            'B': 10,
            'seed': 42,
            param_name: value
        }
        
        model = KSModel(**params)
        
        for i in range(steps):
            model.step()
        
        results.append(model)
    
    # Plot results
    fig, ax = plt.subplots(1, 1, figsize=(10, 6))
    
    for value, model in zip(param_values, results):
        data = model.datacollector.get_model_vars_dataframe()
        ax.plot(data['GDP'], label=f'{param_name}={value}', linewidth=2)
    
    ax.set_title(f'GDP Sensitivity to {param_name}', fontweight='bold')
    ax.set_xlabel('Time')
    ax.set_ylabel('Real GDP')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'python/sensitivity_{param_name}.png', dpi=300, bbox_inches='tight')
    print(f"\nSensitivity plot saved to python/sensitivity_{param_name}.png")
    plt.show()
    
    return results


def main():
    """Run example scenarios"""
    print("\n" + "="*70)
    print("K+S MODEL EXAMPLE SCENARIOS")
    print("Python/Mesa 3.0 Implementation")
    print("="*70)
    
    # Run scenarios
    steps = 100
    
    print("\n### Running Scenarios ###\n")
    
    model1 = scenario_baseline(steps)
    model2 = scenario_high_innovation(steps)
    model3 = scenario_flexible_labor(steps)
    model4 = scenario_tight_credit(steps)
    
    models = [model1, model2, model3, model4]
    labels = ['Baseline', 'High Innovation', 'Flexible Labor', 'Tight Credit']
    
    # Compare scenarios
    print("\n### Comparing Scenarios ###\n")
    print_scenario_comparison(models, labels)
    
    compare_scenarios(models, labels, save_path='python/scenario_comparison.png')
    
    # Parameter sensitivity
    print("\n### Parameter Sensitivity Analysis ###\n")
    
    print("\nTesting R&D investment parameter (nu)...")
    run_parameter_sensitivity('nu', [0.05, 0.10, 0.15, 0.20], steps=100)
    
    print("\n### Analysis Complete ###")
    print("\nAll results saved to python/ directory")
    print("Check the following files:")
    print("  - scenario_comparison.png")
    print("  - sensitivity_nu.png")


if __name__ == '__main__':
    main()
