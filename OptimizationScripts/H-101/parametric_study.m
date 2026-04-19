%% PARAMETRIC STUDY FOR HEATER DESIGN OPTIMIZATION
% Objectives:
%   1. Minimize furnace volume
%   2. Minimize D/H ratio for radiant zone
%   3. Minimize D/H ratio for convective zone
%   4. Constraint: Pressure drop <= Baseline pressure drop
%
% Fixed: Temperature in/out, mass flow rates (fuel and salt)
% Variable: Tube geometry, furnace component geometry
%
% Author: Parametric Study Script
% Date: 2026-04-12

clear; clc; close all;

%% Create results folder with timestamp
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results_folder = fullfile(pwd, sprintf('results_%s', timestamp));
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

fprintf('Results will be saved to: %s\n\n', results_folder);

%% ========================================================================
%  PART 1: RUN BASELINE DESIGN
%  ========================================================================
fprintf('================================================================\n');
fprintf('  RUNNING BASELINE DESIGN\n');
fprintf('================================================================\n\n');

baseline = heater_design();

% Extract baseline metrics
baseline_metrics = struct();
baseline_metrics.DP_total_Pa = baseline.dp.DP_total_Pa;
baseline_metrics.DP_rad_Pa = baseline.dp.DP_total_rad_Pa;
baseline_metrics.DP_conv_Pa = baseline.dp.DP_total_conv_Pa;

% Radiant zone volume (cylindrical approximation)
baseline_metrics.H_rad = baseline.rad.H_coil_m;
baseline_metrics.D_rad = baseline.params.D_shell_heat;
baseline_metrics.V_rad = pi * (baseline_metrics.D_rad/2)^2 * baseline_metrics.H_rad;
baseline_metrics.DH_ratio_rad = baseline_metrics.D_rad / baseline_metrics.H_rad;

% Convection zone dimensions
baseline_metrics.W_conv = baseline.conv.W_conv_m;
baseline_metrics.n_rows_conv = baseline.conv.n_rows;
baseline_metrics.H_conv = baseline.conv.n_rows * baseline.params.p_conv_vertical;
baseline_metrics.V_conv = baseline_metrics.W_conv^2 * baseline_metrics.H_conv;
baseline_metrics.DH_ratio_conv = baseline_metrics.W_conv / baseline_metrics.H_conv;

% Total volume
baseline_metrics.V_total = baseline_metrics.V_rad + baseline_metrics.V_conv;

fprintf('\n--- BASELINE METRICS ---\n');
fprintf('  Radiant Zone:\n');
fprintf('    Height (H):              %.3f m\n', baseline_metrics.H_rad);
fprintf('    Diameter (D):            %.3f m\n', baseline_metrics.D_rad);
fprintf('    Volume:                  %.4f m³\n', baseline_metrics.V_rad);
fprintf('    D/H Ratio:               %.3f\n', baseline_metrics.DH_ratio_rad);
fprintf('  Convection Zone:\n');
fprintf('    Width (W):               %.3f m\n', baseline_metrics.W_conv);
fprintf('    Height (H):              %.3f m\n', baseline_metrics.H_conv);
fprintf('    Volume:                  %.4f m³\n', baseline_metrics.V_conv);
fprintf('    W/H Ratio:               %.3f\n', baseline_metrics.DH_ratio_conv);
fprintf('  Total:\n');
fprintf('    Total Volume:            %.4f m³\n', baseline_metrics.V_total);
fprintf('    Total Pressure Drop:     %.0f Pa (%.3f bar)\n', ...
    baseline_metrics.DP_total_Pa, baseline_metrics.DP_total_Pa/1e5);
fprintf('    Radiant DP:              %.0f Pa\n', baseline_metrics.DP_rad_Pa);
fprintf('    Convection DP:           %.0f Pa\n', baseline_metrics.DP_conv_Pa);

%% ========================================================================
%  PART 2: PARAMETRIC STUDY 1 - RADIANT ZONE GEOMETRY
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  PARAMETRIC STUDY 1: RADIANT ZONE GEOMETRY\n');
fprintf('================================================================\n');

% Parameters to vary for radiant zone (max 5):
% 1. D_coil_heat - coil diameter
% 2. p_coil_heat - coil pitch
% 3. D_shell_heat - shell diameter
% 4. d_tube_OD_heat - tube outer diameter

