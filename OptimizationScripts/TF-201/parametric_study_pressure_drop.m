%% PARAMETRIC_STUDY_PRESSURE_DROP
% Parametric study to minimize pressure drop in the torrefaction heating jacket
% while maintaining thermal design validity (A_av >= A_req)
%
% Variables varied (channel and jacket geometry):
%   1. D_jacket - Jacket inner diameter [m]
%   2. w        - Helical channel width [m]
%   3. t        - Wall/rib thickness [m]
%
% Fixed parameters (torrefaction unit design & operating conditions):
%   - D_pyrolizer = 0.50 m
%   - L = 4.20 m
%   - m_dot = 0.25 kg/s
%   - T_hot1, T_cold, Q_req, fluid properties
%
% Constraint: Pressure drop must be < 8.5 kPa
%
% Author: Parametric Study Script
% Date: Generated for TF-201 optimization

clear; clc; close all;

%% ---- Setup Results Directory ----
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results_folder = fullfile(pwd, sprintf('results_%s', timestamp));
mkdir(results_folder);

fprintf('============================================================\n');
fprintf('  PARAMETRIC STUDY: Pressure Drop Minimization\n');
fprintf('  Results will be saved to: %s\n', results_folder);
fprintf('============================================================\n\n');

%% ---- Fixed Parameters ----
fixed_params = struct();
fixed_params.D_pyrolizer = 0.50;    % [m] - Fixed torrefaction unit
fixed_params.L = 4.20;               % [m] - Fixed pyrolizer length
fixed_params.m_dot = 0.25;           % [kg/s] - Fixed mass flow rate
fixed_params.T_hot1 = 302.0064732 + 273.15;  % [K] - Fixed inlet temp
fixed_params.T_cold = 280 + 273.15;          % [K] - Fixed wall temp
fixed_params.Q_req = 11290;          % [W] - Fixed heat duty
fixed_params.rho = 689.5;            % [kg/m^3]
fixed_params.Cp = 2150;              % [J/(kg K)]
fixed_params.mu = 0.41e-3;           % [Pa s]
fixed_params.k_fluid = 0.076;        % [W/(m K)]
fixed_params.f_c = 0.009;            % [-] Fanning friction factor

%% ---- Default Values (Baseline) ----
default_D_jacket = 0.53;   % [m]
default_w = 0.05;          % [m]
default_t = 0.05;          % [m]

% Calculate baseline
baseline_params = fixed_params;
baseline_params.D_jacket = default_D_jacket;
baseline_params.w = default_w;
baseline_params.t = default_t;
baseline_results = torrefaction_heating_jacket_silent(baseline_params);
baseline_DP = baseline_results.DP_kPa;

fprintf('BASELINE DESIGN:\n');
fprintf('  D_jacket = %.3f m, w = %.3f m, t = %.3f m\n', default_D_jacket, default_w, default_t);
fprintf('  Pressure Drop = %.3f kPa\n', baseline_DP);
fprintf('  Design Valid = %s\n\n', mat2str(baseline_results.design_ok));

%% ---- Parameter Ranges ----
% D_jacket: Must be > D_pyrolizer (0.50m), reasonable max ~0.70m
D_jacket_range = linspace(0.52, 0.70, 25);

% w (channel width): 0.02m to 0.15m (reasonable manufacturing limits)
w_range = linspace(0.02, 0.15, 25);

% t (rib thickness): 0.01m to 0.10m (structural limits)
t_range = linspace(0.01, 0.10, 20);

%% ---- STUDY 1: D_jacket vs w (fixed t = 0.05m) ----
fprintf('Running Study 1: D_jacket vs Channel Width (w)...\n');

[D_jkt_grid, W_grid] = meshgrid(D_jacket_range, w_range);
DP_study1 = zeros(size(D_jkt_grid));
valid_study1 = false(size(D_jkt_grid));

for i = 1:numel(D_jkt_grid)
    params = fixed_params;
    params.D_jacket = D_jkt_grid(i);
    params.w = W_grid(i);
    params.t = default_t;

    try
        res = torrefaction_heating_jacket_silent(params);
        DP_study1(i) = res.DP_kPa;
        valid_study1(i) = res.design_ok;
    catch
        DP_study1(i) = NaN;
        valid_study1(i) = false;
    end
end

