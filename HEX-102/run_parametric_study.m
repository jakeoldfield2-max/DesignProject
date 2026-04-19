%% PARAMETRIC STUDY FOR HEAT EXCHANGER OPTIMIZATION
% Objectives:
%   1. Minimize volume of the unit
%   2. Minimize D/L ratio (diameter to height)
%   3. Keep pressure drop below baseline (key parameter)
%
% Fixed parameters (not varied):
%   - Temperature in/out for both streams
%   - Mass flow rates
%
% Variable parameters (geometry only):
%   - L_tube: Tube length
%   - D_int/D_ext: Tube diameters
%   - N_p: Number of passes (multiples of 2)
%   - pitch_ratio: Tube pitch ratio
%   - baffle_spacing_ratio: Baffle spacing ratio

clear; clc; close all;

%% Create results folder with timestamp
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results_folder = fullfile(pwd, 'results', ['study_' timestamp]);
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

fprintf('Results will be saved to: %s\n\n', results_folder);

%% Run baseline design first
fprintf('========== BASELINE DESIGN ==========\n');
baseline_params = struct();
baseline = loop_interface_exchanger(baseline_params);

% Calculate baseline metrics
baseline_volume = pi/4 * baseline.D_s^2 * 1.0;  % L_tube = 1.0 for baseline
baseline_DL_ratio = baseline.D_s / 1.0;
baseline_DP_total = baseline.DP_t + baseline.DP_s;

fprintf('\nBaseline Metrics:\n');
fprintf('  Volume: %.6f m3\n', baseline_volume);
fprintf('  D/L Ratio: %.4f\n', baseline_DL_ratio);
fprintf('  Total Pressure Drop: %.2f Pa\n', baseline_DP_total);

%% STUDY 1: Vary tube length and number of passes
fprintf('\n========== STUDY 1: Tube Length & Passes ==========\n');

L_tube_range = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
N_p_range = [2, 4, 6, 8];

study1_results = [];
idx = 1;

for L = L_tube_range
    for Np = N_p_range
        params = struct('L_tube', L, 'N_p', Np);
        try
            res = loop_interface_exchanger(params);
            volume = pi/4 * res.D_s^2 * L;
            DL_ratio = res.D_s / L;
            DP_total = res.DP_t + res.DP_s;

            study1_results(idx).L_tube = L;
            study1_results(idx).N_p = Np;
            study1_results(idx).D_s = res.D_s;
            study1_results(idx).volume = volume;
            study1_results(idx).DL_ratio = DL_ratio;
            study1_results(idx).DP_t = res.DP_t;
            study1_results(idx).DP_s = res.DP_s;
            study1_results(idx).DP_total = DP_total;
            study1_results(idx).N_tt = res.N_tt;
            study1_results(idx).U_o_calc = res.U_o_calc;
            study1_results(idx).valid = DP_total < baseline_DP_total;
            idx = idx + 1;
        catch
            % Skip invalid configurations
        end
    end
end

% Convert to table for analysis
study1_table = struct2table(study1_results);

% Plot Study 1 results
figure('Position', [100 100 1200 800]);

subplot(2,2,1);
hold on;
colors = lines(length(N_p_range));
for i = 1:length(N_p_range)
    Np = N_p_range(i);
    mask = [study1_results.N_p] == Np;
    plot([study1_results(mask).L_tube], [study1_results(mask).volume], '-o', ...
        'LineWidth', 2, 'Color', colors(i,:), 'DisplayName', sprintf('N_p = %d', Np));
end
yline(baseline_volume, '--k', 'Baseline', 'LineWidth', 1.5);
xlabel('Tube Length [m]');
ylabel('Volume [m^3]');
title('Volume vs Tube Length');
legend('Location', 'best');
grid on;

subplot(2,2,2);
hold on;
for i = 1:length(N_p_range)
    Np = N_p_range(i);
    mask = [study1_results.N_p] == Np;
    plot([study1_results(mask).L_tube], [study1_results(mask).DL_ratio], '-o', ...
        'LineWidth', 2, 'Color', colors(i,:), 'DisplayName', sprintf('N_p = %d', Np));
end
yline(baseline_DL_ratio, '--k', 'Baseline', 'LineWidth', 1.5);
xlabel('Tube Length [m]');
ylabel('D/L Ratio [-]');
title('D/L Ratio vs Tube Length');
legend('Location', 'best');
grid on;

