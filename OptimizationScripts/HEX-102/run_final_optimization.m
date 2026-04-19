%% FINAL OPTIMIZATION STUDY - Seeking Best Balanced Design
% Key insight from previous studies:
%   - Pressure drop dominated by tube-side (627 Pa vs 0.1 Pa shell)
%   - Larger tubes reduce dP but increase volume
%   - Need to find optimal balance
%
% Strategy: Explore full parameter space with different weighting schemes
% to find Pareto-optimal designs

clear; clc; close all;

%% Create results folder
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results_folder = fullfile(pwd, 'results', ['final_optimization_' timestamp]);
if ~exist(results_folder, 'dir')
    mkdir(results_folder);
end

fprintf('Final Optimization Study\n');
fprintf('Results folder: %s\n\n', results_folder);

%% Baseline reference
baseline = loop_interface_exchanger(struct());
baseline_volume = pi/4 * baseline.D_s^2 * 1.0;
baseline_DL_ratio = baseline.D_s / 1.0;
baseline_DP_total = baseline.DP_t + baseline.DP_s;

fprintf('BASELINE DESIGN:\n');
fprintf('  Volume: %.6f m3\n', baseline_volume);
fprintf('  D/L Ratio: %.4f\n', baseline_DL_ratio);
fprintf('  Pressure Drop: %.2f Pa (Tube: %.2f, Shell: %.4f)\n\n', ...
        baseline_DP_total, baseline.DP_t, baseline.DP_s);

%% Comprehensive parameter sweep
L_tube_range = 0.5:0.1:3.0;
D_int_range = 0.010:0.002:0.036;  % 10mm to 36mm
pitch_range = [1.25, 1.30];
N_p = 2;  % Fixed at 2 passes

all_results = [];
idx = 1;
total = length(L_tube_range) * length(D_int_range) * length(pitch_range);
fprintf('Testing %d configurations...\n', total);

for L = L_tube_range
    for D_int = D_int_range
        D_ext = D_int + 0.004;  % 2mm wall
        for pr = pitch_range
            params = struct('L_tube', L, 'N_p', N_p, 'D_int', D_int, ...
                           'D_ext', D_ext, 'pitch_ratio', pr);
            try
                res = loop_interface_exchanger(params);
                volume = pi/4 * res.D_s^2 * L;
                DL_ratio = res.D_s / L;
                DP_total = res.DP_t + res.DP_s;

                all_results(idx).L_tube = L;
                all_results(idx).D_int = D_int * 1000;
                all_results(idx).D_ext = D_ext * 1000;
                all_results(idx).pitch_ratio = pr;
                all_results(idx).D_s = res.D_s;
                all_results(idx).volume = volume;
                all_results(idx).DL_ratio = DL_ratio;
                all_results(idx).DP_t = res.DP_t;
                all_results(idx).DP_s = res.DP_s;
                all_results(idx).DP_total = DP_total;
                all_results(idx).N_tt = res.N_tt;
                all_results(idx).U_o_calc = res.U_o_calc;
                all_results(idx).h_i = res.h_i;
                all_results(idx).h_s = res.h_s;
                all_results(idx).Re_t = res.Re_t;

                % Check if valid (dP < baseline)
                all_results(idx).valid = DP_total < baseline_DP_total;

                % Calculate normalized metrics
                all_results(idx).norm_vol = volume / baseline_volume;
                all_results(idx).norm_DL = DL_ratio / baseline_DL_ratio;
                all_results(idx).norm_DP = DP_total / baseline_DP_total;

                idx = idx + 1;
            catch
            end
        end
    end
end

fprintf('Completed %d configurations\n\n', idx-1);

%% Identify Pareto-optimal designs
% A design is Pareto-optimal if no other design is better in all objectives
valid_results = all_results([all_results.valid]);
fprintf('Found %d designs meeting pressure drop constraint\n', length(valid_results));

