"""
Parametric Study with Enhanced Heat Transfer Surfaces

KEY INSIGHT: The baseline fails because Section 2 needs higher heat transfer.
Previous studies achieved this by reducing gap (higher velocity = higher h),
but this dramatically increases pressure drop.

ALTERNATIVE APPROACH: Add internal ribs/fins to the channel walls to enhance
effective heat transfer area. This allows us to keep larger gap (lower velocity,
lower DP) while still meeting heat transfer requirements.

New parameters (rib geometry):
- fin_height: Height of internal ribs (m)
- fin_pitch: Spacing between ribs (m)
- fin_thickness_internal: Thickness of internal ribs (m)
- n_fins_per_channel: Number of longitudinal fins per channel

This increases effective heat transfer area without significantly increasing DP.
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
    'k_wall': 20.0,  # W/m/K - thermal conductivity of wall/fin material (steel)
    'mu_A': 0.0852,
    'mu_Ea': 3.51e4,
    'R_gas': 8.314,
}

BASELINE = {'D_jacket': 0.358, 'N_ch': 10, 't_fin': 0.005}


def viscosity(T_K):
    return FIXED['mu_A'] * np.exp(FIXED['mu_Ea'] / (FIXED['R_gas'] * T_K))


def fin_efficiency(h, fin_height, fin_thickness, k_fin):
    """
    Calculate fin efficiency for rectangular fin.
    eta = tanh(m*L) / (m*L) where m = sqrt(2*h/(k*t))
    """
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
    """
    Calculate design with optional longitudinal fins inside channels.

    Longitudinal fins run along the length of the channel on the pyrolizer wall,
    increasing the effective heat transfer area.
    """
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

    # Channel geometry
    w_ch = (np.pi * D_pyr / N_ch) - t_fin
    if w_ch <= 0:
        return None

    GAP = (D_jacket - D_pyr) / 2
    if GAP <= 0:
        return None

    # Check fin height doesn't exceed gap
    if longitudinal_fin_height > GAP * 0.8:
        return None

    # Effective flow area (reduced by fins)
    A_fin_blockage = n_longitudinal_fins * longitudinal_fin_height * longitudinal_fin_thickness
    A_c = w_ch * GAP - A_fin_blockage
    if A_c <= 0:
        return None

    # Hydraulic diameter with fins
    # Perimeter includes: 2*w_ch (top/bottom) + 2*GAP (sides) + fin surfaces
    P_base = 2 * w_ch + 2 * GAP
    P_fins = 2 * n_longitudinal_fins * longitudinal_fin_height  # Both sides of each fin
    P_total = P_base + P_fins
    D_h = 4 * A_c / P_total

    v = m_dot / (rho * N_ch * A_c)

    # Heat transfer coefficients (base, without area enhancement)
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

    # BASE heat transfer areas (tube surface only)
    A_base1 = np.pi * D_pyr * L1
    A_base2 = np.pi * D_pyr * L2

    # ENHANCED areas with longitudinal fins
    # Fin area per channel = 2 * fin_height * L (both sides of fin)
    A_fin_per_channel1 = n_longitudinal_fins * 2 * longitudinal_fin_height * L1
    A_fin_per_channel2 = n_longitudinal_fins * 2 * longitudinal_fin_height * L2

    # Total fin area (all channels)
    A_fin_total1 = N_ch * A_fin_per_channel1
    A_fin_total2 = N_ch * A_fin_per_channel2

    # Fin efficiency
    eta1 = fin_efficiency(h1_base, longitudinal_fin_height, longitudinal_fin_thickness, k_wall)
    eta2 = fin_efficiency(h2_base, longitudinal_fin_height, longitudinal_fin_thickness, k_wall)

    # Effective heat transfer area = base area + eta * fin area
    A_eff1 = A_base1 + eta1 * A_fin_total1
    A_eff2 = A_base2 + eta2 * A_fin_total2

    # Area enhancement factor
    enhancement1 = A_eff1 / A_base1
    enhancement2 = A_eff2 / A_base2

    # Required area (using base h, but we have more effective area now)
    A_req1 = Q1 / (h1_base * LMTD1)
    A_req2 = Q2 / (h2_base * LMTD2)

    # Design check: effective area must exceed required
    design_ok = (A_eff1 >= A_req1) and (A_eff2 >= A_req2)

    # Pressure drop
    # With fins, friction factor increases slightly due to added wetted perimeter
    # Use correction factor for finned tubes (approximate)
    fin_friction_factor = 1.0 + 0.5 * (P_fins / P_base)  # Empirical correction

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
        'fin_friction_factor': fin_friction_factor,
    }


def create_results_folder(suffix=""):
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    folder_name = f"results_{timestamp}{suffix}"
    folder_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), folder_name)
    os.makedirs(folder_path, exist_ok=True)
    return folder_path


if __name__ == "__main__":
    print("="*70)
    print("PARAMETRIC STUDY WITH ENHANCED HEAT TRANSFER SURFACES")
    print("="*70)
    print("\nApproach: Add longitudinal fins inside channels to increase")
    print("effective heat transfer area without increasing velocity/DP")

    # Baseline (no fins)
    baseline_res = calculate_design_enhanced(**BASELINE, n_longitudinal_fins=0)
    BASELINE_DP = baseline_res['DP_total_kPa']
    print(f"\nBASELINE (no fins): DP = {BASELINE_DP:.2f} kPa, Valid = {baseline_res['design_ok']}")
    print(f"  A_req2 = {baseline_res['A_req2']:.3f} m2, A_eff2 = {baseline_res['A_eff2']:.3f} m2")
    print(f"  Deficit = {baseline_res['A_req2'] - baseline_res['A_eff2']:.3f} m2")

    output_path = create_results_folder("_enhanced_fins")
    print(f"\nResults folder: {output_path}")

    # Calculate required enhancement for Section 2
    required_enhancement = baseline_res['A_req2'] / baseline_res['A_base2']
    print(f"\nRequired area enhancement for S2: {required_enhancement:.2f}x")

    # ============== COMPREHENSIVE GRID SEARCH ==============
    print("\n--- Comprehensive Search with Longitudinal Fins ---")

    all_results = []
    valid_results = []
    valid_low_dp = []

    # Parameters to vary
    D_jacket_range = np.linspace(0.340, 0.420, 30)  # Larger gaps allowed now
    N_ch_range = range(6, 20)
    t_fin_range = [0.003, 0.004, 0.005, 0.006, 0.008]
    n_fins_range = range(0, 8)  # 0-7 longitudinal fins per channel
    fin_height_range = np.linspace(0.003, 0.015, 8)  # 3-15mm fin height
    fin_thickness_range = [0.002, 0.003, 0.004]  # 2-4mm fin thickness

    total = (len(D_jacket_range) * len(N_ch_range) * len(t_fin_range) *
             len(n_fins_range) * len(fin_height_range) * len(fin_thickness_range))
    print(f"Testing {total} configurations...")

    count = 0
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
                            if res is not None:
                                all_results.append(res)
                                if res['design_ok']:
                                    valid_results.append(res)
                                    if res['DP_total_kPa'] < BASELINE_DP:
                                        valid_low_dp.append(res)
                            count += 1
        if count % 50000 == 0:
            print(f"  Progress: {count}/{total} ({100*count/total:.1f}%)")

    print(f"\nTotal valid configurations: {len(valid_results)}")
    print(f"Valid with DP < baseline ({BASELINE_DP:.2f} kPa): {len(valid_low_dp)}")

    if valid_low_dp:
        # Sort by pressure drop
        valid_low_dp.sort(key=lambda x: x['DP_total_kPa'])
        best = valid_low_dp[0]

        print(f"\n{'='*70}")
        print("SUCCESS! FOUND VALID DESIGNS WITH DP < BASELINE")
        print("="*70)
        print(f"\nTOP 5 OPTIMAL DESIGNS (DP < {BASELINE_DP:.2f} kPa):")

        for i, design in enumerate(valid_low_dp[:5]):
            print(f"\n--- Design #{i+1} ---")
            print(f"  D_jacket = {design['D_jacket']:.4f} m (GAP = {design['GAP']*1000:.2f} mm)")
            print(f"  N_ch = {design['N_ch']} channels, t_fin = {design['t_fin']*1000:.1f} mm")
            print(f"  Longitudinal fins: {design['n_longitudinal_fins']} per channel")
            print(f"    Height = {design['longitudinal_fin_height']*1000:.1f} mm")
            print(f"    Thickness = {design['longitudinal_fin_thickness']*1000:.1f} mm")
            print(f"  Area Enhancement: S1={design['enhancement1']:.2f}x, S2={design['enhancement2']:.2f}x")
            print(f"  Fin Efficiency: eta1={design['eta1']:.3f}, eta2={design['eta2']:.3f}")
            print(f"  DP_total = {design['DP_total_kPa']:.2f} kPa (vs baseline {BASELINE_DP:.2f} kPa)")
            print(f"  DP Reduction = {(1 - design['DP_total_kPa']/BASELINE_DP)*100:.1f}%")
            print(f"  Area Margin S1 = {design['A_margin1']:.1f}%, S2 = {design['A_margin2']:.1f}%")

        # Create visualizations
        fig, axes = plt.subplots(2, 3, figsize=(16, 11))
        fig.suptitle('Enhanced Heat Transfer Design: Valid Designs with DP < Baseline',
                    fontsize=14, fontweight='bold')

        # 1. DP vs number of fins
        ax1 = axes[0, 0]
        n_fins_valid = [r['n_longitudinal_fins'] for r in valid_low_dp]
        dp_valid = [r['DP_total_kPa'] for r in valid_low_dp]
        ax1.scatter(n_fins_valid, dp_valid, c='green', alpha=0.5, s=20)
        ax1.scatter(best['n_longitudinal_fins'], best['DP_total_kPa'],
                   c='red', s=200, marker='*', zorder=5, label='Optimal')
        ax1.axhline(y=BASELINE_DP, color='orange', linestyle='--',
                   label=f'Baseline: {BASELINE_DP:.2f} kPa')
        ax1.set_xlabel('Number of Longitudinal Fins per Channel')
        ax1.set_ylabel('Pressure Drop (kPa)')
        ax1.set_title('DP vs Number of Fins')
        ax1.legend()
        ax1.grid(True, alpha=0.3)

        # 2. DP vs fin height
        ax2 = axes[0, 1]
        fin_h_valid = [r['longitudinal_fin_height']*1000 for r in valid_low_dp]
        ax2.scatter(fin_h_valid, dp_valid, c='blue', alpha=0.5, s=20)
        ax2.scatter(best['longitudinal_fin_height']*1000, best['DP_total_kPa'],
                   c='red', s=200, marker='*', zorder=5, label='Optimal')
        ax2.axhline(y=BASELINE_DP, color='orange', linestyle='--')
        ax2.set_xlabel('Fin Height (mm)')
        ax2.set_ylabel('Pressure Drop (kPa)')
        ax2.set_title('DP vs Fin Height')
        ax2.legend()
        ax2.grid(True, alpha=0.3)

        # 3. DP vs GAP
        ax3 = axes[0, 2]
        gap_valid = [r['GAP']*1000 for r in valid_low_dp]
        ax3.scatter(gap_valid, dp_valid, c='purple', alpha=0.5, s=20)
        ax3.scatter(best['GAP']*1000, best['DP_total_kPa'],
                   c='red', s=200, marker='*', zorder=5, label='Optimal')
        ax3.axhline(y=BASELINE_DP, color='orange', linestyle='--')
        ax3.axvline(x=baseline_res['GAP']*1000, color='orange', linestyle=':',
                   label=f'Baseline GAP: {baseline_res["GAP"]*1000:.1f} mm')
        ax3.set_xlabel('Annular Gap (mm)')
        ax3.set_ylabel('Pressure Drop (kPa)')
        ax3.set_title('DP vs Gap')
        ax3.legend()
        ax3.grid(True, alpha=0.3)

        # 4. Area enhancement vs DP
        ax4 = axes[1, 0]
        enh2_valid = [r['enhancement2'] for r in valid_low_dp]
        ax4.scatter(enh2_valid, dp_valid, c='teal', alpha=0.5, s=20)
        ax4.scatter(best['enhancement2'], best['DP_total_kPa'],
                   c='red', s=200, marker='*', zorder=5, label='Optimal')
        ax4.axhline(y=BASELINE_DP, color='orange', linestyle='--')
        ax4.axvline(x=required_enhancement, color='red', linestyle=':',
                   label=f'Min required: {required_enhancement:.2f}x')
        ax4.set_xlabel('Section 2 Area Enhancement Factor')
        ax4.set_ylabel('Pressure Drop (kPa)')
        ax4.set_title('DP vs Area Enhancement')
        ax4.legend()
        ax4.grid(True, alpha=0.3)

        # 5. Design comparison bar chart
        ax5 = axes[1, 1]
        params = ['GAP\n(mm)', 'N_ch', 'n_fins', 'fin_h\n(mm)', 'v\n(mm/s)']
        baseline_vals = [baseline_res['GAP']*1000, baseline_res['N_ch'], 0, 0, baseline_res['v']*1000]
        optimal_vals = [best['GAP']*1000, best['N_ch'], best['n_longitudinal_fins'],
                       best['longitudinal_fin_height']*1000, best['v']*1000]

        x = np.arange(len(params))
        width = 0.35
        ax5.bar(x - width/2, baseline_vals, width, label='Baseline', color='red', alpha=0.7)
        ax5.bar(x + width/2, optimal_vals, width, label='Optimal', color='green', alpha=0.7)
        ax5.set_xticks(x)
        ax5.set_xticklabels(params)
        ax5.set_ylabel('Value')
        ax5.set_title('Parameter Comparison')
        ax5.legend()
        ax5.grid(True, alpha=0.3, axis='y')

        # 6. Summary text
        ax6 = axes[1, 2]
        ax6.axis('off')
        summary_text = f"""
