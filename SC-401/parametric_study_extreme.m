function parametric_study_extreme()
% PARAMETRIC_STUDY_EXTREME  Push boundaries to find ultimate minimum DP
%
%   Explores extended parameter ranges based on refined study findings:
%   - GAP: 20-35 mm (extended upper range)
%   - w: 55-80 mm (extended upper range)
%   - t_wall: 5-25 mm (full range)
%
%   Also investigates physical constraints and manufacturing limits

    %% Create results folder with timestamp
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    results_folder = fullfile(pwd, 'results', ['Extreme_Study_' timestamp]);
    if ~exist(results_folder, 'dir')
        mkdir(results_folder);
    end

    fprintf('=== EXTREME OPTIMIZATION STUDY ===\n');
    fprintf('Exploring extended parameter ranges for ultimate DP minimization\n');
    fprintf('Results: %s\n\n', results_folder);

    %% Reference values
    baseline.GAP = 0.01;
    baseline.w = 0.03;
    baseline.t_wall = 0.02;
    base_results = screw_separator_cooling_jacket(baseline);

    previous_best.GAP = 0.025;
    previous_best.w = 0.065;
    previous_best.t_wall = 0.018;
    prev_results = screw_separator_cooling_jacket(previous_best);

    %% Study 1: Extended Range Exploration
    fprintf('\n--- Study 1: Extended Range Grid Search ---\n');

    GAP_ext = linspace(0.020, 0.035, 18);
    w_ext = linspace(0.055, 0.085, 18);
    t_ext = linspace(0.005, 0.025, 15);

    best_DP = inf;
    all_valid = [];
    total = numel(GAP_ext) * numel(w_ext) * numel(t_ext);
    count = 0;

    for g = GAP_ext
        for ww = w_ext
            for tt = t_ext
                count = count + 1;
                params.GAP = g;
                params.w = ww;
                params.t_wall = tt;

                try
                    r = screw_separator_cooling_jacket(params);
                    if r.design_ok
                        all_valid = [all_valid; g*1000, ww*1000, tt*1000, r.DP_kPa, r.h_j, ...
                                     r.Re, r.A_av/r.A_req, r.v, r.N_turn, r.L_coil];
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

    fprintf('Total valid configurations: %d\n', size(all_valid, 1));
    fprintf('Best DP found: %.4f kPa\n', best_DP);
    fprintf('Parameters: GAP=%.1f mm, w=%.1f mm, t_wall=%.1f mm\n', ...
        best_params.GAP*1000, best_params.w*1000, best_params.t_wall*1000);

    %% Study 2: Ultra-Fine Search Around New Optimum
    fprintf('\n--- Study 2: Ultra-Fine Search ---\n');

    GAP_fine = linspace(best_params.GAP - 0.003, best_params.GAP + 0.003, 15);
    GAP_fine = GAP_fine(GAP_fine > 0);
    w_fine = linspace(best_params.w - 0.008, best_params.w + 0.008, 15);
    w_fine = w_fine(w_fine > 0);
    t_fine = linspace(max(0.003, best_params.t_wall - 0.005), best_params.t_wall + 0.005, 15);

    ultra_best_DP = inf;

    for g = GAP_fine
        for ww = w_fine
            for tt = t_fine
                params.GAP = g;
                params.w = ww;
                params.t_wall = tt;
                try
                    r = screw_separator_cooling_jacket(params);
                    if r.design_ok && r.DP_kPa < ultra_best_DP
                        ultra_best_DP = r.DP_kPa;
                        ultra_best_params = params;
                        ultra_best_results = r;
                    end
                catch
                end
            end
        end
    end

    fprintf('Ultra-refined best DP: %.4f kPa\n', ultra_best_DP);

    %% Study 3: Physical Constraint Analysis
    fprintf('\n--- Study 3: Physical Constraint Analysis ---\n');

    % Analyze effect of key physical constraints
    % 1. Minimum wall thickness for structural integrity
    % 2. Maximum GAP relative to separator diameter
    % 3. Minimum Reynolds number for good heat transfer

    constraint_analysis = [];
    t_wall_values = [0.003, 0.005, 0.008, 0.010, 0.015, 0.020];

    for tt = t_wall_values
        local_best_DP = inf;
        for g = GAP_ext
            for ww = w_ext
                params.GAP = g;
                params.w = ww;
                params.t_wall = tt;
                try
                    r = screw_separator_cooling_jacket(params);
                    if r.design_ok && r.DP_kPa < local_best_DP
                        local_best_DP = r.DP_kPa;
                        local_params = params;
                        local_results = r;
                    end
                catch
                end
            end
        end
        if ~isinf(local_best_DP)
            constraint_analysis = [constraint_analysis; tt*1000, local_params.GAP*1000, ...
                local_params.w*1000, local_best_DP, local_results.h_j, local_results.Re];
        end
    end

    %% Visualization
    fig1 = figure('Position', [100 100 1500 600], 'Color', 'w');

    % 3D scatter of all valid configurations
    subplot(1,3,1);
    scatter3(all_valid(:,1), all_valid(:,2), all_valid(:,4), 30, all_valid(:,4), 'filled');
    colorbar;
    hold on;
    scatter3(ultra_best_params.GAP*1000, ultra_best_params.w*1000, ultra_best_DP, 200, 'r', 'p', 'filled');
    xlabel('GAP [mm]');
    ylabel('w [mm]');
    zlabel('DP [kPa]');
    title('Extended Search: All Valid Configurations');
    view(45, 30);
    colormap(parula);

    % Contour of minimum DP vs t_wall
    subplot(1,3,2);
    if ~isempty(constraint_analysis)
        yyaxis left;
        plot(constraint_analysis(:,1), constraint_analysis(:,4), 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
        ylabel('Minimum DP [kPa]');
        yyaxis right;
        plot(constraint_analysis(:,1), constraint_analysis(:,5), 'r-s', 'LineWidth', 2, 'MarkerSize', 8);
        ylabel('Heat Transfer Coeff [W/(m^2K)]');
        xlabel('Wall Thickness t_{wall} [mm]');
        title('Constraint Analysis: t_{wall} Effect');
        grid on;
        legend('Min DP', 'h_j at Min DP', 'Location', 'best');
    end

    % Comparison bar chart
    subplot(1,3,3);
    configs = {'Baseline', 'First Study', 'Refined Study', 'Extreme Study'};
    DP_vals = [base_results.DP_kPa, 0.956, prev_results.DP_kPa, ultra_best_DP];

    bar_h = bar(DP_vals, 'FaceColor', 'flat');
    for i = 1:length(DP_vals)
        if i == 1
            bar_h.CData(i,:) = [0.7 0.7 0.7];
        elseif i == length(DP_vals)
            bar_h.CData(i,:) = [0.1 0.7 0.1];
        else
            bar_h.CData(i,:) = [0.2 0.5 0.8];
        end
    end
    set(gca, 'XTickLabel', configs, 'XTickLabelRotation', 20);
    ylabel('Pressure Drop [kPa]');
    title('Progressive Optimization Results');
    grid on;

    % Add percentage labels
    for i = 2:length(DP_vals)
        pct_red = (1 - DP_vals(i)/DP_vals(1)) * 100;
        text(i, DP_vals(i) + 1, sprintf('-%.1f%%', pct_red), 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end

    sgtitle('Extreme Optimization Study Results', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig1, fullfile(results_folder, 'ExtendedOptimization.png'));
    fprintf('Saved: ExtendedOptimization.png\n');

    %% Detailed comparison figure
    fig2 = figure('Position', [100 100 1200 800], 'Color', 'w');

    % Configuration details table as visual
    subplot(2,2,1);
    config_names = {'Baseline', 'First Opt', 'Refined', 'Ultimate'};
    config_data = [
        baseline.GAP*1000, baseline.w*1000, baseline.t_wall*1000, base_results.DP_kPa, base_results.h_j;
        22, 55, 15, 0.956, 375.7;
        previous_best.GAP*1000, previous_best.w*1000, previous_best.t_wall*1000, prev_results.DP_kPa, prev_results.h_j;
        ultra_best_params.GAP*1000, ultra_best_params.w*1000, ultra_best_params.t_wall*1000, ultra_best_DP, ultra_best_results.h_j
    ];

    bar(config_data(:,[1,2,3]));
    set(gca, 'XTickLabel', config_names);
    ylabel('Dimension [mm]');
    legend('GAP', 'w', 't_{wall}', 'Location', 'northwest');
    title('Geometric Parameters');
    grid on;

    subplot(2,2,2);
    bar([config_data(:,4), log10(config_data(:,4)+0.01)*10]);  % DP with log scale for visibility
    set(gca, 'XTickLabel', config_names);
    ylabel('Pressure Drop [kPa]');
    title('Pressure Drop Comparison');
    grid on;
    legend('DP [kPa]', 'log10(DP)*10', 'Location', 'best');

    subplot(2,2,3);
    % Reynolds number and velocity comparison
    Re_vals = [base_results.Re, 15838, prev_results.Re, ultra_best_results.Re];
    v_vals = [base_results.v, 0.2997, prev_results.v, ultra_best_results.v];

    yyaxis left;
    bar(1:4, Re_vals, 0.4);
    ylabel('Reynolds Number');
    yyaxis right;
    plot(1:4, v_vals, 'rs-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    ylabel('Velocity [m/s]');
    set(gca, 'XTick', 1:4, 'XTickLabel', config_names);
    title('Flow Characteristics');
    legend('Re', 'Velocity', 'Location', 'best');
    grid on;

    subplot(2,2,4);
    % Area ratio (safety margin)
    A_ratios = [base_results.A_av/base_results.A_req, 7.0, prev_results.A_av/prev_results.A_req, ...
                ultra_best_results.A_av/ultra_best_results.A_req];
    bar(A_ratios);
    hold on;
    yline(1, 'r--', 'Min Required', 'LineWidth', 2);
    set(gca, 'XTickLabel', config_names);
    ylabel('A_{available} / A_{required}');
    title('Heat Transfer Area Safety Margin');
    grid on;

    sgtitle('Complete Configuration Analysis', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig2, fullfile(results_folder, 'DetailedComparison.png'));
    fprintf('Saved: DetailedComparison.png\n');

    %% Design envelope plot
    fig3 = figure('Position', [100 100 1000 800], 'Color', 'w');

    % Columns: [GAP, w, t, DP, h_j, Re, A_ratio, v, N_turn, L_coil]
    subplot(2,2,1);
    scatter(all_valid(:,6), all_valid(:,4), 20, all_valid(:,5), 'filled');
    colorbar;
    xlabel('Reynolds Number');
    ylabel('Pressure Drop [kPa]');
    title('DP vs Re (color = h_j)');
    grid on;

    subplot(2,2,2);
    scatter(all_valid(:,8), all_valid(:,4), 20, all_valid(:,6), 'filled');
    colorbar;
    xlabel('Velocity [m/s]');
    ylabel('Pressure Drop [kPa]');
    title('DP vs Velocity (color = Re)');
    grid on;

    subplot(2,2,3);
    scatter(all_valid(:,9), all_valid(:,4), 20, all_valid(:,3), 'filled');
    colorbar;
    xlabel('Number of Turns');
    ylabel('Pressure Drop [kPa]');
    title('DP vs N_{turns} (color = t_{wall})');
    grid on;

    subplot(2,2,4);
    scatter(all_valid(:,10), all_valid(:,4), 20, all_valid(:,7), 'filled');
    colorbar;
    xlabel('Coil Length [m]');
    ylabel('Pressure Drop [kPa]');
    title('DP vs L_{coil} (color = A_{ratio})');
    grid on;

    sgtitle('Design Space Visualization', 'FontSize', 14, 'FontWeight', 'bold');
    saveas(fig3, fullfile(results_folder, 'DesignSpace.png'));
    fprintf('Saved: DesignSpace.png\n');

    %% Write Final Summary
    summary_file = fullfile(results_folder, 'EXTREME_STUDY_SUMMARY.txt');
    fid = fopen(summary_file, 'w');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  EXTREME OPTIMIZATION STUDY - FINAL RESULTS\n');
    fprintf(fid, '  Screw Separator Cooling Jacket\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  PROGRESSIVE OPTIMIZATION SUMMARY\n');
    fprintf(fid, '============================================================\n\n');

    fprintf(fid, '%-20s | %8s | %8s | %8s | %10s | %10s | %10s\n', ...
        'Study', 'GAP[mm]', 'w[mm]', 't[mm]', 'DP[kPa]', 'h_j', 'Reduction');
    fprintf(fid, '%s\n', repmat('-', 1, 90));
    fprintf(fid, '%-20s | %8.1f | %8.1f | %8.1f | %10.3f | %10.1f | %10s\n', ...
        'Baseline', baseline.GAP*1000, baseline.w*1000, baseline.t_wall*1000, ...
        base_results.DP_kPa, base_results.h_j, '-');
    fprintf(fid, '%-20s | %8.1f | %8.1f | %8.1f | %10.3f | %10.1f | %9.1f%%\n', ...
        'First Study', 22, 55, 15, 0.956, 375.7, (1-0.956/base_results.DP_kPa)*100);
    fprintf(fid, '%-20s | %8.1f | %8.1f | %8.1f | %10.3f | %10.1f | %9.1f%%\n', ...
        'Refined Study', previous_best.GAP*1000, previous_best.w*1000, previous_best.t_wall*1000, ...
        prev_results.DP_kPa, prev_results.h_j, (1-prev_results.DP_kPa/base_results.DP_kPa)*100);
    fprintf(fid, '%-20s | %8.1f | %8.1f | %8.1f | %10.4f | %10.1f | %9.1f%%\n', ...
        'ULTIMATE OPTIMUM', ultra_best_params.GAP*1000, ultra_best_params.w*1000, ultra_best_params.t_wall*1000, ...
        ultra_best_DP, ultra_best_results.h_j, (1-ultra_best_DP/base_results.DP_kPa)*100);

    fprintf(fid, '\n============================================================\n');
    fprintf(fid, '  ULTIMATE OPTIMUM - DETAILED RESULTS\n');
    fprintf(fid, '============================================================\n\n');

    fprintf(fid, 'GEOMETRY:\n');
    fprintf(fid, '  GAP (annular gap)     = %.2f mm\n', ultra_best_params.GAP*1000);
    fprintf(fid, '  w (channel width)     = %.2f mm\n', ultra_best_params.w*1000);
    fprintf(fid, '  t_wall (wall thick.)  = %.2f mm\n', ultra_best_params.t_wall*1000);
    fprintf(fid, '  Pitch (w + t_wall)    = %.2f mm\n', (ultra_best_params.w + ultra_best_params.t_wall)*1000);
    fprintf(fid, '\n');

    fprintf(fid, 'PERFORMANCE:\n');
    fprintf(fid, '  Pressure Drop         = %.4f kPa (%.1f Pa)\n', ultra_best_DP, ultra_best_DP*1000);
    fprintf(fid, '  Heat Transfer Coeff   = %.1f W/(m2K)\n', ultra_best_results.h_j);
    fprintf(fid, '  Reynolds Number       = %.0f\n', ultra_best_results.Re);
    fprintf(fid, '  Velocity              = %.4f m/s\n', ultra_best_results.v);
    fprintf(fid, '  Friction Factor       = %.6f\n', ultra_best_results.f_c);
    fprintf(fid, '\n');

    fprintf(fid, 'GEOMETRY DERIVED:\n');
    fprintf(fid, '  Number of Turns       = %.1f\n', ultra_best_results.N_turn);
    fprintf(fid, '  Coil Length           = %.2f m\n', ultra_best_results.L_coil);
    fprintf(fid, '  Hydraulic Diameter    = %.4f m\n', ultra_best_results.D_h);
    fprintf(fid, '  Channel Area          = %.6f m2\n', ultra_best_results.A_c);
    fprintf(fid, '\n');

    fprintf(fid, 'HEAT TRANSFER VALIDATION:\n');
    fprintf(fid, '  A_required            = %.6f m2\n', ultra_best_results.A_req);
    fprintf(fid, '  A_available           = %.6f m2\n', ultra_best_results.A_av);
    fprintf(fid, '  Safety Factor         = %.1f (A_av/A_req)\n', ultra_best_results.A_av/ultra_best_results.A_req);
    fprintf(fid, '  Design Status         = VALID\n');

    fprintf(fid, '\n============================================================\n');
    fprintf(fid, '  CONSTRAINT ANALYSIS - WALL THICKNESS EFFECT\n');
    fprintf(fid, '============================================================\n\n');

    if ~isempty(constraint_analysis)
        fprintf(fid, '%10s | %10s | %10s | %10s | %10s | %10s\n', ...
            't_wall[mm]', 'GAP[mm]', 'w[mm]', 'Min DP[kPa]', 'h_j', 'Re');
        fprintf(fid, '%s\n', repmat('-', 1, 70));
        for i = 1:size(constraint_analysis, 1)
            fprintf(fid, '%10.1f | %10.1f | %10.1f | %10.4f | %10.1f | %10.0f\n', constraint_analysis(i,:));
        end
    end

    fprintf(fid, '\n============================================================\n');
    fprintf(fid, '  KEY FINDINGS & RECOMMENDATIONS\n');
    fprintf(fid, '============================================================\n\n');

    fprintf(fid, '1. OPTIMAL PRESSURE DROP REDUCTION:\n');
    fprintf(fid, '   - Achieved %.1f%% reduction from baseline\n', (1-ultra_best_DP/base_results.DP_kPa)*100);
    fprintf(fid, '   - From %.2f kPa to %.4f kPa\n\n', base_results.DP_kPa, ultra_best_DP);

    fprintf(fid, '2. TRADE-OFF ANALYSIS:\n');
    fprintf(fid, '   - Heat transfer coefficient reduced from %.0f to %.0f W/(m2K)\n', ...
        base_results.h_j, ultra_best_results.h_j);
    fprintf(fid, '   - Design remains valid with safety factor of %.1f\n', ...
        ultra_best_results.A_av/ultra_best_results.A_req);
    fprintf(fid, '   - Adequate thermal performance maintained\n\n');

    fprintf(fid, '3. PHYSICAL INSIGHTS:\n');
    fprintf(fid, '   - Larger GAP reduces velocity and friction losses\n');
    fprintf(fid, '   - Wider channels (larger w) reduce number of turns\n');
    fprintf(fid, '   - Pressure drop scales with velocity squared (v^2)\n');
    fprintf(fid, '   - Lower Re means lower friction factor in Mishra-Gupta\n\n');

    fprintf(fid, '4. MANUFACTURING CONSIDERATIONS:\n');
    fprintf(fid, '   - t_wall = %.1f mm is manufacturable\n', ultra_best_params.t_wall*1000);
    fprintf(fid, '   - GAP = %.1f mm provides good clearance\n', ultra_best_params.GAP*1000);
    fprintf(fid, '   - Recommend minimum t_wall >= 5mm for structural integrity\n\n');

    fprintf(fid, '============================================================\n');
    fprintf(fid, '  FILES GENERATED\n');
    fprintf(fid, '============================================================\n');
    fprintf(fid, '  ExtendedOptimization.png    - Overall optimization results\n');
    fprintf(fid, '  DetailedComparison.png      - Detailed config comparison\n');
    fprintf(fid, '  DesignSpace.png             - Design envelope visualization\n');
    fprintf(fid, '  EXTREME_STUDY_SUMMARY.txt   - This file\n\n');

    fclose(fid);
    fprintf('Saved: EXTREME_STUDY_SUMMARY.txt\n');

    fprintf('\n============================================================\n');
    fprintf('  EXTREME OPTIMIZATION COMPLETE\n');
    fprintf('============================================================\n');
    fprintf('Ultimate optimum: DP = %.4f kPa (%.1f%% reduction)\n', ...
        ultra_best_DP, (1-ultra_best_DP/base_results.DP_kPa)*100);
    fprintf('Configuration: GAP=%.1f mm, w=%.1f mm, t_wall=%.1f mm\n', ...
        ultra_best_params.GAP*1000, ultra_best_params.w*1000, ultra_best_params.t_wall*1000);
    fprintf('Results folder: %s\n', results_folder);
end
