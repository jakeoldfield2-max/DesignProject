"""
GENERATE REPORT - Pyrolysis Heating Jacket Design Optimization

Creates a multi-page PDF report comparing the three designs:
1. Baseline (Invalid)
2. Non-Finned Optimal (Valid, high DP)
3. Finned Optimal (Valid, minimum DP)

Includes key graphs from the parametric studies.
"""

import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
import numpy as np
from datetime import datetime
import os
from PIL import Image

# ============== DESIGN DATA ==============
# Baseline Design (Invalid)
BASELINE = {
    'name': 'Baseline',
    'status': 'INVALID',
    'D_jacket': 0.358,
    'GAP': 20.0,  # mm
    'N_ch': 10,
    't_fin': 5.0,  # mm
    'n_longitudinal_fins': 0,
    'fin_height': 0,  # mm
    'fin_thickness': 0,  # mm
    'D_h': 33.04,  # mm
    'velocity': 19.56,  # mm/s
    'h1': 132.30,  # W/m2K
    'h2': 123.89,  # W/m2K
    'DP_total': 28.73,  # kPa
    'A_margin1': 40.9,  # %
    'A_margin2': -49.3,  # %
    'enhancement': 1.0,
}

# Non-Finned Optimal (Valid but high DP)
NONFINNED = {
    'name': 'Non-Finned Optimal',
    'status': 'VALID',
    'D_jacket': 0.3397,
    'GAP': 10.84,  # mm
    'N_ch': 8,
    't_fin': 14.65,  # mm
    'n_longitudinal_fins': 0,
    'fin_height': 0,  # mm
    'fin_thickness': 0,  # mm
    'D_h': 19.73,  # mm
    'velocity': 38.84,  # mm/s
    'h1': 197.47,  # W/m2K
    'h2': 184.92,  # W/m2K
    'DP_total': 159.96,  # kPa
    'A_margin1': 60.40,  # %
    'A_margin2': 0.0003,  # %
    'enhancement': 1.0,
}

# Finned Optimal (Valid with minimum DP)
FINNED = {
    'name': 'Finned Optimal',
    'status': 'VALID',
    'D_jacket': 0.500,
    'GAP': 91.0,  # mm
    'N_ch': 7,
    't_fin': 2.0,  # mm
    'n_longitudinal_fins': 9,
    'fin_height': 18.16,  # mm
    'fin_thickness': 4.71,  # mm
    'D_h': 60.91,  # mm
    'velocity': 4.41,  # mm/s
    'h1': 65.65,  # W/m2K
    'h2': 61.48,  # W/m2K
    'DP_total': 2.58,  # kPa
    'A_margin1': 60.22,  # %
    'A_margin2': 0.07,  # %
    'enhancement': 3.01,
}

# Fixed operating conditions
FIXED = {
    'D_pyrolizer': 0.318,  # m
    'L1': 2.05,  # m
    'L2': 2.57,  # m
    'm_dot': 0.7609,  # kg/s
    'T_hot_in': 611.72,  # C
    'T_cold_in': 280,  # C
    'T_cold_out': 550,  # C
    'Q1': 23550,  # W
    'Q2': 20070,  # W
}