% Define parameter ranges
D_coil_range = linspace(0.7, 1.5, 8);      % m
p_coil_range = linspace(0.050, 0.100, 8);  % m
D_shell_range = linspace(1.0, 2.0, 8);     % m

% Study 1a: D_coil_heat sweep
fprintf('\nStudy 1a: Sweeping D_coil_heat...\n');
results_1a = struct('D_coil', [], 'V_rad', [], 'DH_rad', [], 'DP_total', [], 'status', []);

for i = 1:length(D_coil_range)
    params = struct();
    params.D_coil_heat = D_coil_range(i);
    % Adjust shell diameter to maintain clearance
    params.D_shell_heat = D_coil_range(i) + 0.4;

    try
        r = heater_design(params);
        H_rad = r.rad.H_coil_m;
        D_rad = params.D_shell_heat;
        V_rad = pi * (D_rad/2)^2 * H_rad;

        results_1a.D_coil(end+1) = D_coil_range(i);
        results_1a.V_rad(end+1) = V_rad;
        results_1a.DH_rad(end+1) = D_rad / H_rad;
        results_1a.DP_total(end+1) = r.dp.DP_total_Pa;
        results_1a.status(end+1) = r.status.all_pass;
    catch
        fprintf('  Warning: D_coil = %.2f m failed\n', D_coil_range(i));
    end
end

% Study 1b: p_coil_heat sweep
fprintf('Study 1b: Sweeping p_coil_heat...\n');
results_1b = struct('p_coil', [], 'V_rad', [], 'DH_rad', [], 'DP_total', [], 'status', []);

for i = 1:length(p_coil_range)
    params = struct();
    params.p_coil_heat = p_coil_range(i);

    try
        r = heater_design(params);
        H_rad = r.rad.H_coil_m;
        D_rad = r.params.D_shell_heat;
        V_rad = pi * (D_rad/2)^2 * H_rad;

        results_1b.p_coil(end+1) = p_coil_range(i);
        results_1b.V_rad(end+1) = V_rad;
        results_1b.DH_rad(end+1) = D_rad / H_rad;
        results_1b.DP_total(end+1) = r.dp.DP_total_Pa;
        results_1b.status(end+1) = r.status.all_pass;
    catch
        fprintf('  Warning: p_coil = %.3f m failed\n', p_coil_range(i));
    end
end

% Study 1c: D_shell_heat sweep
fprintf('Study 1c: Sweeping D_shell_heat...\n');
results_1c = struct('D_shell', [], 'V_rad', [], 'DH_rad', [], 'DP_total', [], 'status', []);

for i = 1:length(D_shell_range)
    params = struct();
    params.D_shell_heat = D_shell_range(i);
    % Adjust coil diameter to fit inside shell
    params.D_coil_heat = D_shell_range(i) - 0.4;

    if params.D_coil_heat < 0.5
        continue;
    end

    try
        r = heater_design(params);
        H_rad = r.rad.H_coil_m;
        D_rad = D_shell_range(i);
        V_rad = pi * (D_rad/2)^2 * H_rad;

        results_1c.D_shell(end+1) = D_shell_range(i);
        results_1c.V_rad(end+1) = V_rad;
        results_1c.DH_rad(end+1) = D_rad / H_rad;
        results_1c.DP_total(end+1) = r.dp.DP_total_Pa;
        results_1c.status(end+1) = r.status.all_pass;
    catch
        fprintf('  Warning: D_shell = %.2f m failed\n', D_shell_range(i));
    end
end

%% ========================================================================
%  PART 3: PARAMETRIC STUDY 2 - CONVECTION ZONE GEOMETRY
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  PARAMETRIC STUDY 2: CONVECTION ZONE GEOMETRY\n');
fprintf('================================================================\n');

% Parameters to vary for convection zone:
% 1. d_tube_OD_conv - tube outer diameter
% 2. p_conv_horizontal - horizontal pitch
% 3. n_conv_parallel - number of parallel passes

d_tube_conv_range = linspace(0.016, 0.032, 8);  % m
p_conv_h_range = linspace(0.040, 0.080, 8);      % m
n_parallel_range = 2:6;

% Study 2a: d_tube_OD_conv sweep
fprintf('\nStudy 2a: Sweeping d_tube_OD_conv...\n');
results_2a = struct('d_tube', [], 'V_conv', [], 'DH_conv', [], 'DP_total', [], 'status', []);