% Find Pareto front (minimize volume, minimize D/L, minimize dP)
pareto_idx = [];
for i = 1:length(valid_results)
    is_dominated = false;
    for j = 1:length(valid_results)
        if i ~= j
            % Check if j dominates i
            if valid_results(j).volume <= valid_results(i).volume && ...
               valid_results(j).DL_ratio <= valid_results(i).DL_ratio && ...
               valid_results(j).DP_total <= valid_results(i).DP_total && ...
               (valid_results(j).volume < valid_results(i).volume || ...
                valid_results(j).DL_ratio < valid_results(i).DL_ratio || ...
                valid_results(j).DP_total < valid_results(i).DP_total)
                is_dominated = true;
                break;
            end
        end
    end
    if ~is_dominated
        pareto_idx = [pareto_idx, i];
    end
end

pareto_results = valid_results(pareto_idx);
fprintf('Found %d Pareto-optimal designs\n\n', length(pareto_results));

%% Score designs with different weighting schemes
% Scheme 1: Pressure drop priority (60% dP, 25% vol, 15% D/L)
% Scheme 2: Balanced (40% dP, 35% vol, 25% D/L)
% Scheme 3: Volume priority (30% dP, 50% vol, 20% D/L)

for i = 1:length(valid_results)
    v = valid_results(i);
    dp_red = (baseline_DP_total - v.DP_total) / baseline_DP_total;
    vol_red = (baseline_volume - v.volume) / baseline_volume;
    dl_red = (baseline_DL_ratio - v.DL_ratio) / baseline_DL_ratio;

    valid_results(i).score_dp_priority = 0.60*dp_red + 0.25*vol_red + 0.15*dl_red;
    valid_results(i).score_balanced = 0.40*dp_red + 0.35*vol_red + 0.25*dl_red;
    valid_results(i).score_vol_priority = 0.30*dp_red + 0.50*vol_red + 0.20*dl_red;
end

%% Sort and get best designs for each scheme
[~, idx_dp] = sort([valid_results.score_dp_priority], 'descend');
[~, idx_bal] = sort([valid_results.score_balanced], 'descend');
[~, idx_vol] = sort([valid_results.score_vol_priority], 'descend');

best_dp = valid_results(idx_dp(1));
best_bal = valid_results(idx_bal(1));
best_vol = valid_results(idx_vol(1));

%% Create visualizations

% Figure 1: Parameter sensitivity
figure('Position', [50 50 1600 900]);

subplot(2,3,1);
scatter([all_results.D_int], [all_results.volume], 20, [all_results.norm_DP], 'filled');
colorbar;
xlabel('Tube Internal Diameter [mm]');
ylabel('Volume [m^3]');
title('Volume vs Tube Diameter (Color = Normalized dP)');
hold on;
yline(baseline_volume, '--r', 'Baseline', 'LineWidth', 1.5);
grid on;

subplot(2,3,2);
scatter([all_results.L_tube], [all_results.volume], 20, [all_results.norm_DP], 'filled');
colorbar;
xlabel('Tube Length [m]');
ylabel('Volume [m^3]');
title('Volume vs Tube Length (Color = Normalized dP)');
hold on;
yline(baseline_volume, '--r', 'Baseline', 'LineWidth', 1.5);
grid on;

subplot(2,3,3);
scatter([all_results.D_int], [all_results.DP_total], 20, [all_results.norm_vol], 'filled');
colorbar;
xlabel('Tube Internal Diameter [mm]');
ylabel('Total Pressure Drop [Pa]');
title('Pressure Drop vs Tube Diameter (Color = Normalized Vol)');
hold on;
yline(baseline_DP_total, '--r', 'Baseline Limit', 'LineWidth', 1.5);
grid on;