% Mask invalid designs
DP_study1_valid = DP_study1;
DP_study1_valid(~valid_study1) = NaN;

% Find minimum
[min_DP1, idx1] = min(DP_study1_valid(:));
[row1, col1] = ind2sub(size(DP_study1_valid), idx1);
best_D_jkt_1 = D_jacket_range(col1);
best_w_1 = w_range(row1);

fprintf('  Best: D_jacket=%.3fm, w=%.3fm => DP=%.3f kPa\n\n', best_D_jkt_1, best_w_1, min_DP1);

%% ---- STUDY 2: D_jacket vs t (fixed w = 0.05m) ----
fprintf('Running Study 2: D_jacket vs Rib Thickness (t)...\n');

[D_jkt_grid2, T_grid] = meshgrid(D_jacket_range, t_range);
DP_study2 = zeros(size(D_jkt_grid2));
valid_study2 = false(size(D_jkt_grid2));

for i = 1:numel(D_jkt_grid2)
    params = fixed_params;
    params.D_jacket = D_jkt_grid2(i);
    params.w = default_w;
    params.t = T_grid(i);

    try
        res = torrefaction_heating_jacket_silent(params);
        DP_study2(i) = res.DP_kPa;
        valid_study2(i) = res.design_ok;
    catch
        DP_study2(i) = NaN;
        valid_study2(i) = false;
    end
end

DP_study2_valid = DP_study2;
DP_study2_valid(~valid_study2) = NaN;

[min_DP2, idx2] = min(DP_study2_valid(:));
[row2, col2] = ind2sub(size(DP_study2_valid), idx2);
best_D_jkt_2 = D_jacket_range(col2);
best_t_2 = t_range(row2);

fprintf('  Best: D_jacket=%.3fm, t=%.3fm => DP=%.3f kPa\n\n', best_D_jkt_2, best_t_2, min_DP2);

%% ---- STUDY 3: w vs t (fixed D_jacket at optimal from Study 1) ----
fprintf('Running Study 3: Channel Width (w) vs Rib Thickness (t)...\n');

[W_grid3, T_grid3] = meshgrid(w_range, t_range);
DP_study3 = zeros(size(W_grid3));
valid_study3 = false(size(W_grid3));

optimal_D_jacket = best_D_jkt_1;  % Use best from Study 1

for i = 1:numel(W_grid3)
    params = fixed_params;
    params.D_jacket = optimal_D_jacket;
    params.w = W_grid3(i);
    params.t = T_grid3(i);

    try
        res = torrefaction_heating_jacket_silent(params);
        DP_study3(i) = res.DP_kPa;
        valid_study3(i) = res.design_ok;
    catch
        DP_study3(i) = NaN;
        valid_study3(i) = false;
    end
end

DP_study3_valid = DP_study3;
DP_study3_valid(~valid_study3) = NaN;

[min_DP3, idx3] = min(DP_study3_valid(:));
[row3, col3] = ind2sub(size(DP_study3_valid), idx3);
best_w_3 = w_range(col3);
best_t_3 = t_range(row3);

fprintf('  Best: w=%.3fm, t=%.3fm => DP=%.3f kPa\n\n', best_w_3, best_t_3, min_DP3);

%% ---- STUDY 4: 3D Parameter Space (D_jacket, w, t) ----
fprintf('Running Study 4: Full 3D Parameter Space Search...\n');

% Coarser grid for 3D study
D_jkt_3d = linspace(0.52, 0.70, 15);
w_3d = linspace(0.02, 0.15, 15);
t_3d = linspace(0.01, 0.10, 10);

n_combinations = length(D_jkt_3d) * length(w_3d) * length(t_3d);
results_table = zeros(n_combinations, 7);  % D_jkt, w, t, DP, valid, GAP, D_h
idx = 0;

for i = 1:length(D_jkt_3d)
    for j = 1:length(w_3d)
        for k = 1:length(t_3d)
            idx = idx + 1;
            params = fixed_params;
            params.D_jacket = D_jkt_3d(i);
            params.w = w_3d(j);
            params.t = t_3d(k);

            try
                res = torrefaction_heating_jacket_silent(params);
                results_table(idx, :) = [D_jkt_3d(i), w_3d(j), t_3d(k), ...
                    res.DP_kPa, res.design_ok, res.GAP, res.D_h];
            catch
                results_table(idx, :) = [D_jkt_3d(i), w_3d(j), t_3d(k), NaN, 0, NaN, NaN];
            end
        end
    end
