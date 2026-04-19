function results = heater_design(params)
% HEATER_DESIGN  Combined biogas/bio-oil fired heater design.
%
%   results = heater_design()          % use all defaults
%   results = heater_design(params)    % override any subset
%
%   params is a struct whose fields override defaults. Any field
%   not supplied keeps its default value.  The full list of
%   tuneable fields is printed by:  heater_design('list')
%
%   results is a struct containing every computed quantity plus
%   a nested .status struct with PASS/FAIL flags.
%
%   Requires: CoolProp (via Python bridge or MEX) for gas-mixture
%             density/viscosity lookups.  If CoolProp is not
%             available the code falls back to ideal-gas estimates
%             and prints a warning.
%
%   Based on the Maple 2025 worksheet:
%     "3rd Year Project, Heating System Design – Diesel & Gas Burner"
%   Methodology: Walas (Lobo-Evans / Wimpress) for fired heaters,
%                Lacava/Bastos-Netto/Pimenta for pressure-swirl atomiser,
%                biogas burner design per Ethiopian NDL / O'Reilly references.
%
%   Author: Jake (QMUL) — MATLAB translation with Claude assistance
%   Date:   2026

% =====================================================================
%  Handle 'list' call
% =====================================================================
if nargin == 1 && ischar(params) && strcmpi(params, 'list')
    d = default_params();
    fn = fieldnames(d);
    fprintf('\n  %-25s  %s\n', 'Parameter', 'Default');
    fprintf('  %-25s  %s\n', repmat('-',1,25), repmat('-',1,20));
    for k = 1:numel(fn)
        fprintf('  %-25s  %g\n', fn{k}, d.(fn{k}));
    end
    fprintf('\n');
    results = d;
    return
end

% =====================================================================
%  Merge user overrides with defaults
% =====================================================================
p = default_params();
if nargin >= 1 && isstruct(params)
    fn = fieldnames(params);
    for k = 1:numel(fn)
        if isfield(p, fn{k})
            p.(fn{k}) = params.(fn{k});
        else
            warning('heater_design:unknownParam', ...
                'Unknown parameter "%s" ignored.', fn{k});
        end
    end
end

% =====================================================================
%  Unpack into local variables for readability
% =====================================================================
% --- System targets ---
Q_target      = p.Q_target;        % kW
T_salt_in     = p.T_salt_in;       % C
T_salt_out    = p.T_salt_out;      % C

% --- Salt properties ---
T_salt_melt   = p.T_salt_melt;     % C
T_salt_max    = p.T_salt_max;      % C
Cp_salt       = p.Cp_salt;         % J/kg/K
rho_salt      = p.rho_salt;        % kg/m3
k_salt        = p.k_salt;          % W/m/K
R_gas         = p.R_gas;           % J/mol/K

% --- Biogas ---
xi_CH4        = p.xi_CH4;
xi_CO2        = p.xi_CO2;
m_gas_factory = p.m_gas_factory;   % kg/s
m_molar_CH4   = p.m_molar_CH4;    % kg/mol
m_molar_CO2   = p.m_molar_CO2;    % kg/mol
Q_mol_CH4     = p.Q_mol_CH4;      % kJ/mol (HHV)

% --- Bio-oil ---
m_oil         = p.m_oil;           % kg/s
rho_oil       = p.rho_oil;        % kg/m3
HHV_oil       = p.HHV_oil;        % kJ/kg
LHV_oil       = p.LHV_oil;        % kJ/kg
nu_oil        = p.nu_oil;         % m2/s
sigma_oil     = p.sigma_oil;      % N/m
w_C           = p.w_C;
w_H           = p.w_H;
w_O           = p.w_O;
w_N           = p.w_N;
n_H           = p.n_H;
n_O_          = p.n_O;
n_N           = p.n_N;

% --- Gas burner geometry ---
T_prior_gas   = p.T_prior_gas;     % K
p_prior_gas   = p.p_prior_gas;     % mbar
C_d_gas       = p.C_d_gas;
a_o_gas       = p.a_o_gas;         % deg
n_p_gas       = p.n_p_gas;
d_p_gas       = p.d_p_gas;         % m

% --- Oil burner geometry ---
DP_oil        = p.DP_oil;          % Pa
D_0           = p.D_0;             % m
D_p           = p.D_p;             % m
D_s           = p.D_s;             % m
L_s           = p.L_s;             % m
L_0           = p.L_0;             % m
L_p           = p.L_p;             % m
rho_a         = p.rho_a;           % kg/m3
n_p_oil       = p.n_p_oil;

% --- Heater geometry ---
d_tube_OD_heat = p.d_tube_OD_heat; % m
d_tube_ID_heat = p.d_tube_ID_heat; % m
D_coil_heat    = p.D_coil_heat;    % m
p_coil_heat    = p.p_coil_heat;    % m
D_shell_heat   = p.D_shell_heat;   % m
d_tube_OD_conv = p.d_tube_OD_conv; % m
d_tube_ID_conv = p.d_tube_ID_conv; % m
p_conv_horiz   = p.p_conv_horizontal;
p_conv_vert    = p.p_conv_vertical;
W_conv_bend    = p.W_conv_bend;    % m
n_shield_rows  = p.n_shield_rows;
n_conv_parallel= p.n_conv_parallel;
k_tube_heat    = p.k_tube_heat;    % W/m/K
t_refr_heat    = p.t_refr_heat;    % m
k_refr_heat    = p.k_refr_heat;    % W/m/K

% --- Performance targets ---
z_excess       = p.z_excess;
eta_heater     = p.eta_heater;
f_radiant      = p.f_radiant;
q_rad_target   = p.q_rad;          % W/m2

% Derived
mu_oil = nu_oil * rho_oil;  % Pa.s

% Salt viscosity function (mPa.s -> Pa.s via /1000 at call site)
F_mu_salt = @(T_K) 0.0852 * exp(3.51e4 ./ (R_gas .* T_K));  % mPa.s

% =====================================================================
%  OIL BURNER GEOMETRY CHECKS
% =====================================================================
Check1 = L_s / D_s;   % must be > 0.5
Check2 = L_p / D_p;   % must be > 1.3
Check3 = L_0 / D_0;

