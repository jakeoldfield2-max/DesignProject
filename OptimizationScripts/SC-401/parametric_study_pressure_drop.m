function parametric_study_pressure_drop()
% PARAMETRIC_STUDY_PRESSURE_DROP  Run parametric studies to minimize pressure drop
%   in the screw separator cooling jacket while maintaining design validity.
%
%   Creates a results folder with timestamp containing:
%   - Plots showing parameter effects on pressure drop
%   - Summary text file with optimal configurations
%
%   Variables studied (rib and shell geometry):
%   - GAP: Annular gap (shell geometry) [m]
%   - w: Channel width (rib geometry) [m]
%   - t_wall: Wall thickness between channels (rib geometry) [m]

    %% Create results folder with timestamp
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    results_folder = fullfile(pwd, 'results', ['Study_' timestamp]);
    if ~exist(results_folder, 'dir')
        mkdir(results_folder);
    end

    fprintf('=== Parametric Study for Pressure Drop Minimization ===\n');
    fprintf('Results will be saved to: %s\n\n', results_folder);

    %% Baseline parameters
    baseline.GAP = 0.01;      % [m] annular gap
    baseline.w = 0.03;        % [m] channel width
    baseline.t_wall = 0.02;   % [m] wall thickness

    % Run baseline
    base_results = screw_separator_cooling_jacket(baseline);
    fprintf('Baseline Pressure Drop: %.2f kPa\n', base_results.DP_kPa);
    fprintf('Baseline Design OK: %s\n\n', string(base_results.design_ok));

    %% Study 1: Single Parameter Sweeps
    fprintf('--- Study 1: Single Parameter Sweeps ---\n');

    % GAP sweep
    GAP_range = linspace(0.005, 0.025, 30);
    [DP_GAP, valid_GAP, Re_GAP, h_GAP] = sweep_parameter('GAP', GAP_range, baseline);

    % w sweep
    w_range = linspace(0.015, 0.06, 30);
    [DP_w, valid_w, Re_w, h_w] = sweep_parameter('w', w_range, baseline);

    % t_wall sweep
    t_wall_range = linspace(0.005, 0.04, 30);
    [DP_t, valid_t, Re_t, h_t] = sweep_parameter('t_wall', t_wall_range, baseline);

    %% Plot Study 1 Results
    fig1 = figure('Position', [100 100 1400 900], 'Color', 'w');

    % GAP subplot
    subplot(2,3,1);
    plot_single_sweep(GAP_range*1000, DP_GAP, valid_GAP, 'GAP [mm]', baseline.GAP*1000);
    title('Pressure Drop vs GAP (Annular Gap)');

    subplot(2,3,4);
    yyaxis left;
    plot(GAP_range*1000, Re_GAP, 'b-', 'LineWidth', 1.5);
    ylabel('Reynolds Number');
    yyaxis right;
    plot(GAP_range*1000, h_GAP, 'r-', 'LineWidth', 1.5);
    ylabel('Heat Transfer Coeff [W/(m^2K)]');
    xlabel('GAP [mm]');
    title('Re and h_j vs GAP');
    grid on;

    % w subplot
    subplot(2,3,2);
    plot_single_sweep(w_range*1000, DP_w, valid_w, 'Channel Width w [mm]', baseline.w*1000);
    title('Pressure Drop vs Channel Width');

    subplot(2,3,5);
    yyaxis left;
    plot(w_range*1000, Re_w, 'b-', 'LineWidth', 1.5);
    ylabel('Reynolds Number');
    yyaxis right;
    plot(w_range*1000, h_w, 'r-', 'LineWidth', 1.5);
    ylabel('Heat Transfer Coeff [W/(m^2K)]');
    xlabel('Channel Width w [mm]');
    title('Re and h_j vs Channel Width');
    grid on;

    % t_wall subplot
    subplot(2,3,3);
    plot_single_sweep(t_wall_range*1000, DP_t, valid_t, 'Wall Thickness t [mm]', baseline.t_wall*1000);
    title('Pressure Drop vs Wall Thickness');

    subplot(2,3,6);
    yyaxis left;
    plot(t_wall_range*1000, Re_t, 'b-', 'LineWidth', 1.5);
    ylabel('Reynolds Number');
    yyaxis right;
    plot(t_wall_range*1000, h_t, 'r-', 'LineWidth', 1.5);
    ylabel('Heat Transfer Coeff [W/(m^2K)]');
    xlabel('Wall Thickness t [mm]');
    title('Re and h_j vs Wall Thickness');
    grid on;

    sgtitle('Study 1: Single Parameter Sweeps', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig1, fullfile(results_folder, 'Study1_SingleParameterSweeps.png'));
    fprintf('Saved: Study1_SingleParameterSweeps.png\n');

    %% Study 2: GAP vs w (2D sweep with fixed t_wall)
    fprintf('\n--- Study 2: GAP vs Channel Width (2D Sweep) ---\n');

    GAP_2d = linspace(0.008, 0.02, 25);
    w_2d = linspace(0.02, 0.05, 25);
    [GAP_grid, w_grid] = meshgrid(GAP_2d, w_2d);
    DP_grid = zeros(size(GAP_grid));
    valid_grid = zeros(size(GAP_grid));

    for i = 1:numel(GAP_grid)
        params = baseline;
        params.GAP = GAP_grid(i);
        params.w = w_grid(i);
        try
            r = screw_separator_cooling_jacket(params);
            DP_grid(i) = r.DP_kPa;
            valid_grid(i) = r.design_ok;
        catch
            DP_grid(i) = NaN;
            valid_grid(i) = 0;
        end
    end

    % Mask invalid designs
    DP_valid = DP_grid;
    DP_valid(~valid_grid) = NaN;

    fig2 = figure('Position', [100 100 1200 500], 'Color', 'w');

    subplot(1,2,1);
    contourf(GAP_grid*1000, w_grid*1000, DP_grid, 20);
    colorbar;
    hold on;
    contour(GAP_grid*1000, w_grid*1000, valid_grid, [0.5 0.5], 'r-', 'LineWidth', 2);
    plot(baseline.GAP*1000, baseline.w*1000, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'y');
    xlabel('GAP [mm]');
    ylabel('Channel Width w [mm]');
    title('Pressure Drop [kPa] (All Designs)');
    legend('', 'Design Validity Boundary', 'Baseline', 'Location', 'best');

    subplot(1,2,2);
    contourf(GAP_grid*1000, w_grid*1000, DP_valid, 20);
    colorbar;
    hold on;
    [min_DP, min_idx] = min(DP_valid(:));
    if ~isnan(min_DP)
        plot(GAP_grid(min_idx)*1000, w_grid(min_idx)*1000, 'g*', 'MarkerSize', 15, 'LineWidth', 2);
    end
    plot(baseline.GAP*1000, baseline.w*1000, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'y');
    xlabel('GAP [mm]');
    ylabel('Channel Width w [mm]');
    title('Pressure Drop [kPa] (Valid Designs Only)');
    legend('', 'Minimum DP Point', 'Baseline', 'Location', 'best');

    sgtitle(sprintf('Study 2: GAP vs Channel Width (t_{wall} = %.0f mm)', baseline.t_wall*1000), 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig2, fullfile(results_folder, 'Study2_GAP_vs_ChannelWidth.png'));
    fprintf('Saved: Study2_GAP_vs_ChannelWidth.png\n');

    %% Study 3: GAP vs t_wall (2D sweep with fixed w)
    fprintf('\n--- Study 3: GAP vs Wall Thickness (2D Sweep) ---\n');

    GAP_3 = linspace(0.008, 0.02, 25);
    t_3 = linspace(0.005, 0.03, 25);
    [GAP_grid3, t_grid3] = meshgrid(GAP_3, t_3);
    DP_grid3 = zeros(size(GAP_grid3));
    valid_grid3 = zeros(size(GAP_grid3));

    for i = 1:numel(GAP_grid3)
        params = baseline;
        params.GAP = GAP_grid3(i);
        params.t_wall = t_grid3(i);
        try
            r = screw_separator_cooling_jacket(params);
            DP_grid3(i) = r.DP_kPa;
            valid_grid3(i) = r.design_ok;
        catch
            DP_grid3(i) = NaN;
            valid_grid3(i) = 0;
        end
    end

    DP_valid3 = DP_grid3;
    DP_valid3(~valid_grid3) = NaN;

    fig3 = figure('Position', [100 100 1200 500], 'Color', 'w');

    subplot(1,2,1);
    contourf(GAP_grid3*1000, t_grid3*1000, DP_grid3, 20);
    colorbar;
    hold on;
    contour(GAP_grid3*1000, t_grid3*1000, valid_grid3, [0.5 0.5], 'r-', 'LineWidth', 2);
    plot(baseline.GAP*1000, baseline.t_wall*1000, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'y');
    xlabel('GAP [mm]');
    ylabel('Wall Thickness t [mm]');
    title('Pressure Drop [kPa] (All Designs)');

    subplot(1,2,2);
    contourf(GAP_grid3*1000, t_grid3*1000, DP_valid3, 20);
    colorbar;
    hold on;
    [min_DP3, min_idx3] = min(DP_valid3(:));
    if ~isnan(min_DP3)
        plot(GAP_grid3(min_idx3)*1000, t_grid3(min_idx3)*1000, 'g*', 'MarkerSize', 15, 'LineWidth', 2);
    end
    plot(baseline.GAP*1000, baseline.t_wall*1000, 'ko', 'MarkerSize', 10, 'MarkerFaceColor', 'y');
    xlabel('GAP [mm]');
    ylabel('Wall Thickness t [mm]');
    title('Pressure Drop [kPa] (Valid Designs Only)');

    sgtitle(sprintf('Study 3: GAP vs Wall Thickness (w = %.0f mm)', baseline.w*1000), 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig3, fullfile(results_folder, 'Study3_GAP_vs_WallThickness.png'));
    fprintf('Saved: Study3_GAP_vs_WallThickness.png\n');

    %% Study 4: 3-Parameter Optimization
    fprintf('\n--- Study 4: 3-Parameter Grid Search Optimization ---\n');

    GAP_opt = linspace(0.012, 0.022, 12);
    w_opt = linspace(0.035, 0.055, 12);
    t_opt = linspace(0.005, 0.015, 12);

    best_DP = inf;
    best_params = baseline;
    all_results = [];

    total_iter = length(GAP_opt) * length(w_opt) * length(t_opt);
    iter = 0;

    for g = GAP_opt
        for ww = w_opt
            for tt = t_opt
                iter = iter + 1;
                params = baseline;
                params.GAP = g;
                params.w = ww;
                params.t_wall = tt;
                try
                    r = screw_separator_cooling_jacket(params);
                    if r.design_ok && r.DP_kPa < best_DP
                        best_DP = r.DP_kPa;
                        best_params = params;
                        best_results = r;
                    end
                    if r.design_ok
                        all_results = [all_results; g*1000, ww*1000, tt*1000, r.DP_kPa, r.Re, r.h_j];
                    end
                catch
                end
            end
        end
    end

    fprintf('Best configuration found:\n');
    fprintf('  GAP = %.1f mm\n', best_params.GAP*1000);
    fprintf('  w = %.1f mm\n', best_params.w*1000);
    fprintf('  t_wall = %.1f mm\n', best_params.t_wall*1000);
    fprintf('  Pressure Drop = %.2f kPa (%.1f%% reduction)\n', best_DP, (1 - best_DP/base_results.DP_kPa)*100);

    %% Visualization of optimization results
    fig4 = figure('Position', [100 100 1400 600], 'Color', 'w');

    if ~isempty(all_results)
        subplot(1,3,1);
        scatter3(all_results(:,1), all_results(:,2), all_results(:,4), 40, all_results(:,4), 'filled');
        colorbar;
        xlabel('GAP [mm]');
        ylabel('w [mm]');
        zlabel('DP [kPa]');
        title('Pressure Drop vs GAP & w');
        view(45, 30);

        subplot(1,3,2);
        scatter3(all_results(:,1), all_results(:,3), all_results(:,4), 40, all_results(:,4), 'filled');
        colorbar;
        xlabel('GAP [mm]');
        ylabel('t_{wall} [mm]');
        zlabel('DP [kPa]');
        title('Pressure Drop vs GAP & t_{wall}');
        view(45, 30);

        subplot(1,3,3);
        scatter3(all_results(:,2), all_results(:,3), all_results(:,4), 40, all_results(:,4), 'filled');
        colorbar;
        xlabel('w [mm]');
        ylabel('t_{wall} [mm]');
        zlabel('DP [kPa]');
        title('Pressure Drop vs w & t_{wall}');
        view(45, 30);
    end

    sgtitle('Study 4: 3-Parameter Optimization Results', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig4, fullfile(results_folder, 'Study4_3ParameterOptimization.png'));
    fprintf('Saved: Study4_3ParameterOptimization.png\n');

    %% Create Comparison Bar Chart
    fig5 = figure('Position', [100 100 800 600], 'Color', 'w');

    configs = {'Baseline', 'Optimized'};
    DP_values = [base_results.DP_kPa, best_DP];

    bar_h = bar(DP_values, 'FaceColor', 'flat');
    bar_h.CData(1,:) = [0.7 0.7 0.7];  % Gray for baseline
    bar_h.CData(2,:) = [0.2 0.6 0.2];  % Green for optimized

    set(gca, 'XTickLabel', configs);
    ylabel('Pressure Drop [kPa]');
    title('Pressure Drop Comparison: Baseline vs Optimized');

    % Add value labels
    text(1, DP_values(1)+1, sprintf('%.2f kPa', DP_values(1)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    text(2, DP_values(2)+1, sprintf('%.2f kPa\n(%.1f%% reduction)', DP_values(2), (1-DP_values(2)/DP_values(1))*100), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0 0.5 0]);

    ylim([0 max(DP_values)*1.3]);
    grid on;

    saveas(fig5, fullfile(results_folder, 'Study5_Comparison.png'));
    fprintf('Saved: Study5_Comparison.png\n');

    %% Write Summary Report
    summary_file = fullfile(results_folder, 'SUMMARY_REPORT.txt');
    fid = fopen(summary_file, 'w');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  PARAMETRIC STUDY SUMMARY REPORT\n');
    fprintf(fid, '  Screw Separator Cooling Jacket - Pressure Drop Optimization\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));

    fprintf(fid, 'OBJECTIVE: Minimize pressure drop while maintaining valid design\n');
    fprintf(fid, '           (Available area >= Required area for heat transfer)\n\n');

    fprintf(fid, '------------------------------------------------------------\n');
    fprintf(fid, 'FIXED PARAMETERS (Unit Design - Not Varied):\n');
    fprintf(fid, '------------------------------------------------------------\n');
    fprintf(fid, '  L_jacket     = 1.200 m    (Screw conveyor length)\n');
    fprintf(fid, '  D_separator  = 0.1016 m   (Separator diameter)\n');
    fprintf(fid, '  Q_req        = 1100 W     (Required heat extraction)\n');
    fprintf(fid, '  m_dot        = 0.25 kg/s  (Mass flow rate)\n');
    fprintf(fid, '  T_cold_in    = 281.0 C    (Coolant inlet temp)\n');
    fprintf(fid, '  T_hot_in     = 500.0 C    (Wall inlet temp)\n');
    fprintf(fid, '  T_hot_out    = 285.0 C    (Target wall outlet temp)\n\n');

    fprintf(fid, '------------------------------------------------------------\n');
    fprintf(fid, 'VARIABLE PARAMETERS (Rib & Shell Geometry):\n');
    fprintf(fid, '------------------------------------------------------------\n');
    fprintf(fid, '  GAP    - Annular gap (shell geometry)\n');
    fprintf(fid, '  w      - Channel width (rib geometry)\n');
    fprintf(fid, '  t_wall - Wall thickness between channels (rib geometry)\n\n');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  RESULTS COMPARISON\n');
    fprintf(fid, '============================================================\n\n');

    fprintf(fid, 'BASELINE DESIGN:\n');
    fprintf(fid, '  GAP     = %.1f mm\n', baseline.GAP*1000);
    fprintf(fid, '  w       = %.1f mm\n', baseline.w*1000);
    fprintf(fid, '  t_wall  = %.1f mm\n', baseline.t_wall*1000);
    fprintf(fid, '  -----------------------\n');
    fprintf(fid, '  Pressure Drop = %.2f kPa\n', base_results.DP_kPa);
    fprintf(fid, '  Reynolds No.  = %.0f\n', base_results.Re);
    fprintf(fid, '  Heat Coeff.   = %.1f W/(m2K)\n', base_results.h_j);
    fprintf(fid, '  Design Valid  = %s\n\n', string(base_results.design_ok));

    fprintf(fid, 'OPTIMIZED DESIGN:\n');
    fprintf(fid, '  GAP     = %.1f mm\n', best_params.GAP*1000);
    fprintf(fid, '  w       = %.1f mm\n', best_params.w*1000);
    fprintf(fid, '  t_wall  = %.1f mm\n', best_params.t_wall*1000);
    fprintf(fid, '  -----------------------\n');
    fprintf(fid, '  Pressure Drop = %.2f kPa\n', best_DP);
    fprintf(fid, '  Reynolds No.  = %.0f\n', best_results.Re);
    fprintf(fid, '  Heat Coeff.   = %.1f W/(m2K)\n', best_results.h_j);
    fprintf(fid, '  Design Valid  = %s\n\n', string(best_results.design_ok));

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  IMPROVEMENT SUMMARY\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, '  Pressure Drop Reduction: %.2f kPa -> %.2f kPa\n', base_results.DP_kPa, best_DP);
    fprintf(fid, '  Percentage Improvement:  %.1f%%\n', (1 - best_DP/base_results.DP_kPa)*100);
    fprintf(fid, '\n');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  KEY FINDINGS\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, '  1. Increasing GAP reduces velocity, lowering pressure drop\n');
    fprintf(fid, '  2. Increasing w (channel width) reduces friction losses\n');
    fprintf(fid, '  3. Decreasing t_wall increases N_turns but shortens L_coil\n');
    fprintf(fid, '  4. Trade-off exists: larger channels reduce h_j (heat transfer)\n');
    fprintf(fid, '  5. Optimal design balances low DP with adequate heat transfer\n\n');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  FILES GENERATED\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, '  Study1_SingleParameterSweeps.png   - Individual parameter effects\n');
    fprintf(fid, '  Study2_GAP_vs_ChannelWidth.png     - 2D contour: GAP vs w\n');
    fprintf(fid, '  Study3_GAP_vs_WallThickness.png    - 2D contour: GAP vs t_wall\n');
    fprintf(fid, '  Study4_3ParameterOptimization.png  - 3D scatter optimization\n');
    fprintf(fid, '  Study5_Comparison.png              - Bar chart comparison\n');
    fprintf(fid, '  SUMMARY_REPORT.txt                 - This file\n\n');

    fclose(fid);
    fprintf('Saved: SUMMARY_REPORT.txt\n');

    fprintf('\n=== Parametric Study Complete ===\n');
    fprintf('Results saved to: %s\n', results_folder);
    fprintf('Baseline DP: %.2f kPa -> Optimized DP: %.2f kPa (%.1f%% reduction)\n', ...
        base_results.DP_kPa, best_DP, (1-best_DP/base_results.DP_kPa)*100);

    % Return best parameters for further optimization
    assignin('base', 'optimized_params', best_params);
    assignin('base', 'optimized_results', best_results);
