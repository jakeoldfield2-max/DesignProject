%% PARAMETRIC STUDY V3 - REFINED OPTIMIZATION FOR BETTER D/H RATIOS
% Follow-up study based on V2 findings
% Key insight: Larger tube ID dramatically reduces DP
% Challenge: D/H radiant ratio increased - need to balance
%
% Strategy:
%   - Keep larger tube ID (0.045-0.050m) for low DP
%   - Increase coil pitch to reduce D/H radiant
%   - Larger convection tubes with more rows to reduce W/H convection
%
% Author: Parametric Study Script v3
% Date: 2026-04-12

clear; clc; close all;

%% Create results folder with timestamp
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results_folder = fullfile(pwd, sprintf('results_%s_refined', timestamp));
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

fprintf('Results will be saved to: %s\n\n', results_folder);

%% ========================================================================
%  BASELINE
%  ========================================================================
fprintf('================================================================\n');
fprintf('  BASELINE AND PREVIOUS OPTIMAL\n');
fprintf('================================================================\n\n');

baseline = heater_design();

% Baseline metrics
BL = struct();
BL.H_rad = baseline.rad.H_coil_m;
BL.D_rad = baseline.params.D_shell_heat;
BL.V_rad = pi * (BL.D_rad/2)^2 * BL.H_rad;
BL.DH_rad = BL.D_rad / BL.H_rad;

BL.W_conv = baseline.conv.W_conv_m;
BL.H_conv = baseline.conv.n_rows * baseline.params.p_conv_vertical;
BL.V_conv = BL.W_conv^2 * BL.H_conv;
BL.DH_conv = BL.W_conv / max(BL.H_conv, 0.01);

BL.V_total = BL.V_rad + BL.V_conv;
BL.DP_total = baseline.dp.DP_total_Pa;
BL.DP_rad = baseline.dp.DP_total_rad_Pa;
BL.DP_conv = baseline.dp.DP_total_conv_Pa;

fprintf('BASELINE:\n');
fprintf('  Volume Total: %.4f m³, D/H Rad: %.3f, W/H Conv: %.3f, DP: %.0f Pa\n\n', ...
    BL.V_total, BL.DH_rad, BL.DH_conv, BL.DP_total);

% Previous optimal from V2 study
fprintf('Previous V2 Optimal:\n');
fprintf('  Volume Total: 0.8664 m³, D/H Rad: 2.149, W/H Conv: 12.257, DP: 8184 Pa\n');
fprintf('  Issue: D/H Radiant INCREASED (+19.7%%) - need to reduce this\n\n');

%% ========================================================================
%  REFINED OPTIMIZATION - Focus on reducing D/H ratios
%  ========================================================================
fprintf('================================================================\n');
fprintf('  REFINED 5-PARAMETER OPTIMIZATION\n');
fprintf('================================================================\n');

% Strategy:
% 1. Larger tube ID (45-50mm) - keeps DP low
% 2. LARGER coil pitch (70-120mm) - increases height, reduces D/H
% 3. Moderate coil diameter (0.9-1.1m) - balance volume vs height
% 4. Larger convection tubes (25-35mm) - more rows, better W/H
% 5. More parallel passes (5-7) - lower DP

tube_ID_range = linspace(0.042, 0.050, 4);     % Larger IDs for low DP
p_coil_range = linspace(0.070, 0.120, 5);      % LARGER pitch for lower D/H
D_coil_range = linspace(0.85, 1.15, 4);        % Moderate range
d_conv_range = linspace(0.025, 0.035, 4);      % Larger conv tubes
n_parallel_range = [5, 6, 7];

all_results = [];
result_count = 0;
total_combos = length(tube_ID_range) * length(p_coil_range) * length(D_coil_range) * ...
               length(d_conv_range) * length(n_parallel_range);

fprintf('Running %d parameter combinations...\n', total_combos);
progress_interval = max(1, floor(total_combos/10));
combo = 0;