% =====================================================================
%  GAS BURNER
% =====================================================================
% Fuel calculations
m_gas_import = 0;   % initial; solved later
m_fuel_gas   = m_gas_factory + m_gas_import;
Q_mol_fuel   = Q_mol_CH4 * xi_CH4;                        % kJ/mol
m_molar_fuel = xi_CH4*m_molar_CH4 + xi_CO2*m_molar_CO2;   % kg/mol
Q_comb_gas   = (m_fuel_gas / m_molar_fuel) * Q_mol_fuel;   % kW

% --- Gas density via CoolProp or ideal-gas fallback ---
P_abs_gas = 101325 + p_prior_gas*100;   % Pa
[rho_mix, coolprop_ok] = gas_density_coolprop( ...
    xi_CH4, xi_CO2, P_abs_gas, T_prior_gas);
if ~coolprop_ok
    % Ideal gas fallback
    M_mix   = m_molar_fuel;                          % kg/mol
    rho_mix = P_abs_gas * M_mix / (R_gas * T_prior_gas);
end

m_fuel_kg_h = m_fuel_gas * 3600;         % kg/h
V_fuel      = m_fuel_kg_h / rho_mix;     % m3/h
s_grav      = rho_mix / 1.225;           % specific gravity

% Injector orifice (eq1 solved for A_o)
%   V_fuel = 0.0467 * C_d_gas * A_o_mm2 * sqrt(30) * sqrt(1/s)
%   => A_o_mm2 = V_fuel / (0.0467*C_d_gas * sqrt(30/s))
A_o_mm2 = V_fuel / (0.0467 * C_d_gas * sqrt(30) * sqrt(1/s_grav));
A_o     = A_o_mm2 / 1e6;                % m2
r_o     = sqrt(A_o / pi);               % m
b_o     = 1.75 * r_o;                   % m
d_o     = 2 * r_o;                       % m

% Air-to-fuel ratio (CH4 + 2O2 -> CO2 + 2H2O)
Per_CH4 = 1 / xi_CH4;
Per_O2  = 2 / 0.21;
v_air   = Per_O2 / Per_CH4;             % m3 air / m3 gas
V_air   = v_air * V_fuel;               % m3/h
r_ent   = v_air * 0.5;                  % entrainment ratio

% Throat design
d_t = d_o * (r_ent / sqrt(s_grav) + 1); % m (from Prigg eq2)
L_t = d_t * 10;                          % m
A_t = pi * (d_t/2)^2;                    % m2

% Orifice velocity
v_o = V_fuel / (3600 * A_o);            % m/s

% Throat flow conditions
V_airfuel = V_fuel * (1 + r_ent) / 3600; % m3/s
m_air_g_s = m_fuel_gas * v_air * (1.184 / rho_mix);  % kg/s

% Throat temperature (mixing)
T_t = (m_fuel_gas*T_prior_gas + m_air_g_s*298.18) / ...
      (m_fuel_gas + m_air_g_s);          % K

% Throat pressure (Bernoulli)
p_o = 101325;  % Pa
p_t = p_o - rho_mix*(v_o^2/2)*(1 - (d_o/d_t)^4);

% Pseudo-fluid composition in throat
total_mols = 1 + r_ent;
x_CH4_t = xi_CH4 / total_mols;
x_CO2_t = xi_CO2 / total_mols;
x_N2_t  = (r_ent*0.79) / total_mols;
x_O2_t  = (r_ent*0.21) / total_mols;

% Throat density & viscosity
[rho_t, mu_t] = throat_props(x_CH4_t, x_CO2_t, x_N2_t, x_O2_t, ...
                              p_t, T_t, coolprop_ok, m_molar_fuel, R_gas, r_ent);

% Reynolds number in throat
Re_t = (4 * rho_t * V_airfuel) / (pi * mu_t * d_t);
f_t  = 0.316 / Re_t^0.25;
DP_t_gas = (f_t/2) * rho_t * (16*V_airfuel^2) / (pi^2 * d_t^5) * L_t;

% Flame ports
A_p_gas = n_p_gas * pi * d_p_gas^2 / 4;
v_p_gas = V_airfuel / A_p_gas;

% Prigg ratio check
Prigg_ratio = A_p_gas / A_t;

% =====================================================================
%  OIL BURNER (Lacava / Bastos-Netto / Pimenta)
% =====================================================================
FN_oil = m_oil / sqrt(rho_oil * DP_oil);          % m2
A_0    = pi * (D_0/2)^2;                           % m2
Cd_oil = m_oil / (A_0 * sqrt(2*rho_oil*DP_oil));
A_p_oil= n_p_oil * pi * (D_p/2)^2;                % m2

% Correlations (for reference / comparison)
K_oil  = A_p_oil / (D_s * D_0);
eq1_Carlisle = 0.0616 * (D_s/D_0) * K_oil;
eq2_RL       = 0.35 * sqrt(D_s/D_0) * sqrt(K_oil);

% Air core fraction X from D_0 = 2*sqrt(FN_oil / (pi*(1-X)*sqrt(2)))
% Solve: (D_0/2)^2 = FN_oil / (pi*(1-X)*sqrt(2))
%   => 1-X = FN_oil / (pi*(D_0/2)^2*sqrt(2))
X_oil = 1 - FN_oil / (pi * (D_0/2)^2 * sqrt(2));

% Spray semi-angle
sin_theta = (pi/2 * Cd_oil) / (K_oil * (1 + sqrt(X_oil)));
theta_oil = asin(sin_theta);                       % rad
theta_oil_deg = theta_oil * 180/pi;
spray_angle_full = 2 * theta_oil_deg;

% Sheet thickness at nozzle tip
h_0_oil = 0.00805 * FN_oil * sqrt(rho_oil) / (D_0 * cos(theta_oil));

% Exit velocity
U_0_oil = sqrt(2*DP_oil / rho_oil);

% Ligament diameter
D_L_oil = 0.9615 * cos(theta_oil) * ...
    (h_0_oil^4 * sigma_oil^2 / (U_0_oil^4 * rho_a * rho_oil))^(1/6) * ...
    (1 + 2.6*mu_oil*cos(theta_oil) * ...
    (h_0_oil^2 * rho_a^4 * U_0_oil^7 / (72*rho_oil^2*sigma_oil^5))^(1/3))^0.2;

