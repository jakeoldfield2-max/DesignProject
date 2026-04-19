#!/usr/bin/env python3
"""
Combined Burner Fired Heater (H-101) - Engineering Design Drawings
====================================================================
Cylindrical fired heater with radiant helical coil and convection tube bank.
Combined gas (biogas) and oil (bio-oil) burners at the base.
Ternary eutectic molten salt as the heat transfer fluid.
All parameters from the Maple design summary.
"""

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, Arc, Wedge, FancyArrowPatch
import numpy as np
from math import pi, sqrt, cos, sin, ceil

# ==================================================================
#  DESIGN PARAMETERS (from Maple worksheet results)
# ==================================================================
# --- System ---
Q_total    = 68.856e3   # W  total duty to salt
Q_radiant  = 57.44e3    # W  radiant absorption
Q_conv     = 13.56e3    # W  convection absorption
eta        = 0.74       # thermal efficiency
T_salt_in  = 580.65     # C  (from Maple: T__salt_in)
T_salt_out = 620        # C
m_salt     = 0.7608     # kg/s
Q_released = 93.05e3    # W  (Q_target / eta)

# --- Radiant Zone: Shell ---
D_shell_outer = 1.250   # m
t_refractory  = 0.150   # m
D_firebox     = 0.952   # m  (D_coil_heat - d_tube_OD_heat)
k_refr        = 0.35    # W/m/K

# --- Radiant Zone: Helical Coil ---
D_tube_rad_OD = 0.048   # m
D_tube_rad_ID = 0.038   # m
D_helix       = 1.000   # m  coil helix diameter (D_coil_heat)
coil_pitch    = 0.1075  # m  (p_coil_heat from Maple)
N_turns_rad   = 12      # integer turns
H_coil        = N_turns_rad * coil_pitch  # 1.290 m
L_turn        = sqrt((pi * D_helix)**2 + coil_pitch**2)  # ~3.143 m
L_tube_rad    = N_turns_rad * L_turn      # ~37.72 m
A_rad_actual  = N_turns_rad * pi * D_tube_rad_OD * L_turn  # ~5.688 m2
q_flux        = 10099   # W/m2  (actual radiant flux)
k_tube        = 25      # W/m/K (stainless steel)

# --- Firebox geometry ---
LD_ratio      = H_coil / D_firebox  # ~1.355
H_burner_zone = 0.15    # m clearance below bottom coil turn
H_transition  = 0.10    # m clearance above top coil turn
H_firebox     = H_coil + H_burner_zone + H_transition  # ~1.54 m

# --- Convection Zone ---
D_duct_width  = 0.8839  # m  square duct (W_conv from Maple)
D_tube_conv_OD = 0.035  # m
D_tube_conv_ID = 0.027  # m
pitch_h       = 0.0875  # m  horizontal pitch (2.5 x OD)
pitch_v       = 0.0875  # m  vertical pitch (2.5 x OD)
N_tubes_row   = 11
N_rows        = 2       # convection rows
N_shield      = 2       # shield rows (exposed to radiation)
N_parallel    = 7       # parallel salt streams
W_conv_bend   = 0.005   # m
L_tube_conv   = D_duct_width - 2 * W_conv_bend  # 0.8739 m
L_tube_conv_total = 19.34  # m

# --- Gas Burner ---
D_orifice     = 3.537   # mm  (d_o from Maple)
D_bore        = 3.095   # mm  (b_o = 1.75 x r_o)
D_throat      = 15.221  # mm  (d_t)
L_throat      = 152.2   # mm  (L_t = d_t x 10)
N_ports       = 15      # flame ports
D_port        = 5.0     # mm  (d_p_gas)
v_orifice     = 236.05  # m/s
v_port        = 30.38   # m/s
Re_throat     = 37137
Q_gas         = 41.74e3 # W (HHV)
Prigg_ratio   = 1.62    # A_p/A_t

# --- Oil Atomizer ---
D_nozzle      = 1.50    # mm  (D_0)
D_swirl       = 3.00    # mm  (D_s)
D_passage     = 0.60    # mm  (D_p)
L_swirl       = 2.00    # mm  (L_s)
L_nozzle      = 1.00    # mm  (L_0)
L_passage     = 1.00    # mm  (L_p)
N_passages    = 4
cone_angle    = 14.61   # degrees full cone
SMD           = 21.8    # um (corrected x1.75)
Q_oil         = 102.35e3  # W (LHV)
Cd_oil        = 0.0403
K_oil         = 0.2512

# --- Pressure Drop ---
DP_rad  = 22130   # Pa
DP_conv = 404     # Pa

