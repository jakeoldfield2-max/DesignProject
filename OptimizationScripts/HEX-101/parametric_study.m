function parametric_study()
% PARAMETRIC_STUDY  Runs parametric studies on air heater design
%
% Objective: Minimize tube-side pressure drop (< 7 kPa) and shell diameter
% Fixed conditions:
%   - m_cold = 0.0570722222 kg/s (air)
%   - m_hot = 0.25 kg/s (heating fluid)
%   - T_cold1 = 25 C (air inlet)
%   - T_cold2 = 280 C (air outlet)
%   - T_hot1 = 330 C (salt inlet)

    %% Create results folder with timestamp
    timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');
    results_folder = fullfile(pwd, 'results', ['study_' timestamp]);
    if ~exist(results_folder, 'dir')
        mkdir(results_folder);
    end

    %% Fixed process conditions
    fixed = struct();
    fixed.m_cold = 0.0570722222;  % kg/s
    fixed.T_cold1 = 25;           % C (user specified)
    fixed.T_cold2 = 280;          % C
    fixed.m_hot = 0.25;           % kg/s
    fixed.T_hot1 = 330;           % C

    %% Run Study Phase 1: Tube Geometry (L_tube, D_int, D_ext)
    fprintf('\n========== PHASE 1: TUBE GEOMETRY STUDY ==========\n');
    phase1_results = study_tube_geometry(fixed, results_folder);

    %% Run Study Phase 2: Fin Geometry (l_f, p_f, t_f)
    fprintf('\n========== PHASE 2: FIN GEOMETRY STUDY ==========\n');
    phase2_results = study_fin_geometry(fixed, phase1_results.best, results_folder);

    %% Run Study Phase 3: Layout Parameters (N_p, LB_mult, psi_n)
    fprintf('\n========== PHASE 3: LAYOUT STUDY ==========\n');
    phase3_results = study_layout(fixed, phase2_results.best, results_folder);

    %% Generate summary report
    generate_summary_report(results_folder, phase1_results, phase2_results, phase3_results);

    fprintf('\n\nAll results saved to: %s\n', results_folder);
end

