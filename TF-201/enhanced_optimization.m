%% ENHANCED_OPTIMIZATION
% Extended parametric study to find optimal pressure drop
% Based on findings from initial study - extending parameter ranges
%
% Key Insights from Initial Study:
%   - Rib thickness (t) optimal was at edge of range (0.10m) - extend further
%   - Channel width (w) optimal was ~0.12m - but could go higher
%   - D_jacket had minimal impact once w and t are optimized
%
% New Ranges:
%   - t: 0.05m to 0.30m (fewer turns = shorter coil = lower DP)
%   - w: 0.05m to 0.20m (larger channel = larger D_h = lower DP)
%   - D_jacket: 0.52m to 0.65m
%
% Additional Constraint: Minimum 5 helical turns for manufacturing

clear; clc; close all;

%% ---- Setup Results Directory ----
timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
results_folder = fullfile(pwd, sprintf('results_enhanced_%s', timestamp));
mkdir(results_folder);

fprintf('================================================================\n');
fprintf('  ENHANCED OPTIMIZATION STUDY\n');
fprintf('  Extended Parameter Ranges for Further DP Reduction\n');
fprintf('  Results: %s\n', results_folder);
fprintf('================================================================\n\n');

%% ---- Fixed Parameters ----
fixed_params = struct();
fixed_params.D_pyrolizer = 0.50;
fixed_params.L = 4.20;
fixed_params.m_dot = 0.25;
fixed_params.T_hot1 = 302.0064732 + 273.15;
fixed_params.T_cold = 280 + 273.15;
fixed_params.Q_req = 11290;
fixed_params.rho = 689.5;
fixed_params.Cp = 2150;
fixed_params.mu = 0.41e-3;
fixed_params.k_fluid = 0.076;
fixed_params.f_c = 0.009;

MIN_TURNS = 5;  % Practical constraint: minimum number of helical turns

%% ---- Extended Parameter Ranges ----
% Coarse grid for initial scan
D_jacket_range = linspace(0.52, 0.65, 15);
w_range = linspace(0.05, 0.20, 20);
t_range = linspace(0.05, 0.30, 20);

fprintf('Extended Ranges:\n');
fprintf('  D_jacket: %.2f - %.2f m\n', min(D_jacket_range), max(D_jacket_range));
fprintf('  w:        %.2f - %.2f m\n', min(w_range), max(w_range));
fprintf('  t:        %.2f - %.2f m\n', min(t_range), max(t_range));
fprintf('  Min turns: %d\n\n', MIN_TURNS);

%% ---- Full 3D Parameter Space Search ----
fprintf('Running Full 3D Extended Search...\n');

n_combinations = length(D_jacket_range) * length(w_range) * length(t_range);
results_table = zeros(n_combinations, 10);
idx = 0;

for i = 1:length(D_jacket_range)
    for j = 1:length(w_range)
        for k = 1:length(t_range)
            idx = idx + 1;
            D_jkt = D_jacket_range(i);
            w = w_range(j);
            t = t_range(k);

            % Calculate pitch and turns
            P = w + t;
            N_turn = fixed_params.L / P;

            params = fixed_params;
            params.D_jacket = D_jkt;
            params.w = w;
            params.t = t;

            try
                res = torrefaction_heating_jacket_silent(params);

                % Check constraints
                meets_turns = N_turn >= MIN_TURNS;
                meets_DP = res.DP_kPa < 8.5;
                valid = res.design_ok && meets_turns && meets_DP;

                results_table(idx, :) = [D_jkt, w, t, res.DP_kPa, ...
                    res.design_ok, N_turn, res.GAP, res.D_h, res.v, valid];
            catch
                results_table(idx, :) = [D_jkt, w, t, NaN, 0, N_turn, NaN, NaN, NaN, 0];
            end
        end
    end
end

% Column names: D_jkt, w, t, DP_kPa, design_ok, N_turn, GAP, D_h, v, valid

%% ---- Filter Valid Designs ----
valid_mask = results_table(:, 10) == 1;
valid_results = results_table(valid_mask, :);

fprintf('  Total combinations: %d\n', n_combinations);
fprintf('  Valid designs:      %d\n', sum(valid_mask));

