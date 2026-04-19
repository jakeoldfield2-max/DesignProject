#!/usr/bin/env python3
"""
Loop Interface Exchanger – Engineering Design Drawings
=======================================================
Shell-and-tube HEX: Ternary eutectic molten salt (tube side)
heating Helisol 5A (shell side). Plain tubes, triangular 30° layout,
2 tube passes. All parameters from the Maple worksheet.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, Arc, Wedge
import numpy as np
from math import pi, sqrt, cos, sin, ceil, log, exp

# ═══════════════════════════════════════════════════════════════
#  DESIGN PARAMETERS (from Maple worksheet)
# ═══════════════════════════════════════════════════════════════
R_gas = 8.314

# Process conditions
T_cold1_C = 263.05    # °C  Helisol 5A inlet (from torrefaction jacket)
T_cold2_C = 310.0     # °C  Helisol 5A outlet (to air heater)
T_hot1_C  = 620.0     # °C  molten salt inlet
m_cold    = 0.25      # kg/s  Helisol 5A
m_hot     = 0.7609    # kg/s  molten salt
c_cold    = 2150      # J/kg·K
c_hot     = 2300      # J/kg·K

Q = m_cold * c_cold * ((T_cold2_C + 273.15) - (T_cold1_C + 273.15))  # ≈ 25237 W
T_hot2_C = T_hot1_C - Q / (m_hot * c_hot)  # ≈ 605.6 °C

# Thermal results
DeltaT_LM = 326.0     # K
F          = 0.95
U_o_calc   = 72.17     # W/m²·K
U_o_ass    = 83.165    # W/m²·K

# Tube geometry
L_tube     = 0.700     # m
D_internal = 0.026     # m  (26 mm)
D_external = 0.030     # m  (30 mm)

# Tube layout
N_tt_calc  = 14.85
N_tt       = 15        # rounded up
N_p        = 2         # tube passes
L_tp       = 1.25 * D_external  # 0.0375 m  tube pitch (triangular 30°)
C_1        = 0.866
psi_n      = 0.17

D_ctl      = 0.1666    # m  tube bundle OTL
L_bb       = 0.0127    # m  baffle bypass clearance
D_s        = D_ctl + L_bb + D_external  # ≈ 0.2093 m  shell ID

# Baffles
L_B        = 0.5 * D_s   # ≈ 0.1046 m baffle spacing
BaffleCut  = 0.25         # 25%
N_baffles  = max(1, int(L_tube / L_B) - 1)

# Tube-side results
Re_t = 521.5
Pr_t = 40.24
h_i  = 362.1    # W/m²·K
v_t  = 0.094    # m/s
DP_t = 92.74    # Pa

# Shell-side results
Re_s = 2966
Pr_s = 11.6
h_s  = 99.20    # W/m²·K
DP_s = 0.12     # Pa

# Areas
A_req = Q / (F * U_o_ass * DeltaT_LM)  # ≈ 0.98 m²
A_o   = pi * D_external * L_tube * N_tt  # available

# Material notes
tube_material  = "Carbon Steel"
shell_material = "Carbon Steel"
k_tube = 50     # W/m·K
Rf_o = 0.0002   # m²·K/W
Rf_i = 0.0003   # m²·K/W

# ═══════════════════════════════════════════════════════════════
#  DRAWING HELPERS
# ═══════════════════════════════════════════════════════════════
DIM_COL   = "#2255AA"
TUBE_COL  = "#888888"
SHELL_COL = "#444444"
SALT_COL  = "#DD6633"
OIL_COL   = "#66AAEE"
TITLE_FS  = 13
LABEL_FS  = 8.5
DIM_FS    = 7.5


def dim_line(ax, p1, p2, text, offset=0, side="above", fontsize=DIM_FS,
             color=DIM_COL, text_offset=0):
    x1, y1 = p1
    x2, y2 = p2
    dx, dy = x2 - x1, y2 - y1
    length = sqrt(dx**2 + dy**2)
    if length == 0:
        return
    nx, ny = -dy / length, dx / length
    sign = 1 if side == "above" else -1
    ox, oy = nx * offset * sign, ny * offset * sign

    ax.plot([x1, x1 + ox], [y1, y1 + oy], lw=0.4, color=color)
    ax.plot([x2, x2 + ox], [y2, y2 + oy], lw=0.4, color=color)
    mx1, my1 = x1 + ox, y1 + oy
    mx2, my2 = x2 + ox, y2 + oy
    ax.annotate("", xy=(mx2, my2), xytext=(mx1, my1),
                arrowprops=dict(arrowstyle="<->", lw=0.7, color=color))
    cx, cy = (mx1 + mx2) / 2, (my1 + my2) / 2
    angle = np.degrees(np.arctan2(dy, dx))
    if angle > 90: angle -= 180
    if angle < -90: angle += 180
    t_off = sign * 0.006 + text_offset
    ax.text(cx + nx * t_off, cy + ny * t_off, text,
            ha="center", va="center", fontsize=fontsize, color=color,
            rotation=angle, bbox=dict(fc="white", ec="none", pad=0.8, alpha=0.85))


def add_title_block(fig, dwg_no, scale_text="NTS"):
    fig.text(0.98, 0.012, f"Dwg: {dwg_no}   |   Scale: {scale_text}   |   "
             f"3rd Year Design Project – Loop Interface Exchanger",
             ha="right", va="bottom", fontsize=6.5, color="#555555",
             style="italic")


# ═══════════════════════════════════════════════════════════════
#  SHEET 1 – TUBE-SHEET CROSS-SECTION
# ═══════════════════════════════════════════════════════════════
def draw_cross_section(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 1 – Tube-Sheet Cross-Section", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_shell = D_s / 2
    R_ctl   = D_ctl / 2

    # Shell circle
    ax.add_patch(Circle((0, 0), R_shell, fill=False, ec=SHELL_COL, lw=2.0))

    # Baffle cut line (25%)
    bc_y = -R_shell + BaffleCut * D_s
    bc_half_x = sqrt(max(0, R_shell**2 - bc_y**2))
    ax.plot([-bc_half_x, bc_half_x], [bc_y, bc_y], "k--", lw=0.8)
    ax.text(bc_half_x + 0.005, bc_y, f"Baffle cut {int(BaffleCut*100)}%",
            fontsize=LABEL_FS, va="center", color="#666")

    # Generate tube centres – triangular 30° pitch
    tubes_xy = []
    rows = int(ceil(D_ctl / (L_tp * sin(pi / 3)))) + 2
    for row in range(-rows, rows + 1):
        y = row * L_tp * sin(pi / 3)
        x_offset = (L_tp / 2) if (row % 2) else 0
        cols = int(ceil(D_ctl / L_tp)) + 2
        for col in range(-cols, cols + 1):
            x = col * L_tp + x_offset
            r = sqrt(x**2 + y**2)
            if r <= R_ctl + L_tp * 0.3:
                tubes_xy.append((x, y))

    # Keep only N_tt tubes closest to centre
    tubes_xy.sort(key=lambda p: p[0]**2 + p[1]**2)
    tubes_xy = tubes_xy[:N_tt]

    cx = sum(t[0] for t in tubes_xy) / len(tubes_xy)
    cy = sum(t[1] for t in tubes_xy) / len(tubes_xy)
    tubes_xy = [(t[0] - cx, t[1] - cy) for t in tubes_xy]

    # Draw tubes (plain – no fins)
    for (tx, ty) in tubes_xy:
        # Tube OD
        ax.add_patch(Circle((tx, ty), D_external / 2, fill=True, fc="#CCCCCC",
                             ec=TUBE_COL, lw=0.6, zorder=1))
        # Tube ID (bore)
        ax.add_patch(Circle((tx, ty), D_internal / 2, fill=True, fc="white",
                             ec="#999999", lw=0.4, zorder=1))


    # OTL circle (dashed) – sized to actual tube positions
    R_ctl_actual = max(sqrt(t[0]**2 + t[1]**2) for t in tubes_xy) + D_external / 2.4
    ax.add_patch(Circle((0, 0.003), R_ctl_actual, fill=False, ec="#3388CC", lw=0.6, ls="--"))

    # ── Dimensions ──
    # Shell ID (top)
    dim_line(ax, (-R_shell, 0), (R_shell, 0),
             f"D_s = {D_s*1000:.1f} mm",
             offset=R_shell + 0.035, side="above")

    # OTL
    dim_line(ax, (0, 0.0085), (R_ctl * cos(pi/4), R_ctl * sin(pi/3.5)),
             f"D_ctl = {D_ctl*1000:.1f} mm",
             offset=0.012, side="below", fontsize=DIM_FS - 0.5)

    # Tube pitch
    if len(tubes_xy) >= 2:
        t0 = tubes_xy[0]
        dists = [(sqrt((t[0]-t0[0])**2 + (t[1]-t0[1])**2), t) for t in tubes_xy[1:]]
        dists.sort()
        t1 = dists[0][1]
        dim_line(ax, t0, t1, f"P_t = {L_tp*1000:.1f} mm",
                 offset=0.018, side="below", fontsize=DIM_FS - 0.5)

    # Tube size callout
    ax.annotate(f"Tube OD = {D_external*1000:.0f} mm\n"
                f"Tube ID = {D_internal*1000:.0f} mm\n"
                f"Plain tubes (no fins)",
                xy=(tubes_xy[-1][0], tubes_xy[-1][1]),
                xytext=(R_shell + 0.01, -R_shell + 0.01),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Info box
    info = (f"N_tt = {N_tt} tubes\n"
            f"N_p = {N_p} passes\n"
            f"Layout: Δ 30° rotated\n"
            f"Tube: {tube_material}")
    ax.text(-R_shell - 0.025, R_shell + 0.01, info,
            fontsize=LABEL_FS - 1, va="top",
            bbox=dict(fc="white", ec="#999999", boxstyle="round,pad=0.4"))

    # Legend
    ax.plot([], [], 'o', color="#CCCCCC", mec=TUBE_COL, ms=6, label="Tube OD")
    ax.legend(loc="lower left", fontsize=6.5, framealpha=0.9)

    pad = 0.06
    ax.set_xlim(-R_shell - pad - 0.02, R_shell + pad + 0.06)
    ax.set_ylim(-R_shell - pad, R_shell + pad + 0.02)
    ax.set_xlabel("m", fontsize=7)
    ax.set_ylabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 2 – LONGITUDINAL SECTION
# ═══════════════════════════════════════════════════════════════
def draw_longitudinal(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 2 – Longitudinal Section", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R = D_s / 2
    L = L_tube

    # Shell outline
    ax.plot([0, L], [R, R], color=SHELL_COL, lw=2)
    ax.plot([0, L], [-R, -R], color=SHELL_COL, lw=2)

    # End caps
    cap_left = Arc((0, 0), D_s, D_s, angle=0, theta1=90, theta2=270,
                   ec=SHELL_COL, lw=2)
    cap_right = Arc((L, 0), D_s, D_s, angle=0, theta1=-90, theta2=90,
                    ec=SHELL_COL, lw=2)
    ax.add_patch(cap_left)
    ax.add_patch(cap_right)

    # Tube sheet plates
    ts_w = 0.010
    for x in [0, L]:
        ax.add_patch(Rectangle((x - ts_w / 2, -R), ts_w, D_s,
                                fc="#AAAAAA", ec=SHELL_COL, lw=1.0, zorder=5))

    # Baffles
    baffle_positions = []
    n_spaces = N_baffles + 1
    spacing = L / n_spaces
    for i in range(1, N_baffles + 1):
        bx = i * spacing
        baffle_positions.append(bx)
        if i % 2 == 0:
            by_bot = -R
            by_top = R - BaffleCut * D_s
        else:
            by_bot = -R + BaffleCut * D_s
            by_top = R
        ax.add_patch(Rectangle((bx - 0.003, by_bot), 0.006, by_top - by_bot,
                                fc="#CCBBAA", ec="#886644", lw=0.6, zorder=4))

    # Representative tubes
    tube_ys = np.linspace(-R * 0.7, R * 0.7, 5)
    for ty in tube_ys:
        ax.plot([0, L], [ty, ty], color=TUBE_COL, lw=0.8, zorder=3)

    # Nozzles
    noz_h = 0.03
    noz_w = 0.025

    # Shell-side Helisol inlet (top, near right)
    noz_x = L * 0.93
    ax.add_patch(Rectangle((noz_x - noz_w / 2, R), noz_w, noz_h,
                            fc=OIL_COL, ec="#336699", lw=1, alpha=0.7))
    ax.annotate(f"Helisol 5A In\n({T_cold1_C:.0f} °C)", xy=(noz_x, R + noz_h),
                ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#336699",
                fontweight="bold")

    # Shell-side Helisol outlet (top, near left)
    noz_x2 = L * 0.07
    ax.add_patch(Rectangle((noz_x2 - noz_w / 2, R), noz_w, noz_h,
                            fc="#EE9966", ec="#AA5522", lw=1, alpha=0.7))
    ax.annotate(f"Helisol 5A Out\n({T_cold2_C:.0f} °C)", xy=(noz_x2, R + noz_h),
                ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#AA5522",
                fontweight="bold")

    # Tube-side inlet (left)
    ax.annotate(f"Molten Salt In\n({T_hot1_C:.0f} °C)", xy=(-R * 0.6, -R * 0.3),
                ha="center", fontsize=LABEL_FS - 1, color=SALT_COL, fontweight="bold")
    ax.annotate("", xy=(0, -R * 0.3), xytext=(-R * 0.45, -R * 0.3),
                arrowprops=dict(arrowstyle="->", color=SALT_COL, lw=1.2))

    # Tube-side outlet (left top)
    ax.annotate(f"Molten Salt Out\n({T_hot2_C:.0f} °C)", xy=(-R * 0.6, R * 0.3),
                ha="center", fontsize=LABEL_FS - 1, color="#CC8844", fontweight="bold")
    ax.annotate("", xy=(-R * 0.45, R * 0.3), xytext=(0, R * 0.3),
                arrowprops=dict(arrowstyle="->", color="#CC8844", lw=1.2))

    # ── Dimensions ──
    dim_line(ax, (0, -R), (L, -R), f"L_tube = {L*1000:.0f} mm",
             offset=0.04, side="below")

    dim_line(ax, (L + 0.015, -R), (L + 0.015, R),
             f"D_s = {D_s*1000:.1f} mm", offset=0.03, side="above")

    if len(baffle_positions) >= 2:
        b1, b2 = baffle_positions[0], baffle_positions[1]
        dim_line(ax, (b1, R), (b2, R),
                 f"L_B = {spacing*1000:.0f} mm",
                 offset=0.02, side="above", fontsize=DIM_FS - 0.5)

    for i, bx in enumerate(baffle_positions):
        ax.text(bx, -R - 0.012, f"B{i+1}", ha="center", fontsize=5.5, color="#886644")

    pad = 0.08
    ax.set_xlim(-R - 0.06, L + R + 0.06)
    ax.set_ylim(-R - pad, R + pad + 0.02)
    ax.set_xlabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 3 – TUBE DETAIL (plain tube cross-section)
# ═══════════════════════════════════════════════════════════════
def draw_tube_detail(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 3 – Plain Tube Cross-Section Detail", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # Draw in mm
    R_ext = D_external / 2 * 1000
    R_int = D_internal / 2 * 1000
    cx, cy = 0, 0

    # Tube wall
    ax.add_patch(Circle((cx, cy), R_ext, fc="#C0C0C0", ec=TUBE_COL, lw=1.5, zorder=2))
    ax.add_patch(Circle((cx, cy), R_int, fc="#FFDDBB", ec="#999999", lw=1.0, zorder=3))

    # Label bore
    ax.text(cx, cy, "Molten\nSalt", ha="center", va="center",
            fontsize=7, color=SALT_COL)

    # Shell-side fluid label
    ax.text(cx + R_ext + 9, cy, "Helisol 5A\n(shell side)", ha="left", va="center",
            fontsize=7, color="#336699")

    # ── Dimensions ──
    ang1 = pi / 4
    p1 = (cx + R_ext * cos(ang1), cy + R_ext * sin(ang1))
    p2 = (cx - R_ext * cos(ang1), cy - R_ext * sin(ang1))
    dim_line(ax, p1, p2, f"OD = {D_external*1000:.0f} mm",
             offset=18.0, side="above")

    ang2 = -pi / 4
    p3 = (cx + R_int * cos(ang2), cy + R_int * sin(ang2))
    p4 = (cx - R_int * cos(ang2), cy - R_int * sin(ang2))
    dim_line(ax, p3, p4, f"ID = {D_internal*1000:.0f} mm",
             offset=2.0, side="below")

    # Wall thickness
    wall_t = (D_external - D_internal) / 2 * 1000
    dim_line(ax, (cx, cy + R_int), (cx, cy + R_ext),
             f"wall = {wall_t:.0f} mm",
             offset=5, side="above", fontsize=DIM_FS - 0.5)

    # Info box
    info = (f"Plain tube (no fins)\n"
            f"Material: {tube_material}\n"
            f"k_tube = {k_tube} W/m·K\n"
            f"Rf_i = {Rf_i} m²·K/W\n"
            f"Rf_o = {Rf_o} m²·K/W\n"
            f"η_o = 1.0")
    ax.text(R_ext + 5, -R_ext - 2, info, fontsize=LABEL_FS,
            va="top",
            bbox=dict(fc="#FFFFF0", ec="#BBBB88", boxstyle="round,pad=0.4"))

    pad = R_ext + 8
    ax.set_xlim(-pad, pad + 15)
    ax.set_ylim(-pad - 5, pad + 4)
    ax.set_xlabel("mm", fontsize=7)
    ax.set_ylabel("mm", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 4 – TUBE SIDE PROFILE (axial section)
# ═══════════════════════════════════════════════════════════════
def draw_tube_side(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 4 – Tube Axial Section (Side Profile)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # Draw in mm
    R_ext = D_external / 2 * 1000
    R_int = D_internal / 2 * 1000
    L_mm  = L_tube * 1000  # 700 mm

    # Scale down for fit
    scale = 1
    ax_len = L_mm * scale

    # Tube wall (upper half for clarity)
    ax.fill_between([0, ax_len], [R_int, R_int], [R_ext, R_ext],
                    color="#C0C0C0", zorder=2)
    ax.plot([0, ax_len], [R_ext, R_ext], color=TUBE_COL, lw=1.0, zorder=3)
    ax.plot([0, ax_len], [R_int, R_int], color="#999999", lw=0.8, zorder=3)

    # Bore fill (molten salt)
    ax.fill_between([0, ax_len], [0, 0], [R_int, R_int],
                    color="#FFDDBB", alpha=0.3, zorder=1)

    # Centre line
    ax.plot([0, ax_len], [0, 0], color="#333", lw=0.5, ls="-.")
    ax.text(ax_len + 5, 0, "CL", fontsize=6, va="center", color="#666")

    # Flow arrow
    ax.annotate("", xy=(ax_len * 0.8, R_int / 2),
                xytext=(ax_len * 0.2, R_int / 2),
                arrowprops=dict(arrowstyle="->", color=SALT_COL, lw=1.2))
    ax.text(ax_len / 2, R_int / 2 + 1.5, "Molten salt flow", ha="center",
            fontsize=7, color=SALT_COL)

    # ── Dimensions ──
    # Tube length
    dim_line(ax, (0, R_ext), (ax_len, R_ext),
             f"L_tube = {L_tube*1000:.0f} mm",
             offset=3, side="above")

    # Wall thickness
    wall_t = (D_external - D_internal) / 2 * 1000
    dim_line(ax, (ax_len + 5, R_int), (ax_len + 5, R_ext),
             f"wall = {wall_t:.0f} mm", offset=4, side="above", fontsize=DIM_FS - 0.5)

    # OD / ID labels
    ax.text(-10, R_ext, f"OD = {D_external*1000:.0f} mm", fontsize=6,
            va="center", ha="right", color=TUBE_COL)
    ax.text(-10, R_int, f"ID = {D_internal*1000:.0f} mm", fontsize=6,
            va="center", ha="right", color="#999")

    pad_x = 20
    pad_y = 5
    ax.set_xlim(-pad_x - 10, ax_len + pad_x + 15)
    ax.set_ylim(-2, R_ext + pad_y + 6)
    ax.set_xlabel("mm (axial)", fontsize=7)
    ax.set_ylabel("mm (radial)", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  COMPOSE & SAVE
# ═══════════════════════════════════════════════════════════════
def main():
    # Page 1: Cross-section + Longitudinal
    fig1, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 16),
                                     gridspec_kw={"height_ratios": [1, 0.85]})
    fig1.suptitle("Loop Interface Exchanger – Design Drawings (1/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_cross_section(ax1)
    draw_longitudinal(ax2)
    add_title_block(fig1, "LIE-001")
    fig1.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig1.savefig("loop_interface_page1.png", dpi=200, bbox_inches="tight")
    print("Saved page 1")

    # Page 2: Tube detail + Side profile
    fig2 = plt.figure(figsize=(14, 16))
    fig2.suptitle("Loop Interface Exchanger – Design Drawings (2/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    ax3 = fig2.add_subplot(2, 2, 1)
    draw_tube_detail(ax3)
    ax4 = fig2.add_subplot(2, 2, 2)
    draw_tube_side(ax4)
    add_title_block(fig2, "LIE-002")
    fig2.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig2.savefig("loop_interface_page2.png", dpi=200, bbox_inches="tight")
    print("Saved page 2")

    # Combined PDF
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages("Loop_Interface_Exchanger_Design_Drawings.pdf") as pdf:
        pdf.savefig(fig1, bbox_inches="tight")
        pdf.savefig(fig2, bbox_inches="tight")
    print("Saved combined PDF")

    plt.close("all")


if __name__ == "__main__":
    main()
