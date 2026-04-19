function parametric_study_v2()
% PARAMETRIC_STUDY_V2  Comprehensive optimization with shell size constraints
%
% Objectives (multi-objective optimization):
%   1. Minimize tube-side pressure drop (DP_t < 7 kPa baseline)
%   2. Minimize shell-side pressure drop (DP_s < 0.068 Pa baseline)
%   3. Minimize shell length (L_tube)
%   4. Minimize shell diameter (D_s)
%   5. Minimize L/D ratio for compact design
%
% Fixed conditions:
%   - m_cold = 0.0570722222 kg/s (air)
%   - m_hot = 0.25 kg/s (heating fluid)
%   - T_cold1 = 25 C, T_cold2 = 280 C, T_hot1 = 330 C

    %% Create results folder with timestamp
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    results_folder = fullfile(pwd, 'results', ['study_v2_' timestamp]);
    if ~exist(results_folder, 'dir')
        mkdir(results_folder);
    end

    %% Fixed process conditions
    fixed = struct();
    fixed.m_cold = 0.0570722222;  % kg/s
    fixed.T_cold1 = 25;           % C
    fixed.T_cold2 = 280;          % C
    fixed.m_hot = 0.25;           % kg/s
    fixed.T_hot1 = 330;           % C

    %% Baseline constraints (from original design)
    constraints.DP_t_max = 7000;    % Pa (7 kPa)
    constraints.DP_s_max = 0.068;   % Pa

    %% Run comprehensive multi-objective study
    fprintf('\n========== COMPREHENSIVE SHELL SIZE OPTIMIZATION ==========\n');
    fprintf('Objectives: Min DP_t, Min DP_s, Min L_shell, Min D_s, Min L/D ratio\n');
    fprintf('Constraints: DP_t < 7 kPa, DP_s < 0.068 Pa\n\n');

    results = run_comprehensive_study(fixed, constraints, results_folder);

    %% Generate summary
    generate_comprehensive_summary(results_folder, results, constraints);

    fprintf('\n\nAll results saved to: %s\n', results_folder);
end