end

%% Helper function for single parameter sweep
function [DP, valid, Re, h] = sweep_parameter(param_name, param_range, baseline)
    n = length(param_range);
    DP = zeros(1, n);
    valid = zeros(1, n);
    Re = zeros(1, n);
    h = zeros(1, n);

    for i = 1:n
        params = baseline;
        params.(param_name) = param_range(i);
        try
            r = screw_separator_cooling_jacket(params);
            DP(i) = r.DP_kPa;
            valid(i) = r.design_ok;
            Re(i) = r.Re;
            h(i) = r.h_j;
        catch
            DP(i) = NaN;
            valid(i) = 0;
            Re(i) = NaN;
            h(i) = NaN;
        end
    end
end

%% Helper function for plotting single sweeps
function plot_single_sweep(x, DP, valid, xlabel_str, baseline_x)
    hold on;

    % Plot invalid region in red
    invalid_idx = ~valid;
    if any(invalid_idx)
        area(x, max(DP)*ones(size(x)), 'FaceColor', [1 0.9 0.9], 'EdgeColor', 'none');
        plot(x(invalid_idx), DP(invalid_idx), 'rx', 'MarkerSize', 8);
    end

    % Plot valid region
    valid_idx = logical(valid);
    plot(x, DP, 'b-', 'LineWidth', 1.5);
    plot(x(valid_idx), DP(valid_idx), 'go', 'MarkerSize', 4, 'MarkerFaceColor', 'g');

    % Mark baseline
    xline(baseline_x, 'k--', 'LineWidth', 1.5);

    % Find minimum in valid region
    DP_valid = DP;
    DP_valid(~valid_idx) = inf;
    [min_DP, min_idx] = min(DP_valid);
    if ~isinf(min_DP)
        plot(x(min_idx), min_DP, 'm*', 'MarkerSize', 15, 'LineWidth', 2);
    end

    xlabel(xlabel_str);
    ylabel('Pressure Drop [kPa]');
    grid on;
    legend('Invalid Region', 'Invalid Points', 'All', 'Valid Points', 'Baseline', 'Minimum', 'Location', 'best');
    hold off;
end
