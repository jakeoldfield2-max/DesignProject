"""
Parametric Study for Pyrolysis Heating Jacket - Pressure Drop Optimization

This script performs parametric studies to minimize pressure drop while
maintaining a valid design (sufficient heat transfer area in both sections).

Variables that CAN be varied (rib/shell geometry):
- D_jacket: Jacket inner diameter (shell geometry)
- N_ch: Number of axial channels (rib geometry)
- t_fin: Fin/wall thickness between channels (rib geometry)

Variables that are FIXED (unit design):
- D_pyrolizer, L1, L2, heat duties, mass flow rate, salt properties
"""

import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime
import os
import json

# ============== FIXED PARAMETERS ==============
FIXED = {
    'D_pyrolizer': 0.318,      # m, pyrolizer OD
    'L1': 2.05,                # m, heating zone length
    'L2': 2.57,                # m, constant temp zone length
    'T_hot1_C': 611.7223193,   # degC, salt inlet temperature
    'm_dot': 0.7609,           # kg/s, salt mass flow rate
    'Q1': 23550,               # W, heat duty, heating zone
    'Q2': 20070,               # W, heat duty, constant temp zone
    'T_cold_in_C': 280,        # degC, wall temperature at biomass inlet
    'T_cold_out_C': 550,       # degC, wall temperature at end of L1 / all of L2
    'rho': 2050,               # kg/m3, density
    'Cp': 2300,                # J/kg/K, specific heat capacity
    'k_fluid': 0.55,           # W/m/K, thermal conductivity
    'mu_A': 0.0852,            # viscosity pre-exponential (Pa.s)
    'mu_Ea': 3.51e4,           # J/mol, viscosity activation energy
    'R_gas': 8.314,            # J/(mol.K)
}

# ============== BASELINE DESIGN ==============
BASELINE = {
    'D_jacket': 0.358,         # m, jacket ID
    'N_ch': 10,                # number of axial channels
    't_fin': 0.005,            # m, fin thickness
}


def viscosity(T_K, mu_A=FIXED['mu_A'], mu_Ea=FIXED['mu_Ea'], R_gas=FIXED['R_gas']):
    """Calculate viscosity using Arrhenius equation."""
    return mu_A * np.exp(mu_Ea / (R_gas * T_K))


