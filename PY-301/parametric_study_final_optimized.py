"""
FINAL OPTIMIZED PARAMETRIC STUDY

Based on enhanced study results showing optimal around:
- D_jacket = 0.42 m (large gap)
- N_ch = 7 channels
- 7 longitudinal fins per channel
- Fin height = 15 mm

This study performs ultra-fine optimization to find absolute minimum DP.
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
    'k_wall': 20.0,
    'mu_A': 0.0852,
    'mu_Ea': 3.51e4,
    'R_gas': 8.314,
}

BASELINE = {'D_jacket': 0.358, 'N_ch': 10, 't_fin': 0.005}


def viscosity(T_K):
    return FIXED['mu_A'] * np.exp(FIXED['mu_Ea'] / (FIXED['R_gas'] * T_K))


def fin_efficiency(h, fin_height, fin_thickness, k_fin):
    if fin_height <= 0 or fin_thickness <= 0:
        return 1.0
    m = np.sqrt(2 * h / (k_fin * fin_thickness))
    mL = m * fin_height
    if mL < 0.01:
        return 1.0
    return np.tanh(mL) / mL


def calculate_design_enhanced(D_jacket, N_ch, t_fin,
                               n_longitudinal_fins=0,
                               longitudinal_fin_height=0.005,
                               longitudinal_fin_thickness=0.002):
    D_pyr = FIXED['D_pyrolizer']
    L1, L2 = FIXED['L1'], FIXED['L2']
    T_hot1 = FIXED['T_hot1_C'] + 273.15
    m_dot = FIXED['m_dot']
    Q1, Q2 = FIXED['Q1'], FIXED['Q2']
    T_cold_in = FIXED['T_cold_in_C'] + 273.15
    T_cold_out = FIXED['T_cold_out_C'] + 273.15
    rho, Cp, k_f = FIXED['rho'], FIXED['Cp'], FIXED['k_fluid']
    k_wall = FIXED['k_wall']

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

    if longitudinal_fin_height > GAP * 0.8:
        return None

    A_fin_blockage = n_longitudinal_fins * longitudinal_fin_height * longitudinal_fin_thickness
    A_c = w_ch * GAP - A_fin_blockage
    if A_c <= 0:
        return None

    P_base = 2 * w_ch + 2 * GAP
    P_fins = 2 * n_longitudinal_fins * longitudinal_fin_height
    P_total = P_base + P_fins
    D_h = 4 * A_c / P_total

    v = m_dot / (rho * N_ch * A_c)

    mu1 = viscosity(T_hot_avg1)
    mu_wall = viscosity(T_cold_out)
    Re1 = rho * v * D_h / mu1
    Pr1 = Cp * mu1 / k_f
    Gz1 = Re1 * Pr1 * D_h / L1
    Nu1 = 1.86 * (Gz1 ** (1/3)) * ((mu1 / mu_wall) ** 0.14)
    h1_base = Nu1 * k_f / D_h

    mu2 = viscosity(T_hot_avg2)
    Re2 = rho * v * D_h / mu2
    Pr2 = Cp * mu2 / k_f
    Gz2 = Re2 * Pr2 * D_h / L2
    Nu2 = 1.86 * (Gz2 ** (1/3)) * ((mu2 / mu_wall) ** 0.14)
    h2_base = Nu2 * k_f / D_h

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

    A_base1 = np.pi * D_pyr * L1
    A_base2 = np.pi * D_pyr * L2

    A_fin_per_channel1 = n_longitudinal_fins * 2 * longitudinal_fin_height * L1
    A_fin_per_channel2 = n_longitudinal_fins * 2 * longitudinal_fin_height * L2
    A_fin_total1 = N_ch * A_fin_per_channel1
    A_fin_total2 = N_ch * A_fin_per_channel2

    eta1 = fin_efficiency(h1_base, longitudinal_fin_height, longitudinal_fin_thickness, k_wall)
    eta2 = fin_efficiency(h2_base, longitudinal_fin_height, longitudinal_fin_thickness, k_wall)

    A_eff1 = A_base1 + eta1 * A_fin_total1
    A_eff2 = A_base2 + eta2 * A_fin_total2

    enhancement1 = A_eff1 / A_base1
    enhancement2 = A_eff2 / A_base2

    A_req1 = Q1 / (h1_base * LMTD1)
    A_req2 = Q2 / (h2_base * LMTD2)

    design_ok = (A_eff1 >= A_req1) and (A_eff2 >= A_req2)

    fin_friction_factor = 1.0 + 0.5 * (P_fins / P_base)

    f1 = 16 / Re1 * fin_friction_factor
    DP1 = 4 * f1 * (L1 / D_h) * (rho * v**2 / 2)

    f2 = 16 / Re2 * fin_friction_factor
    DP2 = 4 * f2 * (L2 / D_h) * (rho * v**2 / 2)

    DP_total = DP1 + DP2

    return {
        'D_jacket': D_jacket, 'N_ch': N_ch, 't_fin': t_fin,
        'n_longitudinal_fins': n_longitudinal_fins,
        'longitudinal_fin_height': longitudinal_fin_height,
        'longitudinal_fin_thickness': longitudinal_fin_thickness,
        'w_ch': w_ch, 'GAP': GAP, 'A_c': A_c, 'D_h': D_h, 'v': v,
        'Re1': Re1, 'Re2': Re2,
        'h1': h1_base, 'h2': h2_base,
        'eta1': eta1, 'eta2': eta2,
        'LMTD1': LMTD1, 'LMTD2': LMTD2,
        'A_req1': A_req1, 'A_base1': A_base1, 'A_eff1': A_eff1,
        'A_req2': A_req2, 'A_base2': A_base2, 'A_eff2': A_eff2,
        'enhancement1': enhancement1, 'enhancement2': enhancement2,
        'A_margin1': (A_eff1 - A_req1) / A_eff1 * 100,
        'A_margin2': (A_eff2 - A_req2) / A_eff2 * 100,
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
    print("FINAL OPTIMIZED STUDY - MINIMUM PRESSURE DROP")
    print("="*70)

    baseline_res = calculate_design_enhanced(**BASELINE, n_longitudinal_fins=0)
    BASELINE_DP = baseline_res['DP_total_kPa']

    output_path = create_results_folder("_FINAL_OPTIMIZED")
    print(f"Results folder: {output_path}")

    # Ultra-fine grid around optimal region
    print("\n--- Ultra-Fine Grid Search ---")

    valid_low_dp = []

    # Expand jacket diameter range for even lower DP
    D_jacket_range = np.linspace(0.40, 0.50, 50)  # Larger gaps
    N_ch_range = range(5, 12)
    t_fin_range = np.linspace(0.002, 0.006, 10)
    n_fins_range = range(5, 10)
    fin_height_range = np.linspace(0.012, 0.025, 20)  # Taller fins
    fin_thickness_range = np.linspace(0.003, 0.006, 8)

    total = (len(D_jacket_range) * len(N_ch_range) * len(t_fin_range) *
             len(n_fins_range) * len(fin_height_range) * len(fin_thickness_range))
    print(f"Testing {total} configurations...")

    for D_jkt in D_jacket_range:
        for N_ch in N_ch_range:
            for t_fin in t_fin_range:
                for n_fins in n_fins_range:
                    for fin_h in fin_height_range:
                        for fin_t in fin_thickness_range:
                            res = calculate_design_enhanced(
                                D_jkt, N_ch, t_fin,
                                n_longitudinal_fins=n_fins,
                                longitudinal_fin_height=fin_h,
                                longitudinal_fin_thickness=fin_t
                            )
                            if res is not None and res['design_ok']:
                                if res['DP_total_kPa'] < BASELINE_DP:
                                    valid_low_dp.append(res)

    print(f"Valid with DP < baseline: {len(valid_low_dp)}")

    if valid_low_dp:
        valid_low_dp.sort(key=lambda x: x['DP_total_kPa'])
        best = valid_low_dp[0]

        print(f"\n{'='*70}")
        print("ABSOLUTE MINIMUM PRESSURE DROP DESIGN")
        print("="*70)
        print(f"\n  D_jacket = {best['D_jacket']:.5f} m")
        print(f"  GAP = {best['GAP']*1000:.3f} mm")
        print(f"  N_ch = {best['N_ch']} channels")
        print(f"  t_fin = {best['t_fin']*1000:.3f} mm")
        print(f"\n  LONGITUDINAL FINS:")
        print(f"    Number per channel = {best['n_longitudinal_fins']}")
        print(f"    Height = {best['longitudinal_fin_height']*1000:.3f} mm")
        print(f"    Thickness = {best['longitudinal_fin_thickness']*1000:.3f} mm")
        print(f"    Fin efficiency S2 = {best['eta2']:.4f}")
        print(f"\n  PERFORMANCE:")
        print(f"    DP_total = {best['DP_total_kPa']:.4f} kPa")
        print(f"    DP REDUCTION = {(1-best['DP_total_kPa']/BASELINE_DP)*100:.2f}%")
        print(f"    Velocity = {best['v']*1000:.4f} mm/s")
        print(f"    Area Enhancement S2 = {best['enhancement2']:.3f}x")
        print(f"    S2 Area Margin = {best['A_margin2']:.3f}%")

        # Create comprehensive report figure
        fig = plt.figure(figsize=(18, 14))
        fig.suptitle('FINAL OPTIMIZED DESIGN REPORT\nPyrolysis Heating Jacket with Longitudinal Fins',
                    fontsize=16, fontweight='bold')

        # 1. DP distribution
        ax1 = fig.add_subplot(2, 3, 1)
        dp_vals = [r['DP_total_kPa'] for r in valid_low_dp[:1000]]
        ax1.hist(dp_vals, bins=50, color='steelblue', edgecolor='black', alpha=0.7)
        ax1.axvline(x=best['DP_total_kPa'], color='red', linewidth=2,
                   label=f'Min: {best["DP_total_kPa"]:.2f} kPa')
        ax1.axvline(x=BASELINE_DP, color='orange', linewidth=2, linestyle='--',
                   label=f'Baseline: {BASELINE_DP:.2f} kPa')
        ax1.set_xlabel('Pressure Drop (kPa)')
        ax1.set_ylabel('Count')
        ax1.set_title('Distribution of Valid Design Pressure Drops')
        ax1.legend()
        ax1.grid(True, alpha=0.3)

        # 2. DP vs GAP
        ax2 = fig.add_subplot(2, 3, 2)
        gap_vals = [r['GAP']*1000 for r in valid_low_dp]
        dp_all = [r['DP_total_kPa'] for r in valid_low_dp]
        ax2.scatter(gap_vals, dp_all, c='green', alpha=0.3, s=5)
        ax2.scatter(best['GAP']*1000, best['DP_total_kPa'], c='red', s=200, marker='*',
                   edgecolors='black', zorder=5, label='Optimal')
        ax2.axhline(y=BASELINE_DP, color='orange', linestyle='--', label='Baseline')
        ax2.set_xlabel('Annular Gap (mm)')
        ax2.set_ylabel('Pressure Drop (kPa)')
        ax2.set_title('DP vs Gap (larger gap = lower DP)')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

        # 3. DP vs Fin Height
        ax3 = fig.add_subplot(2, 3, 3)
        fh_vals = [r['longitudinal_fin_height']*1000 for r in valid_low_dp]
        ax3.scatter(fh_vals, dp_all, c='purple', alpha=0.3, s=5)
        ax3.scatter(best['longitudinal_fin_height']*1000, best['DP_total_kPa'],
                   c='red', s=200, marker='*', edgecolors='black', zorder=5)
        ax3.axhline(y=BASELINE_DP, color='orange', linestyle='--')
        ax3.set_xlabel('Fin Height (mm)')
        ax3.set_ylabel('Pressure Drop (kPa)')
        ax3.set_title('DP vs Fin Height')
        ax3.grid(True, alpha=0.3)

        # 4. Parameter comparison
        ax4 = fig.add_subplot(2, 3, 4)
        params = ['GAP\n(mm)', 'N_ch', 'n_fins', 'fin_h\n(mm)', 'v\n(mm/s)']
        baseline_vals = [baseline_res['GAP']*1000, baseline_res['N_ch'], 0, 0, baseline_res['v']*1000]
        optimal_vals = [best['GAP']*1000, best['N_ch'], best['n_longitudinal_fins'],
                       best['longitudinal_fin_height']*1000, best['v']*1000]

        x = np.arange(len(params))
        width = 0.35
        ax4.bar(x - width/2, baseline_vals, width, label='Baseline (Invalid)', color='red', alpha=0.7)
        ax4.bar(x + width/2, optimal_vals, width, label='Optimal (Valid)', color='green', alpha=0.7)
        ax4.set_xticks(x)
        ax4.set_xticklabels(params)
        ax4.set_ylabel('Value')
        ax4.set_title('Geometry Comparison')
        ax4.legend()
        ax4.grid(True, alpha=0.3, axis='y')

        # 5. Area analysis
        ax5 = fig.add_subplot(2, 3, 5)
        areas = ['A_req2', 'A_base2', 'A_eff2']
        baseline_areas = [baseline_res['A_req2'], baseline_res['A_base2'], baseline_res['A_eff2']]
        optimal_areas = [best['A_req2'], best['A_base2'], best['A_eff2']]

        x = np.arange(len(areas))
        ax5.bar(x - width/2, baseline_areas, width, label='Baseline', color='red', alpha=0.7)
        ax5.bar(x + width/2, optimal_areas, width, label='Optimal', color='green', alpha=0.7)
        ax5.set_xticks(x)
        ax5.set_xticklabels(['Required\nArea', 'Base\nArea', 'Effective\nArea'])
        ax5.set_ylabel('Area (m2)')
        ax5.set_title('Section 2 Heat Transfer Area\n(Need: A_eff >= A_req)')
        ax5.legend()
        ax5.grid(True, alpha=0.3, axis='y')

        # 6. Summary text
        ax6 = fig.add_subplot(2, 3, 6)
        ax6.axis('off')

        summary_text = f"""