%% ========================================================================
%  COMPREHENSIVE MULTI-OBJECTIVE STUDY
%  ========================================================================
function results = run_comprehensive_study(fixed, constraints, results_folder)

    % Expanded parameter ranges for finding compact designs
    % Shorter tubes require more tubes, affecting shell diameter
    L_tube_range = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];  % m
    D_int_range = [0.012, 0.015, 0.018, 0.020, 0.022];                 % m
    D_ext_range = [0.016, 0.018, 0.020, 0.022, 0.025];                 % m
    N_p_range = [2, 4, 6, 8];                                            % passes (must be even)

    % Fin geometry
    l_f_range = [0.004, 0.006, 0.008, 0.010];    % m
    p_f_range = [0.002, 0.0025, 0.003];          % m
    t_f_range = [0.0005, 0.001];                  % m

    % Layout
    psi_n_range = [0.10, 0.15, 0.20];
    LB_mult_range = [1.5, 2.0, 2.5, 3.0];

    all_results = [];
    idx = 1;
    total_configs = 0;
    valid_configs = 0;

    fprintf('Scanning parameter space...\n');

    for L = L_tube_range
        for Di = D_int_range
            for De = D_ext_range
                % Skip invalid tube combinations
                if De <= Di + 0.002
                    continue;
                end

                for Np = N_p_range
                    for lf = l_f_range
                        for pf = p_f_range
                            for tf = t_f_range
                                for psin = psi_n_range
                                    for LBm = LB_mult_range
                                        total_configs = total_configs + 1;

                                        % Create parameter struct
                                        params = fixed;
                                        params.L_tube = L;
                                        params.D_int = Di;
                                        params.D_ext = De;
                                        params.N_p = Np;
                                        params.l_f = lf;
                                        params.p_f = pf;
                                        params.t_f = tf;
                                        params.psi_n = psin;
                                        params.LB_mult = LBm;

                                        try
                                            evalc('r = air_heater(params);');

                                            % Check constraints
                                            valid = (r.DP_t <= constraints.DP_t_max) && ...
                                                    (r.DP_s <= constraints.DP_s_max);

                                            if valid
                                                valid_configs = valid_configs + 1;
                                            end

                                            % Store results
                                            all_results(idx).L_tube = L;
                                            all_results(idx).D_int = Di;
                                            all_results(idx).D_ext = De;
                                            all_results(idx).N_p = Np;
                                            all_results(idx).l_f = lf;
                                            all_results(idx).p_f = pf;
                                            all_results(idx).t_f = tf;
                                            all_results(idx).psi_n = psin;
                                            all_results(idx).LB_mult = LBm;

                                            all_results(idx).DP_t = r.DP_t;
                                            all_results(idx).DP_t_kPa = r.DP_t / 1000;
                                            all_results(idx).DP_s = r.DP_s;
                                            all_results(idx).D_s = r.D_s;
                                            all_results(idx).D_s_mm = r.D_s * 1000;
                                            all_results(idx).L_shell = L;  % Shell length = tube length
                                            all_results(idx).L_shell_mm = L * 1000;
                                            all_results(idx).L_D_ratio = L / r.D_s;
                                            all_results(idx).N_tt = r.N_tt;
                                            all_results(idx).U_o_calc = r.U_o_calc;
                                            all_results(idx).valid = valid;

                                            % Calculate shell volume (approximate as cylinder)
                                            all_results(idx).shell_volume = pi * (r.D_s/2)^2 * L * 1000;  % liters

                                            idx = idx + 1;
                                        catch
                                            % Skip failed cases
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    fprintf('Total configurations tested: %d\n', total_configs);
    fprintf('Successful simulations: %d\n', idx - 1);
    fprintf('Valid configurations (meet all constraints): %d\n', valid_configs);

    % Convert to table
    T = struct2table(all_results);
    valid_T = T(T.valid == 1, :);

    % Multi-objective scoring for valid designs
    if ~isempty(valid_T) && height(valid_T) > 1
        % Normalize all objectives (0 = best, 1 = worst)
        DP_t_norm = normalize_objective(valid_T.DP_t_kPa);
        DP_s_norm = normalize_objective(valid_T.DP_s);
        L_norm = normalize_objective(valid_T.L_shell_mm);
        D_norm = normalize_objective(valid_T.D_s_mm);
        LD_norm = normalize_objective(valid_T.L_D_ratio);
        Vol_norm = normalize_objective(valid_T.shell_volume);

        % Weighted multi-objective score
        % Weights: DP_t=20%, DP_s=10%, L_shell=25%, D_s=25%, L/D=10%, Volume=10%
        valid_T.score = 0.20 * DP_t_norm + ...
                        0.10 * DP_s_norm + ...
                        0.25 * L_norm + ...
                        0.25 * D_norm + ...
                        0.10 * LD_norm + ...
                        0.10 * Vol_norm;

        % Sort by score (lower is better)
        valid_T = sortrows(valid_T, 'score');

        % Get best design
        best = valid_T(1, :);

        % Get Pareto-optimal designs (non-dominated in DP_t, L_shell, D_s)
        pareto = find_pareto_front(valid_T);
    else
        best = valid_T(1, :);
        pareto = valid_T;
    end

    % Generate plots
    generate_v2_plots(T, valid_T, pareto, best, results_folder);

    % Save results
    writetable(T, fullfile(results_folder, 'all_results.csv'));
    writetable(valid_T, fullfile(results_folder, 'valid_results.csv'));
    writetable(pareto, fullfile(results_folder, 'pareto_optimal.csv'));

    % Pack results
    results.all = T;
    results.valid = valid_T;
    results.pareto = pareto;
    results.best = best;
    results.constraints = constraints;
end

function norm_val = normalize_objective(values)
    min_val = min(values);
    max_val = max(values);
    if max_val - min_val < 1e-10
        norm_val = zeros(size(values));
    else
        norm_val = (values - min_val) / (max_val - min_val);
    end