% Sauter Mean Diameter
SMD_oil    = 1.89 * D_L_oil;
SMD_oil_um = SMD_oil * 1e6;
SMD_corrected = SMD_oil_um * 1.75;

Q_comb_oil = m_oil * LHV_oil;  % kJ/s = kW

% =====================================================================
%  HEATING COILS — System requirements
% =====================================================================
Q_absorbed   = Q_target * 1000;                     % W
Q_released   = Q_target * 1000 / eta_heater;        % W
Q_radiant    = f_radiant * Q_absorbed;              % W
Q_convection = Q_absorbed - Q_radiant;              % W
m_salt       = Q_absorbed / (Cp_salt * (T_salt_out - T_salt_in));

% Flue gas mass flows
O2_per_kg_gas = (xi_CH4 / m_molar_fuel) * 2 * 0.032;
air_per_kg_gas= O2_per_kg_gas / 0.233;
O2_per_kg_oil = (w_C/12)*32 + (w_H/4)*32 - (w_O/32)*32;
air_per_kg_oil= O2_per_kg_oil / 0.233;
m_total_air  = (1+z_excess) * (air_per_kg_gas*m_fuel_gas + air_per_kg_oil*m_oil);
m_flue       = m_total_air + m_fuel_gas + m_oil;

% =====================================================================
%  RADIANT ZONE — Helical coil geometry
% =====================================================================
A_radiant     = Q_radiant / q_rad_target;           % m2
L_turn_heat   = sqrt((pi*D_coil_heat)^2 + p_coil_heat^2);
A_per_turn    = pi * d_tube_OD_heat * L_turn_heat;
N_turns_heat  = A_radiant / A_per_turn;
N_turns_int   = ceil(N_turns_heat);
H_coil        = N_turns_int * p_coil_heat;          % m

A_rad_actual  = N_turns_int * A_per_turn;
q_rad_actual  = Q_radiant / A_rad_actual;
L_tube_rad    = N_turns_int * L_turn_heat;

% Cold plane & refractory
A_cp    = pi * D_coil_heat * H_coil;
x_spacing = p_coil_heat / d_tube_OD_heat;
alpha_tube= 1 - (0.0277 + 0.0927*(x_spacing-1))*(x_spacing-1);

A_shell = pi*D_shell_heat*H_coil + 2*(pi/4)*D_shell_heat^2;
A_refr  = A_shell - A_cp;
alpha_AR= alpha_tube * A_cp;
ratio_Aw_alphaAR = A_refr / alpha_AR;

% Firebox dimensions
D_firebox = D_coil_heat - d_tube_OD_heat;
L_D_ratio = H_coil / D_firebox;

% Mean beam length
if L_D_ratio <= 1.0
    L_beam = (2/3) * D_firebox;
else
    L_beam = 1.0 * D_firebox;
end

P_CO2_H2O = 0.288 - 0.229*z_excess + 0.090*z_excess^2;
L_beam_ft = L_beam * 3.28084;
PL        = P_CO2_H2O * L_beam_ft;

% Salt temperatures in Fahrenheit
T_salt_in_F  = T_salt_in  * 9/5 + 32;
T_salt_out_F = T_salt_out * 9/5 + 32;
T_salt_rad_in_F = T_salt_in_F + (1 - f_radiant)*(T_salt_out_F - T_salt_in_F);

% Mean tube wall temperature (Walas approximation)
T_tube_F = 100 + 0.5*(T_salt_rad_in_F + T_salt_out_F);
T_tube_R = T_tube_F + 460;
T_tube_C = (T_tube_F - 32) * 5/9;
T_tube_K = T_tube_C + 273.15;

% Convert to Imperial for Walas
Q_n_Btu       = Q_released * 3.41214;
Q_radiant_Btu = Q_radiant  * 3.41214;
alphaAR_sqft  = alpha_AR   * 10.7639;

% =====================================================================
%  RADIANT ZONE — Newton-Raphson iteration for T_g
% =====================================================================
f_loss = 0.025;
T_g    = 1600;  % F initial guess

for iter = 1:30
    phi_g   = F_emissivity(T_g, PL);
    z9_val  = A_refr*10.7639 / alphaAR_sqft;
    F_exc   = F_exchange(phi_g, z9_val);

    % LHS: radiant heat transfer
    LHS     = 1730*((T_g+460)/1000)^4 - 1730*(T_tube_R/1000)^4 ...
              + 7*(T_g - T_tube_F);
    Q_R_calc= alphaAR_sqft * F_exc * LHS;

    % RHS: heat balance
    Qg_ratio   = F_Qg_ratio(T_g, z_excess);
    Q_R_balance= Q_n_Btu * (1 - f_loss - Qg_ratio);

    residual = Q_R_calc - Q_R_balance;

    % Numerical derivative
    dT = 1.0;
    phi_g2  = F_emissivity(T_g+dT, PL);
    F_exc2  = F_exchange(phi_g2, z9_val);
    LHS2    = 1730*((T_g+dT+460)/1000)^4 - 1730*(T_tube_R/1000)^4 ...
              + 7*(T_g+dT - T_tube_F);
    Q_R_calc2   = alphaAR_sqft * F_exc2 * LHS2;
    Qg_ratio2   = F_Qg_ratio(T_g+dT, z_excess);
    Q_R_balance2= Q_n_Btu * (1 - f_loss - Qg_ratio2);
    residual2   = Q_R_calc2 - Q_R_balance2;

    dres_dT = (residual2 - residual) / dT;
    if abs(dres_dT) < 1e-10, break; end

    T_g_new = T_g - residual / dres_dT;
    if abs(T_g_new - T_g) < 0.01
        T_g = T_g_new;
        break;
    end
    T_g = T_g_new;
end

% Final converged values
phi_g_final = F_emissivity(T_g, PL);
F_exc_final = F_exchange(phi_g_final, z9_val);
Q_R_final_Btu = alphaAR_sqft * F_exc_final * ...
    (1730*((T_g+460)/1000)^4 - 1730*(T_tube_R/1000)^4 + 7*(T_g - T_tube_F));
Q_R_final = Q_R_final_Btu / 3.41214;   % W
T_g_C     = (T_g - 32)*5/9;
T_g_K     = T_g_C + 273.15;

% Radiant flux verification
q_rad_check     = Q_R_final / A_rad_actual;
q_rad_check_Btu = q_rad_check * 0.316998;