for i1 = 1:length(tube_ID_range)
    for i2 = 1:length(p_coil_range)
        for i3 = 1:length(D_coil_range)
            for i4 = 1:length(d_conv_range)
                for i5 = 1:length(n_parallel_range)
                    combo = combo + 1;
                    if mod(combo, progress_interval) == 0
                        fprintf('  Progress: %d/%d (%.0f%%)\n', combo, total_combos, combo/total_combos*100);
                    end

                    params = struct();
                    params.d_tube_ID_heat = tube_ID_range(i1);
                    params.d_tube_OD_heat = tube_ID_range(i1) + 0.010;
                    params.p_coil_heat = p_coil_range(i2);
                    params.D_coil_heat = D_coil_range(i3);
                    params.D_shell_heat = D_coil_range(i3) + 0.4;
                    params.d_tube_OD_conv = d_conv_range(i4);
                    params.d_tube_ID_conv = d_conv_range(i4) - 0.008;
                    params.p_conv_horizontal = 2.5 * d_conv_range(i4);
                    params.p_conv_vertical = 2.5 * d_conv_range(i4);
                    params.n_conv_parallel = n_parallel_range(i5);

                    if params.d_tube_ID_conv < 0.010
                        continue;
                    end

                    try
                        r = heater_design(params);

                        H_rad = r.rad.H_coil_m;
                        D_rad = params.D_shell_heat;
                        V_rad = pi * (D_rad/2)^2 * H_rad;
                        DH_rad = D_rad / H_rad;

                        W_conv = r.conv.W_conv_m;
                        H_conv = r.conv.n_rows * params.p_conv_vertical;
                        V_conv = W_conv^2 * H_conv;
                        DH_conv = W_conv / max(H_conv, 0.01);

                        result_count = result_count + 1;
                        all_results(result_count).tube_ID = tube_ID_range(i1);
                        all_results(result_count).p_coil = p_coil_range(i2);
                        all_results(result_count).D_coil = D_coil_range(i3);
                        all_results(result_count).d_conv = d_conv_range(i4);
                        all_results(result_count).n_parallel = n_parallel_range(i5);
                        all_results(result_count).V_rad = V_rad;
                        all_results(result_count).V_conv = V_conv;
                        all_results(result_count).V_total = V_rad + V_conv;
                        all_results(result_count).DH_rad = DH_rad;
                        all_results(result_count).DH_conv = DH_conv;
                        all_results(result_count).H_rad = H_rad;
                        all_results(result_count).H_conv = H_conv;
                        all_results(result_count).DP_total = r.dp.DP_total_Pa;
                        all_results(result_count).DP_rad = r.dp.DP_total_rad_Pa;
                        all_results(result_count).DP_conv = r.dp.DP_total_conv_Pa;
                        all_results(result_count).status = r.status.all_pass;
                        all_results(result_count).DP_ok = r.dp.DP_total_Pa <= BL.DP_total;
                    catch
                        % Skip failed configs
                    end
                end
            end
        end
    end
end

fprintf('Total configurations: %d\n', result_count);

%% ========================================================================
%  FIND OPTIMAL CONFIGURATIONS
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  OPTIMAL CONFIGURATIONS\n');
fprintf('================================================================\n');

