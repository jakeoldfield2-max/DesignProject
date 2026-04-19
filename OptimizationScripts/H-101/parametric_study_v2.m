%% PARAMETRIC STUDY V2 - REFINED OPTIMIZATION
% Enhanced study with relaxed constraints and deeper analysis
% Objectives:
%   1. Minimize furnace volume
%   2. Minimize D/H ratio for radiant zone
%   3. Minimize D/H ratio for convective zone
%   4. Minimize pressure drop (soft constraint)
%
% Author: Parametric Study Script v2
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
baseline_metrics.DH_ratio_conv = baseline_metrics.W_conv / max(baseline_metrics.H_conv, 0.01);

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

%% ========================================================================
%  PART 2: SINGLE PARAMETER SENSITIVITY STUDIES
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  SENSITIVITY ANALYSIS: INDIVIDUAL PARAMETERS\n');
fprintf('================================================================\n');

% Key insight: Pressure drop is dominated by radiant zone (47574 Pa vs 1862 Pa)
% Focus on parameters that affect radiant zone pressure drop

% Study A: Tube ID impact on pressure drop (larger ID = lower DP)
fprintf('\nStudy A: Tube Inner Diameter Effect...\n');
tube_ID_range = linspace(0.030, 0.050, 12);
results_A = struct('tube_ID', [], 'tube_OD', [], 'V_rad', [], 'DH_rad', [], ...
                   'DP_rad', [], 'DP_conv', [], 'DP_total', [], 'status', []);

for i = 1:length(tube_ID_range)
    params = struct();
    params.d_tube_ID_heat = tube_ID_range(i);
    params.d_tube_OD_heat = tube_ID_range(i) + 0.010;  % 10mm wall

    try
        r = heater_design(params);
        H_rad = r.rad.H_coil_m;
        D_rad = r.params.D_shell_heat;
        V_rad = pi * (D_rad/2)^2 * H_rad;

        results_A.tube_ID(end+1) = tube_ID_range(i);
        results_A.tube_OD(end+1) = params.d_tube_OD_heat;
        results_A.V_rad(end+1) = V_rad;
        results_A.DH_rad(end+1) = D_rad / H_rad;
        results_A.DP_rad(end+1) = r.dp.DP_total_rad_Pa;
        results_A.DP_conv(end+1) = r.dp.DP_total_conv_Pa;
        results_A.DP_total(end+1) = r.dp.DP_total_Pa;
        results_A.status(end+1) = r.status.all_pass;
    catch ME
        fprintf('  Warning: tube_ID = %.3f m failed: %s\n', tube_ID_range(i), ME.message);
    end
end

% Study B: Coil Diameter (D_coil_heat) - affects tube length and DP
fprintf('Study B: Coil Diameter Effect...\n');
D_coil_range = linspace(0.8, 1.6, 12);
results_B = struct('D_coil', [], 'D_shell', [], 'V_rad', [], 'DH_rad', [], ...
                   'DP_rad', [], 'DP_total', [], 'H_rad', [], 'status', []);

for i = 1:length(D_coil_range)
    params = struct();
    params.D_coil_heat = D_coil_range(i);
    params.D_shell_heat = D_coil_range(i) + 0.4;

    try
        r = heater_design(params);
        H_rad = r.rad.H_coil_m;
        D_rad = params.D_shell_heat;
        V_rad = pi * (D_rad/2)^2 * H_rad;

        results_B.D_coil(end+1) = D_coil_range(i);
        results_B.D_shell(end+1) = params.D_shell_heat;
        results_B.V_rad(end+1) = V_rad;
        results_B.DH_rad(end+1) = D_rad / H_rad;
        results_B.DP_rad(end+1) = r.dp.DP_total_rad_Pa;
        results_B.DP_total(end+1) = r.dp.DP_total_Pa;
        results_B.H_rad(end+1) = H_rad;
        results_B.status(end+1) = r.status.all_pass;
    catch ME
        fprintf('  Warning: D_coil = %.2f m failed: %s\n', D_coil_range(i), ME.message);
    end
end

% Study C: Coil Pitch Effect
fprintf('Study C: Coil Pitch Effect...\n');
p_coil_range = linspace(0.050, 0.120, 12);
results_C = struct('p_coil', [], 'V_rad', [], 'DH_rad', [], 'H_rad', [], ...
                   'DP_rad', [], 'DP_total', [], 'status', []);

for i = 1:length(p_coil_range)
    params = struct();
    params.p_coil_heat = p_coil_range(i);

    try
        r = heater_design(params);
        H_rad = r.rad.H_coil_m;
        D_rad = r.params.D_shell_heat;
        V_rad = pi * (D_rad/2)^2 * H_rad;

        results_C.p_coil(end+1) = p_coil_range(i);
        results_C.V_rad(end+1) = V_rad;
        results_C.DH_rad(end+1) = D_rad / H_rad;
        results_C.H_rad(end+1) = H_rad;
        results_C.DP_rad(end+1) = r.dp.DP_total_rad_Pa;
        results_C.DP_total(end+1) = r.dp.DP_total_Pa;
        results_C.status(end+1) = r.status.all_pass;
    catch ME
        fprintf('  Warning: p_coil = %.3f m failed: %s\n', p_coil_range(i), ME.message);
    end
end

% Study D: Convection tube diameter
fprintf('Study D: Convection Tube Diameter Effect...\n');
d_conv_range = linspace(0.016, 0.035, 12);
results_D = struct('d_conv', [], 'V_conv', [], 'DH_conv', [], 'H_conv', [], ...
                   'n_rows', [], 'DP_conv', [], 'DP_total', [], 'status', []);

