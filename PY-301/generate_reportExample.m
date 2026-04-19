function generate_report()
% GENERATE_REPORT  Creates a PDF summary of screw separator cooling jacket designs
%
% Compiles the three designs (Original, V1 Balanced, V2 Min DP) into a
% single PDF report with key graphs highlighting design trade-offs.

    %% Setup
    report_file = fullfile(pwd, 'Cooling_Jacket_Design_Report.pdf');

    % Delete existing report if present
    if exist(report_file, 'file')
        delete(report_file);
    end

    fprintf('Generating Screw Separator Cooling Jacket Design Report...\n');

    %% Page 1: Title and Design Comparison Table
    fig1 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    % Title
    annotation('textbox', [0.1, 0.92, 0.8, 0.06], 'String', ...
        'SCREW SEPARATOR COOLING JACKET - DESIGN OPTIMIZATION SUMMARY', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    annotation('textbox', [0.1, 0.88, 0.8, 0.04], 'String', ...
        sprintf('Generated: %s | Project: SC-401', datestr(now, 'dd-mmm-yyyy')), ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'EdgeColor', 'none');

    % Operating Conditions Box
    annotation('textbox', [0.05, 0.70, 0.9, 0.16], 'String', {...
        'FIXED OPERATING CONDITIONS:', ...
        '', ...
        '  Coolant mass flow rate:    0.25 kg/s (Helisol 5A)', ...
        '  Screw conveyor length:     1.2 m', ...
        '  Separator diameter:        101.6 mm', ...
        '  Coolant inlet temperature: 281 C', ...
        '  Wall inlet temperature:    500 C', ...
        '  Wall outlet temperature:   285 C', ...
        '  Required heat extraction:  1100 W'}, ...
        'FontSize', 9, 'FontName', 'Courier', 'BackgroundColor', [0.95 0.95 0.95], ...
        'EdgeColor', [0.5 0.5 0.5]);

    % Design Comparison Table
    annotation('textbox', [0.05, 0.64, 0.9, 0.04], 'String', ...
        'DESIGN COMPARISON', 'FontSize', 12, 'FontWeight', 'bold', ...
        'EdgeColor', 'none');

    % Create table data
    ax_table = axes('Position', [0.05, 0.35, 0.9, 0.28]);
    axis off;

    col_headers = {'Parameter', 'Original', 'V1 (Balanced)', 'V2 (Min DP)', 'Units'};
    table_data = {
        'GAP (Annular Gap)',     '10.0',   '22.0',   '25.0',   'mm';
        'w (Channel Width)',     '30.0',   '55.0',   '65.0',   'mm';
        't_wall (Wall Thick.)',  '20.0',   '15.0',   '18.0',   'mm';
        'Pitch (w + t_wall)',    '50.0',   '70.0',   '83.0',   'mm';
        'Pressure Drop',         '36.38',  '0.96',   '0.41',   'kPa';
        'DP Reduction',          '-',      '97.4',   '98.9',   '%';
        'Heat Transfer Coeff',   '1288.6', '375.7',  '289.7',  'W/(m2K)';
        'Reynolds Number',       '30488',  '15838',  '13550',  '-';
        'Velocity',              '1.21',   '0.30',   '0.22',   'm/s';
        'Number of Turns',       '24.0',   '17.1',   '14.5',   '-';
        'Coil Length',           '7.75',   '5.50',   '4.66',   'm';
        'Safety Factor (A_av/A_req)', '23.9', '7.0', '5.4',    '-'
    };

    % Draw table
    n_rows = size(table_data, 1);
    n_cols = 5;
    col_widths = [0.30, 0.15, 0.17, 0.17, 0.11];

    % Header row
    x_pos = 0.05;
    for c = 1:n_cols
        if c == 1
            ha = 'left';
        else
            ha = 'center';
        end
        annotation('textbox', [x_pos, 0.60, col_widths(c), 0.03], ...
            'String', col_headers{c}, 'FontSize', 9, 'FontWeight', 'bold', ...
            'HorizontalAlignment', ha, 'EdgeColor', 'none', 'BackgroundColor', [0.8 0.8 0.9]);
        x_pos = x_pos + col_widths(c);
    end

    % Data rows
    for r = 1:n_rows
        y_pos = 0.60 - r * 0.022;
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
    annotation('textbox', [0.05, 0.06, 0.9, 0.26], 'String', {...
        'DESIGN DESCRIPTIONS:', ...
        '', ...
        'Original Baseline: Starting design with GAP=10mm, w=30mm, t_wall=20mm.', ...
        '  Pressure drop at 36.38 kPa. Standard helical cooling jacket configuration.', ...
        '', ...
        'V1 (Balanced Design): Optimized to reduce pressure drop while maintaining', ...
        '  good heat transfer. GAP=22mm, w=55mm, t_wall=15mm.', ...
        '  Achieved 97.4% DP reduction with safety factor of 7.0x.', ...
        '', ...
        'V2 (Minimum Pressure Drop): Optimized primarily to minimize pressure drop.', ...
        '  GAP=25mm, w=65mm, t_wall=18mm. Larger channels and annular gap.', ...
        '  Achieved 98.9% DP reduction (36.38 kPa -> 0.41 kPa).'}, ...
        'FontSize', 9, 'EdgeColor', 'none', 'VerticalAlignment', 'top');

    % Save first page
    exportgraphics(fig1, report_file, 'ContentType', 'vector', 'Append', false);
    close(fig1);
    fprintf('  Page 1: Title and comparison table\n');

    %% Page 2: Study 1 - Key Graphs
    fig2 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'STUDY 1: SINGLE PARAMETER SWEEPS & INITIAL OPTIMIZATION', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load and display Study 1 graphs
    study1_folder = 'results/Study_2026-04-12_16-51-02';

    % Graph 1: Single Parameter Sweeps
    ax1 = subplot(2, 2, 1);
    try
        img1 = imread(fullfile(study1_folder, 'Study1_SingleParameterSweeps.png'));
        imshow(img1);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('Single Parameter Sweeps', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: GAP vs Channel Width
    ax2 = subplot(2, 2, 2);
    try
        img2 = imread(fullfile(study1_folder, 'Study2_GAP_vs_ChannelWidth.png'));
        imshow(img2);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('GAP vs Channel Width Contour', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: GAP vs Wall Thickness
    ax3 = subplot(2, 2, 3);
    try
        img3 = imread(fullfile(study1_folder, 'Study3_GAP_vs_WallThickness.png'));
        imshow(img3);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('GAP vs Wall Thickness Contour', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: Comparison
    ax4 = subplot(2, 2, 4);
    try
        img4 = imread(fullfile(study1_folder, 'Study5_Comparison.png'));
        imshow(img4);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('Baseline vs Optimized', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - STUDY 1:', ...
        '  GAP is the dominant parameter - increasing from 10mm to 22mm reduced DP by 97%', ...
        '  Pressure drop scales with velocity squared (v^2) - larger channels dramatically reduce losses', ...
        '  Trade-off: Higher GAP and w reduce heat transfer coefficient (h_j) but design remains valid'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.98 0.95]);

    exportgraphics(fig2, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig2);
    fprintf('  Page 2: Study 1 optimization graphs\n');

    %% Page 3: Refined Study - Key Graphs
    fig3 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'STUDY 2: REFINED OPTIMIZATION & PARETO ANALYSIS', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load and display Refined Study graphs
    refined_folder = 'results/Refined_Study_2026-04-12_16-53-11';

    % Graph 1: Pareto Front
    ax1 = subplot(2, 2, 1);
    try
        img1 = imread(fullfile(refined_folder, 'StudyAB_ParetoFront.png'));
        imshow(img1);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('Pareto Front: DP vs h_j Trade-off', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: Heat Transfer Targets
    ax2 = subplot(2, 2, 2);
    try
        img2 = imread(fullfile(refined_folder, 'StudyC_HeatTransferTargets.png'));
        imshow(img2);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('h_j Constrained Optimization', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: Response Surfaces
    ax3 = subplot(2, 2, 3);
    try
        img3 = imread(fullfile(refined_folder, 'StudyD_ResponseSurfaces.png'));
        imshow(img3);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('3D Response Surfaces', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: Final Comparison
    ax4 = subplot(2, 2, 4);
    try
        img4 = imread(fullfile(refined_folder, 'Final_Comparison.png'));
        imshow(img4);
    catch
        text(0.5, 0.5, 'Image not found', 'HorizontalAlignment', 'center');
    end
    title('Multi-Configuration Comparison', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - STUDY 2 (REFINED):', ...
        '  Pareto front shows clear trade-off between pressure drop and heat transfer coefficient', ...
        '  Minimum DP of 0.41 kPa achieved at GAP=25mm, w=65mm, t_wall=18mm', ...
        '  All Pareto-optimal designs maintain safety factor > 5x (design valid)'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.95 0.98]);

    exportgraphics(fig3, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig3);
    fprintf('  Page 3: Refined study graphs\n');

    %% Page 4: Final Recommendations
    fig4 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.92, 0.8, 0.05], 'String', ...
        'DESIGN RECOMMENDATIONS', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Visual comparison - bar charts
    designs = {'Original', 'V1 Balanced', 'V2 Min DP'};

    % Geometry comparison
    ax1 = axes('Position', [0.08, 0.68, 0.40, 0.20]);
    bar_data = [10 30 20; 22 55 15; 25 65 18];
    b = bar(bar_data);
    b(1).FaceColor = [0.2 0.4 0.8];
    b(2).FaceColor = [0.8 0.4 0.2];
    b(3).FaceColor = [0.4 0.7 0.4];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Dimension [mm]');
    title('Geometry Parameters', 'FontWeight', 'bold');
    legend('GAP', 'w', 't_{wall}', 'Location', 'northwest');
    grid on;

    % Pressure drop comparison
    ax2 = axes('Position', [0.55, 0.68, 0.40, 0.20]);
    dp = [36.38, 0.96, 0.41];
    b = bar(dp);
    b.FaceColor = [0.8 0.3 0.3];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Pressure Drop [kPa]');
    title('Pressure Drop', 'FontWeight', 'bold');
    grid on;
    % Add percentage labels
    for i = 2:3
        pct = (1 - dp(i)/dp(1)) * 100;
        text(i, dp(i) + 2, sprintf('-%.1f%%', pct), 'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
    end

    % Heat transfer coefficient comparison
    ax3 = axes('Position', [0.08, 0.42, 0.40, 0.20]);
    hj = [1288.6, 375.7, 289.7];
    b = bar(hj);
    b.FaceColor = [0.3 0.5 0.8];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('h_j [W/(m^2K)]');
    title('Heat Transfer Coefficient', 'FontWeight', 'bold');
    grid on;

    % Safety factor comparison
    ax4 = axes('Position', [0.55, 0.42, 0.40, 0.20]);
    sf = [23.9, 7.0, 5.4];
    b = bar(sf);
    b.FaceColor = [0.4 0.7 0.4];
    hold on;
    yline(1, 'r--', 'Minimum', 'LineWidth', 2);
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('A_{av} / A_{req}');
    title('Safety Factor', 'FontWeight', 'bold');
    grid on;

    % Recommendations text
    annotation('textbox', [0.05, 0.05, 0.9, 0.32], 'String', {...
        'RECOMMENDATIONS:', ...
        '', ...
        'Choose V1 BALANCED DESIGN (Recommended) if:', ...
        '  - Good balance between low pressure drop and heat transfer is needed', ...
        '  - Comfortable safety margin (7x) is preferred', ...
        '  - Moderate jacket dimensions are acceptable', ...
        '', ...
        'Choose V2 MIN DP DESIGN if:', ...
        '  - Minimizing pumping power is the primary concern', ...
        '  - System can accommodate larger jacket dimensions', ...
        '  - Lower heat transfer coefficient (289.7 W/m2K) is acceptable', ...
        '', ...
        'AVOID ORIGINAL DESIGN:', ...
        '  - Excessively high pressure drop (36.38 kPa)', ...
        '  - No benefit from oversized heat transfer coefficient', ...
        '', ...
        'All optimized designs meet thermal requirements (Q_req = 1100 W) with', ...
        'safety factors well above 1.0, ensuring robust heat transfer performance.'}, ...
        'FontSize', 9, 'EdgeColor', [0.3 0.3 0.3], 'BackgroundColor', [0.98 0.98 0.98], ...
        'VerticalAlignment', 'top');

    exportgraphics(fig4, report_file, 'ContentType', 'vector', 'Append', true);
    close(fig4);
    fprintf('  Page 4: Recommendations\n');

    %% Done
    fprintf('\nReport saved to: %s\n', report_file);
end