for i = 1:length(d_tube_conv_range)
    params = struct();
    params.d_tube_OD_conv = d_tube_conv_range(i);
    params.d_tube_ID_conv = d_tube_conv_range(i) - 0.008;  % maintain wall thickness
    params.p_conv_horizontal = 2.5 * d_tube_conv_range(i);
    params.p_conv_vertical = 2.5 * d_tube_conv_range(i);

    if params.d_tube_ID_conv < 0.006
        continue;
    end

    try
        r = heater_design(params);
        W_conv = r.conv.W_conv_m;
        H_conv = r.conv.n_rows * params.p_conv_vertical;
        V_conv = W_conv^2 * H_conv;

        results_2a.d_tube(end+1) = d_tube_conv_range(i);
        results_2a.V_conv(end+1) = V_conv;
        results_2a.DH_conv(end+1) = W_conv / max(H_conv, 0.01);
        results_2a.DP_total(end+1) = r.dp.DP_total_Pa;
        results_2a.status(end+1) = r.status.all_pass;
    catch
        fprintf('  Warning: d_tube_conv = %.3f m failed\n', d_tube_conv_range(i));
    end
end

% Study 2b: n_conv_parallel sweep
fprintf('Study 2b: Sweeping n_conv_parallel...\n');
results_2b = struct('n_parallel', [], 'V_conv', [], 'DH_conv', [], 'DP_total', [], 'status', []);

for i = 1:length(n_parallel_range)
    params = struct();
    params.n_conv_parallel = n_parallel_range(i);

    try
        r = heater_design(params);
        W_conv = r.conv.W_conv_m;
        H_conv = r.conv.n_rows * r.params.p_conv_vertical;
        V_conv = W_conv^2 * H_conv;

        results_2b.n_parallel(end+1) = n_parallel_range(i);
        results_2b.V_conv(end+1) = V_conv;
        results_2b.DH_conv(end+1) = W_conv / max(H_conv, 0.01);
        results_2b.DP_total(end+1) = r.dp.DP_total_Pa;
        results_2b.status(end+1) = r.status.all_pass;
    catch
        fprintf('  Warning: n_parallel = %d failed\n', n_parallel_range(i));
    end
end

%% ========================================================================
%  PART 4: COMBINED OPTIMIZATION STUDY (5 parameters)
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  PARAMETRIC STUDY 3: COMBINED 5-PARAMETER OPTIMIZATION\n');
fprintf('================================================================\n');

% Select 5 key parameters:
% 1. D_coil_heat
% 2. p_coil_heat
% 3. d_tube_OD_conv
% 4. n_conv_parallel
% 5. D_shell_heat (derived from D_coil)

% Reduced grid for computational efficiency
D_coil_opt = linspace(0.8, 1.2, 5);
p_coil_opt = linspace(0.055, 0.075, 4);
d_tube_conv_opt = linspace(0.018, 0.028, 4);
n_parallel_opt = [3, 4, 5];

% Store all valid results
all_results = [];
result_count = 0;
total_combinations = length(D_coil_opt) * length(p_coil_opt) * length(d_tube_conv_opt) * length(n_parallel_opt);
fprintf('Running %d parameter combinations...\n', total_combinations);