%% ========================================================================
%  PHASE 1: TUBE GEOMETRY STUDY
%  ========================================================================
function results = study_tube_geometry(fixed, results_folder)
    fprintf('Varying: L_tube, D_int, D_ext, N_p\n');

    % Parameter ranges - engineering standards
    L_tube_range = [1.0, 1.5, 2.0, 2.5, 3.0];           % m
    D_int_range = [0.008, 0.010, 0.012, 0.015, 0.018];  % m
    D_ext_range = [0.012, 0.014, 0.016, 0.018, 0.020];  % m (must be > D_int)
    N_p_range = [2, 4, 6, 8];                            % tube passes

    % Store all results
    all_results = [];
    idx = 1;

    for L = L_tube_range
        for Di = D_int_range
            for De = D_ext_range
                for Np = N_p_range
                    % Skip invalid combinations
                    if De <= Di + 0.002  % minimum wall thickness 1mm
                        continue;
                    end

                    % Create parameter struct
                    params = fixed;
                    params.L_tube = L;
                    params.D_int = Di;
                    params.D_ext = De;
                    params.N_p = Np;

                    % Run simulation (suppress output)
                    try
                        evalc('r = air_heater(params);');

                        % Store results
                        all_results(idx).L_tube = L;
                        all_results(idx).D_int = Di;
                        all_results(idx).D_ext = De;
                        all_results(idx).N_p = Np;
                        all_results(idx).DP_t = r.DP_t;
                        all_results(idx).DP_t_kPa = r.DP_t / 1000;
                        all_results(idx).D_s = r.D_s;
                        all_results(idx).D_s_mm = r.D_s * 1000;
                        all_results(idx).N_tt = r.N_tt;
                        all_results(idx).U_o_calc = r.U_o_calc;
                        all_results(idx).valid = (r.DP_t < 7000);
                        idx = idx + 1;
                    catch
                        % Skip failed cases
                    end
                end
            end
        end
    end

    % Convert to table for analysis
    T = struct2table(all_results);

    % Filter valid results (DP_t < 7 kPa)
    valid_results = T(T.valid == 1, :);

    % Find best design (minimize DP_t with bias toward smaller D_s)
    if ~isempty(valid_results)
        % Weighted score: 70% pressure drop, 30% shell size
        DP_norm = (valid_results.DP_t_kPa - min(valid_results.DP_t_kPa)) / ...
                  (max(valid_results.DP_t_kPa) - min(valid_results.DP_t_kPa) + 0.001);
        Ds_norm = (valid_results.D_s_mm - min(valid_results.D_s_mm)) / ...
                  (max(valid_results.D_s_mm) - min(valid_results.D_s_mm) + 0.001);
        score = 0.7 * DP_norm + 0.3 * Ds_norm;
        [~, best_idx] = min(score);
        best = valid_results(best_idx, :);
    else
        % Fallback to baseline if no valid results
        best = T(1, :);
        warning('No valid results found in Phase 1, using first result');
    end

    % Generate plots
    generate_phase1_plots(T, valid_results, results_folder);

    % Store results
    results.all = T;
    results.valid = valid_results;
    results.best = struct('L_tube', best.L_tube, 'D_int', best.D_int, ...
                          'D_ext', best.D_ext, 'N_p', best.N_p);
    results.best_metrics = struct('DP_t_kPa', best.DP_t_kPa, 'D_s_mm', best.D_s_mm);

    fprintf('Phase 1 Best: L=%.2fm, Di=%.3fm, De=%.3fm, Np=%d\n', ...
            best.L_tube, best.D_int, best.D_ext, best.N_p);
    fprintf('  -> DP_t = %.2f kPa, D_s = %.1f mm\n', best.DP_t_kPa, best.D_s_mm);

    % Save results to CSV
    writetable(T, fullfile(results_folder, 'phase1_all_results.csv'));
    if ~isempty(valid_results)
        writetable(valid_results, fullfile(results_folder, 'phase1_valid_results.csv'));
    end
end

function generate_phase1_plots(all_data, valid_data, folder)
    % Plot 1: DP_t vs D_int for different L_tube
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    L_values = unique(all_data.L_tube);
    colors = lines(length(L_values));
    hold on;
    for i = 1:length(L_values)
        subset = all_data(all_data.L_tube == L_values(i) & all_data.N_p == 4, :);
        if ~isempty(subset)
            scatter(subset.D_int*1000, subset.DP_t_kPa, 50, colors(i,:), 'filled');
        end
    end
    yline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
    xlabel('Internal Diameter D_{int} [mm]');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Phase 1: Effect of Tube Diameter on Pressure Drop (N_p=4)');
    legend(arrayfun(@(x) sprintf('L=%.1fm', x), L_values, 'UniformOutput', false), ...
           'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase1_DP_vs_Dint.png'));
    close;

    % Plot 2: DP_t vs N_p for different D_int
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    D_int_values = unique(all_data.D_int);
    colors = lines(length(D_int_values));
    hold on;
    for i = 1:length(D_int_values)
        subset = all_data(all_data.D_int == D_int_values(i) & all_data.L_tube == 2.0, :);
        if ~isempty(subset)
            plot(subset.N_p, subset.DP_t_kPa, '-o', 'Color', colors(i,:), 'LineWidth', 1.5);
        end
    end
    yline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
    xlabel('Number of Tube Passes N_p');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Phase 1: Effect of Tube Passes on Pressure Drop (L=2.0m)');
    legend(arrayfun(@(x) sprintf('D_{int}=%.0fmm', x*1000), D_int_values, 'UniformOutput', false), ...
           'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase1_DP_vs_Np.png'));
    close;

    % Plot 3: D_s vs D_int
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    if ~isempty(valid_data)
        scatter(valid_data.D_int*1000, valid_data.D_s_mm, 50, valid_data.DP_t_kPa, 'filled');
        cb = colorbar; cb.Label.String = 'Pressure Drop [kPa]';
        xlabel('Internal Diameter D_{int} [mm]');
        ylabel('Shell Diameter D_s [mm]');
        title('Phase 1: Shell Size vs Tube Diameter (Valid Designs Only)');
        grid on;
    end
    saveas(gcf, fullfile(folder, 'phase1_Ds_vs_Dint.png'));
    close;

    % Plot 4: Pareto front - DP_t vs D_s
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    scatter(all_data.D_s_mm, all_data.DP_t_kPa, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    if ~isempty(valid_data)
        scatter(valid_data.D_s_mm, valid_data.DP_t_kPa, 50, 'g', 'filled');
    end
    yline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
    xlabel('Shell Diameter D_s [mm]');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Phase 1: Trade-off Space (Green = Valid Designs)');
    legend('All Designs', 'Valid Designs', 'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase1_pareto.png'));
    close;