def calculate_design(D_jacket, N_ch, t_fin):
    """
    Calculate all design parameters for given geometry.
    Returns dict with all results including pressure drop and design validity.
    """
    # Unpack fixed parameters
    D_pyr = FIXED['D_pyrolizer']
    L1, L2 = FIXED['L1'], FIXED['L2']
    T_hot1 = FIXED['T_hot1_C'] + 273.15
    m_dot = FIXED['m_dot']
    Q1, Q2 = FIXED['Q1'], FIXED['Q2']
    T_cold_in = FIXED['T_cold_in_C'] + 273.15
    T_cold_out = FIXED['T_cold_out_C'] + 273.15
    rho, Cp, k_f = FIXED['rho'], FIXED['Cp'], FIXED['k_fluid']

    # Temperature profile
    T_hot_mid = T_hot1 - Q1 / (m_dot * Cp)
    T_hot2 = T_hot_mid - Q2 / (m_dot * Cp)
    T_hot_avg1 = (T_hot1 + T_hot_mid) / 2
    T_hot_avg2 = (T_hot_mid + T_hot2) / 2

    # Channel geometry
    w_ch = (np.pi * D_pyr / N_ch) - t_fin
    if w_ch <= 0:
        return None  # Invalid geometry

    GAP = (D_jacket - D_pyr) / 2
    if GAP <= 0:
        return None  # Invalid geometry

    A_c = w_ch * GAP
    D_h = 2 * w_ch * GAP / (w_ch + GAP)
    v = m_dot / (rho * N_ch * A_c)

    # Heat transfer - Section 1
    mu1 = viscosity(T_hot_avg1)
    mu_wall = viscosity(T_cold_out)
    Re1 = rho * v * D_h / mu1
    Pr1 = Cp * mu1 / k_f
    Gz1 = Re1 * Pr1 * D_h / L1
    Nu1 = 1.86 * (Gz1 ** (1/3)) * ((mu1 / mu_wall) ** 0.14)
    h1 = Nu1 * k_f / D_h

    # Heat transfer - Section 2
    mu2 = viscosity(T_hot_avg2)
    Re2 = rho * v * D_h / mu2
    Pr2 = Cp * mu2 / k_f
    Gz2 = Re2 * Pr2 * D_h / L2
    Nu2 = 1.86 * (Gz2 ** (1/3)) * ((mu2 / mu_wall) ** 0.14)
    h2 = Nu2 * k_f / D_h

    # LMTD calculations
    dT1_in = T_hot1 - T_cold_in
    dT1_out = T_hot_mid - T_cold_out
    if dT1_in <= 0 or dT1_out <= 0 or dT1_in == dT1_out:
        return None
    LMTD1 = (dT1_in - dT1_out) / np.log(dT1_in / dT1_out)

    dT2_in = T_hot_mid - T_cold_out
    dT2_out = T_hot2 - T_cold_out
    if dT2_in <= 0 or dT2_out <= 0 or dT2_in == dT2_out:
        return None
    LMTD2 = (dT2_in - dT2_out) / np.log(dT2_in / dT2_out)

    # Area check
    A_req1 = Q1 / (h1 * LMTD1)
    A_av1 = np.pi * D_pyr * L1
    A_req2 = Q2 / (h2 * LMTD2)
    A_av2 = np.pi * D_pyr * L2

    design_ok = (A_av1 >= A_req1) and (A_av2 >= A_req2)

    # Pressure drop (laminar)
    f1 = 16 / Re1
    DP1 = 4 * f1 * (L1 / D_h) * (rho * v**2 / 2)

    f2 = 16 / Re2
    DP2 = 4 * f2 * (L2 / D_h) * (rho * v**2 / 2)

    DP_total = DP1 + DP2

    return {
        'D_jacket': D_jacket,
        'N_ch': N_ch,
        't_fin': t_fin,
        'w_ch': w_ch,
        'GAP': GAP,
        'A_c': A_c,
        'D_h': D_h,
        'v': v,
        'Re1': Re1, 'Re2': Re2,
        'Nu1': Nu1, 'Nu2': Nu2,
        'h1': h1, 'h2': h2,
        'LMTD1': LMTD1, 'LMTD2': LMTD2,
        'A_req1': A_req1, 'A_av1': A_av1,
        'A_req2': A_req2, 'A_av2': A_av2,
        'A_margin1': (A_av1 - A_req1) / A_av1 * 100,
        'A_margin2': (A_av2 - A_req2) / A_av2 * 100,
        'DP1_kPa': DP1 / 1000,
        'DP2_kPa': DP2 / 1000,
        'DP_total_kPa': DP_total / 1000,
        'design_ok': design_ok,
    }


def run_parametric_study(param_name, param_values, base_params):
    """Run a parametric study varying one parameter."""
    results = []
    for val in param_values:
        params = base_params.copy()
        params[param_name] = val
        res = calculate_design(**params)
        if res is not None:
            results.append(res)
    return results


def run_2d_study(param1_name, param1_values, param2_name, param2_values, base_params):
    """Run a 2D parametric study varying two parameters."""
    results = []
    for v1 in param1_values:
        for v2 in param2_values:
            params = base_params.copy()
            params[param1_name] = v1
            params[param2_name] = v2
            res = calculate_design(**params)
            if res is not None:
                results.append(res)
    return results