% =====================================================================
%  SALT-SIDE THERMODYNAMICS (Radiant)
% =====================================================================
T_salt_avg_K  = (T_salt_in + T_salt_out)/2 + 273.15;
mu_salt_Pas   = F_mu_salt(T_salt_avg_K) / 1000;
v_salt        = m_salt / (rho_salt * pi * (d_tube_ID_heat/2)^2);
Re_salt       = rho_salt * v_salt * d_tube_ID_heat / mu_salt_Pas;
Pr_salt       = Cp_salt * mu_salt_Pas / k_salt;
De_salt       = Re_salt * sqrt(d_tube_ID_heat / D_coil_heat);

% Nusselt number
if Re_salt > 10000
    Nu_salt = 0.023 * Re_salt^0.85 * Pr_salt^0.4 * ...
              (1 + 3.6*(1 - d_tube_ID_heat/D_coil_heat)^0.8);
elseif Re_salt > 2100
    Nu_salt = 0.023 * Re_salt^0.85 * Pr_salt^0.4 * ...
              (d_tube_ID_heat/D_coil_heat)^0.1;
else
    Nu_salt = 0.913 * De_salt^(1/3) * Pr_salt^(1/3);
end

h_i = Nu_salt * k_salt / d_tube_ID_heat;

% Outside film coefficient
h_o = q_rad_check / (T_g_K - T_tube_K);

% Thermal resistances
R_o    = 1/h_o;
R_wall = (d_tube_OD_heat/2) * log(d_tube_OD_heat/d_tube_ID_heat) / k_tube_heat;
R_i    = (d_tube_OD_heat/d_tube_ID_heat) * (1/h_i);
U_overall = 1 / (R_o + R_wall + R_i);

% LMTD (radiant)
DT_hot  = T_g_K - (T_salt_out + 273.15);
T_salt_rad_in_C = (T_salt_rad_in_F - 32)*5/9;
DT_cold = T_g_K - (T_salt_rad_in_C + 273.15);
if abs(DT_hot - DT_cold) < 1
    LMTD_rad = (DT_hot + DT_cold)/2;
else
    LMTD_rad = (DT_hot - DT_cold) / log(DT_hot/DT_cold);
end

A_required_UA = Q_radiant / (U_overall * LMTD_rad);
T_skin_max    = T_salt_out + q_rad_check / h_i;
T_skin_outside= T_skin_max + q_rad_check * R_wall;

% =====================================================================
%  CONVECTION ZONE
% =====================================================================
Q_convection_btu = Q_convection * 3.41214;

% Duct geometry
W_conv = sqrt(D_shell_heat^2 / 2);
n_tubes_per_row_conv = ceil(W_conv / p_conv_horiz);
L_tube_conv = W_conv - 2*W_conv_bend;

A_conv_free = W_conv*L_tube_conv - n_tubes_per_row_conv*d_tube_OD_conv*L_tube_conv;
A_conv_free_sqft = A_conv_free * 10.7639;
G_convection = (m_flue * 2.20462) / A_conv_free_sqft;

% Stack temperature iteration
Qs_ratio = 1 - eta_heater + f_loss;
T_stack  = 500;  % F initial guess
for iter2 = 1:30
    Qs_calc  = F_Qg_ratio(T_stack, z_excess);
    res2     = Qs_calc - Qs_ratio;
    Qs_calc2 = F_Qg_ratio(T_stack+1, z_excess);
    dres2    = Qs_calc2 - Qs_calc;
    if abs(dres2) < 1e-10, break; end
    T_stack = T_stack - res2/dres2;
    if abs(res2) < 0.0001, break; end
end

% LMTD (convection) in Fahrenheit
DT_conv_hot  = T_g - T_salt_rad_in_F;
DT_conv_cold = T_stack - T_salt_in_F;
if DT_conv_cold <= 0
    LMTD_conv_F = DT_conv_hot;
elseif abs(DT_conv_hot - DT_conv_cold) < 1
    LMTD_conv_F = (DT_conv_hot + DT_conv_cold)/2;
else
    LMTD_conv_F = (DT_conv_hot - DT_conv_cold) / log(DT_conv_hot/DT_conv_cold);
end
LMTD_conv_K = LMTD_conv_F * 5/9;

% Walas convection coefficient
T_f_conv_F = 0.5*(T_salt_in_F + T_salt_rad_in_F) + 0.5*LMTD_conv_F;
z_Uc = T_f_conv_F / 1000;
a_Uc = 2.461 - 0.759*z_Uc + 1.625*z_Uc^2;
b_Uc = 0.7655 + 21.373*z_Uc - 9.6625*z_Uc^2;
c_Uc = 9.7938 - 30.809*z_Uc + 14.333*z_Uc^2;
d_tube_OD_in = d_tube_OD_conv / 0.0254;

U_conv_Btu = (a_Uc + b_Uc*G_convection + c_Uc*G_convection^2) * ...
             (4.5/d_tube_OD_conv)^0.25;    % NOTE: uses d_tube_OD_conv in m for the exponent ratio per Maple
U_convection = U_conv_Btu * 5.67826;       % W/m2/K

% Required convection area
A_convection = Q_convection / (U_convection * LMTD_conv_K);
A_conv_per_row = n_tubes_per_row_conv * pi * d_tube_OD_conv * L_tube_conv;
n_rows_conv  = ceil(A_convection / A_conv_per_row);
L_tube_conv_total = n_rows_conv * n_tubes_per_row_conv * (L_tube_conv + W_conv_bend);

Q_convection_check = m_salt * Cp_salt * (T_salt_rad_in_C - T_salt_in);

% Salt-side (convection)
T_salt_avg_conv   = (T_salt_in + T_salt_rad_in_C)/2;
T_salt_avg_conv_K = T_salt_avg_conv + 273.15;
mu_salt_conv_Pas  = F_mu_salt(T_salt_avg_conv_K) / 1000;
v_salt_conv       = (m_salt / (rho_salt * pi * (d_tube_ID_heat/2)^2)) / n_conv_parallel;
Re_salt_conv      = rho_salt * v_salt_conv * d_tube_ID_heat / mu_salt_conv_Pas;
Pr_salt_conv      = Cp_salt * mu_salt_conv_Pas / k_salt;