# --- Flue Gas ---
T_gas      = 810.0   # C  converged gas temp
T_stack    = 681.7   # C  stack temp
T_tube_C   = 659.8   # C  mean tube wall temp
m_flue     = 0.05534 # kg/s
m_total_air = 0.04972 # kg/s
z_excess   = 0.15

# --- Heat Transfer ---
h_i_rad    = 814.7    # W/m2/K
h_o_rad    = 67.2     # W/m2/K
U_overall_rad = 60.1  # W/m2/K
LMTD_rad   = 205.4    # K
T_skin_max = 632.4    # C

h_i_conv   = 234.7    # W/m2/K
h_o_conv   = 153.6    # W/m2/K
U_conv     = 81.8     # W/m2/K

T_salt_rad_in = 588.4 # C
Re_salt_rad   = 2382
Re_salt_conv  = 311
v_salt_rad    = 0.327  # m/s
v_salt_conv   = 0.047  # m/s

# ==================================================================
#  DRAWING HELPERS
# ==================================================================
DIM_COL    = "#2255AA"
WALL_COL   = "#666666"
REFR_COL   = "#CC9966"
TUBE_COL   = "#888888"
SALT_COL   = "#DD6633"
FLAME_COL  = "#FF6622"
GAS_COL    = "#44AA66"
FLUE_COL   = "#AAAACC"
OIL_COL    = "#CC5500"
TITLE_FS   = 13
LABEL_FS   = 8.5
DIM_FS     = 7.5


def dim_line(ax, p1, p2, text, offset=0, side="above", fontsize=DIM_FS,
             color=DIM_COL, text_offset=0):
    x1, y1 = p1; x2, y2 = p2
    dx, dy = x2 - x1, y2 - y1
    length = sqrt(dx**2 + dy**2)
    if length == 0: return
    nx, ny = -dy / length, dx / length
    sign = 1 if side == "above" else -1
    ox, oy = nx * offset * sign, ny * offset * sign
    ax.plot([x1, x1+ox], [y1, y1+oy], lw=0.4, color=color)
    ax.plot([x2, x2+ox], [y2, y2+oy], lw=0.4, color=color)
    mx1, my1 = x1+ox, y1+oy; mx2, my2 = x2+ox, y2+oy
    ax.annotate("", xy=(mx2,my2), xytext=(mx1,my1),
                arrowprops=dict(arrowstyle="<->", lw=0.7, color=color), zorder=10)
    cx, cy = (mx1+mx2)/2, (my1+my2)/2
    angle = np.degrees(np.arctan2(dy, dx))
    if angle > 90: angle -= 180
    if angle < -90: angle += 180
    t_off = sign * 0.006 + text_offset
    ax.text(cx + nx*t_off, cy + ny*t_off, text,
            ha="center", va="center", fontsize=fontsize, color=color,
            rotation=angle, bbox=dict(fc="white", ec="none", pad=0.8, alpha=0.85),
            zorder=10)


def add_title_block(fig, dwg_no):
    fig.text(0.98, 0.012, f"Dwg: {dwg_no}   |   Scale: NTS   |   "
             f"3rd Year Design Project - Combined Burner Fired Heater (H-101)",
             ha="right", va="bottom", fontsize=6.5, color="#555555", style="italic")