for i = 1:length(d_conv_range)
    params = struct();
    params.d_tube_OD_conv = d_conv_range(i);
    params.d_tube_ID_conv = d_conv_range(i) - 0.008;
    params.p_conv_horizontal = 2.5 * d_conv_range(i);
    params.p_conv_vertical = 2.5 * d_conv_range(i);

    if params.d_tube_ID_conv < 0.006
        continue;
    end

    try
        r = heater_design(params);
        W_conv = r.conv.W_conv_m;
        H_conv = r.conv.n_rows * params.p_conv_vertical;
        V_conv = W_conv^2 * H_conv;

        results_D.d_conv(end+1) = d_conv_range(i);
        results_D.V_conv(end+1) = V_conv;
        results_D.DH_conv(end+1) = W_conv / max(H_conv, 0.01);
        results_D.H_conv(end+1) = H_conv;
        results_D.n_rows(end+1) = r.conv.n_rows;
        results_D.DP_conv(end+1) = r.dp.DP_total_conv_Pa;
        results_D.DP_total(end+1) = r.dp.DP_total_Pa;
        results_D.status(end+1) = r.status.all_pass;
    catch ME
        fprintf('  Warning: d_conv = %.3f m failed: %s\n', d_conv_range(i), ME.message);
    end
end

% Study E: Parallel passes
fprintf('Study E: Number of Parallel Passes Effect...\n');
n_parallel_range = 2:8;
results_E = struct('n_parallel', [], 'V_conv', [], 'DH_conv', [], ...
                   'DP_conv', [], 'DP_total', [], 'status', []);

for i = 1:length(n_parallel_range)
    params = struct();
    params.n_conv_parallel = n_parallel_range(i);

    try
        r = heater_design(params);
        W_conv = r.conv.W_conv_m;
        H_conv = r.conv.n_rows * r.params.p_conv_vertical;
        V_conv = W_conv^2 * H_conv;

        results_E.n_parallel(end+1) = n_parallel_range(i);
        results_E.V_conv(end+1) = V_conv;
        results_E.DH_conv(end+1) = W_conv / max(H_conv, 0.01);
        results_E.DP_conv(end+1) = r.dp.DP_total_conv_Pa;
        results_E.DP_total(end+1) = r.dp.DP_total_Pa;
        results_E.status(end+1) = r.status.all_pass;
    catch ME
        fprintf('  Warning: n_parallel = %d failed: %s\n', n_parallel_range(i), ME.message);
    end
end

%% ========================================================================
%  PART 3: COMBINED 5-PARAMETER OPTIMIZATION
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  COMBINED 5-PARAMETER OPTIMIZATION\n');
fprintf('================================================================\n');

% Based on sensitivity analysis, focus on:
% 1. d_tube_ID_heat (most impact on DP)
% 2. D_coil_heat
% 3. p_coil_heat
% 4. d_tube_OD_conv
% 5. n_conv_parallel

% Parameter ranges (refined based on sensitivity)
tube_ID_opt = linspace(0.035, 0.048, 4);   % Larger for lower DP
D_coil_opt = linspace(0.9, 1.3, 4);
p_coil_opt = linspace(0.055, 0.080, 4);
d_conv_opt = linspace(0.020, 0.030, 3);
n_parallel_opt = [4, 5, 6];

% Store all results (no hard constraint on DP)
all_results = [];
result_count = 0;
total_combinations = length(tube_ID_opt) * length(D_coil_opt) * length(p_coil_opt) * ...
                     length(d_conv_opt) * length(n_parallel_opt);
fprintf('Running %d parameter combinations...\n', total_combinations);

progress_interval = max(1, floor(total_combinations / 20));
combo_count = 0;

for i1 = 1:length(tube_ID_opt)
    for i2 = 1:length(D_coil_opt)
        for i3 = 1:length(p_coil_opt)
            for i4 = 1:length(d_conv_opt)
                for i5 = 1:length(n_parallel_opt)
                    combo_count = combo_count + 1;
                    if mod(combo_count, progress_interval) == 0
                        fprintf('  Progress: %d/%d (%.0f%%)\n', ...
                            combo_count, total_combinations, combo_count/total_combinations*100);
                    end

                    params = struct();
                    params.d_tube_ID_heat = tube_ID_opt(i1);
                    params.d_tube_OD_heat = tube_ID_opt(i1) + 0.010;
                    params.D_coil_heat = D_coil_opt(i2);
                    params.D_shell_heat = D_coil_opt(i2) + 0.4;
                    params.p_coil_heat = p_coil_opt(i3);
                    params.d_tube_OD_conv = d_conv_opt(i4);
                    params.d_tube_ID_conv = d_conv_opt(i4) - 0.008;
                    params.p_conv_horizontal = 2.5 * d_conv_opt(i4);
                    params.p_conv_vertical = 2.5 * d_conv_opt(i4);
                    params.n_conv_parallel = n_parallel_opt(i5);

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

                        result_count = result_count + 1;
                        all_results(result_count).tube_ID = tube_ID_opt(i1);
                        all_results(result_count).D_coil = D_coil_opt(i2);
                        all_results(result_count).p_coil = p_coil_opt(i3);
                        all_results(result_count).d_conv = d_conv_opt(i4);
                        all_results(result_count).n_parallel = n_parallel_opt(i5);
                        all_results(result_count).V_rad = V_rad;
                        all_results(result_count).V_conv = V_conv;
                        all_results(result_count).V_total = V_total;
                        all_results(result_count).DH_rad = DH_rad;
                        all_results(result_count).DH_conv = DH_conv;
                        all_results(result_count).DP_total = DP_total;
                        all_results(result_count).DP_rad = r.dp.DP_total_rad_Pa;
                        all_results(result_count).DP_conv = r.dp.DP_total_conv_Pa;
                        all_results(result_count).H_rad = H_rad;
                        all_results(result_count).H_conv = H_conv;
                        all_results(result_count).status = r.status.all_pass;
                        all_results(result_count).DP_vs_baseline = DP_total <= baseline_metrics.DP_total_Pa;
                    catch
                        % Skip failed configurations
                    end
                end
            end
        end
    end
end

fprintf('Total valid configurations: %d\n', result_count);

%% ========================================================================
%  PART 4: IDENTIFY OPTIMAL CONFIGURATIONS
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  OPTIMAL CONFIGURATIONS ANALYSIS\n');
fprintf('================================================================\n');

