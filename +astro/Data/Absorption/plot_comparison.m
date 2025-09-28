function plot_comparison()
    absorption_dir = fileparts(mfilename('fullpath'));

    dat_files = dir(fullfile(absorption_dir, 'Abs_*.dat'));
    dat_files = dat_files(~contains({dat_files.name}, '_interp_LAST.dat'));

    fprintf('Creating comparison plots for %d files...\n', length(dat_files));

    figure('Position', [100, 100, 1400, 1000]);

    num_files = length(dat_files);
    rows = ceil(sqrt(num_files));
    cols = ceil(num_files / rows);

    for i = 1:num_files
        filename = dat_files(i).name;
        filepath = fullfile(absorption_dir, filename);

        [~, base_name, ~] = fileparts(filename);
        interp_filename = [base_name '_interp_LAST.dat'];
        interp_filepath = fullfile(absorption_dir, interp_filename);

        try
            data_orig = readtable(filepath, 'FileType', 'text', 'Delimiter', '\t');
            data_interp = readtable(interp_filepath, 'FileType', 'text', 'Delimiter', '\t');

            wl_orig = data_orig{:, 1};
            abs_orig = data_orig{:, 2};
            if ~isnumeric(abs_orig)
                abs_orig = str2double(abs_orig);
            end

            mask_orig = wl_orig >= 300 & wl_orig <= 1100;
            wl_orig = wl_orig(mask_orig);
            abs_orig = abs_orig(mask_orig);

            wl_interp = data_interp{:, 1};
            abs_interp = data_interp{:, 2};
            if ~isnumeric(abs_interp)
                abs_interp = str2double(abs_interp);
            end

            subplot(rows, cols, i);
            plot(wl_orig, abs_orig, 'b-', 'LineWidth', 1);
            hold on;
            plot(wl_interp, abs_interp, 'r.', 'MarkerSize', 6);
            hold off;

            xlim([300 1100]);
            xlabel('Wavelength (nm)', 'FontSize', 8);
            ylabel('Absorption', 'FontSize', 8);
            title(strrep(base_name, '_', '\_'), 'FontSize', 9);
            legend({'Original', 'Interpolated'}, 'FontSize', 7, 'Location', 'best');
            grid on;
            set(gca, 'FontSize', 7);

            fprintf('Plotted %s\n', filename);

        catch ME
            fprintf('Error plotting %s: %s\n', filename, ME.message);
        end
    end

    sgtitle('Absorption Data: Original vs Interpolated (300-1100 nm, 401 points)', 'FontSize', 14, 'FontWeight', 'bold');

    output_file = fullfile(absorption_dir, 'absorption_comparison.png');
    saveas(gcf, output_file);
    fprintf('\nSaved comparison plot to: %s\n', output_file);
end