if ~isempty(valid_results)
    [min_DP, best_idx] = min(valid_results(:, 4));
    best = valid_results(best_idx, :);

    fprintf('\n  BEST DESIGN:\n');
    fprintf('    D_jacket      = %.4f m (%.2f cm)\n', best(1), best(1)*100);
    fprintf('    w             = %.4f m (%.2f cm)\n', best(2), best(2)*100);
    fprintf('    t             = %.4f m (%.2f cm)\n', best(3), best(3)*100);
    fprintf('    Pitch         = %.4f m (%.2f cm)\n', best(2)+best(3), (best(2)+best(3))*100);
    fprintf('    N_turns       = %.1f\n', best(6));
    fprintf('    GAP           = %.4f m (%.2f cm)\n', best(7), best(7)*100);
    fprintf('    D_h           = %.4f m (%.2f cm)\n', best(8), best(8)*100);
    fprintf('    Velocity      = %.4f m/s\n', best(9));
    fprintf('    Pressure Drop = %.4f kPa\n', best(4));
else
    fprintf('  WARNING: No valid designs found!\n');
    best = [];
end

%% ---- Fine-Tune Around Best Solution ----
if ~isempty(best)
    fprintf('\nFine-tuning around best solution...\n');

    % Create fine grid around best parameters
    D_jkt_fine = linspace(best(1)*0.95, min(best(1)*1.05, 0.70), 20);
    w_fine = linspace(best(2)*0.90, min(best(2)*1.10, 0.25), 20);
    t_fine = linspace(best(3)*0.90, min(best(3)*1.10, 0.40), 20);

    n_fine = length(D_jkt_fine) * length(w_fine) * length(t_fine);
    fine_results = zeros(n_fine, 10);
    idx = 0;

    for i = 1:length(D_jkt_fine)
        for j = 1:length(w_fine)
            for k = 1:length(t_fine)
                idx = idx + 1;
                D_jkt = D_jkt_fine(i);
                w = w_fine(j);
                t = t_fine(k);
                P = w + t;
                N_turn = fixed_params.L / P;

                params = fixed_params;
                params.D_jacket = D_jkt;
                params.w = w;
                params.t = t;

                try
                    res = torrefaction_heating_jacket_silent(params);
                    meets_turns = N_turn >= MIN_TURNS;
                    meets_DP = res.DP_kPa < 8.5;
                    valid = res.design_ok && meets_turns && meets_DP;
                    fine_results(idx, :) = [D_jkt, w, t, res.DP_kPa, ...
                        res.design_ok, N_turn, res.GAP, res.D_h, res.v, valid];
                catch
                    fine_results(idx, :) = [D_jkt, w, t, NaN, 0, N_turn, NaN, NaN, NaN, 0];
                end
            end
        end
    end

    valid_fine = fine_results(fine_results(:, 10) == 1, :);
    if ~isempty(valid_fine)
        [min_DP_fine, best_fine_idx] = min(valid_fine(:, 4));
        best_fine = valid_fine(best_fine_idx, :);

        fprintf('\n  FINE-TUNED BEST:\n');
        fprintf('    D_jacket      = %.4f m (%.2f cm)\n', best_fine(1), best_fine(1)*100);
        fprintf('    w             = %.4f m (%.2f cm)\n', best_fine(2), best_fine(2)*100);
        fprintf('    t             = %.4f m (%.2f cm)\n', best_fine(3), best_fine(3)*100);
        fprintf('    Pitch         = %.4f m (%.2f cm)\n', best_fine(2)+best_fine(3), (best_fine(2)+best_fine(3))*100);
        fprintf('    N_turns       = %.1f\n', best_fine(6));
        fprintf('    Pressure Drop = %.4f kPa\n', best_fine(4));
    else
        best_fine = best;
    end
else
    best_fine = [];
end

%% ---- Physical Limits Analysis ----
fprintf('\n--- Physical Limits Analysis ---\n');

% Find designs at the edge of the valid region
if ~isempty(valid_results)
    % What happens as we increase t further?
    test_t_values = linspace(0.30, 0.60, 10);
    test_results = zeros(length(test_t_values), 5);

    for k = 1:length(test_t_values)
        params = fixed_params;
        params.D_jacket = best(1);
        params.w = best(2);
        params.t = test_t_values(k);
        P = params.w + params.t;
        N_turn = fixed_params.L / P;

        res = torrefaction_heating_jacket_silent(params);
        test_results(k, :) = [test_t_values(k), res.DP_kPa, N_turn, res.design_ok, res.A_av >= res.A_req];
    end

    fprintf('Testing larger rib thickness (t):\n');
    fprintf('  t [m]    DP [kPa]   Turns    Valid\n');
    for k = 1:length(test_t_values)
        fprintf('  %.3f    %.4f     %.1f      %d\n', ...
            test_results(k,1), test_results(k,2), test_results(k,3), test_results(k,4));
    end