# ==================================================================
#  SHEET 1 - OVERALL SIDE ELEVATION
# ==================================================================
def draw_elevation(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 1 - Overall Side Elevation (Section A-A)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_shell = D_shell_outer / 2
    R_fire  = D_firebox / 2
    R_coil  = D_helix / 2
    H_conv  = (N_rows + N_shield) * pitch_v + 0.10
    base_y  = 0

    # Shell outer wall
    ax.add_patch(Rectangle((-R_shell, base_y), D_shell_outer, H_firebox,
                            fc="none", ec=WALL_COL, lw=2.5))
    ax.add_patch(Rectangle((-R_shell, base_y), t_refractory, H_firebox,
                            fc=REFR_COL, ec="#AA7744", lw=0.8, alpha=0.5))
    ax.add_patch(Rectangle((R_shell - t_refractory, base_y), t_refractory, H_firebox,
                            fc=REFR_COL, ec="#AA7744", lw=0.8, alpha=0.5))
    ax.add_patch(Rectangle((-R_fire, base_y), D_firebox, H_firebox,
                            fc="#FFF8F0", ec="none", alpha=0.3))

    # Helical coil tubes
    for i in range(N_turns_rad):
        y_tube = base_y + H_burner_zone + i * coil_pitch
        if y_tube > base_y + H_firebox - H_transition:
            break
        ax.add_patch(Circle((-R_coil, y_tube), D_tube_rad_OD/2,
                            fc="#CCCCCC", ec=TUBE_COL, lw=0.8, zorder=3))
        ax.add_patch(Circle((R_coil, y_tube), D_tube_rad_OD/2,
                            fc="#CCCCCC", ec=TUBE_COL, lw=0.8, zorder=3))

    # Convection zone
    conv_y = base_y + H_firebox
    R_duct = D_duct_width / 2
    ax.add_patch(Rectangle((-R_duct, conv_y), D_duct_width, H_conv,
                            fc="#E8E8F0", ec=WALL_COL, lw=2.0))

    for row in range(N_rows + N_shield):
        ty = conv_y + 0.05 + row * pitch_v
        ax.plot([-R_duct + 0.03, R_duct - 0.03], [ty, ty],
                color=TUBE_COL, lw=1.5, zorder=3)
        if row < N_shield:
            ax.text(R_duct + 0.02, ty, f"Shield {row+1}", fontsize=5.5, va="center", color="#886644")
        else:
            ax.text(R_duct + 0.02, ty, f"Conv {row-N_shield+1}", fontsize=5.5, va="center", color="#886644")

    # Stack
    stack_w = 0.15; stack_h = 0.12
    stack_y = conv_y + H_conv
    ax.add_patch(Rectangle((-stack_w/2, stack_y), stack_w, stack_h,
                            fc=FLUE_COL, ec=WALL_COL, lw=1.5, alpha=0.5))
    ax.annotate(f"Flue Gas Out\n({T_stack:.0f} C)", xy=(0, stack_y + stack_h),
                ha="center", va="bottom", fontsize=LABEL_FS - 1, color="#666699", fontweight="bold")

    # Burners at base
    burner_y = base_y
    oil_w = 0.06
    ax.add_patch(Rectangle((-oil_w/2, burner_y - 0.06), oil_w, 0.06,
                            fc=OIL_COL, ec="#AA3311", lw=1.0, alpha=0.7))
    ax.text(0, burner_y - 0.03, "Oil", ha="center", va="center",
            fontsize=5.5, color="white", fontweight="bold")
    for gx in [-0.18, -0.12, 0.12, 0.18]:
        ax.add_patch(Circle((gx, burner_y - 0.03), 0.018,
                            fc=GAS_COL, ec="#226633", lw=0.6, alpha=0.7))
    ax.text(-0.25, burner_y - 0.03, "Gas", ha="center", va="center",
            fontsize=5.5, color="#226633", fontweight="bold")
    ax.text(0.25, burner_y - 0.03, "Gas", ha="center", va="center",
            fontsize=5.5, color="#226633", fontweight="bold")

    # Salt flow
    ax.annotate(f"Salt In\n({T_salt_in:.1f} C)", xy=(-R_shell + 0.15, conv_y + 0.30),
                ha="right", fontsize=LABEL_FS - 1, color=SALT_COL, fontweight="bold")

    ax.annotate(f"Salt Out\n({T_salt_out:.0f} C)", xy=(R_shell + 0.04, base_y + 0.10),
                ha="left", fontsize=LABEL_FS - 1, color="#CC8844", fontweight="bold")


    ax.text(0, base_y + H_burner_zone + H_coil / 2, "RADIANT\nZONE", ha="center",
            va="center", fontsize=10, color="#CC6633", alpha=0.4, fontweight="bold")
    ax.text(0, conv_y + H_conv / 2, "CONVECTION\nZONE", ha="center", va="center",
            fontsize=8, color="#6666AA", alpha=0.5, fontweight="bold")
    ax.text(0, base_y + H_burner_zone * 0.35, "BURNER", ha="center", va="center",
            fontsize=6, color="#AA5533", alpha=0.5, fontweight="bold")

    # Dimensions
    dim_line(ax, (-R_shell, base_y - 0.01), (R_shell, base_y - 0.01),
             f"D_shell = {D_shell_outer*1000:.0f} mm", offset=0.08, side="below")
    dim_line(ax, (-R_fire, base_y + H_firebox * 0.3), (R_fire, base_y + H_firebox * 0.3),
             f"D_firebox = {D_firebox*1000:.0f} mm", offset=0.01, side="below", fontsize=DIM_FS - 0.5)
    dim_line(ax, (R_shell + 0.02, base_y + H_burner_zone),
             (R_shell + 0.02, base_y + H_burner_zone + H_coil),
             f"H_coil = {H_coil*1000:.0f} mm", offset=0.06, side="above")
    dim_line(ax, (-R_shell - 0.02, base_y), (-R_shell - 0.02, base_y + H_firebox),
             f"H_firebox = {H_firebox*1000:.0f} mm", offset=0.06, side="below")
    dim_line(ax, (-R_shell, base_y + H_firebox + 0.02),
             (-R_shell + t_refractory, base_y + H_firebox + 0.02),
             f"t_refr = {t_refractory*1000:.0f} mm", offset=0.02, side="above", fontsize=DIM_FS - 0.5)

    pad = 0.15
    ax.set_xlim(-R_shell - pad - 0.10, R_shell + pad + 0.10)
    ax.set_ylim(burner_y - 0.12, stack_y + stack_h + pad)
    ax.set_xlabel("m", fontsize=7); ax.set_ylabel("m", fontsize=7)
    ax.tick_params(labelsize=6)


# ==================================================================
#  SHEET 2 - BURNER ARRANGEMENT PLAN VIEW (looking up into firebox)
# ==================================================================
def draw_burner_plan(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 2 - Burner Arrangement Plan View (Looking Up)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    # All in mm
    R_fire_mm  = D_firebox / 2 * 1000
    R_coil_mm  = D_helix / 2 * 1000
    R_shell_mm = D_shell_outer / 2 * 1000

    # Shell and refractory
    ax.add_patch(Circle((0, 0), R_shell_mm, fill=False, ec=WALL_COL, lw=2.5))
    ax.add_patch(Wedge((0, 0), R_shell_mm, 0, 360, width=t_refractory * 1000,
                        fc=REFR_COL, ec="#AA7744", lw=0.5, alpha=0.4))
    ax.add_patch(Circle((0, 0), R_fire_mm, fill=True, fc="#FFF8F0", ec="#CCAA88", lw=1.0))

    # Coil footprint (dashed)
    ax.add_patch(Circle((0, 0), R_coil_mm, fill=False, ec=SALT_COL, lw=1.2, ls="--", alpha=0.5))
    ax.text(R_coil_mm * cos(pi/4) + 15, R_coil_mm * sin(pi/4) + 15,
            "Coil helix\n(above)", fontsize=5.5, color=SALT_COL, alpha=0.6, ha="left")

    # Oil atomizer at centre
    oil_body_r = 25  # mm visual radius for atomizer body
    nozzle_r = D_nozzle / 2 * 8  # scaled nozzle exit
    ax.add_patch(Circle((0, 0), oil_body_r, fc="#FFE0CC", ec=OIL_COL, lw=2.0, zorder=5))
    ax.add_patch(Circle((0, 0), nozzle_r, fc=OIL_COL, ec="#882200", lw=1.0, zorder=6))

    # Tangential passages (schematic)
    for i in range(N_passages):
        ang = 2 * pi * i / N_passages + pi / 4
        px = oil_body_r * cos(ang)
        py = oil_body_r * sin(ang)
        tx = -sin(ang) * 12
        ty = cos(ang) * 12
        ax.plot([px, px + tx], [py, py + ty], color="#886644", lw=1.5, zorder=5)
        ax.plot([px + tx, px + tx - cos(ang) * 8], [py + ty, py + ty - sin(ang) * 8],
                color="#886644", lw=1.5, zorder=5)

    ax.text(0, -oil_body_r - 8, "Oil Atomizer\n(pressure-swirl)", ha="center",
            va="top", fontsize=6.5, color=OIL_COL, fontweight="bold", zorder=7)

    # Spray cone footprint
    for r_spray in [60, 100, 150]:
        ax.add_patch(Circle((0, 0), r_spray, fill=False, ec=FLAME_COL,
                            lw=0.4, ls=":", alpha=0.3, zorder=2))

    # Gas flame ports (15 ports in a circle)
    R_port_circle = 200  # mm PCD
    port_r_mm = D_port / 2 * 4  # scaled for visibility

    for i in range(N_ports):
        ang = 2 * pi * i / N_ports
        px = R_port_circle * cos(ang)
        py = R_port_circle * sin(ang)
        ax.add_patch(Circle((px, py), port_r_mm, fc=GAS_COL, ec="#226633",
                            lw=0.8, zorder=4, alpha=0.8))
        fx = (R_port_circle + port_r_mm + 5) * cos(ang)
        fy = (R_port_circle + port_r_mm + 5) * sin(ang)
        ax.plot([px, fx], [py, fy], color="#FF8844", lw=0.5, alpha=0.6)

    ax.add_patch(Circle((0, 0), R_port_circle, fill=False, ec=GAS_COL,
                        lw=0.8, ls="--", alpha=0.4))

    # Gas manifold ring
    R_manifold = R_port_circle - 25
    ax.add_patch(Circle((0, 0), R_manifold, fill=False, ec=GAS_COL,
                        lw=2.5, ls="-", alpha=0.25))
    ax.text(0, R_manifold + port_r_mm + 35, "Gas manifold\nring", ha="center",
            va="bottom", fontsize=7.5, color=GAS_COL, alpha=0.7)

    # Label one port
    label_idx = 2
    label_ang = 2 * pi * label_idx / N_ports
    lx = R_port_circle * cos(label_ang)
    ly = R_port_circle * sin(label_ang)
    ax.annotate(f"Gas flame port\n{D_port:.0f} mm x {N_ports}",
                xy=(lx, ly),
                xytext=(R_fire_mm * 0.85, R_fire_mm * 0.65),
                fontsize=6, color="#226633",
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#226633"),
                bbox=dict(fc="#EEFFEE", ec="#88BB88", boxstyle="round,pad=0.3"), zorder=8)

    ax.plot([0], [0], '+', color="#333", ms=6, mew=0.5, zorder=7)

    # Dimensions
    dim_line(ax, (-R_fire_mm, 0), (R_fire_mm, 0),
             f"D_firebox = {D_firebox*1000:.0f} mm",
             offset=R_fire_mm + 60, side="above")
    dim_line(ax, (-R_port_circle, 0), (R_port_circle, 0),
             f"Port PCD = {2*R_port_circle:.0f} mm",
             offset=R_fire_mm + 60, side="below", fontsize=DIM_FS - 0.5)
    dim_line(ax, (-R_shell_mm, R_shell_mm + 20), (R_shell_mm, R_shell_mm + 20),
             f"D_shell = {D_shell_outer*1000:.0f} mm", offset=15, side="above")

    # Info box
    info = (f"Burner arrangement\n"
            f"Centre: 1x oil atomizer (pressure-swirl)\n"
            f"  Q_oil = {Q_oil/1000:.1f} kW (LHV)\n"
            f"  SMD = {SMD:.0f} um, cone = {cone_angle:.1f} deg\n"
            f"Ring: {N_ports}x gas flame ports\n"
            f"  Q_gas = {Q_gas/1000:.1f} kW (HHV)\n"
            f"  Port dia = {D_port:.0f} mm\n"
            f"Excess air: {z_excess*100:.0f}%")
    ax.text(-R_shell_mm - 20, -R_shell_mm + 140, info,
            fontsize=LABEL_FS - 1.5, va="top", ha="left",
            bbox=dict(fc="white", ec="#999", boxstyle="round,pad=0.4"), zorder=8)

    pad = 80
    ax.set_xlim(-R_shell_mm - pad - 30, R_shell_mm + pad + 30)
    ax.set_ylim(-R_shell_mm - pad, R_shell_mm + pad + 30)
    ax.set_xlabel("mm", fontsize=7); ax.set_ylabel("mm", fontsize=7)
    ax.tick_params(labelsize=6)


# ==================================================================
#  SHEET 3 - GAS BURNER DETAIL
# ==================================================================
def draw_gas_burner(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 3 - Gas Burner (Premixed Bunsen Type)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    ox = 0
    pipe_w = 15; pipe_h = D_bore
    ax.add_patch(Rectangle((ox - pipe_w, -pipe_h/2), pipe_w, pipe_h,
                            fc="#DDFFDD", ec=GAS_COL, lw=1.0))
    ax.text(ox - pipe_w/2, 0, "Biogas\nsupply", ha="center", va="center",
            fontsize=5.5, color="#226633")

    orif_w = 3
    ax.add_patch(Rectangle((ox, -D_orifice/2), orif_w, D_orifice,
                            fc="#AADDAA", ec="#226633", lw=1.0))
    ax.text(ox + orif_w/2, -D_orifice/2 - 2, f"Orifice\n{D_orifice:.1f} mm",
            ha="center", va="top", fontsize=5.5, color="#226633")

    air_gap = 8
    ax.add_patch(Rectangle((ox + orif_w, -D_throat/2), air_gap, D_throat,
                            fc="#E0F0FF", ec="#6699CC", lw=0.6, alpha=0.5))
    ax.text(ox + orif_w + air_gap/2, D_throat/2 + 2, "Air\nentrainment",
            ha="center", va="bottom", fontsize=5, color="#6699CC")

    throat_x = ox + orif_w + air_gap
    ax.add_patch(Rectangle((throat_x, -D_throat/2), L_throat, D_throat,
                            fc="#F0F0F0", ec=WALL_COL, lw=1.2))
    ax.text(throat_x + L_throat/2, 0, "Mixing Throat", ha="center", va="center",
            fontsize=7, color="#555")

    port_x = throat_x + L_throat
    port_spacing = D_throat / (min(N_ports, 5) + 1)
    n_show_ports = min(N_ports, 5)
    for i in range(n_show_ports):
        py = -D_throat/2 + (i + 1) * port_spacing
        ax.add_patch(Circle((port_x + 2, py), D_port/2,
                            fc=FLAME_COL, ec="#AA3311", lw=0.6, alpha=0.7))

    ax.text(port_x + 8, 0, f"Flame Ports\n{N_ports} x {D_port:.0f} mm",
            ha="left", va="center", fontsize=6, color=FLAME_COL)

    ax.annotate("", xy=(port_x - 5, 0), xytext=(ox + orif_w + 2, 0),
                arrowprops=dict(arrowstyle="->", color=GAS_COL, lw=1.0))

    dim_line(ax, (throat_x, -D_throat/2), (throat_x + L_throat, -D_throat/2),
             f"L_throat = {L_throat:.1f} mm", offset=5, side="below")
    dim_line(ax, (throat_x, -D_throat/2), (throat_x, D_throat/2),
             f"D_throat = {D_throat:.1f} mm", offset=8, side="below", fontsize=DIM_FS - 0.5)

    info = (f"Gas: 60% CH4 / 40% CO2\n"
            f"Q_gas = {Q_gas/1000:.1f} kW (HHV)\n"
            f"v_orifice = {v_orifice:.0f} m/s\n"
            f"v_port = {v_port:.1f} m/s\n"
            f"Re_throat = {Re_throat}\n"
            f"Prigg = {Prigg_ratio:.2f}")
    ax.text(ox - pipe_w, -D_throat/2 - 12, info, fontsize=LABEL_FS - 1, va="top",
            bbox=dict(fc="#FFFFF0", ec="#BBBB88", boxstyle="round,pad=0.3"))

    ax.set_xlim(ox - pipe_w - 5, port_x + 25)
    ax.set_ylim(-D_throat/2 - 25, D_throat/2 + 15)
    ax.set_xlabel("mm", fontsize=7); ax.tick_params(labelsize=6)


# ==================================================================
#  SHEET 4 - OIL ATOMIZER DETAIL
# ==================================================================
def draw_oil_atomizer(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 4 - Oil Atomizer (Pressure-Swirl)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    s = 8  # scale factor
    sc_w = L_swirl * s
    sc_h = D_swirl * s
    sc_x = 0
    sc_y = -sc_h / 2

    ax.add_patch(Rectangle((sc_x, sc_y), sc_w, sc_h,
                            fc="#FFE8CC", ec="#AA7744", lw=1.5))
    ax.text(sc_x + sc_w/2, 0, "Swirl\nChamber", ha="center", va="center",
            fontsize=7, color="#884400")

    noz_w = L_nozzle * s
    noz_h = D_nozzle * s
    noz_x = sc_x + sc_w

    noz_pts = np.array([
        [noz_x, -sc_h/2], [noz_x + noz_w, -noz_h/2],
        [noz_x + noz_w, noz_h/2], [noz_x, sc_h/2]
    ])
    ax.fill(noz_pts[:, 0], noz_pts[:, 1], fc="#FFDDAA", ec="#AA7744", lw=1.5)
    ax.text(noz_x + noz_w/2, 0, "Nozzle", ha="center", va="center",
            fontsize=6, color="#884400")

    pass_w = L_passage * s
    pass_h = D_passage * s
    for sign in [1, -1]:
        py = sign * (sc_h/2 - pass_h)
        ax.add_patch(Rectangle((sc_x - pass_w, py - pass_h/2), pass_w, pass_h,
                                fc="#DDCCBB", ec="#886644", lw=0.8))
    ax.text(sc_x - pass_w/2, sc_h/2 + 3, f"Tangential\npassages (x{N_passages})",
            ha="center", va="bottom", fontsize=5.5, color="#886644")

    spray_len = 20
    half_angle_rad = (cone_angle / 2) * pi / 180
    exit_x = noz_x + noz_w
    ax.plot([exit_x, exit_x + spray_len], [0, spray_len * sin(half_angle_rad) * 3],
            color=FLAME_COL, lw=1.0, ls="--")
    ax.plot([exit_x, exit_x + spray_len], [0, -spray_len * sin(half_angle_rad) * 3],
            color=FLAME_COL, lw=1.0, ls="--")
    ax.text(exit_x + spray_len + 2, 0, f"Spray cone\n{cone_angle:.1f} deg",
            fontsize=6, va="center", color=FLAME_COL)

    dim_line(ax, (sc_x, -sc_h/2), (sc_x, sc_h/2),
             f"Ds = {D_swirl:.1f} mm", offset=pass_w + 5, side="below")
    dim_line(ax, (exit_x, -noz_h/2), (exit_x, noz_h/2),
             f"D0 = {D_nozzle:.1f} mm", offset=5, side="above", fontsize=DIM_FS - 0.5)
    dim_line(ax, (sc_x, -sc_h/2), (sc_x + sc_w, -sc_h/2),
             f"Ls = {L_swirl:.1f} mm", offset=5, side="below")

    info = (f"Bio-oil atomizer\n"
            f"Q_oil = {Q_oil/1000:.1f} kW (LHV)\n"
            f"dP_inj = 10 bar\n"
            f"Cd = {Cd_oil:.4f}\n"
            f"K = {K_oil:.4f}\n"
            f"SMD = {SMD:.1f} um (corrected)\n"
            f"Dp = {D_passage:.2f} mm (x{N_passages})")
    ax.text(sc_x - pass_w - 2, -sc_h/2 - 12, info, fontsize=LABEL_FS - 1, va="top",
            bbox=dict(fc="#FFFFF0", ec="#BBBB88", boxstyle="round,pad=0.3"))

    ax.set_xlim(sc_x - pass_w - 15, exit_x + spray_len + 20)
    ax.set_ylim(-sc_h/2 - 25, sc_h/2 + 15)
    ax.set_xlabel("mm (scaled x8 for visibility)", fontsize=6, color="#999")
    ax.tick_params(labelsize=6)


# ==================================================================
#  SHEET 5 - CONVECTION TUBE BANK (Front View)
# ==================================================================
def draw_conv_tubes(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 5 - Convection Zone Tube Bank (Front View)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_t = D_tube_conv_OD / 2 * 1000
    ph = pitch_h * 1000
    pv = pitch_v * 1000

    total_rows = N_rows + N_shield
    for row in range(total_rows):
        for col in range(N_tubes_row):
            cx = col * ph
            cy = row * pv
            fc = "#DDCCBB" if row < N_shield else "#CCCCCC"
            ax.add_patch(Circle((cx, cy), R_t, fc=fc, ec=TUBE_COL, lw=0.6))

    for row in range(total_rows):
        label = f"Shield {row+1}" if row < N_shield else f"Conv {row-N_shield+1}"
        ax.text(-15, row * pv, label, fontsize=6, ha="right", va="center", color="#886644")

    total_w = (N_tubes_row - 1) * ph
    total_h = (total_rows - 1) * pv
    margin = 30
    ax.add_patch(Rectangle((-margin, -margin), total_w + 2*margin, total_h + 2*margin,
                            fill=False, ec=WALL_COL, lw=2.0, ls="--"))

    dim_line(ax, (0, -margin), (ph, -margin),
             f"P_h = {pitch_h*1000:.1f} mm", offset=10, side="below")
    dim_line(ax, (total_w + margin, 0), (total_w + margin, pv),
             f"P_v = {pitch_v*1000:.1f} mm", offset=10, side="above")

    info = (f"Tube OD = {D_tube_conv_OD*1000:.0f} mm\n"
            f"Tube ID = {D_tube_conv_ID*1000:.0f} mm\n"
            f"{N_tubes_row} tubes/row x {total_rows} rows\n"
            f"({N_shield} shield + {N_rows} conv)\n"
            f"{N_parallel} parallel salt streams\n"
            f"Q_conv = {Q_conv/1000:.1f} kW\n"
            f"U_c = {U_conv:.1f} W/m2/K")
    ax.text(total_w + margin + 15, total_h, info, fontsize=LABEL_FS - 1, va="top",
            bbox=dict(fc="#FFFFF0", ec="#BBBB88", boxstyle="round,pad=0.4"))

    ax.set_xlim(-margin - 25, total_w + margin + 80)
    ax.set_ylim(-margin - 25, total_h + margin + 15)
    ax.set_xlabel("mm", fontsize=7); ax.set_ylabel("mm", fontsize=7)
    ax.tick_params(labelsize=6)


# ==================================================================
#  SHEET 6 - HELICAL COIL PROFILE
# ==================================================================
def draw_coil_profile(ax):
    ax.set_aspect("equal")
    ax.set_title("Sheet 6 - Radiant Helical Coil (Side Profile)", fontsize=TITLE_FS,
                 fontweight="bold", pad=12)

    R_coil_mm = D_helix / 2 * 1000
    OD_mm = D_tube_rad_OD * 1000
    ID_mm = D_tube_rad_ID * 1000
    pitch_mm = coil_pitch * 1000

    for i in range(N_turns_rad):
        y = i * pitch_mm
        ax.add_patch(Circle((-R_coil_mm, y), OD_mm/2,
                            fc="#CCCCCC", ec=TUBE_COL, lw=0.8, zorder=3))
        ax.add_patch(Circle((-R_coil_mm, y), ID_mm/2,
                            fc="#FFDDBB", ec="#999", lw=0.4, zorder=4))
        ax.add_patch(Circle((R_coil_mm, y), OD_mm/2,
                            fc="#CCCCCC", ec=TUBE_COL, lw=0.8, zorder=3))
        ax.add_patch(Circle((R_coil_mm, y), ID_mm/2,
                            fc="#FFDDBB", ec="#999", lw=0.4, zorder=4))

    ax.plot([0, 0], [-50, N_turns_rad * pitch_mm + 50], color="#333", lw=0.5, ls="-.")
    ax.text(5, N_turns_rad * pitch_mm + 55, "CL", fontsize=6, color="#666")

    dim_line(ax, (-R_coil_mm, -30), (R_coil_mm, -30),
             f"D_helix = {D_helix*1000:.0f} mm", offset=15, side="below")
    dim_line(ax, (R_coil_mm + OD_mm, 0), (R_coil_mm + OD_mm, pitch_mm),
             f"Pitch = {pitch_mm:.1f} mm", offset=20, side="above")
    dim_line(ax, (-R_coil_mm - OD_mm, 0),
             (-R_coil_mm - OD_mm, (N_turns_rad - 1) * pitch_mm),
             f"H_coil = {H_coil*1000:.0f} mm", offset=30, side="below")

    ax.annotate(f"OD = {OD_mm:.0f} mm\nID = {ID_mm:.0f} mm\nk = {k_tube} W/m/K",
                xy=(R_coil_mm + OD_mm/2, pitch_mm * 3),
                xytext=(R_coil_mm + 80, pitch_mm * 3),
                fontsize=LABEL_FS - 0.5,
                arrowprops=dict(arrowstyle="->", lw=0.5, color="#555"),
                bbox=dict(fc="#FFFFF0", ec="#CCCCAA", boxstyle="round,pad=0.3"))

    info = (f"Turns: {N_turns_rad}\n"
            f"L_tube = {L_tube_rad:.1f} m\n"
            f"A_rad = {A_rad_actual:.2f} m2\n"
            f"q = {q_flux:.0f} W/m2\n"
            f"dP = {DP_rad/1000:.1f} kPa\n"
            f"Re = {Re_salt_rad}\n"
            f"U = {U_overall_rad:.1f} W/m2/K")
    ax.text(-R_coil_mm - 100, (N_turns_rad - 1) * pitch_mm, info,
            fontsize=LABEL_FS - 1, va="top",
            bbox=dict(fc="white", ec="#999", boxstyle="round,pad=0.4"))

    pad_x = 80
    ax.set_xlim(-R_coil_mm - pad_x - 60, R_coil_mm + pad_x + 50)
    ax.set_ylim(-pad_x, N_turns_rad * pitch_mm + pad_x)
    ax.set_xlabel("mm", fontsize=7); ax.set_ylabel("mm", fontsize=7)
    ax.tick_params(labelsize=6)


# ==================================================================
#  COMPOSE & SAVE
# ==================================================================
def main():
    # Page 1: Overall elevation + Burner arrangement plan
    fig1, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 12))
    fig1.suptitle("Combined Burner Fired Heater (H-101) - Design Drawings (1/3)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_elevation(ax1)
    draw_burner_plan(ax2)
    add_title_block(fig1, "FH-001")
    fig1.tight_layout(rect=[0, 0.02, 1, 0.95])
    fig1.savefig("fired_heater_page1.png", dpi=200, bbox_inches="tight")
    print("Saved page 1")

    # Page 2: Gas burner + Oil atomizer
    fig2, (ax3, ax4) = plt.subplots(2, 1, figsize=(14, 12))
    fig2.suptitle("Combined Burner Fired Heater (H-101) - Design Drawings (2/3)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_gas_burner(ax3)
    draw_oil_atomizer(ax4)
    add_title_block(fig2, "FH-002")
    fig2.tight_layout(rect=[0, 0.02, 1, 0.95])
    fig2.savefig("fired_heater_page2.png", dpi=200, bbox_inches="tight")
    print("Saved page 2")

    # Page 3: Convection tubes + Coil profile
    fig3, (ax5, ax6) = plt.subplots(1, 2, figsize=(16, 10))
    fig3.suptitle("Combined Burner Fired Heater (H-101) - Design Drawings (3/3)",
                  fontsize=15, fontweight="bold", y=0.98)
    draw_conv_tubes(ax5)
    draw_coil_profile(ax6)
    add_title_block(fig3, "FH-003")
    fig3.tight_layout(rect=[0, 0.02, 1, 0.95])
    fig3.savefig("fired_heater_page3.png", dpi=200, bbox_inches="tight")
    print("Saved page 3")

    # Combined PDF
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages("Fired_Heater_Design_Drawings.pdf") as pdf:
        pdf.savefig(fig1, bbox_inches="tight")
        pdf.savefig(fig2, bbox_inches="tight")
        pdf.savefig(fig3, bbox_inches="tight")
    print("Saved combined PDF")

    plt.close("all")


if __name__ == "__main__":
    main()
