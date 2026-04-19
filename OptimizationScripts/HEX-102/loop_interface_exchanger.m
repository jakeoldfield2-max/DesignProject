function results = loop_interface_exchanger(params)
% LOOP_INTERFACE_EXCHANGER  Shell-and-tube heat exchanger design
%   for heating Helisol 5A (shell side) using ternary eutectic mixture (tube side).
%
%   results = loop_interface_exchanger(params)
%
%   INPUTS (struct fields) — all temperatures in °C, all units SI:
%
%     Flow conditions:
%       params.m_cold    - Cold fluid mass flow rate [kg/s]       (default: 0.25)
%       params.m_hot     - Hot fluid mass flow rate  [kg/s]       (default: 0.7609)
%       params.T_cold1   - Cold fluid inlet temp     [°C]         (default: 283.0483)
%       params.T_cold2   - Cold fluid outlet temp    [°C]         (default: 310)
%       params.T_hot1    - Hot fluid inlet temp      [°C]         (default: 620)
%       params.c_hot     - Hot fluid specific heat   [J/kg/K]     (default: 2300)
%       params.c_cold    - Cold fluid specific heat  [J/kg/K]     (default: 2150)
%
%     Tube-side (hot) fluid properties:
%       params.rho_t     - Density                   [kg/m3]      (default: 2050)
%       params.k_t       - Thermal conductivity      [W/m/K]      (default: 0.55)
%       params.C_pt      - Specific heat capacity    [J/kg/K]     (default: 2300)
%       params.mu_t_A    - Viscosity pre-exp factor  [Pa·s/1000]  (default: 0.0852)
%       params.mu_t_Ea   - Viscosity activation E    [J/mol]      (default: 3.51e4)
%
%     Shell-side (cold) fluid properties:
%       params.rho_s     - Density                   [kg/m3]      (default: 689.5)
%       params.mu_s      - Dynamic viscosity         [Pa·s]       (default: 0.41e-3)
%       params.k_s       - Thermal conductivity      [W/m/K]      (default: 0.076)
%       params.C_ps      - Specific heat capacity    [J/kg/K]     (default: 2150)
%
%     Geometry:
%       params.L_tube    - Tube length               [m]          (default: 1.0)
%       params.D_int     - Tube internal diameter    [m]          (default: 0.020)
%       params.D_ext     - Tube external diameter    [m]          (default: 0.024)
%       params.N_p       - Number of tube passes     [-]          (default: 2)
%       params.pitch_ratio - L_tp / D_ext ratio      [-]          (default: 1.25)
%
%     Layout & baffles:
%       params.psi_n     - Tube count correction     [-]          (default: 0.17)
%       params.C_1       - Layout constant (triangular 30°)       (default: 0.866)
%       params.L_bb      - Baffle bypass clearance   [m]          (default: 0.0127)
%       params.baffle_spacing_ratio - L_B / D_s      [-]          (default: 0.5)
%       params.baffle_cut - Baffle cut fraction       [-]          (default: 0.25)
%
%     Thermal resistances:
%       params.k_tube    - Tube wall conductivity    [W/m/K]      (default: 50)
%       params.Rf_o      - Outside fouling resistance[m2·K/W]     (default: 0.0002)
%       params.Rf_i      - Inside fouling resistance [m2·K/W]     (default: 0.0003)
%
%     Design estimates:
%       params.F         - LMTD correction factor    [-]          (default: 0.95)
%       params.U_o_ass   - Assumed overall U         [W/m2/K]     (default: 68)
%
%   OUTPUTS (struct):
%     results.Q_kW           - Heat duty [kW]
%     results.T_hot2_C       - Hot fluid outlet temperature [°C]
%     results.LMTD           - Log-mean temperature difference [K]
%     results.R              - Temperature ratio R [-]
%     results.S              - Temperature ratio S [-]
%     results.A_req          - Required heat transfer area [m2]
%     results.N_tt           - Total number of tubes [-]
%     results.D_ctl          - Tube bundle diameter [m]
%     results.D_s            - Shell diameter [m]
%     results.L_B            - Baffle spacing [m]
%     results.Re_t           - Tube-side Reynolds number
%     results.Re_s           - Shell-side Reynolds number
%     results.Pr_t           - Tube-side Prandtl number
%     results.Pr_s           - Shell-side Prandtl number
%     results.h_i            - Tube-side heat transfer coeff [W/m2/K]
%     results.h_s            - Shell-side heat transfer coeff [W/m2/K]
%     results.U_o_calc       - Calculated overall U [W/m2/K]
%     results.U_o_ass        - Assumed overall U [W/m2/K]
%     results.DP_t           - Tube-side pressure drop [Pa]
%     results.DP_s           - Shell-side pressure drop [Pa]
%     results.R_shell_conv   - Shell convection resistance [m2·K/W]
%     results.R_tube_conv    - Tube convection resistance [m2·K/W]
%     results.R_wall_cond    - Wall conduction resistance [m2·K/W]
%     results.R_fouling      - Fouling resistance [m2·K/W]
%     results.R_total        - Total thermal resistance [m2·K/W]

    %% Parse inputs with defaults
    p = set_defaults(params);

    R_gas = 8.314; % J/mol/K

    %% Convert temperatures to Kelvin
    T_hot1  = p.T_hot1  + 273.15;
    T_cold1 = p.T_cold1 + 273.15;
    T_cold2 = p.T_cold2 + 273.15;

    %% Heat duty and hot outlet temperature
    Q = p.m_cold * p.c_cold * (T_cold2 - T_cold1);           % [W]
    T_hot2 = T_hot1 - Q / (p.m_hot * p.c_hot);               % [K]

    %% LMTD and temperature ratios
    dT1 = T_hot2 - T_cold1;
    dT2 = T_hot1 - T_cold2;
    DeltaT_LM = (dT1 - dT2) / log(dT1 / dT2);

    R_ratio = (T_hot1 - T_hot2) / (T_cold2 - T_cold1);
    S_ratio = (T_cold2 - T_cold1) / (T_hot1 - T_cold1);

    %% Required area (initial estimate)
    A_req = Q / (p.F * p.U_o_ass * DeltaT_LM);               % [m2]

    %% Tube geometry
    L_tp = p.pitch_ratio * p.D_ext;                            % Tube pitch [m]
    A_o_one_tube = pi * p.D_ext * p.L_tube;                    % Outside area per tube [m2]
    N_tt = A_req / A_o_one_tube;                               % Number of tubes (real)

    %% Shell layout — triangular 30° rotation
    D_ctl = L_tp * sqrt(4 * p.C_1 * N_tt / (pi * (1 - p.psi_n)));
    D_s   = D_ctl + p.L_bb + p.D_ext;
    L_B   = p.baffle_spacing_ratio * D_s;

    P_v   = L_tp * cos(pi/6);
    N_r   = D_ctl / P_v;
    N_tcc = (1 - p.baffle_cut) * N_r;

    %% Tube-side heat transfer coefficient
    % Viscosity of ternary eutectic (Arrhenius form)
    mu_t = p.mu_t_A * exp(p.mu_t_Ea / (R_gas * T_hot1)) / 1000;  % [Pa·s]

    N_per_pass = N_tt / p.N_p;
    A_internal = (pi/4) * p.D_int^2;
    A_t = N_per_pass * A_internal;

    v_t  = p.m_hot / (p.rho_t * A_t);
    Re_t = p.rho_t * v_t * p.D_int / mu_t;
    Pr_t = p.C_pt * mu_t / p.k_t;

    % Sieder-Tate (laminar entry) correlation
    Nu_t = 1.86 * (Re_t * Pr_t * p.D_int / p.L_tube)^(1/3);
    h_i  = Nu_t * p.k_t / p.D_int;

    %% Shell-side heat transfer coefficient
    Q_vol_s = p.m_cold / p.rho_s;
    A_face  = p.L_tube * (D_ctl + p.D_ext);
    u_f     = Q_vol_s / A_face;
    u_max   = u_f * (L_tp / (L_tp - p.D_ext));

    Pr_s = p.C_ps * p.mu_s / p.k_s;
    Re_s_crossflow = p.rho_s * u_max * p.D_ext / p.mu_s;

    % Zukauskas-type correlation
    Nu_s = 0.27 * Re_s_crossflow^0.63 * Pr_s^0.36;
    h_s  = Nu_s * p.k_s / p.D_ext;

    %% Overall heat transfer coefficient
    A_o = A_o_one_tube * N_tt;
    A_i = pi * p.D_int * p.L_tube * N_tt;

    eta_o = 1.0;  % No fins

    R_shell_conv = 1 / (eta_o * h_s);
    R_tube_conv  = 1 / (h_i * (A_i / A_o));
    R_wall_cond  = (p.D_ext * log(p.D_ext / p.D_int)) / (2 * p.k_tube);
    R_fouling    = p.Rf_i * (A_o / A_i) + p.Rf_o;

    R_total  = R_shell_conv + R_tube_conv + R_wall_cond + R_fouling;
    U_o_calc = 1 / R_total;

    %% Tube-side pressure drop
    f_t = 16 / Re_t;                      % Laminar friction factor
    L_total = p.L_tube * p.N_p;
    K_loss  = 1.8 * p.N_p;                % Return bend losses

    DP_t_friction = 4 * f_t * (L_total / p.D_int) * (p.rho_t * v_t^2 / 2);
    DP_t_return   = K_loss * (p.rho_t * v_t^2) / 2;
    DP_t = DP_t_friction + DP_t_return;

    %% Shell-side pressure drop
    A_s_flow = (L_tp - p.D_ext) * D_s * L_B / L_tp;
    G_s  = p.m_cold / A_s_flow;
    u_s  = G_s / p.rho_s;
    d_e  = 1.10 / p.D_ext * (L_tp^2 - 0.917 * p.D_ext^2);
    Re_s = G_s * d_e / p.mu_s;

    % Robinson & Briggs friction factor
    f_s  = exp(0.576 - 0.19 * log(Re_s));
    DP_s = N_r * f_s * (p.rho_s * u_max^2 / 2);

    %% Pack results
    results.Q_kW         = Q / 1000;
    results.T_hot2_C     = T_hot2 - 273.15;
    results.LMTD         = DeltaT_LM;
    results.R            = R_ratio;
    results.S            = S_ratio;
    results.A_req        = A_req;
    results.N_tt         = N_tt;
    results.D_ctl        = D_ctl;
    results.D_s          = D_s;
    results.L_B          = L_B;
    results.Re_t         = Re_t;
    results.Re_s         = Re_s;
    results.Pr_t         = Pr_t;
    results.Pr_s         = Pr_s;
    results.h_i          = h_i;
    results.h_s          = h_s;
    results.U_o_calc     = U_o_calc;
    results.U_o_ass      = p.U_o_ass;
    results.DP_t         = DP_t;
    results.DP_s         = DP_s;
    results.R_shell_conv = R_shell_conv;
    results.R_tube_conv  = R_tube_conv;
    results.R_wall_cond  = R_wall_cond;
    results.R_fouling    = R_fouling;
    results.R_total      = R_total;

    %% Print summary
    fprintf('\n============ Loop Interface Exchanger Summary ============\n');
    fprintf('  Heat duty                Q  = %.2f kW\n', results.Q_kW);
    fprintf('  Hot outlet temp      T_h2   = %.2f °C\n', results.T_hot2_C);
    fprintf('  LMTD                        = %.2f K\n', results.LMTD);
    fprintf('  R / S                       = %.4f / %.4f\n', results.R, results.S);
    fprintf('  Required area        A_req  = %.4f m2\n', results.A_req);
    fprintf('  Number of tubes      N_tt   = %.1f\n', results.N_tt);
    fprintf('  Shell diameter       D_s    = %.4f m\n', results.D_s);
    fprintf('  Baffle spacing       L_B    = %.4f m\n', results.L_B);
    fprintf('  --------------------------------------------------------\n');
    fprintf('  Tube-side:  Re = %.1f,  Pr = %.2f,  h_i = %.2f W/m2/K\n', ...
            results.Re_t, results.Pr_t, results.h_i);
    fprintf('  Shell-side: Re = %.1f,  Pr = %.2f,  h_s = %.2f W/m2/K\n', ...
            results.Re_s, results.Pr_s, results.h_s);
    fprintf('  --------------------------------------------------------\n');
    fprintf('  U_o (calculated) = %.2f W/m2/K\n', results.U_o_calc);
    fprintf('  U_o (assumed)    = %.2f W/m2/K\n', results.U_o_ass);
    fprintf('  --------------------------------------------------------\n');
    fprintf('  Tube-side  DP = %.2f Pa\n', results.DP_t);
    fprintf('  Shell-side DP = %.4f Pa\n', results.DP_s);
    fprintf('==========================================================\n\n');