if Re_salt_conv > 10000
    Nu_salt_conv = 0.023 * Re_salt_conv^0.8 * Pr_salt_conv^0.4;
elseif Re_salt_conv > 2100
    Nu_salt_conv = 0.023 * Re_salt_conv^0.85 * Pr_salt_conv^0.4;
else
    Nu_salt_conv = 1.86 * (Re_salt_conv * Pr_salt_conv * ...
                   d_tube_ID_heat / L_tube_conv)^(1/3);
end
h_i_conv = Nu_salt_conv * k_salt / d_tube_ID_heat;

% Checking U
R_wall_conv = (d_tube_OD_conv/2) * log(d_tube_OD_conv/d_tube_ID_conv) / k_tube_heat;
R_i_conv    = (d_tube_OD_conv/d_tube_ID_conv) * (1/h_i_conv);
R_inside_plus_wall = R_wall_conv + R_i_conv;
U_max_possible     = 1 / R_inside_plus_wall;

if U_convection < U_max_possible
    h_o_conv    = 1 / (1/U_convection - R_wall_conv - R_i_conv);
    R_o_conv    = 1 / h_o_conv;
    U_check_conv= U_convection;
else
    R_o_conv    = 1 / U_convection;
    h_o_conv    = U_convection;
    U_check_conv= 1 / (R_o_conv + R_wall_conv + R_i_conv);
end

% =====================================================================
%  PRESSURE DROP
% =====================================================================
% Convection section
if Re_salt_conv > 4000
    f_conv = 0.316 / Re_salt_conv^0.25;
elseif Re_salt_conv > 2100
    f_conv = 0.316 / Re_salt_conv^0.25;
else
    f_conv = 64 / Re_salt_conv;
end

n_passes_total_conv = n_tubes_per_row_conv * n_rows_conv;
L_total_straight_conv = n_passes_total_conv * L_tube_conv;
n_bends_conv = n_passes_total_conv;
K_bend       = 1.5;

DP_friction_conv = f_conv * (L_tube_conv_total/d_tube_ID_conv) * ...
                   0.5 * rho_salt * v_salt_conv^2;
DP_bends_conv    = n_bends_conv * K_bend * 0.5 * rho_salt * v_salt_conv^2;
DP_total_conv    = DP_friction_conv + DP_bends_conv;

% Radiation section
f_Darcy_rad = 0.316 / Re_salt^0.25;
f_coil      = f_Darcy_rad * (1 + 3.6*(1 - d_tube_ID_heat/D_coil_heat)^0.8);
DP_total_rad= f_coil * (L_tube_rad/d_tube_ID_heat) * 0.5 * rho_salt * v_salt^2;

DP_total = DP_total_rad + DP_total_conv;

% =====================================================================
%  ENERGY BALANCE — solve for import gas
% =====================================================================
Q_total_check   = Q_R_final + Q_convection;
Q_released_check= Q_comb_gas + Q_comb_oil;   % kW total

Q_required_release = Q_target * 1000 / eta_heater;  % W
Q_from_oil         = m_oil * LHV_oil * 1000;         % W
Q_from_factory_gas = (m_gas_factory / m_molar_fuel) * Q_mol_fuel * 1000;  % W
Q_shortfall        = Q_required_release - Q_from_oil - Q_from_factory_gas;

if Q_shortfall > 0
    m_gas_import = Q_shortfall / ((Q_mol_fuel / m_molar_fuel) * 1000);
else
    m_gas_import = 0;
end

% =====================================================================
%  STATUS FLAGS
% =====================================================================
status = struct();
status.energy_balance    = (Q_comb_gas + Q_comb_oil) >= (Q_released/1000);
status.prigg_ratio       = Prigg_ratio >= 1.5 && Prigg_ratio <= 2.2;
status.oil_K             = K_oil >= 0.19 && K_oil <= 1.21;
status.radiant_flux      = abs(q_rad_check - q_rad_target)/q_rad_target <= 0.10;
status.skin_temp         = T_skin_max <= T_salt_max;
status.radiant_area      = A_rad_actual >= A_required_UA;
status.f_radiant_conv    = abs(Q_R_final/Q_absorbed - f_radiant) <= 0.05;
status.oil_SMD           = SMD_corrected <= 100;
status.oil_Ls_Ds         = Check1 > 0.5;
status.oil_Lp_Dp         = Check2 > 1.3;
status.Ds_D0             = (D_s/D_0) >= 1.41 && (D_s/D_0) <= 8.13;
status.throat_dP         = DP_t_gas < p_prior_gas*100;
status.all_pass          = all(structfun(@(x) x, status));

% =====================================================================
%  PACK RESULTS
% =====================================================================
r = struct();

% --- Inputs echoed ---
r.params = p;

% --- System ---
r.Q_target_kW     = Q_target;
r.Q_absorbed_W    = Q_absorbed;
r.Q_released_W    = Q_released;
r.Q_radiant_W     = Q_radiant;
r.Q_convection_W  = Q_convection;
r.m_salt_kgs      = m_salt;
r.eta_heater      = eta_heater;
r.f_radiant_assumed = f_radiant;
r.f_radiant_calc  = Q_R_final / Q_absorbed;

% --- Gas burner ---
r.gas.m_fuel_gas     = m_fuel_gas;
r.gas.m_gas_factory  = m_gas_factory;
r.gas.m_gas_import   = m_gas_import;
r.gas.Q_comb_gas_kW  = Q_comb_gas;
r.gas.rho_mix        = rho_mix;
r.gas.V_fuel_m3h     = V_fuel;
r.gas.m_molar_fuel   = m_molar_fuel;
r.gas.A_o_m2         = A_o;
r.gas.r_o_m          = r_o;
r.gas.d_o_m          = d_o;
r.gas.b_o_m          = b_o;
r.gas.v_o_ms         = v_o;
r.gas.v_air          = v_air;
r.gas.V_air_m3h      = V_air;
r.gas.r_ent          = r_ent;
r.gas.m_air_gs       = m_air_g_s;
r.gas.d_t_m          = d_t;
r.gas.L_t_m          = L_t;
r.gas.A_t_m2         = A_t;
r.gas.Re_t           = Re_t;
r.gas.f_t            = f_t;
r.gas.DP_t_Pa        = DP_t_gas;
r.gas.T_t_K          = T_t;
r.gas.rho_t          = rho_t;
r.gas.mu_t           = mu_t;
r.gas.A_p_gas_m2     = A_p_gas;
r.gas.v_p_gas_ms     = v_p_gas;
r.gas.Prigg_ratio    = Prigg_ratio;
r.gas.n_p_gas        = n_p_gas;
r.gas.d_p_gas_m      = d_p_gas;

