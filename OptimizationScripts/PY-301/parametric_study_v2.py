"""
Parametric Study V2 - Refined Optimization
Focus on finding valid designs with minimum pressure drop.

Key insight from V1: Baseline design is INVALID because Section 2 has insufficient
heat transfer area. Valid designs require smaller gap (higher h), which increases DP.

This study explores the design space more thoroughly to find the best trade-off.
"""

import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime
import os
import json

# ============== FIXED PARAMETERS ==============
FIXED = {
    'D_pyrolizer': 0.318,
    'L1': 2.05,
    'L2': 2.57,
    'T_hot1_C': 611.7223193,
    'm_dot': 0.7609,
    'Q1': 23550,
    'Q2': 20070,
    'T_cold_in_C': 280,
    'T_cold_out_C': 550,
    'rho': 2050,
    'Cp': 2300,
    'k_fluid': 0.55,
    'mu_A': 0.0852,
    'mu_Ea': 3.51e4,
    'R_gas': 8.314,
}

BASELINE = {
    'D_jacket': 0.358,
    'N_ch': 10,
    't_fin': 0.005,
}


def viscosity(T_K, mu_A=FIXED['mu_A'], mu_Ea=FIXED['mu_Ea'], R_gas=FIXED['R_gas']):
    return mu_A * np.exp(mu_Ea / (R_gas * T_K))


def calculate_design(D_jacket, N_ch, t_fin):
    D_pyr = FIXED['D_pyrolizer']
    L1, L2 = FIXED['L1'], FIXED['L2']
    T_hot1 = FIXED['T_hot1_C'] + 273.15
    m_dot = FIXED['m_dot']
    Q1, Q2 = FIXED['Q1'], FIXED['Q2']
    T_cold_in = FIXED['T_cold_in_C'] + 273.15
    T_cold_out = FIXED['T_cold_out_C'] + 273.15
    rho, Cp, k_f = FIXED['rho'], FIXED['Cp'], FIXED['k_fluid']

    T_hot_mid = T_hot1 - Q1 / (m_dot * Cp)
    T_hot2 = T_hot_mid - Q2 / (m_dot * Cp)
    T_hot_avg1 = (T_hot1 + T_hot_mid) / 2
    T_hot_avg2 = (T_hot_mid + T_hot2) / 2

    w_ch = (np.pi * D_pyr / N_ch) - t_fin
    if w_ch <= 0:
        return None

    GAP = (D_jacket - D_pyr) / 2
    if GAP <= 0:
        return None

    A_c = w_ch * GAP
    D_h = 2 * w_ch * GAP / (w_ch + GAP)
    v = m_dot / (rho * N_ch * A_c)

    mu1 = viscosity(T_hot_avg1)
    mu_wall = viscosity(T_cold_out)
    Re1 = rho * v * D_h / mu1
    Pr1 = Cp * mu1 / k_f
    Gz1 = Re1 * Pr1 * D_h / L1
    Nu1 = 1.86 * (Gz1 ** (1/3)) * ((mu1 / mu_wall) ** 0.14)
    h1 = Nu1 * k_f / D_h

    mu2 = viscosity(T_hot_avg2)
    Re2 = rho * v * D_h / mu2
    Pr2 = Cp * mu2 / k_f
    Gz2 = Re2 * Pr2 * D_h / L2
    Nu2 = 1.86 * (Gz2 ** (1/3)) * ((mu2 / mu_wall) ** 0.14)
    h2 = Nu2 * k_f / D_h

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

    A_req1 = Q1 / (h1 * LMTD1)
    A_av1 = np.pi * D_pyr * L1
    A_req2 = Q2 / (h2 * LMTD2)
    A_av2 = np.pi * D_pyr * L2

    design_ok = (A_av1 >= A_req1) and (A_av2 >= A_req2)

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


def create_results_folder(suffix=""):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    folder_name = f"results_{timestamp}{suffix}"
    folder_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), folder_name)
    os.makedirs(folder_path, exist_ok=True)
    return folder_path