subplot(2,3,4);
scatter([all_results.D_int], [all_results.DL_ratio], 20, [all_results.L_tube], 'filled');
colorbar;
xlabel('Tube Internal Diameter [mm]');
ylabel('D/L Ratio [-]');
title('D/L Ratio vs Tube Diameter (Color = Tube Length)');
hold on;
yline(baseline_DL_ratio, '--r', 'Baseline', 'LineWidth', 1.5);
grid on;

subplot(2,3,5);
scatter([all_results.L_tube], [all_results.DL_ratio], 20, [all_results.D_int], 'filled');
colorbar;
xlabel('Tube Length [m]');
ylabel('D/L Ratio [-]');
title('D/L Ratio vs Tube Length (Color = Tube Diameter)');
hold on;
yline(baseline_DL_ratio, '--r', 'Baseline', 'LineWidth', 1.5);
grid on;

subplot(2,3,6);
scatter([all_results.Re_t], [all_results.DP_t], 20, [all_results.D_int], 'filled');
colorbar;
xlabel('Tube Reynolds Number [-]');
ylabel('Tube-side Pressure Drop [Pa]');
title('Tube dP vs Re (Color = Tube Diameter)');
grid on;

sgtitle('Parameter Sensitivity Analysis');
saveas(gcf, fullfile(results_folder, 'parameter_sensitivity.png'));
saveas(gcf, fullfile(results_folder, 'parameter_sensitivity.fig'));

% Figure 2: Pareto front and optimal designs
figure('Position', [50 50 1400 600]);

subplot(1,2,1);
hold on;
% All valid designs
scatter([valid_results.volume], [valid_results.DP_total], 30, ...
        [valid_results.DL_ratio], 'filled', 'MarkerFaceAlpha', 0.3);
colorbar;
% Pareto front
if ~isempty(pareto_results)
    scatter([pareto_results.volume], [pareto_results.DP_total], 100, 'k', 'filled');
end
% Baseline
scatter(baseline_volume, baseline_DP_total, 200, 'r', 'p', 'filled');
% Best designs
scatter(best_dp.volume, best_dp.DP_total, 150, 'g', 'd', 'filled');
scatter(best_bal.volume, best_bal.DP_total, 150, 'm', 's', 'filled');
scatter(best_vol.volume, best_vol.DP_total, 150, 'c', '^', 'filled');

xlabel('Volume [m^3]');
ylabel('Total Pressure Drop [Pa]');
title('Pareto Analysis (Color = D/L Ratio)');
legend('Valid Designs', 'Pareto Front', 'Baseline', 'Best dP Priority', ...
       'Best Balanced', 'Best Vol Priority', 'Location', 'best');
grid on;

subplot(1,2,2);
hold on;
scatter([valid_results.DL_ratio], [valid_results.DP_total], 30, ...
        [valid_results.volume], 'filled', 'MarkerFaceAlpha', 0.3);
colorbar;
if ~isempty(pareto_results)
    scatter([pareto_results.DL_ratio], [pareto_results.DP_total], 100, 'k', 'filled');
end
scatter(baseline_DL_ratio, baseline_DP_total, 200, 'r', 'p', 'filled');
scatter(best_dp.DL_ratio, best_dp.DP_total, 150, 'g', 'd', 'filled');
scatter(best_bal.DL_ratio, best_bal.DP_total, 150, 'm', 's', 'filled');
scatter(best_vol.DL_ratio, best_vol.DP_total, 150, 'c', '^', 'filled');

xlabel('D/L Ratio [-]');
ylabel('Total Pressure Drop [Pa]');
title('D/L vs Pressure Drop (Color = Volume)');
legend('Valid Designs', 'Pareto Front', 'Baseline', 'Best dP Priority', ...
       'Best Balanced', 'Best Vol Priority', 'Location', 'best');
grid on;

sgtitle('Optimization Results and Pareto Front');
saveas(gcf, fullfile(results_folder, 'pareto_analysis.png'));
saveas(gcf, fullfile(results_folder, 'pareto_analysis.fig'));