for i1 = 1:length(D_coil_opt)
    for i2 = 1:length(p_coil_opt)
        for i3 = 1:length(d_tube_conv_opt)
            for i4 = 1:length(n_parallel_opt)
                params = struct();
                params.D_coil_heat = D_coil_opt(i1);
                params.D_shell_heat = D_coil_opt(i1) + 0.4;
                params.p_coil_heat = p_coil_opt(i2);
                params.d_tube_OD_conv = d_tube_conv_opt(i3);
                params.d_tube_ID_conv = d_tube_conv_opt(i3) - 0.008;
                params.p_conv_horizontal = 2.5 * d_tube_conv_opt(i3);
                params.p_conv_vertical = 2.5 * d_tube_conv_opt(i3);
                params.n_conv_parallel = n_parallel_opt(i4);

                if params.d_tube_ID_conv < 0.006
                    continue;
                end

                try
                    r = heater_design(params);

                    % Calculate metrics
                    H_rad = r.rad.H_coil_m;
                    D_rad = params.D_shell_heat;
                    V_rad = pi * (D_rad/2)^2 * H_rad;
                    DH_rad = D_rad / H_rad;

                    W_conv = r.conv.W_conv_m;
                    H_conv = r.conv.n_rows * params.p_conv_vertical;
                    V_conv = W_conv^2 * H_conv;
                    DH_conv = W_conv / max(H_conv, 0.01);

                    V_total = V_rad + V_conv;
                    DP_total = r.dp.DP_total_Pa;

                    % Only keep if pressure drop constraint is met
                    if DP_total <= baseline_metrics.DP_total_Pa && r.status.all_pass
                        result_count = result_count + 1;
                        all_results(result_count).D_coil = D_coil_opt(i1);
                        all_results(result_count).p_coil = p_coil_opt(i2);
                        all_results(result_count).d_tube_conv = d_tube_conv_opt(i3);
                        all_results(result_count).n_parallel = n_parallel_opt(i4);
                        all_results(result_count).V_rad = V_rad;
                        all_results(result_count).V_conv = V_conv;
                        all_results(result_count).V_total = V_total;
                        all_results(result_count).DH_rad = DH_rad;
                        all_results(result_count).DH_conv = DH_conv;
                        all_results(result_count).DP_total = DP_total;
                        all_results(result_count).DP_reduction = (baseline_metrics.DP_total_Pa - DP_total) / baseline_metrics.DP_total_Pa * 100;
                    end
                catch
                    % Skip failed configurations
                end
            end
        end
    end
end

fprintf('Found %d valid configurations meeting pressure drop constraint.\n', result_count);

%% ========================================================================
%  PART 5: IDENTIFY OPTIMAL CONFIGURATIONS
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  OPTIMAL CONFIGURATIONS\n');
fprintf('================================================================\n');

if result_count > 0
    % Convert to arrays for analysis
    V_total_arr = [all_results.V_total];
    DH_rad_arr = [all_results.DH_rad];
    DH_conv_arr = [all_results.DH_conv];
    DP_arr = [all_results.DP_total];

    % Find optimal for each objective
    [~, idx_min_vol] = min(V_total_arr);
    [~, idx_min_DH_rad] = min(DH_rad_arr);
    [~, idx_min_DH_conv] = min(DH_conv_arr);

    % Combined objective: weighted sum (normalize each metric)
    V_norm = (V_total_arr - min(V_total_arr)) / (max(V_total_arr) - min(V_total_arr) + 1e-10);
    DH_rad_norm = (DH_rad_arr - min(DH_rad_arr)) / (max(DH_rad_arr) - min(DH_rad_arr) + 1e-10);
    DH_conv_norm = (DH_conv_arr - min(DH_conv_arr)) / (max(DH_conv_arr) - min(DH_conv_arr) + 1e-10);

    % Weighted objective (equal weights)
    combined_obj = 0.4*V_norm + 0.3*DH_rad_norm + 0.3*DH_conv_norm;
    [~, idx_best_combined] = min(combined_obj);

    % Print optimal configurations
    fprintf('\n--- Minimum Volume Configuration ---\n');
    print_config(all_results(idx_min_vol), baseline_metrics);

    fprintf('\n--- Minimum Radiant D/H Ratio Configuration ---\n');
    print_config(all_results(idx_min_DH_rad), baseline_metrics);

    fprintf('\n--- Minimum Convection D/H Ratio Configuration ---\n');
    print_config(all_results(idx_min_DH_conv), baseline_metrics);

    fprintf('\n--- Best Combined (Weighted) Configuration ---\n');
    print_config(all_results(idx_best_combined), baseline_metrics);

    optimal = all_results(idx_best_combined);
else
    fprintf('No valid configurations found! Relaxing constraints...\n');
    optimal = [];
end

%% ========================================================================
%  PART 6: GENERATE PLOTS
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  GENERATING PLOTS\n');
fprintf('================================================================\n');

