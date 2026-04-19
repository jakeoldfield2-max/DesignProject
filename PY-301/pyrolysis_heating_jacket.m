function results = pyrolysis_heating_jacket(params)
% PYROLYSIS_HEATING_JACKET  Design calculation for pyrolizer heating jacket.
%
%   results = pyrolysis_heating_jacket(params)
%
%   The heating jacket is modelled as concurrent axial channels around the
%   pyrolizer shell.  Two zones are considered:
%       Section 1 (L1) – heating zone:  wall rises from T_cold_in to T_cold_out
%       Section 2 (L2) – constant-temp zone:  wall held at T_cold_out
%
%   Heat-transfer coefficients use the Sieder-Tate (laminar entry) correlation
%   (Fundamentals of Heat and Mass Transfer, p 491).
%
% ---- INPUT ----
%   params : struct with the following fields (defaults shown in brackets):
%
%   Geometry
%       D_pyrolizer  [0.318]   m   pyrolizer OD
%       D_jacket     [0.358]   m   jacket ID
%       L1           [2.05]    m   heating-zone length
%       L2           [2.57]    m   constant-temp-zone length
%       N_ch         [10]      -   number of axial channels
%       t_fin        [0.005]   m   fin / wall thickness between channels
%
%   Process
%       T_hot1_C     [611.72]  degC   salt inlet temperature
%       m_dot        [0.7609]  kg/s   salt mass flow rate
%       Q1           [23550]   W      heat duty, heating zone
%       Q2           [20070]   W      heat duty, constant-temp zone
%       T_cold_in_C  [280]     degC   wall temperature at biomass inlet
%       T_cold_out_C [550]     degC   wall temperature at end of L1 / all of L2
%
%   Salt properties (ternary eutectic)
%       rho          [2050]    kg/m3  density
%       Cp           [2300]    J/kg/K specific heat capacity
%       k_fluid      [0.55]    W/m/K  thermal conductivity
%       mu_A         [0.0852]  -      viscosity pre-exponential (Pa.s)
%       mu_Ea        [3.51e4]  J/mol  viscosity activation energy
%
% ---- OUTPUT ----
%   results : struct containing all computed design quantities
%
% Example
%   res = pyrolysis_heating_jacket();          % run with all defaults
%   res = pyrolysis_heating_jacket(struct('N_ch',12,'L2',3.0));

    %% ---------- defaults ----------
    d = struct( ...
        'D_pyrolizer', 0.318, ...
        'D_jacket',    0.358, ...
        'L1',          2.05, ...
        'L2',          2.57, ...
        'N_ch',        10, ...
        't_fin',       0.005, ...
        'T_hot1_C',    611.7223193, ...
        'm_dot',       0.7609, ...
        'Q1',          23550, ...
        'Q2',          20070, ...
        'T_cold_in_C', 280, ...
        'T_cold_out_C',550, ...
        'rho',         2050, ...
        'Cp',          2300, ...
        'k_fluid',     0.55, ...
        'mu_A',        0.0852, ...
        'mu_Ea',       3.51e4);

    if nargin == 0
        params = struct();
    end

    % Merge user params over defaults
    fnames = fieldnames(d);
    for i = 1:numel(fnames)
        if ~isfield(params, fnames{i})
            params.(fnames{i}) = d.(fnames{i});
        end
    end

    %% ---------- unpack ----------
    R_gas = 8.314;  % J/(mol.K)

    D_pyr   = params.D_pyrolizer;
    D_jkt   = params.D_jacket;
    L1      = params.L1;
    L2      = params.L2;
    N_ch    = params.N_ch;
    t_fin   = params.t_fin;

    T_hot1  = params.T_hot1_C + 273.15;   % K
    m_dot   = params.m_dot;
    Q1      = params.Q1;
    Q2      = params.Q2;
    T_cold_in  = params.T_cold_in_C  + 273.15;  % K
    T_cold_out = params.T_cold_out_C + 273.15;  % K

    rho     = params.rho;
    Cp      = params.Cp;
    k_f     = params.k_fluid;
    mu_A    = params.mu_A;
    mu_Ea   = params.mu_Ea;

    % Viscosity function  mu(T) = A * exp(Ea / (R*T))   [Pa.s]
    mu = @(T_K) mu_A .* exp(mu_Ea ./ (R_gas .* T_K));

    %% ---------- temperature profile (linear assumption) ----------
    T_hot_mid = T_hot1  - Q1 / (m_dot * Cp);   % salt leaving Section 1
    T_hot2    = T_hot_mid - Q2 / (m_dot * Cp);  % salt leaving Section 2

    T_hot_avg1 = (T_hot1 + T_hot_mid) / 2;
    T_hot_avg2 = (T_hot_mid + T_hot2) / 2;

    %% ---------- channel geometry ----------
    w_ch  = (pi * D_pyr / N_ch) - t_fin;   % circumferential width per channel
    GAP   = (D_jkt - D_pyr) / 2;           % radial height
    A_c   = w_ch * GAP;                    % flow area per channel
    D_h   = 2 * w_ch * GAP / (w_ch + GAP); % hydraulic diameter
    v     = m_dot / (rho * N_ch * A_c);    % velocity per channel

    %% ---------- heat transfer – Sieder-Tate (laminar entry) ----------
    % Section 1
    Re1  = rho * v * D_h / mu(T_hot_avg1);
    Pr1  = Cp * mu(T_hot_avg1) / k_f;
    Gz1  = Re1 * Pr1 * D_h / L1;
    Nu1  = 1.86 * Gz1^(1/3) * (mu(T_hot_avg1) / mu(T_cold_out))^0.14;
    h1   = Nu1 * k_f / D_h;

    % Section 2
    Re2  = rho * v * D_h / mu(T_hot_avg2);
    Pr2  = Cp * mu(T_hot_avg2) / k_f;
    Gz2  = Re2 * Pr2 * D_h / L2;
    Nu2  = 1.86 * Gz2^(1/3) * (mu(T_hot_avg2) / mu(T_cold_out))^0.14;
    h2   = Nu2 * k_f / D_h;

    %% ---------- LMTD ----------
    % Section 1: co-current, wall heated from T_cold_in to T_cold_out
    dT1_in  = T_hot1    - T_cold_in;
    dT1_out = T_hot_mid - T_cold_out;
    LMTD1   = (dT1_in - dT1_out) / log(dT1_in / dT1_out);

    % Section 2: wall constant at T_cold_out
    dT2_in  = T_hot_mid - T_cold_out;
    dT2_out = T_hot2    - T_cold_out;
    LMTD2   = (dT2_in - dT2_out) / log(dT2_in / dT2_out);

    %% ---------- area check ----------
    A_req1 = Q1 / (h1 * LMTD1);
    A_av1  = pi * D_pyr * L1;

    A_req2 = Q2 / (h2 * LMTD2);
    A_av2  = pi * D_pyr * L2;

    design_ok = (A_av1 >= A_req1) && (A_av2 >= A_req2);

    %% ---------- pressure drop (laminar, straight duct) ----------
    f1 = 16 / Re1;   % Fanning friction factor
    DP1 = 4 * f1 * (L1 / D_h) * (rho * v^2 / 2);

    f2 = 16 / Re2;
    DP2 = 4 * f2 * (L2 / D_h) * (rho * v^2 / 2);

    DP_total = DP1 + DP2;

    %% ---------- pack results ----------
    results = struct();

    % Temperatures (degC)
    results.T_salt_in_C    = T_hot1    - 273.15;
    results.T_salt_mid_C   = T_hot_mid - 273.15;
    results.T_salt_out_C   = T_hot2    - 273.15;
    results.T_wall_in_C    = T_cold_in - 273.15;
    results.T_wall_out_C   = T_cold_out- 273.15;

    % Channel geometry
    results.w_ch    = w_ch;
    results.GAP     = GAP;
    results.A_c     = A_c;
    results.D_h     = D_h;
    results.v       = v;

    % Section 1
    results.Re1     = Re1;
    results.Pr1     = Pr1;
    results.Gz1     = Gz1;
    results.Nu1     = Nu1;
    results.h1      = h1;
    results.LMTD1   = LMTD1;
    results.A_req1  = A_req1;
    results.A_av1   = A_av1;

    % Section 2
    results.Re2     = Re2;
    results.Pr2     = Pr2;
    results.Gz2     = Gz2;
    results.Nu2     = Nu2;
    results.h2      = h2;
    results.LMTD2   = LMTD2;
    results.A_req2  = A_req2;
    results.A_av2   = A_av2;

    % Pressure drop
    results.f1       = f1;
    results.f2       = f2;
    results.DP1_kPa  = DP1 / 1000;
    results.DP2_kPa  = DP2 / 1000;
    results.DP_total_kPa = DP_total / 1000;

    % Overall verdict
    results.design_ok = design_ok;

    %% ---------- print summary ----------
    fprintf('\n====== Pyrolizer Heating Jacket Design ======\n');
    if design_ok
        fprintf('  *** DESIGN SUCCESSFUL ***\n');
    else
        fprintf('  *** DESIGN FAILED ***\n');
    end

    fprintf('\nSection 1 (Heating Zone, L1 = %.2f m):\n', L1);
    fprintf('  Re     = %.4f\n', Re1);
    fprintf('  Pr     = %.2f\n', Pr1);
    fprintf('  Nu     = %.4f\n', Nu1);
    fprintf('  h      = %.2f W/(m2.K)\n', h1);
    fprintf('  T_salt_in  = %.2f C\n', T_hot1 - 273.15);
    fprintf('  T_salt_out = %.2f C\n', T_hot_mid - 273.15);
    fprintf('  T_wall_in  = %.2f C\n', T_cold_in - 273.15);
    fprintf('  T_wall_out = %.2f C\n', T_cold_out - 273.15);
    fprintf('  LMTD   = %.2f K\n', LMTD1);
    fprintf('  A_req  = %.4f m2,  A_av = %.4f m2\n', A_req1, A_av1);

    fprintf('\nSection 2 (Constant Temp Zone, L2 = %.2f m):\n', L2);
    fprintf('  Re     = %.4f\n', Re2);
    fprintf('  Pr     = %.2f\n', Pr2);
    fprintf('  Nu     = %.4f\n', Nu2);
    fprintf('  h      = %.2f W/(m2.K)\n', h2);
    fprintf('  T_salt_in  = %.2f C\n', T_hot_mid - 273.15);
    fprintf('  T_salt_out = %.2f C\n', T_hot2 - 273.15);
    fprintf('  T_wall     = %.2f C\n', T_cold_out - 273.15);
    fprintf('  LMTD   = %.2f K\n', LMTD2);
    fprintf('  A_req  = %.4f m2,  A_av = %.4f m2\n', A_req2, A_av2);

    fprintf('\nFlow:\n');
    fprintf('  v        = %.4f m/s\n', v);
    fprintf('  DP_total = %.2f kPa\n', DP_total / 1000);
    fprintf('==============================================\n\n');
end