# ============== MAIN ==============
if __name__ == "__main__":
    print("=" * 70)
    print("PARAMETRIC STUDY V2 - REFINED OPTIMIZATION")
    print("=" * 70)

    baseline_res = calculate_design(**BASELINE)
    BASELINE_DP = baseline_res['DP_total_kPa']
    print(f"\nBaseline: DP = {BASELINE_DP:.2f} kPa, Valid = {baseline_res['design_ok']}")

    output_path = create_results_folder("_v2")
    print(f"Results folder: {output_path}")

    # Comprehensive grid search with fine resolution
    print("\n--- Comprehensive Grid Search ---")

    all_results = []
    valid_results = []

    # Expand search range and increase resolution
    D_jacket_range = np.linspace(0.325, 0.400, 40)  # Explore tighter gaps
    N_ch_range = range(8, 30)                        # More channels
    t_fin_range = np.linspace(0.001, 0.008, 20)     # Thinner fins

    total_configs = len(D_jacket_range) * len(N_ch_range) * len(t_fin_range)
    print(f"Testing {total_configs} configurations...")

    for D_jkt in D_jacket_range:
        for N_ch in N_ch_range:
            for t_fin in t_fin_range:
                res = calculate_design(D_jkt, N_ch, t_fin)
                if res is not None:
                    all_results.append(res)
                    if res['design_ok']:
                        valid_results.append(res)

    print(f"Total valid configurations: {len(valid_results)}")
    print(f"Valid geometries found: {len(valid_results)} / {len(all_results)}")

    if valid_results:
        # Sort by pressure drop
        valid_results.sort(key=lambda x: x['DP_total_kPa'])

        # Best designs
        best = valid_results[0]
        print(f"\n{'='*70}")
        print("TOP 5 OPTIMAL DESIGNS (Minimum Pressure Drop)")
        print("="*70)

        for i, design in enumerate(valid_results[:5]):
            print(f"\n--- Design #{i+1} ---")
            print(f"  D_jacket = {design['D_jacket']:.4f} m (GAP = {design['GAP']*1000:.2f} mm)")
            print(f"  N_ch = {design['N_ch']} channels")
            print(f"  t_fin = {design['t_fin']*1000:.2f} mm")
            print(f"  D_h = {design['D_h']*1000:.2f} mm")
            print(f"  Velocity = {design['v']:.4f} m/s")
            print(f"  h1 = {design['h1']:.1f} W/m²K, h2 = {design['h2']:.1f} W/m²K")
            print(f"  DP_total = {design['DP_total_kPa']:.2f} kPa")
            print(f"  Area Margin S1: {design['A_margin1']:.1f}%, S2: {design['A_margin2']:.1f}%")

        # Create visualizations
        fig, axes = plt.subplots(2, 3, figsize=(15, 10))
        fig.suptitle('Parametric Study V2: Valid Design Analysis', fontsize=14, fontweight='bold')

        # Plot 1: DP vs D_jacket for valid designs
        ax1 = axes[0, 0]
        D_jkt_valid = [r['D_jacket'] for r in valid_results]
        DP_valid = [r['DP_total_kPa'] for r in valid_results]
        ax1.scatter(D_jkt_valid, DP_valid, c='green', alpha=0.6, s=30)
        ax1.scatter(best['D_jacket'], best['DP_total_kPa'], c='red', s=100, marker='*', label='Optimal')
        ax1.set_xlabel('Jacket Diameter (m)')
        ax1.set_ylabel('Pressure Drop (kPa)')
        ax1.set_title('Valid Designs: DP vs D_jacket')
        ax1.grid(True, alpha=0.3)
        ax1.legend()

        # Plot 2: DP vs N_ch for valid designs
        ax2 = axes[0, 1]
        N_ch_valid = [r['N_ch'] for r in valid_results]
        ax2.scatter(N_ch_valid, DP_valid, c='blue', alpha=0.6, s=30)
        ax2.scatter(best['N_ch'], best['DP_total_kPa'], c='red', s=100, marker='*', label='Optimal')
        ax2.set_xlabel('Number of Channels')
        ax2.set_ylabel('Pressure Drop (kPa)')
        ax2.set_title('Valid Designs: DP vs N_ch')
        ax2.grid(True, alpha=0.3)
        ax2.legend()

        # Plot 3: DP vs t_fin for valid designs
        ax3 = axes[0, 2]
        t_fin_valid = [r['t_fin']*1000 for r in valid_results]
        ax3.scatter(t_fin_valid, DP_valid, c='purple', alpha=0.6, s=30)
        ax3.scatter(best['t_fin']*1000, best['DP_total_kPa'], c='red', s=100, marker='*', label='Optimal')
        ax3.set_xlabel('Fin Thickness (mm)')
        ax3.set_ylabel('Pressure Drop (kPa)')
        ax3.set_title('Valid Designs: DP vs t_fin')
        ax3.grid(True, alpha=0.3)
        ax3.legend()

        # Plot 4: Design space coverage - D_jacket vs N_ch
        ax4 = axes[1, 0]
        # All tested points
        D_all = [r['D_jacket'] for r in all_results]
        N_all = [r['N_ch'] for r in all_results]
        ax4.scatter(D_all, N_all, c='gray', alpha=0.1, s=10, label='Invalid')
        ax4.scatter(D_jkt_valid, N_ch_valid, c='green', alpha=0.6, s=20, label='Valid')
        ax4.scatter(best['D_jacket'], best['N_ch'], c='red', s=100, marker='*', label='Optimal')
        ax4.set_xlabel('Jacket Diameter (m)')
        ax4.set_ylabel('Number of Channels')
        ax4.set_title('Design Space: Valid Region')
        ax4.legend()
        ax4.grid(True, alpha=0.3)

        # Plot 5: Area Margins
        ax5 = axes[1, 1]
        margin1 = [r['A_margin1'] for r in valid_results]
        margin2 = [r['A_margin2'] for r in valid_results]
        ax5.scatter(margin1, margin2, c=DP_valid, cmap='viridis', alpha=0.7, s=30)
        ax5.scatter(best['A_margin1'], best['A_margin2'], c='red', s=100, marker='*')
        ax5.axhline(y=0, color='red', linestyle='--', alpha=0.5)
        ax5.axvline(x=0, color='red', linestyle='--', alpha=0.5)
        ax5.set_xlabel('Section 1 Area Margin (%)')
        ax5.set_ylabel('Section 2 Area Margin (%)')
        ax5.set_title('Area Margins (color = DP)')
        ax5.grid(True, alpha=0.3)
        cb = plt.colorbar(ax5.collections[0], ax=ax5)
        cb.set_label('DP (kPa)')

        # Plot 6: Histogram of pressure drops
        ax6 = axes[1, 2]
        ax6.hist(DP_valid, bins=30, color='steelblue', edgecolor='black', alpha=0.7)
        ax6.axvline(x=best['DP_total_kPa'], color='red', linewidth=2, label=f'Min: {best["DP_total_kPa"]:.1f} kPa')
        ax6.set_xlabel('Pressure Drop (kPa)')
        ax6.set_ylabel('Count')
        ax6.set_title('Distribution of Valid Design Pressure Drops')
        ax6.legend()
        ax6.grid(True, alpha=0.3)

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'valid_designs_analysis.png'), dpi=150)
        plt.close()

        # Create 3D scatter plot
        fig = plt.figure(figsize=(12, 8))
        ax = fig.add_subplot(111, projection='3d')

        scatter = ax.scatter(D_jkt_valid, N_ch_valid, t_fin_valid,
                            c=DP_valid, cmap='viridis', s=40, alpha=0.7)
        ax.scatter(best['D_jacket'], best['N_ch'], best['t_fin']*1000,
                   c='red', s=200, marker='*', label='Optimal')

        ax.set_xlabel('Jacket Diameter (m)')
        ax.set_ylabel('Number of Channels')
        ax.set_zlabel('Fin Thickness (mm)')
        ax.set_title('3D Design Space - Valid Configurations')
        plt.colorbar(scatter, label='Pressure Drop (kPa)', shrink=0.5)
        ax.legend()

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, '3d_design_space.png'), dpi=150)
        plt.close()

        # Sensitivity analysis around optimal
        print("\n" + "="*70)
        print("SENSITIVITY ANALYSIS AROUND OPTIMAL DESIGN")
        print("="*70)

        # Vary each parameter individually around optimal
        opt_D = best['D_jacket']
        opt_N = best['N_ch']
        opt_t = best['t_fin']

        # D_jacket sensitivity
        D_sens_range = np.linspace(opt_D - 0.01, opt_D + 0.01, 21)
        D_sens_results = []
        for D in D_sens_range:
            res = calculate_design(D, opt_N, opt_t)
            if res is not None:
                D_sens_results.append(res)

        # N_ch sensitivity
        N_sens_range = range(max(opt_N - 5, 4), opt_N + 6)
        N_sens_results = []
        for N in N_sens_range:
            res = calculate_design(opt_D, N, opt_t)
            if res is not None:
                N_sens_results.append(res)

        # t_fin sensitivity
        t_sens_range = np.linspace(max(opt_t - 0.002, 0.001), opt_t + 0.002, 21)
        t_sens_results = []
        for t in t_sens_range:
            res = calculate_design(opt_D, opt_N, t)
            if res is not None:
                t_sens_results.append(res)

        # Plot sensitivity
        fig, axes = plt.subplots(1, 3, figsize=(15, 5))
        fig.suptitle('Sensitivity Analysis Around Optimal Design', fontsize=14, fontweight='bold')

        # D_jacket sensitivity
        ax1 = axes[0]
        D_vals = [r['D_jacket'] for r in D_sens_results]
        DP_vals = [r['DP_total_kPa'] for r in D_sens_results]
        colors = ['green' if r['design_ok'] else 'red' for r in D_sens_results]
        ax1.scatter(D_vals, DP_vals, c=colors, s=50, edgecolors='black')
        ax1.axvline(x=opt_D, color='blue', linestyle='--', alpha=0.5, label='Optimal')
        ax1.set_xlabel('Jacket Diameter (m)')
        ax1.set_ylabel('Pressure Drop (kPa)')
        ax1.set_title('Sensitivity: D_jacket')
        ax1.grid(True, alpha=0.3)
        ax1.legend()

        # N_ch sensitivity
        ax2 = axes[1]
        N_vals = [r['N_ch'] for r in N_sens_results]
        DP_vals = [r['DP_total_kPa'] for r in N_sens_results]
        colors = ['green' if r['design_ok'] else 'red' for r in N_sens_results]
        ax2.scatter(N_vals, DP_vals, c=colors, s=50, edgecolors='black')
        ax2.axvline(x=opt_N, color='blue', linestyle='--', alpha=0.5, label='Optimal')
        ax2.set_xlabel('Number of Channels')
        ax2.set_ylabel('Pressure Drop (kPa)')
        ax2.set_title('Sensitivity: N_ch')
        ax2.grid(True, alpha=0.3)
        ax2.legend()

        # t_fin sensitivity
        ax3 = axes[2]
        t_vals = [r['t_fin']*1000 for r in t_sens_results]
        DP_vals = [r['DP_total_kPa'] for r in t_sens_results]
        colors = ['green' if r['design_ok'] else 'red' for r in t_sens_results]
        ax3.scatter(t_vals, DP_vals, c=colors, s=50, edgecolors='black')
        ax3.axvline(x=opt_t*1000, color='blue', linestyle='--', alpha=0.5, label='Optimal')
        ax3.set_xlabel('Fin Thickness (mm)')
        ax3.set_ylabel('Pressure Drop (kPa)')
        ax3.set_title('Sensitivity: t_fin')
        ax3.grid(True, alpha=0.3)
        ax3.legend()

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'sensitivity_analysis.png'), dpi=150)
        plt.close()

        # Generate summary
        summary = []
        summary.append("="*70)
        summary.append("PARAMETRIC STUDY V2 - REFINED OPTIMIZATION SUMMARY")
        summary.append("="*70)
        summary.append(f"\nGenerated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        summary.append(f"\nTotal configurations tested: {total_configs}")
        summary.append(f"Valid designs found: {len(valid_results)}")
        summary.append(f"\nBASELINE (INVALID):")
        summary.append(f"  D_jacket = {BASELINE['D_jacket']} m")
        summary.append(f"  N_ch = {BASELINE['N_ch']}")
        summary.append(f"  t_fin = {BASELINE['t_fin']*1000:.1f} mm")
        summary.append(f"  DP = {BASELINE_DP:.2f} kPa")
        summary.append(f"  Area Margin S2 = {baseline_res['A_margin2']:.1f}% (INSUFFICIENT)")

        summary.append(f"\nOPTIMAL VALID DESIGN:")
        summary.append(f"  D_jacket = {best['D_jacket']:.4f} m")
        summary.append(f"  GAP = {best['GAP']*1000:.2f} mm")
        summary.append(f"  N_ch = {best['N_ch']} channels")
        summary.append(f"  t_fin = {best['t_fin']*1000:.2f} mm")
        summary.append(f"  w_ch = {best['w_ch']*1000:.2f} mm")
        summary.append(f"  D_h = {best['D_h']*1000:.2f} mm")
        summary.append(f"  Velocity = {best['v']:.4f} m/s")
        summary.append(f"  DP_total = {best['DP_total_kPa']:.2f} kPa")
        summary.append(f"  Area Margin S1 = {best['A_margin1']:.1f}%")
        summary.append(f"  Area Margin S2 = {best['A_margin2']:.1f}%")

        summary.append(f"\nKEY OBSERVATIONS:")
        summary.append(f"  1. Baseline design is INVALID due to insufficient heat transfer area in Section 2")
        summary.append(f"  2. Valid designs require smaller gap (tighter jacket) to increase h")
        summary.append(f"  3. Smaller gap increases velocity and pressure drop")
        summary.append(f"  4. Optimal trade-off: GAP = {best['GAP']*1000:.2f} mm with {best['N_ch']} channels")
        summary.append(f"  5. Minimum achievable DP for valid design: {best['DP_total_kPa']:.2f} kPa")

        summary_text = "\n".join(summary)
        print("\n" + summary_text)

        with open(os.path.join(output_path, 'study_summary_v2.txt'), 'w') as f:
            f.write(summary_text)

        # Save optimal design
        with open(os.path.join(output_path, 'optimal_design_v2.json'), 'w') as f:
            json.dump({k: float(v) if isinstance(v, (np.floating, np.integer)) else v
                      for k, v in best.items()}, f, indent=2)

        # Save all valid results
        with open(os.path.join(output_path, 'all_valid_designs.json'), 'w') as f:
            valid_data = [{k: float(v) if isinstance(v, (np.floating, np.integer)) else v
                          for k, v in r.items()} for r in valid_results]
            json.dump(valid_data, f, indent=2)

    else:
        print("No valid designs found in the search space!")

    print(f"\n\nAll results saved to: {output_path}")