end

%% ========================================================================
%  PHASE 2: FIN GEOMETRY STUDY
%  ========================================================================
function results = study_fin_geometry(fixed, best_tube, results_folder)
    fprintf('Using best tube geometry from Phase 1\n');
    fprintf('Varying: l_f, p_f, t_f\n');

    % Parameter ranges - engineering standards for helical fins
    l_f_range = [0.005, 0.006, 0.008, 0.010, 0.012];    % m (fin height)
    p_f_range = [0.002, 0.0025, 0.003, 0.0035, 0.004];  % m (fin pitch)
    t_f_range = [0.0003, 0.0005, 0.0007, 0.001];        % m (fin thickness)

    all_results = [];
    idx = 1;

    for lf = l_f_range
        for pf = p_f_range
            for tf = t_f_range
                % Create parameter struct
                params = fixed;
                params.L_tube = best_tube.L_tube;
                params.D_int = best_tube.D_int;
                params.D_ext = best_tube.D_ext;
                params.N_p = best_tube.N_p;
                params.l_f = lf;
                params.p_f = pf;
                params.t_f = tf;

                try
                    evalc('r = air_heater(params);');

                    all_results(idx).l_f = lf;
                    all_results(idx).l_f_mm = lf * 1000;
                    all_results(idx).p_f = pf;
                    all_results(idx).p_f_mm = pf * 1000;
                    all_results(idx).t_f = tf;
                    all_results(idx).t_f_mm = tf * 1000;
                    all_results(idx).DP_t = r.DP_t;
                    all_results(idx).DP_t_kPa = r.DP_t / 1000;
                    all_results(idx).D_s = r.D_s;
                    all_results(idx).D_s_mm = r.D_s * 1000;
                    all_results(idx).N_tt = r.N_tt;
                    all_results(idx).U_o_calc = r.U_o_calc;
                    all_results(idx).eta_f = r.eta_f;
                    all_results(idx).valid = (r.DP_t < 7000);
                    idx = idx + 1;
                catch
                end
            end
        end
    end

    T = struct2table(all_results);
    valid_results = T(T.valid == 1, :);

    if ~isempty(valid_results)
        DP_norm = (valid_results.DP_t_kPa - min(valid_results.DP_t_kPa)) / ...
                  (max(valid_results.DP_t_kPa) - min(valid_results.DP_t_kPa) + 0.001);
        Ds_norm = (valid_results.D_s_mm - min(valid_results.D_s_mm)) / ...
                  (max(valid_results.D_s_mm) - min(valid_results.D_s_mm) + 0.001);
        score = 0.7 * DP_norm + 0.3 * Ds_norm;
        [~, best_idx] = min(score);
        best = valid_results(best_idx, :);
    else
        best = T(1, :);
        warning('No valid results found in Phase 2');
    end

    generate_phase2_plots(T, valid_results, results_folder);

    results.all = T;
    results.valid = valid_results;
    results.best = struct('L_tube', best_tube.L_tube, 'D_int', best_tube.D_int, ...
                          'D_ext', best_tube.D_ext, 'N_p', best_tube.N_p, ...
                          'l_f', best.l_f, 'p_f', best.p_f, 't_f', best.t_f);
    results.best_metrics = struct('DP_t_kPa', best.DP_t_kPa, 'D_s_mm', best.D_s_mm);

    fprintf('Phase 2 Best: l_f=%.1fmm, p_f=%.2fmm, t_f=%.2fmm\n', ...
            best.l_f*1000, best.p_f*1000, best.t_f*1000);
    fprintf('  -> DP_t = %.2f kPa, D_s = %.1f mm\n', best.DP_t_kPa, best.D_s_mm);

    writetable(T, fullfile(results_folder, 'phase2_all_results.csv'));
    if ~isempty(valid_results)
        writetable(valid_results, fullfile(results_folder, 'phase2_valid_results.csv'));
    end
