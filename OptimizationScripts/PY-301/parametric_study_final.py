"""
Parametric Study FINAL - Ultra-Fine Optimization

Based on V3 results showing optimal around:
- D_jacket = 0.3386 m
- N_ch = 6 channels
- t_fin = 8.53 mm

This study performs ultra-fine grid search around the optimal region.
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
    print("PARAMETRIC STUDY FINAL - ULTRA-FINE OPTIMIZATION")
    print("="*70)

    baseline_res = calculate_design(**BASELINE)
    BASELINE_DP = baseline_res['DP_total_kPa']

    output_path = create_results_folder("_FINAL")
    print(f"Results folder: {output_path}")

    # Ultra-fine grid around optimal from V3
    print("\n--- Ultra-Fine Grid Search ---")

    all_results = []
    valid_results = []

    # V3 optimal: D_jacket=0.3386, N_ch=6, t_fin=8.53mm
    # Explore very fine around this
    D_jacket_range = np.linspace(0.335, 0.345, 200)
    N_ch_range = [5, 6, 7, 8]
    t_fin_range = np.linspace(0.001, 0.015, 200)

    total = len(D_jacket_range) * len(N_ch_range) * len(t_fin_range)
    print(f"Testing {total} configurations...")

    for D_jkt in D_jacket_range:
        for N_ch in N_ch_range:
            for t_fin in t_fin_range:
                res = calculate_design(D_jkt, N_ch, t_fin)
                if res is not None:
                    all_results.append(res)
                    if res['design_ok']:
                        valid_results.append(res)

    print(f"Valid designs found: {len(valid_results)} / {len(all_results)}")

    if valid_results:
        valid_results.sort(key=lambda x: x['DP_total_kPa'])
        best = valid_results[0]

        print(f"\n{'='*70}")
        print("FINAL OPTIMAL DESIGN")
        print("="*70)
        print(f"\n  D_jacket = {best['D_jacket']:.6f} m")
        print(f"  GAP = {best['GAP']*1000:.4f} mm")
        print(f"  N_ch = {best['N_ch']} channels")
        print(f"  t_fin = {best['t_fin']*1000:.4f} mm")
        print(f"  w_ch = {best['w_ch']*1000:.4f} mm")
        print(f"  D_h = {best['D_h']*1000:.4f} mm")
        print(f"  Flow velocity = {best['v']:.6f} m/s")
        print(f"  Reynolds S1 = {best['Re1']:.4f}")
        print(f"  Reynolds S2 = {best['Re2']:.4f}")
        print(f"  h1 = {best['h1']:.3f} W/m2K")
        print(f"  h2 = {best['h2']:.3f} W/m2K")
        print(f"  DP_total = {best['DP_total_kPa']:.4f} kPa")
        print(f"  Area Margin S1 = {best['A_margin1']:.3f}%")
        print(f"  Area Margin S2 = {best['A_margin2']:.4f}%")

        # Create comprehensive final report figure
        fig = plt.figure(figsize=(18, 14))

        # Title
        fig.suptitle('PYROLYSIS HEATING JACKET - FINAL OPTIMIZATION REPORT',
                    fontsize=16, fontweight='bold', y=0.98)

        # Subplot layout
        gs = fig.add_gridspec(3, 4, hspace=0.35, wspace=0.3)

        # 1. DP contour for valid designs
        ax1 = fig.add_subplot(gs[0, 0:2])
        gap_valid = [r['GAP']*1000 for r in valid_results]
        nch_valid = [r['N_ch'] for r in valid_results]
        dp_valid = [r['DP_total_kPa'] for r in valid_results]
        scatter = ax1.scatter(gap_valid, nch_valid, c=dp_valid, cmap='viridis',
                             s=20, alpha=0.7, vmin=min(dp_valid), vmax=min(dp_valid)+50)
        ax1.scatter(best['GAP']*1000, best['N_ch'], c='red', s=200, marker='*',
                   edgecolors='black', zorder=5, label=f'Optimal: {best["DP_total_kPa"]:.1f} kPa')
        plt.colorbar(scatter, ax=ax1, label='DP (kPa)')
        ax1.set_xlabel('Annular Gap (mm)')
        ax1.set_ylabel('Number of Channels')
        ax1.set_title('Valid Design Space')
        ax1.legend()
        ax1.grid(True, alpha=0.3)

        # 2. DP vs Gap
        ax2 = fig.add_subplot(gs[0, 2:4])
        ax2.scatter(gap_valid, dp_valid, c='steelblue', alpha=0.3, s=10)
        ax2.scatter(best['GAP']*1000, best['DP_total_kPa'], c='red', s=200, marker='*',
                   edgecolors='black', zorder=5, label='Optimal')
        ax2.set_xlabel('Annular Gap (mm)')
        ax2.set_ylabel('Pressure Drop (kPa)')
        ax2.set_title('Pressure Drop vs Gap')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

        # 3. Parameter comparison bar chart
        ax3 = fig.add_subplot(gs[1, 0:2])
        params = ['GAP (mm)', 'N_ch', 't_fin (mm)', 'D_h (mm)', 'v (mm/s)']
        baseline_vals = [baseline_res['GAP']*1000, baseline_res['N_ch'],
                        BASELINE['t_fin']*1000, baseline_res['D_h']*1000, baseline_res['v']*1000]
        optimal_vals = [best['GAP']*1000, best['N_ch'],
                       best['t_fin']*1000, best['D_h']*1000, best['v']*1000]

        x = np.arange(len(params))
        width = 0.35
        bars1 = ax3.bar(x - width/2, baseline_vals, width, label='Baseline (Invalid)', color='red', alpha=0.7)
        bars2 = ax3.bar(x + width/2, optimal_vals, width, label='Optimal (Valid)', color='green', alpha=0.7)
        ax3.set_xticks(x)
        ax3.set_xticklabels(params, fontsize=9)
        ax3.set_ylabel('Value')
        ax3.set_title('Geometry Comparison')
        ax3.legend()
        ax3.grid(True, alpha=0.3, axis='y')

        # 4. Heat transfer comparison
        ax4 = fig.add_subplot(gs[1, 2:4])
        ht_params = ['h1 (W/m2K)', 'h2 (W/m2K)', 'LMTD1 (K)', 'LMTD2 (K)']
        baseline_ht = [baseline_res['h1'], baseline_res['h2'], baseline_res['LMTD1'], baseline_res['LMTD2']]
        optimal_ht = [best['h1'], best['h2'], best['LMTD1'], best['LMTD2']]

        x = np.arange(len(ht_params))
        ax4.bar(x - width/2, baseline_ht, width, label='Baseline', color='red', alpha=0.7)
        ax4.bar(x + width/2, optimal_ht, width, label='Optimal', color='green', alpha=0.7)
        ax4.set_xticks(x)
        ax4.set_xticklabels(ht_params, fontsize=9)
        ax4.set_ylabel('Value')
        ax4.set_title('Heat Transfer Comparison')
        ax4.legend()
        ax4.grid(True, alpha=0.3, axis='y')

        # 5. Area margin comparison
        ax5 = fig.add_subplot(gs[2, 0])
        sections = ['S1', 'S2']
        baseline_margins = [baseline_res['A_margin1'], baseline_res['A_margin2']]
        optimal_margins = [best['A_margin1'], best['A_margin2']]

        x = np.arange(len(sections))
        width = 0.35
        ax5.bar(x - width/2, baseline_margins, width, label='Baseline', color='red', alpha=0.7)
        ax5.bar(x + width/2, optimal_margins, width, label='Optimal', color='green', alpha=0.7)
        ax5.axhline(y=0, color='black', linestyle='--', linewidth=2)
        ax5.set_xticks(x)
        ax5.set_xticklabels(sections)
        ax5.set_ylabel('Area Margin (%)')
        ax5.set_title('Heat Transfer Area Margin')
        ax5.legend()
        ax5.grid(True, alpha=0.3, axis='y')

        # 6. Pressure drop breakdown
        ax6 = fig.add_subplot(gs[2, 1])
        dp_parts = ['DP Section 1', 'DP Section 2']
        baseline_dp = [baseline_res['DP1_kPa'], baseline_res['DP2_kPa']]
        optimal_dp = [best['DP1_kPa'], best['DP2_kPa']]

        x = np.arange(len(dp_parts))
        ax6.bar(x - width/2, baseline_dp, width, label='Baseline', color='red', alpha=0.7)
        ax6.bar(x + width/2, optimal_dp, width, label='Optimal', color='green', alpha=0.7)
        ax6.set_xticks(x)
        ax6.set_xticklabels(dp_parts)
        ax6.set_ylabel('Pressure Drop (kPa)')
        ax6.set_title('Pressure Drop Breakdown')
        ax6.legend()
        ax6.grid(True, alpha=0.3, axis='y')

        # 7. Summary text box
        ax7 = fig.add_subplot(gs[2, 2:4])
        ax7.axis('off')

        summary_text = f"""
