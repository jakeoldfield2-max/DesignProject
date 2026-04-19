function generate_report()
% GENERATE_REPORT  Creates a PDF summary of torrefaction heating jacket designs
%
% Compiles the parametric study results (Baseline, Initial Study, Extended
% Optimization) into a single PDF report with key graphs highlighting
% design trade-offs for pressure drop minimization.

    %% Setup
    report_file = fullfile(pwd, 'TF201_Heating_Jacket_Optimization_Report.pdf');

    % Delete existing report if present
    if exist(report_file, 'file')
        delete(report_file);
    end

    fprintf('Generating Torrefaction Heating Jacket Design Report...\n');

    %% Page 1: Title and Design Comparison Table
    fig1 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    % Title
    annotation('textbox', [0.1, 0.92, 0.8, 0.06], 'String', ...
        'TF-201 HEATING JACKET - PRESSURE DROP OPTIMIZATION', ...
        'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    annotation('textbox', [0.1, 0.88, 0.8, 0.04], 'String', ...
        sprintf('Generated: %s', datestr(now, 'dd-mmm-yyyy')), ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'EdgeColor', 'none');

    % Operating Conditions Box
    annotation('textbox', [0.05, 0.70, 0.9, 0.16], 'String', {...
        'FIXED OPERATING CONDITIONS:', ...
        '', ...
        '  Pyrolizer diameter:       0.50 m (500 mm)', ...
        '  Pyrolizer length:         4.20 m', ...
        '  HTF mass flow rate:       0.25 kg/s (Helisol 5A)', ...
        '  HTF inlet temperature:    302°C (575.2 K)', ...
        '  Wall temperature:         280°C (553.2 K)', ...
        '  Required heat duty:       11.29 kW', ...
        '  Fanning friction factor:  0.009'}, ...
        'FontSize', 9, 'FontName', 'Courier', 'BackgroundColor', [0.95 0.95 0.95], ...
        'EdgeColor', [0.5 0.5 0.5]);

    % Design Comparison Table
    annotation('textbox', [0.05, 0.64, 0.9, 0.04], 'String', ...
        'DESIGN COMPARISON', 'FontSize', 12, 'FontWeight', 'bold', ...
        'EdgeColor', 'none');

    % Create table data
    ax_table = axes('Position', [0.05, 0.35, 0.9, 0.28]);
    axis off;

    col_headers = {'Parameter', 'Baseline', 'Initial Best', 'Extended Best', 'Units'};
    table_data = {
        'Jacket Diameter',     '530',    '528',    '552',    'mm';
        'Channel Width (w)',   '50',     '118',    '62',     'mm';
        'Rib Thickness (t)',   '50',     '100',    '330',    'mm';
        'Pitch (w + t)',       '100',    '218',    '392',    'mm';
        'Number of Turns',     '42',     '19',     '11',     '-';
        'Annular Gap',         '15',     '14',     '26',     'mm';
        'Hydraulic Diameter',  '23',     '25',     '37',     'mm';
        'Fluid Velocity',      '0.97',   '0.43',   '0.22',   'm/s';
        'Coil Length',         '54.2',   '31.0',   '17.8',   'm';
        'Pressure Drop',       '8.56',   '0.80',   '0.31',   'kPa';
        'DP Reduction',        '-',      '90.7%',  '96.4%',  '-';
        'Design Valid',        'Yes',    'Yes',    'Yes',    '-'
    };

    % Draw table
    n_rows = size(table_data, 1);
    n_cols = 5;
    col_widths = [0.30, 0.15, 0.17, 0.18, 0.10];

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
        % Highlight pressure drop row
        if r == 10
            bg_color = [0.9 1.0 0.9];
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
        'Baseline Design: Original configuration with 5cm channel width and 5cm rib thickness.', ...
        '  Pressure drop (8.56 kPa) exceeds the 8.5 kPa design limit. High number of helical', ...
        '  turns (42) results in long coil path and high pressure losses.', ...
        '', ...
        'Initial Best (Study 3): Optimized by increasing channel width to 11.8 cm and rib', ...
        '  thickness to 10 cm. Reduces turns to 19 and achieves 90.7% pressure drop reduction.', ...
        '  Increased pitch reduces total coil length.', ...
        '', ...
        'Extended Best: Further optimization with 33 cm rib thickness dramatically reduces', ...
        '  the number of turns to only 11. Achieves 96.4% pressure drop reduction to 0.31 kPa.', ...
        '  Most aggressive design with lowest pumping requirements.'}, ...
        'FontSize', 9, 'EdgeColor', 'none', 'VerticalAlignment', 'top');

    % Save first page
    exportgraphics(fig1, report_file, 'ContentType', 'vector', 'Append', false);
    close(fig1);
    fprintf('  Page 1: Title and comparison table\n');

    %% Page 2: Initial Parametric Study - Key Graphs
    fig2 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'INITIAL PARAMETRIC STUDY: D_{jacket}, w, t OPTIMIZATION', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load and display initial study graphs
    initial_folder = 'results_2026-04-12_15-53-13';

    % Graph 1: D_jacket vs w
    ax1 = subplot(2, 2, 1);
    img1 = imread(fullfile(initial_folder, 'study1_Djacket_vs_w.png'));
    imshow(img1);
    title('D_{jacket} vs Channel Width', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: D_jacket vs t
    ax2 = subplot(2, 2, 2);
    img2 = imread(fullfile(initial_folder, 'study2_Djacket_vs_t.png'));
    imshow(img2);
    title('D_{jacket} vs Rib Thickness', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: w vs t
    ax3 = subplot(2, 2, 3);
    img3 = imread(fullfile(initial_folder, 'study3_w_vs_t.png'));
    imshow(img3);
    title('Channel Width vs Rib Thickness', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: Comparison
    ax4 = subplot(2, 2, 4);
    img4 = imread(fullfile(initial_folder, 'comparison_bar_chart.png'));
    imshow(img4);
    title('Design Comparison', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - INITIAL STUDY:', ...
        '  Increasing channel width (w) dramatically reduces pressure drop by increasing flow area and hydraulic diameter', ...
        '  Larger jacket diameter has secondary effect - increases annular gap and flow cross-section', ...
        '  Rib thickness (t) shows potential for further optimization - optimal was at edge of search range (10 cm)'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.98 0.95]);

    exportgraphics(fig2, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig2);
    fprintf('  Page 2: Initial parametric study graphs\n');

    %% Page 3: Enhanced Optimization - Key Graphs
    fig3 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'ENHANCED OPTIMIZATION: EXTENDED PARAMETER RANGES', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load and display enhanced study graphs
    enhanced_folder = 'results_enhanced_2026-04-12_15-56-36';

    % Graph 1: Extended w vs t contour
    ax1 = subplot(2, 2, 1);
    img1 = imread(fullfile(enhanced_folder, 'extended_w_vs_t_contour.png'));
    imshow(img1);
    title('Extended w vs t Search', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 2: DP vs turns
    ax2 = subplot(2, 2, 2);
    img2 = imread(fullfile(enhanced_folder, 'DP_vs_turns.png'));
    imshow(img2);
    title('Pressure Drop vs Number of Turns', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 3: Pareto analysis
    ax3 = subplot(2, 2, 3);
    img3 = imread(fullfile(enhanced_folder, 'pareto_analysis.png'));
    imshow(img3);
    title('Pareto Analysis', 'FontSize', 10, 'FontWeight', 'bold');

    % Graph 4: Final comparison
    ax4 = subplot(2, 2, 4);
    img4 = imread(fullfile(enhanced_folder, 'final_comparison.png'));
    imshow(img4);
    title('Final Optimization Comparison', 'FontSize', 10, 'FontWeight', 'bold');

    % Key findings text
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'KEY FINDINGS - ENHANCED STUDY:', ...
        '  RIB THICKNESS (t) is the dominant parameter - increasing to 33 cm reduces turns from 42 to 11', ...
        '  Fewer helical turns directly reduces total coil length, which scales linearly with pressure drop', ...
        '  Lower fluid velocity (0.22 m/s vs 0.97 m/s) further reduces DP since it scales with velocity squared'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [0.95 0.95 0.98]);

    exportgraphics(fig3, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig3);
    fprintf('  Page 3: Enhanced optimization graphs\n');

    %% Page 4: Physical Analysis
    fig4 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.94, 0.8, 0.04], 'String', ...
        'PHYSICAL ANALYSIS: UNDERSTANDING THE OPTIMIZATION', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Load sensitivity and validity graphs
    ax1 = subplot(2, 2, 1);
    img1 = imread(fullfile(initial_folder, 'study5_sensitivity.png'));
    imshow(img1);
    title('Parameter Sensitivity Analysis', 'FontSize', 10, 'FontWeight', 'bold');

    ax2 = subplot(2, 2, 2);
    img2 = imread(fullfile(initial_folder, 'design_validity_map.png'));
    imshow(img2);
    title('Design Space Validity', 'FontSize', 10, 'FontWeight', 'bold');

    ax3 = subplot(2, 2, 3);
    img3 = imread(fullfile(enhanced_folder, 'number_of_turns.png'));
    imshow(img3);
    title('Number of Helical Turns', 'FontSize', 10, 'FontWeight', 'bold');

    ax4 = subplot(2, 2, 4);
    img4 = imread(fullfile(enhanced_folder, 'design_tradeoff.png'));
    imshow(img4);
    title('Design Trade-offs', 'FontSize', 10, 'FontWeight', 'bold');

    % Physics explanation
    annotation('textbox', [0.05, 0.02, 0.9, 0.08], 'String', {...
        'PRESSURE DROP PHYSICS:  DP = 4 * f_c * (L_coil / D_h) * (rho * v^2 / 2)', ...
        '  L_coil = N_turns * L_turn : Reducing turns has the strongest effect on DP', ...
        '  v = m_dot / (rho * GAP * w) : Larger flow area reduces velocity, DP scales with v^2', ...
        '  D_h = 2*GAP*w/(GAP+w) : Larger hydraulic diameter reduces friction losses'}, ...
        'FontSize', 8, 'EdgeColor', [0.5 0.5 0.5], 'BackgroundColor', [1.0 0.98 0.95], 'FontName', 'Courier');

    exportgraphics(fig4, report_file, 'ContentType', 'image', 'Resolution', 200, 'Append', true);
    close(fig4);
    fprintf('  Page 4: Physical analysis\n');

    %% Page 5: Final Recommendations
    fig5 = figure('Position', [100, 100, 800, 1000], 'Color', 'w', 'Visible', 'off');

    annotation('textbox', [0.1, 0.92, 0.8, 0.05], 'String', ...
        'DESIGN RECOMMENDATIONS', ...
        'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'EdgeColor', 'none');

    % Visual comparison - bar charts
    designs = {'Baseline', 'Initial Best', 'Extended Best'};

    % Pressure drop comparison
    ax1 = axes('Position', [0.08, 0.68, 0.40, 0.20]);
    dp = [8.56, 0.80, 0.31];
    b = bar(dp);
    b.FaceColor = 'flat';
    b.CData(1,:) = [0.8 0.3 0.3];
    b.CData(2,:) = [0.3 0.6 0.8];
    b.CData(3,:) = [0.2 0.7 0.3];
    hold on;
    yline(8.5, 'r--', 'LineWidth', 2);
    text(3.3, 8.5, '8.5 kPa limit', 'FontSize', 8, 'Color', 'r');
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Pressure Drop [kPa]');
    title('Pressure Drop Comparison', 'FontWeight', 'bold');
    grid on;
    % Add values
    for i = 1:3
        text(i, dp(i) + 0.4, sprintf('%.2f', dp(i)), 'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
    end

    % Number of turns comparison
    ax2 = axes('Position', [0.55, 0.68, 0.40, 0.20]);
    turns = [42, 19, 11];
    b = bar(turns);
    b.FaceColor = [0.5 0.3 0.7];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Number of Turns');
    title('Helical Turns', 'FontWeight', 'bold');
    grid on;
    for i = 1:3
        text(i, turns(i) + 1.5, sprintf('%d', turns(i)), 'HorizontalAlignment', 'center', 'FontSize', 9, 'FontWeight', 'bold');
    end

    % Pitch comparison
    ax3 = axes('Position', [0.08, 0.42, 0.40, 0.20]);
    pitch = [100, 218, 392];
    b = bar(pitch);
    b.FaceColor = [0.3 0.7 0.5];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Pitch [mm]');
    title('Pitch (w + t)', 'FontWeight', 'bold');
    grid on;

    % Velocity comparison
    ax4 = axes('Position', [0.55, 0.42, 0.40, 0.20]);
    vel = [0.97, 0.43, 0.22];
    b = bar(vel);
    b.FaceColor = [0.8 0.5 0.2];
    set(gca, 'XTickLabel', designs, 'FontSize', 9);
    ylabel('Velocity [m/s]');
    title('Fluid Velocity', 'FontWeight', 'bold');
    grid on;

    % Recommendations text
    annotation('textbox', [0.05, 0.04, 0.9, 0.34], 'String', {...
        'RECOMMENDED DESIGNS:', ...
        '', ...
        'OPTION A - Aggressive (Extended Best): D_jacket=55cm, w=6cm, t=33cm', ...
        '  Pressure Drop: 0.31 kPa (96% reduction)', ...
        '  Best for: Maximum pumping efficiency, simplest fabrication (only 11 turns)', ...
        '  Consideration: Verify heat transfer uniformity with CFD', ...
        '', ...
        'OPTION B - Balanced: D_jacket=55cm, w=8cm, t=25cm', ...
        '  Pressure Drop: ~0.4 kPa (95% reduction)', ...
        '  Best for: Balance between DP reduction and manufacturing practicality', ...
        '', ...
        'OPTION C - Conservative (Initial Best): D_jacket=53cm, w=12cm, t=10cm', ...
        '  Pressure Drop: 0.80 kPa (91% reduction)', ...
        '  Best for: More conventional geometry, easier to validate', ...
        '', ...
        'AVOID BASELINE DESIGN:', ...
        '  Exceeds the 8.5 kPa pressure drop limit with no safety margin.', ...
        '', ...
        'All optimized designs maintain thermal validity (A_available >= A_required).'}, ...
        'FontSize', 9, 'EdgeColor', [0.3 0.3 0.3], 'BackgroundColor', [0.98 0.98 0.98], ...
        'VerticalAlignment', 'top');

    exportgraphics(fig5, report_file, 'ContentType', 'vector', 'Append', true);
    close(fig5);
    fprintf('  Page 5: Recommendations\n');

    %% Done
    fprintf('\nReport saved to: %s\n', report_file);
end