end

%% ---- Generate Enhanced Figures ----
fprintf('\nGenerating figures...\n');

% Figure 1: Extended w vs t contour (at optimal D_jacket)
if ~isempty(best_fine)
    opt_D_jkt = best_fine(1);
else
    opt_D_jkt = 0.53;
end

[W_grid, T_grid] = meshgrid(w_range, t_range);
DP_wt = zeros(size(W_grid));
valid_wt = false(size(W_grid));
turns_wt = zeros(size(W_grid));

for i = 1:numel(W_grid)
    params = fixed_params;
    params.D_jacket = opt_D_jkt;
    params.w = W_grid(i);
    params.t = T_grid(i);
    P = params.w + params.t;
    N_turn = fixed_params.L / P;

    try
        res = torrefaction_heating_jacket_silent(params);
        DP_wt(i) = res.DP_kPa;
        valid_wt(i) = res.design_ok && (N_turn >= MIN_TURNS);
        turns_wt(i) = N_turn;
    catch
        DP_wt(i) = NaN;
        valid_wt(i) = false;
        turns_wt(i) = NaN;
    end
end

DP_wt_valid = DP_wt;
DP_wt_valid(~valid_wt) = NaN;

fig1 = figure('Position', [100 100 900 700], 'Visible', 'off');
contourf(w_range*100, t_range*100, DP_wt_valid, 30, 'LineColor', 'none');
hold on;
contour(w_range*100, t_range*100, DP_wt_valid, [8.5 8.5], 'r-', 'LineWidth', 2);
contour(w_range*100, t_range*100, DP_wt_valid, [1 1], 'g--', 'LineWidth', 2);
contour(w_range*100, t_range*100, DP_wt_valid, [0.5 0.5], 'm--', 'LineWidth', 2);
if ~isempty(best_fine)
    plot(best_fine(2)*100, best_fine(3)*100, 'ko', 'MarkerSize', 15, 'MarkerFaceColor', 'w', 'LineWidth', 3);
end
colorbar;
colormap(jet);
xlabel('Channel Width w [cm]', 'FontSize', 12);
ylabel('Rib Thickness t [cm]', 'FontSize', 12);
title(sprintf('Extended Study: Pressure Drop [kPa] (D_{jacket} = %.1f cm)', opt_D_jkt*100), 'FontSize', 14);
legend('', 'DP = 8.5 kPa', 'DP = 1.0 kPa', 'DP = 0.5 kPa', 'Optimal', 'Location', 'southwest');
grid on;
saveas(fig1, fullfile(results_folder, 'extended_w_vs_t_contour.png'));
close(fig1);

% Figure 2: Number of turns overlay
fig2 = figure('Position', [100 100 900 700], 'Visible', 'off');
turns_display = turns_wt;
turns_display(~valid_wt) = NaN;
contourf(w_range*100, t_range*100, turns_display, 20, 'LineColor', 'none');
hold on;
contour(w_range*100, t_range*100, turns_display, [MIN_TURNS MIN_TURNS], 'r-', 'LineWidth', 3);
contour(w_range*100, t_range*100, turns_display, [10 10], 'g--', 'LineWidth', 2);
colorbar;
colormap(copper);
xlabel('Channel Width w [cm]', 'FontSize', 12);
ylabel('Rib Thickness t [cm]', 'FontSize', 12);
title('Number of Helical Turns (Constraint: min 5 turns)', 'FontSize', 14);
legend('', sprintf('N = %d (minimum)', MIN_TURNS), 'N = 10', 'Location', 'southwest');
grid on;
saveas(fig2, fullfile(results_folder, 'number_of_turns.png'));
close(fig2);

% Figure 3: DP vs Number of Turns
fig3 = figure('Position', [100 100 800 600], 'Visible', 'off');
if ~isempty(valid_results)
    scatter(valid_results(:,6), valid_results(:,4), 30, valid_results(:,2)*100, 'filled');
    hold on;
    yline(8.5, 'r--', 'LineWidth', 2);
    xline(MIN_TURNS, 'k--', 'LineWidth', 2);
    colorbar;
    colormap(jet);
    xlabel('Number of Helical Turns', 'FontSize', 12);
    ylabel('Pressure Drop [kPa]', 'FontSize', 12);
    title('Pressure Drop vs Number of Turns (Color = Channel Width [cm])', 'FontSize', 14);
    legend('Valid designs', '8.5 kPa limit', 'Min turns', 'Location', 'best');
    grid on;
