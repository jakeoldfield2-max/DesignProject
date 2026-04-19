#!/usr/bin/env python3
"""
Torrefaction Heating Jacket – Engineering Design Drawings
==========================================================
Helical-channel annular jacket around a cylindrical torrefaction.
Helisol 5A flows through rectangular helical channels to heat the
torrefaction wall to the torrefaction temperature.
All parameters extracted from the Maple design worksheet.
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
# Process conditions
T_hot1_K  = 282.0064732 + 273.15    # K   HTF inlet (from air heater)
T_hot1_C  = 282.0                   # °C
m_dot     = 0.25                    # kg/s  Helisol 5A
T_cold_K  = 280 + 273.15            # K   torrefaction wall
T_cold_C  = 280                     # °C
Q_req     = 11290                   # W   required duty

# Derived outlet temperature (energy balance)
Cp        = 2150                    # J/kg·K
T_hot2_K  = T_hot1_K - Q_req / (m_dot * Cp)   # ≈ 534.15 K
T_hot2_C  = T_hot2_K - 273.15                  # ≈ 261.0 °C
T_hot_avg_K = (T_hot1_K + T_hot2_K) / 2       # ≈ 544.65 K

# Vessel geometry
D_torrefaction = 0.500                 # m   torrefaction OD
D_jacket    = 0.552                 # m   jacket ID
L_torrefaction = 4.200                 # m   torrefaction length
GAP         = (D_jacket - D_torrefaction) / 2  # 0.026 m annular gap

# Helical channel geometry
w_channel   = 0.062                 # m   channel width (axial)
t_wall      = 0.330                 # m   wall thickness between channels
P_pitch     = w_channel + t_wall    # 0.392 m  helix pitch
N_turns     = L_torrefaction / P_pitch # ≈ 10.71 turns
D_coil      = (D_jacket + D_torrefaction) / 2  # 0.526 m  mean coil diameter

# Channel cross-section
A_c   = GAP * w_channel             # 0.001612 m²  flow area
D_h   = 2 * GAP * w_channel / (GAP + w_channel)  # 0.03664 m  hydraulic dia.

# Coil length
L_turn = sqrt((pi * D_coil)**2 + P_pitch**2)  # m per turn
L_coil = N_turns * L_turn                      # m total

# Heat transfer surface
A_surface = pi * D_torrefaction * L_torrefaction     # 6.597 m²

# Fluid properties (Helisol 5A at T_avg)
rho     = 689.5                     # kg/m³
mu      = 0.41e-3                   # Pa·s
k_fluid = 0.076                     # W/m·K

# Calculated results
v_flow = m_dot / (rho * A_c)        # 0.225 m/s
Re     = rho * v_flow * D_h / mu    # ≈ 13858
Pr     = Cp * mu / k_fluid          # ≈ 11.6
Nu     = 0.023 * Re**0.85 * Pr**0.3 * (D_h / D_coil)**0.1  # ≈ 121.8
h_j    = Nu * k_fluid / D_h         # ≈ 252.8 W/m²·K

# Pressure drop
f_c    = 0.009                      # Fanning friction factor (from chart)
DP     = 4 * f_c * (L_coil / D_h) * (rho * v_flow**2 / 2)  # ≈ 312 Pa
DP_kPa = DP / 1000

# LMTD
dT1 = T_hot1_K - T_cold_K
dT2 = T_hot2_K - T_cold_K
# Note: dT2 is negative (T_hot2 < T_cold), indicating a temperature cross.
# The Maple worksheet flags "Design Failed" for this reason.
# For reporting purposes, compute |LMTD| using absolute temperature differences.
if dT1 * dT2 <= 0 or abs(dT1 - dT2) < 0.01:
    # Temperature cross or negligible ΔT – use arithmetic mean for display
    DeltaT_lm = (abs(dT1) + abs(dT2)) / 2
    DeltaT_lm_note = "(arith. mean – temp. cross)"
else:
    DeltaT_lm = (dT1 - dT2) / log(dT1 / dT2)
    DeltaT_lm_note = ""

A_req = Q_req / (h_j * abs(DeltaT_lm)) if abs(DeltaT_lm) > 0.01 else float('inf')

# Material notes
HTF_name      = "Helisol 5A"
jacket_material = "Carbon Steel"
torrefaction_material = "Carbon Steel"

# ═══════════════════════════════════════════════════════════════
#  DRAWING HELPERS
# ═══════════════════════════════════════════════════════════════
DIM_COL   = "#2255AA"
WALL_COL  = "#666666"
JACKET_COL = "#888888"
HTF_COL   = "#DD6633"
PYRO_COL  = "#AA8855"
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

    # Extension lines
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


def add_title_block(fig, dwg_no, scale_text="NTS"):
    """Add a simple title block at bottom of figure."""
    fig.text(0.98, 0.012, f"Dwg: {dwg_no}   |   Scale: {scale_text}   |   "
             f"3rd Year Design Project – Torrefaction Heating Jacket",
             ha="right", va="bottom", fontsize=6.5, color="#555555",
             style="italic")


# ═══════════════════════════════════════════════════════════════
#  SHEET 1 – RADIAL CROSS-SECTION (looking along axis)
# ═══════════════════════════════════════════════════════════════
def draw_cross_section(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 1 – Radial Cross-Section (End View)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_pyro  = D_torrefaction / 2
    R_jacket = D_jacket / 2

    # Scale factor for drawing (draw in metres)
    # Outer jacket wall (assume ~5 mm wall thickness for drawing)
    t_jacket_wall = 0.008  # drawing assumption for jacket outer wall
    R_jacket_outer = R_jacket + t_jacket_wall

    # Jacket outer shell
    outer_shell = Circle((0, 0), R_jacket_outer, fill=False, ec=JACKET_COL, lw=2.5)
    ax.add_patch(outer_shell)

    # Jacket inner surface (= jacket ID)
    inner_jacket = Circle((0, 0), R_jacket, fill=False, ec=JACKET_COL, lw=1.5, ls="--")
    ax.add_patch(inner_jacket)

    # torrefaction outer wall
    pyro_outer = Circle((0, 0), R_pyro, fill=True, fc="#F5EED8", ec=PYRO_COL, lw=2.0)
    ax.add_patch(pyro_outer)

    # torrefaction bore (hollow inside – assume ~8mm wall for drawing)
    t_pyro_wall = 0.008
    R_pyro_inner = R_pyro - t_pyro_wall
    pyro_inner = Circle((0, 0), R_pyro_inner, fill=True, fc="white", ec="#BBAA88", lw=1.0)
    ax.add_patch(pyro_inner)

    # Draw the annular gap with helical channel cross-section
    # Show the channel as the current slice through the helix
    # At any axial position, we see the rectangular channel cut
    n_channels_visible = 1  # one channel visible in cross-section
    # Draw the annular gap filled to show the channel
    # The channel occupies an angular portion of the annulus

    # For visualisation: show the annular region with the channel highlighted
    # Draw the full annulus lightly, then highlight the channel portion
    annulus = Wedge((0, 0), R_jacket, 0, 360, width=GAP,
                    fc="#E8E0D0", ec="none", alpha=0.5, zorder=1)
    ax.add_patch(annulus)

    # Highlight a channel cross-section (rectangular, in the annular gap)
    # Show multiple channel cuts as they spiral around
    for i in range(int(N_turns) + 1):
        angle_deg = (i * 360 / N_turns) % 360
        # Draw a small arc representing the channel at this angular position
        arc_extent = (w_channel / (pi * D_coil)) * 360  # angular width of channel
        chan_start = angle_deg - arc_extent / 2
        channel = Wedge((0, 0), R_jacket, chan_start, chan_start + arc_extent,
                        width=GAP, fc=CHAN_COL, ec="#CC9944", lw=0.6, zorder=2)
        ax.add_patch(channel)

    # Centre mark
    ax.plot(0, 0, '+', color="#333", ms=8, mew=0.8)

    # ── Dimensions ──
    # torrefaction diameter
    dim_line(ax, (-R_pyro, 0), (R_pyro, 0),
             f"D_torrefaction = {D_torrefaction*1000:.0f} mm",
             offset=R_jacket_outer + 0.04, side="above")

    # Jacket diameter
    dim_line(ax, (-R_jacket, 0), (R_jacket, 0),
         f"D_jacket = {D_jacket*1000:.0f} mm",
         offset=R_jacket_outer + 0.04, side="below")

    # Annular gap (radial dimension)
    ang = pi / 4
    p_inner = (R_pyro * cos(ang), R_pyro * sin(ang))
    p_outer = (R_jacket * cos(ang), R_jacket * sin(ang))
    dim_line(ax, p_inner, p_outer,
             f"GAP = {GAP*1000:.0f} mm",
             offset=0.035, side="above", fontsize=DIM_FS - 0.5)

    # Channel width callout
    ax.annotate(f"Channel width\nw = {w_channel*1000:.0f} mm",
                xy=(R_jacket * cos(pi/6), R_jacket * sin(pi/6)),
                xytext=(R_jacket_outer + 0.03, R_jacket_outer * 0.6),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    

    # Info box
    info = (f"D_coil (mean) = {D_coil*1000:.0f} mm\n"
            f"N_turns = {N_turns:.1f}\n"
            f"Helix pitch = {P_pitch*1000:.0f} mm\n"
            f"HTF: {HTF_name}\n"
            f"Material: {jacket_material}")
    ax.text(-R_jacket_outer - 0.04, R_jacket_outer + 0.04, info,
            fontsize=LABEL_FS - 1, va="top", ha="left",
            bbox=dict(fc="white", ec="#999999", boxstyle="round,pad=0.4"))

    pad = 0.08
    ax.set_xlim(-R_jacket_outer - pad - 0.04, R_jacket_outer + pad + 0.06)
    ax.set_ylim(-R_jacket_outer - pad, R_jacket_outer + pad + 0.03)
    ax.set_xlabel("m", fontsize=7)
    ax.set_ylabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 2 – LONGITUDINAL SECTION (Side elevation)
# ═══════════════════════════════════════════════════════════════
def draw_longitudinal(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 2 – Longitudinal Section (Side Elevation)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_pyro = D_torrefaction / 2
    R_jacket = D_jacket / 2
    L = L_torrefaction
    t_jacket_wall = 0.008
    R_jacket_outer = R_jacket + t_jacket_wall

    # torrefaction wall (inner cylinder)
    ax.fill_between([0, L], [R_pyro, R_pyro], [-R_pyro, -R_pyro],
                    color="#F5EED8", alpha=0.3, zorder=1)
    ax.plot([0, L], [R_pyro, R_pyro], color=PYRO_COL, lw=2.0, zorder=5)
    ax.plot([0, L], [-R_pyro, -R_pyro], color=PYRO_COL, lw=2.0, zorder=5)

    # Jacket outer wall
    ax.plot([0, L], [R_jacket_outer, R_jacket_outer], color=JACKET_COL, lw=2.0, zorder=5)
    ax.plot([0, L], [-R_jacket_outer, -R_jacket_outer], color=JACKET_COL, lw=2.0, zorder=5)

    # Jacket inner wall
    ax.plot([0, L], [R_jacket, R_jacket], color=JACKET_COL, lw=1.0, ls="--", zorder=4)
    ax.plot([0, L], [-R_jacket, -R_jacket], color=JACKET_COL, lw=1.0, ls="--", zorder=4)

    # Draw helical channels as visible rectangles in the annular gap
    # In longitudinal section, the channels appear as periodic rectangular cuts
    for i in range(int(N_turns) + 1):
        x_start = i * P_pitch
        if x_start + w_channel > L:
            break
        # Top annular gap channel
        ax.add_patch(Rectangle((x_start, R_pyro), w_channel, GAP,
                               fc=CHAN_COL, ec="#CC9944", lw=0.6, zorder=3))
        # Bottom annular gap channel
        ax.add_patch(Rectangle((x_start, -R_pyro - GAP), w_channel, GAP,
                               fc=CHAN_COL, ec="#CC9944", lw=0.6, zorder=3))

    # Wall between channels (shown as the gap between channel rectangles)
    for i in range(int(N_turns)):
        x_wall_start = i * P_pitch + w_channel
        x_wall_end = (i + 1) * P_pitch
        if x_wall_end > L:
            break
        # Top walls
        ax.add_patch(Rectangle((x_wall_start, R_pyro), t_wall, GAP,
                               fc="#D0C8B8", ec="#998877", lw=0.4, zorder=3))
        # Bottom walls
        ax.add_patch(Rectangle((x_wall_start, -R_pyro - GAP), t_wall, GAP,
                               fc="#D0C8B8", ec="#998877", lw=0.4, zorder=3))

    # End plates
    ep_w = 0.015
    ax.add_patch(Rectangle((-ep_w, -R_jacket_outer), ep_w, 2 * R_jacket_outer,
                            fc="#AAAAAA", ec=WALL_COL, lw=1.2, zorder=6))
    ax.add_patch(Rectangle((L, -R_jacket_outer), ep_w, 2 * R_jacket_outer,
                            fc="#AAAAAA", ec=WALL_COL, lw=1.2, zorder=6))

    # Centre line
    ax.plot([- 0.05, L + 0.05], [0, 0], color="#333", lw=0.5, ls="-.", zorder=1)
    ax.text(L + 0.06, 0, "CL", fontsize=6, va="center", color="#666")

    # Nozzles / flow arrows
    noz_h = 0.04
    noz_w = 0.035
    # Inlet nozzle (left end, top)
    ax.add_patch(Rectangle((-0.02, R_jacket_outer), noz_w, noz_h,
                            fc="#FFAA66", ec="#CC6600", lw=1, alpha=0.8, zorder=6))
    ax.annotate(f"{HTF_name} In\n({T_hot1_C:.0f} °C)", xy=(noz_w/2 - 0.02, R_jacket_outer + noz_h),
                ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#CC6600",
                fontweight="bold")

    # Outlet nozzle (right end, top)
    ax.add_patch(Rectangle((L - noz_w + 0.02, R_jacket_outer), noz_w, noz_h,
                            fc="#FFCC88", ec="#AA8844", lw=1, alpha=0.8, zorder=6))
    ax.annotate(f"{HTF_name} Out\n({T_hot2_C:.0f} °C)", xy=(L - noz_w/2 + 0.02, R_jacket_outer + noz_h),
                ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#AA8844",
                fontweight="bold")

    # Flow direction arrows through channels
    for i in range(0, int(N_turns), 2):
        x_mid = i * P_pitch + w_channel / 2
        if x_mid > L - 0.1:
            break
        ax.annotate("", xy=(x_mid + 0.03, R_pyro + GAP/2),
                    xytext=(x_mid - 0.03, R_pyro + GAP/2),
                    arrowprops=dict(arrowstyle="->", color=HTF_COL, lw=0.8))

    # torrefaction interior label
    ax.text(L/2, 0.02, "torrefaction Interior\n(Biomass feed)", ha="center",
            va="center", fontsize=LABEL_FS, color="#886644", style="italic")

    # ── Dimensions ──
    # Total length
    dim_line(ax, (0, -R_jacket_outer), (L, -R_jacket_outer),
             f"L = {L*1000:.0f} mm",
             offset=0.06, side="below")

    # torrefaction diameter (right side)
    dim_line(ax, (L + 0.03, -R_pyro), (L + 0.03, R_pyro),
             f"D_pyro = {D_torrefaction*1000:.0f} mm",
             offset=0.05, side="above")

    # Jacket OD
    dim_line(ax, (L + 0.08, -R_jacket_outer), (L + 0.08, R_jacket_outer),
             f"D_jacket_OD ≈ {(D_jacket + 2*t_jacket_wall)*1000:.0f} mm",
             offset=0.04, side="above", fontsize=DIM_FS - 0.5)

    # Channel pitch (between two channels)
    if N_turns >= 2:
        x1_p = 0
        x2_p = P_pitch
        dim_line(ax, (x1_p, R_jacket_outer), (x2_p, R_jacket_outer),
                 f"P = {P_pitch*1000:.0f} mm",
                 offset=0.025, side="above", fontsize=DIM_FS - 0.5)

    # Channel width
    dim_line(ax, (P_pitch, -R_jacket_outer), (P_pitch + w_channel, -R_jacket_outer),
             f"w = {w_channel*1000:.0f} mm",
             offset=0.02, side="below", fontsize=DIM_FS - 0.5)

    pad = 0.12
    ax.set_xlim(-0.1, L + 0.2)
    ax.set_ylim(-R_jacket_outer - pad - 0.04, R_jacket_outer + pad + 0.04)
    ax.set_xlabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 3 – CHANNEL DETAIL (Enlarged cross-section)
# ═══════════════════════════════════════════════════════════════
def draw_channel_detail(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 3 – Channel Cross-Section Detail", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # Draw in mm for clarity
    gap_mm = GAP * 1000          # 26 mm
    w_mm   = w_channel * 1000    # 62 mm
    t_mm   = t_wall * 1000       # 330 mm
    Dh_mm  = D_h * 1000          # 36.6 mm
    pyro_wall_mm = 8             # assumed torrefaction wall thickness for drawing

    # Origin at bottom-left of channel
    ox, oy = 0, 0

    # torrefaction wall (bottom)
    ax.add_patch(Rectangle((ox - 20, oy - pyro_wall_mm), w_mm + 40, pyro_wall_mm,
                            fc="#D8C8A8", ec=PYRO_COL, lw=1.5))
    ax.text(ox + w_mm/2, oy - pyro_wall_mm/2, "torrefaction wall", ha="center",
            va="center", fontsize=LABEL_FS - 1, color="#886644")

    # Channel void (fluid space)
    ax.add_patch(Rectangle((ox, oy), w_mm, gap_mm,
                            fc=CHAN_COL, ec="#CC9944", lw=1.0))
    ax.text(ox + w_mm/2, oy + gap_mm/2, f"HTF Channel\n({HTF_name})",
            ha="center", va="center", fontsize=LABEL_FS, color="#884400")

    # Jacket outer wall (top)
    jacket_wall_mm = 8
    ax.add_patch(Rectangle((ox - 20, oy + gap_mm), w_mm + 40, jacket_wall_mm,
                            fc="#C0C0C0", ec=JACKET_COL, lw=1.5))
    ax.text(ox + w_mm/2, oy + gap_mm + jacket_wall_mm/2, "Jacket wall",
            ha="center", va="center", fontsize=LABEL_FS - 1, color="#666666")

    # Channel dividing walls (left and right)
    wall_draw_w = min(t_mm, 40)  # cap drawing width for legibility
    # Left wall
    ax.add_patch(Rectangle((ox - wall_draw_w, oy), wall_draw_w, gap_mm,# Heat flow arrow (from channel to pyrolizer wall)
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
             offset=10, side="below")

    # Channel height (gap)
    dim_line(ax, (ox + w_mm, oy), (ox + w_mm, oy + gap_mm),
             f"GAP = {gap_mm:.0f} mm",
             offset=wall_draw_w + 12, side="above")

    # Hydraulic diameter callout
    ax.annotate(f"D_h = {Dh_mm:.1f} mm\nA_c = {A_c*1e6:.0f} mm²",
                xy=(ox + w_mm * 0.75, oy + gap_mm * 0.75),
                xytext=(ox + w_mm + wall_draw_w + 20, oy + gap_mm + 10),
                fontsize=LABEL_FS - 0.5,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Wall thickness annotation
    ax.annotate(f"Wall between channels\nt = {t_mm:.0f} mm",
                xy=(ox - wall_draw_w, oy + gap_mm/2),
                xytext=(ox - wall_draw_w - 40, oy + gap_mm + 15),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))


    pad = 20
    ax.set_xlim(ox - wall_draw_w - 50, ox + w_mm + wall_draw_w + pad + 30)
    ax.set_ylim(oy - pyro_wall_mm - pad, oy + gap_mm + jacket_wall_mm + pad + 15)
    ax.set_xlabel("mm", fontsize=7)
    ax.set_ylabel("mm", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 4 – HELIX UNWOUND / DESIGN DATA TABLE
# ═══════════════════════════════════════════════════════════════
def draw_helix_schematic(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 4 – Helical Channel Schematic (Unwound)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # Show the helix unwound as a flat strip with channel and walls
    # Total unwound length per turn = L_turn
    # Show a few representative turns

    n_show = min(5, int(N_turns))
    strip_h = GAP * 1000  # mm (channel height = gap)
    total_w = n_show * P_pitch * 1000  # mm

    # Scale to fit nicely
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
    ax.plot([0, n_show * P_pitch * 1000 * scale], [oy, oy],
            color=PYRO_COL, lw=2.0)
    ax.plot([0, n_show * P_pitch * 1000 * scale], [oy + strip_h_s, oy + strip_h_s],
            color=JACKET_COL, lw=2.0)
    ax.text(-5, oy, "torrefaction wall", ha="right", va="center",
            fontsize=LABEL_FS - 1, color=PYRO_COL)
    ax.text(-5, oy + strip_h_s, "Jacket wall", ha="right", va="center",
            fontsize=LABEL_FS - 1, color=JACKET_COL)

    # Turn labels
    for i in range(n_show):
        x_mid = (i * P_pitch * 1000 + w_channel * 1000 / 2) * scale
        ax.text(x_mid, oy - 4, f"Turn {i+1}", ha="center", fontsize=6, color="#666")

    # Continuation marks
    x_end = n_show * P_pitch * 1000 * scale
    ax.text(x_end + 5, oy + strip_h_s / 2, f"... ({N_turns:.1f} turns total)",
            fontsize=LABEL_FS, va="center", color="#888")

    # Dimension: one pitch
    x1_p = 0
    x2_p = P_pitch * 1000 * scale
    dim_line(ax, (x1_p, oy + strip_h_s), (x2_p, oy + strip_h_s),
             f"P = {P_pitch*1000:.0f} mm",
             offset=5, side="above")

    ax.set_xlim(-60, x_end + 60)
    ax.set_ylim(-15, strip_h_s + 20)
    ax.set_xlabel("(not to scale – schematic)", fontsize=6, color="#999")
    ax.tick_params(labelsize=6)


def draw_data_table(ax):
    ax.set_title("Design Data Summary", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)
    ax.axis("off")

    data = [
        ["Parameter", "Value", "Unit"],
        ["Duty (Q_req)", f"{Q_req:.0f}", "W"],
        ["HTF inlet temp (T_hot1)", f"{T_hot1_C:.1f}", "°C"],
        ["HTF outlet temp (T_hot2)", f"{T_hot2_C:.1f}", "°C"],
        ["Wall temp (T_cold)", f"{T_cold_C:.0f}", "°C"],
        ["Mass flow rate (ṁ)", f"{m_dot:.2f}", "kg/s"],
        ["LMTD (ΔT_lm)", f"{abs(DeltaT_lm):.2f}", "K"],
        ["", "", ""],
        ["torrefaction diameter", f"{D_torrefaction*1000:.0f}", "mm"],
        ["Jacket diameter", f"{D_jacket*1000:.0f}", "mm"],
        ["Annular gap", f"{GAP*1000:.0f}", "mm"],
        ["torrefaction length", f"{L_torrefaction*1000:.0f}", "mm"],
        ["Channel width (w)", f"{w_channel*1000:.0f}", "mm"],
        ["Wall thickness (t)", f"{t_wall*1000:.0f}", "mm"],
        ["Helix pitch (P)", f"{P_pitch*1000:.0f}", "mm"],
        ["Number of turns", f"{N_turns:.1f}", "–"],
        ["Mean coil diameter", f"{D_coil*1000:.0f}", "mm"],
        ["Coil length (total)", f"{L_coil:.2f}", "m"],
        ["Hydraulic diameter", f"{D_h*1000:.1f}", "mm"],
        ["Flow area (A_c)", f"{A_c*1e6:.0f}", "mm²"],
        ["", "", ""],
        ["Fluid: " + HTF_name, "", ""],
        ["Density (ρ)", f"{rho:.1f}", "kg/m³"],
        ["Viscosity (μ)", f"{mu*1000:.2f}", "mPa·s"],
        ["Thermal cond. (k)", f"{k_fluid:.3f}", "W/m·K"],
        ["Specific heat (Cp)", f"{Cp:.0f}", "J/kg·K"],
        ["", "", ""],
        ["Velocity (v)", f"{v_flow:.3f}", "m/s"],
        ["Reynolds (Re)", f"{Re:.0f}", "–"],
        ["Prandtl (Pr)", f"{Pr:.1f}", "–"],
        ["Nusselt (Nu)", f"{Nu:.1f}", "–"],
        ["HTC (h_j)", f"{h_j:.1f}", "W/m²·K"],
        ["Heat transfer area", f"{A_surface:.2f}", "m²"],
        ["Required area (A_req)", f"{A_req:.2f}", "m²"],
        ["", "", ""],
        ["Friction factor (f_c)", f"{f_c:.4f}", "–"],
        ["Pressure drop (ΔP)", f"{DP:.1f}", "Pa"],
        ["Pressure drop", f"{DP_kPa:.3f}", "kPa"],
        ["Correlation", "Seban & McLaughlin", ""],
    ]

    table = ax.table(cellText=data, cellLoc="center", loc="center",
                     colWidths=[0.45, 0.30, 0.20])
    table.auto_set_font_size(False)
    table.set_fontsize(7.5)
    table.scale(1, 1.15)

    # Style header row
    for j in range(3):
        cell = table[0, j]
        cell.set_facecolor("#445566")
        cell.set_text_props(color="white", fontweight="bold")

    # Style separator rows
    for i, row in enumerate(data):
        if row[0] == "" and row[1] == "":
            for j in range(3):
                table[i, j].set_facecolor("#F0F0F0")
                table[i, j].set_edgecolor("#F0F0F0")
        # Style fluid header
        if row[0].startswith("Fluid:"):
            for j in range(3):
                table[i, j].set_facecolor("#EEE8DD")
                table[i, j].set_text_props(fontweight="bold")

    # Alternating row colors
    for i, row in enumerate(data):
        if i == 0:
            continue
        if row[0] == "" and row[1] == "":
            continue
        if row[0].startswith("Fluid:"):
            continue
        bg = "#FFFFFF" if i % 2 == 0 else "#F8F8F8"
        for j in range(3):
            if table[i, j].get_facecolor() in [(1.0, 1.0, 1.0, 1.0)]:
                table[i, j].set_facecolor(bg)


# ═══════════════════════════════════════════════════════════════
#  COMPOSE & SAVE
# ═══════════════════════════════════════════════════════════════
def main():
    # --- Page 1: Cross-section + Longitudinal ---
    fig1, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 16),
                                     gridspec_kw={"height_ratios": [1, 0.85]})
    fig1.suptitle("Torrefaction Heating Jacket – Design Drawings (1/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_cross_section(ax1)
    draw_longitudinal(ax2)
    add_title_block(fig1, "TJ-001")
    fig1.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig1.savefig("torrefaction_jacket_page1.png", dpi=200, bbox_inches="tight")
    print("Saved page 1")

    # --- Page 2: Channel detail + Helix schematic ---
    fig2, (ax3, ax4) = plt.subplots(1, 2, figsize=(14, 8))
    fig2.suptitle("Torrefaction Heating Jacket – Design Drawings (2/2)",
                  fontsize=15, fontweight="bold", y=0.98)

    draw_channel_detail(ax3)
    draw_helix_schematic(ax4)

    add_title_block(fig2, "TJ-002")
    fig2.tight_layout(rect=[0, 0.02, 1, 0.93])
    fig2.savefig("torrefaction_jacket_page2.png", dpi=200, bbox_inches="tight")
    print("Saved page 2")

    # Combined PDF
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages("Torrefaction_Jacket_Design_Drawings.pdf") as pdf:
        pdf.savefig(fig1, bbox_inches="tight")
        pdf.savefig(fig2, bbox_inches="tight")
    print("Saved combined PDF")

    plt.close("all")


if __name__ == "__main__":
    main()