% Figure 3: 3D Design Space
figure('Position', [50 50 1200 800]);
scatter3([valid_results.volume], [valid_results.DL_ratio], [valid_results.DP_total], ...
         40, [valid_results.D_int], 'filled');
colorbar;
hold on;
scatter3(baseline_volume, baseline_DL_ratio, baseline_DP_total, ...
         300, 'r', 'p', 'filled');
if ~isempty(pareto_results)
    scatter3([pareto_results.volume], [pareto_results.DL_ratio], [pareto_results.DP_total], ...
             150, 'k', 'filled');
end
xlabel('Volume [m^3]');
ylabel('D/L Ratio [-]');
zlabel('Total Pressure Drop [Pa]');
title('3D Design Space (Color = Tube Diameter [mm])');
legend('Valid Designs', 'Baseline', 'Pareto Front', 'Location', 'best');
grid on;
view(45, 25);
saveas(gcf, fullfile(results_folder, '3D_design_space.png'));
saveas(gcf, fullfile(results_folder, '3D_design_space.fig'));

% Figure 4: Best designs comparison
figure('Position', [50 50 1200 500]);

categories = {'Baseline', 'Best dP Priority', 'Best Balanced', 'Best Vol Priority'};
volumes = [baseline_volume, best_dp.volume, best_bal.volume, best_vol.volume];
DL_ratios = [baseline_DL_ratio, best_dp.DL_ratio, best_bal.DL_ratio, best_vol.DL_ratio];
DP_totals = [baseline_DP_total, best_dp.DP_total, best_bal.DP_total, best_vol.DP_total];

subplot(1,3,1);
bar(volumes);
set(gca, 'XTickLabel', categories, 'XTickLabelRotation', 45);
ylabel('Volume [m^3]');
title('Volume Comparison');
grid on;

subplot(1,3,2);
bar(DL_ratios);
set(gca, 'XTickLabel', categories, 'XTickLabelRotation', 45);
ylabel('D/L Ratio [-]');
title('D/L Ratio Comparison');
grid on;

subplot(1,3,3);
bar(DP_totals);
set(gca, 'XTickLabel', categories, 'XTickLabelRotation', 45);
ylabel('Total Pressure Drop [Pa]');
title('Pressure Drop Comparison');
grid on;

sgtitle('Best Designs Comparison');
saveas(gcf, fullfile(results_folder, 'best_designs_comparison.png'));
saveas(gcf, fullfile(results_folder, 'best_designs_comparison.fig'));

% Figure 5: Heat map of design space
figure('Position', [50 50 1200 500]);

% Create grids for heatmap
[D_grid, L_grid] = meshgrid(D_int_range*1000, L_tube_range);
Vol_map = nan(size(D_grid));
DP_map = nan(size(D_grid));

for i = 1:length(all_results)
    d_idx = find(abs(D_int_range*1000 - all_results(i).D_int) < 0.1);
    l_idx = find(abs(L_tube_range - all_results(i).L_tube) < 0.01);
    if ~isempty(d_idx) && ~isempty(l_idx) && all_results(i).pitch_ratio == 1.25
        Vol_map(l_idx, d_idx) = all_results(i).volume;
        DP_map(l_idx, d_idx) = all_results(i).DP_total;
    end
end

subplot(1,2,1);
imagesc(D_int_range*1000, L_tube_range, Vol_map);
colorbar;
xlabel('Tube Internal Diameter [mm]');
ylabel('Tube Length [m]');
title('Volume [m^3] (Pitch Ratio = 1.25)');
set(gca, 'YDir', 'normal');

subplot(1,2,2);
imagesc(D_int_range*1000, L_tube_range, DP_map);
colorbar;
hold on;
contour(D_grid, L_grid, DP_map, [baseline_DP_total baseline_DP_total], 'w--', 'LineWidth', 2);
xlabel('Tube Internal Diameter [mm]');
ylabel('Tube Length [m]');
title(sprintf('Pressure Drop [Pa] (White line = %.0f Pa baseline)', baseline_DP_total));
set(gca, 'YDir', 'normal');

