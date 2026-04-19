function results = screw_separator_cooling_jacket(params)
% SCREW_SEPARATOR_COOLING_JACKET  Design a helical cooling jacket for a screw separator.
%
%   results = screw_separator_cooling_jacket(params)
%
%   INPUTS (fields of params struct):
%     T_cold1_C    - Coolant inlet temperature [°C]            (default: 281.00)
%     T_hot1_C     - Wall temperature at separator inlet [°C]  (default: 500)
%     T_hot2_C     - Desired wall temperature at outlet [°C]   (default: 285)
%     m_dot        - Coolant mass flow rate [kg/s]              (default: 0.25)
%     Q_req        - Required heat extraction [W]               (default: 1100)
%     L_jacket     - Length of screw conveyor [m]               (default: 1.2)
%     D_separator  - Separator outer diameter [m]               (default: 0.1016)
%     GAP          - Annular gap [m]                            (default: 0.01)
%     w            - Channel width [m]                          (default: 0.03)
%     t_wall       - Wall thickness between channels [m]        (default: 0.02)
%
%   Fluid properties (Helisol 5A, override if using a different HTF):
%     rho          - Density [kg/m^3]                           (default: 689.5)
%     Cp           - Specific heat capacity [J/(kg·K)]          (default: 2150)
%     mu           - Dynamic viscosity [Pa·s]                   (default: 0.41e-3)
%     k_fluid      - Thermal conductivity [W/(m·K)]             (default: 0.076)
%
%   OUTPUTS (fields of results struct):
%     T_cold2_C    - Coolant outlet temperature [°C]
%     DeltaT_lm    - Log-mean temperature difference [K]
%     Re           - Reynolds number [-]
%     Pr           - Prandtl number [-]
%     Nu           - Nusselt number [-]
%     h_j          - Jacket-side heat transfer coefficient [W/(m^2·K)]
%     v            - Coolant velocity [m/s]
%     A_req        - Required heat transfer area [m^2]
%     A_av         - Available heat transfer area [m^2]
%     design_ok    - true if A_av >= A_req
%     N_turn       - Number of helical turns [-]
%     L_turn       - Length per turn [m]
%     L_coil       - Total coil path length [m]
%     D_h          - Hydraulic diameter [m]
%     D_coil       - Mean coil diameter [m]
%     A_c          - Channel cross-sectional area [m^2]
%     f_c          - Friction factor (Mishra & Gupta) [-]
%     DP_friction  - Frictional pressure drop [Pa]
%     DP_kPa       - Total pressure drop [kPa]

    %% Default parameters
    def.T_cold1_C   = 281.001822;
    def.T_hot1_C    = 500;
    def.T_hot2_C    = 285;
    def.m_dot       = 0.25;
    def.Q_req       = 1100;
    def.L_jacket    = 1.2;
    def.D_separator = 0.1016;
    def.GAP         = 0.01;
    def.w           = 0.03;
    def.t_wall      = 0.02;
    def.rho         = 689.5;
    def.Cp          = 2150;
    def.mu          = 0.41e-3;
    def.k_fluid     = 0.076;

    if nargin < 1, params = struct(); end
    p = apply_defaults(params, def);

    %% Convert temperatures to Kelvin
    T_cold1 = p.T_cold1_C + 273.15;
    T_hot1  = p.T_hot1_C  + 273.15;
    T_hot2  = p.T_hot2_C  + 273.15;

    %% Geometry
    D_jacket = p.D_separator + 2 * p.GAP;
    P_pitch  = p.w + p.t_wall;                         % pitch [m]
    N_turn   = p.L_jacket / P_pitch;                    % number of turns
    L_turn   = sqrt((pi * p.D_separator)^2 + P_pitch^2); % length per turn [m]
    L_coil   = N_turn * L_turn;                         % total coil length [m]
    A_c      = p.GAP * p.w;                             % channel cross-section [m^2]
    D_h      = 2 * p.GAP * p.w / (p.GAP + p.w);        % hydraulic diameter [m]
    D_coil   = (D_jacket + p.D_separator) / 2;          % mean coil diameter [m]

    %% Energy balance — coolant outlet temperature
    T_cold2 = T_cold1 + p.Q_req / (p.m_dot * p.Cp);    % [K]

    %% Flow parameters
    v  = p.m_dot / (p.rho * A_c);                       % velocity [m/s]
    Re = p.rho * v * D_h / p.mu;                        % Reynolds number
    Pr = p.Cp * p.mu / p.k_fluid;                       % Prandtl number

    %% Heat transfer — Seban & McLaughlin correlation (helical coils)
    Nu  = 0.023 * Re^0.85 * Pr^0.3 * (D_h / D_coil)^0.1;
    h_j = Nu * p.k_fluid / D_h;                        % [W/(m^2·K)]

    %% Log-mean temperature difference (concurrent / parallel flow)
    dT1 = T_hot1 - T_cold2;
    dT2 = T_hot2 - T_cold1;
    if abs(dT1 - dT2) < 1e-10
        DeltaT_lm = dT1;   % degenerate case
    else
        DeltaT_lm = (dT1 - dT2) / log(dT1 / dT2);
    end

    %% Area comparison
    A_req = p.Q_req / (h_j * DeltaT_lm);               % required area [m^2]
    A_av  = pi * p.D_separator * p.L_jacket;            % available area [m^2]
    design_ok = A_av >= A_req;

    %% Pressure drop — Mishra & Gupta correlation
    f_c = 0.3164 / Re^0.25 + 0.03 * (D_h / D_coil)^0.5;
    DP_friction = 4 * f_c * (L_coil / D_h) * (p.rho * v^2 / 2);  % [Pa]
    DP_kPa      = DP_friction / 1000;

    %% Pack outputs
    results.T_cold1_C   = p.T_cold1_C;
    results.T_cold2_C   = T_cold2 - 273.15;
    results.T_hot1_C    = p.T_hot1_C;
    results.T_hot2_C    = p.T_hot2_C;
    results.DeltaT_lm   = DeltaT_lm;
    results.Re          = Re;
    results.Pr          = Pr;
    results.Nu          = Nu;
    results.h_j         = h_j;
    results.v           = v;
    results.A_req       = A_req;
    results.A_av        = A_av;
    results.design_ok   = design_ok;
    results.N_turn      = N_turn;
    results.L_turn      = L_turn;
    results.L_coil      = L_coil;
    results.D_h         = D_h;
    results.D_coil      = D_coil;
    results.A_c         = A_c;
    results.f_c         = f_c;
    results.DP_friction = DP_friction;
    results.DP_kPa      = DP_kPa;

    %% Print summary
    fprintf('\n===== Screw Separator Cooling Jacket Design =====\n');
    fprintf('Coolant inlet  : %8.2f °C\n', p.T_cold1_C);
    fprintf('Coolant outlet : %8.2f °C\n', results.T_cold2_C);
    fprintf('Wall inlet     : %8.2f °C\n', p.T_hot1_C);
    fprintf('Wall outlet    : %8.2f °C\n', p.T_hot2_C);
    fprintf('--------------------------------------------------\n');
    fprintf('Re             : %12.2f\n', Re);
    fprintf('Pr             : %12.2f\n', Pr);
    fprintf('Nu             : %12.2f\n', Nu);
    fprintf('h_j            : %12.2f W/(m²·K)\n', h_j);
    fprintf('LMTD           : %12.2f K\n', DeltaT_lm);
    fprintf('Velocity       : %12.4f m/s\n', v);
    fprintf('--------------------------------------------------\n');
    fprintf('A_required     : %12.6f m²\n', A_req);
    fprintf('A_available    : %12.6f m²\n', A_av);
    if design_ok
        fprintf('>> Design PASSED (A_av / A_req = %.1f)\n', A_av / A_req);
    else
        fprintf('>> Design FAILED — increase area or h_j\n');
    end
    fprintf('--------------------------------------------------\n');
    fprintf('Friction factor: %12.6f\n', f_c);
    fprintf('ΔP (friction)  : %12.2f Pa\n', DP_friction);
    fprintf('ΔP (total)     : %12.2f kPa\n', DP_kPa);
    fprintf('==================================================\n\n');
end

%% ---- helper ----
function s = apply_defaults(user, def)
    s = def;
    fnames = fieldnames(user);
    for i = 1:numel(fnames)
        s.(fnames{i}) = user.(fnames{i});
    end
end