end

% Filter valid designs with DP < 8.5 kPa
valid_mask = (results_table(:,5) == 1) & (results_table(:,4) < 8.5);
valid_results = results_table(valid_mask, :);

if ~isempty(valid_results)
    [~, best_idx] = min(valid_results(:,4));
    best_overall = valid_results(best_idx, :);

    fprintf('\n  OPTIMAL DESIGN FOUND:\n');
    fprintf('    D_jacket = %.4f m\n', best_overall(1));
    fprintf('    w        = %.4f m\n', best_overall(2));
    fprintf('    t        = %.4f m\n', best_overall(3));
    fprintf('    DP       = %.4f kPa\n', best_overall(4));
    fprintf('    GAP      = %.4f m\n', best_overall(6));
    fprintf('    D_h      = %.4f m\n', best_overall(7));
else
    fprintf('  WARNING: No valid designs found with DP < 8.5 kPa\n');
    best_overall = [NaN NaN NaN NaN NaN NaN NaN];
end

%% ---- STUDY 5: Sensitivity Analysis ----
fprintf('\nRunning Study 5: Sensitivity Analysis around optimal...\n');

% Perturb each parameter by +/- 10% around optimal
if ~isnan(best_overall(1))
    opt_D_jkt = best_overall(1);
    opt_w = best_overall(2);
    opt_t = best_overall(3);

    perturb = 0.10;  % 10% perturbation
    sensitivity = struct();

    % D_jacket sensitivity
    D_jkt_sens = linspace(opt_D_jkt*(1-perturb), opt_D_jkt*(1+perturb), 50);
    DP_D_jkt_sens = zeros(size(D_jkt_sens));
    for i = 1:length(D_jkt_sens)
        params = fixed_params;
        params.D_jacket = D_jkt_sens(i);
        params.w = opt_w;
        params.t = opt_t;
        res = torrefaction_heating_jacket_silent(params);
        DP_D_jkt_sens(i) = res.DP_kPa;
    end
    sensitivity.D_jacket = [D_jkt_sens', DP_D_jkt_sens'];

    % w sensitivity
    w_sens = linspace(opt_w*(1-perturb), opt_w*(1+perturb), 50);
    DP_w_sens = zeros(size(w_sens));
    for i = 1:length(w_sens)
        params = fixed_params;
        params.D_jacket = opt_D_jkt;
        params.w = w_sens(i);
        params.t = opt_t;
        res = torrefaction_heating_jacket_silent(params);
        DP_w_sens(i) = res.DP_kPa;
    end
    sensitivity.w = [w_sens', DP_w_sens'];

    % t sensitivity
    t_sens = linspace(opt_t*(1-perturb), opt_t*(1+perturb), 50);
    DP_t_sens = zeros(size(t_sens));
    for i = 1:length(t_sens)
        params = fixed_params;
        params.D_jacket = opt_D_jkt;
        params.w = opt_w;
        params.t = t_sens(i);
        res = torrefaction_heating_jacket_silent(params);
        DP_t_sens(i) = res.DP_kPa;
    end
    sensitivity.t = [t_sens', DP_t_sens'];
end

%% ---- Generate Figures ----
fprintf('\nGenerating figures...\n');

% Figure 1: D_jacket vs w contour
fig1 = figure('Position', [100 100 800 600], 'Visible', 'off');
contourf(D_jacket_range*100, w_range*100, DP_study1_valid, 20, 'LineColor', 'none');
hold on;
contour(D_jacket_range*100, w_range*100, DP_study1_valid, [8.5 8.5], 'r-', 'LineWidth', 2);
plot(best_D_jkt_1*100, best_w_1*100, 'ko', 'MarkerSize', 12, 'MarkerFaceColor', 'g', 'LineWidth', 2);
colorbar;
xlabel('Jacket Diameter D_{jacket} [cm]', 'FontSize', 12);
ylabel('Channel Width w [cm]', 'FontSize', 12);
title('Study 1: Pressure Drop [kPa] vs D_{jacket} and w (t = 5 cm fixed)', 'FontSize', 14);
legend('', 'DP = 8.5 kPa limit', sprintf('Optimum: %.2f kPa', min_DP1), 'Location', 'best');
colormap(jet);
grid on;
saveas(fig1, fullfile(results_folder, 'study1_Djacket_vs_w.png'));
close(fig1);

