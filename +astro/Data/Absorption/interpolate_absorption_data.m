function interpolate_absorption_data()
    absorption_dir = fileparts(mfilename('fullpath'));

    dat_files = dir(fullfile(absorption_dir, 'Abs_*.dat'));
    dat_files = dat_files(~contains({dat_files.name}, '_interp_LAST.dat'));

    target_wavelength = linspace(300, 1100, 401)';

    fprintf('Processing %d absorption data files...\n', length(dat_files));

    for i = 1:length(dat_files)
        filename = dat_files(i).name;
        filepath = fullfile(absorption_dir, filename);

        fprintf('Processing %s... ', filename);

        try
            data = readtable(filepath, 'FileType', 'text', 'Delimiter', '\t');

            wavelength = data{:, 1};

            interp_data = zeros(length(target_wavelength), width(data));
            interp_data(:, 1) = target_wavelength;

            for col = 2:width(data)
                values = data{:, col};
                if isnumeric(values)
                    interp_data(:, col) = interp1(wavelength, values, target_wavelength, 'linear', 0);
                else
                    values_num = str2double(values);
                    interp_data(:, col) = interp1(wavelength, values_num, target_wavelength, 'linear', 0);
                end
            end

            [~, base_name, ~] = fileparts(filename);
            output_filename = [base_name '_interp_LAST.dat'];
            output_filepath = fullfile(absorption_dir, output_filename);

            fid = fopen(output_filepath, 'w');

            header_line = strjoin(data.Properties.VariableNames, sprintf('\t'));
            fprintf(fid, '%s\r\n', header_line);

            format_spec = repmat('%g\t', 1, width(data));
            format_spec(end) = [];
            format_spec = [format_spec '\r\n'];

            for row = 1:length(target_wavelength)
                fprintf(fid, format_spec, interp_data(row, :));
            end

            fclose(fid);

            mat_filename = [base_name '_interp_LAST.mat'];
            mat_filepath = fullfile(absorption_dir, mat_filename);
            interp_table = array2table(interp_data, 'VariableNames', data.Properties.VariableNames);
            save(mat_filepath, 'interp_table', 'interp_data', 'target_wavelength');

            fprintf('Done. Created %s and %s\n', output_filename, mat_filename);

        catch ME
            fprintf('Error: %s\n', ME.message);
        end
    end

    fprintf('\nInterpolation complete!\n');
end