sgtitle('Design Space Heat Maps');
saveas(gcf, fullfile(results_folder, 'design_space_heatmaps.png'));
saveas(gcf, fullfile(results_folder, 'design_space_heatmaps.fig'));

%% Generate comprehensive summary report
summary_file = fullfile(results_folder, 'FINAL_OPTIMIZATION_SUMMARY.txt');
fid = fopen(summary_file, 'w');

fprintf(fid, '================================================================\n');
fprintf(fid, '     FINAL HEAT EXCHANGER OPTIMIZATION STUDY REPORT\n');
fprintf(fid, '     Generated: %s\n', datestr(now));
fprintf(fid, '================================================================\n\n');

fprintf(fid, '====== BASELINE DESIGN ======\n');
fprintf(fid, '  L_tube = 1.0 m\n');
fprintf(fid, '  D_int = 20 mm, D_ext = 24 mm\n');
fprintf(fid, '  N_p = 2 passes\n');
fprintf(fid, '  Pitch Ratio = 1.25\n');
fprintf(fid, '  ---\n');
fprintf(fid, '  Shell Diameter D_s = %.4f m\n', baseline.D_s);
fprintf(fid, '  Number of Tubes = %.1f\n', baseline.N_tt);
fprintf(fid, '  Volume = %.6f m3\n', baseline_volume);
fprintf(fid, '  D/L Ratio = %.4f\n', baseline_DL_ratio);
fprintf(fid, '  Tube-side dP = %.2f Pa\n', baseline.DP_t);
fprintf(fid, '  Shell-side dP = %.4f Pa\n', baseline.DP_s);
fprintf(fid, '  Total dP = %.2f Pa\n', baseline_DP_total);
fprintf(fid, '  Heat Duty = %.2f kW\n', baseline.Q_kW);
fprintf(fid, '  U_o = %.2f W/m2/K\n\n', baseline.U_o_calc);

fprintf(fid, '====== OPTIMIZATION OBJECTIVES ======\n');
fprintf(fid, '  1. Minimize Volume\n');
fprintf(fid, '  2. Minimize D/L Ratio (Diameter to Height)\n');
fprintf(fid, '  3. Pressure Drop < Baseline (%.2f Pa) - KEY CONSTRAINT\n\n', baseline_DP_total);

fprintf(fid, '====== SEARCH SPACE ======\n');
fprintf(fid, '  L_tube: %.1f to %.1f m (step 0.1)\n', min(L_tube_range), max(L_tube_range));
fprintf(fid, '  D_int: %.0f to %.0f mm (step 2)\n', min(D_int_range)*1000, max(D_int_range)*1000);
fprintf(fid, '  Pitch Ratio: 1.25, 1.30\n');
fprintf(fid, '  N_p: 2 (fixed - optimal for pressure drop)\n');
fprintf(fid, '  Total configurations tested: %d\n', length(all_results));
fprintf(fid, '  Designs meeting dP constraint: %d\n', length(valid_results));
fprintf(fid, '  Pareto-optimal designs: %d\n\n', length(pareto_results));