FINAL OPTIMIZATION RESULTS
{'='*50}

BASELINE (INVALID):
  D_jacket = {BASELINE['D_jacket']} m, GAP = {baseline_res['GAP']*1000:.1f} mm
  DP = {BASELINE_DP:.2f} kPa
  No longitudinal fins
  S2 Margin = {baseline_res['A_margin2']:.1f}% (FAIL)

OPTIMAL DESIGN (VALID):
  D_jacket = {best['D_jacket']:.4f} m
  GAP = {best['GAP']*1000:.2f} mm
  N_ch = {best['N_ch']} channels
  t_fin = {best['t_fin']*1000:.2f} mm

  Longitudinal Fins (RIB GEOMETRY):
    {best['n_longitudinal_fins']} fins per channel
    Height = {best['longitudinal_fin_height']*1000:.2f} mm
    Thickness = {best['longitudinal_fin_thickness']*1000:.2f} mm
    Total fin area = {best['A_eff2'] - best['A_base2']:.2f} m2

  Results:
    DP = {best['DP_total_kPa']:.2f} kPa
    DP REDUCTION = {(1-best['DP_total_kPa']/BASELINE_DP)*100:.1f}%
    S2 Margin = {best['A_margin2']:.2f}%

CONCLUSION:
  By adding longitudinal fins, we achieve:
  - {(1-best['DP_total_kPa']/BASELINE_DP)*100:.0f}% lower pressure drop
  - Valid heat transfer design
  - Larger gap = lower velocity = lower DP