% Figure 2: D_jacket vs t contour
fig2 = figure('Position', [100 100 800 600], 'Visible', 'off');
contourf(D_jacket_range*100, t_range*100, DP_study2_valid, 20, 'LineColor', 'none');
hold on;
contour(D_jacket_range*100, t_range*100, DP_study2_valid, [8.5 8.5], 'r-', 'LineWidth', 2);
plot(best_D_jkt_2*100, best_t_2*100, 'ko', 'MarkerSize', 12, 'MarkerFaceColor', 'g', 'LineWidth', 2);
colorbar;
xlabel('Jacket Diameter D_{jacket} [cm]', 'FontSize', 12);
ylabel('Rib Thickness t [cm]', 'FontSize', 12);
title('Study 2: Pressure Drop [kPa] vs D_{jacket} and t (w = 5 cm fixed)', 'FontSize', 14);
legend('', 'DP = 8.5 kPa limit', sprintf('Optimum: %.2f kPa', min_DP2), 'Location', 'best');
colormap(jet);
grid on;
saveas(fig2, fullfile(results_folder, 'study2_Djacket_vs_t.png'));
close(fig2);

% Figure 3: w vs t contour
fig3 = figure('Position', [100 100 800 600], 'Visible', 'off');
contourf(w_range*100, t_range*100, DP_study3_valid, 20, 'LineColor', 'none');
hold on;
contour(w_range*100, t_range*100, DP_study3_valid, [8.5 8.5], 'r-', 'LineWidth', 2);
plot(best_w_3*100, best_t_3*100, 'ko', 'MarkerSize', 12, 'MarkerFaceColor', 'g', 'LineWidth', 2);
colorbar;
xlabel('Channel Width w [cm]', 'FontSize', 12);
ylabel('Rib Thickness t [cm]', 'FontSize', 12);
title(sprintf('Study 3: Pressure Drop [kPa] vs w and t (D_{jacket} = %.1f cm)', optimal_D_jacket*100), 'FontSize', 14);
legend('', 'DP = 8.5 kPa limit', sprintf('Optimum: %.2f kPa', min_DP3), 'Location', 'best');
colormap(jet);
grid on;
saveas(fig3, fullfile(results_folder, 'study3_w_vs_t.png'));
close(fig3);

% Figure 4: Pareto-style scatter of valid designs
fig4 = figure('Position', [100 100 900 700], 'Visible', 'off');
if ~isempty(valid_results)
    scatter3(valid_results(:,1)*100, valid_results(:,2)*100, valid_results(:,3)*100, ...
        50, valid_results(:,4), 'filled');
    hold on;
    plot3(best_overall(1)*100, best_overall(2)*100, best_overall(3)*100, ...
        'rp', 'MarkerSize', 20, 'MarkerFaceColor', 'r', 'LineWidth', 2);
    colorbar;
    xlabel('D_{jacket} [cm]', 'FontSize', 12);
    ylabel('w [cm]', 'FontSize', 12);
    zlabel('t [cm]', 'FontSize', 12);
    title('Study 4: Valid Designs (DP < 8.5 kPa) - Color = Pressure Drop [kPa]', 'FontSize', 14);
    legend('Valid designs', 'Optimal design', 'Location', 'best');
    colormap(jet);
    view(45, 30);
    grid on;
end
saveas(fig4, fullfile(results_folder, 'study4_3D_valid_designs.png'));
close(fig4);