FINAL OPTIMIZATION SUMMARY
{'='*50}

BASELINE DESIGN (INVALID):
  D_jacket = {BASELINE['D_jacket']} m, N_ch = {BASELINE['N_ch']}, t_fin = {BASELINE['t_fin']*1000:.1f} mm
  DP = {baseline_res['DP_total_kPa']:.2f} kPa
  S2 Area Margin = {baseline_res['A_margin2']:.1f}% (FAIL)

OPTIMAL VALID DESIGN:
  D_jacket = {best['D_jacket']:.5f} m
  N_ch = {best['N_ch']} channels
  t_fin = {best['t_fin']*1000:.3f} mm
  GAP = {best['GAP']*1000:.3f} mm
  D_h = {best['D_h']*1000:.3f} mm
  DP = {best['DP_total_kPa']:.2f} kPa
  S2 Area Margin = {best['A_margin2']:.3f}% (PASS)

KEY CHANGES:
  Gap reduced: {baseline_res['GAP']*1000:.1f} -> {best['GAP']*1000:.1f} mm ({(1-best['GAP']/baseline_res['GAP'])*100:.0f}% smaller)
  h2 increased: {baseline_res['h2']:.0f} -> {best['h2']:.0f} W/m2K ({(best['h2']/baseline_res['h2']-1)*100:.0f}% higher)
  DP increased: {baseline_res['DP_total_kPa']:.1f} -> {best['DP_total_kPa']:.1f} kPa