end

function generate_phase2_plots(all_data, valid_data, folder)
    % Plot 1: DP_t vs fin height for different pitches
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    p_f_values = unique(all_data.p_f_mm);
    colors = lines(length(p_f_values));
    hold on;
    for i = 1:length(p_f_values)
        subset = all_data(all_data.p_f_mm == p_f_values(i) & all_data.t_f_mm == 0.5, :);
        if ~isempty(subset)
            plot(subset.l_f_mm, subset.DP_t_kPa, '-o', 'Color', colors(i,:), 'LineWidth', 1.5);
        end
    end
    yline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
    xlabel('Fin Height l_f [mm]');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Phase 2: Effect of Fin Height on Pressure Drop (t_f=0.5mm)');
    legend(arrayfun(@(x) sprintf('p_f=%.2fmm', x), p_f_values, 'UniformOutput', false), ...
           'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase2_DP_vs_lf.png'));
    close;

    % Plot 2: D_s vs fin height
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    hold on;
    for i = 1:length(p_f_values)
        subset = all_data(all_data.p_f_mm == p_f_values(i) & all_data.t_f_mm == 0.5, :);
        if ~isempty(subset)
            plot(subset.l_f_mm, subset.D_s_mm, '-s', 'Color', colors(i,:), 'LineWidth', 1.5);
        end
    end
    xlabel('Fin Height l_f [mm]');
    ylabel('Shell Diameter D_s [mm]');
    title('Phase 2: Effect of Fin Height on Shell Size (t_f=0.5mm)');
    legend(arrayfun(@(x) sprintf('p_f=%.2fmm', x), p_f_values, 'UniformOutput', false), ...
           'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase2_Ds_vs_lf.png'));
    close;

    % Plot 3: Fin efficiency vs fin height
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    if ~isempty(valid_data)
        scatter(valid_data.l_f_mm, valid_data.eta_f, 50, valid_data.D_s_mm, 'filled');
        cb = colorbar; cb.Label.String = 'Shell Diameter [mm]';
        xlabel('Fin Height l_f [mm]');
        ylabel('Fin Efficiency \eta_f');
        title('Phase 2: Fin Efficiency vs Fin Height');
        grid on;
    end
    saveas(gcf, fullfile(folder, 'phase2_eta_vs_lf.png'));
    close;

    % Plot 4: Pareto front
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    scatter(all_data.D_s_mm, all_data.DP_t_kPa, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    if ~isempty(valid_data)
        scatter(valid_data.D_s_mm, valid_data.DP_t_kPa, 50, 'g', 'filled');
    end
    yline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
    xlabel('Shell Diameter D_s [mm]');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Phase 2: Trade-off Space (Green = Valid Designs)');
    legend('All Designs', 'Valid Designs', 'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase2_pareto.png'));
    close;
end