% --- Oil burner ---
r.oil.m_oil_kgs      = m_oil;
r.oil.Q_comb_oil_kW  = Q_comb_oil;
r.oil.FN_oil_m2      = FN_oil;
r.oil.Cd_oil         = Cd_oil;
r.oil.Cd_Carlisle    = eq1_Carlisle;
r.oil.Cd_RL          = eq2_RL;
r.oil.K_oil          = K_oil;
r.oil.X_oil          = X_oil;
r.oil.theta_oil_deg  = theta_oil_deg;
r.oil.spray_angle_full = spray_angle_full;
r.oil.h_0_oil_m      = h_0_oil;
r.oil.U_0_oil_ms     = U_0_oil;
r.oil.D_L_oil_m      = D_L_oil;
r.oil.SMD_oil_um     = SMD_oil_um;
r.oil.SMD_corrected_um = SMD_corrected;
r.oil.A_0_m2         = A_0;
r.oil.A_p_oil_m2     = A_p_oil;
r.oil.D_0_m          = D_0;
r.oil.D_s_m          = D_s;
r.oil.D_p_m          = D_p;
r.oil.L_s_m          = L_s;
r.oil.L_0_m          = L_0;
r.oil.L_p_m          = L_p;
r.oil.n_p_oil        = n_p_oil;
r.oil.Check_Ls_Ds    = Check1;
r.oil.Check_Lp_Dp    = Check2;
r.oil.Check_L0_D0    = Check3;

% --- Radiant zone ---
r.rad.N_turns_exact  = N_turns_heat;
r.rad.N_turns_int    = N_turns_int;
r.rad.H_coil_m       = H_coil;
r.rad.L_turn_m       = L_turn_heat;
r.rad.L_tube_rad_m   = L_tube_rad;
r.rad.A_radiant_req  = A_radiant;
r.rad.A_rad_actual   = A_rad_actual;
r.rad.A_cp_m2        = A_cp;
r.rad.A_shell_m2     = A_shell;
r.rad.A_refr_m2      = A_refr;
r.rad.alpha_tube     = alpha_tube;
r.rad.alpha_AR_m2    = alpha_AR;
r.rad.D_firebox_m    = D_firebox;
r.rad.L_D_ratio      = L_D_ratio;
r.rad.L_beam_m       = L_beam;
r.rad.P_CO2_H2O      = P_CO2_H2O;
r.rad.PL_atmft       = PL;
r.rad.T_g_C          = T_g_C;
r.rad.T_g_F          = T_g;
r.rad.T_g_K          = T_g_K;
r.rad.phi_g          = phi_g_final;
r.rad.F_exc          = F_exc_final;
r.rad.Q_R_final_W    = Q_R_final;
r.rad.q_rad_check_Wm2   = q_rad_check;
r.rad.q_rad_target_Wm2  = q_rad_target;
r.rad.iterations     = iter;
r.rad.m_total_air    = m_total_air;
r.rad.m_flue         = m_flue;

% Salt-side radiant
r.rad.Re_salt        = Re_salt;
r.rad.Pr_salt        = Pr_salt;
r.rad.De_salt        = De_salt;
r.rad.Nu_salt        = Nu_salt;
r.rad.h_i_Wm2K      = h_i;
r.rad.h_o_Wm2K      = h_o;
r.rad.R_o            = R_o;
r.rad.R_wall         = R_wall;
r.rad.R_i            = R_i;
r.rad.U_overall_Wm2K = U_overall;
r.rad.LMTD_rad_K    = LMTD_rad;
r.rad.A_required_UA  = A_required_UA;
r.rad.T_tube_C       = T_tube_C;
r.rad.T_skin_max_C   = T_skin_max;
r.rad.T_skin_outside_C = T_skin_outside;
r.rad.v_salt_ms      = v_salt;
r.rad.mu_salt_Pas    = mu_salt_Pas;

% --- Convection zone ---
r.conv.Q_conv_W       = Q_convection;
r.conv.W_conv_m       = W_conv;
r.conv.n_tubes_per_row= n_tubes_per_row_conv;
r.conv.n_rows         = n_rows_conv;
r.conv.L_tube_conv_m  = L_tube_conv;
r.conv.L_tube_conv_total_m = L_tube_conv_total;
r.conv.A_conv_free_m2 = A_conv_free;
r.conv.G_conv         = G_convection;
r.conv.T_stack_F      = T_stack;
r.conv.T_stack_C      = (T_stack-32)*5/9;
r.conv.LMTD_conv_F    = LMTD_conv_F;
r.conv.LMTD_conv_K    = LMTD_conv_K;
r.conv.U_conv_Btu     = U_conv_Btu;
r.conv.U_convection_Wm2K = U_convection;
r.conv.U_check_Wm2K   = U_check_conv;
r.conv.A_convection_m2= A_convection;
r.conv.A_conv_per_row = A_conv_per_row;
r.conv.Re_salt_conv   = Re_salt_conv;
r.conv.Pr_salt_conv   = Pr_salt_conv;
r.conv.Nu_salt_conv   = Nu_salt_conv;
r.conv.h_i_conv_Wm2K  = h_i_conv;
r.conv.h_o_conv_Wm2K  = h_o_conv;
r.conv.R_o_conv       = R_o_conv;
r.conv.R_wall_conv    = R_wall_conv;
r.conv.R_i_conv       = R_i_conv;
r.conv.T_salt_rad_in_C= T_salt_rad_in_C;
r.conv.v_salt_conv_ms = v_salt_conv;
r.conv.mu_salt_conv   = mu_salt_conv_Pas;

% --- Pressure drop ---
r.dp.f_coil           = f_coil;
r.dp.DP_total_rad_Pa  = DP_total_rad;
r.dp.DP_total_rad_bar = DP_total_rad / 1e5;
r.dp.f_conv           = f_conv;
r.dp.DP_friction_conv_Pa = DP_friction_conv;
r.dp.DP_bends_conv_Pa = DP_bends_conv;
r.dp.DP_total_conv_Pa = DP_total_conv;
r.dp.DP_total_Pa      = DP_total;
r.dp.DP_total_bar     = DP_total / 1e5;
r.dp.K_bend           = K_bend;
r.dp.n_bends_conv     = n_bends_conv;