if result_count > 0
    % Convert to arrays
    V_total_arr = [all_results.V_total];
    V_rad_arr = [all_results.V_rad];
    V_conv_arr = [all_results.V_conv];
    DH_rad_arr = [all_results.DH_rad];
    DH_conv_arr = [all_results.DH_conv];
    DP_arr = [all_results.DP_total];
    status_arr = [all_results.status];
    DP_ok_arr = [all_results.DP_vs_baseline];

    % Filter for those meeting pressure constraint
    valid_idx = find(DP_ok_arr);
    fprintf('Configurations meeting DP constraint: %d\n', length(valid_idx));

    % If no valid configs, relax constraint
    if isempty(valid_idx)
        fprintf('Relaxing constraint: using top 20%% by DP...\n');
        [~, sorted_idx] = sort(DP_arr);
        valid_idx = sorted_idx(1:ceil(0.2*length(sorted_idx)));
    end

    % Find optimal configurations within valid set
    valid_V = V_total_arr(valid_idx);
    valid_DH_rad = DH_rad_arr(valid_idx);
    valid_DH_conv = DH_conv_arr(valid_idx);
    valid_DP = DP_arr(valid_idx);

    % Minimum volume
    [~, idx_min_vol_local] = min(valid_V);
    idx_min_vol = valid_idx(idx_min_vol_local);

    % Minimum D/H radiant
    [~, idx_min_DH_rad_local] = min(valid_DH_rad);
    idx_min_DH_rad = valid_idx(idx_min_DH_rad_local);

    % Minimum D/H convection
    [~, idx_min_DH_conv_local] = min(valid_DH_conv);
    idx_min_DH_conv = valid_idx(idx_min_DH_conv_local);

    % Minimum pressure drop
    [~, idx_min_DP_local] = min(valid_DP);
    idx_min_DP = valid_idx(idx_min_DP_local);

    % Combined objective (weighted sum - normalize each metric)
    V_norm = (valid_V - min(valid_V)) / (max(valid_V) - min(valid_V) + 1e-10);
    DH_rad_norm = (valid_DH_rad - min(valid_DH_rad)) / (max(valid_DH_rad) - min(valid_DH_rad) + 1e-10);
    DH_conv_norm = (valid_DH_conv - min(valid_DH_conv)) / (max(valid_DH_conv) - min(valid_DH_conv) + 1e-10);
    DP_norm = (valid_DP - min(valid_DP)) / (max(valid_DP) - min(valid_DP) + 1e-10);

    % Weighted objective
    w_vol = 0.35;
    w_DH_rad = 0.25;
    w_DH_conv = 0.20;
    w_DP = 0.20;

    combined_obj = w_vol*V_norm + w_DH_rad*DH_rad_norm + w_DH_conv*DH_conv_norm + w_DP*DP_norm;
    [~, idx_best_local] = min(combined_obj);
    idx_best = valid_idx(idx_best_local);

    % Print results
    fprintf('\n--- Minimum Volume Configuration ---\n');
    print_config_v2(all_results(idx_min_vol), baseline_metrics);

    fprintf('\n--- Minimum Radiant D/H Configuration ---\n');
    print_config_v2(all_results(idx_min_DH_rad), baseline_metrics);

    fprintf('\n--- Minimum Convection W/H Configuration ---\n');
    print_config_v2(all_results(idx_min_DH_conv), baseline_metrics);

    fprintf('\n--- Minimum Pressure Drop Configuration ---\n');
    print_config_v2(all_results(idx_min_DP), baseline_metrics);

    fprintf('\n--- Best Combined (Weighted) Configuration ---\n');
    print_config_v2(all_results(idx_best), baseline_metrics);

    optimal = all_results(idx_best);
    optimal_min_vol = all_results(idx_min_vol);
    optimal_min_DP = all_results(idx_min_DP);
else
    fprintf('No valid configurations found!\n');
    optimal = [];
    optimal_min_vol = [];
    optimal_min_DP = [];
end

%% ========================================================================
%  PART 5: GENERATE PLOTS
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  GENERATING PLOTS\n');
fprintf('================================================================\n');