%% ========================================================================
%  PHASE 3: LAYOUT STUDY
%  ========================================================================
function results = study_layout(fixed, best_params, results_folder)
    fprintf('Using best parameters from Phase 1 & 2\n');
    fprintf('Varying: LB_mult, psi_n, BaffleCut\n');

    % Parameter ranges
    LB_mult_range = [1.5, 2.0, 2.5, 3.0, 3.5, 4.0];     % baffle spacing multiplier
    psi_n_range = [0.10, 0.15, 0.17, 0.20, 0.25];        % tube count fraction
    BaffleCut_range = [0.20, 0.25, 0.30, 0.35];          % baffle cut

    all_results = [];
    idx = 1;

    for LBm = LB_mult_range
        for psin = psi_n_range
            for BC = BaffleCut_range
                params = fixed;
                params.L_tube = best_params.L_tube;
                params.D_int = best_params.D_int;
                params.D_ext = best_params.D_ext;
                params.N_p = best_params.N_p;
                params.l_f = best_params.l_f;
                params.p_f = best_params.p_f;
                params.t_f = best_params.t_f;
                params.LB_mult = LBm;
                params.psi_n = psin;
                params.BaffleCut = BC;

                try
                    evalc('r = air_heater(params);');

                    all_results(idx).LB_mult = LBm;
                    all_results(idx).psi_n = psin;
                    all_results(idx).BaffleCut = BC;
                    all_results(idx).DP_t = r.DP_t;
                    all_results(idx).DP_t_kPa = r.DP_t / 1000;
                    all_results(idx).D_s = r.D_s;
                    all_results(idx).D_s_mm = r.D_s * 1000;
                    all_results(idx).L_B = r.L_B;
                    all_results(idx).L_B_mm = r.L_B * 1000;
                    all_results(idx).N_tt = r.N_tt;
                    all_results(idx).U_o_calc = r.U_o_calc;
                    all_results(idx).valid = (r.DP_t < 7000);
                    idx = idx + 1;
                catch
                end
            end
        end
    end

    T = struct2table(all_results);
    valid_results = T(T.valid == 1, :);

    if ~isempty(valid_results)
        DP_norm = (valid_results.DP_t_kPa - min(valid_results.DP_t_kPa)) / ...
                  (max(valid_results.DP_t_kPa) - min(valid_results.DP_t_kPa) + 0.001);
        Ds_norm = (valid_results.D_s_mm - min(valid_results.D_s_mm)) / ...
                  (max(valid_results.D_s_mm) - min(valid_results.D_s_mm) + 0.001);
        score = 0.7 * DP_norm + 0.3 * Ds_norm;
        [~, best_idx] = min(score);
        best = valid_results(best_idx, :);
    else
        best = T(1, :);
        warning('No valid results found in Phase 3');
    end

    generate_phase3_plots(T, valid_results, results_folder);

    results.all = T;
    results.valid = valid_results;
    results.best = struct('L_tube', best_params.L_tube, 'D_int', best_params.D_int, ...
                          'D_ext', best_params.D_ext, 'N_p', best_params.N_p, ...
                          'l_f', best_params.l_f, 'p_f', best_params.p_f, ...
                          't_f', best_params.t_f, 'LB_mult', best.LB_mult, ...
                          'psi_n', best.psi_n, 'BaffleCut', best.BaffleCut);
    results.best_metrics = struct('DP_t_kPa', best.DP_t_kPa, 'D_s_mm', best.D_s_mm);

    fprintf('Phase 3 Best: LB_mult=%.1f, psi_n=%.2f, BaffleCut=%.2f\n', ...
            best.LB_mult, best.psi_n, best.BaffleCut);
    fprintf('  -> DP_t = %.2f kPa, D_s = %.1f mm\n', best.DP_t_kPa, best.D_s_mm);

    writetable(T, fullfile(results_folder, 'phase3_all_results.csv'));
    if ~isempty(valid_results)
        writetable(valid_results, fullfile(results_folder, 'phase3_valid_results.csv'));
    end
end