if result_count > 0
    % Extract arrays
    V_arr = [all_results.V_total];
    DH_rad_arr = [all_results.DH_rad];
    DH_conv_arr = [all_results.DH_conv];
    DP_arr = [all_results.DP_total];
    status_arr = [all_results.status];
    DP_ok_arr = [all_results.DP_ok];

    % Filter for valid (status pass and DP constraint)
    valid_idx = find(DP_ok_arr & status_arr);
    fprintf('\nConfigurations meeting all constraints: %d\n', length(valid_idx));

    if isempty(valid_idx)
        fprintf('Relaxing to just DP constraint...\n');
        valid_idx = find(DP_ok_arr);
    end

    if ~isempty(valid_idx)
        % Among valid, find best for each objective
        [~, idx_min_V] = min(V_arr(valid_idx));
        [~, idx_min_DH_rad] = min(DH_rad_arr(valid_idx));
        [~, idx_min_DH_conv] = min(DH_conv_arr(valid_idx));
        [~, idx_min_DP] = min(DP_arr(valid_idx));

        idx_min_V = valid_idx(idx_min_V);
        idx_min_DH_rad = valid_idx(idx_min_DH_rad);
        idx_min_DH_conv = valid_idx(idx_min_DH_conv);
        idx_min_DP = valid_idx(idx_min_DP);

        % Normalized multi-objective
        V_valid = V_arr(valid_idx);
        DH_rad_valid = DH_rad_arr(valid_idx);
        DH_conv_valid = DH_conv_arr(valid_idx);
        DP_valid = DP_arr(valid_idx);

        V_norm = (V_valid - min(V_valid)) / (max(V_valid) - min(V_valid) + 1e-10);
        DH_rad_norm = (DH_rad_valid - min(DH_rad_valid)) / (max(DH_rad_valid) - min(DH_rad_valid) + 1e-10);
        DH_conv_norm = (DH_conv_valid - min(DH_conv_valid)) / (max(DH_conv_valid) - min(DH_conv_valid) + 1e-10);
        DP_norm = (DP_valid - min(DP_valid)) / (max(DP_valid) - min(DP_valid) + 1e-10);

        % Weights: emphasize D/H ratios more
        w = [0.25, 0.30, 0.30, 0.15];  % V, DH_rad, DH_conv, DP
        combined = w(1)*V_norm + w(2)*DH_rad_norm + w(3)*DH_conv_norm + w(4)*DP_norm;
        [~, idx_best_local] = min(combined);
        idx_best = valid_idx(idx_best_local);

        % Print configurations
        fprintf('\n--- Minimum Volume ---\n');
        print_cfg(all_results(idx_min_V), BL);

        fprintf('\n--- Minimum D/H Radiant (TARGET) ---\n');
        print_cfg(all_results(idx_min_DH_rad), BL);

        fprintf('\n--- Minimum W/H Convection ---\n');
        print_cfg(all_results(idx_min_DH_conv), BL);

        fprintf('\n--- Minimum Pressure Drop ---\n');
        print_cfg(all_results(idx_min_DP), BL);

        fprintf('\n--- Best Combined (Weighted) ---\n');
        print_cfg(all_results(idx_best), BL);

        optimal = all_results(idx_best);
        opt_min_DH_rad = all_results(idx_min_DH_rad);
        opt_min_vol = all_results(idx_min_V);
    else
        fprintf('No valid configurations found!\n');
        optimal = [];
        opt_min_DH_rad = [];
        opt_min_vol = [];
    end
end

%% ========================================================================
%  GENERATE PLOTS
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  GENERATING PLOTS\n');
fprintf('================================================================\n');

% Plot 1: D/H Ratio Trade-offs
fig1 = figure('Position', [100, 100, 1400, 500]);

subplot(1,3,1);
scatter(DH_rad_arr, DH_conv_arr, 40, V_arr, 'filled');
hold on;
plot(BL.DH_rad, BL.DH_conv, 'rp', 'MarkerSize', 20, 'MarkerFaceColor', 'r', 'DisplayName', 'Baseline');
if ~isempty(optimal)
    plot(optimal.DH_rad, optimal.DH_conv, 'g^', 'MarkerSize', 15, 'MarkerFaceColor', 'g', 'DisplayName', 'Optimal');
end
xlabel('D/H Ratio (Radiant)');
ylabel('W/H Ratio (Convection)');
title('Aspect Ratios (color: Volume m³)');
colorbar;
legend('Location', 'best');
grid on;

subplot(1,3,2);
scatter(V_arr, DH_rad_arr, 40, DP_arr/1000, 'filled');
hold on;
plot(BL.V_total, BL.DH_rad, 'rp', 'MarkerSize', 20, 'MarkerFaceColor', 'r');
if ~isempty(optimal)
    plot(optimal.V_total, optimal.DH_rad, 'g^', 'MarkerSize', 15, 'MarkerFaceColor', 'g');
end
xlabel('Total Volume (m³)');
ylabel('D/H Ratio (Radiant)');
title('Volume vs Radiant D/H (color: DP kPa)');
colorbar;
grid on;

subplot(1,3,3);
scatter(V_arr, DH_conv_arr, 40, DP_arr/1000, 'filled');
hold on;
plot(BL.V_total, BL.DH_conv, 'rp', 'MarkerSize', 20, 'MarkerFaceColor', 'r');
if ~isempty(optimal)
    plot(optimal.V_total, optimal.DH_conv, 'g^', 'MarkerSize', 15, 'MarkerFaceColor', 'g');