def create_results_folder():
    """Create a timestamped results folder."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    folder_name = f"results_{timestamp}"
    folder_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), folder_name)
    os.makedirs(folder_path, exist_ok=True)
    return folder_path


def plot_1d_study(results, param_name, param_label, output_path, study_name):
    """Create plots for 1D parametric study."""
    if not results:
        return

    x = [r[param_name] for r in results]
    dp_total = [r['DP_total_kPa'] for r in results]
    design_ok = [r['design_ok'] for r in results]

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    fig.suptitle(f'Parametric Study: {study_name}', fontsize=14, fontweight='bold')

    # Plot 1: Pressure Drop vs Parameter
    ax1 = axes[0, 0]
    colors = ['green' if ok else 'red' for ok in design_ok]
    ax1.scatter(x, dp_total, c=colors, s=50, edgecolors='black', linewidths=0.5)
    ax1.plot(x, dp_total, 'b-', alpha=0.5, linewidth=1)
    ax1.set_xlabel(param_label)
    ax1.set_ylabel('Total Pressure Drop (kPa)')
    ax1.set_title('Pressure Drop vs ' + param_label)
    ax1.grid(True, alpha=0.3)
    ax1.axhline(y=BASELINE_DP, color='orange', linestyle='--', label=f'Baseline: {BASELINE_DP:.2f} kPa')
    ax1.legend()

    # Plot 2: Hydraulic Diameter
    D_h = [r['D_h'] * 1000 for r in results]  # Convert to mm
    ax2 = axes[0, 1]
    ax2.scatter(x, D_h, c=colors, s=50, edgecolors='black', linewidths=0.5)
    ax2.plot(x, D_h, 'b-', alpha=0.5, linewidth=1)
    ax2.set_xlabel(param_label)
    ax2.set_ylabel('Hydraulic Diameter (mm)')
    ax2.set_title('Hydraulic Diameter vs ' + param_label)
    ax2.grid(True, alpha=0.3)

    # Plot 3: Velocity
    v = [r['v'] for r in results]
    ax3 = axes[1, 0]
    ax3.scatter(x, v, c=colors, s=50, edgecolors='black', linewidths=0.5)
    ax3.plot(x, v, 'b-', alpha=0.5, linewidth=1)
    ax3.set_xlabel(param_label)
    ax3.set_ylabel('Flow Velocity (m/s)')
    ax3.set_title('Velocity vs ' + param_label)
    ax3.grid(True, alpha=0.3)

    # Plot 4: Area Margins
    margin1 = [r['A_margin1'] for r in results]
    margin2 = [r['A_margin2'] for r in results]
    ax4 = axes[1, 1]
    ax4.plot(x, margin1, 'b-', label='Section 1 Margin', linewidth=2)
    ax4.plot(x, margin2, 'r-', label='Section 2 Margin', linewidth=2)
    ax4.axhline(y=0, color='black', linestyle='--', linewidth=1)
    ax4.set_xlabel(param_label)
    ax4.set_ylabel('Area Margin (%)')
    ax4.set_title('Heat Transfer Area Margin')
    ax4.legend()
    ax4.grid(True, alpha=0.3)
    ax4.fill_between(x, 0, margin2, where=[m < 0 for m in margin2], alpha=0.3, color='red')

    plt.tight_layout()
    plt.savefig(os.path.join(output_path, f'{study_name.replace(" ", "_")}.png'), dpi=150)
    plt.close()


def plot_2d_contour(results, param1_name, param1_label, param2_name, param2_label, output_path, study_name):
    """Create contour plots for 2D parametric study."""
    if not results:
        return

    # Extract unique parameter values
    p1_vals = sorted(list(set(r[param1_name] for r in results)))
    p2_vals = sorted(list(set(r[param2_name] for r in results)))

    # Create meshgrid for plotting
    P1, P2 = np.meshgrid(p1_vals, p2_vals)
    DP = np.full_like(P1, np.nan, dtype=float)
    VALID = np.full_like(P1, False, dtype=bool)

    for r in results:
        i = p2_vals.index(r[param2_name])
        j = p1_vals.index(r[param1_name])
        DP[i, j] = r['DP_total_kPa']
        VALID[i, j] = r['design_ok']

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    fig.suptitle(f'2D Parametric Study: {study_name}', fontsize=14, fontweight='bold')

    # Plot 1: Pressure drop contour
    ax1 = axes[0]
    cf = ax1.contourf(P1, P2, DP, levels=20, cmap='viridis')
    plt.colorbar(cf, ax=ax1, label='Pressure Drop (kPa)')
    ax1.set_xlabel(param1_label)
    ax1.set_ylabel(param2_label)
    ax1.set_title('Pressure Drop Contour')

    # Mark valid designs
    valid_p1 = [r[param1_name] for r in results if r['design_ok']]
    valid_p2 = [r[param2_name] for r in results if r['design_ok']]
    ax1.scatter(valid_p1, valid_p2, c='white', s=10, alpha=0.5, label='Valid Design')
    ax1.legend()

    # Plot 2: Valid region with pressure drop
    ax2 = axes[1]
    # Show invalid region in red
    invalid_mask = ~VALID
    ax2.contourf(P1, P2, invalid_mask.astype(float), levels=[0.5, 1.5], colors=['red'], alpha=0.3)

    # Contour of pressure drop only for valid designs
    DP_valid = np.where(VALID, DP, np.nan)
    if np.any(~np.isnan(DP_valid)):
        cf2 = ax2.contourf(P1, P2, DP_valid, levels=15, cmap='viridis')
        plt.colorbar(cf2, ax=ax2, label='Pressure Drop (kPa)')

    ax2.set_xlabel(param1_label)
    ax2.set_ylabel(param2_label)
    ax2.set_title('Valid Design Region (red = invalid)')

    plt.tight_layout()
    plt.savefig(os.path.join(output_path, f'{study_name.replace(" ", "_")}_contour.png'), dpi=150)
    plt.close()


def find_optimal_design(results):
    """Find the optimal design (lowest pressure drop among valid designs)."""
    valid_results = [r for r in results if r['design_ok']]
    if not valid_results:
        return None
    return min(valid_results, key=lambda r: r['DP_total_kPa'])


def generate_summary(all_studies, optimal_designs, output_path):
    """Generate a summary report."""
    summary = []
    summary.append("=" * 70)
    summary.append("PYROLYSIS HEATING JACKET - PARAMETRIC STUDY SUMMARY")
    summary.append("=" * 70)
    summary.append(f"\nGenerated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    summary.append(f"\nObjective: Minimize pressure drop while maintaining valid design")
    summary.append(f"\nConstraints:")
    summary.append(f"  - D_pyrolizer = {FIXED['D_pyrolizer']} m (FIXED)")
    summary.append(f"  - L1 = {FIXED['L1']} m (FIXED)")
    summary.append(f"  - L2 = {FIXED['L2']} m (FIXED)")
    summary.append(f"  - Heat duties Q1 = {FIXED['Q1']} W, Q2 = {FIXED['Q2']} W (FIXED)")
    summary.append(f"  - Mass flow rate = {FIXED['m_dot']} kg/s (FIXED)")

    summary.append(f"\n" + "-" * 70)
    summary.append("BASELINE DESIGN")
    summary.append("-" * 70)
    baseline_res = calculate_design(**BASELINE)
    summary.append(f"  D_jacket = {BASELINE['D_jacket']} m")
    summary.append(f"  N_ch = {BASELINE['N_ch']} channels")
    summary.append(f"  t_fin = {BASELINE['t_fin']*1000:.1f} mm")
    summary.append(f"  Pressure Drop = {baseline_res['DP_total_kPa']:.2f} kPa")
    summary.append(f"  Design Valid = {baseline_res['design_ok']}")
    summary.append(f"  Area Margin Section 1 = {baseline_res['A_margin1']:.1f}%")
    summary.append(f"  Area Margin Section 2 = {baseline_res['A_margin2']:.1f}%")

    for study_name, study_data in all_studies.items():
        summary.append(f"\n" + "-" * 70)
        summary.append(f"STUDY: {study_name}")
        summary.append("-" * 70)

        valid_count = sum(1 for r in study_data if r['design_ok'])
        total_count = len(study_data)
        summary.append(f"  Total configurations tested: {total_count}")
        summary.append(f"  Valid designs: {valid_count}")

        if study_name in optimal_designs and optimal_designs[study_name]:
            opt = optimal_designs[study_name]
            summary.append(f"\n  OPTIMAL CONFIGURATION:")
            summary.append(f"    D_jacket = {opt['D_jacket']:.4f} m")
            summary.append(f"    N_ch = {opt['N_ch']} channels")
            summary.append(f"    t_fin = {opt['t_fin']*1000:.2f} mm")
            summary.append(f"    Hydraulic Diameter = {opt['D_h']*1000:.2f} mm")
            summary.append(f"    Flow Velocity = {opt['v']:.4f} m/s")
            summary.append(f"    Pressure Drop = {opt['DP_total_kPa']:.2f} kPa")
            summary.append(f"    Improvement vs Baseline = {(BASELINE_DP - opt['DP_total_kPa'])/BASELINE_DP*100:.1f}%")
            summary.append(f"    Area Margin Section 1 = {opt['A_margin1']:.1f}%")
            summary.append(f"    Area Margin Section 2 = {opt['A_margin2']:.1f}%")

    # Write summary to file
    summary_text = "\n".join(summary)
    with open(os.path.join(output_path, "study_summary.txt"), 'w') as f:
        f.write(summary_text)

    return summary_text


# ============== MAIN EXECUTION ==============
if __name__ == "__main__":
    # Calculate baseline
    baseline_res = calculate_design(**BASELINE)
    BASELINE_DP = baseline_res['DP_total_kPa']

    print("=" * 60)
    print("PYROLYSIS HEATING JACKET - PARAMETRIC OPTIMIZATION")
    print("=" * 60)
    print(f"\nBaseline Pressure Drop: {BASELINE_DP:.2f} kPa")
    print(f"Baseline Design Valid: {baseline_res['design_ok']}")

    # Create results folder
    output_path = create_results_folder()
    print(f"\nResults will be saved to: {output_path}")

    all_studies = {}
    optimal_designs = {}

    # ============== STUDY 1: Vary D_jacket ==============
    print("\n--- Study 1: Varying Jacket Diameter ---")
    D_jacket_range = np.linspace(0.340, 0.450, 50)
    results1 = run_parametric_study('D_jacket', D_jacket_range, BASELINE)
    all_studies['Study1_D_jacket'] = results1
    optimal_designs['Study1_D_jacket'] = find_optimal_design(results1)
    plot_1d_study(results1, 'D_jacket', 'Jacket Diameter (m)', output_path, 'Study1_D_jacket')

    if optimal_designs['Study1_D_jacket']:
        print(f"  Optimal D_jacket = {optimal_designs['Study1_D_jacket']['D_jacket']:.4f} m")
        print(f"  Pressure Drop = {optimal_designs['Study1_D_jacket']['DP_total_kPa']:.2f} kPa")

    # ============== STUDY 2: Vary N_ch ==============
    print("\n--- Study 2: Varying Number of Channels ---")
    N_ch_range = range(4, 30)
    results2 = run_parametric_study('N_ch', N_ch_range, BASELINE)
    all_studies['Study2_N_ch'] = results2
    optimal_designs['Study2_N_ch'] = find_optimal_design(results2)
    plot_1d_study(results2, 'N_ch', 'Number of Channels', output_path, 'Study2_N_ch')

    if optimal_designs['Study2_N_ch']:
        print(f"  Optimal N_ch = {optimal_designs['Study2_N_ch']['N_ch']}")
        print(f"  Pressure Drop = {optimal_designs['Study2_N_ch']['DP_total_kPa']:.2f} kPa")

    # ============== STUDY 3: Vary t_fin ==============
    print("\n--- Study 3: Varying Fin Thickness ---")
    t_fin_range = np.linspace(0.002, 0.015, 40)
    results3 = run_parametric_study('t_fin', t_fin_range, BASELINE)
    all_studies['Study3_t_fin'] = results3
    optimal_designs['Study3_t_fin'] = find_optimal_design(results3)
    plot_1d_study(results3, 't_fin', 'Fin Thickness (m)', output_path, 'Study3_t_fin')

    if optimal_designs['Study3_t_fin']:
        print(f"  Optimal t_fin = {optimal_designs['Study3_t_fin']['t_fin']*1000:.2f} mm")
        print(f"  Pressure Drop = {optimal_designs['Study3_t_fin']['DP_total_kPa']:.2f} kPa")

    # ============== STUDY 4: 2D Study - D_jacket vs N_ch ==============
    print("\n--- Study 4: 2D Study - D_jacket vs N_ch ---")
    D_jacket_2d = np.linspace(0.340, 0.450, 25)
    N_ch_2d = range(4, 25)
    results4 = run_2d_study('D_jacket', D_jacket_2d, 'N_ch', N_ch_2d, BASELINE)
    all_studies['Study4_D_jacket_vs_N_ch'] = results4
    optimal_designs['Study4_D_jacket_vs_N_ch'] = find_optimal_design(results4)
    plot_2d_contour(results4, 'D_jacket', 'Jacket Diameter (m)', 'N_ch', 'Number of Channels',
                    output_path, 'Study4_D_jacket_vs_N_ch')

    if optimal_designs['Study4_D_jacket_vs_N_ch']:
        opt4 = optimal_designs['Study4_D_jacket_vs_N_ch']
        print(f"  Optimal: D_jacket={opt4['D_jacket']:.4f} m, N_ch={opt4['N_ch']}")
        print(f"  Pressure Drop = {opt4['DP_total_kPa']:.2f} kPa")

    # ============== STUDY 5: Combined Optimization ==============
    print("\n--- Study 5: Combined 3-Parameter Optimization ---")
    best_dp = float('inf')
    best_config = None
    results5 = []

    for D_jkt in np.linspace(0.360, 0.450, 20):
        for N_ch in range(6, 20):
            for t_fin in np.linspace(0.002, 0.010, 10):
                res = calculate_design(D_jkt, N_ch, t_fin)
                if res is not None:
                    results5.append(res)
                    if res['design_ok'] and res['DP_total_kPa'] < best_dp:
                        best_dp = res['DP_total_kPa']
                        best_config = res

    all_studies['Study5_Combined'] = results5
    optimal_designs['Study5_Combined'] = best_config

    if best_config:
        print(f"  Best Configuration Found:")
        print(f"    D_jacket = {best_config['D_jacket']:.4f} m")
        print(f"    N_ch = {best_config['N_ch']}")
        print(f"    t_fin = {best_config['t_fin']*1000:.2f} mm")
        print(f"    Pressure Drop = {best_config['DP_total_kPa']:.2f} kPa")
        print(f"    Reduction from baseline: {(BASELINE_DP - best_config['DP_total_kPa'])/BASELINE_DP*100:.1f}%")

    # Create comparison plot
    fig, ax = plt.subplots(figsize=(10, 6))
    studies_to_plot = ['Study1_D_jacket', 'Study2_N_ch', 'Study3_t_fin', 'Study4_D_jacket_vs_N_ch', 'Study5_Combined']
    opt_values = []
    labels = []

    for study in studies_to_plot:
        if study in optimal_designs and optimal_designs[study]:
            opt_values.append(optimal_designs[study]['DP_total_kPa'])
            labels.append(study.replace('_', '\n'))

    bars = ax.bar(range(len(opt_values)), opt_values, color='steelblue', edgecolor='black')
    ax.axhline(y=BASELINE_DP, color='red', linestyle='--', linewidth=2, label=f'Baseline: {BASELINE_DP:.2f} kPa')
    ax.set_xticks(range(len(opt_values)))
    ax.set_xticklabels(labels, fontsize=8)
    ax.set_ylabel('Optimal Pressure Drop (kPa)')
    ax.set_title('Comparison of Optimal Designs Across Studies')
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')

    for i, v in enumerate(opt_values):
        ax.text(i, v + 0.5, f'{v:.1f}', ha='center', fontsize=9)

    plt.tight_layout()
    plt.savefig(os.path.join(output_path, 'study_comparison.png'), dpi=150)
    plt.close()

    # Generate summary
    summary = generate_summary(all_studies, optimal_designs, output_path)
    print("\n" + "=" * 60)
    print(summary)

    # Save optimal config to JSON
    if best_config:
        with open(os.path.join(output_path, 'optimal_design.json'), 'w') as f:
            json.dump({k: float(v) if isinstance(v, (np.floating, np.integer)) else v
                      for k, v in best_config.items()}, f, indent=2)

    print(f"\n\nAll results saved to: {output_path}")
