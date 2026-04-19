"""
Parametric Study V3 - Fine-Tuned Boundary Optimization

Focus on the boundary between valid and invalid designs to find
the minimum pressure drop configuration that is just barely valid.
"""

import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime
import os
import json

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

BASELINE = {'D_jacket': 0.358, 'N_ch': 10, 't_fin': 0.005}


def viscosity(T_K):
    return FIXED['mu_A'] * np.exp(FIXED['mu_Ea'] / (FIXED['R_gas'] * T_K))


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
        'D_jacket': D_jacket, 'N_ch': N_ch, 't_fin': t_fin,
        'w_ch': w_ch, 'GAP': GAP, 'A_c': A_c, 'D_h': D_h, 'v': v,
        'Re1': Re1, 'Re2': Re2, 'h1': h1, 'h2': h2,
        'LMTD1': LMTD1, 'LMTD2': LMTD2,
        'A_req1': A_req1, 'A_av1': A_av1, 'A_req2': A_req2, 'A_av2': A_av2,
        'A_margin1': (A_av1 - A_req1) / A_av1 * 100,
        'A_margin2': (A_av2 - A_req2) / A_av2 * 100,
        'DP1_kPa': DP1 / 1000, 'DP2_kPa': DP2 / 1000,
        'DP_total_kPa': DP_total / 1000,
        'design_ok': design_ok,
    }


def create_results_folder(suffix=""):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    folder_name = f"results_{timestamp}{suffix}"
    folder_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), folder_name)
    os.makedirs(folder_path, exist_ok=True)
    return folder_path


