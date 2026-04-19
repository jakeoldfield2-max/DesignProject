function parametric_study_refined()
% PARAMETRIC_STUDY_REFINED  Refined optimization study based on initial results
%
%   Study 1 found optimal parameters at GAP=22mm, w=55mm, t_wall=15mm
%   This refined study:
%   1. Explores the optimal region more finely
%   2. Investigates Pareto front (DP vs heat transfer coefficient trade-off)
%   3. Finds configurations with good h_j while still reducing DP significantly

    %% Create results folder with timestamp
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    results_folder = fullfile(pwd, 'results', ['Refined_Study_' timestamp]);
    if ~exist(results_folder, 'dir')
        mkdir(results_folder);
    end

    fprintf('=== REFINED Parametric Study ===\n');
    fprintf('Building on initial findings to further optimize\n');
    fprintf('Results will be saved to: %s\n\n', results_folder);

    %% Baseline and first optimum parameters
    baseline.GAP = 0.01;      % [m]
    baseline.w = 0.03;        % [m]
    baseline.t_wall = 0.02;   % [m]

    first_opt.GAP = 0.022;
    first_opt.w = 0.055;
    first_opt.t_wall = 0.015;

    base_results = screw_separator_cooling_jacket(baseline);
    first_results = screw_separator_cooling_jacket(first_opt);

    %% Study A: Fine-Grained Search Around Optimal Region
    fprintf('\n--- Study A: Fine-Grained Search Near Optimal ---\n');

    GAP_fine = linspace(0.018, 0.025, 15);
    w_fine = linspace(0.045, 0.065, 15);
    t_fine = linspace(0.008, 0.018, 15);

    best_DP = inf;
    all_configs = [];

    for g = GAP_fine
        for ww = w_fine
            for tt = t_fine
                params = struct();
                params.GAP = g;
                params.w = ww;
                params.t_wall = tt;
                try
                    r = screw_separator_cooling_jacket(params);
                    if r.design_ok
                        all_configs = [all_configs; g*1000, ww*1000, tt*1000, r.DP_kPa, r.h_j, r.Re, r.A_av/r.A_req];
                        if r.DP_kPa < best_DP
                            best_DP = r.DP_kPa;
                            best_params = params;
                            best_results = r;
                        end
                    end
                catch
                end
            end
        end
    end

    fprintf('Best DP in fine search: %.3f kPa\n', best_DP);
    fprintf('Parameters: GAP=%.1f mm, w=%.1f mm, t=%.1f mm\n', ...
        best_params.GAP*1000, best_params.w*1000, best_params.t_wall*1000);

    %% Study B: Pareto Front Analysis (DP vs h_j trade-off)
    fprintf('\n--- Study B: Pareto Front Analysis ---\n');

    % Already collected all configurations, now find Pareto front
    % Columns: [GAP, w, t_wall, DP_kPa, h_j, Re, A_ratio]

    % Find Pareto-optimal points (minimize DP, maximize h_j)
    pareto_idx = [];
    for i = 1:size(all_configs, 1)
        is_dominated = false;
        for j = 1:size(all_configs, 1)
            if i ~= j
                % j dominates i if j has lower DP AND higher h_j
                if all_configs(j,4) <= all_configs(i,4) && all_configs(j,5) >= all_configs(i,5) && ...
                   (all_configs(j,4) < all_configs(i,4) || all_configs(j,5) > all_configs(i,5))
                    is_dominated = true;
                    break;
                end
            end
        end
        if ~is_dominated
            pareto_idx = [pareto_idx; i];
        end
    end

    pareto_points = all_configs(pareto_idx, :);
    [~, sort_idx] = sort(pareto_points(:,4));  % Sort by DP
    pareto_points = pareto_points(sort_idx, :);

    fprintf('Found %d Pareto-optimal configurations\n', size(pareto_points, 1));

    %% Study C: Target h_j Configurations
    fprintf('\n--- Study C: Configurations Meeting Heat Transfer Targets ---\n');

    % Find best DP for different h_j thresholds
    h_thresholds = [500, 600, 700, 800, 900, 1000];
    target_configs = [];

    for h_min = h_thresholds
        valid_idx = all_configs(:,5) >= h_min;
        if any(valid_idx)
            valid_subset = all_configs(valid_idx, :);
            [min_dp, idx] = min(valid_subset(:,4));
            target_configs = [target_configs; h_min, valid_subset(idx, :)];
        end
    end

    %% Visualization
    fig1 = figure('Position', [100 100 1400 600], 'Color', 'w');

    % Pareto Front Plot
    subplot(1,2,1);
    scatter(all_configs(:,4), all_configs(:,5), 20, [0.7 0.7 0.7], 'filled');
    hold on;
    plot(pareto_points(:,4), pareto_points(:,5), 'ro-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    plot(base_results.DP_kPa, base_results.h_j, 'b^', 'MarkerSize', 15, 'MarkerFaceColor', 'b', 'LineWidth', 2);
    plot(first_results.DP_kPa, first_results.h_j, 'gs', 'MarkerSize', 15, 'MarkerFaceColor', 'g', 'LineWidth', 2);

    xlabel('Pressure Drop [kPa]');
    ylabel('Heat Transfer Coefficient h_j [W/(m^2K)]');
    title('Pareto Front: Pressure Drop vs Heat Transfer');
    legend('All Designs', 'Pareto Front', 'Baseline', 'First Optimum', 'Location', 'northeast');
    grid on;

    % Zoomed Pareto with annotations
    subplot(1,2,2);
    plot(pareto_points(:,4), pareto_points(:,5), 'ro-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    hold on;

    % Add labels for key points
    for i = 1:min(5, size(pareto_points, 1))
        text(pareto_points(i,4)+0.05, pareto_points(i,5)+10, ...
            sprintf('G=%.0f,w=%.0f,t=%.0f', pareto_points(i,1), pareto_points(i,2), pareto_points(i,3)), ...
            'FontSize', 8);
    end

    xlabel('Pressure Drop [kPa]');
    ylabel('Heat Transfer Coefficient h_j [W/(m^2K)]');
    title('Pareto Front (Zoomed) with Parameter Labels');
    grid on;

    sgtitle('Refined Study A & B: Pareto Optimization', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig1, fullfile(results_folder, 'StudyAB_ParetoFront.png'));
    fprintf('Saved: StudyAB_ParetoFront.png\n');

    %% Target h_j Bar Chart
    fig2 = figure('Position', [100 100 1000 600], 'Color', 'w');

    if ~isempty(target_configs)
        subplot(1,2,1);
        bar(target_configs(:,1), target_configs(:,5));  % DP for each h_j threshold
        xlabel('Minimum h_j Threshold [W/(m^2K)]');
        ylabel('Achievable Pressure Drop [kPa]');
        title('Minimum DP for Heat Transfer Requirements');
        grid on;

        % Add baseline reference line
        hold on;
        yline(base_results.DP_kPa, 'r--', 'Baseline DP', 'LineWidth', 1.5);

        subplot(1,2,2);
        % Create grouped bar chart
        categories = categorical(arrayfun(@(x) sprintf('h_j >= %d', x), target_configs(:,1)', 'UniformOutput', false));
        data_matrix = [target_configs(:,2), target_configs(:,3), target_configs(:,4)];  % GAP, w, t
        bar(categories, data_matrix);
        ylabel('Parameter Value [mm]');
        legend('GAP', 'w', 't_{wall}', 'Location', 'best');
        title('Optimal Parameters for h_j Targets');
        grid on;
    end

    sgtitle('Refined Study C: Heat Transfer Constrained Optimization', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig2, fullfile(results_folder, 'StudyC_HeatTransferTargets.png'));
    fprintf('Saved: StudyC_HeatTransferTargets.png\n');

    %% 3D Surface Plots
    fig3 = figure('Position', [100 100 1400 500], 'Color', 'w');

    % Create meshgrid for visualization
    [GAP_mesh, w_mesh] = meshgrid(linspace(0.018, 0.025, 20), linspace(0.045, 0.065, 20));
    DP_mesh = nan(size(GAP_mesh));
    h_mesh = nan(size(GAP_mesh));

    for i = 1:numel(GAP_mesh)
        params.GAP = GAP_mesh(i);
        params.w = w_mesh(i);
        params.t_wall = 0.012;  % Use optimal t_wall
        try
            r = screw_separator_cooling_jacket(params);
            if r.design_ok
                DP_mesh(i) = r.DP_kPa;
                h_mesh(i) = r.h_j;
            end
        catch
        end
    end

    subplot(1,2,1);
    surf(GAP_mesh*1000, w_mesh*1000, DP_mesh, 'FaceAlpha', 0.8);
    colorbar;
    xlabel('GAP [mm]');
    ylabel('w [mm]');
    zlabel('Pressure Drop [kPa]');
    title(sprintf('Pressure Drop Surface (t_{wall} = 12 mm)'));
    view(45, 30);

    subplot(1,2,2);
    surf(GAP_mesh*1000, w_mesh*1000, h_mesh, 'FaceAlpha', 0.8);
    colorbar;
    xlabel('GAP [mm]');
    ylabel('w [mm]');
    zlabel('h_j [W/(m^2K)]');
    title(sprintf('Heat Transfer Coeff Surface (t_{wall} = 12 mm)'));
    view(45, 30);

    sgtitle('Refined Study: Response Surfaces', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig3, fullfile(results_folder, 'StudyD_ResponseSurfaces.png'));
    fprintf('Saved: StudyD_ResponseSurfaces.png\n');

    %% Final Comparison Chart
    fig4 = figure('Position', [100 100 1200 500], 'Color', 'w');

    % Select representative configurations
    configs_to_compare = {
        'Baseline', baseline, base_results;
        'First Optimum (Min DP)', first_opt, first_results;
        sprintf('Best Refined (DP=%.2f kPa)', best_DP), best_params, best_results;
    };

    % Add balanced configurations from pareto front
    if size(pareto_points, 1) >= 3
        mid_idx = round(size(pareto_points, 1)/2);
        mid_params.GAP = pareto_points(mid_idx,1)/1000;
        mid_params.w = pareto_points(mid_idx,2)/1000;
        mid_params.t_wall = pareto_points(mid_idx,3)/1000;
        mid_results = screw_separator_cooling_jacket(mid_params);
        configs_to_compare{end+1, 1} = sprintf('Balanced (h_j=%.0f)', mid_results.h_j);
        configs_to_compare{end, 2} = mid_params;
        configs_to_compare{end, 3} = mid_results;
    end

    n_configs = size(configs_to_compare, 1);

    subplot(1,3,1);
    DP_vals = cellfun(@(x) x.DP_kPa, configs_to_compare(:,3));
    bar_h = bar(DP_vals, 'FaceColor', 'flat');
    for i = 1:n_configs
        if i == 1
            bar_h.CData(i,:) = [0.7 0.7 0.7];  % Gray for baseline
        else
            bar_h.CData(i,:) = [0.2 0.6 0.2];  % Green for optimized
        end
    end
    set(gca, 'XTickLabel', configs_to_compare(:,1), 'XTickLabelRotation', 30);
    ylabel('Pressure Drop [kPa]');
    title('Pressure Drop Comparison');
    grid on;

    subplot(1,3,2);
    h_vals = cellfun(@(x) x.h_j, configs_to_compare(:,3));
    bar_h = bar(h_vals, 'FaceColor', 'flat');
    for i = 1:n_configs
        if i == 1
            bar_h.CData(i,:) = [0.7 0.7 0.7];
        else
            bar_h.CData(i,:) = [0.2 0.2 0.8];  % Blue
        end
    end
    set(gca, 'XTickLabel', configs_to_compare(:,1), 'XTickLabelRotation', 30);
    ylabel('Heat Transfer Coeff. [W/(m^2K)]');
    title('Heat Transfer Comparison');
    grid on;

    subplot(1,3,3);
    Re_vals = cellfun(@(x) x.Re, configs_to_compare(:,3));
    bar_h = bar(Re_vals, 'FaceColor', 'flat');
    for i = 1:n_configs
        if i == 1
            bar_h.CData(i,:) = [0.7 0.7 0.7];
        else
            bar_h.CData(i,:) = [0.8 0.4 0.2];  % Orange
        end
    end
    set(gca, 'XTickLabel', configs_to_compare(:,1), 'XTickLabelRotation', 30);
    ylabel('Reynolds Number');
    title('Reynolds Number Comparison');
    grid on;

    sgtitle('Final Configuration Comparison', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig4, fullfile(results_folder, 'Final_Comparison.png'));
    fprintf('Saved: Final_Comparison.png\n');

    %% Write Summary Report
    summary_file = fullfile(results_folder, 'REFINED_SUMMARY_REPORT.txt');
    fid = fopen(summary_file, 'w');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  REFINED PARAMETRIC STUDY SUMMARY REPORT\n');
    fprintf(fid, '  Screw Separator Cooling Jacket - Advanced Optimization\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));

    fprintf(fid, 'This refined study builds on the initial parametric study to:\n');
    fprintf(fid, '  1. Fine-tune parameters near the optimal region\n');
    fprintf(fid, '  2. Analyze Pareto-optimal trade-offs (DP vs h_j)\n');
    fprintf(fid, '  3. Find configurations meeting heat transfer requirements\n\n');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  CONFIGURATION COMPARISON\n');
    fprintf(fid, '============================================================\n\n');

    fprintf(fid, '%-25s | %8s | %8s | %8s | %10s | %10s | %8s\n', ...
        'Configuration', 'GAP[mm]', 'w[mm]', 't[mm]', 'DP[kPa]', 'h_j[W/m2K]', 'Re');
    fprintf(fid, '%s\n', repmat('-', 1, 95));

    for i = 1:n_configs
        cfg = configs_to_compare{i,2};
        res = configs_to_compare{i,3};
        fprintf(fid, '%-25s | %8.1f | %8.1f | %8.1f | %10.3f | %10.1f | %8.0f\n', ...
            configs_to_compare{i,1}, cfg.GAP*1000, cfg.w*1000, cfg.t_wall*1000, ...
            res.DP_kPa, res.h_j, res.Re);
    end

    fprintf(fid, '\n============================================================\n');
    fprintf(fid, '  PARETO-OPTIMAL CONFIGURATIONS (Top 10)\n');
    fprintf(fid, '============================================================\n\n');

    fprintf(fid, '%8s | %8s | %8s | %10s | %10s\n', 'GAP[mm]', 'w[mm]', 't[mm]', 'DP[kPa]', 'h_j[W/m2K]');
    fprintf(fid, '%s\n', repmat('-', 1, 55));

    for i = 1:min(10, size(pareto_points, 1))
        fprintf(fid, '%8.1f | %8.1f | %8.1f | %10.3f | %10.1f\n', ...
            pareto_points(i,1), pareto_points(i,2), pareto_points(i,3), ...
            pareto_points(i,4), pareto_points(i,5));
    end

    fprintf(fid, '\n============================================================\n');
    fprintf(fid, '  BEST CONFIGURATIONS FOR h_j REQUIREMENTS\n');
    fprintf(fid, '============================================================\n\n');

    if ~isempty(target_configs)
        fprintf(fid, '%12s | %8s | %8s | %8s | %10s\n', 'Min h_j', 'GAP[mm]', 'w[mm]', 't[mm]', 'DP[kPa]');
        fprintf(fid, '%s\n', repmat('-', 1, 60));
        for i = 1:size(target_configs, 1)
            fprintf(fid, '%12.0f | %8.1f | %8.1f | %8.1f | %10.3f\n', ...
                target_configs(i,1), target_configs(i,2), target_configs(i,3), ...
                target_configs(i,4), target_configs(i,5));
        end
    end

    fprintf(fid, '\n============================================================\n');
    fprintf(fid, '  RECOMMENDATIONS\n');
    fprintf(fid, '============================================================\n\n');

    fprintf(fid, 'Based on the refined analysis:\n\n');

    fprintf(fid, '1. MINIMUM PRESSURE DROP CONFIGURATION:\n');
    fprintf(fid, '   GAP = %.1f mm, w = %.1f mm, t_wall = %.1f mm\n', ...
        best_params.GAP*1000, best_params.w*1000, best_params.t_wall*1000);
    fprintf(fid, '   DP = %.3f kPa (%.1f%% reduction from baseline)\n', ...
        best_results.DP_kPa, (1-best_results.DP_kPa/base_results.DP_kPa)*100);
    fprintf(fid, '   h_j = %.1f W/(m2K)\n\n', best_results.h_j);

    if size(pareto_points, 1) >= 3
        fprintf(fid, '2. BALANCED CONFIGURATION (Good DP and h_j):\n');
        fprintf(fid, '   GAP = %.1f mm, w = %.1f mm, t_wall = %.1f mm\n', ...
            mid_params.GAP*1000, mid_params.w*1000, mid_params.t_wall*1000);
        fprintf(fid, '   DP = %.3f kPa (%.1f%% reduction from baseline)\n', ...
            mid_results.DP_kPa, (1-mid_results.DP_kPa/base_results.DP_kPa)*100);
        fprintf(fid, '   h_j = %.1f W/(m2K)\n\n', mid_results.h_j);
    end

    fprintf(fid, '3. KEY INSIGHTS:\n');
    fprintf(fid, '   - Increasing GAP from 10mm to 20-25mm dramatically reduces DP\n');
    fprintf(fid, '   - Increasing w from 30mm to 55-65mm provides further DP reduction\n');
    fprintf(fid, '   - Decreasing t_wall to 8-12mm optimizes turn geometry\n');
    fprintf(fid, '   - Trade-off: Lower DP comes at cost of reduced h_j\n');
    fprintf(fid, '   - Design remains valid as A_available >> A_required\n\n');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  FILES GENERATED\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, '  StudyAB_ParetoFront.png        - Pareto optimization plot\n');
    fprintf(fid, '  StudyC_HeatTransferTargets.png - h_j constrained results\n');
    fprintf(fid, '  StudyD_ResponseSurfaces.png    - 3D response surfaces\n');
    fprintf(fid, '  Final_Comparison.png           - Multi-configuration comparison\n');
    fprintf(fid, '  REFINED_SUMMARY_REPORT.txt     - This file\n\n');

    fclose(fid);
    fprintf('Saved: REFINED_SUMMARY_REPORT.txt\n');

    fprintf('\n=== Refined Parametric Study Complete ===\n');
    fprintf('Best pressure drop achieved: %.3f kPa (%.1f%% reduction)\n', ...
        best_DP, (1-best_DP/base_results.DP_kPa)*100);

    % Export for next optimization
    assignin('base', 'refined_best_params', best_params);
    assignin('base', 'pareto_points', pareto_points);
end