fprintf(fid, '====== BEST DESIGN - PRESSURE DROP PRIORITY ======\n');
fprintf(fid, '  (Weighting: 60%% dP, 25%% Volume, 15%% D/L)\n');
fprintf(fid, '  Parameters:\n');
fprintf(fid, '    L_tube = %.2f m\n', best_dp.L_tube);
fprintf(fid, '    D_int = %.0f mm, D_ext = %.0f mm\n', best_dp.D_int, best_dp.D_ext);
fprintf(fid, '    Pitch Ratio = %.2f\n', best_dp.pitch_ratio);
fprintf(fid, '  Results:\n');
fprintf(fid, '    Shell Diameter = %.4f m\n', best_dp.D_s);
fprintf(fid, '    Number of Tubes = %.1f\n', best_dp.N_tt);
fprintf(fid, '    Volume = %.6f m3 (%.1f%% vs baseline)\n', best_dp.volume, (best_dp.volume/baseline_volume-1)*100);
fprintf(fid, '    D/L Ratio = %.4f (%.1f%% vs baseline)\n', best_dp.DL_ratio, (1-best_dp.DL_ratio/baseline_DL_ratio)*100);
fprintf(fid, '    Total dP = %.2f Pa (%.1f%% reduction)\n', best_dp.DP_total, (1-best_dp.DP_total/baseline_DP_total)*100);
fprintf(fid, '    Score = %.4f\n\n', best_dp.score_dp_priority);

fprintf(fid, '====== BEST DESIGN - BALANCED ======\n');
fprintf(fid, '  (Weighting: 40%% dP, 35%% Volume, 25%% D/L)\n');
fprintf(fid, '  Parameters:\n');
fprintf(fid, '    L_tube = %.2f m\n', best_bal.L_tube);
fprintf(fid, '    D_int = %.0f mm, D_ext = %.0f mm\n', best_bal.D_int, best_bal.D_ext);
fprintf(fid, '    Pitch Ratio = %.2f\n', best_bal.pitch_ratio);
fprintf(fid, '  Results:\n');
fprintf(fid, '    Shell Diameter = %.4f m\n', best_bal.D_s);
fprintf(fid, '    Number of Tubes = %.1f\n', best_bal.N_tt);
fprintf(fid, '    Volume = %.6f m3 (%.1f%% vs baseline)\n', best_bal.volume, (best_bal.volume/baseline_volume-1)*100);
fprintf(fid, '    D/L Ratio = %.4f (%.1f%% vs baseline)\n', best_bal.DL_ratio, (1-best_bal.DL_ratio/baseline_DL_ratio)*100);
fprintf(fid, '    Total dP = %.2f Pa (%.1f%% reduction)\n', best_bal.DP_total, (1-best_bal.DP_total/baseline_DP_total)*100);
fprintf(fid, '    Score = %.4f\n\n', best_bal.score_balanced);

fprintf(fid, '====== BEST DESIGN - VOLUME PRIORITY ======\n');
fprintf(fid, '  (Weighting: 30%% dP, 50%% Volume, 20%% D/L)\n');
fprintf(fid, '  Parameters:\n');
fprintf(fid, '    L_tube = %.2f m\n', best_vol.L_tube);
fprintf(fid, '    D_int = %.0f mm, D_ext = %.0f mm\n', best_vol.D_int, best_vol.D_ext);
fprintf(fid, '    Pitch Ratio = %.2f\n', best_vol.pitch_ratio);
fprintf(fid, '  Results:\n');
fprintf(fid, '    Shell Diameter = %.4f m\n', best_vol.D_s);
fprintf(fid, '    Number of Tubes = %.1f\n', best_vol.N_tt);
fprintf(fid, '    Volume = %.6f m3 (%.1f%% vs baseline)\n', best_vol.volume, (best_vol.volume/baseline_volume-1)*100);
fprintf(fid, '    D/L Ratio = %.4f (%.1f%% vs baseline)\n', best_vol.DL_ratio, (1-best_vol.DL_ratio/baseline_DL_ratio)*100);
fprintf(fid, '    Total dP = %.2f Pa (%.1f%% reduction)\n', best_vol.DP_total, (1-best_vol.DP_total/baseline_DP_total)*100);
fprintf(fid, '    Score = %.4f\n\n', best_vol.score_vol_priority);