CONCLUSION:
  Minimum achievable pressure drop for a valid design
  is {best['DP_total_kPa']:.1f} kPa. This is the fundamental
  trade-off required to achieve sufficient h2 for Section 2.
"""

        ax7.text(0.02, 0.98, summary_text, transform=ax7.transAxes, fontsize=10,
                verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle='round', facecolor='lightyellow', alpha=0.8))

        plt.savefig(os.path.join(output_path, 'FINAL_OPTIMIZATION_REPORT.png'), dpi=150, bbox_inches='tight')
        plt.close()

        # Create design schematic
        fig, axes = plt.subplots(1, 2, figsize=(14, 7))
        fig.suptitle('Cross-Section Comparison: Baseline vs Optimal', fontsize=14, fontweight='bold')

        for idx, (ax, design, title, color) in enumerate([
            (axes[0], baseline_res, f'BASELINE (INVALID)\nDP = {baseline_res["DP_total_kPa"]:.1f} kPa', 'red'),
            (axes[1], best, f'OPTIMAL (VALID)\nDP = {best["DP_total_kPa"]:.1f} kPa', 'green')
        ]):
            ax.set_aspect('equal')
            ax.set_xlim(-0.25, 0.25)
            ax.set_ylim(-0.25, 0.25)

            # Draw circles
            theta = np.linspace(0, 2*np.pi, 100)
            r_pyr = FIXED['D_pyrolizer'] / 2
            r_jkt = design['D_jacket'] / 2 if 'D_jacket' in design else BASELINE['D_jacket'] / 2

            ax.fill(r_jkt*np.cos(theta), r_jkt*np.sin(theta), color=color, alpha=0.3, label='Salt annulus')
            ax.fill(r_pyr*np.cos(theta), r_pyr*np.sin(theta), color='white')
            ax.plot(r_pyr*np.cos(theta), r_pyr*np.sin(theta), 'k-', linewidth=2, label='Pyrolizer wall')
            ax.plot(r_jkt*np.cos(theta), r_jkt*np.sin(theta), 'k-', linewidth=2, label='Jacket wall')

            # Draw channels/fins
            N = design['N_ch'] if idx == 1 else BASELINE['N_ch']
            t_f = design['t_fin'] if idx == 1 else BASELINE['t_fin']

            for i in range(N):
                angle = 2*np.pi*i/N
                x1 = r_pyr * np.cos(angle)
                y1 = r_pyr * np.sin(angle)
                x2 = r_jkt * np.cos(angle)
                y2 = r_jkt * np.sin(angle)
                ax.plot([x1, x2], [y1, y2], 'k-', linewidth=1)

            # Annotations
            gap = design['GAP'] if 'GAP' in design else (BASELINE['D_jacket'] - FIXED['D_pyrolizer'])/2
            ax.annotate('', xy=(r_jkt, 0), xytext=(r_pyr, 0),
                       arrowprops=dict(arrowstyle='<->', color='blue'))
            ax.text((r_pyr+r_jkt)/2, 0.02, f'GAP={gap*1000:.1f}mm', fontsize=9, ha='center')

            ax.set_title(title, fontsize=12, color=color, fontweight='bold')
            ax.set_xlabel('x (m)')
            ax.set_ylabel('y (m)')
            ax.grid(True, alpha=0.3)

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'cross_section_comparison.png'), dpi=150)
        plt.close()

        # Write final summary
        summary_lines = [
            "="*70,
            "PYROLYSIS HEATING JACKET - FINAL OPTIMIZATION REPORT",
            "="*70,
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Total configurations tested: {total}",
            f"Valid designs found: {len(valid_results)}",
            "",
            "="*70,
            "BASELINE DESIGN (REFERENCE - INVALID)",
            "="*70,
            f"  D_jacket = {BASELINE['D_jacket']} m",
            f"  GAP = {baseline_res['GAP']*1000:.2f} mm",
            f"  N_ch = {BASELINE['N_ch']} channels",
            f"  t_fin = {BASELINE['t_fin']*1000:.1f} mm",
            f"  D_h = {baseline_res['D_h']*1000:.2f} mm",
            f"  Velocity = {baseline_res['v']:.4f} m/s",
            f"  h1 = {baseline_res['h1']:.2f} W/m2K",
            f"  h2 = {baseline_res['h2']:.2f} W/m2K",
            f"  DP_total = {baseline_res['DP_total_kPa']:.2f} kPa",
            f"  Area Margin S1 = {baseline_res['A_margin1']:.1f}%",
            f"  Area Margin S2 = {baseline_res['A_margin2']:.1f}% <-- INSUFFICIENT",
            f"  STATUS: DESIGN FAILED",
            "",
            "="*70,
            "OPTIMAL VALID DESIGN",
            "="*70,
            f"  D_jacket = {best['D_jacket']:.6f} m",
            f"  GAP = {best['GAP']*1000:.4f} mm",
            f"  N_ch = {best['N_ch']} channels",
            f"  t_fin = {best['t_fin']*1000:.4f} mm",
            f"  w_ch = {best['w_ch']*1000:.4f} mm",
            f"  D_h = {best['D_h']*1000:.4f} mm",
            f"  A_c = {best['A_c']*1e6:.4f} mm2",
            f"  Velocity = {best['v']:.6f} m/s",
            f"  Re1 = {best['Re1']:.4f}",
            f"  Re2 = {best['Re2']:.4f}",
            f"  h1 = {best['h1']:.3f} W/m2K",
            f"  h2 = {best['h2']:.3f} W/m2K",
            f"  LMTD1 = {best['LMTD1']:.2f} K",
            f"  LMTD2 = {best['LMTD2']:.2f} K",
            f"  A_req1 = {best['A_req1']:.4f} m2, A_av1 = {best['A_av1']:.4f} m2",
            f"  A_req2 = {best['A_req2']:.4f} m2, A_av2 = {best['A_av2']:.4f} m2",
            f"  DP1 = {best['DP1_kPa']:.3f} kPa",
            f"  DP2 = {best['DP2_kPa']:.3f} kPa",
            f"  DP_total = {best['DP_total_kPa']:.4f} kPa",
            f"  Area Margin S1 = {best['A_margin1']:.3f}%",
            f"  Area Margin S2 = {best['A_margin2']:.4f}%",
            f"  STATUS: DESIGN SUCCESSFUL",
            "",
            "="*70,
            "DESIGN CHANGES SUMMARY",
            "="*70,
            f"  GAP: {baseline_res['GAP']*1000:.2f} -> {best['GAP']*1000:.2f} mm ({(1-best['GAP']/baseline_res['GAP'])*100:.1f}% reduction)",
            f"  N_ch: {BASELINE['N_ch']} -> {best['N_ch']} channels",
            f"  t_fin: {BASELINE['t_fin']*1000:.1f} -> {best['t_fin']*1000:.2f} mm",
            f"  D_h: {baseline_res['D_h']*1000:.2f} -> {best['D_h']*1000:.2f} mm",
            f"  Velocity: {baseline_res['v']:.4f} -> {best['v']:.4f} m/s ({(best['v']/baseline_res['v']-1)*100:.1f}% increase)",
            f"  h2: {baseline_res['h2']:.2f} -> {best['h2']:.2f} W/m2K ({(best['h2']/baseline_res['h2']-1)*100:.1f}% increase)",
            f"  DP: {baseline_res['DP_total_kPa']:.2f} -> {best['DP_total_kPa']:.2f} kPa ({(best['DP_total_kPa']/baseline_res['DP_total_kPa']-1)*100:.1f}% increase)",
            "",
            "="*70,
            "KEY FINDINGS",
            "="*70,
            "",
            "1. The baseline design FAILS because Section 2 has insufficient",
            "   heat transfer area. The required area exceeds available area:",
            f"   A_req2 = {baseline_res['A_req2']:.3f} m2 > A_av2 = {baseline_res['A_av2']:.3f} m2",
            "",
            "2. To make the design valid, h2 must increase to reduce A_req2.",
            "   Required h2 increase: from 123.9 to 184.9 W/m2K (49% increase)",
            "",
            "3. Higher h2 is achieved by:",
            "   - Reducing the annular gap (increases velocity and turbulence)",
            "   - Adjusting channel geometry for optimal hydraulic diameter",
            "",
            "4. The trade-off is unavoidable: smaller gap and higher velocity",
            "   result in higher pressure drop.",
            "",
            "5. MINIMUM ACHIEVABLE PRESSURE DROP FOR VALID DESIGN:",
            f"   DP = {best['DP_total_kPa']:.2f} kPa",
            "",
            "="*70,
            "RECOMMENDATIONS",
            "="*70,
            "",
            f"1. Implement optimal design with D_jacket = {best['D_jacket']:.4f} m",
            f"2. Use {best['N_ch']} axial channels with {best['t_fin']*1000:.2f} mm fin thickness",
            f"3. Ensure pump can handle {best['DP_total_kPa']:.1f} kPa pressure drop",
            "4. Consider insulation to reduce heat losses given smaller gap",
            "5. Monitor Section 2 performance closely (minimal margin)",
            "",
        ]

        summary_text = "\n".join(summary_lines)
        print("\n" + summary_text)

        with open(os.path.join(output_path, 'FINAL_SUMMARY.txt'), 'w') as f:
            f.write(summary_text)

        # Save optimal design JSON
        optimal_json = {k: (bool(v) if isinstance(v, (bool, np.bool_)) else
                           float(v) if isinstance(v, (float, np.floating, np.integer)) else v)
                       for k, v in best.items()}
        with open(os.path.join(output_path, 'optimal_design_FINAL.json'), 'w') as f:
            json.dump(optimal_json, f, indent=2)

        # Save top 10 designs
        top10 = valid_results[:10]
        top10_json = [{k: (bool(v) if isinstance(v, (bool, np.bool_)) else
                          float(v) if isinstance(v, (float, np.floating, np.integer)) else v)
                      for k, v in r.items()} for r in top10]
        with open(os.path.join(output_path, 'top_10_designs.json'), 'w') as f:
            json.dump(top10_json, f, indent=2)

    print(f"\n\nAll results saved to: {output_path}")