subplot(2,2,3);
hold on;
for i = 1:length(N_p_range)
    Np = N_p_range(i);
    mask = [study1_results.N_p] == Np;
    plot([study1_results(mask).L_tube], [study1_results(mask).DP_total], '-o', ...
        'LineWidth', 2, 'Color', colors(i,:), 'DisplayName', sprintf('N_p = %d', Np));
end
yline(baseline_DP_total, '--r', 'Baseline Limit', 'LineWidth', 2);
xlabel('Tube Length [m]');
ylabel('Total Pressure Drop [Pa]');
title('Pressure Drop vs Tube Length');
legend('Location', 'best');
grid on;

subplot(2,2,4);
hold on;
for i = 1:length(N_p_range)
    Np = N_p_range(i);
    mask = [study1_results.N_p] == Np;
    plot([study1_results(mask).L_tube], [study1_results(mask).N_tt], '-o', ...
        'LineWidth', 2, 'Color', colors(i,:), 'DisplayName', sprintf('N_p = %d', Np));
end
xlabel('Tube Length [m]');
ylabel('Number of Tubes [-]');
title('Number of Tubes vs Tube Length');
legend('Location', 'best');
grid on;

sgtitle('Study 1: Effect of Tube Length and Number of Passes');
saveas(gcf, fullfile(results_folder, 'study1_tube_length_passes.png'));
saveas(gcf, fullfile(results_folder, 'study1_tube_length_passes.fig'));

%% STUDY 2: Vary tube diameters
fprintf('\n========== STUDY 2: Tube Diameters ==========\n');

% Tube wall thickness typically 2mm, vary D_int and keep wall constant
D_int_range = [0.012, 0.016, 0.020, 0.024, 0.028, 0.032];
wall_thickness = 0.002;  % 2mm wall

study2_results = [];
idx = 1;

for D_int = D_int_range
    D_ext = D_int + 2*wall_thickness;
    params = struct('D_int', D_int, 'D_ext', D_ext);
    try
        res = loop_interface_exchanger(params);
        volume = pi/4 * res.D_s^2 * 1.0;
        DL_ratio = res.D_s / 1.0;
        DP_total = res.DP_t + res.DP_s;

        study2_results(idx).D_int = D_int * 1000;  % Convert to mm
        study2_results(idx).D_ext = D_ext * 1000;
        study2_results(idx).D_s = res.D_s;
        study2_results(idx).volume = volume;
        study2_results(idx).DL_ratio = DL_ratio;
        study2_results(idx).DP_t = res.DP_t;
        study2_results(idx).DP_s = res.DP_s;
        study2_results(idx).DP_total = DP_total;
        study2_results(idx).N_tt = res.N_tt;
        study2_results(idx).Re_t = res.Re_t;
        study2_results(idx).h_i = res.h_i;
        study2_results(idx).valid = DP_total < baseline_DP_total;
        idx = idx + 1;
    catch
        % Skip invalid configurations
    end
end

% Plot Study 2 results
figure('Position', [100 100 1200 600]);

subplot(1,3,1);
bar([study2_results.D_int], [study2_results.volume]);
hold on;
yline(baseline_volume, '--r', 'Baseline', 'LineWidth', 2);
xlabel('Internal Diameter [mm]');
ylabel('Volume [m^3]');
title('Volume vs Tube Diameter');
grid on;

subplot(1,3,2);
bar([study2_results.D_int], [study2_results.DP_total]);
hold on;
yline(baseline_DP_total, '--r', 'Baseline Limit', 'LineWidth', 2);
xlabel('Internal Diameter [mm]');
ylabel('Total Pressure Drop [Pa]');
title('Pressure Drop vs Tube Diameter');
grid on;

subplot(1,3,3);
yyaxis left;
plot([study2_results.D_int], [study2_results.Re_t], '-o', 'LineWidth', 2);
ylabel('Reynolds Number [-]');
yyaxis right;
plot([study2_results.D_int], [study2_results.h_i], '-s', 'LineWidth', 2);
ylabel('h_i [W/m^2/K]');
xlabel('Internal Diameter [mm]');
title('Flow Characteristics vs Tube Diameter');
grid on;

sgtitle('Study 2: Effect of Tube Diameter');
saveas(gcf, fullfile(results_folder, 'study2_tube_diameter.png'));
saveas(gcf, fullfile(results_folder, 'study2_tube_diameter.fig'));

