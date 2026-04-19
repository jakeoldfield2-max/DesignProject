function results = air_heater(params)
% AIR_HEATER  Fin-and-tube air heat exchanger design calculation.
%
%   results = air_heater(params)
%
%   Heats air (shell side) using a hot transfer fluid (tube side, e.g.
%   Helisol 5A) through a finned-tube bundle in a baffled shell.
%
%   INPUT  -  params: struct with fields listed below.  Any field left
%             unset takes its default value.
%
%   ── Process conditions ──────────────────────────────────────────────
%     m_cold    [kg/s]   Air mass flow rate              (0.0570722222)
%     T_cold1   [°C]     Ambient / air inlet temperature (20)
%     T_cold2   [°C]     Target air outlet temperature   (280)
%     m_hot     [kg/s]   Hot-fluid mass flow rate        (0.25)
%     T_hot1    [°C]     Hot-fluid inlet temperature     (330)
%     c_hot     [J/kg/K] Hot-fluid isobaric heat cap.    (2150)
%     c_cold    [J/kg/K] Air isobaric heat capacity      (1014)
%
%   ── Hot-fluid (tube-side) properties ────────────────────────────────
%     rho_t     [kg/m³]  Density                         (689.5)
%     mu_t      [Pa·s]   Dynamic viscosity               (0.41e-3)
%     k_t       [W/m/K]  Thermal conductivity            (0.076)
%     C_pt      [J/kg/K] Heat capacity (same as c_hot)   (2150)
%
%   ── Air (shell-side) properties ─────────────────────────────────────
%     rho_s     [kg/m³]  Density (at avg temp)           (0.835)
%     mu_s      [Pa·s]   Dynamic viscosity               (2.38e-5)
%     k_s       [W/m/K]  Thermal conductivity            (0.0354)
%     C_ps      [J/kg/K] Heat capacity                   (1014)
%
%   ── Tube geometry ───────────────────────────────────────────────────
%     L_tube    [m]      Tube length                     (2.0)
%     D_int     [m]      Tube internal diameter           (0.010)
%     D_ext     [m]      Tube external diameter           (0.014)
%
%   ── Helical fin geometry ────────────────────────────────────────────
%     l_f       [m]      Fin height                      (0.008)
%     t_f       [m]      Fin thickness                   (0.0005)
%     p_f       [m]      Fin pitch                       (0.003)
%
%   ── Layout & shell ──────────────────────────────────────────────────
%     N_p       [-]      Number of tube passes           (4)
%     psi_n     [-]      Tube count fraction (layout)    (0.17)
%     C_1       [-]      Triangular layout constant      (0.866)
%     L_bb      [m]      Baffle bypass clearance         (0.0127)
%     BaffleCut [-]      Baffle cut fraction             (0.25)
%     LB_mult   [-]      Baffle spacing = LB_mult * D_s  (3.0)
%
%   ── Material conductivities ─────────────────────────────────────────
%     k_tube    [W/m/K]  Tube wall conductivity          (50)
%     k_fin     [W/m/K]  Fin conductivity                (205)
%
%   ── Fouling resistances ─────────────────────────────────────────────
%     Rf_o      [m²·K/W] Outside fouling                 (0.0002)
%     Rf_i      [m²·K/W] Inside fouling                  (0.0003)
%
%   ── Initial estimates ───────────────────────────────────────────────
%     U_o_ass   [W/m²/K] Assumed overall HTC             (5.85)
%     F         [-]      LMTD correction factor           (0.95)
%
%   OUTPUT -  results: struct with calculated design quantities.
%
%   Example:
%       p = struct();                 % use all defaults
%       r = air_heater(p);
%       fprintf('U_calc = %.2f W/m2/K\n', r.U_o_calc);
%
%       p.m_hot = 0.30;              % increase hot-fluid flow
%       p.T_cold2 = 300;             % hotter air target
%       r = air_heater(p);

    %% ================================================================
    %  1.  SET DEFAULTS & UNPACK
    %  ================================================================
    d = default_params();
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(params, f{i}) || isempty(params.(f{i}))
            params.(f{i}) = d.(f{i});
        end
    end
    p = params;  % shorthand

    %% ================================================================
    %  2.  HEAT DUTY & TEMPERATURE CALCULATIONS
    %  ================================================================
    % Convert temperatures to Kelvin
    T_cold1_K = p.T_cold1 + 273.15;
    T_cold2_K = p.T_cold2 + 273.15;
    T_hot1_K  = p.T_hot1  + 273.15;

    Q = p.m_cold * p.c_cold * (T_cold2_K - T_cold1_K);       % [W]
    T_hot2_K = T_hot1_K - Q / (p.m_hot * p.c_hot);            % [K]

    R_ratio = (T_hot1_K - T_hot2_K) / (T_cold2_K - T_cold1_K);
    S_ratio = (T_cold2_K - T_cold1_K) / (T_hot1_K - T_cold1_K);

    DeltaT_LM = ((T_hot2_K - T_cold1_K) - (T_hot1_K - T_cold2_K)) ...
              / log((T_hot2_K - T_cold1_K) / (T_hot1_K - T_cold2_K));

    A_req = Q / (p.F * p.U_o_ass * DeltaT_LM);                % [m²]

    %% ================================================================
    %  3.  FIN & TUBE GEOMETRY  (per tube)
    %  ================================================================
    r_f1  = p.D_ext / 2;
    l_fc  = p.l_f + p.t_f / 2;          % corrected fin height
    r_f2c = r_f1 + l_fc;

    A_f_single = 2 * pi * (r_f2c^2 - r_f1^2);         % one fin area
    N_fin      = p.L_tube / p.p_f;                     % fins per tube
    A_b        = pi * p.D_ext * (p.L_tube - N_fin * p.t_f);  % bare area
    A_o_one    = A_f_single * N_fin + A_b;             % total outside / tube

    N_tt = A_req / A_o_one;                             % number of tubes

    %% ================================================================
    %  4.  SHELL LAYOUT
    %  ================================================================
    L_tp  = 1.25 * (p.D_ext + 2 * p.l_f);              % tube pitch (TEMA min)
    D_ctl = L_tp * sqrt(4 * p.C_1 * N_tt / pi / (1 - p.psi_n));
    D_s   = D_ctl + p.L_bb + p.D_ext;                  % shell diameter
    L_B   = p.LB_mult * D_s;                           % baffle spacing

    P_v   = L_tp * cos(pi/6);
    N_r   = D_ctl / P_v;
    N_tcc = (1 - p.BaffleCut) * N_r;

    T_coldAvg = (T_cold1_K + T_cold2_K) / 2;

    %% ================================================================
    %  5.  TUBE-SIDE HEAT TRANSFER  (Dittus–Boelter)
    %  ================================================================
    N_per_pass = N_tt / p.N_p;
    A_internal = (pi/4) * p.D_int^2;
    A_t        = N_per_pass * A_internal;

    v_t   = p.m_hot / (p.rho_t * A_t);
    Re_t  = p.rho_t * v_t * p.D_int / p.mu_t;
    Pr_t  = p.C_pt * p.mu_t / p.k_t;
    Nu_t  = 0.023 * Re_t^0.8 * Pr_t^0.3;       % cooling exponent 0.3
    h_i   = Nu_t * p.k_t / p.D_int;

    %% ================================================================
    %  6.  SHELL-SIDE HEAT TRANSFER  (finned-tube correlation)
    %  ================================================================
    Q_air  = p.m_cold / p.rho_s;                        % volumetric flow
    A_face = p.L_tube * (D_ctl + p.D_ext);
    u_f    = Q_air / A_face;
    u_max  = u_f * L_tp / (L_tp - p.D_ext);

    Pr_s = p.C_ps * p.mu_s / p.k_s;
    Re_s_ht = p.rho_s * u_max * p.D_ext / p.mu_s;      % for HT correlation
    Nu_s = 0.134 * Re_s_ht^0.681 * Pr_s^0.33 ...
         * ((p.p_f - p.t_f) / p.l_f)^0.2 ...
         * (p.p_f / p.t_f)^0.1134;
    h_s  = Nu_s * p.k_s / p.D_ext;

    %% ================================================================
    %  7.  FIN EFFICIENCY & OVERALL SURFACE EFFICIENCY
    %  ================================================================
    m_fin  = sqrt(2 * h_s / (p.k_fin * p.t_f));
    eta_f  = tanh(m_fin * p.l_f) / (m_fin * p.l_f);

    A_f_total = N_fin * A_f_single * N_tt;
    A_b_total = A_b * N_tt;
    A_o       = A_f_total + A_b_total;                  % total outside area
    A_i       = pi * p.D_int * p.L_tube * N_tt;         % total inside area

    eta_o = (eta_f * A_f_total + A_b_total) / A_o;

    %% ================================================================
    %  8.  THERMAL RESISTANCES & OVERALL HTC
    %  ================================================================
    R_shell_conv = 1 / (eta_o * h_s);
    R_tube_conv  = 1 / (h_i * (A_i / A_o));
    R_wall_cond  = p.D_ext * log(p.D_ext / p.D_int) / (2 * p.k_tube);
    R_fouling    = p.Rf_i * (A_o / A_i) + p.Rf_o / eta_o;

    R_total  = R_shell_conv + R_tube_conv + R_wall_cond + R_fouling;
    U_o_calc = 1 / R_total;

    %% ================================================================
    %  9.  TUBE-SIDE PRESSURE DROP
    %  ================================================================
    f_t       = 0.0035 + 0.264 / Re_t^0.42;
    L_total   = p.L_tube * p.N_p;
    K_loss    = 1.8 * p.N_p;
    DP_t_fric = 4 * f_t * (L_total / p.D_int) * (p.rho_t * v_t^2 / 2);
    DP_t_ret  = K_loss * (p.rho_t * v_t^2) / 2;
    DP_t      = DP_t_fric + DP_t_ret;

    %% ================================================================
    %  10. SHELL-SIDE PRESSURE DROP  (Robinson & Briggs)
    %  ================================================================
    A_s_flow = (L_tp - p.D_ext) * D_s * L_B / L_tp;
    G_s      = p.m_hot / A_s_flow;
    u_s      = G_s / p.rho_s;
    d_e      = 1.10 / p.D_ext * (L_tp^2 - 0.917 * p.D_ext^2);
    Re_s_dp  = G_s * d_e / p.mu_s;

    f_s   = 9.465 * Re_s_dp^(-0.316) ...
          * (L_tp / (p.D_ext + 2 * p.l_f))^(-0.927);
    DP_s  = N_r * f_s * (p.rho_s * u_max^2 / 2);

    %% ================================================================
    %  11. PACK RESULTS
    %  ================================================================
    results.Q          = Q;              % Heat duty [W]
    results.T_hot2     = T_hot2_K - 273.15;  % Hot outlet [°C]
    results.T_cold2    = p.T_cold2;          % Air outlet [°C]
    results.R          = R_ratio;
    results.S          = S_ratio;
    results.DeltaT_LM  = DeltaT_LM;     % Log-mean ΔT [K]
    results.A_req      = A_req;          % Required area [m²]

    results.N_tt       = N_tt;           % Number of tubes
    results.N_fin      = N_fin;          % Fins per tube
    results.D_ctl      = D_ctl;          % Tube bundle diameter [m]
    results.D_s        = D_s;            % Shell diameter [m]
    results.L_B        = L_B;            % Baffle spacing [m]
    results.L_tp       = L_tp;           % Tube pitch [m]
    results.N_r        = N_r;            % Number of tube rows
    results.N_tcc      = N_tcc;          % Tubes in cross-flow

    results.Re_t       = Re_t;           % Tube-side Reynolds
    results.Pr_t       = Pr_t;           % Tube-side Prandtl
    results.Nu_t       = Nu_t;           % Tube-side Nusselt
    results.h_i        = h_i;            % Inside HTC [W/m²/K]
    results.v_t        = v_t;            % Tube velocity [m/s]

    results.Re_s       = Re_s_ht;        % Shell-side Reynolds (HT)
    results.Pr_s       = Pr_s;           % Shell-side Prandtl
    results.Nu_s       = Nu_s;           % Shell-side Nusselt
    results.h_s        = h_s;            % Outside HTC [W/m²/K]
    results.u_max      = u_max;          % Max shell velocity [m/s]

    results.eta_f      = eta_f;          % Fin efficiency
    results.eta_o      = eta_o;          % Overall surface efficiency

    results.R_shell    = R_shell_conv;   % Shell convection resistance
    results.R_tube     = R_tube_conv;    % Tube convection resistance
    results.R_wall     = R_wall_cond;    % Wall conduction resistance
    results.R_fouling  = R_fouling;      % Fouling resistance
    results.R_total    = R_total;        % Total resistance
    results.U_o_calc   = U_o_calc;       % Calculated overall HTC [W/m²/K]
    results.U_o_ass    = p.U_o_ass;      % Assumed overall HTC [W/m²/K]

    results.DP_t       = DP_t;           % Tube-side ΔP [Pa]
    results.DP_s       = DP_s;           % Shell-side ΔP [Pa]

    results.A_o        = A_o;            % Total outside area [m²]
    results.A_i        = A_i;            % Total inside area [m²]

    %% ================================================================
    %  12. PRINT SUMMARY
    %  ================================================================
    fprintf('\n============ AIR HEATER DESIGN SUMMARY ============\n');
    fprintf('Heat duty                Q    = %.1f W  (%.2f kW)\n', Q, Q/1e3);
    fprintf('Hot fluid outlet         T_h2 = %.1f °C\n', results.T_hot2);
    fprintf('Air outlet               T_c2 = %.1f °C\n', results.T_cold2);
    fprintf('LMTD                          = %.2f K\n', DeltaT_LM);
    fprintf('R = %.4f    S = %.4f\n', R_ratio, S_ratio);
    fprintf('\n--- Geometry ---\n');
    fprintf('Required area            A    = %.2f m²\n', A_req);
    fprintf('Number of tubes          N_tt = %.1f\n', N_tt);
    fprintf('Shell diameter           D_s  = %.4f m  (%.1f mm)\n', D_s, D_s*1e3);
    fprintf('Baffle spacing           L_B  = %.4f m\n', L_B);
    fprintf('Tube pitch               L_tp = %.5f m\n', L_tp);
    fprintf('\n--- Tube side (hot fluid) ---\n');
    fprintf('Re_t = %.1f    Pr_t = %.2f\n', Re_t, Pr_t);
    fprintf('h_i  = %.2f W/m²/K\n', h_i);
    fprintf('ΔP_t = %.1f Pa  (%.3f kPa)\n', DP_t, DP_t/1e3);
    fprintf('\n--- Shell side (air) ---\n');
    fprintf('Re_s = %.1f    Pr_s = %.4f\n', Re_s_ht, Pr_s);
    fprintf('h_s  = %.4f W/m²/K\n', h_s);
    fprintf('ΔP_s = %.4f Pa\n', DP_s);
    fprintf('\n--- Overall ---\n');
    fprintf('Fin efficiency           η_f  = %.4f\n', eta_f);
    fprintf('Surface efficiency       η_o  = %.4f\n', eta_o);
    fprintf('U_calc = %.4f W/m²/K\n', U_o_calc);
    fprintf('U_assumed = %.4f W/m²/K\n', p.U_o_ass);
    fprintf('Ratio  U_calc / U_ass = %.3f\n', U_o_calc / p.U_o_ass);
    fprintf('====================================================\n\n');
