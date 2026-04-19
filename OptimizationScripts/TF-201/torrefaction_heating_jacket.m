function results = torrefaction_heating_jacket(params)
% TORREFACTION_HEATING_JACKET  Design calculation for a helical-channel
% heating jacket around a torrefaction pyrolizer.
%
% results = torrefaction_heating_jacket(params)
%
% INPUTS (struct fields – all optional, defaults from original Maple sheet):
%
%   Geometry
%     D_pyrolizer  - Pyrolizer outer diameter [m]          (default 0.50)
%     D_jacket     - Jacket inner diameter [m]             (default 0.53)
%     L            - Pyrolizer length [m]                  (default 4.20)
%     w            - Helical channel width [m]             (default 0.05)
%     t            - Wall / rib thickness [m]              (default 0.05)
%
%   Operating conditions
%     T_hot1       - HTF inlet temperature [K]             (default 575.16)
%     m_dot        - HTF mass flow rate [kg/s]             (default 0.25)
%     T_cold       - Wall (process-side) temperature [K]   (default 553.15)
%     Q_req        - Required heat duty [W]                (default 11290)
%
%   Fluid properties (Helisol 5A defaults)
%     rho          - Density [kg/m^3]                      (default 689.5)
%     Cp           - Specific heat capacity [J/(kg K)]     (default 2150)
%     mu           - Dynamic viscosity [Pa s]              (default 4.1e-4)
%     k_fluid      - Thermal conductivity [W/(m K)]        (default 0.076)
%
%   Friction
%     f_c          - Fanning friction factor [-]           (default 0.009)
%
% OUTPUTS (struct):
%   --- Geometry ---
%   P             - Pitch [m]
%   N_turn        - Number of helical turns [-]
%   D_coil        - Mean coil diameter [m]
%   L_turn        - Length of one helical turn [m]
%   L_coil        - Total coil centreline length [m]
%   GAP           - Annular gap [m]
%   A_c           - Channel cross-sectional area [m^2]
%   D_h           - Hydraulic diameter [m]
%
%   --- Thermal ---
%   T_hot2        - HTF outlet temperature [K]
%   T_hot_avg     - Mean HTF temperature [K]
%   v             - HTF velocity [m/s]
%   Re            - Reynolds number [-]
%   Pr            - Prandtl number [-]
%   Nu            - Nusselt number (Seban & McLaughlin) [-]
%   h_j           - Jacket-side heat transfer coefficient [W/(m^2 K)]
%   DeltaT_lm     - Log-mean temperature difference [K]
%   A_req         - Required heat transfer area [m^2]
%   A_av          - Available heat transfer area [m^2]
%   design_ok     - true if A_av >= A_req
%
%   --- Pressure ---
%   DP            - Pressure drop [Pa]
%   DP_kPa        - Pressure drop [kPa]
%
% EXAMPLE
%   res = torrefaction_heating_jacket();              % all defaults
%   res = torrefaction_heating_jacket(struct('L',5)); % longer pyrolizer

    %% ---- Apply defaults ------------------------------------------------
    if nargin < 1, params = struct(); end

    def = struct( ...
        'D_pyrolizer', 0.50, ...
        'D_jacket',    0.53, ...
        'L',           4.20, ...
        'w',           0.05, ...
        't',           0.05, ...
        'T_hot1',      302.0064732 + 273.15, ...  % 575.1564732 K
        'm_dot',       0.25, ...
        'T_cold',      280 + 273.15, ...          % 553.15 K
        'Q_req',       11290, ...
        'rho',         689.5, ...
        'Cp',          2150, ...
        'mu',          0.41e-3, ...
        'k_fluid',     0.076, ...
        'f_c',         0.009);

    flds = fieldnames(def);
    for i = 1:numel(flds)
        if ~isfield(params, flds{i})
            params.(flds{i}) = def.(flds{i});
        end
    end

    % Unpack for readability
    D_pyr   = params.D_pyrolizer;
    D_jkt   = params.D_jacket;
    L       = params.L;
    w       = params.w;
    t       = params.t;
    T_hot1  = params.T_hot1;
    m_dot   = params.m_dot;
    T_cold  = params.T_cold;
    Q_req   = params.Q_req;
    rho     = params.rho;
    Cp      = params.Cp;
    mu      = params.mu;
    k_fl    = params.k_fluid;
    f_c     = params.f_c;

    %% ---- Helical channel geometry --------------------------------------
    P       = w + t;                                   % pitch [m]
    N_turn  = L / P;                                   % number of turns
    D_coil  = (D_jkt + D_pyr) / 2;                    % mean coil diameter [m]
    L_turn  = sqrt((pi * D_coil)^2 + P^2);            % length per turn [m]
    L_coil  = N_turn * L_turn;                         % total coil length [m]
    GAP     = (D_jkt - D_pyr) / 2;                     % annular gap [m]
    A_c     = GAP * w;                                 % flow cross-section [m^2]
    D_h     = 2 * GAP * w / (GAP + w);                % hydraulic diameter [m]

    %% ---- Energy balance → outlet temperature ---------------------------
    T_hot2    = T_hot1 - Q_req / (m_dot * Cp);        % [K]
    T_hot_avg = (T_hot1 + T_hot2) / 2;                % [K]

    %% ---- Flow parameters -----------------------------------------------
    v   = m_dot / (rho * A_c);                         % velocity [m/s]
    Re  = rho * v * D_h / mu;                          % Reynolds number
    Pr  = Cp * mu / k_fl;                              % Prandtl number

    %% ---- Heat transfer (Seban & McLaughlin correlation) ----------------
    Nu  = 0.023 * Re^0.85 * Pr^0.3 * (D_h / D_coil)^0.1;
    h_j = Nu * k_fl / D_h;                            % [W/(m^2 K)]

    %% ---- LMTD and area check ------------------------------------------
    A_surface = pi * D_pyr * L;                        % available area [m^2]

    dT1       = T_hot1 - T_cold;
    dT2       = T_hot2 - T_cold;
    DeltaT_lm = (dT1 - dT2) / log(dT1 / dT2);        % LMTD [K]

    A_req     = Q_req / (h_j * DeltaT_lm);            % required area [m^2]
    design_ok = A_surface >= A_req;

    %% ---- Pressure drop (Fanning, helical coil) -------------------------
    DP     = 4 * f_c * (L_coil / D_h) * (rho * v^2 / 2);  % [Pa]
    DP_kPa = DP / 1000;

    %% ---- Pack results --------------------------------------------------
    results = struct( ...
        'P',          P, ...
        'N_turn',     N_turn, ...
        'D_coil',     D_coil, ...
        'L_turn',     L_turn, ...
        'L_coil',     L_coil, ...
        'GAP',        GAP, ...
        'A_c',        A_c, ...
        'D_h',        D_h, ...
        'T_hot2',     T_hot2, ...
        'T_hot_avg',  T_hot_avg, ...
        'v',          v, ...
        'Re',         Re, ...
        'Pr',         Pr, ...
        'Nu',         Nu, ...
        'h_j',        h_j, ...
        'DeltaT_lm',  DeltaT_lm, ...
        'A_req',      A_req, ...
        'A_av',       A_surface, ...
        'design_ok',  design_ok, ...
        'DP',         DP, ...
        'DP_kPa',     DP_kPa);

    %% ---- Console summary -----------------------------------------------
    fprintf('\n===== Torrefaction Heating Jacket Design =====\n');
    fprintf('  Geometry\n');
    fprintf('    Pitch              = %.4f m\n', P);
    fprintf('    Turns              = %.0f\n', N_turn);
    fprintf('    Coil diameter      = %.4f m\n', D_coil);
    fprintf('    Coil length        = %.2f m\n', L_coil);
    fprintf('    Annular gap        = %.4f m\n', GAP);
    fprintf('    Hydraulic dia.     = %.6f m\n', D_h);
    fprintf('    Flow area          = %.6e m^2\n', A_c);
    fprintf('\n  Thermal\n');
    fprintf('    T_hot in           = %.2f K  (%.2f C)\n', T_hot1, T_hot1-273.15);
    fprintf('    T_hot out          = %.2f K  (%.2f C)\n', T_hot2, T_hot2-273.15);
    fprintf('    T_wall             = %.2f K  (%.2f C)\n', T_cold, T_cold-273.15);
    fprintf('    Velocity           = %.4f m/s\n', v);
    fprintf('    Re                 = %.1f\n', Re);
    fprintf('    Pr                 = %.2f\n', Pr);
    fprintf('    Nu                 = %.2f\n', Nu);
    fprintf('    h_j                = %.2f W/(m^2 K)\n', h_j);
    fprintf('    LMTD               = %.3f K\n', DeltaT_lm);
    fprintf('    A_required         = %.4f m^2\n', A_req);
    fprintf('    A_available        = %.4f m^2\n', A_surface);
    if design_ok
        fprintf('    >> DESIGN SUCCESSFUL <<\n');
    else
        fprintf('    >> DESIGN FAILED – increase area or h_j <<\n');
    end
    fprintf('\n  Pressure drop\n');
    fprintf('    dP                 = %.1f Pa  (%.3f kPa)\n', DP, DP_kPa);
    fprintf('===============================================\n\n');
end