end


function p = set_defaults(params)
% SET_DEFAULTS  Fill in any missing fields with default values.

    defaults = struct( ...
        'm_cold',    0.25, ...
        'm_hot',     0.7609, ...
        'T_cold1',   283.0483336, ...
        'T_cold2',   310, ...
        'T_hot1',    620, ...
        'c_hot',     2300, ...
        'c_cold',    2150, ...
        'rho_t',     2050, ...
        'k_t',       0.55, ...
        'C_pt',      2300, ...
        'mu_t_A',    0.0852, ...
        'mu_t_Ea',   3.51e4, ...
        'rho_s',     689.5, ...
        'mu_s',      0.41e-3, ...
        'k_s',       0.076, ...
        'C_ps',      2150, ...
        'L_tube',    1.0, ...
        'D_int',     0.020, ...
        'D_ext',     0.024, ...
        'N_p',       2, ...
        'pitch_ratio', 1.25, ...
        'psi_n',     0.17, ...
        'C_1',       0.866, ...
        'L_bb',      0.0127, ...
        'baffle_spacing_ratio', 0.5, ...
        'baffle_cut', 0.25, ...
        'k_tube',    50, ...
        'Rf_o',      0.0002, ...
        'Rf_i',      0.0003, ...
        'F',         0.95, ...
        'U_o_ass',   68 ...
    );

    p = defaults;
    if nargin > 0 && ~isempty(params)
        fields = fieldnames(params);
        for i = 1:numel(fields)
            p.(fields{i}) = params.(fields{i});
        end
    end
end
