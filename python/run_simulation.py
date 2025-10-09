"""
K+S Model Runner and Visualization
===================================

Script to run the K+S model and visualize results.
"""

import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
from model import KSModel


def run_simulation(steps=100, **model_params):
    """Run a single simulation"""
    print(f"Initializing K+S model...")
    model = KSModel(**model_params)
    
    print(f"Running simulation for {steps} steps...")
    for i in range(steps):
        model.step()
        if (i + 1) % 10 == 0:
            print(f"Step {i + 1}/{steps} - GDP: {model.GDPreal:.2f}, Unemployment: {model.Ue:.2%}")
    
    print("Simulation complete!")
    return model


def visualize_results(model, save_path=None):
    """Visualize simulation results"""
    # Get data
    model_data = model.datacollector.get_model_vars_dataframe()
    
    # Create figure with subplots
    fig, axes = plt.subplots(3, 2, figsize=(15, 12))
    fig.suptitle('K+S Model Simulation Results', fontsize=16, fontweight='bold')
    
    # 1. GDP
    ax = axes[0, 0]
    model_data['GDP'].plot(ax=ax, color='blue', linewidth=2)
    ax.set_title('Real GDP', fontweight='bold')
    ax.set_xlabel('Time')
    ax.set_ylabel('GDP')
    ax.grid(True, alpha=0.3)
    
    # 2. Unemployment
    ax = axes[0, 1]
    model_data['Unemployment'].plot(ax=ax, color='red', linewidth=2)
    ax.set_title('Unemployment Rate', fontweight='bold')
    ax.set_xlabel('Time')
    ax.set_ylabel('Unemployment Rate')
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: f'{y:.1%}'))
    ax.grid(True, alpha=0.3)
    
    # 3. Inflation
    ax = axes[1, 0]
    model_data['Inflation'].plot(ax=ax, color='green', linewidth=2)
    ax.set_title('Inflation Rate', fontweight='bold')
    ax.set_xlabel('Time')
    ax.set_ylabel('Inflation Rate')
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: f'{y:.1%}'))
    ax.grid(True, alpha=0.3)
    ax.axhline(y=0, color='black', linestyle='--', alpha=0.5)
    
    # 4. Number of Firms
    ax = axes[1, 1]
    model_data['Num_Firms1'].plot(ax=ax, label='Capital-Good Firms', linewidth=2)
    model_data['Num_Firms2'].plot(ax=ax, label='Consumption-Good Firms', linewidth=2)
    ax.set_title('Number of Firms', fontweight='bold')
    ax.set_xlabel('Time')
    ax.set_ylabel('Number of Firms')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # 5. Average Wages
    ax = axes[2, 0]
    model_data['Wages'].plot(ax=ax, color='purple', linewidth=2)
    ax.set_title('Average Wages', fontweight='bold')
    ax.set_xlabel('Time')
    ax.set_ylabel('Average Wage')
    ax.grid(True, alpha=0.3)
    
    # 6. Interest Rate and Public Debt
    ax = axes[2, 1]
    ax2 = ax.twinx()
    model_data['Interest_Rate'].plot(ax=ax, color='orange', linewidth=2, label='Interest Rate')
    model_data['Public_Debt'].plot(ax=ax2, color='brown', linewidth=2, label='Public Debt', alpha=0.7)
    ax.set_title('Interest Rate & Public Debt', fontweight='bold')
    ax.set_xlabel('Time')
    ax.set_ylabel('Interest Rate', color='orange')
    ax2.set_ylabel('Public Debt', color='brown')
    ax.tick_params(axis='y', labelcolor='orange')
    ax2.tick_params(axis='y', labelcolor='brown')
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda y, _: f'{y:.1%}'))
    ax.grid(True, alpha=0.3)
    
    # Add legends
    lines1, labels1 = ax.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax.legend(lines1 + lines2, labels1 + labels2, loc='upper left')
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"Figure saved to {save_path}")
    
    plt.show()
    
    return fig


def print_summary_statistics(model):
    """Print summary statistics"""
    model_data = model.datacollector.get_model_vars_dataframe()
    
    print("\n" + "="*60)
    print("SIMULATION SUMMARY STATISTICS")
    print("="*60)
    
    print(f"\nMacroeconomic Indicators:")
    print(f"  Average GDP:          {model_data['GDP'].mean():10.2f}")
    print(f"  GDP Growth (total):   {(model_data['GDP'].iloc[-1] / model_data['GDP'].iloc[0] - 1):.2%}")
    print(f"  Average Unemployment: {model_data['Unemployment'].mean():10.2%}")
    print(f"  Average Inflation:    {model_data['Inflation'].mean():10.2%}")
    print(f"  Average Wages:        {model_data['Wages'].mean():10.2f}")
    
    print(f"\nFirm Demographics:")
    print(f"  Average Firm1 Count:  {model_data['Num_Firms1'].mean():10.1f}")
    print(f"  Average Firm2 Count:  {model_data['Num_Firms2'].mean():10.1f}")
    print(f"  Firm1 Volatility:     {model_data['Num_Firms1'].std():10.1f}")
    print(f"  Firm2 Volatility:     {model_data['Num_Firms2'].std():10.1f}")
    
    print(f"\nFinancial Indicators:")
    print(f"  Average Interest Rate:{model_data['Interest_Rate'].mean():10.2%}")
    print(f"  Final Public Debt:    {model_data['Public_Debt'].iloc[-1]:10.2f}")
    
    print("="*60 + "\n")


def export_results(model, filename='ks_results.csv'):
    """Export results to CSV"""
    model_data = model.datacollector.get_model_vars_dataframe()
    model_data.to_csv(filename)
    print(f"Results exported to {filename}")


def main():
    """Main execution"""
    print("="*60)
    print("K+S AGENT-BASED MACROECONOMIC MODEL")
    print("Python/Mesa 3.0 Implementation")
    print("="*60)
    
    # Model parameters (using default baseline configuration)
    model_params = {
        'F10': 20,  # Capital-good firms
        'F20': 100,  # Consumption-good firms
        'Ls0': 1000,  # Workers
        'B': 10,  # Banks
        'seed': 42,  # Random seed for reproducibility
    }
    
    # Run simulation
    steps = 100
    model = run_simulation(steps=steps, **model_params)
    
    # Print summary
    print_summary_statistics(model)
    
    # Visualize results
    visualize_results(model, save_path='python/ks_results.png')
    
    # Export results
    export_results(model, filename='python/ks_results.csv')
    
    print("\nSimulation complete! Check the output files.")


if __name__ == '__main__':
    main()