% Figure 5: Sensitivity Analysis
if exist('sensitivity', 'var')
    fig5 = figure('Position', [100 100 1200 400], 'Visible', 'off');

    subplot(1,3,1);
    plot(sensitivity.D_jacket(:,1)*100, sensitivity.D_jacket(:,2), 'b-', 'LineWidth', 2);
    hold on;
    yline(8.5, 'r--', 'LineWidth', 1.5);
    xline(opt_D_jkt*100, 'g--', 'LineWidth', 1.5);
    xlabel('D_{jacket} [cm]', 'FontSize', 11);
    ylabel('Pressure Drop [kPa]', 'FontSize', 11);
    title('Sensitivity: D_{jacket}', 'FontSize', 12);
    legend('DP', '8.5 kPa limit', 'Optimal', 'Location', 'best');
    grid on;

    subplot(1,3,2);
    plot(sensitivity.w(:,1)*100, sensitivity.w(:,2), 'b-', 'LineWidth', 2);
    hold on;
    yline(8.5, 'r--', 'LineWidth', 1.5);
    xline(opt_w*100, 'g--', 'LineWidth', 1.5);
    xlabel('Channel Width w [cm]', 'FontSize', 11);
    ylabel('Pressure Drop [kPa]', 'FontSize', 11);
    title('Sensitivity: w', 'FontSize', 12);
    legend('DP', '8.5 kPa limit', 'Optimal', 'Location', 'best');
    grid on;

    subplot(1,3,3);
    plot(sensitivity.t(:,1)*100, sensitivity.t(:,2), 'b-', 'LineWidth', 2);
    hold on;
    yline(8.5, 'r--', 'LineWidth', 1.5);
    xline(opt_t*100, 'g--', 'LineWidth', 1.5);
    xlabel('Rib Thickness t [cm]', 'FontSize', 11);
    ylabel('Pressure Drop [kPa]', 'FontSize', 11);
    title('Sensitivity: t', 'FontSize', 12);
    legend('DP', '8.5 kPa limit', 'Optimal', 'Location', 'best');
    grid on;

    saveas(fig5, fullfile(results_folder, 'study5_sensitivity.png'));
    close(fig5);
end

% Figure 6: Comparison Bar Chart
fig6 = figure('Position', [100 100 800 500], 'Visible', 'off');
designs = {'Baseline', 'Study 1', 'Study 2', 'Study 3', 'Optimal'};
DPs = [baseline_DP, min_DP1, min_DP2, min_DP3, best_overall(4)];
colors = [0.7 0.7 0.7; 0.3 0.6 0.9; 0.3 0.8 0.5; 0.9 0.6 0.3; 0.2 0.8 0.2];

b = bar(DPs);
b.FaceColor = 'flat';
for i = 1:length(DPs)
    b.CData(i,:) = colors(i,:);
end
hold on;
yline(8.5, 'r--', 'LineWidth', 2);
text(5.5, 8.5, ' Design Limit', 'Color', 'r', 'FontSize', 10, 'VerticalAlignment', 'bottom');
set(gca, 'XTickLabel', designs, 'FontSize', 11);
ylabel('Pressure Drop [kPa]', 'FontSize', 12);
title('Comparison of Design Optima', 'FontSize', 14);
grid on;

% Add values on bars
for i = 1:length(DPs)
    text(i, DPs(i) + 0.2, sprintf('%.2f', DPs(i)), 'HorizontalAlignment', 'center', 'FontSize', 10);
end

saveas(fig6, fullfile(results_folder, 'comparison_bar_chart.png'));
close(fig6);

% Figure 7: Design Space Validity Map
fig7 = figure('Position', [100 100 800 600], 'Visible', 'off');
valid_mask_study1 = double(valid_study1);
imagesc(D_jacket_range*100, w_range*100, valid_mask_study1);
colormap([1 0.3 0.3; 0.3 1 0.3]);  % Red for invalid, green for valid
xlabel('Jacket Diameter D_{jacket} [cm]', 'FontSize', 12);
ylabel('Channel Width w [cm]', 'FontSize', 12);
title('Design Space Validity (Green = Valid, Red = Invalid)', 'FontSize', 14);
cb = colorbar;
cb.Ticks = [0.25, 0.75];
cb.TickLabels = {'Invalid', 'Valid'};
grid on;
saveas(fig7, fullfile(results_folder, 'design_validity_map.png'));
close(fig7);

%% ---- Generate Summary Report ----
fprintf('\nGenerating summary report...\n');

summary_file = fullfile(results_folder, 'SUMMARY_REPORT.txt');
fid = fopen(summary_file, 'w');

fprintf(fid, '================================================================\n');
fprintf(fid, '  PARAMETRIC STUDY SUMMARY REPORT\n');
fprintf(fid, '  Torrefaction Heating Jacket - Pressure Drop Optimization\n');
fprintf(fid, '  Generated: %s\n', datestr(now));
fprintf(fid, '================================================================\n\n');

fprintf(fid, 'OBJECTIVE:\n');
fprintf(fid, '  Minimize pressure drop while maintaining thermal design validity\n');
fprintf(fid, '  Constraint: Pressure Drop < 8.5 kPa\n\n');