if __name__ == "__main__":
    print("="*70)
    print("PARAMETRIC STUDY V3 - FINE-TUNED BOUNDARY OPTIMIZATION")
    print("="*70)

    baseline_res = calculate_design(**BASELINE)
    BASELINE_DP = baseline_res['DP_total_kPa']

    output_path = create_results_folder("_v3_optimized")
    print(f"Results folder: {output_path}")

    # Very fine grid search around the valid boundary
    print("\n--- Fine Grid Search Around Valid Boundary ---")

    all_results = []
    valid_results = []

    # Focus on the region where valid designs exist
    # Based on V2: D_jacket around 0.338, N_ch 8-15, t_fin 2-8mm
    D_jacket_range = np.linspace(0.330, 0.355, 100)  # Very fine resolution
    N_ch_range = range(5, 25)
    t_fin_range = np.linspace(0.001, 0.010, 50)

    total = len(D_jacket_range) * len(N_ch_range) * len(t_fin_range)
    print(f"Testing {total} configurations...")

    count = 0
    for D_jkt in D_jacket_range:
        for N_ch in N_ch_range:
            for t_fin in t_fin_range:
                res = calculate_design(D_jkt, N_ch, t_fin)
                if res is not None:
                    all_results.append(res)
                    if res['design_ok']:
                        valid_results.append(res)
                count += 1

    print(f"Valid designs found: {len(valid_results)} / {len(all_results)}")

    if valid_results:
        # Sort by pressure drop
        valid_results.sort(key=lambda x: x['DP_total_kPa'])

        best = valid_results[0]

        # Find designs at different margin thresholds
        designs_by_margin = {
            '0-1%': [r for r in valid_results if 0 <= r['A_margin2'] <= 1],
            '1-2%': [r for r in valid_results if 1 < r['A_margin2'] <= 2],
            '2-5%': [r for r in valid_results if 2 < r['A_margin2'] <= 5],
            '5-10%': [r for r in valid_results if 5 < r['A_margin2'] <= 10],
        }

        print("\n" + "="*70)
        print("ANALYSIS BY SAFETY MARGIN (Section 2)")
        print("="*70)

        for margin_range, designs in designs_by_margin.items():
            if designs:
                best_in_range = min(designs, key=lambda x: x['DP_total_kPa'])
                print(f"\nMargin {margin_range}: {len(designs)} designs")
                print(f"  Best DP: {best_in_range['DP_total_kPa']:.2f} kPa")
                print(f"  Config: D_jacket={best_in_range['D_jacket']:.4f}, N_ch={best_in_range['N_ch']}, t_fin={best_in_range['t_fin']*1000:.2f}mm")

        print("\n" + "="*70)
        print("GLOBALLY OPTIMAL DESIGN")
        print("="*70)
        print(f"\n  D_jacket = {best['D_jacket']:.5f} m")
        print(f"  GAP = {best['GAP']*1000:.3f} mm")
        print(f"  N_ch = {best['N_ch']} channels")
        print(f"  t_fin = {best['t_fin']*1000:.3f} mm")
        print(f"  w_ch = {best['w_ch']*1000:.3f} mm")
        print(f"  D_h = {best['D_h']*1000:.3f} mm")
        print(f"  Flow velocity = {best['v']:.5f} m/s")
        print(f"  h1 = {best['h1']:.2f} W/m²K")
        print(f"  h2 = {best['h2']:.2f} W/m²K")
        print(f"  DP_total = {best['DP_total_kPa']:.3f} kPa")
        print(f"  Area Margin S1 = {best['A_margin1']:.2f}%")
        print(f"  Area Margin S2 = {best['A_margin2']:.2f}%")

        # Create comprehensive visualizations
        fig, axes = plt.subplots(2, 3, figsize=(16, 11))
        fig.suptitle('Parametric Study V3: Optimized Design Analysis\n(Green=Valid, Red=Invalid, Star=Optimal)',
                     fontsize=14, fontweight='bold')

        # 1. DP vs GAP
        ax1 = axes[0, 0]
        gap_all = [r['GAP']*1000 for r in all_results]
        dp_all = [r['DP_total_kPa'] for r in all_results]
        colors_all = ['green' if r['design_ok'] else 'red' for r in all_results]
        ax1.scatter(gap_all, dp_all, c=colors_all, alpha=0.3, s=5)
        ax1.scatter(best['GAP']*1000, best['DP_total_kPa'], c='gold', s=200, marker='*',
                   edgecolors='black', linewidths=1.5, zorder=5, label='Optimal')
        ax1.set_xlabel('Annular Gap (mm)')
        ax1.set_ylabel('Pressure Drop (kPa)')
        ax1.set_title('Pressure Drop vs Gap')
        ax1.grid(True, alpha=0.3)
        ax1.legend()

        # 2. DP vs N_ch
        ax2 = axes[0, 1]
        nch_all = [r['N_ch'] for r in all_results]
        ax2.scatter(nch_all, dp_all, c=colors_all, alpha=0.3, s=5)
        ax2.scatter(best['N_ch'], best['DP_total_kPa'], c='gold', s=200, marker='*',
                   edgecolors='black', linewidths=1.5, zorder=5, label='Optimal')
        ax2.set_xlabel('Number of Channels')
        ax2.set_ylabel('Pressure Drop (kPa)')
        ax2.set_title('Pressure Drop vs Number of Channels')
        ax2.grid(True, alpha=0.3)
        ax2.legend()

        # 3. DP vs D_h
        ax3 = axes[0, 2]
        dh_all = [r['D_h']*1000 for r in all_results]
        ax3.scatter(dh_all, dp_all, c=colors_all, alpha=0.3, s=5)
        ax3.scatter(best['D_h']*1000, best['DP_total_kPa'], c='gold', s=200, marker='*',
                   edgecolors='black', linewidths=1.5, zorder=5, label='Optimal')
        ax3.set_xlabel('Hydraulic Diameter (mm)')
        ax3.set_ylabel('Pressure Drop (kPa)')
        ax3.set_title('Pressure Drop vs Hydraulic Diameter')
        ax3.grid(True, alpha=0.3)
        ax3.legend()

        # 4. Valid design space
        ax4 = axes[1, 0]
        gap_valid = [r['GAP']*1000 for r in valid_results]
        dp_valid = [r['DP_total_kPa'] for r in valid_results]
        margin2_valid = [r['A_margin2'] for r in valid_results]
        scatter = ax4.scatter(gap_valid, dp_valid, c=margin2_valid, cmap='viridis',
                             alpha=0.6, s=20, vmin=0, vmax=10)
        ax4.scatter(best['GAP']*1000, best['DP_total_kPa'], c='red', s=200, marker='*',
                   edgecolors='black', linewidths=1.5, zorder=5, label='Optimal')
        plt.colorbar(scatter, ax=ax4, label='S2 Area Margin (%)')
        ax4.set_xlabel('Annular Gap (mm)')
        ax4.set_ylabel('Pressure Drop (kPa)')
        ax4.set_title('Valid Designs: DP vs Gap (color = S2 margin)')
        ax4.grid(True, alpha=0.3)
        ax4.legend()

        # 5. Pareto front - DP vs S2 Margin
        ax5 = axes[1, 1]
        ax5.scatter(margin2_valid, dp_valid, c='steelblue', alpha=0.5, s=20)
        ax5.scatter(best['A_margin2'], best['DP_total_kPa'], c='red', s=200, marker='*',
                   edgecolors='black', linewidths=1.5, zorder=5, label='Optimal')
        ax5.set_xlabel('Section 2 Area Margin (%)')
        ax5.set_ylabel('Pressure Drop (kPa)')
        ax5.set_title('Trade-off: Pressure Drop vs Safety Margin')
        ax5.grid(True, alpha=0.3)
        ax5.legend()

        # 6. Channel geometry comparison
        ax6 = axes[1, 2]
        wch_valid = [r['w_ch']*1000 for r in valid_results]
        ax6.scatter(wch_valid, dp_valid, c=margin2_valid, cmap='viridis',
                   alpha=0.6, s=20, vmin=0, vmax=10)
        ax6.scatter(best['w_ch']*1000, best['DP_total_kPa'], c='red', s=200, marker='*',
                   edgecolors='black', linewidths=1.5, zorder=5, label='Optimal')
        ax6.set_xlabel('Channel Width (mm)')
        ax6.set_ylabel('Pressure Drop (kPa)')
        ax6.set_title('DP vs Channel Width')
        ax6.grid(True, alpha=0.3)
        ax6.legend()

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'optimization_analysis.png'), dpi=150)
        plt.close()

        # Create detailed comparison figure
        fig, axes = plt.subplots(2, 2, figsize=(14, 12))
        fig.suptitle('Detailed Design Comparison: Baseline vs Optimal', fontsize=14, fontweight='bold')

        # Bar chart comparison
        ax1 = axes[0, 0]
        params = ['GAP\n(mm)', 'N_ch', 't_fin\n(mm)', 'D_h\n(mm)', 'v\n(m/s×100)']
        baseline_vals = [
            baseline_res['GAP']*1000,
            baseline_res['N_ch'],
            BASELINE['t_fin']*1000,
            baseline_res['D_h']*1000,
            baseline_res['v']*100
        ]
        optimal_vals = [
            best['GAP']*1000,
            best['N_ch'],
            best['t_fin']*1000,
            best['D_h']*1000,
            best['v']*100
        ]

        x = np.arange(len(params))
        width = 0.35
        ax1.bar(x - width/2, baseline_vals, width, label='Baseline (Invalid)', color='red', alpha=0.7)
        ax1.bar(x + width/2, optimal_vals, width, label='Optimal (Valid)', color='green', alpha=0.7)
        ax1.set_xticks(x)
        ax1.set_xticklabels(params)
        ax1.set_ylabel('Value')
        ax1.set_title('Geometric Parameters Comparison')
        ax1.legend()
        ax1.grid(True, alpha=0.3, axis='y')

        # Performance metrics
        ax2 = axes[0, 1]
        metrics = ['DP Total\n(kPa)', 'h1\n(W/m²K)', 'h2\n(W/m²K)', 'Re1\n(×10)', 'Re2\n(×10)']
        baseline_perf = [
            baseline_res['DP_total_kPa'],
            baseline_res['h1'],
            baseline_res['h2'],
            baseline_res['Re1']*10,
            baseline_res['Re2']*10
        ]
        optimal_perf = [
            best['DP_total_kPa'],
            best['h1'],
            best['h2'],
            best['Re1']*10,
            best['Re2']*10
        ]

        x = np.arange(len(metrics))
        ax2.bar(x - width/2, baseline_perf, width, label='Baseline', color='red', alpha=0.7)
        ax2.bar(x + width/2, optimal_perf, width, label='Optimal', color='green', alpha=0.7)
        ax2.set_xticks(x)
        ax2.set_xticklabels(metrics)
        ax2.set_ylabel('Value')
        ax2.set_title('Performance Metrics Comparison')
        ax2.legend()
        ax2.grid(True, alpha=0.3, axis='y')

        # Area margins
        ax3 = axes[1, 0]
        sections = ['Section 1\n(Heating Zone)', 'Section 2\n(Constant Temp)']
        baseline_margins = [baseline_res['A_margin1'], baseline_res['A_margin2']]
        optimal_margins = [best['A_margin1'], best['A_margin2']]

        x = np.arange(len(sections))
        ax3.bar(x - width/2, baseline_margins, width, label='Baseline', color='red', alpha=0.7)
        ax3.bar(x + width/2, optimal_margins, width, label='Optimal', color='green', alpha=0.7)
        ax3.axhline(y=0, color='black', linestyle='--', linewidth=2)
        ax3.set_xticks(x)
        ax3.set_xticklabels(sections)
        ax3.set_ylabel('Area Margin (%)')
        ax3.set_title('Heat Transfer Area Margin\n(Negative = INSUFFICIENT)')
        ax3.legend()
        ax3.grid(True, alpha=0.3, axis='y')
        ax3.set_ylim(min(baseline_margins)-10, max(optimal_margins)+10)

        # Text summary
        ax4 = axes[1, 1]
        ax4.axis('off')
        summary_text = f"""
DESIGN COMPARISON SUMMARY
{'='*40}

BASELINE DESIGN (INVALID):
  Status: FAILED (insufficient S2 area)
  D_jacket = {BASELINE['D_jacket']} m
  GAP = {baseline_res['GAP']*1000:.2f} mm
  N_ch = {BASELINE['N_ch']} channels
  t_fin = {BASELINE['t_fin']*1000:.1f} mm
  DP_total = {baseline_res['DP_total_kPa']:.2f} kPa
  S1 Margin = {baseline_res['A_margin1']:.1f}%
  S2 Margin = {baseline_res['A_margin2']:.1f}% ← NEGATIVE!

OPTIMAL VALID DESIGN:
  Status: PASSED
  D_jacket = {best['D_jacket']:.4f} m
  GAP = {best['GAP']*1000:.2f} mm
  N_ch = {best['N_ch']} channels
  t_fin = {best['t_fin']*1000:.2f} mm
  DP_total = {best['DP_total_kPa']:.2f} kPa
  S1 Margin = {best['A_margin1']:.1f}%
  S2 Margin = {best['A_margin2']:.2f}% ← VALID!

KEY INSIGHT:
  The baseline design FAILS because Section 2
  requires higher heat transfer coefficient (h2).

  To achieve valid design:
  - Reduce gap: {baseline_res['GAP']*1000:.1f} → {best['GAP']*1000:.1f} mm
  - h2 increases: {baseline_res['h2']:.0f} → {best['h2']:.0f} W/m²K
  - Trade-off: DP increases {baseline_res['DP_total_kPa']:.0f} → {best['DP_total_kPa']:.0f} kPa
"""
        ax4.text(0.05, 0.95, summary_text, transform=ax4.transAxes, fontsize=10,
                verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'baseline_vs_optimal.png'), dpi=150)
        plt.close()

        # Create a schematic diagram
        fig, ax = plt.subplots(figsize=(14, 8))
        ax.set_xlim(0, 14)
        ax.set_ylim(0, 8)
        ax.set_aspect('equal')
        ax.axis('off')
        ax.set_title('Heating Jacket Cross-Section Schematic', fontsize=14, fontweight='bold')

        # Draw baseline cross-section
        # Outer circle (jacket)
        theta = np.linspace(0, 2*np.pi, 100)
        baseline_center = (3.5, 4)
        baseline_scale = 2.5

        r_pyr_base = FIXED['D_pyrolizer']/2 / 0.2 * baseline_scale
        r_jkt_base = BASELINE['D_jacket']/2 / 0.2 * baseline_scale

        x_pyr = baseline_center[0] + r_pyr_base * np.cos(theta)
        y_pyr = baseline_center[1] + r_pyr_base * np.sin(theta)
        x_jkt = baseline_center[0] + r_jkt_base * np.cos(theta)
        y_jkt = baseline_center[1] + r_jkt_base * np.sin(theta)

        ax.fill(x_jkt, y_jkt, color='lightgray', alpha=0.5)
        ax.fill(x_pyr, y_pyr, color='white')
        ax.plot(x_pyr, y_pyr, 'k-', linewidth=2)
        ax.plot(x_jkt, y_jkt, 'k-', linewidth=2)
        ax.annotate('', xy=(baseline_center[0]+r_jkt_base, baseline_center[1]),
                   xytext=(baseline_center[0]+r_pyr_base, baseline_center[1]),
                   arrowprops=dict(arrowstyle='<->', color='red'))
        ax.text(baseline_center[0]+r_pyr_base+0.2, baseline_center[1]+0.3,
               f'GAP={baseline_res["GAP"]*1000:.1f}mm', fontsize=9, color='red')
        ax.text(baseline_center[0], baseline_center[1]-2.5,
               f'BASELINE (INVALID)\nDP={baseline_res["DP_total_kPa"]:.1f} kPa\nS2 margin={baseline_res["A_margin2"]:.1f}%',
               ha='center', fontsize=10, color='red', fontweight='bold')

        # Draw optimal cross-section
        optimal_center = (10.5, 4)
        r_pyr_opt = FIXED['D_pyrolizer']/2 / 0.2 * baseline_scale
        r_jkt_opt = best['D_jacket']/2 / 0.2 * baseline_scale

        x_pyr_opt = optimal_center[0] + r_pyr_opt * np.cos(theta)
        y_pyr_opt = optimal_center[1] + r_pyr_opt * np.sin(theta)
        x_jkt_opt = optimal_center[0] + r_jkt_opt * np.cos(theta)
        y_jkt_opt = optimal_center[1] + r_jkt_opt * np.sin(theta)

        ax.fill(x_jkt_opt, y_jkt_opt, color='lightgreen', alpha=0.5)
        ax.fill(x_pyr_opt, y_pyr_opt, color='white')
        ax.plot(x_pyr_opt, y_pyr_opt, 'k-', linewidth=2)
        ax.plot(x_jkt_opt, y_jkt_opt, 'k-', linewidth=2)
        ax.annotate('', xy=(optimal_center[0]+r_jkt_opt, optimal_center[1]),
                   xytext=(optimal_center[0]+r_pyr_opt, optimal_center[1]),
                   arrowprops=dict(arrowstyle='<->', color='green'))
        ax.text(optimal_center[0]+r_pyr_opt+0.1, optimal_center[1]+0.3,
               f'GAP={best["GAP"]*1000:.1f}mm', fontsize=9, color='green')
        ax.text(optimal_center[0], optimal_center[1]-2.5,
               f'OPTIMAL (VALID)\nDP={best["DP_total_kPa"]:.1f} kPa\nS2 margin={best["A_margin2"]:.2f}%',
               ha='center', fontsize=10, color='green', fontweight='bold')

        # Arrow between
        ax.annotate('', xy=(6.5, 4), xytext=(5.5, 4),
                   arrowprops=dict(arrowstyle='->', color='black', lw=2))
        ax.text(6, 4.5, 'Reduce\nGap', ha='center', fontsize=10)

        # Labels
        ax.text(baseline_center[0], baseline_center[1], 'Pyrolizer\nShell', ha='center', va='center', fontsize=9)
        ax.text(optimal_center[0], optimal_center[1], 'Pyrolizer\nShell', ha='center', va='center', fontsize=9)

        plt.savefig(os.path.join(output_path, 'schematic_comparison.png'), dpi=150)
        plt.close()

        # Write comprehensive summary
        summary = []
        summary.append("="*70)
        summary.append("PARAMETRIC STUDY V3 - FINE-TUNED OPTIMIZATION SUMMARY")
        summary.append("="*70)
        summary.append(f"\nGenerated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        summary.append(f"\nTotal configurations tested: {total}")
        summary.append(f"Valid designs found: {len(valid_results)}")

        summary.append(f"\n{'='*70}")
        summary.append("BASELINE DESIGN (REFERENCE)")
        summary.append("="*70)
        summary.append(f"  D_jacket = {BASELINE['D_jacket']} m")
        summary.append(f"  GAP = {baseline_res['GAP']*1000:.2f} mm")
        summary.append(f"  N_ch = {BASELINE['N_ch']} channels")
        summary.append(f"  t_fin = {BASELINE['t_fin']*1000:.1f} mm")
        summary.append(f"  D_h = {baseline_res['D_h']*1000:.2f} mm")
        summary.append(f"  Flow velocity = {baseline_res['v']:.4f} m/s")
        summary.append(f"  h1 = {baseline_res['h1']:.2f} W/m²K")
        summary.append(f"  h2 = {baseline_res['h2']:.2f} W/m²K")
        summary.append(f"  DP_total = {baseline_res['DP_total_kPa']:.2f} kPa")
        summary.append(f"  Area Margin S1 = {baseline_res['A_margin1']:.1f}%")
        summary.append(f"  Area Margin S2 = {baseline_res['A_margin2']:.1f}% ← INSUFFICIENT!")
        summary.append(f"  STATUS: ***DESIGN FAILED***")

        summary.append(f"\n{'='*70}")
        summary.append("OPTIMAL VALID DESIGN")
        summary.append("="*70)
        summary.append(f"  D_jacket = {best['D_jacket']:.5f} m")
        summary.append(f"  GAP = {best['GAP']*1000:.3f} mm")
        summary.append(f"  N_ch = {best['N_ch']} channels")
        summary.append(f"  t_fin = {best['t_fin']*1000:.3f} mm")
        summary.append(f"  w_ch = {best['w_ch']*1000:.3f} mm")
        summary.append(f"  D_h = {best['D_h']*1000:.3f} mm")
        summary.append(f"  Flow velocity = {best['v']:.5f} m/s")
        summary.append(f"  h1 = {best['h1']:.2f} W/m²K")
        summary.append(f"  h2 = {best['h2']:.2f} W/m²K")
        summary.append(f"  DP_total = {best['DP_total_kPa']:.3f} kPa")
        summary.append(f"  Area Margin S1 = {best['A_margin1']:.2f}%")
        summary.append(f"  Area Margin S2 = {best['A_margin2']:.3f}%")
        summary.append(f"  STATUS: ***DESIGN SUCCESSFUL***")

        summary.append(f"\n{'='*70}")
        summary.append("KEY FINDINGS")
        summary.append("="*70)
        summary.append(f"\n1. BASELINE FAILURE REASON:")
        summary.append(f"   Section 2 requires A_req = {baseline_res['A_req2']:.3f} m²")
        summary.append(f"   Available area = {baseline_res['A_av2']:.3f} m² (FIXED by L2 and D_pyrolizer)")
        summary.append(f"   Deficit = {baseline_res['A_req2'] - baseline_res['A_av2']:.3f} m²")
        summary.append(f"\n2. SOLUTION:")
        summary.append(f"   Increase h2 (heat transfer coefficient) to reduce A_req2")
        summary.append(f"   h2 baseline = {baseline_res['h2']:.2f} W/m²K")
        summary.append(f"   h2 optimal  = {best['h2']:.2f} W/m²K")
        summary.append(f"   Improvement = {(best['h2']/baseline_res['h2']-1)*100:.1f}%")
        summary.append(f"\n3. TRADE-OFF:")
        summary.append(f"   Achieving higher h2 requires smaller gap and higher velocity")
        summary.append(f"   GAP: {baseline_res['GAP']*1000:.1f} mm → {best['GAP']*1000:.1f} mm ({(best['GAP']/baseline_res['GAP']-1)*100:.1f}%)")
        summary.append(f"   Velocity: {baseline_res['v']:.4f} → {best['v']:.4f} m/s ({(best['v']/baseline_res['v']-1)*100:.1f}%)")
        summary.append(f"   DP: {baseline_res['DP_total_kPa']:.1f} → {best['DP_total_kPa']:.1f} kPa ({(best['DP_total_kPa']/baseline_res['DP_total_kPa']-1)*100:.1f}%)")

        summary.append(f"\n{'='*70}")
        summary.append("CONCLUSION")
        summary.append("="*70)
        summary.append(f"\nThe minimum pressure drop achievable for a VALID design is")
        summary.append(f"{best['DP_total_kPa']:.2f} kPa, which is {(best['DP_total_kPa']/baseline_res['DP_total_kPa']):.1f}x higher than")
        summary.append(f"the baseline's {baseline_res['DP_total_kPa']:.2f} kPa.")
        summary.append(f"\nThis is an unavoidable trade-off because:")
        summary.append(f"- The fixed pyrolizer dimensions constrain available heat transfer area")
        summary.append(f"- Section 2 requires {(baseline_res['h2']/best['h2']):.1f}x higher h to meet heat duty")
        summary.append(f"- Higher h necessitates smaller gap and higher velocity")
        summary.append(f"- Both factors increase pressure drop significantly")

        summary_text = "\n".join(summary)
        print("\n" + summary_text)

        with open(os.path.join(output_path, 'study_summary_v3.txt'), 'w') as f:
            f.write(summary_text)

        # Save optimal design to JSON
        optimal_json = {k: (bool(v) if isinstance(v, (bool, np.bool_)) else
                           float(v) if isinstance(v, (float, np.floating, np.integer)) else v)
                       for k, v in best.items()}
        with open(os.path.join(output_path, 'optimal_design_v3.json'), 'w') as f:
            json.dump(optimal_json, f, indent=2)

    print(f"\n\nAll results saved to: {output_path}")