% --- Energy balance ---
r.energy.Q_total_check_W     = Q_total_check;
r.energy.Q_released_check_kW = Q_released_check;
r.energy.Q_shortfall_W       = Q_shortfall;
r.energy.m_gas_import_kgs    = m_gas_import;

% --- Status ---
r.status = status;

results = r;

% =====================================================================
%  Print summary if no output requested
% =====================================================================
if nargout == 0
    print_summary(r);
end

end  % heater_design


% =====================================================================
%  DEFAULT PARAMETERS
% =====================================================================
function p = default_params()
    % System targets
    p.Q_target      = 68.856;     % kW
    p.T_salt_in     = 586.80;     % C
    p.T_salt_out    = 620;        % C

    % Salt properties
    p.T_salt_melt   = 395.68;     % C
    p.T_salt_max    = 650;        % C
    p.Cp_salt       = 2300;       % J/kg/K
    p.rho_salt      = 2050;       % kg/m3
    p.k_salt        = 0.55;       % W/m/K
    p.R_gas         = 8.314;      % J/mol/K

    % Biogas
    p.xi_CH4        = 0.60;
    p.xi_CO2        = 0.40;
    p.m_gas_factory = 0.002125633;  % kg/s
    p.m_molar_CH4   = 16.04/1000;   % kg/mol
    p.m_molar_CO2   = 44.01/1000;   % kg/mol
    p.Q_mol_CH4     = 891;          % kJ/mol (HHV)

    % Bio-oil
    p.m_oil         = 0.003486039;  % kg/s
    p.rho_oil       = 1200;         % kg/m3
    p.HHV_oil       = 31030;        % kJ/kg
    p.LHV_oil       = 29360;        % kJ/kg
    p.nu_oil        = 60e-6;        % m2/s
    p.sigma_oil     = 30e-3;        % N/m
    p.w_C           = 0.6393;
    p.w_H           = 0.0761;
    p.w_O           = 0.2836;
    p.w_N           = 0.0010;
    p.n_H           = 1.43;
    p.n_O           = 0.332;
    p.n_N           = 0.0013;

    % Gas burner
    p.T_prior_gas   = 100 + 273.15;  % K
    p.p_prior_gas   = 30;            % mbar
    p.C_d_gas       = 0.9;
    p.a_o_gas       = 30;            % deg
    p.n_p_gas       = 15;
    p.d_p_gas       = 0.005;         % m

    % Oil burner (pressure-swirl atomiser)
    p.DP_oil        = 10e5;          % Pa
    p.D_0           = 0.0015;        % m
    p.D_p           = 0.0006;        % m
    p.D_s           = 0.003;         % m
    p.L_s           = 0.002;         % m
    p.L_0           = 0.001;         % m
    p.L_p           = 0.001;         % m
    p.rho_a         = 0.4;           % kg/m3
    p.n_p_oil       = 4;

    % Heater geometry — radiation tubes
    p.d_tube_OD_heat = 0.045;        % m
    p.d_tube_ID_heat = 0.035;        % m
    p.D_coil_heat    = 1;            % m
    p.p_coil_heat    = 0.060;        % m
    p.D_shell_heat   = 1.4;          % m

    % Convection tubes
    p.d_tube_OD_conv     = 0.022;    % m
    p.d_tube_ID_conv     = 0.014;    % m
    p.p_conv_horizontal  = 2.5*0.022;% m
    p.p_conv_vertical    = 2.5*0.022;% m
    p.W_conv_bend        = 0.005;    % m
    p.n_shield_rows      = 2;
    p.n_conv_parallel    = 4;

    % Tube & refractory material
    p.k_tube_heat  = 25;             % W/m/K
    p.t_refr_heat  = 0.15;           % m
    p.k_refr_heat  = 0.35;           % W/m/K

    % Performance targets
    p.z_excess     = 0.15;
    p.eta_heater   = 0.74;
    p.f_radiant    = 0.803;
    p.q_rad        = 10000;          % W/m2
end


% =====================================================================
%  WALAS CORRELATIONS (internal helper functions)
% =====================================================================
function ratio = F_Qg_ratio(T_F, z_ex)
    % Flue gas enthalpy ratio as function of T (deg F)
    t = T_F/1000 - 0.1;
    a = 0.22048 - 0.35027*z_ex + 0.92344*z_ex^2;
    b = 0.016086 + 0.29393*z_ex - 0.48139*z_ex^2;
    ratio = (a + b*t) * t;
end

function eg = F_emissivity(T_g_F, PL_val)
    % Gas emissivity (Walas Eq. 8)
    z = (T_g_F + 460)/1000;
    a = 0.47916 - 0.19847*z + 0.022569*z^2;
    b = 0.047029 + 0.0699*z  - 0.01528*z^2;
    c = 0.000803 - 0.00726*z + 0.001597*z^2;
    eg = a + b*PL_val + c*PL_val^2;
end

function F = F_exchange(phi, z9)
    % Exchange factor (Walas Eq. 9)
    a = 0.00064 + 0.0591*z9 + 0.00101*z9^2;
    b = 1.0256  + 0.4908*z9 - 0.058*z9^2;
    c = -0.144  - 0.552*z9  + 0.040*z9^2;
    F = a + b*phi + c*phi^2;
end


% =====================================================================
%  GAS PROPERTY HELPERS
% =====================================================================
function [rho, ok] = gas_density_coolprop(xi_CH4, xi_CO2, P, T)
    % Try CoolProp via Python; fall back to ideal gas
    ok = false;
    rho = 0;
    try
        % Build CoolProp mixture string
        fluid = sprintf('CH4[%f]&CO2[%f]', xi_CH4, xi_CO2);
        rho = py.CoolProp.CoolProp.PropsSI('D','P',P,'T',T, fluid);
        rho = double(rho);
        ok = true;
    catch
        % Ideal gas fallback
        M_mix = xi_CH4*0.01604 + xi_CO2*0.04401;
        rho = P * M_mix / (8.314 * T);
        ok = false;
    end
