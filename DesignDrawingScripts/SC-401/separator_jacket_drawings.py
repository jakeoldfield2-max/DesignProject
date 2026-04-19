#!/usr/bin/env python3
"""
Screw Separator Cooling Jacket – Engineering Design Drawings
==============================================================
Helical-channel annular jacket around a constant-diameter screw separator.
Helisol 5A flows through rectangular helical channels to cool the
separator wall. All parameters extracted from the Maple design worksheet.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch, Arc, Rectangle, Circle, Wedge
from matplotlib.collections import PatchCollection
import numpy as np
from math import pi, sqrt, cos, sin, ceil, log

# ═══════════════════════════════════════════════════════════════
#  DESIGN PARAMETERS (from Maple worksheet)
# ═══════════════════════════════════════════════════════════════
# Process conditions  (Cold = fluid, Hot = wall)
T_cold1_K = 281.001822 + 273.15      # K   fluid inlet
T_cold1_C = 281.0                     # °C
m_dot     = 0.25                      # kg/s  Helisol 5A
T_hot1_K  = 500 + 273.15             # K   wall temp at separator inlet (hot end)
T_hot1_C  = 500                       # °C
T_hot2_K  = 285 + 273.15             # K   wall temp at separator outlet (cool end)
T_hot2_C  = 285                       # °C
Q_req     = 1100                      # W   duty to extract

# Derived fluid outlet temperature (energy balance)
Cp        = 2150                      # J/kg·K
T_cold2_K = T_cold1_K + Q_req / (m_dot * Cp)   # ≈ 556.20 K
T_cold2_C = T_cold2_K - 273.15                  # ≈ 283.05 °C

# Vessel geometry
D_separator = 0.1016                  # m   separator OD
GAP         = 0.010                   # m   annular gap (10 mm)
D_jacket    = D_separator + 2 * GAP  # 0.1216 m  jacket ID
L_jacket    = 1.200                   # m   jacket length

# Helical channel geometry
w_channel   = 0.030                   # m   channel width (axial)
t_wall      = 0.020                   # m   wall thickness between channels
P_pitch     = w_channel + t_wall      # 0.050 m  helix pitch
N_turns     = L_jacket / P_pitch      # 24 turns
D_coil      = (D_jacket + D_separator) / 2  # 0.1116 m  mean coil diameter

# Channel cross-section
A_c   = GAP * w_channel               # 0.0003 m²  flow area
D_h   = 2 * GAP * w_channel / (GAP + w_channel)  # 0.015 m  hydraulic dia.

# Coil length
L_turn = sqrt((pi * D_separator)**2 + P_pitch**2)  # m per turn
L_coil = N_turns * L_turn                           # m total

# Heat transfer surface
A_surface = pi * D_separator * L_jacket              # 0.383 m²

# Fluid properties (Helisol 5A)
rho     = 689.5                       # kg/m³
mu      = 0.41e-3                     # Pa·s
k_fluid = 0.076                       # W/m·K

# Calculated results
v_flow = m_dot / (rho * A_c)          # 1.209 m/s
Re     = rho * v_flow * D_h / mu      # ≈ 30488
Pr     = Cp * mu / k_fluid            # ≈ 11.6
Nu     = 0.023 * Re**0.85 * Pr**0.3 * (D_h / D_coil)**0.1  # ≈ 254.3
h_j    = Nu * k_fluid / D_h           # ≈ 1288.6 W/m²·K

# LMTD  (co-current: hot wall cools from 500→285 °C, fluid heats from 281→283 °C)
dT1 = T_hot1_K - T_cold2_K   # hot end
dT2 = T_hot2_K - T_cold1_K   # cold end
if dT1 * dT2 <= 0 or abs(dT1 - dT2) < 0.01:
    DeltaT_lm = (abs(dT1) + abs(dT2)) / 2
else:
    DeltaT_lm = (dT1 - dT2) / log(dT1 / dT2)

A_req = Q_req / (h_j * abs(DeltaT_lm)) if abs(DeltaT_lm) > 0.01 else float('inf')

# Pressure drop  (Mishra & Gupta correlation)
f_c    = 0.3164 / Re**0.25 + 0.03 * (D_h / D_coil)**0.5
DP     = 4 * f_c * (L_coil / D_h) * (rho * v_flow**2 / 2)
DP_kPa = DP / 1000

# Material notes
HTF_name           = "Helisol 5A"
jacket_material    = "Carbon Steel"
separator_material = "Carbon Steel"

# ═══════════════════════════════════════════════════════════════
#  DRAWING HELPERS
# ═══════════════════════════════════════════════════════════════
DIM_COL   = "#2255AA"
WALL_COL  = "#666666"
JACKET_COL = "#888888"
HTF_COL   = "#DD6633"
SEP_COL   = "#7799AA"
CHAN_COL  = "#FFCC88"
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
             f"3rd Year Design Project – Screw Separator Cooling Jacket",
             ha="right", va="bottom", fontsize=6.5, color="#555555",
             style="italic")


# ═══════════════════════════════════════════════════════════════
#  SHEET 1 – RADIAL CROSS-SECTION (End View)
# ═══════════════════════════════════════════════════════════════
def draw_cross_section(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 1 – Radial Cross-Section (End View)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_sep    = D_separator / 2
    R_jacket = D_jacket / 2
    t_jacket_wall = 0.005  # assumed jacket outer wall for drawing
    R_jacket_outer = R_jacket + t_jacket_wall

    # Jacket outer shell
    outer_shell = Circle((0, 0), R_jacket_outer, fill=False, ec=JACKET_COL, lw=2.5)
    ax.add_patch(outer_shell)

    # Jacket inner surface
    inner_jacket = Circle((0, 0), R_jacket, fill=False, ec=JACKET_COL, lw=1.5, ls="--")
    ax.add_patch(inner_jacket)

    # Separator outer wall
    sep_outer = Circle((0, 0), R_sep, fill=True, fc="#E0EEF0", ec=SEP_COL, lw=2.0)
    ax.add_patch(sep_outer)

    # Separator bore
    t_sep_wall = 0.004
    R_sep_inner = R_sep - t_sep_wall
    sep_inner = Circle((0, 0), R_sep_inner, fill=True, fc="white", ec="#99AABB", lw=1.0)
    ax.add_patch(sep_inner)

    # Annulus fill
    annulus = Wedge((0, 0), R_jacket, 0, 360, width=GAP,
                    fc="#E8E0D0", ec="none", alpha=0.5, zorder=1)
    ax.add_patch(annulus)

    # Helical channel cuts
    for i in range(int(N_turns) + 1):
        angle_deg = (i * 360 / N_turns) % 360
        arc_extent = (w_channel / (pi * D_coil)) * 360
        chan_start = angle_deg - arc_extent / 2
        channel = Wedge((0, 0), R_jacket, chan_start, chan_start + arc_extent,
                        width=GAP, fc=CHAN_COL, ec="#CC9944", lw=0.6, zorder=2)
        ax.add_patch(channel)

    # Centre mark
    ax.plot(0, 0, '+', color="#333", ms=8, mew=0.8)

    # ── Dimensions ──
    # Separator diameter (top)
    dim_line(ax, (-R_sep, 0), (R_sep, 0),
             f"D_separator = {D_separator*1000:.1f} mm",
             offset=R_jacket_outer + 0.025, side="above")

    # Jacket diameter (bottom, horizontal)
    dim_line(ax, (-R_jacket, 0), (R_jacket, 0),
             f"D_jacket = {D_jacket*1000:.1f} mm",
             offset=R_jacket_outer + 0.025, side="below")

    # Annular gap
    ang = pi / 3
    p_inner = (R_sep * cos(ang), R_sep * sin(ang))
    p_outer = (R_jacket * cos(ang), R_jacket * sin(ang))
    dim_line(ax, p_inner, p_outer,
             f"GAP = {GAP*1000:.0f} mm",
             offset=0.03, side="above", fontsize=DIM_FS - 0.5, text_offset=0.005)

    # Channel width callout
    ax.annotate(f"Channel width\nw = {w_channel*1000:.0f} mm",
                xy=(R_jacket * cos(pi/6), R_jacket * sin(pi/6)),
                xytext=(R_jacket_outer + 0.02, R_jacket_outer * 0.5),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Labels
    ax.text(0, 0.005, "Separator\n(bore)", ha="center", va="center",
            fontsize=LABEL_FS - 1, color="#557788")

    # Info box
    info = (f"D_coil (mean) = {D_coil*1000:.1f} mm\n"
            f"N_turns = {N_turns:.0f}\n"
            f"Helix pitch = {P_pitch*1000:.0f} mm\n"
            f"HTF: {HTF_name}\n"
            f"Material: {jacket_material}")
    ax.text(-R_jacket_outer - 0.04, R_jacket_outer + 0.04, info,
            fontsize=LABEL_FS - 1, va="top", ha="left",
            bbox=dict(fc="white", ec="#999999", boxstyle="round,pad=0.4"))

    pad = 0.05
    ax.set_xlim(-R_jacket_outer - pad - 0.04, R_jacket_outer + pad + 0.04)
    ax.set_ylim(-R_jacket_outer - pad - 0.02, R_jacket_outer + pad + 0.02)
    ax.set_xlabel("m", fontsize=7)
    ax.set_ylabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 2 – LONGITUDINAL SECTION (Side Elevation)
# ═══════════════════════════════════════════════════════════════
def draw_longitudinal(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 2 – Longitudinal Section (Side Elevation)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_sep = D_separator / 2
    R_jacket = D_jacket / 2
    L = L_jacket
    t_jacket_wall = 0.005
    R_jacket_outer = R_jacket + t_jacket_wall

    # Separator wall (inner cylinder)
    ax.fill_between([0, L], [R_sep, R_sep], [-R_sep, -R_sep],
                    color="#E0EEF0", alpha=0.3, zorder=1)
    ax.plot([0, L], [R_sep, R_sep], color=SEP_COL, lw=2.0, zorder=5)
    ax.plot([0, L], [-R_sep, -R_sep], color=SEP_COL, lw=2.0, zorder=5)

    # Jacket outer wall
    ax.plot([0, L], [R_jacket_outer, R_jacket_outer], color=JACKET_COL, lw=2.0, zorder=5)
    ax.plot([0, L], [-R_jacket_outer, -R_jacket_outer], color=JACKET_COL, lw=2.0, zorder=5)

    # Jacket inner wall
    ax.plot([0, L], [R_jacket, R_jacket], color=JACKET_COL, lw=1.0, ls="--", zorder=4)
    ax.plot([0, L], [-R_jacket, -R_jacket], color=JACKET_COL, lw=1.0, ls="--", zorder=4)

    # Helical channels
    for i in range(int(N_turns) + 1):
        x_start = i * P_pitch
        if x_start + w_channel > L:
            break
        # Top channel
        ax.add_patch(Rectangle((x_start, R_sep), w_channel, GAP,
                               fc=CHAN_COL, ec="#CC9944", lw=0.6, zorder=3))
        # Bottom channel
        ax.add_patch(Rectangle((x_start, -R_sep - GAP), w_channel, GAP,
                               fc=CHAN_COL, ec="#CC9944", lw=0.6, zorder=3))

    # Walls between channels
    for i in range(int(N_turns)):
        x_wall_start = i * P_pitch + w_channel
        x_wall_end = (i + 1) * P_pitch
        if x_wall_end > L:
            break
        ax.add_patch(Rectangle((x_wall_start, R_sep), t_wall, GAP,
                               fc="#D0C8B8", ec="#998877", lw=0.4, zorder=3))
        ax.add_patch(Rectangle((x_wall_start, -R_sep - GAP), t_wall, GAP,
                               fc="#D0C8B8", ec="#998877", lw=0.4, zorder=3))

    # End plates
    ep_w = 0.008
    ax.add_patch(Rectangle((-ep_w, -R_jacket_outer), ep_w, 2 * R_jacket_outer,
                            fc="#AAAAAA", ec=WALL_COL, lw=1.2, zorder=6))
    ax.add_patch(Rectangle((L, -R_jacket_outer), ep_w, 2 * R_jacket_outer,
                            fc="#AAAAAA", ec=WALL_COL, lw=1.2, zorder=6))

    # Centre line
    ax.plot([-0.03, L + 0.03], [0, 0], color="#333", lw=0.5, ls="-.", zorder=1)
    ax.text(L + 0.035, 0, "CL", fontsize=6, va="center", color="#666")

    # Nozzles
    noz_h = 0.02
    noz_w = 0.018
    # Inlet (left, top)
    

    # Separator interior label
    ax.text(L/2, 0.005, "Screw Separator Interior", ha="center",
            va="center", fontsize=LABEL_FS, color="#557788", style="italic")

    # ── Dimensions ──
    # Total length
    dim_line(ax, (0, -R_jacket_outer), (L, -R_jacket_outer),
             f"L = {L*1000:.0f} mm",
             offset=0.035, side="below")

    # Separator diameter (right side)
    dim_line(ax, (L + 0.015, -R_sep), (L + 0.015, R_sep),
             f"D_sep = {D_separator*1000:.1f} mm",
             offset=0.025, side="above")

    # Jacket OD
    dim_line(ax, (L + 0.04, -R_jacket_outer), (L + 0.04, R_jacket_outer),
             f"D_jacket_OD ≈ {(D_jacket + 2*t_jacket_wall)*1000:.1f} mm",
             offset=0.02, side="above", fontsize=DIM_FS - 0.5)

    # Channel pitch
    if N_turns >= 2:
        dim_line(ax, (0, R_jacket_outer), (P_pitch, R_jacket_outer),
                 f"P = {P_pitch*1000:.0f} mm",
                 offset=0.015, side="above", fontsize=DIM_FS - 0.5)

    # Channel width
    dim_line(ax, (P_pitch, -R_jacket_outer), (P_pitch + w_channel, -R_jacket_outer),
             f"w = {w_channel*1000:.0f} mm",
             offset=0.012, side="below", fontsize=DIM_FS - 0.5)

    pad = 0.06
    ax.set_xlim(-0.05, L + 0.1)
    ax.set_ylim(-R_jacket_outer - pad - 0.02, R_jacket_outer + pad + 0.02)
    ax.set_xlabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 3 – CHANNEL DETAIL (Enlarged cross-section)
# ═══════════════════════════════════════════════════════════════
def draw_channel_detail(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 3 – Channel Cross-Section Detail", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # Draw in mm
    gap_mm = GAP * 1000           # 10 mm
    w_mm   = w_channel * 1000     # 30 mm
    t_mm   = t_wall * 1000        # 20 mm
    Dh_mm  = D_h * 1000           # 15 mm
    sep_wall_mm = 4               # assumed separator wall thickness

    ox, oy = 0, 0

    # Separator wall (bottom)
    ax.add_patch(Rectangle((ox - 15, oy - sep_wall_mm), w_mm + 30, sep_wall_mm,
                            fc="#C8DDE0", ec=SEP_COL, lw=1.5))
    ax.text(ox + w_mm/2, oy - sep_wall_mm/2, "Separator wall", ha="center",
            va="center", fontsize=LABEL_FS - 1, color="#557788")

    # Channel void
    ax.add_patch(Rectangle((ox, oy), w_mm, gap_mm,
                            fc=CHAN_COL, ec="#CC9944", lw=1.0))
    ax.text(ox + w_mm/2, oy + gap_mm/2, f"HTF Channel\n({HTF_name})",
            ha="center", va="center", fontsize=LABEL_FS, color="#884400")

    # Jacket wall (top)
    jacket_wall_mm = 5
    ax.add_patch(Rectangle((ox - 15, oy + gap_mm), w_mm + 30, jacket_wall_mm,
                            fc="#C0C0C0", ec=JACKET_COL, lw=1.5))
    ax.text(ox + w_mm/2, oy + gap_mm + jacket_wall_mm/2, "Jacket wall",
            ha="center", va="center", fontsize=LABEL_FS - 1, color="#666666")

    # Divider walls (full height – closed rectangular channel)
    wall_draw_w = min(t_mm, 20)
    # Left wall
    ax.add_patch(Rectangle((ox - wall_draw_w, oy), wall_draw_w, gap_mm,
                            fc="#D0C8B8", ec="#998877", lw=1.0))
    ax.text(ox - wall_draw_w/2, oy + gap_mm/2, "Wall\n(divider)", ha="center",
            va="center", fontsize=6, color="#887766", rotation=90)
    # Right wall
    ax.add_patch(Rectangle((ox + w_mm, oy), wall_draw_w, gap_mm,
                            fc="#D0C8B8", ec="#998877", lw=1.0))
    ax.text(ox + w_mm + wall_draw_w/2, oy + gap_mm/2, "Wall\n(divider)", ha="center",
            va="center", fontsize=6, color="#887766", rotation=90)

    # ── Dimensions ──
    # Channel width
    dim_line(ax, (ox, oy), (ox + w_mm, oy),
             f"w = {w_mm:.0f} mm",
             offset=8, side="below")

    # Channel height (gap)
    dim_line(ax, (ox + w_mm, oy), (ox + w_mm, oy + gap_mm),
             f"GAP = {gap_mm:.0f} mm",
             offset=wall_draw_w + 7, side="above", fontsize=DIM_FS / 2)

    # Hydraulic diameter callout
    ax.annotate(f"D_h = {Dh_mm:.1f} mm\nA_c = {A_c*1e6:.0f} mm²",
                xy=(ox + w_mm * 0.75, oy + gap_mm * 0.75),
                xytext=(ox + w_mm + wall_draw_w + 15, oy + gap_mm + 8),
                fontsize=LABEL_FS - 0.5,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Wall thickness annotation
    ax.annotate(f"Wall between channels\nt = {t_mm:.0f} mm",
                xy=(ox - wall_draw_w, oy + gap_mm/2),
                xytext=(ox - wall_draw_w - 30, oy + gap_mm + 10),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    pad = 15
    ax.set_xlim(ox - wall_draw_w - 40, ox + w_mm + wall_draw_w + pad + 25)
    ax.set_ylim(oy - sep_wall_mm - pad, oy + gap_mm + jacket_wall_mm + pad + 10)
    ax.set_xlabel("mm", fontsize=7)
    ax.set_ylabel("mm", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 4 – HELIX UNWOUND SCHEMATIC
# ═══════════════════════════════════════════════════════════════
def draw_helix_schematic(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 4 – Helical Channel Schematic (Unwound)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    n_show = min(8, int(N_turns))
    strip_h = GAP * 1000  # mm
    total_w = n_show * P_pitch * 1000

    scale = 200 / total_w if total_w > 0 else 1
    strip_h_s = strip_h * scale
    oy = 0

    for i in range(n_show):
        x_start = i * P_pitch * 1000 * scale
        w_s = w_channel * 1000 * scale
        t_s = t_wall * 1000 * scale

        # Channel
        ax.add_patch(Rectangle((x_start, oy), w_s, strip_h_s,
                                fc=CHAN_COL, ec="#CC9944", lw=0.8))
        # Wall
        if i < n_show - 1:
            ax.add_patch(Rectangle((x_start + w_s, oy), t_s, strip_h_s,
                                    fc="#D0C8B8", ec="#998877", lw=0.6))

        # Flow arrow
        ax.annotate("", xy=(x_start + w_s * 0.8, oy + strip_h_s / 2),
                    xytext=(x_start + w_s * 0.2, oy + strip_h_s / 2),
                    arrowprops=dict(arrowstyle="->", color=HTF_COL, lw=1.0))

    # Boundary labels
    x_end = n_show * P_pitch * 1000 * scale
    ax.plot([0, x_end], [oy, oy], color=SEP_COL, lw=2.0)
    ax.plot([0, x_end], [oy + strip_h_s, oy + strip_h_s], color=JACKET_COL, lw=2.0)
    ax.text(-5, oy, "Separator wall", ha="right", va="center",
            fontsize=LABEL_FS - 1, color=SEP_COL)
    ax.text(-5, oy + strip_h_s, "Jacket wall", ha="right", va="center",
            fontsize=LABEL_FS - 1, color=JACKET_COL)

    # Turn labels
    for i in range(n_show):
        x_mid = (i * P_pitch * 1000 + w_channel * 1000 / 2) * scale
        ax.text(x_mid, oy - 4, f"Turn {i+1}", ha="center", fontsize=6, color="#666")

    # Continuation
    ax.text(x_end + 5, oy + strip_h_s / 2, f"... ({N_turns:.0f} turns total)",
            fontsize=LABEL_FS, va="center", color="#888")

    # Pitch dimension
    x1_p = 0
    x2_p = P_pitch * 1000 * scale
    dim_line(ax, (x1_p, oy + strip_h_s), (x2_p, oy + strip_h_s),
             f"P = {P_pitch*1000:.0f} mm",
             offset=5, side="above")

    ax.set_xlim(-55, x_end + 60)
    ax.set_ylim(-15, strip_h_s + 20)
    ax.set_xlabel("(not to scale – schematic)", fontsize=6, color="#999")
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  COMPOSE & SAVE
# ═══════════════════════════════════════════════════════════════
def main():
    # --- Page 1: Cross-section + Longitudinal ---
    fig1, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 16),
                                     gridspec_kw={"height_ratios": [1, 0.85]})
    fig1.suptitle("Screw Separator Cooling Jacket – Design Drawings (1/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_cross_section(ax1)
    draw_longitudinal(ax2)
    add_title_block(fig1, "SJ-001")
    fig1.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig1.savefig("separator_jacket_page1.png", dpi=200, bbox_inches="tight")
    print("Saved page 1")

    # --- Page 2: Channel detail + Helix schematic ---
    fig2, (ax3, ax4) = plt.subplots(1, 2, figsize=(14, 8))
    fig2.suptitle("Screw Separator Cooling Jacket – Design Drawings (2/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_channel_detail(ax3)
    draw_helix_schematic(ax4)
    add_title_block(fig2, "SJ-002")
    fig2.tight_layout(rect=[0, 0.02, 1, 0.93])
    fig2.savefig("separator_jacket_page2.png", dpi=200, bbox_inches="tight")
    print("Saved page 2")

    # Combined PDF
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages("Separator_Jacket_Design_Drawings.pdf") as pdf:
        pdf.savefig(fig1, bbox_inches="tight")
        pdf.savefig(fig2, bbox_inches="tight")
    print("Saved combined PDF")

    plt.close("all")


if __name__ == "__main__":
    main()