end
saveas(fig3, fullfile(results_folder, 'DP_vs_turns.png'));
close(fig3);

% Figure 4: Pareto Front - DP vs Physical Constraints
fig4 = figure('Position', [100 100 1000 400], 'Visible', 'off');
if ~isempty(valid_results)
    subplot(1,2,1);
    scatter(valid_results(:,7)*100, valid_results(:,4), 30, valid_results(:,8)*100, 'filled');
    colorbar;
    xlabel('Annular Gap [cm]', 'FontSize', 11);
    ylabel('Pressure Drop [kPa]', 'FontSize', 11);
    title('DP vs GAP (Color = D_h [cm])', 'FontSize', 12);
    grid on;

    subplot(1,2,2);
    scatter(valid_results(:,9), valid_results(:,4), 30, valid_results(:,2)*100, 'filled');
    colorbar;
    xlabel('Fluid Velocity [m/s]', 'FontSize', 11);
    ylabel('Pressure Drop [kPa]', 'FontSize', 11);
    title('DP vs Velocity (Color = w [cm])', 'FontSize', 12);
    grid on;
end
saveas(fig4, fullfile(results_folder, 'pareto_analysis.png'));
close(fig4);

% Figure 5: Design Trade-off Surface
fig5 = figure('Position', [100 100 900 700], 'Visible', 'off');
if ~isempty(valid_results)
    % Bin by turns
    turn_bins = [5, 10, 15, 20, 30, 50];
    colors = lines(length(turn_bins)-1);
    hold on;

    for b = 1:length(turn_bins)-1
        mask = valid_results(:,6) >= turn_bins(b) & valid_results(:,6) < turn_bins(b+1);
        if any(mask)
            scatter(valid_results(mask,2)*100, valid_results(mask,4), 40, colors(b,:), 'filled', 'DisplayName', sprintf('%d-%d turns', turn_bins(b), turn_bins(b+1)));
        end
    end

    yline(8.5, 'r--', 'LineWidth', 2, 'DisplayName', '8.5 kPa limit');
    xlabel('Channel Width w [cm]', 'FontSize', 12);
    ylabel('Pressure Drop [kPa]', 'FontSize', 12);
    title('Design Trade-off: Turns vs Channel Width', 'FontSize', 14);
    legend('Location', 'northeast');
    grid on;
end
saveas(fig5, fullfile(results_folder, 'design_tradeoff.png'));
close(fig5);

% Figure 6: Final Comparison
fig6 = figure('Position', [100 100 900 500], 'Visible', 'off');
baseline_DP = 8.558;
study1_DP = 1.033;  % From initial study
study3_DP = 0.798;  % From initial study

designs = {'Baseline', 'Initial Study 1', 'Initial Study 3', 'Extended Optimal'};
if ~isempty(best_fine)
    DPs = [baseline_DP, study1_DP, study3_DP, best_fine(4)];
else
    DPs = [baseline_DP, study1_DP, study3_DP, NaN];
end
colors = [0.7 0.7 0.7; 0.3 0.6 0.9; 0.9 0.6 0.3; 0.2 0.8 0.2];

b = bar(DPs);
b.FaceColor = 'flat';
for i = 1:length(DPs)
    b.CData(i,:) = colors(i,:);
end
hold on;
yline(8.5, 'r--', 'LineWidth', 2);
set(gca, 'XTickLabel', designs, 'FontSize', 11);
ylabel('Pressure Drop [kPa]', 'FontSize', 12);
title('Comparison: Baseline vs Optimized Designs', 'FontSize', 14);
grid on;

