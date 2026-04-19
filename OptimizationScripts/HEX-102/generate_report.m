function generate_report()
% GENERATE_REPORT  Creates a PDF summary of all heat exchanger designs
%
% Compiles the three designs (Original, V1 Min Volume, V2 Min DP) into a
% single PDF report with key graphs highlighting design trade-offs.

    %% Setup
    report_file = fullfile(pwd, 'HEX_Design_Summary_Report.pdf');

    % Delete existing report if present
    if exist(report_file, 'file')
        delete(report_file);
    end

    fprintf('Generating Heat Exchanger Design Report...\n');

    %% Page 1: Title and Design Comparison Table
    fig1 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    % Title
    annotation('textbox', [0.1, 0.92, 0.8, 0.06], 'String', ...
        'LOOP INTERFACE EXCHANGER - DESIGN OPTIMIZATION SUMMARY', ...
        'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    annotation('textbox', [0.1, 0.88, 0.8, 0.04], 'String', ...
        sprintf('Generated: %s', datestr(now, 'dd-mmm-yyyy')), ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'EdgeColor', 'none');

    % Operating Conditions Box
    annotation('textbox', [0.05, 0.72, 0.9, 0.14], 'String', {...
        'FIXED OPERATING CONDITIONS:', ...
        '', ...
        '  Cold fluid mass flow rate:   0.25 kg/s (Helisol 5A)', ...
        '  Hot fluid mass flow rate:    0.7609 kg/s (Ternary Eutectic)', ...
        '  Cold fluid inlet temperature:  283.05 C', ...
        '  Cold fluid outlet temperature: 310 C', ...
        '  Hot fluid inlet temperature:   620 C', ...
        '  Heat duty:                     14.49 kW'}, ...
        'FontSize', 9, 'FontName', 'Courier', 'BackgroundColor', [0.95 0.95 0.95], ...
        'EdgeColor', [0.5 0.5 0.5]);

    % Design Comparison Table
    annotation('textbox', [0.05, 0.66, 0.9, 0.04], 'String', ...
        'DESIGN COMPARISON', 'FontSize', 12, 'FontWeight', 'bold', ...
        'EdgeColor', 'none');

    % Create table data
    ax_table = axes('Position', [0.05, 0.35, 0.9, 0.30]);
    axis off;

    col_headers = {'Parameter', 'Original', 'V1 (Min Vol)', 'V2 (Min DP)', 'Units'};
    table_data = {
        'Tube Length',        '1000',    '700',     '700',     'mm';
        'Shell Diameter',     '142.2',   '155.5',   '183.7',   'mm';
        'D/L Ratio',          '0.142',   '0.222',   '0.262',   '-';
        'Shell Volume',       '15.89',   '13.29',   '18.56',   'L';
        'Tube-side DP',       '627.9',   '416.5',   '147.5',   'Pa';
        'Shell-side DP',      '0.096',   '0.070',   '0.027',   'Pa';
        'Total DP',           '628.0',   '416.6',   '147.5',   'Pa';
        'Number of Tubes',    '9.3',     '14.5',    '10.6',    '-';
        'Tube Passes',        '2',       '2',       '2',       '-';
        'Tube ID',            '20',      '18',      '26',      'mm';
        'Tube OD',            '24',      '22',      '30',      'mm';
        'Pitch Ratio',        '1.25',    '1.25',    '1.25',    '-';
        'Overall HTC (U_o)',  '83.4',    '102.9',   '60.5',    'W/m2/K'
    };

    % Draw table
    n_rows = size(table_data, 1);
    n_cols = 5;
    row_height = 0.065;
    col_widths = [0.28, 0.16, 0.18, 0.18, 0.10];

    % Header row
    x_pos = 0.05;
    for c = 1:n_cols
        if c == 1
            ha = 'left';
        else
            ha = 'center';
        end
        annotation('textbox', [x_pos, 0.62, col_widths(c), 0.03], ...
            'String', col_headers{c}, 'FontSize', 9, 'FontWeight', 'bold', ...
            'HorizontalAlignment', ha, 'EdgeColor', 'none', 'BackgroundColor', [0.8 0.8 0.9]);
        x_pos = x_pos + col_widths(c);
    end

    % Data rows
    for r = 1:n_rows
        y_pos = 0.62 - r * 0.022;
        x_pos = 0.05;
        bg_color = 'w';
        if mod(r, 2) == 0
            bg_color = [0.95 0.95 0.95];
        end
        for c = 1:n_cols
            if c == 1
                ha = 'left';
            else
                ha = 'center';
            end
            annotation('textbox', [x_pos, y_pos, col_widths(c), 0.022], ...
                'String', table_data{r, c}, 'FontSize', 8, ...
                'HorizontalAlignment', ha, 'EdgeColor', 'none', 'BackgroundColor', bg_color);
            x_pos = x_pos + col_widths(c);
        end
    end

    % Design descriptions
    annotation('textbox', [0.05, 0.08, 0.9, 0.24], 'String', {...
        'DESIGN DESCRIPTIONS:', ...
        '', ...
        'Original Baseline: Starting design with 1.0m tubes and 20mm ID tubes.', ...
        '  Operates at 628 Pa pressure drop. Standard engineering approach.', ...
        '', ...
        'V1 (Minimum Volume): Optimized to minimize shell volume while meeting', ...
        '  pressure drop constraint. Uses shorter tubes (0.7m) and smaller diameter (18mm).', ...
        '  Achieved 16.4% VOLUME REDUCTION and 33.7% pressure drop reduction.', ...
        '', ...
        'V2 (Minimum Pressure Drop): Optimized to minimize tube-side pressure drop.', ...
        '  Uses larger tubes (26mm ID) for dramatically lower flow resistance.', ...
        '  Achieved 76.5% PRESSURE DROP REDUCTION with moderate volume increase.'}, ...
        'FontSize', 9, 'EdgeColor', 'none', 'VerticalAlignment', 'top');

    % Save first page
    exportgraphics(fig1, report_file, 'ContentType', 'vector', 'Append', false);
    close(fig1);
    fprintf('  Page 1: Title and comparison table\n');

    %% Page 2: V1 Study - Key Graphs (Volume Optimization)
    fig2 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'V1 OPTIMIZATION: MINIMIZING VOLUME', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load and display V1 graphs from final optimization study
    v1_folder = 'results/final_optimization_2026-04-12_16-51-22';

    % Graph 1: Parameter sensitivity
    ax1 = subplot(2, 2, 1);
    img1 = imread(fullfile(v1_folder, 'parameter_sensitivity.png'));
    imshow(img1);
    title('Parameter Sensitivity Analysis', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: Design space heatmaps
    ax2 = subplot(2, 2, 2);
    img2 = imread(fullfile(v1_folder, 'design_space_heatmaps.png'));
    imshow(img2);
    title('Design Space Heat Maps', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: Best designs comparison
    ax3 = subplot(2, 2, 3);
    img3 = imread(fullfile(v1_folder, 'best_designs_comparison.png'));
    imshow(img3);
    title('Best Designs Comparison', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: 3D design space
    ax4 = subplot(2, 2, 4);
    img4 = imread(fullfile(v1_folder, '3D_design_space.png'));
    imshow(img4);
    title('3D Design Space', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - Volume Optimization:', ...
        '  Tube internal diameter is dominant - smaller tubes allow more compact shell', ...
        '  Shorter tubes (0.7m vs 1.0m) reduce overall volume despite wider shell', ...
        '  N_p = 2 passes is essential - higher passes dramatically increase pressure drop'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.98 0.95]);

    exportgraphics(fig2, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig2);
    fprintf('  Page 2: V1 optimization graphs\n');

    %% Page 3: V2 Study - Pressure Drop Optimization
    fig3 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'V2 OPTIMIZATION: MINIMIZING PRESSURE DROP', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load graphs
    v2_folder = 'results/final_optimization_2026-04-12_16-51-22';

    % Graph 1: Pareto analysis
    ax1 = subplot(2, 2, 1);
    img1 = imread(fullfile(v2_folder, 'pareto_analysis.png'));
    imshow(img1);
    title('Pareto Front Analysis', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: From initial study - tube length passes
    study1_folder = 'results/study_2026-04-12_16-46-48';
    ax2 = subplot(2, 2, 2);
    img2 = imread(fullfile(study1_folder, 'study1_tube_length_passes.png'));
    imshow(img2);
    title('Effect of Tube Length & Passes', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: Tube diameter study
    ax3 = subplot(2, 2, 3);
    img3 = imread(fullfile(study1_folder, 'study2_tube_diameter.png'));
    imshow(img3);
    title('Effect of Tube Diameter', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: Pitch and baffle
    ax4 = subplot(2, 2, 4);
    img4 = imread(fullfile(study1_folder, 'study3_pitch_baffle.png'));
    imshow(img4);
    title('Pitch Ratio & Baffle Effects', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - Pressure Drop Optimization:', ...
        '  Tube-side pressure drop dominates (99.98% of total) - focus optimization here', ...
        '  Larger tube diameter (26mm vs 20mm) reduces DP by 76.5% with Re^2 relationship', ...
        '  Baffle parameters have negligible impact - use TEMA standard values'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.95 0.98]);

    exportgraphics(fig3, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig3);
    fprintf('  Page 3: V2 optimization graphs\n');

    %% Page 4: Final Recommendations
    fig4 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.92, 0.8, 0.05], 'String', ...
        'DESIGN RECOMMENDATIONS', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Visual comparison - bar charts
    designs = {'Original', 'V1 Min Vol', 'V2 Min DP'};

    % Shell dimensions comparison
    ax1 = axes('Position', [0.08, 0.68, 0.40, 0.20]);
    bar_data = [1000 142.2; 700 155.5; 700 183.7];
    b = bar(bar_data);
    b(1).FaceColor = [0.2 0.4 0.8];
    b(2).FaceColor = [0.8 0.4 0.2];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Dimension [mm]');
    title('Shell Dimensions', 'FontWeight', 'bold');
    legend('Length', 'Diameter', 'Location', 'northeast');
    grid on;

    % Volume comparison
    ax2 = axes('Position', [0.55, 0.68, 0.40, 0.20]);
    volumes = [15.89, 13.29, 18.56];
    b = bar(volumes);
    b.FaceColor = [0.3 0.7 0.4];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Volume [L]');
    title('Shell Volume', 'FontWeight', 'bold');
    grid on;
    % Add percentage labels
    for i = 1:3
        pct = (volumes(i) - volumes(1)) / volumes(1) * 100;
        if i == 1
            lbl = sprintf('%.1fL', volumes(i));
        else
            lbl = sprintf('%.1fL\n(%.1f%%)', volumes(i), pct);
        end
        text(i, volumes(i) + 1, lbl, 'HorizontalAlignment', 'center', 'FontSize', 8);
    end

    % Pressure drop comparison
    ax3 = axes('Position', [0.08, 0.42, 0.40, 0.20]);
    dp = [628.0, 416.6, 147.5];
    b = bar(dp);
    b.FaceColor = [0.8 0.3 0.3];
    hold on;
    yline(628, 'r--', 'Baseline', 'LineWidth', 2);
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Pressure Drop [Pa]');
    title('Total Pressure Drop', 'FontWeight', 'bold');
    grid on;

    % D/L ratio comparison
    ax4 = axes('Position', [0.55, 0.42, 0.40, 0.20]);
    dl = [0.142, 0.222, 0.262];
    b = bar(dl);
    b.FaceColor = [0.6 0.3 0.7];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('D/L Ratio');
    title('Diameter to Length Ratio', 'FontWeight', 'bold');
    grid on;

    % Recommendations text
    annotation('textbox', [0.05, 0.05, 0.9, 0.32], 'String', {...
        'RECOMMENDATIONS:', ...
        '', ...
        'Choose V1 (MINIMUM VOLUME) if:', ...
        '  - Space is limited and a smaller footprint is critical', ...
        '  - Installation constraints favor minimum exchanger volume', ...
        '  - 33.7% pressure drop reduction provides adequate margin', ...
        '  - BEST CHOICE FOR COMPACT INSTALLATIONS', ...
        '', ...
        'Choose V2 (MINIMUM PRESSURE DROP) if:', ...
        '  - Minimizing pumping power is the primary concern', ...
        '  - Maximum margin on pressure drop constraint is desired', ...
        '  - Volume increase (+16.8%) is acceptable', ...
        '  - BEST CHOICE FOR ENERGY EFFICIENCY', ...
        '', ...
        'AVOID ORIGINAL DESIGN:', ...
        '  - Operating at pressure drop limit with no safety margin', ...
        '  - Larger volume than V1 with no benefit', ...
        '', ...
        'All designs meet thermal requirements (14.49 kW heat duty) and constraints.'}, ...
        'FontSize', 9, 'EdgeColor', [0.3 0.3 0.3], 'BackgroundColor', [0.98 0.98 0.98], ...
        'VerticalAlignment', 'top');

    exportgraphics(fig4, report_file, 'ContentType', 'vector', 'Append', true);
    close(fig4);
    fprintf('  Page 4: Recommendations\n');

    %% Done
    fprintf('\nReport saved to: %s\n', report_file);
end