end

function pareto = find_pareto_front(T)
    % Find Pareto-optimal designs (non-dominated in key objectives)
    % Objectives: minimize DP_t, L_shell, D_s

    n = height(T);
    is_dominated = false(n, 1);

    for i = 1:n
        for j = 1:n
            if i ~= j
                % Check if j dominates i (j is better or equal in all, strictly better in at least one)
                j_better_or_equal = (T.DP_t_kPa(j) <= T.DP_t_kPa(i)) && ...
                                    (T.L_shell_mm(j) <= T.L_shell_mm(i)) && ...
                                    (T.D_s_mm(j) <= T.D_s_mm(i));
                j_strictly_better = (T.DP_t_kPa(j) < T.DP_t_kPa(i)) || ...
                                    (T.L_shell_mm(j) < T.L_shell_mm(i)) || ...
                                    (T.D_s_mm(j) < T.D_s_mm(i));
                if j_better_or_equal && j_strictly_better
                    is_dominated(i) = true;
                    break;
                end
            end
        end
    end

    pareto = T(~is_dominated, :);
    pareto = sortrows(pareto, 'L_shell_mm');  % Sort by shell length
end

function generate_v2_plots(all_data, valid_data, pareto, best, folder)

    % Plot 1: L_shell vs D_s with DP_t coloring
    figure('Position', [100, 100, 900, 700], 'Visible', 'off');
    if ~isempty(valid_data)
        scatter(valid_data.D_s_mm, valid_data.L_shell_mm, 40, valid_data.DP_t_kPa, 'filled', 'MarkerFaceAlpha', 0.6);
        hold on;
        % Mark Pareto front
        plot(pareto.D_s_mm, pareto.L_shell_mm, 'r-', 'LineWidth', 2);
        scatter(pareto.D_s_mm, pareto.L_shell_mm, 80, 'r', 'filled');
        % Mark best
        scatter(best.D_s_mm, best.L_shell_mm, 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g', 'LineWidth', 2);
        cb = colorbar; cb.Label.String = 'Tube-side Pressure Drop [kPa]';
        xlabel('Shell Diameter D_s [mm]');
        ylabel('Shell Length L_{shell} [mm]');
        title('Shell Size Trade-off (Pareto Front in Red, Best = Green Star)');
        legend('Valid Designs', 'Pareto Front', 'Pareto Points', 'Overall Best', 'Location', 'best');
        grid on;
    end
    saveas(gcf, fullfile(folder, 'shell_size_tradeoff.png'));
    close;

    % Plot 2: L/D ratio vs DP_t
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    if ~isempty(valid_data)
        scatter(valid_data.DP_t_kPa, valid_data.L_D_ratio, 40, valid_data.D_s_mm, 'filled', 'MarkerFaceAlpha', 0.6);
        hold on;
        scatter(best.DP_t_kPa, best.L_D_ratio, 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g', 'LineWidth', 2);
        xline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
        cb = colorbar; cb.Label.String = 'Shell Diameter [mm]';
        xlabel('Tube-side Pressure Drop [kPa]');
        ylabel('L/D Ratio');
        title('Aspect Ratio vs Pressure Drop');
        grid on;
    end
    saveas(gcf, fullfile(folder, 'LD_ratio_vs_DP.png'));
    close;

    % Plot 3: Shell volume vs DP_t
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    if ~isempty(valid_data)
        scatter(valid_data.DP_t_kPa, valid_data.shell_volume, 40, valid_data.L_D_ratio, 'filled', 'MarkerFaceAlpha', 0.6);
        hold on;
        scatter(best.DP_t_kPa, best.shell_volume, 200, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g', 'LineWidth', 2);
        xline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
        cb = colorbar; cb.Label.String = 'L/D Ratio';
        xlabel('Tube-side Pressure Drop [kPa]');
        ylabel('Shell Volume [liters]');
        title('Shell Volume vs Pressure Drop');
        grid on;
    end
    saveas(gcf, fullfile(folder, 'volume_vs_DP.png'));
    close;

    % Plot 4: Effect of tube length on shell diameter
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    if ~isempty(valid_data)
        L_values = unique(valid_data.L_tube);
        colors = lines(length(L_values));
        hold on;
        for i = 1:length(L_values)
            subset = valid_data(valid_data.L_tube == L_values(i), :);
            if ~isempty(subset)
                scatter(subset.D_s_mm, subset.DP_t_kPa, 30, colors(i,:), 'filled', 'MarkerFaceAlpha', 0.5);
            end
        end
        yline(7, 'r--', 'LineWidth', 2);
        xlabel('Shell Diameter D_s [mm]');
        ylabel('Tube-side Pressure Drop [kPa]');
        title('Effect of Tube Length on Design Space');
        legend(arrayfun(@(x) sprintf('L=%.2fm', x), L_values, 'UniformOutput', false), 'Location', 'best');
        grid on;
    end
    saveas(gcf, fullfile(folder, 'L_tube_effect.png'));
    close;

    % Plot 5: 3D visualization - L, D, DP
    figure('Position', [100, 100, 900, 700], 'Visible', 'off');
    if ~isempty(valid_data)
        scatter3(valid_data.D_s_mm, valid_data.L_shell_mm, valid_data.DP_t_kPa, ...
                 30, valid_data.shell_volume, 'filled', 'MarkerFaceAlpha', 0.5);
        hold on;
        scatter3(best.D_s_mm, best.L_shell_mm, best.DP_t_kPa, 200, 'g', 'p', 'filled');
        cb = colorbar; cb.Label.String = 'Shell Volume [L]';
        xlabel('Shell Diameter [mm]');
        ylabel('Shell Length [mm]');
        zlabel('Pressure Drop [kPa]');
        title('3D Design Space (Green Star = Best)');
        view(45, 30);
        grid on;
    end
    saveas(gcf, fullfile(folder, '3D_design_space.png'));
    close;

    % Plot 6: Pareto front comparison - multiple views
    figure('Position', [100, 100, 1200, 500], 'Visible', 'off');

    subplot(1,3,1);
    if ~isempty(pareto)
        scatter(pareto.D_s_mm, pareto.L_shell_mm, 60, pareto.DP_t_kPa, 'filled');
        hold on;
        scatter(best.D_s_mm, best.L_shell_mm, 150, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');
        cb = colorbar; cb.Label.String = 'DP_t [kPa]';
        xlabel('D_s [mm]'); ylabel('L_{shell} [mm]');
        title('Pareto: D_s vs L_{shell}');
        grid on;
    end

    subplot(1,3,2);
    if ~isempty(pareto)
        scatter(pareto.DP_t_kPa, pareto.L_shell_mm, 60, pareto.D_s_mm, 'filled');
        hold on;
        scatter(best.DP_t_kPa, best.L_shell_mm, 150, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');
        cb = colorbar; cb.Label.String = 'D_s [mm]';
        xlabel('DP_t [kPa]'); ylabel('L_{shell} [mm]');
        title('Pareto: DP_t vs L_{shell}');
        grid on;
    end

    subplot(1,3,3);
    if ~isempty(pareto)
        scatter(pareto.DP_t_kPa, pareto.D_s_mm, 60, pareto.L_shell_mm, 'filled');
        hold on;
        scatter(best.DP_t_kPa, best.D_s_mm, 150, 'p', 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'g');
        cb = colorbar; cb.Label.String = 'L_{shell} [mm]';
        xlabel('DP_t [kPa]'); ylabel('D_s [mm]');
        title('Pareto: DP_t vs D_s');
        grid on;
    end

    saveas(gcf, fullfile(folder, 'pareto_views.png'));
    close;

    % Plot 7: Top 10 designs comparison
    figure('Position', [100, 100, 1000, 600], 'Visible', 'off');
    if height(valid_data) >= 10
        top10 = valid_data(1:10, :);
    else
        top10 = valid_data;
    end

    if ~isempty(top10)
        x = 1:height(top10);

        subplot(2,2,1);
        bar(x, top10.L_shell_mm);
        xlabel('Design Rank'); ylabel('Shell Length [mm]');
        title('Top 10: Shell Length');
        grid on;

        subplot(2,2,2);
        bar(x, top10.D_s_mm);
        xlabel('Design Rank'); ylabel('Shell Diameter [mm]');
        title('Top 10: Shell Diameter');
        grid on;

        subplot(2,2,3);
        bar(x, top10.DP_t_kPa);
        hold on;
        yline(7, 'r--', 'LineWidth', 2);
        xlabel('Design Rank'); ylabel('DP_t [kPa]');
        title('Top 10: Tube Pressure Drop');
        grid on;

        subplot(2,2,4);
        bar(x, top10.L_D_ratio);
        xlabel('Design Rank'); ylabel('L/D Ratio');
        title('Top 10: Aspect Ratio');
        grid on;
    end

    saveas(gcf, fullfile(folder, 'top10_comparison.png'));
    close;
end

%% ========================================================================
%  SUMMARY REPORT
%  ========================================================================
function generate_comprehensive_summary(folder, results, constraints)

    best = results.best;
    pareto = results.pareto;
    valid = results.valid;

    % Write text summary
    fid = fopen(fullfile(folder, 'SUMMARY_REPORT.txt'), 'w');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '   AIR HEATER OPTIMIZATION V2 - COMPACT DESIGN STUDY\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));

    fprintf(fid, 'OPTIMIZATION OBJECTIVES:\n');
    fprintf(fid, '  1. Minimize tube-side pressure drop (DP_t)\n');
    fprintf(fid, '  2. Minimize shell-side pressure drop (DP_s)\n');
    fprintf(fid, '  3. Minimize shell length (L_shell)\n');
    fprintf(fid, '  4. Minimize shell diameter (D_s)\n');
    fprintf(fid, '  5. Minimize L/D ratio (compact design)\n\n');

    fprintf(fid, 'CONSTRAINTS:\n');
    fprintf(fid, '  DP_t < %.1f kPa (baseline tube-side limit)\n', constraints.DP_t_max/1000);
    fprintf(fid, '  DP_s < %.4f Pa (baseline shell-side limit)\n\n', constraints.DP_s_max);

    fprintf(fid, 'WEIGHTING:\n');
    fprintf(fid, '  DP_t: 20%%, DP_s: 10%%, L_shell: 25%%, D_s: 25%%, L/D: 10%%, Volume: 10%%\n\n');

    fprintf(fid, 'SEARCH RESULTS:\n');
    fprintf(fid, '  Total configurations tested: %d\n', height(results.all));
    fprintf(fid, '  Valid configurations: %d\n', height(valid));
    fprintf(fid, '  Pareto-optimal designs: %d\n\n', height(pareto));

    fprintf(fid, '================================================================\n');
    fprintf(fid, 'BEST OVERALL DESIGN (Weighted Score)\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '\nTube Geometry:\n');
    fprintf(fid, '  L_tube = %.2f m (shell length)\n', best.L_tube);
    fprintf(fid, '  D_int  = %.1f mm\n', best.D_int*1000);
    fprintf(fid, '  D_ext  = %.1f mm\n', best.D_ext*1000);
    fprintf(fid, '  N_p    = %d passes\n', best.N_p);
    fprintf(fid, '\nFin Geometry:\n');
    fprintf(fid, '  l_f = %.1f mm\n', best.l_f*1000);
    fprintf(fid, '  p_f = %.2f mm\n', best.p_f*1000);
    fprintf(fid, '  t_f = %.2f mm\n', best.t_f*1000);
    fprintf(fid, '\nLayout:\n');
    fprintf(fid, '  psi_n   = %.2f\n', best.psi_n);
    fprintf(fid, '  LB_mult = %.1f\n', best.LB_mult);
    fprintf(fid, '\nPERFORMANCE:\n');
    fprintf(fid, '  Shell length:     L_shell = %.0f mm (%.2f m)\n', best.L_shell_mm, best.L_shell);
    fprintf(fid, '  Shell diameter:   D_s     = %.1f mm\n', best.D_s_mm);
    fprintf(fid, '  L/D ratio:                = %.2f\n', best.L_D_ratio);
    fprintf(fid, '  Shell volume:             = %.1f liters\n', best.shell_volume);
    fprintf(fid, '  Number of tubes:  N_tt    = %.1f\n', best.N_tt);
    fprintf(fid, '\n  Tube-side DP:     DP_t = %.3f kPa  (limit: %.1f kPa) OK\n', best.DP_t_kPa, constraints.DP_t_max/1000);
    fprintf(fid, '  Shell-side DP:    DP_s = %.5f Pa  (limit: %.4f Pa) OK\n', best.DP_s, constraints.DP_s_max);
    fprintf(fid, '  Overall HTC:      U    = %.2f W/m2/K\n', best.U_o_calc);

    fprintf(fid, '\n================================================================\n');
    fprintf(fid, 'PARETO-OPTIMAL DESIGNS (Top 10)\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '%-6s %-8s %-8s %-8s %-8s %-10s\n', 'Rank', 'L[mm]', 'D_s[mm]', 'L/D', 'DP_t[kPa]', 'Vol[L]');
    fprintf(fid, '--------------------------------------------------------------\n');
    n_show = min(10, height(pareto));
    for i = 1:n_show
        fprintf(fid, '%-6d %-8.0f %-8.1f %-8.2f %-8.3f %-10.1f\n', ...
                i, pareto.L_shell_mm(i), pareto.D_s_mm(i), pareto.L_D_ratio(i), ...
                pareto.DP_t_kPa(i), pareto.shell_volume(i));
    end

    fprintf(fid, '\n================================================================\n');
    fprintf(fid, 'COMPARISON WITH PREVIOUS DESIGNS\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '                    Original    V1 Optimized   V2 Compact\n');
    fprintf(fid, 'Shell Length [mm]:   2000         3000          %.0f\n', best.L_shell_mm);
    fprintf(fid, 'Shell Diameter [mm]: 238          189           %.1f\n', best.D_s_mm);
    fprintf(fid, 'L/D Ratio:           8.4          15.9          %.2f\n', best.L_D_ratio);
    fprintf(fid, 'DP_t [kPa]:          7.0          0.24          %.3f\n', best.DP_t_kPa);
    fprintf(fid, 'Volume [L]:          ~89          ~84           %.1f\n', best.shell_volume);

    fprintf(fid, '\n================================================================\n');
    fprintf(fid, 'DESIGN INSIGHTS\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '1. Shorter tubes require more tubes -> larger diameter\n');
    fprintf(fid, '2. Trade-off between L and D for fixed heat transfer area\n');
    fprintf(fid, '3. Lower L/D ratios (more compact) typically need more passes\n');
    fprintf(fid, '4. Pressure drop constraint limits how compact the design can be\n');
    fprintf(fid, '================================================================\n');

    fclose(fid);

    % Print to console
    fprintf('\n========== BEST COMPACT DESIGN ==========\n');
    fprintf('Shell: %.0f mm long x %.1f mm diameter (L/D = %.2f)\n', ...
            best.L_shell_mm, best.D_s_mm, best.L_D_ratio);
    fprintf('Volume: %.1f liters\n', best.shell_volume);
    fprintf('DP_t = %.3f kPa, DP_s = %.5f Pa\n', best.DP_t_kPa, best.DP_s);
    fprintf('Tubes: %.0f tubes, %d passes, Di=%.0fmm\n', best.N_tt, best.N_p, best.D_int*1000);
    fprintf('\nSummary saved to: %s\n', fullfile(folder, 'SUMMARY_REPORT.txt'));
end
