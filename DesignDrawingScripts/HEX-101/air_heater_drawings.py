#!/usr/bin/env python3
"""
Air Heater Heat Exchanger – Engineering Design Drawings
========================================================
Fin-and-tube shell-and-tube HEX: Helisol 5A (tube side) heating air (shell side).
All parameters extracted from the Maple design worksheet.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch, Arc, Rectangle, Circle, Wedge
from matplotlib.collections import PatchCollection
import numpy as np
from math import pi, sqrt, cos, sin, ceil

# ═══════════════════════════════════════════════════════════════
#  DESIGN PARAMETERS (from Maple worksheet)
# ═══════════════════════════════════════════════════════════════
# Process conditions
T_cold1 = 20        # °C   ambient air inlet
T_cold2 = 280       # °C   air outlet
T_hot1  = 330       # °C   Helisol 5A inlet
T_hot2  = 330 - 15046.52 / (0.25 * 2150)  # °C  hot outlet  ≈ 302.0 °C
m_cold  = 0.0571    # kg/s  air
m_hot   = 0.25      # kg/s  Helisol 5A
Q       = 15046.5   # W     duty
c_hot   = 2150      # J/kg·K
c_cold  = 1014      # J/kg·K

# Tube geometry
L_tube     = 1.750     # m
D_internal = 0.015     # m   (15 mm)
D_external = 0.018     # m   (18 mm)

# Fin geometry (helical)
l_f  = 0.010    # m   fin height
t_f  = 0.0005   # m   fin thickness
p_f  = 0.002    # m   fin pitch
D_fin = D_external + 2 * l_f   # 0.038 m  fin OD

# Tube layout
N_tt_calc = 18.69   # from worksheet
N_tt      = 19      # rounded up
N_p       = 2       # tube passes
L_tp      = 0.04750 # m  tube pitch (triangular 30°)
C_1       = 0.866
psi_n     = 0.17

D_ctl = 0.2367      # m   tube bundle OTL
L_bb  = 0.0127      # m   baffle bypass clearance
D_s   = 0.2674      # m   shell ID

# Baffles
L_B        = 0.802  # m   baffle spacing
BaffleCut  = 0.25   # 25 %
N_baffles  = max(1, int(L_tube / L_B) - 1)   # number of baffles

# Thermal results
U_o_calc = 3.793    # W/m²·K
U_o_ass  = 3.793
Re_t     = 5540
Re_s     = 9443
DP_t     = 223.8    # Pa
DP_s     = 0.063    # Pa
h_i      = 240.2    # W/m²·K
h_s      = 5.79     # W/m²·K
eta_f    = 0.996
eta_o    = 0.996
A_req    = 31.14    # m²
DeltaT_LM = 134.1   # °C

# Material notes
tube_material = "Carbon Steel"
fin_material  = "Aluminium"
k_tube = 50    # W/m·K
k_fin  = 205   # W/m·K

# ═══════════════════════════════════════════════════════════════
#  DRAWING HELPERS
# ═══════════════════════════════════════════════════════════════
DIM_COL   = "#2255AA"
TUBE_COL  = "#888888"
FIN_COL   = "#BBBBBB"
SHELL_COL = "#444444"
AIR_COL   = "#66AAEE"
OIL_COL   = "#DD6633"
TITLE_FS  = 13
LABEL_FS  = 8.5
DIM_FS    = 7.5

def dim_line(ax, p1, p2, text, offset=0, side="above", fontsize=DIM_FS,
             color=DIM_COL, text_offset=0):
    """Draw a dimension line between two points with annotation."""
    x1, y1 = p1
    x2, y2 = p2
    dx, dy = x2 - x1, y2 - y1
    length = sqrt(dx**2 + dy**2)
    if length == 0:
        return
    nx, ny = -dy / length, dx / length  # normal
    sign = 1 if side == "above" else -1
    ox, oy = nx * offset * sign, ny * offset * sign

    # Extension lines
    ext = offset * sign
    ax.plot([x1, x1 + ox], [y1, y1 + oy], lw=0.4, color=color)
    ax.plot([x2, x2 + ox], [y2, y2 + oy], lw=0.4, color=color)

    # Dimension line
    mx1, my1 = x1 + ox, y1 + oy
    mx2, my2 = x2 + ox, y2 + oy
    ax.annotate("", xy=(mx2, my2), xytext=(mx1, my1),
                arrowprops=dict(arrowstyle="<->", lw=0.7, color=color))

    # Text
    cx, cy = (mx1 + mx2) / 2, (my1 + my2) / 2
    angle = np.degrees(np.arctan2(dy, dx))
    if angle > 90: angle -= 180
    if angle < -90: angle += 180
    t_off = sign * 0.006 + text_offset
    ax.text(cx + nx * t_off, cy + ny * t_off, text,
            ha="center", va="center", fontsize=fontsize, color=color,
            rotation=angle, bbox=dict(fc="white", ec="none", pad=0.8, alpha=0.85))


def add_title_block(fig, title, dwg_no, scale_text="NTS"):
    """Add a simple title block at bottom of figure."""
    fig.text(0.98, 0.012, f"Dwg: {dwg_no}   |   Scale: {scale_text}   |   "
             f"3rd Year Design Project – Air Heater HEX",
             ha="right", va="bottom", fontsize=6.5, color="#555555",
             style="italic")


# ═══════════════════════════════════════════════════════════════
#  SHEET 1 – CROSS-SECTION (Tube-sheet / Baffle view)
# ═══════════════════════════════════════════════════════════════
def draw_cross_section(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 1 – Tube-Sheet Cross-Section", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_shell = D_s / 2
    R_ctl   = D_ctl / 2

    # Shell circle
    shell = Circle((0, 0), R_shell, fill=False, ec=SHELL_COL, lw=2.0)
    ax.add_patch(shell)

    # Baffle cut line (25 %)
    bc_y = -R_shell + BaffleCut * D_s   # y-level of cut chord
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

    # Draw tubes with fins
    for (tx, ty) in tubes_xy:
        # Fin circle (outer)
        fin_c = Circle((tx, ty), D_fin / 2, fill=True, fc="#E8E8E8",
                        ec=FIN_COL, lw=0.4, zorder=2)
        ax.add_patch(fin_c)
        # Tube OD
        tube_c = Circle((tx, ty), D_external / 2, fill=True, fc="#CCCCCC",
                         ec=TUBE_COL, lw=0.6, zorder=3)
        ax.add_patch(tube_c)
        # Tube ID (bore)
        bore_c = Circle((tx, ty), D_internal / 2, fill=True, fc="white",
                         ec="#999999", lw=0.4, zorder=4)
        ax.add_patch(bore_c)

    # Pass partition (horizontal line through centre)
    gap_y = L_tp * sin(pi/3) / 2  # halfway between two tube rows
    ax.plot([-R_shell, R_shell], [gap_y, gap_y], color="#AA3333", lw=1.2, ls="-.",
            label="Pass partition")
    ax.text(R_shell + 0.005, gap_y + 0.005, "Pass 1", fontsize=LABEL_FS - 1, color="#AA3333")
    ax.text(R_shell + 0.005, gap_y - 0.010, "Pass 2", fontsize=LABEL_FS - 1, color="#AA3333")

    # OTL circle (dashed)
    otl = Circle((0, 0), R_ctl, fill=False, ec="#3388CC", lw=0.6, ls="--")
    ax.add_patch(otl)

    # ── Dimensions ──
    # Shell OD
    dim_line(ax, (-R_shell, 0), (R_shell, 0), f"D_s = {D_s*1000:.1f} mm",
             offset=R_shell + 0.035, side="above")

    # OTL
    dim_line(ax, (0, 0), (R_ctl * cos(pi/4), R_ctl * sin(pi/4)),
             f"D_ctl = {D_ctl*1000:.1f} mm",
             offset=0.012, side="below", fontsize=DIM_FS - 0.5)

    # Tube pitch (between two neighbouring tubes)
    if len(tubes_xy) >= 2:
        t0 = tubes_xy[0]
        # find nearest neighbour
        dists = [(sqrt((t[0]-t0[0])**2 + (t[1]-t0[1])**2), t) for t in tubes_xy[1:]]
        dists.sort()
        t1 = dists[0][1]
        dim_line(ax, t0, t1, f"P_t = {L_tp*1000:.1f} mm",
                 offset=0.018, side="below", fontsize=DIM_FS - 0.5)

    # Fin detail call-out (bottom right)
    ax.annotate(f"Fin OD = {D_fin*1000:.0f} mm\n"
                f"Tube OD = {D_external*1000:.0f} mm\n"
                f"Tube ID = {D_internal*1000:.0f} mm",
                xy=(tubes_xy[-1][0], tubes_xy[-1][1]),
                xytext=(R_shell + 0.01, -R_shell + 0.01),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFEE", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Legend patches
    ax.plot([], [], 's', color="#E8E8E8", mec=FIN_COL, ms=8, label="Fin envelope")
    ax.plot([], [], 'o', color="#CCCCCC", mec=TUBE_COL, ms=6, label="Tube OD")
    ax.legend(loc="lower left", fontsize=6.5, framealpha=0.9)

    # Info box
    info = (f"N_tt = {N_tt} tubes\n"
            f"N_p = {N_p} passes\n"
            f"Layout: Δ 30° rotated\n"
            f"Tube: {tube_material}\n"
            f"Fin: {fin_material}")
    ax.text(-R_shell - 0.025, R_shell + 0.01, info,
            fontsize=LABEL_FS - 1, va="top",
            bbox=dict(fc="white", ec="#999999", boxstyle="round,pad=0.4"))

    pad = 0.06
    ax.set_xlim(-R_shell - pad - 0.02, R_shell + pad + 0.06)
    ax.set_ylim(-R_shell - pad, R_shell + pad + 0.02)
    ax.set_xlabel("m", fontsize=7)
    ax.set_ylabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 2 – LONGITUDINAL SECTION (Side elevation)
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
    # End caps (semicircles)
    cap_left = Arc((0, 0), D_s, D_s, angle=0, theta1=90, theta2=270,
                    ec=SHELL_COL, lw=2)
    cap_right = Arc((L, 0), D_s, D_s, angle=0, theta1=-90, theta2=90,
                     ec=SHELL_COL, lw=2)
    ax.add_patch(cap_left)
    ax.add_patch(cap_right)

    # Tube sheet plates
    ts_w = 0.012
    for x in [0, L]:
        ax.add_patch(Rectangle((x - ts_w/2, -R), ts_w, D_s,
                                fc="#AAAAAA", ec=SHELL_COL, lw=1.0, zorder=5))

    # Baffles
    baffle_positions = []
    n_spaces = N_baffles + 1
    spacing = L / n_spaces
    for i in range(1, N_baffles + 1):
        bx = i * spacing
        baffle_positions.append(bx)
        # Alternating baffle cut side
        if i % 2 == 0:
            by_bot = -R
            by_top = R - BaffleCut * D_s
        else:
            by_bot = -R + BaffleCut * D_s
            by_top = R
        ax.add_patch(Rectangle((bx - 0.004, by_bot), 0.008, by_top - by_bot,
                                fc="#CCBBAA", ec="#886644", lw=0.6, zorder=4))

    # Representative tubes (a few horizontal lines)
    tube_ys = np.linspace(-R * 0.75, R * 0.75, 7)
    for ty in tube_ys:
        ax.plot([0, L], [ty, ty], color=TUBE_COL, lw=0.8, zorder=3)

    # Nozzles
    noz_h = 0.04
    noz_w = 0.035
    # Shell-side air inlet (top, near right)
    noz_x = L * 0.75
    ax.add_patch(Rectangle((noz_x - noz_w/2, R), noz_w, noz_h,
                            fc=AIR_COL, ec="#336699", lw=1, alpha=0.7))
    ax.annotate("Air In\n(20 °C)", xy=(noz_x, R + noz_h),
                ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#336699",
                fontweight="bold")

    # Shell-side air outlet (top, near left)
    noz_x2 = L * 0.25
    ax.add_patch(Rectangle((noz_x2 - noz_w/2, R), noz_w, noz_h,
                            fc="#EE9966", ec="#AA5522", lw=1, alpha=0.7))
    ax.annotate("Air Out\n(280 °C)", xy=(noz_x2, R + noz_h),
                ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#AA5522",
                fontweight="bold")

    # Tube-side inlet/outlet (ends)
    # Inlet – left bottom
    ax.annotate("Helisol 5A In\n(330 °C)", xy=(-R * 0.6, -R * 0.3),
                ha="center", fontsize=LABEL_FS - 1, color=OIL_COL, fontweight="bold")
    ax.annotate("", xy=(0, -R * 0.3), xytext=(-R * 0.45, -R * 0.3),
                arrowprops=dict(arrowstyle="->", color=OIL_COL, lw=1.2))

    # Outlet – left top
    T_hot2_C = round(T_hot2, 1)
    ax.annotate(f"Helisol 5A Out\n({T_hot2_C:.0f} °C)", xy=(-R * 0.6, R * 0.3),
                ha="center", fontsize=LABEL_FS - 1, color="#CC8844", fontweight="bold")
    ax.annotate("", xy=(-R * 0.45, R * 0.3), xytext=(0, R * 0.3),
                arrowprops=dict(arrowstyle="->", color="#CC8844", lw=1.2))

    # ── Dimensions ──
    # Tube length
    dim_line(ax, (0, -R), (L, -R), f"L_tube = {L*1000:.0f} mm",
             offset=0.05, side="below")

    # Shell ID
    dim_line(ax, (L + 0.02, -R), (L + 0.02, R),
             f"D_s = {D_s*1000:.1f} mm", offset=0.04, side="above")

    # Baffle spacing
    if len(baffle_positions) >= 2:
        b1, b2 = baffle_positions[0], baffle_positions[1]
        dim_line(ax, (b1, R), (b2, R),
                 f"L_B = {spacing*1000:.0f} mm",
                 offset=0.025, side="above", fontsize=DIM_FS - 0.5)

    # Label baffles
    for i, bx in enumerate(baffle_positions):
        ax.text(bx, -R - 0.015, f"B{i+1}", ha="center", fontsize=5.5, color="#886644")

    pad = 0.12
    ax.set_xlim(-R - 0.08, L + R + 0.08)
    ax.set_ylim(-R - pad, R + pad + 0.02)
    ax.set_xlabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 3 – FIN DETAIL
# ═══════════════════════════════════════════════════════════════
def draw_fin_detail(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 3 – Helical Fin Detail", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # Enlarged cross-section of one finned tube
    scale = 1  # drawing in mm
    R_ext = D_external / 2 * 1000   # mm
    R_int = D_internal / 2 * 1000
    R_fin = D_fin / 2 * 1000
    fin_h = l_f * 1000
    fin_t = t_f * 1000
    fin_p = p_f * 1000

    cx, cy = 0, 0

    # Draw tube wall (cross-section style – show as ring)
    tube_od = Circle((cx, cy), R_ext, fc="#C0C0C0", ec=TUBE_COL, lw=1.5, zorder=2)
    tube_id = Circle((cx, cy), R_int, fc="white", ec="#999999", lw=1.0, zorder=3)
    ax.add_patch(tube_od)
    ax.add_patch(tube_id)

    # Draw fins (radial lines at uniform spacing around circumference)
    n_show = 36
    for i in range(n_show):
        angle = 2 * pi * i / n_show
        x1 = cx + R_ext * cos(angle)
        y1 = cy + R_ext * sin(angle)
        x2 = cx + R_fin * cos(angle)
        y2 = cy + R_fin * sin(angle)
        ax.plot([x1, x2], [y1, y2], color="#999999", lw=0.6, zorder=1)

    # Fin tip circle
    fin_circle = Circle((cx, cy), R_fin, fill=False, ec=FIN_COL, lw=0.8, ls="--")
    ax.add_patch(fin_circle)

    # ── Dimensions ──
    # Tube OD
    ang1 = pi / 4
    p1 = (cx + R_ext * cos(ang1), cy + R_ext * sin(ang1))
    p2 = (cx - R_ext * cos(ang1), cy - R_ext * sin(ang1))
    dim_line(ax, p1, p2, f"OD = {D_external*1000:.0f} mm",
             offset=2.0, side="above")

    # Tube ID
    ang2 = -pi / 4
    p3 = (cx + R_int * cos(ang2), cy + R_int * sin(ang2))
    p4 = (cx - R_int * cos(ang2), cy - R_int * sin(ang2))
    dim_line(ax, p3, p4, f"ID = {D_internal*1000:.0f} mm",
             offset=2.0, side="below")

    # Fin height
    ang3 = pi / 2
    pA = (cx + R_ext * cos(ang3), cy + R_ext * sin(ang3))
    pB = (cx + R_fin * cos(ang3), cy + R_fin * sin(ang3))
    dim_line(ax, pA, pB, f"l_f = {l_f*1000:.0f} mm",
             offset=3.0, side="above")

    # Fin OD
    dim_line(ax, (-R_fin, cy), (R_fin, cy),
             f"D_fin = {D_fin*1000:.0f} mm",
             offset=R_fin + 4, side="above")

    # Info box
    info = (f"Fin type: Helical\n"
            f"Fin pitch: {p_f*1000:.1f} mm\n"
            f"Fin thickness: {t_f*1000:.2f} mm\n"
            f"Fins per tube: {int(L_tube/p_f)}\n"
            f"Fin material: {fin_material}\n"
            f"Tube material: {tube_material}\n"
            f"η_f = {eta_f:.3f}")
    ax.text(R_fin + 6, -R_fin - 2, info, fontsize=LABEL_FS,
            va="top",
            bbox=dict(fc="#FFFFF0", ec="#BBBB88", boxstyle="round,pad=0.4"))

    pad = R_fin + 10
    ax.set_xlim(-pad, pad + 12)
    ax.set_ylim(-pad, pad + 4)
    ax.set_xlabel("mm", fontsize=7)
    ax.set_ylabel("mm", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 3b – FIN SIDE PROFILE DETAIL
# ═══════════════════════════════════════════════════════════════
def draw_fin_side(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 3b – Fin Side Profile (Axial Section)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # Draw in mm
    R_ext = D_external / 2 * 1000
    R_int = D_internal / 2 * 1000
    fin_h = l_f * 1000
    fin_t = t_f * 1000
    fin_p = p_f * 1000
    R_fin = R_ext + fin_h

    # Show a section along the axis (x = axial, y = radial)
    n_fins_show = 12
    ax_len = n_fins_show * fin_p

    # Tube wall (upper half only for clarity)
    ax.fill_between([0, ax_len], [R_int, R_int], [R_ext, R_ext],
                     color="#C0C0C0", zorder=2)
    ax.plot([0, ax_len], [R_ext, R_ext], color=TUBE_COL, lw=1.0, zorder=3)
    ax.plot([0, ax_len], [R_int, R_int], color="#999999", lw=0.8, zorder=3)

    # Centre line
    ax.plot([0, ax_len], [0, 0], color="#333", lw=0.5, ls="-.")
    ax.text(ax_len + 0.5, 0, "CL", fontsize=6, va="center", color="#666")

    # Fins
    for i in range(n_fins_show):
        fx = i * fin_p + fin_p / 2 - fin_t / 2
        ax.add_patch(Rectangle((fx, R_ext), fin_t, fin_h,
                                fc="#AAAAAA", ec="#777777", lw=0.5, zorder=4))

    # ── Dimensions ──
    # Fin pitch
    f1x = 0.5 * fin_p - fin_t / 2
    f2x = 1.5 * fin_p - fin_t / 2
    dim_line(ax, (f1x + fin_t/2, R_fin), (f2x + fin_t/2, R_fin),
             f"p_f = {fin_p:.1f} mm", offset=2.5, side="above")

    # Fin thickness
    fx_mid = 3 * fin_p + fin_p / 2
    dim_line(ax, (fx_mid - fin_t/2, R_fin + 1), (fx_mid + fin_t/2, R_fin + 1),
             f"t_f = {fin_t:.2f} mm", offset=3, side="above", fontsize=DIM_FS - 0.5)

    # Fin height
    dim_line(ax, (ax_len + 1, R_ext), (ax_len + 1, R_fin),
             f"l_f = {fin_h:.0f} mm", offset=2.5, side="above")

    # Tube wall thickness
    wall_t = (D_external - D_internal) / 2 * 1000
    dim_line(ax, (ax_len + 1, R_int), (ax_len + 1, R_ext),
         f"wall = {wall_t:.1f} mm", offset=1, side="below", fontsize=DIM_FS - 0.5)

    pad_x = 3
    pad_y = 5
    ax.set_xlim(-pad_x, ax_len + pad_x + 8)
    ax.set_ylim(-2, R_fin + pad_y + 5)
    ax.set_xlabel("mm (axial)", fontsize=7)
    ax.set_ylabel("mm (radial)", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  COMPOSE & SAVE
# ═══════════════════════════════════════════════════════════════

def main():
    # --- Page 1: Cross-section + Longitudinal ---
    fig1, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 16),
                                     gridspec_kw={"height_ratios": [1, 0.85]})
    fig1.suptitle("Air Heater Heat Exchanger – Design Drawings (1/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_cross_section(ax1)
    draw_longitudinal(ax2)
    add_title_block(fig1, "Air Heater HEX", "AH-001")
    fig1.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig1.savefig("air_heater_page1.png", dpi=200, bbox_inches="tight")
    print("Saved page 1")

    # --- Page 2: Fin details + Data table ---
    fig2 = plt.figure(figsize=(14, 16))
    fig2.suptitle("Air Heater Heat Exchanger – Design Drawings (2/2)",
                  fontsize=15, fontweight="bold", y=0.98)

    ax3 = fig2.add_subplot(2, 2, 1)
    draw_fin_detail(ax3)

    ax4 = fig2.add_subplot(2, 2, 2)
    draw_fin_side(ax4)

    add_title_block(fig2, "Air Heater HEX", "AH-002")
    fig2.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig2.savefig("air_heater_page2.png", dpi=200, bbox_inches="tight")
    print("Saved page 2")

    # Also save as PDF
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages("Air_Heater_Design_Drawings.pdf") as pdf:
        pdf.savefig(fig1, bbox_inches="tight")
        pdf.savefig(fig2, bbox_inches="tight")
    print("Saved combined PDF")

    plt.close("all")


if __name__ == "__main__":
    main()