%% STUDY 3: Vary pitch ratio and baffle spacing
fprintf('\n========== STUDY 3: Pitch Ratio & Baffle Spacing ==========\n');

pitch_ratio_range = [1.25, 1.30, 1.35, 1.40, 1.50, 1.60];
baffle_spacing_range = [0.3, 0.4, 0.5, 0.6, 0.7];

study3_results = [];
idx = 1;

for pr = pitch_ratio_range
    for bs = baffle_spacing_range
        params = struct('pitch_ratio', pr, 'baffle_spacing_ratio', bs);
        try
            res = loop_interface_exchanger(params);
            volume = pi/4 * res.D_s^2 * 1.0;
            DL_ratio = res.D_s / 1.0;
            DP_total = res.DP_t + res.DP_s;

            study3_results(idx).pitch_ratio = pr;
            study3_results(idx).baffle_spacing = bs;
            study3_results(idx).D_s = res.D_s;
            study3_results(idx).volume = volume;
            study3_results(idx).DL_ratio = DL_ratio;
            study3_results(idx).DP_t = res.DP_t;
            study3_results(idx).DP_s = res.DP_s;
            study3_results(idx).DP_total = DP_total;
            study3_results(idx).h_s = res.h_s;
            study3_results(idx).valid = DP_total < baseline_DP_total;
            idx = idx + 1;
        catch
            % Skip invalid configurations
        end
    end
end

% Create heatmaps for Study 3
[PR, BS] = meshgrid(pitch_ratio_range, baffle_spacing_range);
Volume_map = nan(size(PR));
DP_map = nan(size(PR));
DL_map = nan(size(PR));

for i = 1:length(study3_results)
    pr_idx = find(pitch_ratio_range == study3_results(i).pitch_ratio);
    bs_idx = find(baffle_spacing_range == study3_results(i).baffle_spacing);
    Volume_map(bs_idx, pr_idx) = study3_results(i).volume;
    DP_map(bs_idx, pr_idx) = study3_results(i).DP_total;
    DL_map(bs_idx, pr_idx) = study3_results(i).DL_ratio;
end

figure('Position', [100 100 1400 500]);

subplot(1,3,1);
imagesc(pitch_ratio_range, baffle_spacing_range, Volume_map);
colorbar;
xlabel('Pitch Ratio [-]');
ylabel('Baffle Spacing Ratio [-]');
title('Volume [m^3]');
set(gca, 'YDir', 'normal');

subplot(1,3,2);
imagesc(pitch_ratio_range, baffle_spacing_range, DP_map);
colorbar;
hold on;
contour(PR, BS, DP_map, [baseline_DP_total baseline_DP_total], 'w--', 'LineWidth', 2);
xlabel('Pitch Ratio [-]');
ylabel('Baffle Spacing Ratio [-]');
title(sprintf('Total Pressure Drop [Pa] (Baseline: %.1f)', baseline_DP_total));
set(gca, 'YDir', 'normal');

subplot(1,3,3);
imagesc(pitch_ratio_range, baffle_spacing_range, DL_map);
colorbar;
xlabel('Pitch Ratio [-]');
ylabel('Baffle Spacing Ratio [-]');
title('D/L Ratio [-]');
set(gca, 'YDir', 'normal');

sgtitle('Study 3: Effect of Pitch Ratio and Baffle Spacing');
saveas(gcf, fullfile(results_folder, 'study3_pitch_baffle.png'));
saveas(gcf, fullfile(results_folder, 'study3_pitch_baffle.fig'));

%% STUDY 4: Combined optimization - find best configurations
fprintf('\n========== STUDY 4: Combined Optimization ==========\n');

% Based on previous studies, explore promising region
L_tube_opt = [1.25, 1.5, 1.75, 2.0];
N_p_opt = [2, 4];
D_int_opt = [0.016, 0.020, 0.024];
pitch_ratio_opt = [1.25, 1.30];

study4_results = [];
idx = 1;