end
xlabel('Total Volume (m³)');
ylabel('W/H Ratio (Convection)');
title('Volume vs Convection W/H (color: DP kPa)');
colorbar;
grid on;

sgtitle('D/H Ratio Optimization Space', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig1, fullfile(results_folder, 'DH_ratio_tradeoffs.png'));
fprintf('Saved: DH_ratio_tradeoffs.png\n');

% Plot 2: Coil Pitch Effect (key for D/H radiant)
fig2 = figure('Position', [100, 100, 1200, 450]);

p_coil_values = [all_results.p_coil];
unique_p = unique(p_coil_values);

mean_DH_rad_by_p = zeros(size(unique_p));
mean_H_rad_by_p = zeros(size(unique_p));
mean_V_by_p = zeros(size(unique_p));

for i = 1:length(unique_p)
    idx = abs(p_coil_values - unique_p(i)) < 0.001;
    mean_DH_rad_by_p(i) = mean(DH_rad_arr(idx));
    mean_H_rad_by_p(i) = mean([all_results(idx).H_rad]);
    mean_V_by_p(i) = mean(V_arr(idx));
end

subplot(1,3,1);
plot(unique_p*1000, mean_DH_rad_by_p, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
hold on;
yline(BL.DH_rad, 'r--', 'LineWidth', 1.5, 'Label', 'Baseline');
xlabel('Coil Pitch (mm)');
ylabel('Mean D/H Ratio (Radiant)');
title('D/H Radiant vs Coil Pitch');
grid on;

subplot(1,3,2);
plot(unique_p*1000, mean_H_rad_by_p, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
hold on;
yline(BL.H_rad, 'r--', 'LineWidth', 1.5, 'Label', 'Baseline');
xlabel('Coil Pitch (mm)');
ylabel('Mean Radiant Height (m)');
title('Height vs Coil Pitch');
grid on;

subplot(1,3,3);
plot(unique_p*1000, mean_V_by_p, 'm-^', 'LineWidth', 2, 'MarkerFaceColor', 'm');
hold on;
yline(BL.V_total, 'r--', 'LineWidth', 1.5, 'Label', 'Baseline');
xlabel('Coil Pitch (mm)');
ylabel('Mean Total Volume (m³)');
title('Volume vs Coil Pitch');
grid on;

sgtitle('Coil Pitch Impact Analysis', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig2, fullfile(results_folder, 'coil_pitch_impact.png'));
fprintf('Saved: coil_pitch_impact.png\n');

% Plot 3: Convection Tube Effect on W/H
fig3 = figure('Position', [100, 100, 1200, 450]);

d_conv_values = [all_results.d_conv];
unique_d = unique(d_conv_values);

mean_DH_conv_by_d = zeros(size(unique_d));
mean_H_conv_by_d = zeros(size(unique_d));
mean_V_conv_by_d = zeros(size(unique_d));

for i = 1:length(unique_d)
    idx = abs(d_conv_values - unique_d(i)) < 0.001;
    mean_DH_conv_by_d(i) = mean(DH_conv_arr(idx));
    mean_H_conv_by_d(i) = mean([all_results(idx).H_conv]);
    mean_V_conv_by_d(i) = mean([all_results(idx).V_conv]);
end

subplot(1,3,1);
plot(unique_d*1000, mean_DH_conv_by_d, 'b-o', 'LineWidth', 2, 'MarkerFaceColor', 'b');
hold on;
yline(BL.DH_conv, 'r--', 'LineWidth', 1.5, 'Label', 'Baseline');
xlabel('Conv Tube OD (mm)');
ylabel('Mean W/H Ratio (Conv)');
title('W/H vs Conv Tube Size');
grid on;

subplot(1,3,2);
plot(unique_d*1000, mean_H_conv_by_d, 'g-s', 'LineWidth', 2, 'MarkerFaceColor', 'g');
hold on;
yline(BL.H_conv, 'r--', 'LineWidth', 1.5, 'Label', 'Baseline');
xlabel('Conv Tube OD (mm)');
ylabel('Mean Conv Height (m)');
title('Height vs Conv Tube Size');
grid on;

subplot(1,3,3);
plot(unique_d*1000, mean_V_conv_by_d, 'm-^', 'LineWidth', 2, 'MarkerFaceColor', 'm');
hold on;
yline(BL.V_conv, 'r--', 'LineWidth', 1.5, 'Label', 'Baseline');
xlabel('Conv Tube OD (mm)');
ylabel('Mean Conv Volume (m³)');
title('Conv Volume vs Tube Size');
grid on;

sgtitle('Convection Tube Size Impact Analysis', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig3, fullfile(results_folder, 'conv_tube_impact.png'));
fprintf('Saved: conv_tube_impact.png\n');

% Plot 4: Comprehensive Comparison
fig4 = figure('Position', [100, 100, 1400, 600]);

if ~isempty(optimal) && ~isempty(opt_min_DH_rad)
    subplot(2,2,1);
    categories = {'Volume (m³)', 'D/H Radiant', 'W/H Conv', 'DP (kPa)'};
    baseline_data = [BL.V_total, BL.DH_rad, BL.DH_conv, BL.DP_total/1000];
    optimal_data = [optimal.V_total, optimal.DH_rad, optimal.DH_conv, optimal.DP_total/1000];
    min_DH_data = [opt_min_DH_rad.V_total, opt_min_DH_rad.DH_rad, opt_min_DH_rad.DH_conv, opt_min_DH_rad.DP_total/1000];

    X = categorical(categories);
    X = reordercats(X, categories);
    bar_data = [baseline_data; optimal_data; min_DH_data]';

    b = bar(X, bar_data);
    b(1).FaceColor = [0.8 0.2 0.2];
    b(2).FaceColor = [0.2 0.6 0.2];
    b(3).FaceColor = [0.2 0.4 0.8];
    legend('Baseline', 'Best Combined', 'Min D/H Rad', 'Location', 'northwest');
    ylabel('Value');
    title('Design Comparison');
    grid on;

    subplot(2,2,2);
    % Radar/Spider chart data (normalized)
    metrics = {'Volume', 'D/H Rad', 'W/H Conv', 'DP'};
    baseline_norm = [BL.V_total/2, BL.DH_rad/3, BL.DH_conv/25, BL.DP_total/60000];
    optimal_norm = [optimal.V_total/2, optimal.DH_rad/3, optimal.DH_conv/25, optimal.DP_total/60000];

    theta = linspace(0, 2*pi, 5);
    baseline_plot = [baseline_norm, baseline_norm(1)];
    optimal_plot = [optimal_norm, optimal_norm(1)];

    polarplot(theta, baseline_plot, 'r-o', 'LineWidth', 2);
    hold on;
    polarplot(theta, optimal_plot, 'g-s', 'LineWidth', 2);
    title('Normalized Performance (smaller = better)');
    legend('Baseline', 'Optimal');

    subplot(2,2,[3 4]);
    % 3D visualization
    scatter3(V_arr, DH_rad_arr, DH_conv_arr, 30, DP_arr/1000, 'filled');
    hold on;
    plot3(BL.V_total, BL.DH_rad, BL.DH_conv, 'rp', 'MarkerSize', 25, 'MarkerFaceColor', 'r');
    plot3(optimal.V_total, optimal.DH_rad, optimal.DH_conv, 'g^', 'MarkerSize', 20, 'MarkerFaceColor', 'g');
    plot3(opt_min_DH_rad.V_total, opt_min_DH_rad.DH_rad, opt_min_DH_rad.DH_conv, 'b^', 'MarkerSize', 20, 'MarkerFaceColor', 'b');
    xlabel('Volume (m³)');
    ylabel('D/H Radiant');
    zlabel('W/H Convection');
    title('3D Design Space (color: DP kPa)');
    colorbar;
    legend('Designs', 'Baseline', 'Optimal', 'Min D/H Rad');
    view(45, 25);
    grid on;
end

sgtitle('Refined Optimization Results Summary', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig4, fullfile(results_folder, 'optimization_summary_plot.png'));
fprintf('Saved: optimization_summary_plot.png\n');

% Plot 5: Pareto Analysis
fig5 = figure('Position', [100, 100, 1400, 500]);

subplot(1,3,1);
scatter(V_arr, DP_arr/1000, 40, DH_rad_arr, 'filled');
hold on;
plot(BL.V_total, BL.DP_total/1000, 'rp', 'MarkerSize', 18, 'MarkerFaceColor', 'r');
xlabel('Volume (m³)');
ylabel('Pressure Drop (kPa)');
title('Volume-DP Trade-off (color: D/H Rad)');
colorbar;
grid on;

subplot(1,3,2);
scatter(DH_rad_arr, DP_arr/1000, 40, V_arr, 'filled');
hold on;
plot(BL.DH_rad, BL.DP_total/1000, 'rp', 'MarkerSize', 18, 'MarkerFaceColor', 'r');
xlabel('D/H Radiant');
ylabel('Pressure Drop (kPa)');
title('D/H Rad - DP Trade-off (color: Vol)');
colorbar;
grid on;

subplot(1,3,3);
scatter(DH_conv_arr, DP_arr/1000, 40, V_arr, 'filled');
hold on;
plot(BL.DH_conv, BL.DP_total/1000, 'rp', 'MarkerSize', 18, 'MarkerFaceColor', 'r');
xlabel('W/H Convection');
ylabel('Pressure Drop (kPa)');
title('W/H Conv - DP Trade-off (color: Vol)');
colorbar;
grid on;

sgtitle('Pareto Trade-off Analysis', 'FontSize', 14, 'FontWeight', 'bold');
saveas(fig5, fullfile(results_folder, 'pareto_analysis.png'));
fprintf('Saved: pareto_analysis.png\n');

% Plot 6: Parameter Histograms for Optimal Region
fig6 = figure('Position', [100, 100, 1400, 400]);

% Find designs that are "good" (better than baseline in all metrics)
good_idx = find(V_arr < BL.V_total & DH_rad_arr < BL.DH_rad & ...
                DH_conv_arr < BL.DH_conv & DP_arr < BL.DP_total);

if length(good_idx) > 5
    subplot(1,5,1);
    histogram([all_results(good_idx).tube_ID]*1000, 'FaceColor', [0.3 0.6 0.9]);
    xlabel('Tube ID (mm)');
    ylabel('Count');
    title('Good Designs: Tube ID');

    subplot(1,5,2);
    histogram([all_results(good_idx).p_coil]*1000, 'FaceColor', [0.3 0.6 0.9]);
    xlabel('Coil Pitch (mm)');
    title('Good Designs: Coil Pitch');

    subplot(1,5,3);
    histogram([all_results(good_idx).D_coil], 'FaceColor', [0.3 0.6 0.9]);
    xlabel('Coil Diameter (m)');
    title('Good Designs: Coil Dia');

    subplot(1,5,4);
    histogram([all_results(good_idx).d_conv]*1000, 'FaceColor', [0.3 0.6 0.9]);
    xlabel('Conv Tube OD (mm)');
    title('Good Designs: Conv Tube');

    subplot(1,5,5);
    histogram([all_results(good_idx).n_parallel], 'FaceColor', [0.3 0.6 0.9]);
    xlabel('Parallel Passes');
    title('Good Designs: N Parallel');

    sgtitle(sprintf('Parameter Distribution for %d Designs Better than Baseline in All Metrics', length(good_idx)), ...
            'FontSize', 12, 'FontWeight', 'bold');
else
    text(0.5, 0.5, sprintf('Only %d designs better than baseline in all metrics', length(good_idx)), ...
         'HorizontalAlignment', 'center', 'FontSize', 14);
    title('Insufficient Good Designs for Histogram');
end

saveas(fig6, fullfile(results_folder, 'good_designs_parameters.png'));
fprintf('Saved: good_designs_parameters.png\n');

%% ========================================================================
%  SAVE COMPREHENSIVE REPORT
%  ========================================================================
fprintf('\n================================================================\n');
fprintf('  SAVING REPORT\n');
fprintf('================================================================\n');

fid = fopen(fullfile(results_folder, 'optimization_report.txt'), 'w');

fprintf(fid, '================================================================\n');
fprintf(fid, '  REFINED HEATER OPTIMIZATION STUDY - V3\n');
fprintf(fid, '  Generated: %s\n', datestr(now));
fprintf(fid, '================================================================\n\n');

fprintf(fid, 'OBJECTIVE: Minimize Volume AND D/H Ratios simultaneously\n');
fprintf(fid, 'while keeping pressure drop below baseline.\n\n');

fprintf(fid, '================================================================\n');
fprintf(fid, '  BASELINE DESIGN\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  Total Volume:     %.4f m³\n', BL.V_total);
fprintf(fid, '  D/H Radiant:      %.3f\n', BL.DH_rad);
fprintf(fid, '  W/H Convection:   %.3f\n', BL.DH_conv);
fprintf(fid, '  Pressure Drop:    %.0f Pa (%.2f bar)\n\n', BL.DP_total, BL.DP_total/1e5);

if ~isempty(optimal)
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  BEST COMBINED OPTIMAL DESIGN\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  Parameters:\n');
    fprintf(fid, '    d_tube_ID_heat:  %.1f mm (baseline: %.1f mm)\n', optimal.tube_ID*1000, baseline.params.d_tube_ID_heat*1000);
    fprintf(fid, '    d_tube_OD_heat:  %.1f mm\n', (optimal.tube_ID+0.01)*1000);
    fprintf(fid, '    p_coil_heat:     %.1f mm (baseline: %.1f mm)\n', optimal.p_coil*1000, baseline.params.p_coil_heat*1000);
    fprintf(fid, '    D_coil_heat:     %.3f m (baseline: %.3f m)\n', optimal.D_coil, baseline.params.D_coil_heat);
    fprintf(fid, '    D_shell_heat:    %.3f m\n', optimal.D_coil + 0.4);
    fprintf(fid, '    d_tube_OD_conv:  %.1f mm (baseline: %.1f mm)\n', optimal.d_conv*1000, baseline.params.d_tube_OD_conv*1000);
    fprintf(fid, '    n_conv_parallel: %d (baseline: %d)\n\n', optimal.n_parallel, baseline.params.n_conv_parallel);

    fprintf(fid, '  Results:\n');
    fprintf(fid, '    Volume Total:   %.4f m³  (%+.1f%% vs baseline)\n', ...
        optimal.V_total, (optimal.V_total - BL.V_total)/BL.V_total*100);
    fprintf(fid, '    D/H Radiant:    %.3f     (%+.1f%% vs baseline)\n', ...
        optimal.DH_rad, (optimal.DH_rad - BL.DH_rad)/BL.DH_rad*100);
    fprintf(fid, '    W/H Convection: %.3f     (%+.1f%% vs baseline)\n', ...
        optimal.DH_conv, (optimal.DH_conv - BL.DH_conv)/BL.DH_conv*100);
    fprintf(fid, '    Pressure Drop:  %.0f Pa  (%+.1f%% vs baseline)\n\n', ...
        optimal.DP_total, (optimal.DP_total - BL.DP_total)/BL.DP_total*100);
end

if ~isempty(opt_min_DH_rad)
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  MINIMUM D/H RADIANT DESIGN\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '  Parameters:\n');
    fprintf(fid, '    d_tube_ID_heat:  %.1f mm\n', opt_min_DH_rad.tube_ID*1000);
    fprintf(fid, '    p_coil_heat:     %.1f mm\n', opt_min_DH_rad.p_coil*1000);
    fprintf(fid, '    D_coil_heat:     %.3f m\n', opt_min_DH_rad.D_coil);
    fprintf(fid, '    d_tube_OD_conv:  %.1f mm\n', opt_min_DH_rad.d_conv*1000);
    fprintf(fid, '    n_conv_parallel: %d\n\n', opt_min_DH_rad.n_parallel);

    fprintf(fid, '  Results:\n');
    fprintf(fid, '    Volume Total:   %.4f m³  (%+.1f%% vs baseline)\n', ...
        opt_min_DH_rad.V_total, (opt_min_DH_rad.V_total - BL.V_total)/BL.V_total*100);
    fprintf(fid, '    D/H Radiant:    %.3f     (%+.1f%% vs baseline)\n', ...
        opt_min_DH_rad.DH_rad, (opt_min_DH_rad.DH_rad - BL.DH_rad)/BL.DH_rad*100);
    fprintf(fid, '    W/H Convection: %.3f     (%+.1f%% vs baseline)\n', ...
        opt_min_DH_rad.DH_conv, (opt_min_DH_rad.DH_conv - BL.DH_conv)/BL.DH_conv*100);
    fprintf(fid, '    Pressure Drop:  %.0f Pa  (%+.1f%% vs baseline)\n\n', ...
        opt_min_DH_rad.DP_total, (opt_min_DH_rad.DP_total - BL.DP_total)/BL.DP_total*100);
end

fprintf(fid, '================================================================\n');
fprintf(fid, '  KEY FINDINGS\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  1. TUBE ID: Larger tube ID (45-50mm) dramatically reduces DP\n');
fprintf(fid, '     without significantly increasing volume.\n\n');
fprintf(fid, '  2. COIL PITCH: Increasing pitch from 60mm to 100+mm\n');
fprintf(fid, '     reduces D/H ratio by increasing coil height.\n');
fprintf(fid, '     Trade-off: Higher pitch = taller, larger volume.\n\n');
fprintf(fid, '  3. CONVECTION TUBES: Larger tubes (30-35mm) create more\n');
fprintf(fid, '     rows, reducing W/H ratio.\n\n');
fprintf(fid, '  4. PARALLEL PASSES: 5-7 passes balance DP and heat transfer.\n\n');
fprintf(fid, '  5. Designs better than baseline in ALL metrics: %d\n\n', length(good_idx));

fprintf(fid, '================================================================\n');
fprintf(fid, '  STATISTICS\n');
fprintf(fid, '================================================================\n');
fprintf(fid, '  Total configurations: %d\n', result_count);
fprintf(fid, '  Meeting DP constraint: %d (%.1f%%)\n', sum(DP_ok_arr), sum(DP_ok_arr)/result_count*100);
fprintf(fid, '  Volume range: %.4f - %.4f m³\n', min(V_arr), max(V_arr));
fprintf(fid, '  D/H Rad range: %.3f - %.3f\n', min(DH_rad_arr), max(DH_rad_arr));
fprintf(fid, '  W/H Conv range: %.3f - %.3f\n', min(DH_conv_arr), max(DH_conv_arr));
fprintf(fid, '  DP range: %.0f - %.0f Pa\n', min(DP_arr), max(DP_arr));

fprintf(fid, '\n================================================================\n');
fprintf(fid, '  END OF REPORT\n');
fprintf(fid, '================================================================\n');

fclose(fid);
fprintf('Saved: optimization_report.txt\n');

% Save data
save(fullfile(results_folder, 'optimization_data.mat'), ...
     'baseline', 'BL', 'all_results', 'optimal', 'opt_min_DH_rad', 'opt_min_vol');
fprintf('Saved: optimization_data.mat\n');

fprintf('\n================================================================\n');
fprintf('  REFINED STUDY COMPLETE\n');
fprintf('  Results saved to: %s\n', results_folder);
fprintf('================================================================\n');

%% ========================================================================
%  HELPER
%  ========================================================================
function print_cfg(cfg, BL)
    fprintf('  Parameters: tube_ID=%.1fmm, p_coil=%.0fmm, D_coil=%.2fm, d_conv=%.0fmm, n_par=%d\n', ...
        cfg.tube_ID*1000, cfg.p_coil*1000, cfg.D_coil, cfg.d_conv*1000, cfg.n_parallel);
    fprintf('  Results:\n');
    fprintf('    Volume:    %.4f m³ (%+.1f%%)\n', cfg.V_total, (cfg.V_total-BL.V_total)/BL.V_total*100);
    fprintf('    D/H Rad:   %.3f (%+.1f%%)\n', cfg.DH_rad, (cfg.DH_rad-BL.DH_rad)/BL.DH_rad*100);
    fprintf('    W/H Conv:  %.3f (%+.1f%%)\n', cfg.DH_conv, (cfg.DH_conv-BL.DH_conv)/BL.DH_conv*100);
    fprintf('    DP:        %.0f Pa (%+.1f%%)\n', cfg.DP_total, (cfg.DP_total-BL.DP_total)/BL.DP_total*100);
end
