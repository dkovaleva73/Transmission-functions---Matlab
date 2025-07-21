function Trans_corrector = correctorTransmission(Lam, C0, C1, C2, C3, C4)
    % Calculate corrector transmission from polynomial coefficients
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   C0-C4 (double): Polynomial coefficients
    %
    % Returns:
    %   Trans_corrector (double array): Corrector transmission values (0-1)
    
    arguments
        Lam (:,1) double
        C0 (1,1) double = 0.0
        C1 (1,1) double = 0.0
        C2 (1,1) double = 0.0
        C3 (1,1) double = 0.0
        C4 (1,1) double = 0.0
    end
    
    % Try to read from data file first
    Data_file = getDataFilePath('StarBrightXLT_Corrector_Trasmission.csv');
    
    if exist(Data_file, 'file')
        % Read corrector transmission data
        Data = readmatrix(Data_file);
        Corrector_wavelength = Data(:, 1);
        Corrector_transmission = Data(:, 2) / 100;  % Convert percentage to fraction
        
        % Interpolate to wavelength array
        Trans_corrector = interp1(Corrector_wavelength, Corrector_transmission, Lam, 'linear', 'extrap');
    else
        % Use polynomial coefficients as fallback
        if any([C0, C1, C2, C3, C4] ~= 0)
            Trans_corrector = polyval([C4, C3, C2, C1, C0], Lam);
        else
            warning('Corrector transmission data file not found and no coefficients provided, using default value 0.95');
            Trans_corrector = 0.95 * ones(size(Lam));
        end
    end
    
    % Ensure values are in valid range [0, 1]
    Trans_corrector = max(0, min(1, Trans_corrector));
end

function file_path = getDataFilePath(filename)
    % Get the file path for instrumental data
    
    % Search locations
    Possible_paths = {
        sprintf('/home/dana/matlab/data_Transmission_Fitter/Templates/%s', filename), ...
        sprintf('/home/dana/Documents/MATLAB/inwork/data/Templates/%s', filename), ...
        sprintf('/home/dana/anaconda3/lib/python3.12/site-packages/transmission_fitter/data/Templates/%s', filename)
    };
    
    file_path = '';
    for I = 1:length(Possible_paths)
        if exist(Possible_paths{I}, 'file')
            file_path = Possible_paths{I};
            return;
        end
    end
    
    % If not found, return the primary path for error handling
    file_path = Possible_paths{1};
end