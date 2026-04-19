#!/usr/bin/env python3
"""
Pyrolizer Heating Jacket – Engineering Design Drawings (v2)
============================================================
SPIRAL-BAFFLE annular jacket wrapping a pyrolizer.
A single helical baffle with pitch 70 mm and thickness 5 mm creates
one continuous spiral flow channel in the 15 mm annulus between the
pyrolizer OD (318 mm) and the jacket ID (348 mm). Ternary eutectic
carbonate salt flows through the spiral channel.

Two thermal zones:
    L1 – heating zone   (2.05 m axial, 29.26 m spiral path)
    L2 – constant-T zone (2.57 m axial, 36.68 m spiral path)
Total flow path: ~65.94 m.

All parameters and computed values taken from the Maple worksheet
(Pyrolysis Heating Jacket PDF). Design status: SUCCESSFUL.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Rectangle, Circle, Wedge, Arc, FancyArrow, Polygon
import numpy as np
from math import pi, sqrt, cos, sin, ceil, log, exp

# ═══════════════════════════════════════════════════════════════
#  DESIGN PARAMETERS (from Maple worksheet)
# ═══════════════════════════════════════════════════════════════
R_gas = 8.314

# Process conditions
T_hot1_K   = 605.5797078 + 273.15     # 878.73 K  salt inlet
T_hot1_C   = 605.58
m_dot      = 0.7609                    # kg/s

# Vessel geometry
D_pyrolizer = 0.318                    # m
D_jacket    = 0.348                    # m  (reduced from 0.500 in v1)
GAP         = (D_jacket - D_pyrolizer) / 2   # 0.015 m
L_1         = 2.05                     # m   heating zone (axial)
L_2         = 2.57                     # m   constant-T zone (axial)
L_total     = L_1 + L_2                # 4.62 m

# Duties
Q_1 = 23550    # W  heating zone
Q_2 = 20070    # W  constant-T zone

# Wall temperatures
T_cold_in_K  = 280 + 273.15            # 553.15 K  at biomass inlet
T_cold_in_C  = 280
T_cold_out_K = 550 + 273.15            # 823.15 K  end of L1 / all of L2
T_cold_out_C = 550

# Salt properties (ternary eutectic carbonate)
rho     = 2050    # kg/m³
Cp      = 2300    # J/kg·K
k_fluid = 0.55    # W/m·K
def F_mu_salt(T_K):
    return 0.0852 * exp(3.51e4 / (R_gas * T_K)) / 1000.0    # Pa·s

# Derived salt temperatures
T_hot_mid_K = T_hot1_K - Q_1 / (m_dot * Cp)    # 865.27 K
T_hot_mid_C = T_hot_mid_K - 273.15              # 592.12 °C
T_hot2_K    = T_hot_mid_K - Q_2 / (m_dot * Cp)  # 853.80 K
T_hot2_C    = T_hot2_K - 273.15                  # 580.65 °C
T_hot_avg1  = (T_hot1_K + T_hot_mid_K) / 2
T_hot_avg2  = (T_hot_mid_K + T_hot2_K) / 2

# ── Spiral-baffle channel geometry ──
Pitch     = 0.07           # m   axial pitch of one helical turn
t_baffle  = 0.005          # m   baffle thickness
w_ch      = Pitch - t_baffle    # 0.065 m   axial width of channel

# Flow area & wetted perimeter (one spiral channel)
A_c       = w_ch * GAP                 # 9.75e-4 m²   = 975 mm²
P_w       = 2 * w_ch + 2 * GAP         # 0.16 m
D_h       = 4 * A_c / P_w              # 0.02438 m  (24.4 mm)
v_flow    = m_dot / (rho * A_c)        # 0.3807 m/s

# Spiral path lengths
N_turns_1 = L_1 / Pitch                      # ≈ 29.29
N_turns_2 = L_2 / Pitch                      # ≈ 36.71
N_turns_total = L_total / Pitch              # ≈ 66.00
L_path1   = L_1 * (pi * D_pyrolizer / Pitch) # 29.26 m
L_path2   = L_2 * (pi * D_pyrolizer / Pitch) # 36.68 m
L_path_total = L_path1 + L_path2             # 65.94 m

# Thermal results (from Maple worksheet)
Re_1     = 1762.75
Re_2     = 1643.26
Pr_1     = 45.13
Pr_2     = 48.41
Nu_1     = 7.23
Nu_2     = 6.77
h_1      = 163.15       # W/m²·K
h_2      = 152.80       # W/m²·K
LMTD_1   = 138.61       # K
LMTD_2   = 36.09        # K
A_bare1  = 2.048        # m²  (pyrolizer wall contribution)
A_bare2  = 2.567        # m²
A_baffle1 = 0.878       # m²  (baffle face contribution)
A_baffle2 = 1.100       # m²
A_av1    = 2.926        # m²  (total available)
A_req1   = 1.041        # m²
A_av2    = 3.668        # m²
A_req2   = 3.640        # m²
f_1      = 0.00908      # Fanning friction factor
f_2      = 0.00974
DP_1     = 6473.5       # Pa
DP_2     = 8705.7       # Pa
DP_total = 15179.2      # Pa  (15.18 kPa)

# Material notes
HTF_name        = "Ternary Eutectic\nCarbonate Salt"
HTF_name_short  = "Molten Salt"
jacket_material = "Carbon Steel"

# ═══════════════════════════════════════════════════════════════
#  DRAWING HELPERS
# ═══════════════════════════════════════════════════════════════
DIM_COL    = "#2255AA"
WALL_COL   = "#666666"
JACKET_COL = "#888888"
HTF_COL    = "#DD6633"
PYRO_COL   = "#AA8855"
CHAN_COL   = "#FFCC88"
BAFFLE_COL = "#8899AA"
ZONE1_COL  = "#FFE0B0"
ZONE2_COL  = "#FFD090"
TITLE_FS   = 13
LABEL_FS   = 8.5
DIM_FS     = 7.5


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
             f"3rd Year Design Project – Pyrolizer Heating Jacket (Spiral-Baffle, v2)",
             ha="right", va="bottom", fontsize=6.5, color="#555555",
             style="italic")


# ═══════════════════════════════════════════════════════════════
#  SHEET 1 – RADIAL CROSS-SECTION (End View)
# ═══════════════════════════════════════════════════════════════
def draw_cross_section(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 1 – Radial Cross-Section (End View)",
                 fontsize=TITLE_FS, fontweight="bold", pad=12)

    R_pyro   = D_pyrolizer / 2
    R_jacket = D_jacket / 2
    t_jacket_wall = 0.004
    R_jacket_outer = R_jacket + t_jacket_wall
    t_pyro_wall   = 0.006

    # Jacket outer shell
    ax.add_patch(Circle((0, 0), R_jacket_outer, fill=False, ec=JACKET_COL, lw=2.5))
    # Jacket inner surface
    ax.add_patch(Circle((0, 0), R_jacket, fill=False, ec=JACKET_COL, lw=1.2, ls="--"))
    # Pyrolizer outer wall (solid ring)
    ax.add_patch(Circle((0, 0), R_pyro, fill=True, fc="#F5EED8",
                         ec=PYRO_COL, lw=2.0))
    # Pyrolizer bore
    ax.add_patch(Circle((0, 0), R_pyro - t_pyro_wall, fill=True, fc="white",
                         ec="#BBAA88", lw=1.0))

    # Fill annulus with channel colour
    annulus = Wedge((0, 0), R_jacket, 0, 360, width=GAP,
                    fc=CHAN_COL, ec="none", alpha=0.5, zorder=1)
    ax.add_patch(annulus)

    # Helical baffle crossings ─ at any axial position the single-start
    # helix cuts the section at exactly ONE angular location.  Show the
    # "reference" baffle crossing at the 3-o'clock (0°) position, plus
    # faded "ghost" positions at ±15° and ±30° indicating that the
    # crossing angle advances continuously with z.
    baffle_angles_deg = [0]
    ghosts_deg = [-30, -15, +15, +30]

    def draw_baffle_slice(angle_deg, alpha=1.0, ec_col="#556677"):
        a = np.radians(angle_deg)
        # Angular half-width of a t_baffle-thick radial bar at mid-radius
        r_mid = (R_pyro + R_jacket) / 2
        half_ang = (t_baffle / 2) / r_mid
        # Build the radial "bar" as a 4-corner polygon
        inner_a1 = a - half_ang
        inner_a2 = a + half_ang
        corners = [
            (R_pyro   * cos(inner_a1), R_pyro   * sin(inner_a1)),
            (R_jacket * cos(inner_a1), R_jacket * sin(inner_a1)),
            (R_jacket * cos(inner_a2), R_jacket * sin(inner_a2)),
            (R_pyro   * cos(inner_a2), R_pyro   * sin(inner_a2)),
        ]
        poly = Polygon(corners, closed=True,
                       fc=BAFFLE_COL, ec=ec_col, lw=1.0,
                       alpha=alpha, zorder=4)
        ax.add_patch(poly)

    for a in ghosts_deg:
        draw_baffle_slice(a, alpha=0.18, ec_col="#99AABB")
    for a in baffle_angles_deg:
        draw_baffle_slice(a, alpha=1.0)

    # Flow direction arrow curving around the annulus (counter-clockwise)
    theta = np.linspace(np.radians(10), np.radians(80), 40)
    r_mid = (R_pyro + R_jacket) / 2
    xs = r_mid * np.cos(theta)
    ys = r_mid * np.sin(theta)
    ax.plot(xs, ys, color="#CC6600", lw=1.2, zorder=5)
    # Arrowhead at end
    end_a = np.radians(78)
    tip = (r_mid * cos(end_a + np.radians(3)), r_mid * sin(end_a + np.radians(3)))
    tail = (r_mid * cos(end_a - np.radians(2)), r_mid * sin(end_a - np.radians(2)))
    ax.annotate("", xy=tip, xytext=tail,
                arrowprops=dict(arrowstyle="->", lw=1.4, color="#CC6600"),
                zorder=5)
    ax.text(r_mid * cos(np.radians(50)) + 0.002,
            r_mid * sin(np.radians(50)) + 0.011,
            "Flow", ha="center", va="center", fontsize=LABEL_FS - 1,
            color="#CC6600", rotation=-40, fontweight="bold")

    # Centre mark
    ax.plot(0, 0, '+', color="#333", ms=8, mew=0.8)

    # Interior label
    ax.text(0, 0.004, "Pyrolizer\n(bore)", ha="center", va="center",
            fontsize=LABEL_FS - 1, color="#886644")

    # ── Dimensions ──
    dim_line(ax, (-R_pyro, 0), (R_pyro, 0),
             f"D_pyrolizer = {D_pyrolizer*1000:.0f} mm",
             offset=R_jacket_outer + 0.030, side="above")

    dim_line(ax, (-R_jacket, 0), (R_jacket, 0),
             f"D_jacket = {D_jacket*1000:.0f} mm",
             offset=R_jacket_outer + 0.030, side="below")

    # Annular gap dimension (at top-left)
    ang = np.radians(135)
    p_inner = (R_pyro * cos(ang), R_pyro * sin(ang))
    p_outer = (R_jacket * cos(ang), R_jacket * sin(ang))
    dim_line(ax, p_inner, p_outer,
             f"GAP = {GAP*1000:.0f} mm",
             offset=0.025, side="above", fontsize=DIM_FS - 0.5, text_offset=0.004)

    # Baffle thickness callout (pointing to reference baffle at 0°)
#     r_tip = (R_pyro + R_jacket) / 2
#     ax.annotate(f"Helical baffle\nt_baffle = {t_baffle*1000:.0f} mm\n"
#                 f"(one crossing per axial\nposition – helix advances)",
#                 xy=(r_tip, 0),
#                 xytext=(R_jacket_outer + 0.015, -R_jacket_outer * 0.35),
#                 fontsize=LABEL_FS - 1,
#                 arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
#                 bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Channel (annulus) callout
#     ch_a = np.radians(225)
#     ax.annotate(f"Annular channel\n"
#                 f"(single spiral path)\n"
#                 f"A_c = {A_c*1e6:.0f} mm²\n"
#                 f"D_h = {D_h*1000:.1f} mm",
#                 xy=((R_pyro + R_jacket)/2 * cos(ch_a),
#                     (R_pyro + R_jacket)/2 * sin(ch_a)),
#                 xytext=(-R_jacket_outer - 0.04, -R_jacket_outer * 0.4),
#                 fontsize=LABEL_FS - 1,
#                 arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
#                 bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Info box (upper-left corner, kept below the D_pyrolizer dim line)
#     info = (f"HTF: {HTF_name_short}\n"
#             f"(30% Na₂CO₃, 33% Li₂CO₃, 37% K₂CO₃)\n"
#             f"Baffle geometry: single-start helix\n"
#             f"Pitch = {Pitch*1000:.0f} mm, "
#             f"Turns ≈ {N_turns_total:.0f}\n"
#             f"Material: {jacket_material}")
#     ax.text(-R_jacket_outer - 0.035, R_jacket_outer + 0.005, info,
#             fontsize=LABEL_FS - 1, va="top", ha="left",
#             bbox=dict(fc="white", ec="#999999", boxstyle="round,pad=0.4"))

    pad = 0.055
    ax.set_xlim(-R_jacket_outer - pad - 0.06, R_jacket_outer + pad + 0.055)
    ax.set_ylim(-R_jacket_outer - pad - 0.02, R_jacket_outer + pad + 0.045)
    ax.set_xlabel("m", fontsize=7)
    ax.set_ylabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 2 – LONGITUDINAL SECTION (Side Elevation)
# ═══════════════════════════════════════════════════════════════
def draw_longitudinal(ax):
    # Do NOT force equal aspect – vessel is 13× longer than it is wide
    # so radial direction is deliberately exaggerated for readability.
    ax.set_title("Sheet 2 – Longitudinal Section (Side Elevation)\n"
                 "Radial direction exaggerated (NTS)",
                 fontsize=TITLE_FS - 1, fontweight="bold", pad=12)

    # Visual scale for radial direction.  True radial dims are tiny
    # relative to L=4.62 m; apply a ×4 y-exaggeration for legibility.
    yscale = 4.0
    R_pyro_v      = D_pyrolizer / 2 * yscale
    R_jacket_v    = D_jacket    / 2 * yscale
    GAP_v         = GAP              * yscale
    t_jacket_wall = 0.004            * yscale
    R_jacket_outer_v = R_jacket_v + t_jacket_wall
    L = L_total

    # Pyrolizer body fill
    ax.fill_between([0, L], [R_pyro_v, R_pyro_v], [-R_pyro_v, -R_pyro_v],
                    color="#F5EED8", alpha=0.3, zorder=1)

    # Pyrolizer walls
    ax.plot([0, L], [ R_pyro_v,  R_pyro_v], color=PYRO_COL, lw=2.0, zorder=5)
    ax.plot([0, L], [-R_pyro_v, -R_pyro_v], color=PYRO_COL, lw=2.0, zorder=5)

    # Jacket outer wall
    ax.plot([0, L], [ R_jacket_outer_v,  R_jacket_outer_v], color=JACKET_COL, lw=2.0, zorder=5)
    ax.plot([0, L], [-R_jacket_outer_v, -R_jacket_outer_v], color=JACKET_COL, lw=2.0, zorder=5)
    # Jacket inner wall
    ax.plot([0, L], [ R_jacket_v,  R_jacket_v], color=JACKET_COL, lw=1.0, ls="--", zorder=4)
    ax.plot([0, L], [-R_jacket_v, -R_jacket_v], color=JACKET_COL, lw=1.0, ls="--", zorder=4)

    # Zone 1 shading (top and bottom annulus)
    ax.add_patch(Rectangle((0, R_pyro_v), L_1, GAP_v,
                            fc=ZONE1_COL, ec="none", alpha=0.5, zorder=2))
    ax.add_patch(Rectangle((0, -R_pyro_v - GAP_v), L_1, GAP_v,
                            fc=ZONE1_COL, ec="none", alpha=0.5, zorder=2))
    # Zone 2 shading
    ax.add_patch(Rectangle((L_1, R_pyro_v), L_2, GAP_v,
                            fc=ZONE2_COL, ec="none", alpha=0.5, zorder=2))
    ax.add_patch(Rectangle((L_1, -R_pyro_v - GAP_v), L_2, GAP_v,
                            fc=ZONE2_COL, ec="none", alpha=0.5, zorder=2))

    # ── Spiral baffle crossings ──
    # A single-start helix crosses any longitudinal cutting plane twice
    # per turn (top and bottom, offset by P/2 due to the 180° rotation).
    # Baffle thickness visually enlarged; true value callout below.
    t_vis = t_baffle * 4.0   # 20 mm visual width (×4 exaggeration)

    z_top = 0.0
    while z_top <= L + 1e-6:
        if 0 <= z_top <= L:
            ax.add_patch(Rectangle((z_top - t_vis/2, R_pyro_v), t_vis, GAP_v,
                                    fc=BAFFLE_COL, ec="#556677", lw=0.3,
                                    alpha=0.85, zorder=3))
        z_top += Pitch

    z_bot = Pitch / 2
    while z_bot <= L + 1e-6:
        if 0 <= z_bot <= L:
            ax.add_patch(Rectangle((z_bot - t_vis/2, -R_pyro_v - GAP_v), t_vis, GAP_v,
                                    fc=BAFFLE_COL, ec="#556677", lw=0.3,
                                    alpha=0.85, zorder=3))
        z_bot += Pitch

    # Zone boundary line
    ax.plot([L_1, L_1], [-R_jacket_outer_v, R_jacket_outer_v],
            color="#CC6600", lw=1.5, ls="--", zorder=6)
    ax.text(L_1, R_jacket_outer_v + 0.018, "Zone boundary",
            ha="center", fontsize=6.5, color="#CC6600")

    # Zone labels (placed inside the pyrolizer interior for maximum space)
    ax.text(L_1 / 2, -R_pyro_v * 0.35,
            f"Section 1 — Heating Zone\n"
            f"Q₁ = {Q_1/1000:.1f} kW   h₁ = {h_1:.0f} W/m²K\n"
            f"L_path₁ = {L_path1:.2f} m  ({N_turns_1:.1f} turns)",
            ha="center", va="center", fontsize=7.5, color="#884400",
            style="italic",
            bbox=dict(fc="#FFF7E8", ec="#DDBB88", boxstyle="round,pad=0.3"))
    ax.text(L_1 + L_2 / 2, -R_pyro_v * 0.35,
            f"Section 2 — Constant-T Zone\n"
            f"Q₂ = {Q_2/1000:.1f} kW   h₂ = {h_2:.0f} W/m²K\n"
            f"L_path₂ = {L_path2:.2f} m  ({N_turns_2:.1f} turns)",
            ha="center", va="center", fontsize=7.5, color="#884400",
            style="italic",
            bbox=dict(fc="#FFF3E0", ec="#DDAA77", boxstyle="round,pad=0.3"))

    # End plates
    ep_w = 0.015
    ax.add_patch(Rectangle((-ep_w, -R_jacket_outer_v), ep_w, 2 * R_jacket_outer_v,
                            fc="#AAAAAA", ec=WALL_COL, lw=1.2, zorder=6))
    ax.add_patch(Rectangle((L, -R_jacket_outer_v), ep_w, 2 * R_jacket_outer_v,
                            fc="#AAAAAA", ec=WALL_COL, lw=1.2, zorder=6))

    # Centre line
    ax.plot([-0.05, L + 0.05], [0, 0], color="#333", lw=0.5, ls="-.", zorder=1)
    ax.text(L + 0.08, 0, "CL", fontsize=6, va="center", color="#666")

    # Salt inlet/outlet nozzles (scaled)
    noz_h = 0.15
    noz_w = 0.06
    # Inlet (left, top)
    ax.add_patch(Rectangle((0.01, R_jacket_outer_v), noz_w, noz_h,
                            fc="#FFAA66", ec="#CC6600", lw=1, alpha=0.8, zorder=6))
    ax.text(0.01 + noz_w/2, R_jacket_outer_v + noz_h + 0.02,
            f"{HTF_name_short} In\n({T_hot1_C:.0f} °C)",
            ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#CC6600",
            fontweight="bold")
    # Outlet (right, top)
    ax.add_patch(Rectangle((L - noz_w - 0.01, R_jacket_outer_v), noz_w, noz_h,
                            fc="#FFCC88", ec="#AA8844", lw=1, alpha=0.8, zorder=6))
    ax.text(L - noz_w/2 - 0.01, R_jacket_outer_v + noz_h + 0.02,
            f"{HTF_name_short} Out\n({T_hot2_C:.1f} °C)",
            ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#AA8844",
            fontweight="bold")

    # Pyrolizer interior label (top of the interior)
    ax.text(L / 2, R_pyro_v * 0.55, "Pyrolizer Interior (Biomass)",
            ha="center", va="center",
            fontsize=LABEL_FS, color="#886644", style="italic")

    # Wall temperature labels — below the bottom annulus
    ax.text(0.1, -R_jacket_outer_v - 0.035,
            f"T_wall,in = {T_cold_in_C:.0f} °C",
            fontsize=7, color="#886644", va="top")
    ax.text(L_1 + 0.1, -R_jacket_outer_v - 0.035,
            f"T_wall,out = {T_cold_out_C:.0f} °C (held through L₂)",
            fontsize=7, color="#886644", va="top")

    # ── Dimensions ──
    # Baseline for length dimensions (well below the vessel)
    y_dim = -R_jacket_outer_v - 0.14

    # L1 and L2 (closer to vessel, on same baseline)
    dim_line(ax, (0, y_dim), (L_1, y_dim),
             f"L₁ = {L_1*1000:.0f} mm",
             offset=0, side="above", fontsize=DIM_FS)
    dim_line(ax, (L_1, y_dim), (L, y_dim),
             f"L₂ = {L_2*1000:.0f} mm",
             offset=0, side="above", fontsize=DIM_FS)

    # Total length (further down)
    dim_line(ax, (0, y_dim - 0.05), (L, y_dim - 0.05),
             f"L_total = {L*1000:.0f} mm",
             offset=0, side="below", fontsize=DIM_FS)

    # Pyrolizer & Jacket diameters at the right end
    dim_line(ax, (L + 0.06, -R_pyro_v), (L + 0.06, R_pyro_v),
             f"D_pyro = {D_pyrolizer*1000:.0f} mm",
             offset=0.06, side="above", fontsize=DIM_FS - 0.5)
    dim_line(ax, (L + 0.15, -R_jacket_outer_v), (L + 0.15, R_jacket_outer_v),
             f"D_jacket = {D_jacket*1000:.0f} mm",
             offset=0.06, side="above", fontsize=DIM_FS - 0.5)

    # Pitch callout – zoom on the first two top baffles (place in a clear
    # area between the inlet nozzle and the middle of the pipe)
    x_pitch_start = 0.35
    dim_line(ax, (x_pitch_start,            R_jacket_outer_v + 0.22),
             (x_pitch_start + Pitch, R_jacket_outer_v + 0.22),
             f"Pitch = {Pitch*1000:.0f} mm",
             offset=0.03, side="above", fontsize=DIM_FS - 0.5)
    # Guide lines from the first two baffles up to the dim
    ax.plot([0,      x_pitch_start],            [R_jacket_outer_v, R_jacket_outer_v + 0.22],
            color=DIM_COL, lw=0.4, ls=":")
    ax.plot([Pitch,  x_pitch_start + Pitch],    [R_jacket_outer_v, R_jacket_outer_v + 0.22],
            color=DIM_COL, lw=0.4, ls=":")

    # Baffle thickness note (callout pointing at first top baffle,
    # placed in the cleared mid-top region)
    ax.annotate(f"t_baffle = {t_baffle*1000:.0f} mm\n(drawn ×4 for clarity)",
                xy=(0, R_jacket_outer_v - 0.005),
                xytext=(0.95, R_jacket_outer_v + 0.18),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#556677"),
                bbox=dict(fc="#F0F4F8", ec="#99AABB", boxstyle="round,pad=0.3"))

    ax.set_xlim(-0.10, L + 0.30)
    ax.set_ylim(-R_jacket_outer_v - 0.27, R_jacket_outer_v + 0.42)
    ax.set_xlabel("axial position  (m) — radial direction exaggerated ×4",
                  fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 3 – CHANNEL CROSS-SECTION DETAIL
# ═══════════════════════════════════════════════════════════════
def draw_channel_detail(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 3 – Spiral Channel Cross-Section (Detail)",
                 fontsize=TITLE_FS, fontweight="bold", pad=12)

    # All dimensions in mm
    gap_mm     = GAP * 1000            # 15 mm
    w_mm       = w_ch * 1000           # 65 mm
    t_baf_mm   = t_baffle * 1000       # 5 mm
    pitch_mm   = Pitch * 1000          # 70 mm
    Dh_mm      = D_h * 1000            # 24.4 mm
    pyro_wall_mm = 6
    jacket_wall_mm = 4

    ox, oy = 0, 0

    # Pyrolizer wall (bottom)
    ax.add_patch(Rectangle((ox - 15, oy - pyro_wall_mm), w_mm + 30, pyro_wall_mm,
                            fc="#D8C8A8", ec=PYRO_COL, lw=1.5))
    ax.text(ox + w_mm / 2, oy - pyro_wall_mm / 2, "Pyrolizer wall",
            ha="center", va="center", fontsize=LABEL_FS - 1, color="#886644")

    # Jacket wall (top)
    ax.add_patch(Rectangle((ox - 15, oy + gap_mm), w_mm + 30, jacket_wall_mm,
                            fc="#C0C0C0", ec=JACKET_COL, lw=1.5))
    ax.text(ox + w_mm / 2, oy + gap_mm + jacket_wall_mm / 2, "Jacket wall",
            ha="center", va="center", fontsize=LABEL_FS - 1, color="#666666")

    # Channel void (HTF)
    ax.add_patch(Rectangle((ox, oy), w_mm, gap_mm,
                            fc=CHAN_COL, ec="#CC9944", lw=1.0, alpha=0.55))

    # Baffle walls on left and right (full GAP height)
    ax.add_patch(Rectangle((ox - t_baf_mm, oy), t_baf_mm, gap_mm,
                            fc=BAFFLE_COL, ec="#556677", lw=1.0, alpha=0.9))
    ax.text(ox - t_baf_mm/2, oy + gap_mm/2, "B", ha="center", va="center",
            fontsize=5.5, color="white", fontweight="bold")
    ax.add_patch(Rectangle((ox + w_mm, oy), t_baf_mm, gap_mm,
                            fc=BAFFLE_COL, ec="#556677", lw=1.0, alpha=0.9))
    ax.text(ox + w_mm + t_baf_mm/2, oy + gap_mm/2, "B", ha="center", va="center",
            fontsize=5.5, color="white", fontweight="bold")

    # HTF label (centred in channel)
    ax.text(ox + w_mm / 2, oy + gap_mm * 0.5,
            f"HTF: {HTF_name_short}\nv = {v_flow:.3f} m/s",
            ha="center", va="center",
            fontsize=LABEL_FS - 0.5, color="#884400")

    # Flow direction into page
    flow_x = ox + w_mm + 48
    ax.plot(flow_x, oy + gap_mm/2, 'o', ms=10,
            mec="#CC6600", mfc="white", mew=1.2)
    ax.plot(flow_x, oy + gap_mm/2, 'x', ms=6,
            mec="#CC6600", mew=1.2)
    ax.text(flow_x, oy + gap_mm/2 + 9, "Flow\n(into page)",
            ha="center", va="bottom", fontsize=5.5, color="#CC6600")

    # ── Dimensions ──
    # Channel width (below the pyrolizer wall)
    dim_line(ax, (ox, oy), (ox + w_mm, oy),
             f"w_ch = {w_mm:.0f} mm",
             offset=pyro_wall_mm + 10, side="below")

    # GAP (radial) — place OUTSIDE the right baffle
    # For a vertical dim line, "below" moves the arrows to +x.
    dim_line(ax, (ox + w_mm + t_baf_mm, oy), (ox + w_mm + t_baf_mm, oy + gap_mm),
             f"GAP = {gap_mm:.0f} mm",
             offset=18, side="below", fontsize=DIM_FS - 0.5)

    # Baffle thickness (small dim above the LEFT baffle, placed high
    # enough that it clears the jacket-wall label band)
    dim_line(ax, (ox - t_baf_mm, oy + gap_mm + jacket_wall_mm + 5),
             (ox,              oy + gap_mm + jacket_wall_mm + 5),
             f"t_baffle = {t_baf_mm:.0f} mm",
             offset=6, side="above", fontsize=DIM_FS - 1)

    # Pitch dimension (spanning left-baffle to right-baffle + one more pitch)
    dim_line(ax, (ox - t_baf_mm, oy - pyro_wall_mm - 28),
             (ox - t_baf_mm + pitch_mm, oy - pyro_wall_mm - 28),
             f"Pitch = {pitch_mm:.0f} mm  (centre-to-centre of consecutive baffle turns)",
             offset=0, side="above", fontsize=DIM_FS - 0.5)
    # Indicate the next baffle position with a dashed ghost
    ax.add_patch(Rectangle((ox - t_baf_mm + pitch_mm, oy), t_baf_mm, gap_mm,
                            fc="none", ec="#99AABB", lw=0.8, ls="--"))

    # Hydraulic diameter callout — placed well above the jacket wall
    ax.annotate(f"D_h = 4·A_c / P_w = {Dh_mm:.1f} mm\n"
                f"A_c = {A_c*1e6:.0f} mm²   P_w = {P_w*1000:.0f} mm\n"
                f"Re = {Re_1:.0f} – {Re_2:.0f}  (laminar)",
                xy=(ox + w_mm * 0.5, oy + gap_mm * 0.9),
                xytext=(ox + w_mm * 0.5, oy + gap_mm + jacket_wall_mm + 32),
                ha="center",
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    # Info box – baffle
    ax.annotate(f"Helical baffle\n(carbon steel)\n"
                f"t_baffle = {t_baf_mm:.0f} mm\n"
                f"Full-GAP height",
                xy=(ox + w_mm + t_baf_mm/2, oy + gap_mm * 0.3),
                xytext=(ox + w_mm + 35, oy + gap_mm - 8),
                fontsize=LABEL_FS - 1,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    pad = 20
    ax.set_xlim(ox - t_baf_mm - 55, ox + w_mm + t_baf_mm + 75)
    ax.set_ylim(oy - pyro_wall_mm - 55, oy + gap_mm + jacket_wall_mm + pad + 55)
    ax.set_xlabel("mm  (axial direction)", fontsize=7)
    ax.set_ylabel("mm  (radial direction)", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  SHEET 4 – HELICAL BAFFLE DEVELOPED VIEW (unrolled) + summary
# ═══════════════════════════════════════════════════════════════
def draw_developed_view(ax):
    ax.set_aspect("auto")
    ax.set_title("Sheet 4 – Developed View (Unrolled Cylindrical Surface)",
                 fontsize=TITLE_FS, fontweight="bold", pad=12)

    # Unroll the pyrolizer cylindrical surface:
    #   x-axis  = axial position z        [mm]     0 ... L_total*1000
    #   y-axis  = circumferential pos φ  [mm]     0 ... π·D_pyrolizer*1000  (wraps)
    circ_mm = pi * D_pyrolizer * 1000        # ≈ 999 mm
    L_mm    = L_total * 1000                  # 4620 mm
    L1_mm   = L_1 * 1000
    L2_mm   = L_2 * 1000
    pitch_mm = Pitch * 1000

    # Zone shading across the full circumference
    ax.add_patch(Rectangle((0, 0), L1_mm, circ_mm,
                            fc=ZONE1_COL, ec="none", alpha=0.55, zorder=1))
    ax.add_patch(Rectangle((L1_mm, 0), L2_mm, circ_mm,
                            fc=ZONE2_COL, ec="none", alpha=0.55, zorder=1))

    # Zone labels (inside each zone, positioned well away from the boundary)
    ax.text(L1_mm * 0.42, circ_mm * 0.5,
            f"Zone 1 — Heating\n"
            f"L₁ = {L1_mm:.0f} mm  ({N_turns_1:.1f} turns)\n"
            f"Path L_path₁ = {L_path1:.2f} m",
            ha="center", va="center", fontsize=8, color="#884400",
            style="italic",
            bbox=dict(fc="#FFFFFFAA", ec="none", boxstyle="round,pad=0.3"))
    ax.text(L1_mm + L2_mm * 0.55, circ_mm * 0.5,
            f"Zone 2 — Constant Wall T\n"
            f"L₂ = {L2_mm:.0f} mm  ({N_turns_2:.1f} turns)\n"
            f"Path L_path₂ = {L_path2:.2f} m",
            ha="center", va="center", fontsize=8, color="#884400",
            style="italic",
            bbox=dict(fc="#FFFFFFAA", ec="none", boxstyle="round,pad=0.3"))

    # ── Draw the helical baffle as parallel diagonal lines ──
    # Parametric: on unrolled surface, along one turn (0 → 2π), z advances
    # by one pitch and φ advances by the circumference.  So the baffle
    # traces a line of slope (dφ/dz) = circumference / Pitch.
    slope = circ_mm / pitch_mm   # ≈ 14.27
    # For a baffle line passing through z0 at φ=0:
    #   φ(z) = slope * (z - z0)  mod circumference
    # We draw N_turns_total+1 lines offset by one pitch in z.
    n_lines = int(N_turns_total) + 2
    for k in range(-1, n_lines + 1):
        z0 = k * pitch_mm
        # The line within the plot spans φ from 0 to circumference; we
        # break it into segments whenever φ wraps.
        # Using φ = slope*(z - z0), the line enters y=0 at z=z0 and exits
        # y=circumference at z=z0+pitch.
        z_start = z0
        z_end = z0 + pitch_mm
        # Clip to plot range
        z_a = max(z_start, 0)
        z_b = min(z_end, L_mm)
        if z_b <= z_a:
            continue
        y_a = slope * (z_a - z0)
        y_b = slope * (z_b - z0)
        ax.plot([z_a, z_b], [y_a, y_b],
                color=BAFFLE_COL, lw=1.2, zorder=3)

    # Pyrolizer-wall boundary (top and bottom of unrolled surface represent
    # the same longitudinal line on the pyrolizer – emphasise periodicity)
    ax.plot([0, L_mm], [0, 0], color=PYRO_COL, lw=1.5, zorder=2)
    ax.plot([0, L_mm], [circ_mm, circ_mm], color=PYRO_COL, lw=1.5,
            ls="--", zorder=2)
    ax.text(-40, 0, "φ = 0°", fontsize=6.5, va="center", color="#666")
    ax.text(-40, circ_mm, "φ = 360°", fontsize=6.5, va="center", color="#666")
    ax.text(-40, circ_mm/2, "φ = 180°", fontsize=6.5, va="center", color="#666")
    # Dashed horizontal reference at 180°
    ax.plot([0, L_mm], [circ_mm/2, circ_mm/2],
            color="#AAAAAA", lw=0.4, ls=":", zorder=1)

    # Zone boundary
    ax.plot([L1_mm, L1_mm], [0, circ_mm],
            color="#CC6600", lw=1.5, ls="--", zorder=4)

    # Flow start marker
    ax.plot(0, 0, 'o', ms=9, mec="#CC6600", mfc="#FFAA66",
            mew=1.2, zorder=5)
    ax.annotate(f"Inlet\n{HTF_name_short} in\n{T_hot1_C:.1f} °C",
                xy=(0, 0),
                xytext=(80, -180),
                fontsize=LABEL_FS - 1, color="#CC6600",
                arrowprops=dict(arrowstyle="->", lw=0.6, color="#CC6600"),
                bbox=dict(fc="#FFF5E8", ec="#CC6600", boxstyle="round,pad=0.3"))

    # Flow end marker (accounting for baffle wrap at z=L)
    y_end = (slope * (L_mm - int(L_mm/pitch_mm) * pitch_mm)) % circ_mm
    ax.plot(L_mm, y_end, 's', ms=9, mec="#AA8844", mfc="#FFCC88",
            mew=1.2, zorder=5)
    ax.annotate(f"Outlet\n{HTF_name_short} out\n{T_hot2_C:.1f} °C",
                xy=(L_mm, y_end),
                xytext=(L_mm - 600, circ_mm + 220),
                fontsize=LABEL_FS - 1, color="#AA8844",
                arrowprops=dict(arrowstyle="->", lw=0.6, color="#AA8844"),
                bbox=dict(fc="#FFF8EC", ec="#AA8844", boxstyle="round,pad=0.3"))

    # Pitch callout – show one pitch on the right-hand side
    z_p = L_mm - 3 * pitch_mm
    dim_line(ax, (z_p, -60), (z_p + pitch_mm, -60),
             f"Pitch = {pitch_mm:.0f} mm",
             offset=35, side="below", fontsize=DIM_FS - 0.5)

    # Total length along the bottom
    dim_line(ax, (0, -180), (L_mm, -180),
             f"L_total = {L_mm:.0f} mm",
             offset=30, side="below", fontsize=DIM_FS)

    # Circumference dimension on the left
    dim_line(ax, (-150, 0), (-150, circ_mm),
             f"π·D_pyro = {circ_mm:.0f} mm",
             offset=25, side="above", fontsize=DIM_FS - 0.5)

    # Summary design-result box (placed BELOW the plot area so it doesn't
    # collide with the title).  Rendered via fig-level text in main().
    summary_text = (f"DESIGN SUMMARY  ✓ SUCCESSFUL\n"
               f"────────────────────────────────────\n"
               f"Zone 1 (Heating):   Re = {Re_1:.0f},  h₁ = {h_1:.1f} W/m²K,  "
               f"A_av = {A_av1:.2f} m² > A_req = {A_req1:.2f} m²\n"
               f"Zone 2 (Constant T): Re = {Re_2:.0f},  h₂ = {h_2:.1f} W/m²K,  "
               f"A_av = {A_av2:.2f} m² > A_req = {A_req2:.2f} m²\n"
               f"Flow:  v = {v_flow:.3f} m/s,   ΔP_total = {DP_total/1000:.2f} kPa\n"
               f"Salt path: {T_hot1_C:.1f} → {T_hot_mid_C:.1f} → {T_hot2_C:.1f} °C  "
               f"|  Wall: {T_cold_in_C} → {T_cold_out_C} °C (ramp + hold)")
    ax._design_summary = summary_text   # stash for main() to render

    ax.set_xlim(-220, L_mm + 120)
    ax.set_ylim(-320, circ_mm + 140)
    ax.set_xlabel("axial position  z  (mm)", fontsize=7)
    ax.set_ylabel("circumferential position  φ (mm along π·D_pyro)", fontsize=7)
    ax.tick_params(labelsize=6)


# ═══════════════════════════════════════════════════════════════
#  COMPOSE & SAVE
# ═══════════════════════════════════════════════════════════════
def main():
    # --- Page 1: Cross-section + Longitudinal ---
    fig1, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 16),
                                     gridspec_kw={"height_ratios": [1, 0.9]})
    fig1.suptitle("Pyrolizer Heating Jacket (Spiral Baffle) – Design Drawings (1/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_cross_section(ax1)
    draw_longitudinal(ax2)
    add_title_block(fig1, "PJ-V2-001")
    fig1.tight_layout(rect=[0, 0.02, 1, 0.96])
    fig1.savefig("pyrolizer_jacket_v2_page1.png", dpi=200, bbox_inches="tight")
    print("Saved page 1")

    # --- Page 2: Channel detail + Developed view ---
    fig2, (ax3, ax4) = plt.subplots(2, 1, figsize=(14, 14),
                                     gridspec_kw={"height_ratios": [0.75, 1]})
    fig2.suptitle("Pyrolizer Heating Jacket (Spiral Baffle) – Design Drawings (2/2)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_channel_detail(ax3)
    draw_developed_view(ax4)
    # Render the stashed Sheet-4 design summary at the figure level so
    # it sits cleanly below the axes, outside the plot box.
    summary_text = getattr(ax4, "_design_summary", None)
    if summary_text:
        fig2.text(0.5, 0.035, summary_text,
                  fontsize=8, va="bottom", ha="center", family="monospace",
                  bbox=dict(fc="#F0F8E8", ec="#668844",
                            boxstyle="round,pad=0.5"))
    add_title_block(fig2, "PJ-V2-002")
    fig2.tight_layout(rect=[0, 0.17, 1, 0.96])
    fig2.savefig("pyrolizer_jacket_v2_page2.png", dpi=200, bbox_inches="tight")
    print("Saved page 2")

    # Combined PDF
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages("Pyrolizer_Jacket_v2_Design_Drawings.pdf") as pdf:
        pdf.savefig(fig1, bbox_inches="tight")
        pdf.savefig(fig2, bbox_inches="tight")
    print("Saved combined PDF")

    plt.close("all")


if __name__ == "__main__":
    main()