fprintf(fid, 'FIXED PARAMETERS (Torrefaction Unit Design):\n');
fprintf(fid, '  D_pyrolizer  = %.3f m (pyrolizer outer diameter)\n', fixed_params.D_pyrolizer);
fprintf(fid, '  L            = %.3f m (pyrolizer length)\n', fixed_params.L);
fprintf(fid, '  m_dot        = %.3f kg/s (mass flow rate)\n', fixed_params.m_dot);
fprintf(fid, '  T_hot_in     = %.2f K (%.2f C)\n', fixed_params.T_hot1, fixed_params.T_hot1-273.15);
fprintf(fid, '  T_wall       = %.2f K (%.2f C)\n', fixed_params.T_cold, fixed_params.T_cold-273.15);
fprintf(fid, '  Q_req        = %.0f W (heat duty)\n', fixed_params.Q_req);
fprintf(fid, '  f_c          = %.4f (Fanning friction factor)\n\n', fixed_params.f_c);

fprintf(fid, 'VARIABLE PARAMETERS:\n');
fprintf(fid, '  D_jacket  : Jacket inner diameter [m]\n');
fprintf(fid, '  w         : Helical channel width [m]\n');
fprintf(fid, '  t         : Wall/rib thickness [m]\n\n');

fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, 'BASELINE DESIGN:\n');
fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, '  D_jacket = %.4f m (%.1f cm)\n', default_D_jacket, default_D_jacket*100);
fprintf(fid, '  w        = %.4f m (%.1f cm)\n', default_w, default_w*100);
fprintf(fid, '  t        = %.4f m (%.1f cm)\n', default_t, default_t*100);
fprintf(fid, '  Pressure Drop = %.4f kPa\n', baseline_DP);
fprintf(fid, '  Design Valid  = %s\n\n', mat2str(baseline_results.design_ok));

fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, 'STUDY RESULTS:\n');
fprintf(fid, '----------------------------------------------------------------\n\n');

fprintf(fid, 'Study 1: D_jacket vs Channel Width (w)\n');
fprintf(fid, '  Fixed: t = %.3f m\n', default_t);
fprintf(fid, '  Best:  D_jacket = %.4f m, w = %.4f m\n', best_D_jkt_1, best_w_1);
fprintf(fid, '  Min DP = %.4f kPa (%.1f%% reduction)\n\n', min_DP1, (1-min_DP1/baseline_DP)*100);

fprintf(fid, 'Study 2: D_jacket vs Rib Thickness (t)\n');
fprintf(fid, '  Fixed: w = %.3f m\n', default_w);
fprintf(fid, '  Best:  D_jacket = %.4f m, t = %.4f m\n', best_D_jkt_2, best_t_2);
fprintf(fid, '  Min DP = %.4f kPa (%.1f%% reduction)\n\n', min_DP2, (1-min_DP2/baseline_DP)*100);

fprintf(fid, 'Study 3: Channel Width (w) vs Rib Thickness (t)\n');
fprintf(fid, '  Fixed: D_jacket = %.4f m\n', optimal_D_jacket);
fprintf(fid, '  Best:  w = %.4f m, t = %.4f m\n', best_w_3, best_t_3);
fprintf(fid, '  Min DP = %.4f kPa (%.1f%% reduction)\n\n', min_DP3, (1-min_DP3/baseline_DP)*100);

fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, 'OPTIMAL DESIGN (3D Search):\n');
fprintf(fid, '----------------------------------------------------------------\n');
if ~isnan(best_overall(1))
    fprintf(fid, '  D_jacket      = %.4f m (%.2f cm)\n', best_overall(1), best_overall(1)*100);
    fprintf(fid, '  w             = %.4f m (%.2f cm)\n', best_overall(2), best_overall(2)*100);
    fprintf(fid, '  t             = %.4f m (%.2f cm)\n', best_overall(3), best_overall(3)*100);
    fprintf(fid, '  Pressure Drop = %.4f kPa\n', best_overall(4));
    fprintf(fid, '  Annular Gap   = %.4f m (%.2f cm)\n', best_overall(6), best_overall(6)*100);
    fprintf(fid, '  Hydraulic Dia = %.4f m (%.2f cm)\n', best_overall(7), best_overall(7)*100);
    fprintf(fid, '\n  IMPROVEMENT: %.1f%% reduction from baseline\n', (1-best_overall(4)/baseline_DP)*100);