% Plot 1: Tube ID Sensitivity
if ~isempty(results_A.tube_ID)
    fig1 = figure('Position', [100, 100, 1400, 450]);

    subplot(1,4,1);
    yyaxis left
    plot(results_A.tube_ID*1000, results_A.DP_rad/1000, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    ylabel('Radiant DP (kPa)');
    yyaxis right
    plot(results_A.tube_ID*1000, results_A.DP_total/1000, 'r-s', 'LineWidth', 2, 'MarkerFaceColor', 'r');
    ylabel('Total DP (kPa)');
    xlabel('Tube Inner Diameter (mm)');
    title('Pressure Drop vs Tube ID');
    legend('Radiant DP', 'Total DP', 'Location', 'best');
    grid on;

    subplot(1,4,2);
    plot(results_A.tube_ID*1000, results_A.V_rad, 'g-^', 'LineWidth', 2, 'MarkerFaceColor', 'g');
    hold on;
    yline(baseline_metrics.V_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Tube Inner Diameter (mm)');
    ylabel('Radiant Volume (m³)');
    title('Volume vs Tube ID');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,3);
    plot(results_A.tube_ID*1000, results_A.DH_rad, 'm-d', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    hold on;
    yline(baseline_metrics.DH_ratio_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Tube Inner Diameter (mm)');
    ylabel('D/H Ratio');
    title('D/H Ratio vs Tube ID');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,4);
    bar(results_A.tube_ID*1000, results_A.status, 'FaceColor', [0.2 0.6 0.2]);
    xlabel('Tube Inner Diameter (mm)');
    ylabel('Status Pass (1=yes)');
    title('Design Validity');
    ylim([0 1.2]);
    grid on;

    sgtitle('Sensitivity Study A: Radiant Tube Inner Diameter', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig1, fullfile(results_folder, 'sensitivity_tube_ID.png'));
    fprintf('Saved: sensitivity_tube_ID.png\n');
end

% Plot 2: Coil Diameter Sensitivity
if ~isempty(results_B.D_coil)
    fig2 = figure('Position', [100, 100, 1400, 450]);

    subplot(1,4,1);
    plot(results_B.D_coil, results_B.DP_total/1000, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    hold on;
    yline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Diameter (m)');
    ylabel('Total DP (kPa)');
    title('Pressure Drop vs Coil Diameter');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,2);
    plot(results_B.D_coil, results_B.V_rad, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
    hold on;
    yline(baseline_metrics.V_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Diameter (m)');
    ylabel('Radiant Volume (m³)');
    title('Volume vs Coil Diameter');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,3);
    plot(results_B.D_coil, results_B.DH_rad, 'm-^', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    hold on;
    yline(baseline_metrics.DH_ratio_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Diameter (m)');
    ylabel('D/H Ratio');
    title('D/H Ratio vs Coil Diameter');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,4);
    plot(results_B.D_coil, results_B.H_rad, 'c-d', 'LineWidth', 2, 'MarkerFaceColor', 'c');
    hold on;
    yline(baseline_metrics.H_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Diameter (m)');
    ylabel('Coil Height (m)');
    title('Height vs Coil Diameter');
    legend('Parametric', 'Baseline');
    grid on;

    sgtitle('Sensitivity Study B: Coil Diameter', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig2, fullfile(results_folder, 'sensitivity_coil_diameter.png'));
    fprintf('Saved: sensitivity_coil_diameter.png\n');
end

% Plot 3: Coil Pitch Sensitivity
if ~isempty(results_C.p_coil)
    fig3 = figure('Position', [100, 100, 1200, 450]);

    subplot(1,3,1);
    plot(results_C.p_coil*1000, results_C.DP_total/1000, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    hold on;
    yline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Pitch (mm)');
    ylabel('Total DP (kPa)');
    title('Pressure Drop vs Coil Pitch');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,3,2);
    yyaxis left
    plot(results_C.p_coil*1000, results_C.V_rad, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
    ylabel('Volume (m³)');
    yyaxis right
    plot(results_C.p_coil*1000, results_C.H_rad, 'c-^', 'LineWidth', 2, 'MarkerFaceColor', 'c');
    ylabel('Height (m)');
    xlabel('Coil Pitch (mm)');
    title('Volume & Height vs Coil Pitch');
    legend('Volume', 'Height');
    grid on;

    subplot(1,3,3);
    plot(results_C.p_coil*1000, results_C.DH_rad, 'm-d', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    hold on;
    yline(baseline_metrics.DH_ratio_rad, 'r--', 'LineWidth', 1.5);
    xlabel('Coil Pitch (mm)');
    ylabel('D/H Ratio');
    title('D/H Ratio vs Coil Pitch');
    legend('Parametric', 'Baseline');
    grid on;

    sgtitle('Sensitivity Study C: Coil Pitch', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig3, fullfile(results_folder, 'sensitivity_coil_pitch.png'));
    fprintf('Saved: sensitivity_coil_pitch.png\n');
end

% Plot 4: Convection Tube Diameter
if ~isempty(results_D.d_conv)
    fig4 = figure('Position', [100, 100, 1400, 450]);

    subplot(1,4,1);
    plot(results_D.d_conv*1000, results_D.DP_conv/1000, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
    hold on;
    yline(baseline_metrics.DP_conv_Pa/1000, 'r--', 'LineWidth', 1.5);
    xlabel('Conv Tube OD (mm)');
    ylabel('Convection DP (kPa)');
    title('Convection DP vs Tube OD');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,2);
    plot(results_D.d_conv*1000, results_D.V_conv, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
    hold on;
    yline(baseline_metrics.V_conv, 'r--', 'LineWidth', 1.5);
    xlabel('Conv Tube OD (mm)');
    ylabel('Convection Volume (m³)');
    title('Volume vs Tube OD');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,3);
    plot(results_D.d_conv*1000, results_D.DH_conv, 'm-^', 'LineWidth', 2, 'MarkerFaceColor', 'm');
    hold on;
    yline(baseline_metrics.DH_ratio_conv, 'r--', 'LineWidth', 1.5);
    xlabel('Conv Tube OD (mm)');
    ylabel('W/H Ratio');
    title('W/H Ratio vs Tube OD');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,4,4);
    bar(results_D.d_conv*1000, results_D.n_rows, 'FaceColor', [0.4 0.6 0.8]);
    hold on;
    yline(baseline_metrics.n_rows_conv, 'r--', 'LineWidth', 2);
    xlabel('Conv Tube OD (mm)');
    ylabel('Number of Rows');
    title('Rows vs Tube OD');
    grid on;

    sgtitle('Sensitivity Study D: Convection Tube Diameter', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig4, fullfile(results_folder, 'sensitivity_conv_tube.png'));
    fprintf('Saved: sensitivity_conv_tube.png\n');
end

% Plot 5: Parallel Passes
if ~isempty(results_E.n_parallel)
    fig5 = figure('Position', [100, 100, 1200, 450]);

    subplot(1,3,1);
    bar(results_E.n_parallel, results_E.DP_total/1000, 'FaceColor', [0.3 0.5 0.8]);
    hold on;
    yline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 2);
    xlabel('Number of Parallel Passes');
    ylabel('Total DP (kPa)');
    title('Pressure Drop vs Parallel Passes');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,3,2);
    bar(results_E.n_parallel, results_E.V_conv, 'FaceColor', [0.3 0.7 0.4]);
    hold on;
    yline(baseline_metrics.V_conv, 'r--', 'LineWidth', 2);
    xlabel('Number of Parallel Passes');
    ylabel('Convection Volume (m³)');
    title('Volume vs Parallel Passes');
    legend('Parametric', 'Baseline');
    grid on;

    subplot(1,3,3);
    bar(results_E.n_parallel, results_E.DH_conv, 'FaceColor', [0.7 0.3 0.5]);
    hold on;
    yline(baseline_metrics.DH_ratio_conv, 'r--', 'LineWidth', 2);
    xlabel('Number of Parallel Passes');
    ylabel('W/H Ratio');
    title('W/H Ratio vs Parallel Passes');
    legend('Parametric', 'Baseline');
    grid on;

    sgtitle('Sensitivity Study E: Number of Parallel Passes', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig5, fullfile(results_folder, 'sensitivity_parallel_passes.png'));
    fprintf('Saved: sensitivity_parallel_passes.png\n');
end

% Plot 6: Combined Optimization Results
if result_count > 0
    fig6 = figure('Position', [100, 100, 1600, 800]);

    % Top row: 2D scatter plots
    subplot(2,4,1);
    scatter(V_total_arr, DP_arr/1000, 30, status_arr, 'filled');
    hold on;
    plot(baseline_metrics.V_total, baseline_metrics.DP_total_Pa/1000, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    if ~isempty(optimal)
        plot(optimal.V_total, optimal.DP_total/1000, 'g^', 'MarkerSize', 12, 'MarkerFaceColor', 'g');
    end
    xlabel('Total Volume (m³)');
    ylabel('Pressure Drop (kPa)');
    title('Volume vs DP (color: status)');
    colorbar;
    grid on;

    subplot(2,4,2);
    scatter(V_rad_arr, DH_rad_arr, 30, DP_arr/1000, 'filled');
    hold on;
    plot(baseline_metrics.V_rad, baseline_metrics.DH_ratio_rad, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    xlabel('Radiant Volume (m³)');
    ylabel('D/H Radiant');
    title('Radiant Zone (color: DP kPa)');
    colorbar;
    grid on;

    subplot(2,4,3);
    scatter(V_conv_arr, DH_conv_arr, 30, DP_arr/1000, 'filled');
    hold on;
    plot(baseline_metrics.V_conv, baseline_metrics.DH_ratio_conv, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    xlabel('Convection Volume (m³)');
    ylabel('W/H Convection');
    title('Convection Zone (color: DP kPa)');
    colorbar;
    grid on;

    subplot(2,4,4);
    scatter(DH_rad_arr, DH_conv_arr, 30, V_total_arr, 'filled');
    hold on;
    plot(baseline_metrics.DH_ratio_rad, baseline_metrics.DH_ratio_conv, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    xlabel('D/H Radiant');
    ylabel('W/H Convection');
    title('Aspect Ratios (color: Volume m³)');
    colorbar;
    grid on;

    % Bottom row: Histograms
    subplot(2,4,5);
    histogram(V_total_arr, 20, 'FaceColor', [0.3 0.5 0.8], 'FaceAlpha', 0.7);
    hold on;
    xline(baseline_metrics.V_total, 'r--', 'LineWidth', 2);
    if ~isempty(optimal)
        xline(optimal.V_total, 'g-', 'LineWidth', 2);
    end
    xlabel('Total Volume (m³)');
    ylabel('Count');
    title('Volume Distribution');
    legend('Results', 'Baseline', 'Optimal');
    grid on;

    subplot(2,4,6);
    histogram(DP_arr/1000, 20, 'FaceColor', [0.7 0.3 0.5], 'FaceAlpha', 0.7);
    hold on;
    xline(baseline_metrics.DP_total_Pa/1000, 'r--', 'LineWidth', 2);
    if ~isempty(optimal)
        xline(optimal.DP_total/1000, 'g-', 'LineWidth', 2);
    end
    xlabel('Pressure Drop (kPa)');
    ylabel('Count');
    title('DP Distribution');
    legend('Results', 'Baseline', 'Optimal');
    grid on;

    subplot(2,4,7);
    histogram(DH_rad_arr, 20, 'FaceColor', [0.3 0.7 0.4], 'FaceAlpha', 0.7);
    hold on;
    xline(baseline_metrics.DH_ratio_rad, 'r--', 'LineWidth', 2);
    xlabel('D/H Radiant');
    ylabel('Count');
    title('Radiant D/H Distribution');
    legend('Results', 'Baseline');
    grid on;

    subplot(2,4,8);
    histogram(DH_conv_arr, 20, 'FaceColor', [0.8 0.6 0.2], 'FaceAlpha', 0.7);
    hold on;
    xline(baseline_metrics.DH_ratio_conv, 'r--', 'LineWidth', 2);
    xlabel('W/H Convection');
    ylabel('Count');
    title('Convection W/H Distribution');
    legend('Results', 'Baseline');
    grid on;

    sgtitle('Combined 5-Parameter Optimization Results', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig6, fullfile(results_folder, 'combined_optimization_results.png'));
    fprintf('Saved: combined_optimization_results.png\n');
end

% Plot 7: Comparison Summary
if ~isempty(optimal)
    fig7 = figure('Position', [100, 100, 1200, 500]);

    subplot(1,2,1);
    categories = {'Total Vol', 'Rad Vol', 'Conv Vol', 'D/H Rad', 'W/H Conv'};
    baseline_vals = [baseline_metrics.V_total, baseline_metrics.V_rad, baseline_metrics.V_conv, ...
                     baseline_metrics.DH_ratio_rad, baseline_metrics.DH_ratio_conv];
    optimal_vals = [optimal.V_total, optimal.V_rad, optimal.V_conv, optimal.DH_rad, optimal.DH_conv];

    X = categorical(categories);
    X = reordercats(X, categories);
    bar_data = [baseline_vals; optimal_vals]';

    b = bar(X, bar_data);
    b(1).FaceColor = [0.8 0.2 0.2];
    b(2).FaceColor = [0.2 0.6 0.2];
    legend('Baseline', 'Optimized', 'Location', 'northwest');
    ylabel('Value');
    title('Geometry Comparison');
    grid on;

    % Add improvement percentages
    for i = 1:length(categories)
        improvement = (baseline_vals(i) - optimal_vals(i)) / baseline_vals(i) * 100;
        y_pos = max(baseline_vals(i), optimal_vals(i)) * 1.1;
        if improvement > 0
            text(i, y_pos, sprintf('-%.1f%%', improvement), ...
                'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0 0.5 0]);
        elseif improvement < 0
            text(i, y_pos, sprintf('+%.1f%%', abs(improvement)), ...
                'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.8 0 0]);
        end
    end

    subplot(1,2,2);
    categories2 = {'Total DP', 'Radiant DP', 'Conv DP'};
    baseline_DP = [baseline_metrics.DP_total_Pa, baseline_metrics.DP_rad_Pa, baseline_metrics.DP_conv_Pa]/1000;
    optimal_DP = [optimal.DP_total, optimal.DP_rad, optimal.DP_conv]/1000;

    X2 = categorical(categories2);
    X2 = reordercats(X2, categories2);
    bar_data2 = [baseline_DP; optimal_DP]';

    b2 = bar(X2, bar_data2);
    b2(1).FaceColor = [0.8 0.2 0.2];
    b2(2).FaceColor = [0.2 0.6 0.2];
    legend('Baseline', 'Optimized', 'Location', 'northeast');
    ylabel('Pressure Drop (kPa)');
    title('Pressure Drop Comparison');
    grid on;

    % Add improvement percentages
    for i = 1:length(categories2)
        improvement = (baseline_DP(i) - optimal_DP(i)) / baseline_DP(i) * 100;
        y_pos = max(baseline_DP(i), optimal_DP(i)) * 1.1;
        if improvement > 0
            text(i, y_pos, sprintf('-%.1f%%', improvement), ...
                'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0 0.5 0]);
        end
    end

    sgtitle('Baseline vs Optimized Design Comparison', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig7, fullfile(results_folder, 'baseline_vs_optimized.png'));
    fprintf('Saved: baseline_vs_optimized.png\n');
end

% Plot 8: Trade-off Pareto Front
if result_count > 0
    fig8 = figure('Position', [100, 100, 1000, 800]);

    % 3D scatter
    subplot(2,2,[1 2]);
    scatter3(V_total_arr, DH_rad_arr, DH_conv_arr, 40, DP_arr/1000, 'filled');
    hold on;
    plot3(baseline_metrics.V_total, baseline_metrics.DH_ratio_rad, baseline_metrics.DH_ratio_conv, ...
          'rp', 'MarkerSize', 20, 'MarkerFaceColor', 'r');
    if ~isempty(optimal)
        plot3(optimal.V_total, optimal.DH_rad, optimal.DH_conv, ...
              'g^', 'MarkerSize', 15, 'MarkerFaceColor', 'g');
    end
    xlabel('Total Volume (m³)');
    ylabel('D/H Radiant');
    zlabel('W/H Convection');
    title('3D Design Space (color: DP in kPa)');
    colorbar;
    view(45, 30);
    grid on;
    legend('Designs', 'Baseline', 'Optimal', 'Location', 'best');

    subplot(2,2,3);
    % Pareto front: Volume vs DP
    scatter(V_total_arr, DP_arr/1000, 30, DH_rad_arr, 'filled');
    hold on;
    plot(baseline_metrics.V_total, baseline_metrics.DP_total_Pa/1000, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    xlabel('Total Volume (m³)');
    ylabel('Pressure Drop (kPa)');
    title('Volume vs DP Trade-off (color: D/H Rad)');
    colorbar;
    grid on;

    subplot(2,2,4);
    % Pareto front: D/H_rad vs D/H_conv
    scatter(DH_rad_arr, DH_conv_arr, 30, V_total_arr, 'filled');
    hold on;
    plot(baseline_metrics.DH_ratio_rad, baseline_metrics.DH_ratio_conv, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
    xlabel('D/H Radiant');
    ylabel('W/H Convection');
    title('Aspect Ratio Trade-off (color: Volume m³)');
    colorbar;
    grid on;

    sgtitle('Design Trade-off Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig8, fullfile(results_folder, 'tradeoff_analysis.png'));
    fprintf('Saved: tradeoff_analysis.png\n');
end

%% ========================================================================
%  PART 6: SAVE COMPREHENSIVE SUMMARY
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  SAVING COMPREHENSIVE SUMMARY\n');
fprintf('================================================================\n');

summary_file = fullfile(results_folder, 'optimization_summary.txt');
fid = fopen(summary_file, 'w');

fprintf(fid, '================================================================\n');
fprintf(fid, '  HEATER DESIGN PARAMETRIC OPTIMIZATION STUDY - V2\n');
fprintf(fid, '  Generated: %s\n', datestr(now));
fprintf(fid, '================================================================\n\n');

fprintf(fid, 'OBJECTIVES:\n');
fprintf(fid, '  1. Minimize furnace total volume\n');
fprintf(fid, '  2. Minimize D/H ratio for radiant zone\n');
fprintf(fid, '  3. Minimize W/H ratio for convective zone\n');
fprintf(fid, '  4. Minimize pressure drop (soft constraint)\n\n');

fprintf(fid, 'METHODOLOGY:\n');
fprintf(fid, '  - Single parameter sensitivity studies (5 parameters)\n');
fprintf(fid, '  - Combined 5-parameter grid optimization\n');
fprintf(fid, '  - Weighted multi-objective scoring\n\n');

fprintf(fid, 'FIXED PARAMETERS:\n');
fprintf(fid, '  T_salt_in:        %.2f C\n', baseline.params.T_salt_in);
fprintf(fid, '  T_salt_out:       %.2f C\n', baseline.params.T_salt_out);
fprintf(fid, '  m_gas_factory:    %.6f kg/s\n', baseline.params.m_gas_factory);
fprintf(fid, '  m_oil:            %.6f kg/s\n', baseline.params.m_oil);
fprintf(fid, '\n');

fprintf(fid, 'VARIABLE PARAMETERS (5 total):\n');
fprintf(fid, '  1. d_tube_ID_heat  - Radiant tube inner diameter\n');
fprintf(fid, '  2. D_coil_heat     - Radiant coil diameter\n');
fprintf(fid, '  3. p_coil_heat     - Radiant coil pitch\n');
fprintf(fid, '  4. d_tube_OD_conv  - Convection tube outer diameter\n');
fprintf(fid, '  5. n_conv_parallel - Number of parallel convection passes\n');
fprintf(fid, '\n');

fprintf(fid, '================================================================\n');
fprintf(fid, '  BASELINE DESIGN\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  Parameters:\n');
fprintf(fid, '    d_tube_ID_heat: %.3f m (OD: %.3f m)\n', baseline.params.d_tube_ID_heat, baseline.params.d_tube_OD_heat);
fprintf(fid, '    D_coil_heat:    %.3f m\n', baseline.params.D_coil_heat);
fprintf(fid, '    D_shell_heat:   %.3f m\n', baseline.params.D_shell_heat);
fprintf(fid, '    p_coil_heat:    %.3f m\n', baseline.params.p_coil_heat);
fprintf(fid, '    d_tube_OD_conv: %.3f m (ID: %.3f m)\n', baseline.params.d_tube_OD_conv, baseline.params.d_tube_ID_conv);
fprintf(fid, '    n_conv_parallel: %d\n', baseline.params.n_conv_parallel);
fprintf(fid, '  Radiant Zone:\n');
fprintf(fid, '    Height:         %.3f m\n', baseline_metrics.H_rad);
fprintf(fid, '    Volume:         %.4f m³\n', baseline_metrics.V_rad);
fprintf(fid, '    D/H Ratio:      %.3f\n', baseline_metrics.DH_ratio_rad);
fprintf(fid, '  Convection Zone:\n');
fprintf(fid, '    Width:          %.3f m\n', baseline_metrics.W_conv);
fprintf(fid, '    Height:         %.3f m\n', baseline_metrics.H_conv);
fprintf(fid, '    Volume:         %.4f m³\n', baseline_metrics.V_conv);
fprintf(fid, '    W/H Ratio:      %.3f\n', baseline_metrics.DH_ratio_conv);
fprintf(fid, '  Total:\n');
fprintf(fid, '    Total Volume:   %.4f m³\n', baseline_metrics.V_total);
fprintf(fid, '    Radiant DP:     %.0f Pa (%.2f bar)\n', baseline_metrics.DP_rad_Pa, baseline_metrics.DP_rad_Pa/1e5);
fprintf(fid, '    Convection DP:  %.0f Pa\n', baseline_metrics.DP_conv_Pa);
fprintf(fid, '    Total DP:       %.0f Pa (%.3f bar)\n', baseline_metrics.DP_total_Pa, baseline_metrics.DP_total_Pa/1e5);
fprintf(fid, '\n');

fprintf(fid, '================================================================\n');
fprintf(fid, '  SENSITIVITY ANALYSIS KEY FINDINGS\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  1. Tube Inner Diameter (d_tube_ID_heat):\n');
fprintf(fid, '     - STRONGEST impact on pressure drop\n');
fprintf(fid, '     - Larger ID dramatically reduces DP (DP ~ 1/ID^5 approx)\n');
fprintf(fid, '     - Minor effect on volume\n\n');
fprintf(fid, '  2. Coil Diameter (D_coil_heat):\n');
fprintf(fid, '     - Affects tube length and heat transfer area\n');
fprintf(fid, '     - Larger coil = larger volume but can reduce height\n');
fprintf(fid, '     - Trade-off with D/H ratio\n\n');
fprintf(fid, '  3. Coil Pitch (p_coil_heat):\n');
fprintf(fid, '     - Directly affects radiant zone height\n');
fprintf(fid, '     - Larger pitch = taller coil = lower D/H ratio\n');
fprintf(fid, '     - Minor DP impact\n\n');
fprintf(fid, '  4. Convection Tube Diameter:\n');
fprintf(fid, '     - Affects number of rows required\n');
fprintf(fid, '     - Larger tubes = fewer rows but larger spacing\n');
fprintf(fid, '     - Moderate DP impact\n\n');
fprintf(fid, '  5. Parallel Passes:\n');
fprintf(fid, '     - More passes = lower velocity = lower DP\n');
fprintf(fid, '     - Trade-off with heat transfer coefficient\n\n');

if ~isempty(optimal)
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  OPTIMIZED DESIGN (Best Combined Objective)\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  Optimized Parameters:\n');
    fprintf(fid, '    d_tube_ID_heat: %.3f m (vs baseline %.3f m)\n', optimal.tube_ID, baseline.params.d_tube_ID_heat);
    fprintf(fid, '    d_tube_OD_heat: %.3f m\n', optimal.tube_ID + 0.010);
    fprintf(fid, '    D_coil_heat:    %.3f m (vs baseline %.3f m)\n', optimal.D_coil, baseline.params.D_coil_heat);
    fprintf(fid, '    D_shell_heat:   %.3f m\n', optimal.D_coil + 0.4);
    fprintf(fid, '    p_coil_heat:    %.3f m (vs baseline %.3f m)\n', optimal.p_coil, baseline.params.p_coil_heat);
    fprintf(fid, '    d_tube_OD_conv: %.3f m (vs baseline %.3f m)\n', optimal.d_conv, baseline.params.d_tube_OD_conv);
    fprintf(fid, '    n_conv_parallel: %d (vs baseline %d)\n', optimal.n_parallel, baseline.params.n_conv_parallel);
    fprintf(fid, '\n');
    fprintf(fid, '  Optimized Results:\n');
    fprintf(fid, '    Radiant Volume:   %.4f m³ (%.1f%% vs baseline)\n', ...
        optimal.V_rad, (optimal.V_rad - baseline_metrics.V_rad)/baseline_metrics.V_rad*100);
    fprintf(fid, '    Convection Vol:   %.4f m³ (%.1f%% vs baseline)\n', ...
        optimal.V_conv, (optimal.V_conv - baseline_metrics.V_conv)/baseline_metrics.V_conv*100);
    fprintf(fid, '    Total Volume:     %.4f m³ (%.1f%% vs baseline)\n', ...
        optimal.V_total, (optimal.V_total - baseline_metrics.V_total)/baseline_metrics.V_total*100);
    fprintf(fid, '    D/H Radiant:      %.3f (%.1f%% vs baseline %.3f)\n', ...
        optimal.DH_rad, (optimal.DH_rad - baseline_metrics.DH_ratio_rad)/baseline_metrics.DH_ratio_rad*100, baseline_metrics.DH_ratio_rad);
    fprintf(fid, '    W/H Convection:   %.3f (%.1f%% vs baseline %.3f)\n', ...
        optimal.DH_conv, (optimal.DH_conv - baseline_metrics.DH_ratio_conv)/baseline_metrics.DH_ratio_conv*100, baseline_metrics.DH_ratio_conv);
    fprintf(fid, '    Radiant DP:       %.0f Pa (%.1f%% reduction)\n', ...
        optimal.DP_rad, (baseline_metrics.DP_rad_Pa - optimal.DP_rad)/baseline_metrics.DP_rad_Pa*100);
    fprintf(fid, '    Convection DP:    %.0f Pa\n', optimal.DP_conv);
    fprintf(fid, '    Total DP:         %.0f Pa (%.1f%% reduction)\n', ...
        optimal.DP_total, (baseline_metrics.DP_total_Pa - optimal.DP_total)/baseline_metrics.DP_total_Pa*100);
    fprintf(fid, '\n');
end

fprintf(fid, '================================================================\n');
fprintf(fid, '  RECOMMENDATIONS FOR FURTHER OPTIMIZATION\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  1. TUBE DIAMETER: Consider even larger tube IDs (45-50mm)\n');
fprintf(fid, '     to further reduce pressure drop. This is the most\n');
fprintf(fid, '     effective parameter for DP reduction.\n\n');
fprintf(fid, '  2. COIL CONFIGURATION: Explore non-helical arrangements\n');
fprintf(fid, '     or multi-layer coils to reduce height while\n');
fprintf(fid, '     maintaining heat transfer area.\n\n');
fprintf(fid, '  3. CONVECTION ZONE: Increase parallel passes to 6-8\n');
fprintf(fid, '     to reduce velocities and pressure drop.\n\n');
fprintf(fid, '  4. MATERIALS: Consider higher conductivity tube materials\n');
fprintf(fid, '     to reduce required heat transfer area.\n\n');
fprintf(fid, '  5. CFD VALIDATION: Run detailed CFD simulations on\n');
fprintf(fid, '     optimal configurations to validate assumptions.\n\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  STUDY STATISTICS\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  Total configurations evaluated: %d\n', result_count);
fprintf(fid, '  Configurations meeting DP constraint: %d\n', sum(DP_ok_arr));
fprintf(fid, '  Min/Max Volume: %.4f / %.4f m³\n', min(V_total_arr), max(V_total_arr));
fprintf(fid, '  Min/Max DP: %.0f / %.0f Pa\n', min(DP_arr), max(DP_arr));
fprintf(fid, '  Min/Max D/H Radiant: %.3f / %.3f\n', min(DH_rad_arr), max(DH_rad_arr));
fprintf(fid, '  Min/Max W/H Convection: %.3f / %.3f\n', min(DH_conv_arr), max(DH_conv_arr));
fprintf(fid, '\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  END OF REPORT\n');
fprintf(fid, '================================================================\n');

fclose(fid);
fprintf('Saved: optimization_summary.txt\n');

%% Save workspace
save(fullfile(results_folder, 'parametric_study_data.mat'), ...
    'baseline', 'baseline_metrics', ...
    'results_A', 'results_B', 'results_C', 'results_D', 'results_E', ...
    'all_results', 'optimal', 'optimal_min_vol', 'optimal_min_DP');
fprintf('Saved: parametric_study_data.mat\n');

fprintf('\n================================================================\n');
fprintf('  PARAMETRIC STUDY V2 COMPLETE\n');
fprintf('  Results saved to: %s\n', results_folder);
fprintf('================================================================\n');

%% ========================================================================
%  HELPER FUNCTION
%  ========================================================================
function print_config_v2(cfg, baseline)
    fprintf('  Parameters:\n');
    fprintf('    d_tube_ID_heat: %.3f m\n', cfg.tube_ID);
    fprintf('    D_coil_heat:    %.3f m\n', cfg.D_coil);
    fprintf('    p_coil_heat:    %.3f m\n', cfg.p_coil);
    fprintf('    d_tube_OD_conv: %.3f m\n', cfg.d_conv);
    fprintf('    n_conv_parallel: %d\n', cfg.n_parallel);
    fprintf('  Results:\n');
    fprintf('    V_total:        %.4f m³ (baseline: %.4f, change: %+.1f%%)\n', ...
        cfg.V_total, baseline.V_total, (cfg.V_total - baseline.V_total)/baseline.V_total*100);
    fprintf('    D/H Radiant:    %.3f (baseline: %.3f, change: %+.1f%%)\n', ...
        cfg.DH_rad, baseline.DH_ratio_rad, (cfg.DH_rad - baseline.DH_ratio_rad)/baseline.DH_ratio_rad*100);
    fprintf('    W/H Convection: %.3f (baseline: %.3f, change: %+.1f%%)\n', ...
        cfg.DH_conv, baseline.DH_ratio_conv, (cfg.DH_conv - baseline.DH_ratio_conv)/baseline.DH_ratio_conv*100);
    fprintf('    DP_total:       %.0f Pa (baseline: %.0f, change: %+.1f%%)\n', ...
        cfg.DP_total, baseline.DP_total_Pa, (cfg.DP_total - baseline.DP_total_Pa)/baseline.DP_total_Pa*100);
    if cfg.DP_vs_baseline
        fprintf('    Meets DP constraint: Yes\n');
    else
        fprintf('    Meets DP constraint: No\n');
    end
end