% Plot 1: Radiant Zone - D_coil sweep
if ~isempty(results_1a.D_coil)
    fig1 = figure('Position', [100, 100, 1200, 500]);

    subplot(1,3,1);
    plot(results_1a.D_coil, results_1a.V_rad, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    hold on;
    yline(baseline_metrics.V_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Diameter D_{coil} (m)');
    ylabel('Radiant Zone Volume (m³)');
    title('Volume vs Coil Diameter');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,2);
    plot(results_1a.D_coil, results_1a.DH_rad, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
    hold on;
    yline(baseline_metrics.DH_ratio_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Diameter D_{coil} (m)');
    ylabel('D/H Ratio (Radiant)');
    title('D/H Ratio vs Coil Diameter');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,3);
    plot(results_1a.D_coil, results_1a.DP_total/1000, 'm-^', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    hold on;
    yline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Diameter D_{coil} (m)');
    ylabel('Total Pressure Drop (kPa)');
    title('Pressure Drop vs Coil Diameter');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    sgtitle('Parametric Study: Coil Diameter Effect on Radiant Zone', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig1, fullfile(results_folder, 'study1a_coil_diameter.png'));
    fprintf('Saved: study1a_coil_diameter.png\n');
end

% Plot 2: Radiant Zone - Coil Pitch sweep
if ~isempty(results_1b.p_coil)
    fig2 = figure('Position', [100, 100, 1200, 500]);

    subplot(1,3,1);
    plot(results_1b.p_coil*1000, results_1b.V_rad, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    hold on;
    yline(baseline_metrics.V_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Pitch p_{coil} (mm)');
    ylabel('Radiant Zone Volume (m³)');
    title('Volume vs Coil Pitch');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,2);
    plot(results_1b.p_coil*1000, results_1b.DH_rad, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
    hold on;
    yline(baseline_metrics.DH_ratio_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Pitch p_{coil} (mm)');
    ylabel('D/H Ratio (Radiant)');
    title('D/H Ratio vs Coil Pitch');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,3);
    plot(results_1b.p_coil*1000, results_1b.DP_total/1000, 'm-^', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    hold on;
    yline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Pitch p_{coil} (mm)');
    ylabel('Total Pressure Drop (kPa)');
    title('Pressure Drop vs Coil Pitch');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    sgtitle('Parametric Study: Coil Pitch Effect on Radiant Zone', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig2, fullfile(results_folder, 'study1b_coil_pitch.png'));
    fprintf('Saved: study1b_coil_pitch.png\n');
end

% Plot 3: Convection Zone - Tube Diameter sweep
if ~isempty(results_2a.d_tube)
    fig3 = figure('Position', [100, 100, 1200, 500]);

    subplot(1,3,1);
    plot(results_2a.d_tube*1000, results_2a.V_conv, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    hold on;
    yline(baseline_metrics.V_conv, 'r--', 'LineWidth', 1.5);
    xlabel('Tube OD (mm)');
    ylabel('Convection Zone Volume (m³)');
    title('Volume vs Tube Diameter');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,2);
    plot(results_2a.d_tube*1000, results_2a.DH_conv, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
    hold on;
    yline(baseline_metrics.DH_ratio_conv, 'r--', 'LineWidth', 1.5);
    xlabel('Tube OD (mm)');
    ylabel('W/H Ratio (Convection)');
    title('W/H Ratio vs Tube Diameter');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,3);
    plot(results_2a.d_tube*1000, results_2a.DP_total/1000, 'm-^', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    hold on;
    yline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 1.5);
    xlabel('Tube OD (mm)');
    ylabel('Total Pressure Drop (kPa)');
    title('Pressure Drop vs Tube Diameter');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    sgtitle('Parametric Study: Convection Tube Diameter Effect', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig3, fullfile(results_folder, 'study2a_conv_tube_diameter.png'));
    fprintf('Saved: study2a_conv_tube_diameter.png\n');
end

% Plot 4: Convection Zone - Parallel Passes sweep
if ~isempty(results_2b.n_parallel)
    fig4 = figure('Position', [100, 100, 1200, 500]);

    subplot(1,3,1);
    bar(results_2b.n_parallel, results_2b.V_conv, 'FaceColor', [0.3 0.5 0.8]);
    hold on;
    yline(baseline_metrics.V_conv, 'r--', 'LineWidth', 2);
    xlabel('Number of Parallel Passes');
    ylabel('Convection Zone Volume (m³)');
    title('Volume vs Parallel Passes');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,2);
    bar(results_2b.n_parallel, results_2b.DH_conv, 'FaceColor', [0.3 0.7 0.4]);
    hold on;
    yline(baseline_metrics.DH_ratio_conv, 'r--', 'LineWidth', 2);
    xlabel('Number of Parallel Passes');
    ylabel('W/H Ratio (Convection)');
    title('W/H Ratio vs Parallel Passes');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    subplot(1,3,3);
    bar(results_2b.n_parallel, results_2b.DP_total/1000, 'FaceColor', [0.7 0.3 0.5]);
    hold on;
    yline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 2);
    xlabel('Number of Parallel Passes');
    ylabel('Total Pressure Drop (kPa)');
    title('Pressure Drop vs Parallel Passes');
    legend('Parametric', 'Baseline', 'Location', 'best');
    grid on;

    sgtitle('Parametric Study: Number of Parallel Passes Effect', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig4, fullfile(results_folder, 'study2b_parallel_passes.png'));
    fprintf('Saved: study2b_parallel_passes.png\n');
end

% Plot 5: Combined Optimization Results (if available)
if result_count > 0
    fig5 = figure('Position', [100, 100, 1400, 600]);

    subplot(2,3,1);
    scatter([all_results.V_total], [all_results.DH_rad], 50, [all_results.DP_total]/1000, 'filled');
    colorbar;
    xlabel('Total Volume (m³)');
    ylabel('D/H Ratio (Radiant)');
    title('Volume vs Radiant D/H (color: DP in kPa)');
    grid on;

    subplot(2,3,2);
    scatter([all_results.V_total], [all_results.DH_conv], 50, [all_results.DP_total]/1000, 'filled');
    colorbar;
    xlabel('Total Volume (m³)');
    ylabel('W/H Ratio (Convection)');
    title('Volume vs Convection W/H (color: DP in kPa)');
    grid on;

    subplot(2,3,3);
    scatter([all_results.DH_rad], [all_results.DH_conv], 50, [all_results.V_total], 'filled');
    colorbar;
    xlabel('D/H Ratio (Radiant)');
    ylabel('W/H Ratio (Convection)');
    title('Radiant vs Convection Ratios (color: Volume in m³)');
    grid on;

    subplot(2,3,4);
    histogram([all_results.V_total], 15, 'FaceColor', [0.3 0.5 0.8]);
    hold on;
    xline(baseline_metrics.V_total, 'r--', 'LineWidth', 2);
    xlabel('Total Volume (m³)');
    ylabel('Count');
    title('Volume Distribution');
    legend('Results', 'Baseline');
    grid on;

    subplot(2,3,5);
    histogram([all_results.DP_total]/1000, 15, 'FaceColor', [0.7 0.3 0.5]);
    hold on;
    xline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 2);
    xlabel('Pressure Drop (kPa)');
    ylabel('Count');
    title('Pressure Drop Distribution');
    legend('Results', 'Baseline');
    grid on;

    subplot(2,3,6);
    % Pareto front approximation
    scatter([all_results.V_total], [all_results.DP_total]/1000, 50, combined_obj, 'filled');
    colorbar;
    hold on;
    plot(baseline_metrics.V_total, baseline_metrics.DP_total_Pa/1000, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    xlabel('Total Volume (m³)');
    ylabel('Pressure Drop (kPa)');
    title('Pareto Space (color: Combined Objective)');
    legend('Designs', 'Baseline', 'Location', 'best');
    grid on;

    sgtitle('Combined 5-Parameter Optimization Results', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig5, fullfile(results_folder, 'study3_combined_optimization.png'));
    fprintf('Saved: study3_combined_optimization.png\n');
end

% Plot 6: Comparison Bar Chart
fig6 = figure('Position', [100, 100, 1000, 600]);

if result_count > 0
    categories = {'Volume (m³)', 'D/H Radiant', 'W/H Convection', 'Pressure Drop (kPa)'};
    baseline_vals = [baseline_metrics.V_total, baseline_metrics.DH_ratio_rad, ...
                     baseline_metrics.DH_ratio_conv, baseline_metrics.DP_total_Pa/1000];
    optimal_vals = [optimal.V_total, optimal.DH_rad, optimal.DH_conv, optimal.DP_total/1000];

    X = categorical(categories);
    X = reordercats(X, categories);

    bar_data = [baseline_vals; optimal_vals]';

    b = bar(X, bar_data);
    b(1).FaceColor = [0.8 0.2 0.2];
    b(2).FaceColor = [0.2 0.6 0.2];

    legend('Baseline', 'Optimized', 'Location', 'northwest');
    ylabel('Value');
    title('Baseline vs Optimized Design Comparison', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;

    % Add percentage improvement labels
    for i = 1:length(categories)
        improvement = (baseline_vals(i) - optimal_vals(i)) / baseline_vals(i) * 100;
        if improvement > 0
            text(i, max(baseline_vals(i), optimal_vals(i)) * 1.05, ...
                sprintf('%.1f%% better', improvement), ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0 0.5 0]);
        end
    end
end

saveas(fig6, fullfile(results_folder, 'comparison_baseline_vs_optimized.png'));
fprintf('Saved: comparison_baseline_vs_optimized.png\n');

%% ========================================================================
%  PART 7: SAVE SUMMARY REPORT
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  SAVING SUMMARY REPORT\n');
fprintf('================================================================\n');

summary_file = fullfile(results_folder, 'optimization_summary.txt');
fid = fopen(summary_file, 'w');

fprintf(fid, '================================================================\n');
fprintf(fid, '  HEATER DESIGN PARAMETRIC OPTIMIZATION STUDY\n');
fprintf(fid, '  Generated: %s\n', datestr(now));
fprintf(fid, '================================================================\n\n');

fprintf(fid, 'OBJECTIVES:\n');
fprintf(fid, '  1. Minimize furnace total volume\n');
fprintf(fid, '  2. Minimize D/H ratio for radiant zone\n');
fprintf(fid, '  3. Minimize W/H ratio for convective zone\n');
fprintf(fid, '  4. Constraint: Pressure drop <= Baseline\n\n');

fprintf(fid, 'FIXED PARAMETERS:\n');
fprintf(fid, '  T_salt_in:        %.2f C\n', baseline.params.T_salt_in);
fprintf(fid, '  T_salt_out:       %.2f C\n', baseline.params.T_salt_out);
fprintf(fid, '  m_gas_factory:    %.6f kg/s\n', baseline.params.m_gas_factory);
fprintf(fid, '  m_oil:            %.6f kg/s\n', baseline.params.m_oil);
fprintf(fid, '\n');

fprintf(fid, '================================================================\n');
fprintf(fid, '  BASELINE DESIGN\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  Radiant Zone:\n');
fprintf(fid, '    D_coil_heat:    %.3f m\n', baseline.params.D_coil_heat);
fprintf(fid, '    D_shell_heat:   %.3f m\n', baseline.params.D_shell_heat);
fprintf(fid, '    p_coil_heat:    %.3f m\n', baseline.params.p_coil_heat);
fprintf(fid, '    Height:         %.3f m\n', baseline_metrics.H_rad);
fprintf(fid, '    Volume:         %.4f m³\n', baseline_metrics.V_rad);
fprintf(fid, '    D/H Ratio:      %.3f\n', baseline_metrics.DH_ratio_rad);
fprintf(fid, '  Convection Zone:\n');
fprintf(fid, '    d_tube_OD_conv: %.3f m\n', baseline.params.d_tube_OD_conv);
fprintf(fid, '    n_conv_parallel: %d\n', baseline.params.n_conv_parallel);
fprintf(fid, '    Width:          %.3f m\n', baseline_metrics.W_conv);
fprintf(fid, '    Height:         %.3f m\n', baseline_metrics.H_conv);
fprintf(fid, '    Volume:         %.4f m³\n', baseline_metrics.V_conv);
fprintf(fid, '    W/H Ratio:      %.3f\n', baseline_metrics.DH_ratio_conv);
fprintf(fid, '  Total:\n');
fprintf(fid, '    Total Volume:   %.4f m³\n', baseline_metrics.V_total);
fprintf(fid, '    Pressure Drop:  %.0f Pa (%.3f bar)\n', ...
    baseline_metrics.DP_total_Pa, baseline_metrics.DP_total_Pa/1e5);
fprintf(fid, '\n');

if result_count > 0
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  OPTIMIZED DESIGN (Best Combined Objective)\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  Parameters:\n');
    fprintf(fid, '    D_coil_heat:    %.3f m\n', optimal.D_coil);
    fprintf(fid, '    D_shell_heat:   %.3f m\n', optimal.D_coil + 0.4);
    fprintf(fid, '    p_coil_heat:    %.3f m\n', optimal.p_coil);
    fprintf(fid, '    d_tube_OD_conv: %.3f m\n', optimal.d_tube_conv);
    fprintf(fid, '    n_conv_parallel: %d\n', optimal.n_parallel);
    fprintf(fid, '  Results:\n');
    fprintf(fid, '    Radiant Volume:   %.4f m³ (%.1f%% change)\n', ...
        optimal.V_rad, (optimal.V_rad - baseline_metrics.V_rad)/baseline_metrics.V_rad*100);
    fprintf(fid, '    Convection Volume: %.4f m³ (%.1f%% change)\n', ...
        optimal.V_conv, (optimal.V_conv - baseline_metrics.V_conv)/baseline_metrics.V_conv*100);
    fprintf(fid, '    Total Volume:     %.4f m³ (%.1f%% change)\n', ...
        optimal.V_total, (optimal.V_total - baseline_metrics.V_total)/baseline_metrics.V_total*100);
    fprintf(fid, '    D/H Radiant:      %.3f (%.1f%% change)\n', ...
        optimal.DH_rad, (optimal.DH_rad - baseline_metrics.DH_ratio_rad)/baseline_metrics.DH_ratio_rad*100);
    fprintf(fid, '    W/H Convection:   %.3f (%.1f%% change)\n', ...
        optimal.DH_conv, (optimal.DH_conv - baseline_metrics.DH_ratio_conv)/baseline_metrics.DH_ratio_conv*100);
    fprintf(fid, '    Pressure Drop:    %.0f Pa (%.1f%% reduction)\n', ...
        optimal.DP_total, optimal.DP_reduction);
    fprintf(fid, '\n');

    fprintf(fid, '================================================================\n');
    fprintf(fid, '  KEY FINDINGS\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  Total valid configurations found: %d\n', result_count);
    fprintf(fid, '  Volume reduction achieved: %.1f%%\n', ...
        (baseline_metrics.V_total - optimal.V_total)/baseline_metrics.V_total*100);
    fprintf(fid, '  Pressure drop reduction: %.1f%%\n', optimal.DP_reduction);
    fprintf(fid, '\n');
end

fprintf(fid, '================================================================\n');
fprintf(fid, '  RECOMMENDATIONS FOR FURTHER OPTIMIZATION\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  1. Consider finer grid search around optimal region\n');
fprintf(fid, '  2. Investigate tube wall thickness optimization\n');
fprintf(fid, '  3. Explore alternative coil configurations\n');
fprintf(fid, '  4. Consider multi-objective Pareto optimization\n');
fprintf(fid, '  5. Validate with detailed CFD simulation\n');
fprintf(fid, '\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  END OF REPORT\n');
fprintf(fid, '================================================================\n');

fclose(fid);
fprintf('Saved: optimization_summary.txt\n');

%% Save workspace
save(fullfile(results_folder, 'parametric_study_data.mat'), ...
    'baseline', 'baseline_metrics', 'results_1a', 'results_1b', 'results_1c', ...
    'results_2a', 'results_2b', 'all_results', 'optimal');
fprintf('Saved: parametric_study_data.mat\n');

fprintf('\n================================================================\n');
fprintf('  PARAMETRIC STUDY COMPLETE\n');
fprintf('  Results saved to: %s\n', results_folder);
fprintf('================================================================\n');

%% ========================================================================
%  HELPER FUNCTION
%  ========================================================================
function print_config(cfg, baseline)
    fprintf('  D_coil_heat:      %.3f m\n', cfg.D_coil);
    fprintf('  p_coil_heat:      %.3f m\n', cfg.p_coil);
    fprintf('  d_tube_OD_conv:   %.3f m\n', cfg.d_tube_conv);
    fprintf('  n_conv_parallel:  %d\n', cfg.n_parallel);
    fprintf('  ---\n');
    fprintf('  V_total:          %.4f m³ (baseline: %.4f, change: %.1f%%)\n', ...
        cfg.V_total, baseline.V_total, (cfg.V_total - baseline.V_total)/baseline.V_total*100);
    fprintf('  D/H Radiant:      %.3f (baseline: %.3f, change: %.1f%%)\n', ...
        cfg.DH_rad, baseline.DH_ratio_rad, (cfg.DH_rad - baseline.DH_ratio_rad)/baseline.DH_ratio_rad*100);
    fprintf('  W/H Convection:   %.3f (baseline: %.3f, change: %.1f%%)\n', ...
        cfg.DH_conv, baseline.DH_ratio_conv, (cfg.DH_conv - baseline.DH_ratio_conv)/baseline.DH_ratio_conv*100);
    fprintf('  DP_total:         %.0f Pa (baseline: %.0f, reduction: %.1f%%)\n', ...
        cfg.DP_total, baseline.DP_total_Pa, cfg.DP_reduction);
end