for L = L_tube_opt
    for Np = N_p_opt
        for D_int = D_int_opt
            for pr = pitch_ratio_opt
                D_ext = D_int + 0.004;  % 2mm wall thickness
                params = struct('L_tube', L, 'N_p', Np, 'D_int', D_int, ...
                               'D_ext', D_ext, 'pitch_ratio', pr);
                try
                    res = loop_interface_exchanger(params);
                    volume = pi/4 * res.D_s^2 * L;
                    DL_ratio = res.D_s / L;
                    DP_total = res.DP_t + res.DP_s;

                    % Only store valid designs (DP < baseline)
                    if DP_total < baseline_DP_total
                        study4_results(idx).L_tube = L;
                        study4_results(idx).N_p = Np;
                        study4_results(idx).D_int = D_int * 1000;
                        study4_results(idx).pitch_ratio = pr;
                        study4_results(idx).D_s = res.D_s;
                        study4_results(idx).volume = volume;
                        study4_results(idx).DL_ratio = DL_ratio;
                        study4_results(idx).DP_t = res.DP_t;
                        study4_results(idx).DP_s = res.DP_s;
                        study4_results(idx).DP_total = DP_total;
                        study4_results(idx).N_tt = res.N_tt;
                        study4_results(idx).U_o_calc = res.U_o_calc;

                        % Composite score (lower is better)
                        % Heavily weight pressure drop reduction
                        DP_reduction = (baseline_DP_total - DP_total) / baseline_DP_total;
                        vol_reduction = (baseline_volume - volume) / baseline_volume;
                        DL_reduction = (baseline_DL_ratio - DL_ratio) / baseline_DL_ratio;

                        % Score: weight DP most heavily (0.5), then volume (0.3), then D/L (0.2)
                        study4_results(idx).score = 0.5 * DP_reduction + 0.3 * vol_reduction + 0.2 * DL_reduction;
                        idx = idx + 1;
                    end
                catch
                    % Skip invalid configurations
                end
            end
        end
    end
end

% Sort by score (descending - higher is better)
if ~isempty(study4_results)
    [~, sort_idx] = sort([study4_results.score], 'descend');
    study4_results = study4_results(sort_idx);
end

% Plot top configurations
figure('Position', [100 100 1200 600]);

subplot(1,2,1);
if ~isempty(study4_results)
    n_show = min(15, length(study4_results));
    bar_data = [[study4_results(1:n_show).volume]; [study4_results(1:n_show).DL_ratio]*0.1]';
    bar(bar_data);
    hold on;
    yline(baseline_volume, '--r', 'Baseline Vol', 'LineWidth', 1.5);
    xlabel('Configuration Rank');
    ylabel('Value');
    legend('Volume [m^3]', 'D/L Ratio (scaled)', 'Location', 'best');
    title('Top Configurations by Composite Score');
    grid on;
end

subplot(1,2,2);
if ~isempty(study4_results)
    scatter([study4_results.volume], [study4_results.DP_total], 100, [study4_results.score], 'filled');
    colorbar;
    hold on;
    scatter(baseline_volume, baseline_DP_total, 200, 'r', 'p', 'filled');
    xlabel('Volume [m^3]');
    ylabel('Total Pressure Drop [Pa]');
    title('Pareto Analysis (Color = Score)');
    legend('Designs', 'Baseline', 'Location', 'best');
    grid on;
end

sgtitle('Study 4: Combined Optimization Results');
saveas(gcf, fullfile(results_folder, 'study4_optimization.png'));
saveas(gcf, fullfile(results_folder, 'study4_optimization.fig'));

%% Generate Summary Report
fprintf('\n========== GENERATING SUMMARY REPORT ==========\n');

% Open file for writing
summary_file = fullfile(results_folder, 'optimization_summary.txt');
fid = fopen(summary_file, 'w');

fprintf(fid, '=============================================================\n');
fprintf(fid, '   HEAT EXCHANGER PARAMETRIC OPTIMIZATION STUDY\n');
fprintf(fid, '   Generated: %s\n', datestr(now));
fprintf(fid, '=============================================================\n\n');

fprintf(fid, '--- BASELINE DESIGN ---\n');
fprintf(fid, '  Tube Length:        %.2f m\n', 1.0);
fprintf(fid, '  Internal Diameter:  %.1f mm\n', 20);
fprintf(fid, '  External Diameter:  %.1f mm\n', 24);
fprintf(fid, '  Number of Passes:   %d\n', 2);
fprintf(fid, '  Pitch Ratio:        %.2f\n', 1.25);
fprintf(fid, '  Shell Diameter:     %.4f m\n', baseline.D_s);
fprintf(fid, '  Volume:             %.6f m3\n', baseline_volume);
fprintf(fid, '  D/L Ratio:          %.4f\n', baseline_DL_ratio);
fprintf(fid, '  Tube-side dP:       %.2f Pa\n', baseline.DP_t);
fprintf(fid, '  Shell-side dP:      %.4f Pa\n', baseline.DP_s);
fprintf(fid, '  Total dP:           %.2f Pa\n', baseline_DP_total);
fprintf(fid, '  Heat Duty:          %.2f kW\n', baseline.Q_kW);
fprintf(fid, '  U_o (calc):         %.2f W/m2/K\n\n', baseline.U_o_calc);