else
    fprintf(fid, '  No optimal design found within constraints.\n');
end

fprintf(fid, '\n----------------------------------------------------------------\n');
fprintf(fid, 'KEY FINDINGS:\n');
fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, '1. Increasing jacket diameter (D_jacket) increases flow area,\n');
fprintf(fid, '   reducing velocity and pressure drop.\n\n');
fprintf(fid, '2. Increasing channel width (w) increases hydraulic diameter,\n');
fprintf(fid, '   which is beneficial for reducing pressure drop.\n\n');
fprintf(fid, '3. Decreasing rib thickness (t) increases number of turns but\n');
fprintf(fid, '   has complex effects on overall coil length.\n\n');
fprintf(fid, '4. The design must maintain A_available >= A_required for valid\n');
fprintf(fid, '   heat transfer.\n\n');

fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, 'FILES GENERATED:\n');
fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, '  study1_Djacket_vs_w.png      - Contour: D_jacket vs channel width\n');
fprintf(fid, '  study2_Djacket_vs_t.png      - Contour: D_jacket vs rib thickness\n');
fprintf(fid, '  study3_w_vs_t.png            - Contour: channel width vs rib thickness\n');
fprintf(fid, '  study4_3D_valid_designs.png  - 3D scatter of valid designs\n');
fprintf(fid, '  study5_sensitivity.png       - Sensitivity analysis plots\n');
fprintf(fid, '  comparison_bar_chart.png     - Comparison of all optima\n');
fprintf(fid, '  design_validity_map.png      - Valid/invalid design regions\n');
fprintf(fid, '  SUMMARY_REPORT.txt           - This file\n');

fprintf(fid, '\n================================================================\n');
fprintf(fid, '  END OF REPORT\n');
fprintf(fid, '================================================================\n');

fclose(fid);

%% ---- Save Results Data ----
save(fullfile(results_folder, 'parametric_study_data.mat'), ...
    'D_jacket_range', 'w_range', 't_range', ...
    'DP_study1', 'valid_study1', ...
    'DP_study2', 'valid_study2', ...
    'DP_study3', 'valid_study3', ...
    'results_table', 'valid_results', 'best_overall', ...
    'baseline_results', 'fixed_params');

fprintf('\n============================================================\n');
fprintf('  PARAMETRIC STUDY COMPLETE\n');
fprintf('  Results saved to: %s\n', results_folder);
fprintf('============================================================\n');

%% ---- Helper Function (Silent version) ----
function results = torrefaction_heating_jacket_silent(params)
    % Silent version of torrefaction_heating_jacket (no console output)

    def = struct( ...
        'D_pyrolizer', 0.50, ...
        'D_jacket',    0.53, ...
        'L',           4.20, ...
        'w',           0.05, ...
        't',           0.05, ...
        'T_hot1',      302.0064732 + 273.15, ...
        'm_dot',       0.25, ...
        'T_cold',      280 + 273.15, ...
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

    P       = w + t;
    N_turn  = L / P;
    D_coil  = (D_jkt + D_pyr) / 2;
    L_turn  = sqrt((pi * D_coil)^2 + P^2);
    L_coil  = N_turn * L_turn;
    GAP     = (D_jkt - D_pyr) / 2;
    A_c     = GAP * w;
    D_h     = 2 * GAP * w / (GAP + w);

    T_hot2    = T_hot1 - Q_req / (m_dot * Cp);
    T_hot_avg = (T_hot1 + T_hot2) / 2;

    v   = m_dot / (rho * A_c);
    Re  = rho * v * D_h / mu;
    Pr  = Cp * mu / k_fl;

    Nu  = 0.023 * Re^0.85 * Pr^0.3 * (D_h / D_coil)^0.1;
    h_j = Nu * k_fl / D_h;

    A_surface = pi * D_pyr * L;
    dT1       = T_hot1 - T_cold;
    dT2       = T_hot2 - T_cold;
    DeltaT_lm = (dT1 - dT2) / log(dT1 / dT2);
    A_req     = Q_req / (h_j * DeltaT_lm);
    design_ok = A_surface >= A_req;

    DP     = 4 * f_c * (L_coil / D_h) * (rho * v^2 / 2);
    DP_kPa = DP / 1000;

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
end