"""
        ax6.text(0.02, 0.98, summary_text, transform=ax6.transAxes, fontsize=10,
                verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.8))

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'FINAL_REPORT.png'), dpi=150, bbox_inches='tight')
        plt.close()

        # Create cross-section schematic
        fig, axes = plt.subplots(1, 2, figsize=(16, 8))
        fig.suptitle('Channel Cross-Section Comparison', fontsize=14, fontweight='bold')

        for idx, (ax, data, title, color) in enumerate([
            (axes[0], baseline_res, f'BASELINE (No Fins)\nDP = {BASELINE_DP:.1f} kPa\nSTATUS: INVALID', 'red'),
            (axes[1], best, f'OPTIMAL (With Fins)\nDP = {best["DP_total_kPa"]:.1f} kPa\nSTATUS: VALID', 'green')
        ]):
            gap = data['GAP']
            w = 0.12

            ax.set_xlim(-0.08, 0.08)
            ax.set_ylim(-0.005, gap + 0.01)

            # Channel
            ax.fill([-w/2, w/2, w/2, -w/2], [0, 0, gap, gap], color=color, alpha=0.2)
            ax.plot([-w/2, w/2], [0, 0], 'k-', linewidth=4, label='Pyrolizer wall')
            ax.plot([-w/2, w/2], [gap, gap], 'k-', linewidth=3, label='Jacket wall')
            ax.plot([-w/2, -w/2], [0, gap], 'k-', linewidth=2)
            ax.plot([w/2, w/2], [0, gap], 'k-', linewidth=2)

            # Fins
            if idx == 1:
                n_fins = data['n_longitudinal_fins']
                fin_h = data['longitudinal_fin_height']
                fin_t = data['longitudinal_fin_thickness']
                spacing = w / (n_fins + 1)
                for i in range(n_fins):
                    x_pos = -w/2 + spacing * (i + 1)
                    ax.fill([x_pos-fin_t/2, x_pos+fin_t/2, x_pos+fin_t/2, x_pos-fin_t/2],
                           [0, 0, fin_h, fin_h], color='gray', edgecolor='black', linewidth=0.5)
                ax.text(0, fin_h/2, f'{n_fins} fins\nh={fin_h*1000:.0f}mm', ha='center', fontsize=9)

            # Gap annotation
            ax.annotate('', xy=(w/2+0.01, gap), xytext=(w/2+0.01, 0),
                       arrowprops=dict(arrowstyle='<->', color='blue', lw=2))
            ax.text(w/2+0.02, gap/2, f'GAP\n{gap*1000:.1f}mm', fontsize=10, va='center', color='blue')

            ax.set_xlabel('Channel Width (m)')
            ax.set_ylabel('Channel Height (m)')
            ax.set_title(title, color=color, fontweight='bold', fontsize=12)
            ax.set_aspect('equal')
            ax.grid(True, alpha=0.3)

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'cross_section_final.png'), dpi=150)
        plt.close()

        # Write summary
        summary_lines = [
            "="*70,
            "FINAL OPTIMIZED DESIGN - MINIMUM PRESSURE DROP",
            "="*70,
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Configurations tested: {total}",
            f"Valid designs with DP < baseline: {len(valid_low_dp)}",
            "",
            "="*70,
            "BASELINE DESIGN (REFERENCE - INVALID)",
            "="*70,
            f"  D_jacket = {BASELINE['D_jacket']} m",
            f"  GAP = {baseline_res['GAP']*1000:.2f} mm",
            f"  N_ch = {BASELINE['N_ch']} channels",
            f"  t_fin = {BASELINE['t_fin']*1000:.1f} mm",
            f"  No longitudinal fins",
            f"  Velocity = {baseline_res['v']*1000:.3f} mm/s",
            f"  DP_total = {BASELINE_DP:.2f} kPa",
            f"  S2 Area Margin = {baseline_res['A_margin2']:.1f}% (FAIL)",
            "",
            "="*70,
            "OPTIMAL DESIGN (MINIMUM PRESSURE DROP)",
            "="*70,
            f"  D_jacket = {best['D_jacket']:.5f} m",
            f"  GAP = {best['GAP']*1000:.3f} mm",
            f"  N_ch = {best['N_ch']} channels",
            f"  t_fin = {best['t_fin']*1000:.3f} mm",
            "",
            "  LONGITUDINAL FINS (Rib Geometry Modification):",
            f"    Number per channel = {best['n_longitudinal_fins']}",
            f"    Height = {best['longitudinal_fin_height']*1000:.3f} mm",
            f"    Thickness = {best['longitudinal_fin_thickness']*1000:.3f} mm",
            f"    Fin efficiency S1 = {best['eta1']:.4f}",
            f"    Fin efficiency S2 = {best['eta2']:.4f}",
            "",
            "  FLOW PARAMETERS:",
            f"    D_h = {best['D_h']*1000:.3f} mm",
            f"    Velocity = {best['v']*1000:.4f} mm/s",
            f"    Re1 = {best['Re1']:.5f}",
            f"    Re2 = {best['Re2']:.5f}",
            "",
            "  HEAT TRANSFER:",
            f"    h1 = {best['h1']:.3f} W/m2K",
            f"    h2 = {best['h2']:.3f} W/m2K",
            f"    Area enhancement S1 = {best['enhancement1']:.3f}x",
            f"    Area enhancement S2 = {best['enhancement2']:.3f}x",
            f"    A_base2 = {best['A_base2']:.4f} m2",
            f"    A_eff2 = {best['A_eff2']:.4f} m2",
            f"    A_req2 = {best['A_req2']:.4f} m2",
            "",
            "  PERFORMANCE:",
            f"    DP1 = {best['DP1_kPa']:.4f} kPa",
            f"    DP2 = {best['DP2_kPa']:.4f} kPa",
            f"    DP_total = {best['DP_total_kPa']:.4f} kPa",
            f"    DP REDUCTION = {(1-best['DP_total_kPa']/BASELINE_DP)*100:.2f}%",
            f"    S1 Area Margin = {best['A_margin1']:.3f}%",
            f"    S2 Area Margin = {best['A_margin2']:.3f}%",
            f"    STATUS: DESIGN SUCCESSFUL",
            "",
            "="*70,
            "SUMMARY OF CHANGES FROM BASELINE",
            "="*70,
            f"  GAP: {baseline_res['GAP']*1000:.1f} -> {best['GAP']*1000:.1f} mm (+{(best['GAP']/baseline_res['GAP']-1)*100:.0f}%)",
            f"  N_ch: {BASELINE['N_ch']} -> {best['N_ch']}",
            f"  Fins: 0 -> {best['n_longitudinal_fins']} per channel",
            f"  Fin height: 0 -> {best['longitudinal_fin_height']*1000:.1f} mm",
            f"  Velocity: {baseline_res['v']*1000:.2f} -> {best['v']*1000:.2f} mm/s ({(best['v']/baseline_res['v']-1)*100:.0f}%)",
            f"  DP: {BASELINE_DP:.2f} -> {best['DP_total_kPa']:.2f} kPa ({(best['DP_total_kPa']/BASELINE_DP-1)*100:.0f}%)",
            "",
            "="*70,
            "KEY INSIGHT",
            "="*70,
            "",
            "The baseline design fails because Section 2 lacks sufficient heat",
            "transfer area. By adding longitudinal fins inside the channels,",
            "we INCREASE effective heat transfer area, which allows us to:",
            "",
            "  1. Use a LARGER annular gap (more space between pyrolizer and jacket)",
            "  2. Achieve LOWER flow velocity (same mass flow through larger area)",
            "  3. Obtain LOWER pressure drop (DP proportional to velocity squared)",
            "",
            f"Result: {(1-best['DP_total_kPa']/BASELINE_DP)*100:.0f}% reduction in pressure drop",
            "while achieving a valid heat transfer design.",
            "",
        ]

        summary_text = "\n".join(summary_lines)
        print("\n" + summary_text)

        with open(os.path.join(output_path, 'FINAL_SUMMARY.txt'), 'w') as f:
            f.write(summary_text)

        # Save optimal design
        optimal_json = {k: (bool(v) if isinstance(v, (bool, np.bool_)) else
                           float(v) if isinstance(v, (float, np.floating, np.integer)) else v)
                       for k, v in best.items()}
        with open(os.path.join(output_path, 'OPTIMAL_DESIGN.json'), 'w') as f:
            json.dump(optimal_json, f, indent=2)

        # Save top 10
        top10 = [{k: (bool(v) if isinstance(v, (bool, np.bool_)) else
                     float(v) if isinstance(v, (float, np.floating, np.integer)) else v)
                 for k, v in r.items()} for r in valid_low_dp[:10]]
        with open(os.path.join(output_path, 'TOP_10_DESIGNS.json'), 'w') as f:
            json.dump(top10, f, indent=2)

    print(f"\n\nAll results saved to: {output_path}")
