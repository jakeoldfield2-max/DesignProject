function generate_parametric_report()
% GENERATE_PARAMETRIC_REPORT  Creates a PDF summary of heater parametric studies
%
% Compiles the parametric optimization studies (V2 Sensitivity, V3 Refined)
% into a single PDF report with key graphs highlighting design trade-offs.

    %% Setup
    report_file = fullfile(pwd, 'Heater_Parametric_Optimization_Report.pdf');

    % Study folders
    v2_folder = 'results_2026-04-12_16-21-39';
    v3_folder = 'results_2026-04-12_16-25-02_refined';

    % Delete existing report if present
    if exist(report_file, 'file')
        delete(report_file);
    end

    fprintf('Generating Heater Parametric Optimization Report...\n');

    % Run baseline and optimized designs to get data
    baseline = heater_design();

    params_opt = struct();
    params_opt.d_tube_ID_heat = 0.050;
    params_opt.d_tube_OD_heat = 0.060;
    params_opt.p_coil_heat = 0.1075;
    params_opt.D_coil_heat = 0.85;
    params_opt.D_shell_heat = 1.25;
    params_opt.d_tube_OD_conv = 0.035;
    params_opt.d_tube_ID_conv = 0.027;
    params_opt.p_conv_horizontal = 0.0875;
    params_opt.p_conv_vertical = 0.0875;
    params_opt.n_conv_parallel = 7;
    optimized = heater_design(params_opt);

    %% Page 1: Title and Design Comparison Table
    fig1 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    % Title
    annotation('textbox', [0.05, 0.92, 0.9, 0.06], 'String', ...
        'FIRED HEATER - PARAMETRIC OPTIMIZATION STUDY', ...
        'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    annotation('textbox', [0.05, 0.88, 0.9, 0.04], 'String', ...
        sprintf('Generated: %s | Unit: H-101 Combined Biogas/Bio-oil Heater', datestr(now, 'dd-mmm-yyyy')), ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'EdgeColor', 'none');

    % Operating Conditions Box
    annotation('textbox', [0.05, 0.72, 0.9, 0.14], 'String', {...
        'FIXED OPERATING CONDITIONS:', ...
        '', ...
        sprintf('  Heat duty to salt:         %.2f kW', baseline.Q_target_kW), ...
        sprintf('  Salt inlet temperature:    %.1f C', baseline.params.T_salt_in), ...
        sprintf('  Salt outlet temperature:   %.1f C', baseline.params.T_salt_out), ...
        sprintf('  Biogas mass flow:          %.6f kg/s', baseline.params.m_gas_factory), ...
        sprintf('  Bio-oil mass flow:         %.6f kg/s', baseline.params.m_oil), ...
        sprintf('  Heater efficiency:         %.0f%%', baseline.params.eta_heater*100)}, ...
        'FontSize', 9, 'FontName', 'Courier', 'BackgroundColor', [0.95 0.95 0.95], ...
        'EdgeColor', [0.5 0.5 0.5]);

    % Objectives
    annotation('textbox', [0.05, 0.64, 0.9, 0.06], 'String', {...
        'OPTIMIZATION OBJECTIVES:', ...
        '  1. Minimize furnace volume  2. Minimize D/H ratios (radiant & convection)  3. Keep DP < baseline'}, ...
        'FontSize', 9, 'EdgeColor', [0.3 0.5 0.7], 'BackgroundColor', [0.92 0.95 1.0]);

    % Design Comparison Table Header
    annotation('textbox', [0.05, 0.58, 0.9, 0.04], 'String', ...
        'DESIGN COMPARISON: BASELINE vs OPTIMIZED', 'FontSize', 12, 'FontWeight', 'bold', ...
        'EdgeColor', 'none');

    % Calculate metrics
    BL_H_rad = baseline.rad.H_coil_m;
    BL_D_rad = baseline.params.D_shell_heat;
    BL_V_rad = pi * (BL_D_rad/2)^2 * BL_H_rad;
    BL_DH_rad = BL_D_rad / BL_H_rad;
    BL_W_conv = baseline.conv.W_conv_m;
    BL_H_conv = baseline.conv.n_rows * baseline.params.p_conv_vertical;
    BL_V_conv = BL_W_conv^2 * BL_H_conv;
    BL_DH_conv = BL_W_conv / max(BL_H_conv, 0.01);
    BL_V_total = BL_V_rad + BL_V_conv;
    BL_H_total = BL_H_rad + BL_H_conv;

    OPT_H_rad = optimized.rad.H_coil_m;
    OPT_D_rad = optimized.params.D_shell_heat;
    OPT_V_rad = pi * (OPT_D_rad/2)^2 * OPT_H_rad;
    OPT_DH_rad = OPT_D_rad / OPT_H_rad;
    OPT_W_conv = optimized.conv.W_conv_m;
    OPT_H_conv = optimized.conv.n_rows * optimized.params.p_conv_vertical;
    OPT_V_conv = OPT_W_conv^2 * OPT_H_conv;
    OPT_DH_conv = OPT_W_conv / max(OPT_H_conv, 0.01);
    OPT_V_total = OPT_V_rad + OPT_V_conv;
    OPT_H_total = OPT_H_rad + OPT_H_conv;

    % Table data
    col_headers = {'Parameter', 'Baseline', 'Optimized', 'Change', 'Units'};
    table_data = {
        'Total Height',         sprintf('%.0f', BL_H_total*1000),    sprintf('%.0f', OPT_H_total*1000),   sprintf('%+.1f%%', (OPT_H_total-BL_H_total)/BL_H_total*100), 'mm';
        'Max Diameter',         sprintf('%.0f', BL_D_rad*1000),      sprintf('%.0f', OPT_D_rad*1000),     sprintf('%+.1f%%', (OPT_D_rad-BL_D_rad)/BL_D_rad*100), 'mm';
        'Total Volume',         sprintf('%.3f', BL_V_total),         sprintf('%.3f', OPT_V_total),        sprintf('%+.1f%%', (OPT_V_total-BL_V_total)/BL_V_total*100), 'm³';
        'D/H Radiant',          sprintf('%.3f', BL_DH_rad),          sprintf('%.3f', OPT_DH_rad),         sprintf('%+.1f%%', (OPT_DH_rad-BL_DH_rad)/BL_DH_rad*100), '-';
        'W/H Convection',       sprintf('%.2f', BL_DH_conv),         sprintf('%.2f', OPT_DH_conv),        sprintf('%+.1f%%', (OPT_DH_conv-BL_DH_conv)/BL_DH_conv*100), '-';
        'Total Pressure Drop',  sprintf('%.0f', baseline.dp.DP_total_Pa), sprintf('%.0f', optimized.dp.DP_total_Pa), sprintf('%+.1f%%', (optimized.dp.DP_total_Pa-baseline.dp.DP_total_Pa)/baseline.dp.DP_total_Pa*100), 'Pa';
        'Radiant Coil Height',  sprintf('%.0f', BL_H_rad*1000),      sprintf('%.0f', OPT_H_rad*1000),     sprintf('%+.1f%%', (OPT_H_rad-BL_H_rad)/BL_H_rad*100), 'mm';
        'Number of Turns',      sprintf('%d', baseline.rad.N_turns_int), sprintf('%d', optimized.rad.N_turns_int), '-', '-';
        'Tube ID (radiant)',    sprintf('%.0f', baseline.params.d_tube_ID_heat*1000), sprintf('%.0f', optimized.params.d_tube_ID_heat*1000), sprintf('%+.1f%%', (optimized.params.d_tube_ID_heat-baseline.params.d_tube_ID_heat)/baseline.params.d_tube_ID_heat*100), 'mm';
        'Coil Pitch',           sprintf('%.0f', baseline.params.p_coil_heat*1000), sprintf('%.1f', optimized.params.p_coil_heat*1000), sprintf('%+.1f%%', (optimized.params.p_coil_heat-baseline.params.p_coil_heat)/baseline.params.p_coil_heat*100), 'mm';
        'Conv Tube OD',         sprintf('%.0f', baseline.params.d_tube_OD_conv*1000), sprintf('%.0f', optimized.params.d_tube_OD_conv*1000), sprintf('%+.1f%%', (optimized.params.d_tube_OD_conv-baseline.params.d_tube_OD_conv)/baseline.params.d_tube_OD_conv*100), 'mm';
        'Parallel Passes',      sprintf('%d', baseline.params.n_conv_parallel), sprintf('%d', optimized.params.n_conv_parallel), sprintf('%+.0f%%', (optimized.params.n_conv_parallel-baseline.params.n_conv_parallel)/baseline.params.n_conv_parallel*100), '-'
    };

    % Draw table
    n_rows = size(table_data, 1);
    col_widths = [0.26, 0.16, 0.16, 0.14, 0.10];

    % Header row
    x_pos = 0.08;
    for c = 1:5
        if c == 1
            ha = 'left';
        else
            ha = 'center';
        end
        annotation('textbox', [x_pos, 0.54, col_widths(c), 0.025], ...
            'String', col_headers{c}, 'FontSize', 9, 'FontWeight', 'bold', ...
            'HorizontalAlignment', ha, 'EdgeColor', 'none', 'BackgroundColor', [0.7 0.8 0.9]);
        x_pos = x_pos + col_widths(c);
    end

    % Data rows
    for r = 1:n_rows
        y_pos = 0.54 - r * 0.028;
        x_pos = 0.08;
        bg_color = 'w';
        if mod(r, 2) == 0
            bg_color = [0.95 0.95 0.95];
        end
        % Highlight improved metrics in green
        change_val = str2double(strrep(strrep(table_data{r,4}, '%', ''), '+', ''));
        if ~isnan(change_val) && change_val < 0 && r <= 6
            bg_color = [0.85 0.95 0.85];  % Green for improvements
        end
        for c = 1:5
            if c == 1
                ha = 'left';
            else
                ha = 'center';
            end
            annotation('textbox', [x_pos, y_pos, col_widths(c), 0.028], ...
                'String', table_data{r, c}, 'FontSize', 8, ...
                'HorizontalAlignment', ha, 'EdgeColor', 'none', 'BackgroundColor', bg_color);
            x_pos = x_pos + col_widths(c);
        end
    end

    % Key improvements summary
    annotation('textbox', [0.05, 0.05, 0.9, 0.14], 'String', {...
        'KEY IMPROVEMENTS ACHIEVED:', ...
        '', ...
        sprintf('  D/H Radiant Ratio:     %.3f -> %.3f  (%.1f%% reduction - more slender profile)', BL_DH_rad, OPT_DH_rad, (BL_DH_rad-OPT_DH_rad)/BL_DH_rad*100), ...
        sprintf('  W/H Convection Ratio:  %.2f -> %.2f  (%.1f%% reduction - better proportions)', BL_DH_conv, OPT_DH_conv, (BL_DH_conv-OPT_DH_conv)/BL_DH_conv*100), ...
        sprintf('  Pressure Drop:         %.0f Pa -> %.0f Pa  (%.1f%% reduction)', baseline.dp.DP_total_Pa, optimized.dp.DP_total_Pa, (baseline.dp.DP_total_Pa-optimized.dp.DP_total_Pa)/baseline.dp.DP_total_Pa*100), ...
        sprintf('  Trade-off: Volume increased %.1f%% (taller furnace)', (OPT_V_total-BL_V_total)/BL_V_total*100)}, ...
        'FontSize', 9, 'EdgeColor', [0.3 0.6 0.3], 'BackgroundColor', [0.92 0.98 0.92]);

    % Save first page
    exportgraphics(fig1, report_file, 'ContentType', 'vector', 'Append', false);
    close(fig1);
    fprintf('  Page 1: Title and comparison table\n');

    %% Page 2: Sensitivity Study - Pressure Drop Focus
    fig2 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.05, 0.94, 0.9, 0.04], 'String', ...
        'SENSITIVITY ANALYSIS: PRESSURE DROP PARAMETERS', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    annotation('textbox', [0.05, 0.90, 0.9, 0.03], 'String', ...
        'Study V2: Individual parameter sweeps to identify key drivers', ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontAngle', 'italic');

    % Load and display graphs
    try
        % Graph 1: Tube ID sensitivity
        ax1 = axes('Position', [0.08, 0.52, 0.42, 0.35]);
        img1 = imread(fullfile(v2_folder, 'sensitivity_tube_ID.png'));
        imshow(img1);
        title('Tube Inner Diameter Effect', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 2: Coil Diameter sensitivity
        ax2 = axes('Position', [0.54, 0.52, 0.42, 0.35]);
        img2 = imread(fullfile(v2_folder, 'sensitivity_coil_diameter.png'));
        imshow(img2);
        title('Coil Diameter Effect', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 3: Coil Pitch sensitivity
        ax3 = axes('Position', [0.08, 0.12, 0.42, 0.35]);
        img3 = imread(fullfile(v2_folder, 'sensitivity_coil_pitch.png'));
        imshow(img3);
        title('Coil Pitch Effect', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 4: Parallel passes
        ax4 = axes('Position', [0.54, 0.12, 0.42, 0.35]);
        img4 = imread(fullfile(v2_folder, 'sensitivity_parallel_passes.png'));
        imshow(img4);
        title('Parallel Passes Effect', 'FontSize', 10, 'FontWeight', 'bold');
    catch ME
        warning('Could not load V2 images: %s', ME.message);
    end

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - SENSITIVITY STUDY:', ...
        '  • Tube ID is the DOMINANT factor for pressure drop (DP proportional to 1/D^5) - increasing from 35mm to 50mm reduces DP by ~85%', ...
        '  • Coil pitch affects height directly but has minimal DP impact - useful for controlling D/H ratio', ...
        '  • Parallel passes: more passes = lower velocity = lower DP, but diminishing returns above 6-7 passes'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.98 0.95]);

    exportgraphics(fig2, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig2);
    fprintf('  Page 2: Sensitivity study graphs\n');

    %% Page 3: D/H Ratio Optimization
    fig3 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.05, 0.94, 0.9, 0.04], 'String', ...
        'REFINED OPTIMIZATION: D/H RATIO MINIMIZATION', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    annotation('textbox', [0.05, 0.90, 0.9, 0.03], 'String', ...
        'Study V3: Targeted optimization for better furnace proportions', ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'EdgeColor', 'none', 'FontAngle', 'italic');

    try
        % Graph 1: D/H trade-offs
        ax1 = axes('Position', [0.08, 0.52, 0.42, 0.35]);
        img1 = imread(fullfile(v3_folder, 'DH_ratio_tradeoffs.png'));
        imshow(img1);
        title('D/H Ratio Trade-off Space', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 2: Coil pitch impact
        ax2 = axes('Position', [0.54, 0.52, 0.42, 0.35]);
        img2 = imread(fullfile(v3_folder, 'coil_pitch_impact.png'));
        imshow(img2);
        title('Coil Pitch Impact on D/H', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 3: Conv tube impact
        ax3 = axes('Position', [0.08, 0.12, 0.42, 0.35]);
        img3 = imread(fullfile(v3_folder, 'conv_tube_impact.png'));
        imshow(img3);
        title('Convection Tube Impact on W/H', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 4: Pareto analysis
        ax4 = axes('Position', [0.54, 0.12, 0.42, 0.35]);
        img4 = imread(fullfile(v3_folder, 'pareto_analysis.png'));
        imshow(img4);
        title('Pareto Trade-off Analysis', 'FontSize', 10, 'FontWeight', 'bold');
    catch ME
        warning('Could not load V3 images: %s', ME.message);
    end

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - D/H OPTIMIZATION:', ...
        '  • Increasing coil pitch from 60mm to 108mm reduces D/H radiant from 1.80 to 1.06 (-41%)', ...
        '  • Larger convection tubes (35mm vs 22mm) create more rows, reducing W/H from 18.0 to 5.1 (-72%)', ...
        '  • 93 configurations found that improve ALL metrics vs baseline simultaneously'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.95 0.98]);

    exportgraphics(fig3, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig3);
    fprintf('  Page 3: D/H ratio optimization graphs\n');

    %% Page 4: Combined Results and 3D Design Space
    fig4 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.05, 0.94, 0.9, 0.04], 'String', ...
        'COMBINED OPTIMIZATION RESULTS', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    try
        % Graph 1: Combined optimization results
        ax1 = axes('Position', [0.08, 0.52, 0.42, 0.38]);
        img1 = imread(fullfile(v2_folder, 'combined_optimization_results.png'));
        imshow(img1);
        title('5-Parameter Design Space', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 2: Trade-off analysis
        ax2 = axes('Position', [0.54, 0.52, 0.42, 0.38]);
        img2 = imread(fullfile(v2_folder, 'tradeoff_analysis.png'));
        imshow(img2);
        title('Multi-Objective Trade-offs', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 3: Summary comparison
        ax3 = axes('Position', [0.08, 0.12, 0.42, 0.35]);
        img3 = imread(fullfile(v3_folder, 'optimization_summary_plot.png'));
        imshow(img3);
        title('Optimization Summary', 'FontSize', 10, 'FontWeight', 'bold');

        % Graph 4: Good designs parameters
        ax4 = axes('Position', [0.54, 0.12, 0.42, 0.35]);
        img4 = imread(fullfile(v3_folder, 'good_designs_parameters.png'));
        imshow(img4);
        title('Parameter Distribution (Good Designs)', 'FontSize', 10, 'FontWeight', 'bold');
    catch ME
        warning('Could not load combined images: %s', ME.message);
    end

    % Summary text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'OPTIMIZATION SUMMARY:', ...
        '  • Total configurations evaluated: 1,536 across two studies', ...
        '  • Best designs cluster around: Tube ID 45-50mm, Coil Pitch 100-120mm, Conv Tube 30-35mm, 5-7 parallel passes', ...
        '  • Clear Pareto frontier identified between volume and D/H ratios'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.98 0.98 0.95]);

    exportgraphics(fig4, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig4);
    fprintf('  Page 4: Combined optimization results\n');

    %% Page 5: Final Recommendations
    fig5 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.05, 0.92, 0.9, 0.05], 'String', ...
        'FINAL DESIGN RECOMMENDATIONS', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Visual comparison - bar charts
    designs = {'Baseline', 'Optimized'};

    % Furnace dimensions comparison
    ax1 = axes('Position', [0.08, 0.68, 0.40, 0.20]);
    bar_data = [BL_H_total*1000 BL_D_rad*1000; OPT_H_total*1000 OPT_D_rad*1000];
    b = bar(bar_data);
    b(1).FaceColor = [0.2 0.4 0.8];
    b(2).FaceColor = [0.8 0.4 0.2];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Dimension [mm]');
    title('Furnace Dimensions', 'FontWeight', 'bold');
    legend('Height', 'Diameter', 'Location', 'northeast');
    grid on;

    % D/H ratio comparison
    ax2 = axes('Position', [0.55, 0.68, 0.40, 0.20]);
    dh_data = [BL_DH_rad BL_DH_conv; OPT_DH_rad OPT_DH_conv];
    b = bar(dh_data);
    b(1).FaceColor = [0.3 0.7 0.4];
    b(2).FaceColor = [0.7 0.3 0.6];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Ratio');
    title('D/H Ratios (Lower = Better)', 'FontWeight', 'bold');
    legend('Radiant D/H', 'Conv W/H', 'Location', 'northeast');
    grid on;

    % Volume comparison
    ax3 = axes('Position', [0.08, 0.42, 0.40, 0.20]);
    volumes = [BL_V_total, OPT_V_total];
    b = bar(volumes);
    b.FaceColor = [0.5 0.5 0.8];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Volume [m³]');
    title('Total Furnace Volume', 'FontWeight', 'bold');
    grid on;
    for i = 1:2
        text(i, volumes(i) + 0.05, sprintf('%.2f m³', volumes(i)), 'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    % Pressure drop comparison
    ax4 = axes('Position', [0.55, 0.42, 0.40, 0.20]);
    dp = [baseline.dp.DP_total_Pa/1000, optimized.dp.DP_total_Pa/1000];
    b = bar(dp);
    b.FaceColor = [0.8 0.3 0.3];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Pressure Drop [kPa]');
    title('Salt-Side Pressure Drop', 'FontWeight', 'bold');
    grid on;
    for i = 1:2
        text(i, dp(i) + 1, sprintf('%.1f kPa', dp(i)), 'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    % Recommendations text
    annotation('textbox', [0.05, 0.05, 0.9, 0.32], 'String', {...
        'RECOMMENDED OPTIMIZED DESIGN PARAMETERS:', ...
        '', ...
        '  RADIANT ZONE:', ...
        sprintf('    Tube ID / OD:        50 mm / 60 mm (was 35 / 45 mm)'), ...
        sprintf('    Coil Pitch:          107.5 mm (was 60 mm)'), ...
        sprintf('    Coil Diameter:       0.85 m (was 1.0 m)'), ...
        sprintf('    Shell Diameter:      1.25 m (was 1.4 m)'), ...
        '', ...
        '  CONVECTION ZONE:', ...
        sprintf('    Tube OD / ID:        35 mm / 27 mm (was 22 / 14 mm)'), ...
        sprintf('    Parallel Passes:     7 (was 4)'), ...
        '', ...
        '  BENEFITS:', ...
        '    - 87% reduction in pressure drop (49.4 kPa -> 6.4 kPa)', ...
        '    - 41% reduction in radiant D/H ratio (better proportions)', ...
        '    - 72% reduction in convection W/H ratio', ...
        '    - Trade-off: 27% increase in total volume (taller, narrower furnace)'}, ...
        'FontSize', 9, 'FontName', 'Courier', 'EdgeColor', [0.3 0.3 0.3], ...
        'BackgroundColor', [0.98 0.98 0.98], 'VerticalAlignment', 'top');

    exportgraphics(fig5, report_file, 'ContentType', 'vector', 'Append', true);
    close(fig5);
    fprintf('  Page 5: Final recommendations\n');

    %% Done
    fprintf('\n========================================\n');
    fprintf('Report saved to: %s\n', report_file);
    fprintf('========================================\n');
end