OPTIMIZATION SUCCESS!
{'='*45}

BASELINE (INVALID):
  DP = {BASELINE_DP:.2f} kPa
  No longitudinal fins
  S2 Area Margin = {baseline_res['A_margin2']:.1f}% (FAIL)

OPTIMAL VALID DESIGN:
  D_jacket = {best['D_jacket']:.4f} m
  GAP = {best['GAP']*1000:.2f} mm
  N_ch = {best['N_ch']} channels
  t_fin = {best['t_fin']*1000:.1f} mm

  Longitudinal Fins:
    {best['n_longitudinal_fins']} fins per channel
    Height = {best['longitudinal_fin_height']*1000:.1f} mm
    Thickness = {best['longitudinal_fin_thickness']*1000:.1f} mm

  Performance:
    DP = {best['DP_total_kPa']:.2f} kPa
    DP Reduction = {(1-best['DP_total_kPa']/BASELINE_DP)*100:.1f}%
    S2 Enhancement = {best['enhancement2']:.2f}x
    S2 Margin = {best['A_margin2']:.1f}%

KEY: Adding longitudinal fins increases
effective heat transfer area, allowing
larger gap and lower velocity = lower DP
"""
        ax6.text(0.02, 0.98, summary_text, transform=ax6.transAxes, fontsize=10,
                verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.8))

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'enhanced_design_analysis.png'), dpi=150)
        plt.close()

        # Create schematic
        fig, axes = plt.subplots(1, 2, figsize=(14, 7))
        fig.suptitle('Channel Cross-Section: Baseline vs Enhanced Design', fontsize=14, fontweight='bold')

        for idx, (ax, title, color, n_fins, gap) in enumerate([
            (axes[0], f'BASELINE (No Fins)\nDP={BASELINE_DP:.1f} kPa - INVALID', 'red', 0, baseline_res['GAP']),
            (axes[1], f'OPTIMAL (With Fins)\nDP={best["DP_total_kPa"]:.1f} kPa - VALID', 'green',
             best['n_longitudinal_fins'], best['GAP'])
        ]):
            ax.set_xlim(-0.08, 0.08)
            ax.set_ylim(-0.01, gap*1.5)
            ax.set_aspect('equal')

            # Draw channel walls
            w_ch = 0.1  # Simplified channel width for visualization
            ax.fill([-w_ch/2, w_ch/2, w_ch/2, -w_ch/2], [0, 0, gap, gap],
                   color=color, alpha=0.2, label='Flow channel')
            ax.plot([-w_ch/2, w_ch/2], [0, 0], 'k-', linewidth=3, label='Pyrolizer wall')
            ax.plot([-w_ch/2, w_ch/2], [gap, gap], 'k-', linewidth=2, label='Jacket wall')
            ax.plot([-w_ch/2, -w_ch/2], [0, gap], 'k-', linewidth=2)
            ax.plot([w_ch/2, w_ch/2], [0, gap], 'k-', linewidth=2)

            # Draw fins
            if n_fins > 0:
                fin_h = best['longitudinal_fin_height']
                fin_t = best['longitudinal_fin_thickness']
                spacing = w_ch / (n_fins + 1)
                for i in range(n_fins):
                    x_pos = -w_ch/2 + spacing * (i + 1)
                    ax.fill([x_pos-fin_t/2, x_pos+fin_t/2, x_pos+fin_t/2, x_pos-fin_t/2],
                           [0, 0, fin_h, fin_h], color='gray', edgecolor='black')

            ax.set_xlabel('Width (m)')
            ax.set_ylabel('Height (m)')
            ax.set_title(title, color=color, fontweight='bold')
            ax.annotate('', xy=(w_ch/2 + 0.005, gap), xytext=(w_ch/2 + 0.005, 0),
                       arrowprops=dict(arrowstyle='<->', color='blue'))
            ax.text(w_ch/2 + 0.01, gap/2, f'GAP\n{gap*1000:.1f}mm', fontsize=9, va='center')

        plt.tight_layout()
        plt.savefig(os.path.join(output_path, 'channel_schematic.png'), dpi=150)
        plt.close()

        # Write summary
        summary_lines = [
            "="*70,
            "ENHANCED HEAT TRANSFER DESIGN - OPTIMIZATION SUMMARY",
            "="*70,
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            f"Total configurations tested: {total}",
            f"Valid designs: {len(valid_results)}",
            f"Valid with DP < baseline: {len(valid_low_dp)}",
            "",
            "="*70,
            "BASELINE DESIGN (INVALID)",
            "="*70,
            f"  D_jacket = {BASELINE['D_jacket']} m",
            f"  GAP = {baseline_res['GAP']*1000:.2f} mm",
            f"  N_ch = {BASELINE['N_ch']} channels",
            f"  t_fin = {BASELINE['t_fin']*1000:.1f} mm",
            f"  No longitudinal fins",
            f"  DP_total = {BASELINE_DP:.2f} kPa",
            f"  A_req2 = {baseline_res['A_req2']:.3f} m2",
            f"  A_eff2 = {baseline_res['A_eff2']:.3f} m2",
            f"  S2 Area Margin = {baseline_res['A_margin2']:.1f}% (INSUFFICIENT)",
            f"  STATUS: DESIGN FAILED",
            "",
            "="*70,
            "OPTIMAL VALID DESIGN (DP < BASELINE)",
            "="*70,
            f"  D_jacket = {best['D_jacket']:.5f} m",
            f"  GAP = {best['GAP']*1000:.3f} mm",
            f"  N_ch = {best['N_ch']} channels",
            f"  t_fin = {best['t_fin']*1000:.2f} mm",
            f"",
            f"  LONGITUDINAL FINS (rib geometry):",
            f"    Number per channel = {best['n_longitudinal_fins']}",
            f"    Height = {best['longitudinal_fin_height']*1000:.2f} mm",
            f"    Thickness = {best['longitudinal_fin_thickness']*1000:.2f} mm",
            f"    Fin efficiency S1 = {best['eta1']:.3f}",
            f"    Fin efficiency S2 = {best['eta2']:.3f}",
            f"",
            f"  HEAT TRANSFER:",
            f"    h1 = {best['h1']:.2f} W/m2K",
            f"    h2 = {best['h2']:.2f} W/m2K",
            f"    Area enhancement S1 = {best['enhancement1']:.2f}x",
            f"    Area enhancement S2 = {best['enhancement2']:.2f}x",
            f"    A_eff2 = {best['A_eff2']:.3f} m2 (vs A_req2 = {best['A_req2']:.3f} m2)",
            f"",
            f"  PERFORMANCE:",
            f"    DP_total = {best['DP_total_kPa']:.3f} kPa",
            f"    DP REDUCTION vs baseline = {(1-best['DP_total_kPa']/BASELINE_DP)*100:.1f}%",
            f"    Velocity = {best['v']:.5f} m/s",
            f"    S1 Area Margin = {best['A_margin1']:.2f}%",
            f"    S2 Area Margin = {best['A_margin2']:.2f}%",
            f"    STATUS: DESIGN SUCCESSFUL",
            "",
            "="*70,
            "KEY INSIGHT",
            "="*70,
            "",
            "By adding longitudinal fins inside the flow channels, we increase",
            "the effective heat transfer area. This allows us to:",
            f"  1. Keep a larger annular gap ({best['GAP']*1000:.1f} mm vs min ~10.8 mm without fins)",
            f"  2. Maintain lower flow velocity ({best['v']*1000:.2f} mm/s vs ~38.8 mm/s without fins)",
            f"  3. Achieve LOWER pressure drop ({best['DP_total_kPa']:.1f} kPa vs 160+ kPa without fins)",
            "",
            "The fins provide the additional heat transfer surface needed for",
            "Section 2 without requiring the high velocities that cause high DP.",
            "",
        ]

        summary_text = "\n".join(summary_lines)
        print("\n" + summary_text)

        with open(os.path.join(output_path, 'enhanced_design_summary.txt'), 'w') as f:
            f.write(summary_text)

        # Save optimal design
        optimal_json = {k: (bool(v) if isinstance(v, (bool, np.bool_)) else
                           float(v) if isinstance(v, (float, np.floating, np.integer)) else v)
                       for k, v in best.items()}
        with open(os.path.join(output_path, 'optimal_enhanced_design.json'), 'w') as f:
            json.dump(optimal_json, f, indent=2)

        # Save top designs
        top_designs = valid_low_dp[:20]
        top_json = [{k: (bool(v) if isinstance(v, (bool, np.bool_)) else
                        float(v) if isinstance(v, (float, np.floating, np.integer)) else v)
                    for k, v in r.items()} for r in top_designs]
        with open(os.path.join(output_path, 'top_20_enhanced_designs.json'), 'w') as f:
            json.dump(top_json, f, indent=2)

    else:
        print("\nNo valid designs found with DP < baseline in this search space.")
        print("Expanding search...")

    print(f"\n\nResults saved to: {output_path}")