for i = 1:length(DPs)
    if ~isnan(DPs(i))
        text(i, DPs(i) + 0.3, sprintf('%.2f kPa', DPs(i)), 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
        if i > 1
            reduction = (1 - DPs(i)/baseline_DP) * 100;
            text(i, DPs(i) - 0.3, sprintf('(-%.0f%%)', reduction), 'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0 0.5 0]);
        end
    end
end

saveas(fig6, fullfile(results_folder, 'final_comparison.png'));
close(fig6);

%% ---- Generate Summary Report ----
fprintf('\nGenerating summary report...\n');

summary_file = fullfile(results_folder, 'ENHANCED_SUMMARY.txt');
fid = fopen(summary_file, 'w');

fprintf(fid, '================================================================\n');
fprintf(fid, '  ENHANCED OPTIMIZATION SUMMARY\n');
fprintf(fid, '  Extended Parametric Study Results\n');
fprintf(fid, '  Generated: %s\n', datestr(now));
fprintf(fid, '================================================================\n\n');

fprintf(fid, 'OBJECTIVE:\n');
fprintf(fid, '  Further minimize pressure drop by extending parameter ranges\n');
fprintf(fid, '  Constraints:\n');
fprintf(fid, '    - DP < 8.5 kPa\n');
fprintf(fid, '    - Minimum %d helical turns (manufacturing)\n', MIN_TURNS);
fprintf(fid, '    - Valid thermal design (A_av >= A_req)\n\n');

fprintf(fid, 'EXTENDED PARAMETER RANGES:\n');
fprintf(fid, '  D_jacket : %.2f - %.2f m\n', min(D_jacket_range), max(D_jacket_range));
fprintf(fid, '  w        : %.2f - %.2f m\n', min(w_range), max(w_range));
fprintf(fid, '  t        : %.2f - %.2f m\n\n', min(t_range), max(t_range));

fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, 'RESULTS COMPARISON:\n');
fprintf(fid, '----------------------------------------------------------------\n\n');

fprintf(fid, 'Baseline Design:\n');
fprintf(fid, '  D_jacket = 0.530 m, w = 0.050 m, t = 0.050 m\n');
fprintf(fid, '  Pressure Drop = 8.558 kPa\n\n');

fprintf(fid, 'Initial Study Best (Study 3):\n');
fprintf(fid, '  w = 0.1175 m, t = 0.100 m\n');
fprintf(fid, '  Pressure Drop = 0.798 kPa (90.7%% reduction)\n\n');

if ~isempty(best_fine)
    fprintf(fid, 'EXTENDED OPTIMIZATION BEST:\n');
    fprintf(fid, '  D_jacket      = %.4f m (%.2f cm)\n', best_fine(1), best_fine(1)*100);
    fprintf(fid, '  w             = %.4f m (%.2f cm)\n', best_fine(2), best_fine(2)*100);
    fprintf(fid, '  t             = %.4f m (%.2f cm)\n', best_fine(3), best_fine(3)*100);
    fprintf(fid, '  Pitch (w+t)   = %.4f m (%.2f cm)\n', best_fine(2)+best_fine(3), (best_fine(2)+best_fine(3))*100);
    fprintf(fid, '  N_turns       = %.1f\n', best_fine(6));
    fprintf(fid, '  Annular Gap   = %.4f m (%.2f cm)\n', best_fine(7), best_fine(7)*100);
    fprintf(fid, '  Hydraulic Dia = %.4f m (%.2f cm)\n', best_fine(8), best_fine(8)*100);
    fprintf(fid, '  Velocity      = %.4f m/s\n', best_fine(9));
    fprintf(fid, '  Pressure Drop = %.4f kPa\n', best_fine(4));
    fprintf(fid, '\n  IMPROVEMENT: %.1f%% reduction from baseline\n', (1-best_fine(4)/baseline_DP)*100);
    fprintf(fid, '               %.1f%% further reduction from initial study\n', (1-best_fine(4)/0.798)*100);
end

fprintf(fid, '\n----------------------------------------------------------------\n');
fprintf(fid, 'PHYSICAL INSIGHTS:\n');
fprintf(fid, '----------------------------------------------------------------\n');
fprintf(fid, '1. Pressure drop scales approximately with:\n');
fprintf(fid, '   DP ~ L_coil/D_h * v^2\n\n');
fprintf(fid, '2. Increasing pitch (w+t) reduces number of turns,\n');
fprintf(fid, '   which reduces total coil length L_coil\n\n');
fprintf(fid, '3. Increasing channel width (w) increases both:\n');
fprintf(fid, '   - Flow area (reduces velocity)\n');
fprintf(fid, '   - Hydraulic diameter (reduces friction)\n\n');
fprintf(fid, '4. The minimum turns constraint (N >= %d) limits how\n', MIN_TURNS);
fprintf(fid, '   large the pitch can be: P_max = L/%d = %.3f m\n\n', MIN_TURNS, fixed_params.L/MIN_TURNS);
fprintf(fid, '5. For manufacturing, ensure:\n');
fprintf(fid, '   - Channel width is machinable\n');
fprintf(fid, '   - Rib thickness provides structural integrity\n');
fprintf(fid, '   - Annular gap is suitable for fluid distribution\n');

fprintf(fid, '\n----------------------------------------------------------------\n');
fprintf(fid, 'RECOMMENDATIONS:\n');
fprintf(fid, '----------------------------------------------------------------\n');
if ~isempty(best_fine) && best_fine(4) < 1.0
    fprintf(fid, '1. The optimized design achieves excellent pressure drop (< 1 kPa)\n');
    fprintf(fid, '2. Consider manufacturing constraints:\n');
    fprintf(fid, '   - Channel width of %.1f cm may require special tooling\n', best_fine(2)*100);
    fprintf(fid, '   - Rib thickness of %.1f cm provides good structural support\n', best_fine(3)*100);
    fprintf(fid, '3. The reduced number of turns (%d) simplifies fabrication\n', round(best_fine(6)));
    fprintf(fid, '4. Verify flow distribution with CFD if annular gap is large\n');
end

fprintf(fid, '\n================================================================\n');
fprintf(fid, '  END OF REPORT\n');
fprintf(fid, '================================================================\n');

fclose(fid);

%% ---- Save Data ----
save(fullfile(results_folder, 'enhanced_optimization_data.mat'), ...
    'results_table', 'valid_results', 'best', 'best_fine', ...
    'D_jacket_range', 'w_range', 't_range', 'fixed_params');

fprintf('\n================================================================\n');
fprintf('  ENHANCED OPTIMIZATION COMPLETE\n');
fprintf('  Results saved to: %s\n', results_folder);
fprintf('================================================================\n');

%% ---- Helper Function ----
function results = torrefaction_heating_jacket_silent(params)
    def = struct( ...
        'D_pyrolizer', 0.50, 'D_jacket', 0.53, 'L', 4.20, ...
        'w', 0.05, 't', 0.05, ...
        'T_hot1', 302.0064732 + 273.15, 'm_dot', 0.25, ...
        'T_cold', 280 + 273.15, 'Q_req', 11290, ...
        'rho', 689.5, 'Cp', 2150, 'mu', 0.41e-3, ...
        'k_fluid', 0.076, 'f_c', 0.009);

    flds = fieldnames(def);
    for i = 1:numel(flds)
        if ~isfield(params, flds{i})
            params.(flds{i}) = def.(flds{i});
        end
    end

    D_pyr = params.D_pyrolizer; D_jkt = params.D_jacket;
    L = params.L; w = params.w; t = params.t;
    T_hot1 = params.T_hot1; m_dot = params.m_dot;
    T_cold = params.T_cold; Q_req = params.Q_req;
    rho = params.rho; Cp = params.Cp; mu = params.mu;
    k_fl = params.k_fluid; f_c = params.f_c;

    P = w + t;
    N_turn = L / P;
    D_coil = (D_jkt + D_pyr) / 2;
    L_turn = sqrt((pi * D_coil)^2 + P^2);
    L_coil = N_turn * L_turn;
    GAP = (D_jkt - D_pyr) / 2;
    A_c = GAP * w;
    D_h = 2 * GAP * w / (GAP + w);

    T_hot2 = T_hot1 - Q_req / (m_dot * Cp);
    v = m_dot / (rho * A_c);
    Re = rho * v * D_h / mu;
    Pr = Cp * mu / k_fl;

    Nu = 0.023 * Re^0.85 * Pr^0.3 * (D_h / D_coil)^0.1;
    h_j = Nu * k_fl / D_h;

    A_surface = pi * D_pyr * L;
    dT1 = T_hot1 - T_cold;
    dT2 = T_hot2 - T_cold;
    DeltaT_lm = (dT1 - dT2) / log(dT1 / dT2);
    A_req = Q_req / (h_j * DeltaT_lm);
    design_ok = A_surface >= A_req;

    DP = 4 * f_c * (L_coil / D_h) * (rho * v^2 / 2);
    DP_kPa = DP / 1000;

    results = struct('P', P, 'N_turn', N_turn, 'D_coil', D_coil, ...
        'L_turn', L_turn, 'L_coil', L_coil, 'GAP', GAP, 'A_c', A_c, ...
        'D_h', D_h, 'T_hot2', T_hot2, 'v', v, 'Re', Re, 'Pr', Pr, ...
        'Nu', Nu, 'h_j', h_j, 'DeltaT_lm', DeltaT_lm, 'A_req', A_req, ...
        'A_av', A_surface, 'design_ok', design_ok, 'DP', DP, 'DP_kPa', DP_kPa);
end
