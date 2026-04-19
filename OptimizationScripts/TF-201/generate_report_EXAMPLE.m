function generate_report()
% GENERATE_REPORT  Creates a PDF summary of all heat exchanger designs
%
% Compiles the three designs (Original, V1 Min DP, V2 Compact) into a
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
        'AIR HEAT EXCHANGER - DESIGN OPTIMIZATION SUMMARY', ...
        'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    annotation('textbox', [0.1, 0.88, 0.8, 0.04], 'String', ...
        sprintf('Generated: %s', datestr(now, 'dd-mmm-yyyy')), ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'EdgeColor', 'none');

    % Operating Conditions Box
    annotation('textbox', [0.05, 0.72, 0.9, 0.14], 'String', {...
        'FIXED OPERATING CONDITIONS:', ...
        '', ...
        '  Air mass flow rate:      0.0570722222 kg/s', ...
        '  Hot fluid mass flow:     0.25 kg/s (Helisol 5A)', ...
        '  Air inlet temperature:   25°C', ...
        '  Air outlet temperature:  280°C', ...
        '  Salt inlet temperature:  330°C', ...
        '  Heat duty:               14.76 kW'}, ...
        'FontSize', 9, 'FontName', 'Courier', 'BackgroundColor', [0.95 0.95 0.95], ...
        'EdgeColor', [0.5 0.5 0.5]);

    % Design Comparison Table
    annotation('textbox', [0.05, 0.66, 0.9, 0.04], 'String', ...
        'DESIGN COMPARISON', 'FontSize', 12, 'FontWeight', 'bold', ...
        'EdgeColor', 'none');

    % Create table data
    ax_table = axes('Position', [0.05, 0.35, 0.9, 0.30]);
    axis off;

    col_headers = {'Parameter', 'Original', 'V1 (Min DP)', 'V2 (Compact)', 'Units'};
    table_data = {
        'Shell Length',      '2000',   '3000',   '1750',   'mm';
        'Shell Diameter',    '238',    '189',    '211',    'mm';
        'L/D Ratio',         '8.4',    '15.9',   '8.3',    '-';
        'Shell Volume',      '~89',    '~84',    '61.4',   'L';
        'Tube-side DP',      '7.00',   '0.24',   '0.51',   'kPa';
        'Shell-side DP',     '0.068',  '0.049',  '0.054',  'Pa';
        'Number of Tubes',   '24',     '14',     '12',     '-';
        'Tube Passes',       '4',      '2',      '2',      '-';
        'Tube ID',           '10',     '18',     '15',     'mm';
        'Tube OD',           '14',     '20',     '18',     'mm';
        'Fin Height',        '8',      '5',      '10',     'mm';
        'Fin Pitch',         '3.0',    '2.0',    '2.0',    'mm';
        'Overall HTC',       '6.38',   '4.77',   '4.22',   'W/m²/K'
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
        'Original Baseline: The starting design with 4 tube passes and 10mm ID tubes.', ...
        '  Pressure drop at the 7 kPa limit. Standard engineering approach.', ...
        '', ...
        'V1 (Minimum Pressure Drop): Optimized primarily to minimize tube-side pressure', ...
        '  drop. Uses larger tubes (18mm ID) and fewer passes (2). Longer but narrower shell.', ...
        '  Achieved 97% reduction in pressure drop.', ...
        '', ...
        'V2 (Compact Design): Optimized to minimize shell volume while meeting all pressure', ...
        '  constraints. Balances length and diameter for smallest overall footprint.', ...
        '  Achieved 31% volume reduction vs original.'}, ...
        'FontSize', 9, 'EdgeColor', 'none', 'VerticalAlignment', 'top');

    % Save first page
    exportgraphics(fig1, report_file, 'ContentType', 'vector', 'Append', false);
    close(fig1);
    fprintf('  Page 1: Title and comparison table\n');

    %% Page 2: V1 Study - Key Graphs
    fig2 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'V1 OPTIMIZATION: MINIMIZING PRESSURE DROP', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load and display V1 graphs
    v1_folder = 'results/study_2026-04-12_15-26-13';

    % Graph 1: DP vs D_int
    ax1 = subplot(2, 2, 1);
    img1 = imread(fullfile(v1_folder, 'phase1_DP_vs_Dint.png'));
    imshow(img1);
    title('Effect of Tube Diameter', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: DP vs N_p
    ax2 = subplot(2, 2, 2);
    img2 = imread(fullfile(v1_folder, 'phase1_DP_vs_Np.png'));
    imshow(img2);
    title('Effect of Tube Passes', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: Pareto
    ax3 = subplot(2, 2, 3);
    img3 = imread(fullfile(v1_folder, 'phase1_pareto.png'));
    imshow(img3);
    title('Phase 1 Trade-off Space', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: Summary
    ax4 = subplot(2, 2, 4);
    img4 = imread(fullfile(v1_folder, 'summary_comparison.png'));
    imshow(img4);
    title('Optimization Progress', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - V1:', ...
        '• Tube internal diameter is the dominant factor - increasing from 10mm to 18mm reduced DP by 97%', ...
        '• Number of passes has near-linear effect on pressure drop - 2 passes vs 4 passes cuts DP by ~75%', ...
        '• Trade-off: Longer shell (3m) required to compensate for fewer, larger tubes'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.98 0.95]);

    exportgraphics(fig2, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig2);
    fprintf('  Page 2: V1 optimization graphs\n');

    %% Page 3: V2 Study - Key Graphs
    fig3 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'V2 OPTIMIZATION: COMPACT DESIGN (MINIMUM VOLUME)', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load and display V2 graphs
    v2_folder = 'results/study_v2_2026-04-12_15-42-31';

    % Graph 1: Shell size tradeoff
    ax1 = subplot(2, 2, 1);
    img1 = imread(fullfile(v2_folder, 'shell_size_tradeoff.png'));
    imshow(img1);
    title('Shell Size Trade-off', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: L/D ratio
    ax2 = subplot(2, 2, 2);
    img2 = imread(fullfile(v2_folder, 'LD_ratio_vs_DP.png'));
    imshow(img2);
    title('Aspect Ratio vs Pressure Drop', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: 3D design space
    ax3 = subplot(2, 2, 3);
    img3 = imread(fullfile(v2_folder, '3D_design_space.png'));
    imshow(img3);
    title('3D Design Space', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: Top 10
    ax4 = subplot(2, 2, 4);
    img4 = imread(fullfile(v2_folder, 'top10_comparison.png'));
    imshow(img4);
    title('Top 10 Compact Designs', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - V2:', ...
        '• Clear trade-off between shell length and diameter - shorter shells require wider diameter', ...
        '• Pareto front shows minimum achievable L/D ratio of ~5.5 (at 1500mm length)', ...
        '• Optimal compact design: 1750mm x 211mm achieves 31% volume reduction while meeting all constraints'}, ...
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
    designs = {'Original', 'V1 Min DP', 'V2 Compact'};

    % Shell dimensions comparison
    ax1 = axes('Position', [0.08, 0.68, 0.40, 0.20]);
    bar_data = [2000 238; 3000 189; 1750 211];
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
    volumes = [89, 84, 61.4];
    b = bar(volumes);
    b.FaceColor = [0.3 0.7 0.4];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Volume [L]');
    title('Shell Volume', 'FontWeight', 'bold');
    grid on;
    % Add percentage labels
    for i = 1:3
        text(i, volumes(i) + 3, sprintf('%.0fL', volumes(i)), 'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    % Pressure drop comparison
    ax3 = axes('Position', [0.08, 0.42, 0.40, 0.20]);
    dp = [7.0, 0.24, 0.51];
    b = bar(dp);
    b.FaceColor = [0.8 0.3 0.3];
    hold on;
    yline(7, 'r--', 'LineWidth', 2);
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Pressure Drop [kPa]');
    title('Tube-side Pressure Drop', 'FontWeight', 'bold');
    grid on;

    % L/D ratio comparison
    ax4 = axes('Position', [0.55, 0.42, 0.40, 0.20]);
    ld = [8.4, 15.9, 8.3];
    b = bar(ld);
    b.FaceColor = [0.6 0.3 0.7];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('L/D Ratio');
    title('Aspect Ratio', 'FontWeight', 'bold');
    grid on;

    % Recommendations text
    annotation('textbox', [0.05, 0.05, 0.9, 0.32], 'String', {...
        'RECOMMENDATIONS:', ...
        '', ...
        'Choose V2 COMPACT DESIGN if:', ...
        '  • Space is limited and a smaller footprint is critical', ...
        '  • Installation constraints favor a shorter exchanger', ...
        '  • The slightly higher pressure drop (0.51 kPa) is acceptable', ...
        '', ...
        'Choose V1 MIN DP DESIGN if:', ...
        '  • Minimizing pumping power is the primary concern', ...
        '  • A longer, narrower exchanger fits the installation space', ...
        '  • Maximum margin on pressure drop constraint is desired', ...
        '', ...
        'AVOID ORIGINAL DESIGN:', ...
        '  • Operating at the pressure drop limit with no safety margin', ...
        '  • Larger volume than necessary', ...
        '', ...
        'All optimized designs meet the thermal requirements (280°C air outlet) and', ...
        'pressure constraints (DP_t < 7 kPa, DP_s < 0.068 Pa).'}, ...
        'FontSize', 9, 'EdgeColor', [0.3 0.3 0.3], 'BackgroundColor', [0.98 0.98 0.98], ...
        'VerticalAlignment', 'top');

    exportgraphics(fig4, report_file, 'ContentType', 'vector', 'Append', true);
    close(fig4);
    fprintf('  Page 4: Recommendations\n');

    %% Done
    fprintf('\nReport saved to: %s\n', report_file);
end