end

function [rho_t, mu_t] = throat_props(x_CH4, x_CO2, x_N2, x_O2, ...
                                       P, T, coolprop_ok, M_fuel, R, r_ent)
    if coolprop_ok
        try
            fluid = sprintf('CH4[%f]&CO2[%f]&Nitrogen[%f]&Oxygen[%f]', ...
                            x_CH4, x_CO2, x_N2, x_O2);
            rho_t = double(py.CoolProp.CoolProp.PropsSI('D','P',P,'T',T, fluid));
            mu_t  = double(py.CoolProp.CoolProp.PropsSI('V','P',P,'T',T, fluid));
            return
        catch
            % fall through to ideal gas
        end
    end
    % Ideal gas fallback
    M_mix = x_CH4*0.01604 + x_CO2*0.04401 + x_N2*0.02802 + x_O2*0.032;
    rho_t = P * M_mix / (R * T);
    % Viscosity estimate using Sutherland-type for air-like mixture
    mu_t  = 1.7e-5 * (T/300)^0.7;   % approximate
end


% =====================================================================
%  SUMMARY PRINTER
% =====================================================================
function print_summary(r)
    fprintf('\n');
    fprintf('================================================================\n');
    fprintf('     COMBINED BURNER HEATING SYSTEM — KEY OVERVIEW\n');
    fprintf('================================================================\n');

    fprintf('\n--- System Targets ---\n');
    fprintf('  Heat duty to salt:         %.1f kW\n', r.Q_target_kW);
    fprintf('  Salt temperature range:    %.0f C  -->  %.0f C\n', ...
            r.params.T_salt_in, r.params.T_salt_out);
    fprintf('  Salt mass flow rate:       %.4f kg/s\n', r.m_salt_kgs);
    fprintf('  Required heat release:     %.1f kW  (eta = %.0f%%)\n', ...
            r.Q_released_W/1000, r.eta_heater*100);

    fprintf('\n--- Energy Supply ---\n');
    fprintf('  Gas burner (HHV):          %.2f kW\n', r.gas.Q_comb_gas_kW);
    fprintf('  Oil burner (LHV):          %.2f kW\n', r.oil.Q_comb_oil_kW);
    fprintf('  Total fuel available:      %.2f kW\n', ...
            r.gas.Q_comb_gas_kW + r.oil.Q_comb_oil_kW);
    fprintf('  Energy shortfall:          %.2f W\n', r.energy.Q_shortfall_W);
    fprintf('  Import gas required:       %.6f kg/s\n', r.energy.m_gas_import_kgs);

    fprintf('\n--- Heat Distribution ---\n');
    fprintf('  f_radiant (assumed):       %.3f\n', r.f_radiant_assumed);
    fprintf('  f_radiant (calc):          %.3f\n', r.f_radiant_calc);
    fprintf('  Radiant absorption:        %.2f kW\n', r.rad.Q_R_final_W/1000);
    fprintf('  Convection absorption:     %.2f kW\n', r.conv.Q_conv_W/1000);
    fprintf('  Total absorbed:            %.2f kW\n', ...
            (r.rad.Q_R_final_W + r.conv.Q_conv_W)/1000);

    fprintf('\n--- Radiant Zone ---\n');
    fprintf('  Converged T_g:             %.1f C\n', r.rad.T_g_C);
    fprintf('  Radiant flux (actual):     %.0f W/m2\n', r.rad.q_rad_check_Wm2);
    fprintf('  Coil turns:                %d\n', r.rad.N_turns_int);
    fprintf('  Coil height:               %.3f m\n', r.rad.H_coil_m);
    fprintf('  Tube length (rad):         %.2f m\n', r.rad.L_tube_rad_m);
    fprintf('  T_skin_max:                %.1f C  (limit %.0f C)\n', ...
            r.rad.T_skin_max_C, r.params.T_salt_max);

    fprintf('\n--- Convection Zone ---\n');
    fprintf('  T_stack:                   %.1f C\n', r.conv.T_stack_C);
    fprintf('  Rows:                      %d\n', r.conv.n_rows);
    fprintf('  U_convection:              %.1f W/m2/K\n', r.conv.U_convection_Wm2K);

    fprintf('\n--- Pressure Drop ---\n');
    fprintf('  Radiant:                   %.0f Pa  (%.2f bar)\n', ...
            r.dp.DP_total_rad_Pa, r.dp.DP_total_rad_bar);
    fprintf('  Convection:                %.0f Pa\n', r.dp.DP_total_conv_Pa);
    fprintf('  Total:                     %.0f Pa  (%.2f bar)\n', ...
            r.dp.DP_total_Pa, r.dp.DP_total_bar);

    fprintf('\n--- Gas Burner ---\n');
    fprintf('  Orifice diameter:          %.4f mm\n', r.gas.d_o_m*1000);
    fprintf('  Throat diameter:           %.4f mm\n', r.gas.d_t_m*1000);
    fprintf('  Prigg ratio (Ap/At):       %.2f\n', r.gas.Prigg_ratio);
    fprintf('  Throat dP:                 %.2f Pa  (supply %.0f Pa)\n', ...
            r.gas.DP_t_Pa, r.params.p_prior_gas*100);

    fprintf('\n--- Oil Burner ---\n');
    fprintf('  Cd:                        %.4f\n', r.oil.Cd_oil);
    fprintf('  Spray angle (full):        %.2f deg\n', r.oil.spray_angle_full);
    fprintf('  SMD (corrected):           %.1f um\n', r.oil.SMD_corrected_um);
    fprintf('  K = Ap/(Ds*D0):            %.4f\n', r.oil.K_oil);

    fprintf('\n--- Status Flags ---\n');
    flags = fieldnames(r.status);
    for k = 1:numel(flags)
        if strcmp(flags{k}, 'all_pass'), continue; end
        if r.status.(flags{k})
            fprintf('  [%d] %-22s PASS\n', k, flags{k});
        else
            fprintf('  [%d] %-22s *** FAIL ***\n', k, flags{k});
        end
    end
    if r.status.all_pass
        fprintf('\n  >> ALL CHECKS PASSED <<\n');
    else
        fprintf('\n  >> SOME CHECKS FAILED — review above <<\n');
    end
    fprintf('================================================================\n\n');
end