def create_report():
    """Generate the PDF report."""

    report_file = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                               'results_20260412_171727_FINAL_OPTIMIZED',
                               'Heating_Jacket_Design_Report.pdf')

    print("Generating Pyrolysis Heating Jacket Design Report...")

    with PdfPages(report_file) as pdf:

        # ============== PAGE 1: Title and Design Comparison ==============
        fig1 = plt.figure(figsize=(8.5, 11))
        fig1.patch.set_facecolor('white')

        # Title
        fig1.text(0.5, 0.95, 'PYROLYSIS HEATING JACKET', fontsize=18, fontweight='bold',
                 ha='center', va='top')
        fig1.text(0.5, 0.92, 'DESIGN OPTIMIZATION SUMMARY', fontsize=16, fontweight='bold',
                 ha='center', va='top')
        fig1.text(0.5, 0.89, f'Generated: {datetime.now().strftime("%d-%b-%Y")} | Project: PY-301',
                 fontsize=10, ha='center', va='top')

        # Operating Conditions Box
        conditions_text = (
            "FIXED OPERATING CONDITIONS:\n\n"
            f"  Salt mass flow rate:        {FIXED['m_dot']} kg/s (Ternary Eutectic)\n"
            f"  Pyrolizer diameter:         {FIXED['D_pyrolizer']*1000:.1f} mm\n"
            f"  Heating zone length (L1):   {FIXED['L1']} m\n"
            f"  Constant temp zone (L2):    {FIXED['L2']} m\n"
            f"  Salt inlet temperature:     {FIXED['T_hot_in']:.2f} C\n"
            f"  Wall inlet temperature:     {FIXED['T_cold_in']} C\n"
            f"  Wall outlet temperature:    {FIXED['T_cold_out']} C\n"
            f"  Heat duty (Section 1):      {FIXED['Q1']} W\n"
            f"  Heat duty (Section 2):      {FIXED['Q2']} W"
        )

        ax_cond = fig1.add_axes([0.05, 0.68, 0.90, 0.18])
        ax_cond.axis('off')
        ax_cond.text(0, 1, conditions_text, fontsize=9, fontfamily='monospace',
                    va='top', ha='left',
                    bbox=dict(boxstyle='round', facecolor='#f0f0f0', edgecolor='gray'))

        # Design Comparison Table Title
        fig1.text(0.5, 0.65, 'DESIGN COMPARISON', fontsize=14, fontweight='bold',
                 ha='center', va='top')

        # Create comparison table
        ax_table = fig1.add_axes([0.05, 0.32, 0.90, 0.30])
        ax_table.axis('off')

        # Table data
        col_headers = ['Parameter', 'Baseline', 'Non-Finned\nOptimal', 'Finned\nOptimal', 'Units']
        table_data = [
            ['Status', 'INVALID', 'VALID', 'VALID', '-'],
            ['D_jacket', f"{BASELINE['D_jacket']:.3f}", f"{NONFINNED['D_jacket']:.4f}", f"{FINNED['D_jacket']:.3f}", 'm'],
            ['GAP (Annular Gap)', f"{BASELINE['GAP']:.1f}", f"{NONFINNED['GAP']:.2f}", f"{FINNED['GAP']:.1f}", 'mm'],
            ['N_ch (Channels)', f"{BASELINE['N_ch']}", f"{NONFINNED['N_ch']}", f"{FINNED['N_ch']}", '-'],
            ['t_fin (Wall Thick.)', f"{BASELINE['t_fin']:.1f}", f"{NONFINNED['t_fin']:.2f}", f"{FINNED['t_fin']:.1f}", 'mm'],
            ['Longitudinal Fins', '0', '0', f"{FINNED['n_longitudinal_fins']}", 'per ch'],
            ['Fin Height', '-', '-', f"{FINNED['fin_height']:.2f}", 'mm'],
            ['Fin Thickness', '-', '-', f"{FINNED['fin_thickness']:.2f}", 'mm'],
            ['Area Enhancement', '1.0x', '1.0x', f"{FINNED['enhancement']:.2f}x", '-'],
            ['Pressure Drop', f"{BASELINE['DP_total']:.2f}", f"{NONFINNED['DP_total']:.2f}", f"{FINNED['DP_total']:.2f}", 'kPa'],
            ['DP Change vs Base', '-', f"+{(NONFINNED['DP_total']/BASELINE['DP_total']-1)*100:.0f}%", f"-{(1-FINNED['DP_total']/BASELINE['DP_total'])*100:.0f}%", '-'],
            ['Velocity', f"{BASELINE['velocity']:.2f}", f"{NONFINNED['velocity']:.2f}", f"{FINNED['velocity']:.2f}", 'mm/s'],
            ['h2 (Heat Trans.)', f"{BASELINE['h2']:.1f}", f"{NONFINNED['h2']:.1f}", f"{FINNED['h2']:.1f}", 'W/m²K'],
            ['S2 Area Margin', f"{BASELINE['A_margin2']:.1f}", f"{NONFINNED['A_margin2']:.4f}", f"{FINNED['A_margin2']:.2f}", '%'],
        ]

        # Draw table
        table = ax_table.table(cellText=table_data, colLabels=col_headers,
                               loc='center', cellLoc='center',
                               colColours=['#d0d0e0']*5)
        table.auto_set_font_size(False)
        table.set_fontsize(8)
        table.scale(1, 1.3)

        # Color code status cells
        for i, row in enumerate(table_data):
            if row[0] == 'Status':
                table[(i+1, 1)].set_facecolor('#ffcccc')  # Red for invalid
                table[(i+1, 2)].set_facecolor('#ccffcc')  # Green for valid
                table[(i+1, 3)].set_facecolor('#ccffcc')  # Green for valid

        # Design descriptions
        descriptions_text = (
            "DESIGN DESCRIPTIONS:\n\n"
            "Baseline: Original design with GAP=20mm, N_ch=10, no longitudinal fins.\n"
            "  FAILED: Section 2 area margin = -49.3% (insufficient heat transfer area).\n"
            "  Pressure drop = 28.73 kPa.\n\n"
            "Non-Finned Optimal: Minimum DP design WITHOUT longitudinal fins.\n"
            "  Required smaller gap (10.8mm) to achieve sufficient h2 for Section 2.\n"
            "  VALID but DP increased to 159.96 kPa (+457% vs baseline).\n\n"
            "Finned Optimal: Minimum DP design WITH longitudinal fins (rib geometry).\n"
            "  9 fins/channel (18.2mm height) increase effective area by 3.01x.\n"
            "  Allows larger gap (91mm), lower velocity, VALID with DP = 2.58 kPa (-91%)."
        )

        ax_desc = fig1.add_axes([0.05, 0.03, 0.90, 0.26])
        ax_desc.axis('off')
        ax_desc.text(0, 1, descriptions_text, fontsize=9, va='top', ha='left',
                    bbox=dict(boxstyle='round', facecolor='white', edgecolor='gray'))

        pdf.savefig(fig1, bbox_inches='tight')
        plt.close(fig1)
        print("  Page 1: Title and comparison table")

        # ============== PAGE 2: Initial Studies (Without Fins) ==============
        fig2 = plt.figure(figsize=(8.5, 11))
        fig2.patch.set_facecolor('white')

        fig2.text(0.5, 0.96, 'STUDY 1: PARAMETRIC OPTIMIZATION WITHOUT FINS',
                 fontsize=14, fontweight='bold', ha='center')
        fig2.text(0.5, 0.93, 'Exploring GAP, N_ch, and t_fin to achieve valid design',
                 fontsize=10, ha='center')

        # Try to load images from results folders
        img_paths = [
            ('results_20260412_170232', 'Study1_D_jacket.png', 'Effect of Jacket Diameter'),
            ('results_20260412_170232', 'Study2_N_ch.png', 'Effect of Number of Channels'),
            ('results_20260412_170414_v2', 'valid_designs_analysis.png', 'Valid Design Analysis'),
            ('results_20260412_170942_FINAL', 'baseline_vs_optimal.png', 'Baseline vs Non-Finned Optimal'),
        ]

        base_path = os.path.dirname(os.path.abspath(__file__))

        for idx, (folder, filename, title) in enumerate(img_paths):
            ax = fig2.add_subplot(2, 2, idx+1)
            img_path = os.path.join(base_path, folder, filename)
            try:
                img = Image.open(img_path)
                ax.imshow(img)
                ax.axis('off')
                ax.set_title(title, fontsize=9, fontweight='bold')
            except:
                ax.text(0.5, 0.5, f'Image not found:\n{filename}', ha='center', va='center')
                ax.axis('off')
                ax.set_title(title, fontsize=9, fontweight='bold')

        # Key findings
        findings_text = (
            "KEY FINDINGS - WITHOUT FINS:\n"
            "  • Baseline fails because Section 2 requires A_req = 3.83 m² but only A_av = 2.57 m² available\n"
            "  • To achieve valid design, h2 must increase by 49% (requires smaller gap, higher velocity)\n"
            "  • Minimum achievable DP for valid non-finned design: 159.96 kPa (+457% vs baseline)"
        )

        fig2.text(0.05, 0.02, findings_text, fontsize=8, va='bottom',
                 bbox=dict(boxstyle='round', facecolor='#f5f5e8', edgecolor='gray'))

        pdf.savefig(fig2, bbox_inches='tight')
        plt.close(fig2)
        print("  Page 2: Initial optimization studies")

        # ============== PAGE 3: Enhanced Studies (With Fins) ==============
        fig3 = plt.figure(figsize=(8.5, 11))
        fig3.patch.set_facecolor('white')

        fig3.text(0.5, 0.96, 'STUDY 2: OPTIMIZATION WITH LONGITUDINAL FINS',
                 fontsize=14, fontweight='bold', ha='center')
        fig3.text(0.5, 0.93, 'Adding fins to increase effective heat transfer area',
                 fontsize=10, ha='center')

        # Load enhanced study images
        img_paths2 = [
            ('results_20260412_171527_enhanced_fins', 'enhanced_design_analysis.png', 'Enhanced Design Analysis'),
            ('results_20260412_171527_enhanced_fins', 'channel_schematic.png', 'Channel Cross-Section'),
            ('results_20260412_171727_FINAL_OPTIMIZED', 'FINAL_REPORT.png', 'Final Optimization Report'),
            ('results_20260412_171727_FINAL_OPTIMIZED', 'cross_section_final.png', 'Final Cross-Section Comparison'),
        ]

        for idx, (folder, filename, title) in enumerate(img_paths2):
            ax = fig3.add_subplot(2, 2, idx+1)
            img_path = os.path.join(base_path, folder, filename)
            try:
                img = Image.open(img_path)
                ax.imshow(img)
                ax.axis('off')
                ax.set_title(title, fontsize=9, fontweight='bold')
            except:
                ax.text(0.5, 0.5, f'Image not found:\n{filename}', ha='center', va='center')
                ax.axis('off')
                ax.set_title(title, fontsize=9, fontweight='bold')

        # Key findings
        findings_text2 = (
            "KEY FINDINGS - WITH FINS:\n"
            "  • Longitudinal fins increase effective heat transfer area by 3.01x\n"
            "  • Larger gap possible (91mm vs 20mm baseline) → lower velocity → lower DP\n"
            "  • Achieved 91% pressure drop reduction (28.73 kPa → 2.58 kPa) with valid design"
        )

        fig3.text(0.05, 0.02, findings_text2, fontsize=8, va='bottom',
                 bbox=dict(boxstyle='round', facecolor='#e8f5e8', edgecolor='gray'))

        pdf.savefig(fig3, bbox_inches='tight')
        plt.close(fig3)
        print("  Page 3: Enhanced optimization studies")

        # ============== PAGE 4: Final Recommendations ==============
        fig4 = plt.figure(figsize=(8.5, 11))
        fig4.patch.set_facecolor('white')

        fig4.text(0.5, 0.96, 'DESIGN RECOMMENDATIONS', fontsize=16, fontweight='bold', ha='center')

        designs = ['Baseline\n(Invalid)', 'Non-Finned\nOptimal', 'Finned\nOptimal']

        # Geometry comparison
        ax1 = fig4.add_axes([0.08, 0.72, 0.40, 0.18])
        bar_data = np.array([[20, 10.84, 91], [10, 8, 7], [0, 0, 9]])
        x = np.arange(3)
        width = 0.25
        ax1.bar(x - width, bar_data[0], width, label='GAP (mm)', color='#4477aa')
        ax1.bar(x, bar_data[1], width, label='N_ch', color='#cc6677')
        ax1.bar(x + width, bar_data[2], width, label='Fins/ch', color='#44aa77')
        ax1.set_xticks(x)
        ax1.set_xticklabels(designs, fontsize=8)
        ax1.set_ylabel('Value')
        ax1.set_title('Geometry Parameters', fontweight='bold')
        ax1.legend(fontsize=7, loc='upper left')
        ax1.grid(True, alpha=0.3)

        # Pressure drop comparison
        ax2 = fig4.add_axes([0.55, 0.72, 0.40, 0.18])
        dp = [BASELINE['DP_total'], NONFINNED['DP_total'], FINNED['DP_total']]
        colors = ['#cc4444', '#cc8844', '#44aa44']
        bars = ax2.bar(designs, dp, color=colors)
        ax2.set_ylabel('Pressure Drop (kPa)')
        ax2.set_title('Pressure Drop Comparison', fontweight='bold')
        ax2.grid(True, alpha=0.3, axis='y')
        # Add labels
        ax2.text(0, dp[0]+5, f'{dp[0]:.1f}', ha='center', fontsize=8)
        ax2.text(1, dp[1]+5, f'{dp[1]:.1f}\n(+{(dp[1]/dp[0]-1)*100:.0f}%)', ha='center', fontsize=7)
        ax2.text(2, dp[2]+5, f'{dp[2]:.2f}\n(-{(1-dp[2]/dp[0])*100:.0f}%)', ha='center', fontsize=7, color='green')

        # Heat transfer coefficient
        ax3 = fig4.add_axes([0.08, 0.48, 0.40, 0.18])
        h2 = [BASELINE['h2'], NONFINNED['h2'], FINNED['h2']]
        ax3.bar(designs, h2, color='#5588bb')
        ax3.set_ylabel('h₂ (W/m²K)')
        ax3.set_title('Heat Transfer Coefficient (Section 2)', fontweight='bold')
        ax3.grid(True, alpha=0.3, axis='y')
        for i, v in enumerate(h2):
            ax3.text(i, v+3, f'{v:.1f}', ha='center', fontsize=8)

        # Area margin
        ax4 = fig4.add_axes([0.55, 0.48, 0.40, 0.18])
        margin = [BASELINE['A_margin2'], NONFINNED['A_margin2'], FINNED['A_margin2']]
        colors = ['#cc4444' if m < 0 else '#44aa44' for m in margin]
        ax4.bar(designs, margin, color=colors)
        ax4.axhline(y=0, color='red', linestyle='--', linewidth=2)
        ax4.set_ylabel('S2 Area Margin (%)')
        ax4.set_title('Section 2 Area Margin\n(Must be ≥ 0 for valid design)', fontweight='bold', fontsize=9)
        ax4.grid(True, alpha=0.3, axis='y')
        for i, v in enumerate(margin):
            y_pos = v + 2 if v >= 0 else v - 5
            ax4.text(i, y_pos, f'{v:.1f}%', ha='center', fontsize=8)

        # Velocity comparison
        ax5 = fig4.add_axes([0.08, 0.24, 0.40, 0.18])
        vel = [BASELINE['velocity'], NONFINNED['velocity'], FINNED['velocity']]
        ax5.bar(designs, vel, color='#aa7744')
        ax5.set_ylabel('Velocity (mm/s)')
        ax5.set_title('Flow Velocity', fontweight='bold')
        ax5.grid(True, alpha=0.3, axis='y')
        for i, v in enumerate(vel):
            ax5.text(i, v+1, f'{v:.1f}', ha='center', fontsize=8)

        # Area enhancement
        ax6 = fig4.add_axes([0.55, 0.24, 0.40, 0.18])
        enh = [BASELINE['enhancement'], NONFINNED['enhancement'], FINNED['enhancement']]
        ax6.bar(designs, enh, color='#7744aa')
        ax6.axhline(y=1.49, color='red', linestyle='--', linewidth=1.5, label='Min required (1.49x)')
        ax6.set_ylabel('Area Enhancement Factor')
        ax6.set_title('Effective Area Enhancement', fontweight='bold')
        ax6.legend(fontsize=7)
        ax6.grid(True, alpha=0.3, axis='y')
        for i, v in enumerate(enh):
            ax6.text(i, v+0.1, f'{v:.2f}x', ha='center', fontsize=8)

        # Recommendations text
        rec_text = (
            "RECOMMENDATIONS:\n\n"
            "✓ CHOOSE FINNED OPTIMAL DESIGN (Recommended):\n"
            "    • Achieves 91% pressure drop reduction vs baseline (2.58 kPa vs 28.73 kPa)\n"
            "    • Valid heat transfer design with 0.07% safety margin on Section 2\n"
            "    • Requires 9 longitudinal fins per channel (18.2mm height, 4.7mm thick)\n"
            "    • Larger jacket diameter (500mm) accommodates increased gap\n\n"
            "✗ AVOID BASELINE DESIGN:\n"
            "    • INVALID: Section 2 area margin is -49.3% (insufficient heat transfer)\n\n"
            "✗ AVOID NON-FINNED OPTIMAL:\n"
            "    • Although valid, pressure drop is 5.6x higher than baseline (159.96 kPa)\n"
            "    • Only use if fins cannot be manufactured\n\n"
            "KEY INSIGHT: Longitudinal fins provide the additional heat transfer surface needed\n"
            "without requiring high velocities, enabling both valid design AND minimum DP."
        )

        ax_rec = fig4.add_axes([0.05, 0.01, 0.90, 0.20])
        ax_rec.axis('off')
        ax_rec.text(0, 1, rec_text, fontsize=8, va='top', ha='left',
                   fontfamily='sans-serif',
                   bbox=dict(boxstyle='round', facecolor='#f8f8f0', edgecolor='#666666'))

        pdf.savefig(fig4, bbox_inches='tight')
        plt.close(fig4)
        print("  Page 4: Final recommendations")

    print(f"\nReport saved to: {report_file}")
    return report_file


if __name__ == "__main__":
    create_report()