end

%% ====================================================================
%  DEFAULT PARAMETER STRUCT
%  ====================================================================
function d = default_params()
    % Process
    d.m_cold   = 0.0570722222;   % kg/s
    d.T_cold1  = 20;             % °C
    d.T_cold2  = 280;            % °C
    d.m_hot    = 0.25;           % kg/s
    d.T_hot1   = 330;            % °C
    d.c_hot    = 2150;           % J/kg/K
    d.c_cold   = 1014;           % J/kg/K

    % Tube-side fluid (Helisol 5A)
    d.rho_t    = 689.5;          % kg/m³
    d.mu_t     = 0.41e-3;        % Pa·s
    d.k_t      = 0.076;          % W/m/K
    d.C_pt     = 2150;           % J/kg/K

    % Shell-side fluid (air at ~280 °C avg)
    d.rho_s    = 0.835;          % kg/m³
    d.mu_s     = 2.38e-5;        % Pa·s
    d.k_s      = 0.0354;         % W/m/K
    d.C_ps     = 1014;           % J/kg/K

    % Tube geometry
    d.L_tube   = 2.0;            % m
    d.D_int    = 0.010;          % m
    d.D_ext    = 0.014;          % m

    % Helical fin geometry
    d.l_f      = 0.008;          % m
    d.t_f      = 0.0005;         % m
    d.p_f      = 0.003;          % m

    % Layout
    d.N_p      = 4;              % tube passes
    d.psi_n    = 0.17;
    d.C_1      = 0.866;          % triangular layout
    d.L_bb     = 0.0127;         % m  baffle bypass clearance
    d.BaffleCut = 0.25;
    d.LB_mult  = 3.0;            % L_B = LB_mult * D_s

    % Material
    d.k_tube   = 50;             % W/m/K
    d.k_fin    = 205;            % W/m/K

    % Fouling
    d.Rf_o     = 0.0002;         % m²·K/W
    d.Rf_i     = 0.0003;         % m²·K/W

    % Estimates
    d.U_o_ass  = 5.85;           % W/m²/K
    d.F        = 0.95;           % LMTD correction factor
end