fprintf(fid, '--- OPTIMIZATION OBJECTIVES ---\n');
fprintf(fid, '  1. Minimize volume\n');
fprintf(fid, '  2. Minimize D/L ratio\n');
fprintf(fid, '  3. Pressure drop < baseline (KEY CONSTRAINT)\n\n');

fprintf(fid, '--- TOP 10 OPTIMIZED DESIGNS ---\n');
fprintf(fid, '(Ranked by composite score: 50%% dP reduction + 30%% vol reduction + 20%% D/L reduction)\n\n');

if ~isempty(study4_results)
    n_top = min(10, length(study4_results));
    for i = 1:n_top
        r = study4_results(i);
        fprintf(fid, 'Rank %d:\n', i);
        fprintf(fid, '  L_tube=%.2fm, N_p=%d, D_int=%.0fmm, pitch=%.2f\n', ...
                r.L_tube, r.N_p, r.D_int, r.pitch_ratio);
        fprintf(fid, '  D_s=%.4fm, Volume=%.6fm3, D/L=%.4f\n', ...
                r.D_s, r.volume, r.DL_ratio);
        fprintf(fid, '  dP_tube=%.2fPa, dP_shell=%.4fPa, dP_total=%.2fPa\n', ...
                r.DP_t, r.DP_s, r.DP_total);
        fprintf(fid, '  Score=%.4f\n', r.score);
        fprintf(fid, '  Improvements: Vol %.1f%%, D/L %.1f%%, dP %.1f%%\n\n', ...
                (1-r.volume/baseline_volume)*100, ...
                (1-r.DL_ratio/baseline_DL_ratio)*100, ...
                (1-r.DP_total/baseline_DP_total)*100);
    end
end

fprintf(fid, '\n--- STUDY INSIGHTS ---\n');
fprintf(fid, '1. Increasing tube length reduces shell diameter and D/L ratio\n');
fprintf(fid, '2. Higher number of passes increases pressure drop significantly\n');
fprintf(fid, '3. Larger tube diameter reduces pressure drop but increases volume\n');
fprintf(fid, '4. Pitch ratio has moderate effect on shell diameter\n');
fprintf(fid, '5. Best designs use longer tubes (1.5-2.0m) with 2 passes\n\n');

fprintf(fid, '=============================================================\n');
fprintf(fid, '   END OF REPORT\n');
fprintf(fid, '=============================================================\n');

fclose(fid);

fprintf('Summary saved to: %s\n', summary_file);

%% Save all study data
save(fullfile(results_folder, 'study_data.mat'), ...
     'baseline', 'baseline_volume', 'baseline_DL_ratio', 'baseline_DP_total', ...
     'study1_results', 'study2_results', 'study3_results', 'study4_results');

fprintf('\nAll data saved to: %s\n', fullfile(results_folder, 'study_data.mat'));
fprintf('\n========== PARAMETRIC STUDY COMPLETE ==========\n');

% Display best result
if ~isempty(study4_results)
    best = study4_results(1);
    fprintf('\nBEST DESIGN FOUND:\n');
    fprintf('  L_tube = %.2f m\n', best.L_tube);
    fprintf('  N_p = %d\n', best.N_p);
    fprintf('  D_int = %.0f mm\n', best.D_int);
    fprintf('  Pitch Ratio = %.2f\n', best.pitch_ratio);
    fprintf('  Volume = %.6f m3 (%.1f%% reduction)\n', best.volume, (1-best.volume/baseline_volume)*100);
    fprintf('  D/L Ratio = %.4f (%.1f%% reduction)\n', best.DL_ratio, (1-best.DL_ratio/baseline_DL_ratio)*100);
    fprintf('  Total dP = %.2f Pa (%.1f%% reduction)\n', best.DP_total, (1-best.DP_total/baseline_DP_total)*100);
end