fprintf(fid, '====== PARETO-OPTIMAL DESIGNS ======\n');
if ~isempty(pareto_results)
    [~, sort_dp] = sort([pareto_results.DP_total]);
    pareto_sorted = pareto_results(sort_dp);
    n_show = min(10, length(pareto_sorted));
    fprintf(fid, 'Top %d Pareto-optimal designs (sorted by pressure drop):\n\n', n_show);
    for i = 1:n_show
        r = pareto_sorted(i);
        fprintf(fid, 'Design %d:\n', i);
        fprintf(fid, '  L=%.2fm, D_int=%.0fmm, pitch=%.2f\n', r.L_tube, r.D_int, r.pitch_ratio);
        fprintf(fid, '  Vol=%.6fm3, D/L=%.4f, dP=%.2fPa\n\n', r.volume, r.DL_ratio, r.DP_total);
    end
end

fprintf(fid, '====== KEY INSIGHTS ======\n');
fprintf(fid, '1. Tube-side pressure drop (%.2f Pa) dominates total dP\n', baseline.DP_t);
fprintf(fid, '2. Shell-side dP (%.4f Pa) is negligible\n', baseline.DP_s);
fprintf(fid, '3. Larger tube diameter reduces dP but increases volume\n');
fprintf(fid, '4. Longer tubes improve D/L ratio significantly\n');
fprintf(fid, '5. N_p=2 is optimal; higher passes dramatically increase dP\n');
fprintf(fid, '6. Trade-off exists: cannot simultaneously minimize volume and dP\n');
fprintf(fid, '7. Best balanced design uses longer tubes with larger diameter\n\n');

fprintf(fid, '====== RECOMMENDATIONS ======\n');
fprintf(fid, '1. For minimum pressure drop: Use D_int=%.0fmm, L=%.2fm\n', best_dp.D_int, best_dp.L_tube);
fprintf(fid, '2. For balanced performance: Use D_int=%.0fmm, L=%.2fm\n', best_bal.D_int, best_bal.L_tube);
fprintf(fid, '3. Keep N_p=2 passes to minimize tube-side dP\n');
fprintf(fid, '4. Pitch ratio has minimal impact; use 1.25 (TEMA minimum)\n');
fprintf(fid, '5. Baffle parameters have negligible effect on objectives\n\n');

fprintf(fid, '================================================================\n');
fprintf(fid, '                    END OF REPORT\n');
fprintf(fid, '================================================================\n');

fclose(fid);

fprintf('\nFinal summary saved to: %s\n', summary_file);

%% Save all data
save(fullfile(results_folder, 'final_optimization_data.mat'), ...
     'all_results', 'valid_results', 'pareto_results', ...
     'best_dp', 'best_bal', 'best_vol', ...
     'baseline', 'baseline_volume', 'baseline_DL_ratio', 'baseline_DP_total');

fprintf('\n========== FINAL OPTIMIZATION COMPLETE ==========\n\n');

% Print summary to console
fprintf('SUMMARY OF BEST DESIGNS:\n');
fprintf('------------------------------------------------------------------\n');
fprintf('%-20s %-12s %-12s %-12s\n', 'Design', 'Volume [m3]', 'D/L Ratio', 'dP [Pa]');
fprintf('------------------------------------------------------------------\n');
fprintf('%-20s %-12.6f %-12.4f %-12.2f\n', 'Baseline', baseline_volume, baseline_DL_ratio, baseline_DP_total);
fprintf('%-20s %-12.6f %-12.4f %-12.2f\n', 'Best dP Priority', best_dp.volume, best_dp.DL_ratio, best_dp.DP_total);
fprintf('%-20s %-12.6f %-12.4f %-12.2f\n', 'Best Balanced', best_bal.volume, best_bal.DL_ratio, best_bal.DP_total);
fprintf('%-20s %-12.6f %-12.4f %-12.2f\n', 'Best Vol Priority', best_vol.volume, best_vol.DL_ratio, best_vol.DP_total);
fprintf('------------------------------------------------------------------\n');