function generate_phase3_plots(all_data, valid_data, folder)
    % Plot 1: DP_t vs LB_mult
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    psi_values = unique(all_data.psi_n);
    colors = lines(length(psi_values));
    hold on;
    for i = 1:length(psi_values)
        subset = all_data(all_data.psi_n == psi_values(i) & all_data.BaffleCut == 0.25, :);
        if ~isempty(subset)
            plot(subset.LB_mult, subset.DP_t_kPa, '-o', 'Color', colors(i,:), 'LineWidth', 1.5);
        end
    end
    yline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
    xlabel('Baffle Spacing Multiplier LB_{mult}');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Phase 3: Effect of Baffle Spacing on Pressure Drop');
    legend(arrayfun(@(x) sprintf('\\psi_n=%.2f', x), psi_values, 'UniformOutput', false), ...
           'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase3_DP_vs_LBmult.png'));
    close;

    % Plot 2: D_s vs psi_n
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    LB_values = unique(all_data.LB_mult);
    colors = lines(length(LB_values));
    hold on;
    for i = 1:length(LB_values)
        subset = all_data(all_data.LB_mult == LB_values(i) & all_data.BaffleCut == 0.25, :);
        if ~isempty(subset)
            plot(subset.psi_n, subset.D_s_mm, '-s', 'Color', colors(i,:), 'LineWidth', 1.5);
        end
    end
    xlabel('Tube Count Fraction \psi_n');
    ylabel('Shell Diameter D_s [mm]');
    title('Phase 3: Effect of Layout Density on Shell Size');
    legend(arrayfun(@(x) sprintf('LB_{mult}=%.1f', x), LB_values, 'UniformOutput', false), ...
           'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase3_Ds_vs_psin.png'));
    close;

    % Plot 3: 3D surface - DP_t vs LB_mult and psi_n
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    if ~isempty(valid_data)
        scatter3(valid_data.LB_mult, valid_data.psi_n, valid_data.DP_t_kPa, 50, valid_data.D_s_mm, 'filled');
        cb = colorbar; cb.Label.String = 'Shell Diameter [mm]';
        xlabel('LB_{mult}');
        ylabel('\psi_n');
        zlabel('Pressure Drop [kPa]');
        title('Phase 3: Parameter Space Exploration');
        view(45, 30);
        grid on;
    end
    saveas(gcf, fullfile(folder, 'phase3_3D_exploration.png'));
    close;

    % Plot 4: Pareto front
    figure('Position', [100, 100, 800, 600], 'Visible', 'off');
    scatter(all_data.D_s_mm, all_data.DP_t_kPa, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    if ~isempty(valid_data)
        scatter(valid_data.D_s_mm, valid_data.DP_t_kPa, 50, 'g', 'filled');
    end
    yline(7, 'r--', 'LineWidth', 2, 'Label', 'Max DP = 7 kPa');
    xlabel('Shell Diameter D_s [mm]');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Phase 3: Trade-off Space (Green = Valid Designs)');
    legend('All Designs', 'Valid Designs', 'Location', 'best');
    grid on;
    saveas(gcf, fullfile(folder, 'phase3_pareto.png'));
    close;
end

%% ========================================================================
%  SUMMARY REPORT
%  ========================================================================
function generate_summary_report(folder, p1, p2, p3)
    % Generate final comparison plot
    figure('Position', [100, 100, 1000, 800], 'Visible', 'off');

    subplot(2,2,1);
    bar([p1.best_metrics.DP_t_kPa, p2.best_metrics.DP_t_kPa, p3.best_metrics.DP_t_kPa]);
    hold on;
    yline(7, 'r--', 'LineWidth', 2);
    set(gca, 'XTickLabel', {'Phase 1', 'Phase 2', 'Phase 3'});
    ylabel('Pressure Drop [kPa]');
    title('Pressure Drop Evolution');
    grid on;

    subplot(2,2,2);
    bar([p1.best_metrics.D_s_mm, p2.best_metrics.D_s_mm, p3.best_metrics.D_s_mm]);
    set(gca, 'XTickLabel', {'Phase 1', 'Phase 2', 'Phase 3'});
    ylabel('Shell Diameter [mm]');
    title('Shell Size Evolution');
    grid on;

    % Combined Pareto plot
    subplot(2,2,[3,4]);
    hold on;
    if ~isempty(p1.valid)
        scatter(p1.valid.D_s_mm, p1.valid.DP_t_kPa, 30, 'b', 'filled', 'MarkerFaceAlpha', 0.4);
    end
    if ~isempty(p2.valid)
        scatter(p2.valid.D_s_mm, p2.valid.DP_t_kPa, 30, 'g', 'filled', 'MarkerFaceAlpha', 0.4);
    end
    if ~isempty(p3.valid)
        scatter(p3.valid.D_s_mm, p3.valid.DP_t_kPa, 30, 'm', 'filled', 'MarkerFaceAlpha', 0.4);
    end
    % Mark final best
    scatter(p3.best_metrics.D_s_mm, p3.best_metrics.DP_t_kPa, 200, 'r', 'p', 'LineWidth', 2);
    yline(7, 'r--', 'LineWidth', 2);
    xlabel('Shell Diameter D_s [mm]');
    ylabel('Tube-side Pressure Drop [kPa]');
    title('Combined Pareto Front (Star = Final Optimum)');
    legend('Phase 1', 'Phase 2', 'Phase 3', 'Final Best', 'Location', 'best');
    grid on;

    saveas(gcf, fullfile(folder, 'summary_comparison.png'));
    close;

    % Write text summary
    fid = fopen(fullfile(folder, 'SUMMARY_REPORT.txt'), 'w');
    fprintf(fid, '================================================================\n');
    fprintf(fid, '       AIR HEATER PARAMETRIC STUDY - SUMMARY REPORT\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, 'Generated: %s\n\n', datestr(now));

    fprintf(fid, 'FIXED OPERATING CONDITIONS:\n');
    fprintf(fid, '  Air mass flow rate:      0.0570722222 kg/s\n');
    fprintf(fid, '  Hot fluid mass flow:     0.25 kg/s\n');
    fprintf(fid, '  Air inlet temperature:   25 C\n');
    fprintf(fid, '  Air outlet temperature:  280 C\n');
    fprintf(fid, '  Salt inlet temperature:  330 C\n\n');

    fprintf(fid, 'OPTIMIZATION OBJECTIVES:\n');
    fprintf(fid, '  Primary:   Minimize tube-side pressure drop (< 7 kPa)\n');
    fprintf(fid, '  Secondary: Minimize shell diameter\n');
    fprintf(fid, '  Weighting: 70%% pressure drop, 30%% shell size\n\n');

    fprintf(fid, '================================================================\n');
    fprintf(fid, 'PHASE 1: TUBE GEOMETRY OPTIMIZATION\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, 'Parameters varied: L_tube, D_int, D_ext, N_p\n');
    fprintf(fid, 'Total configurations tested: %d\n', height(p1.all));
    fprintf(fid, 'Valid configurations (DP_t < 7 kPa): %d\n', height(p1.valid));
    fprintf(fid, '\nBest Phase 1 Design:\n');
    fprintf(fid, '  Tube length:      L_tube = %.2f m\n', p1.best.L_tube);
    fprintf(fid, '  Internal dia:     D_int  = %.1f mm\n', p1.best.D_int*1000);
    fprintf(fid, '  External dia:     D_ext  = %.1f mm\n', p1.best.D_ext*1000);
    fprintf(fid, '  Tube passes:      N_p    = %d\n', p1.best.N_p);
    fprintf(fid, '  -> Pressure drop: %.2f kPa\n', p1.best_metrics.DP_t_kPa);
    fprintf(fid, '  -> Shell diameter: %.1f mm\n\n', p1.best_metrics.D_s_mm);

    fprintf(fid, '================================================================\n');
    fprintf(fid, 'PHASE 2: FIN GEOMETRY OPTIMIZATION\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, 'Parameters varied: l_f, p_f, t_f\n');
    fprintf(fid, 'Total configurations tested: %d\n', height(p2.all));
    fprintf(fid, 'Valid configurations (DP_t < 7 kPa): %d\n', height(p2.valid));
    fprintf(fid, '\nBest Phase 2 Design:\n');
    fprintf(fid, '  Fin height:       l_f = %.1f mm\n', p2.best.l_f*1000);
    fprintf(fid, '  Fin pitch:        p_f = %.2f mm\n', p2.best.p_f*1000);
    fprintf(fid, '  Fin thickness:    t_f = %.2f mm\n', p2.best.t_f*1000);
    fprintf(fid, '  -> Pressure drop: %.2f kPa\n', p2.best_metrics.DP_t_kPa);
    fprintf(fid, '  -> Shell diameter: %.1f mm\n\n', p2.best_metrics.D_s_mm);

    fprintf(fid, '================================================================\n');
    fprintf(fid, 'PHASE 3: LAYOUT OPTIMIZATION\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, 'Parameters varied: LB_mult, psi_n, BaffleCut\n');
    fprintf(fid, 'Total configurations tested: %d\n', height(p3.all));
    fprintf(fid, 'Valid configurations (DP_t < 7 kPa): %d\n', height(p3.valid));
    fprintf(fid, '\nBest Phase 3 Design:\n');
    fprintf(fid, '  Baffle spacing mult: LB_mult   = %.1f\n', p3.best.LB_mult);
    fprintf(fid, '  Tube count fraction: psi_n     = %.2f\n', p3.best.psi_n);
    fprintf(fid, '  Baffle cut:          BaffleCut = %.2f\n', p3.best.BaffleCut);
    fprintf(fid, '  -> Pressure drop: %.2f kPa\n', p3.best_metrics.DP_t_kPa);
    fprintf(fid, '  -> Shell diameter: %.1f mm\n\n', p3.best_metrics.D_s_mm);

    fprintf(fid, '================================================================\n');
    fprintf(fid, 'FINAL OPTIMIZED DESIGN\n');
    fprintf(fid, '================================================================\n');
    fprintf(fid, 'Tube Geometry:\n');
    fprintf(fid, '  L_tube = %.2f m\n', p3.best.L_tube);
    fprintf(fid, '  D_int  = %.1f mm\n', p3.best.D_int*1000);
    fprintf(fid, '  D_ext  = %.1f mm\n', p3.best.D_ext*1000);
    fprintf(fid, '  N_p    = %d passes\n\n', p3.best.N_p);
    fprintf(fid, 'Fin Geometry:\n');
    fprintf(fid, '  l_f = %.1f mm (fin height)\n', p3.best.l_f*1000);
    fprintf(fid, '  p_f = %.2f mm (fin pitch)\n', p3.best.p_f*1000);
    fprintf(fid, '  t_f = %.2f mm (fin thickness)\n\n', p3.best.t_f*1000);
    fprintf(fid, 'Layout Parameters:\n');
    fprintf(fid, '  LB_mult   = %.1f\n', p3.best.LB_mult);
    fprintf(fid, '  psi_n     = %.2f\n', p3.best.psi_n);
    fprintf(fid, '  BaffleCut = %.2f\n\n', p3.best.BaffleCut);
    fprintf(fid, 'FINAL PERFORMANCE:\n');
    fprintf(fid, '  Tube-side pressure drop: %.2f kPa (< 7 kPa constraint: OK)\n', p3.best_metrics.DP_t_kPa);
    fprintf(fid, '  Shell diameter:          %.1f mm\n', p3.best_metrics.D_s_mm);
    fprintf(fid, '================================================================\n');

    fclose(fid);

    fprintf('\nSummary report saved to: %s\n', fullfile(folder, 'SUMMARY_REPORT.txt'));
end
