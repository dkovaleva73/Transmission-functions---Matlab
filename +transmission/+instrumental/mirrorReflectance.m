function Ref_mirror = mirrorReflectance(Lam, Use_orig_xlt, R0, R1, R2, R3, R4)
    % Calculate mirror reflectance from data files or polynomial coefficients
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   Use_orig_xlt (logical): Use original data file (true) or polynomial (false)
    %   R0-R4 (double): Polynomial coefficients (used if Use_orig_xlt = false)
    %
    % Returns:
    %   Ref_mirror (double array): Mirror reflectance values (0-1)
    
    arguments
        Lam (:,1) double
        Use_orig_xlt (1,1) logical = true
        R0 (1,1) double = 0.0
        R1 (1,1) double = 0.0
        R2 (1,1) double = 0.0
        R3 (1,1) double = 0.0
        R4 (1,1) double = 0.0
    end
    
    if Use_orig_xlt
        % Use original data file
        Data_file = getDataFilePath('StarBrightXLT_Mirror_Reflectivity.csv');
        
        if exist(Data_file, 'file')
            % Read mirror reflectance data
            Data = readmatrix(Data_file);
            Mirror_wavelength = Data(:, 1);
            Mirror_reflectance = Data(:, 2) / 100;  % Convert percentage to fraction
            
            % Interpolate to wavelength array
            Ref_mirror = interp1(Mirror_wavelength, Mirror_reflectance, Lam, 'linear', 'extrap');
        else
            % Use alternative file if available
            Alt_file = getDataFilePath('StarBrightXLT_Mirror_Reflectivity_ALTERNATIVE.csv');
            if exist(Alt_file, 'file')
                Data = readmatrix(Alt_file);
                Mirror_wavelength = Data(:, 1);
                Mirror_reflectance = Data(:, 2) / 100;  % Convert percentage to fraction
                Ref_mirror = interp1(Mirror_wavelength, Mirror_reflectance, Lam, 'linear', 'extrap');
            else
                warning('Mirror reflectance data file not found, using default value 0.9');
                Ref_mirror = 0.9 * ones(size(Lam));
            end
        end
    else
        % Use polynomial coefficients
        Ref_mirror = polyval([R4, R3, R2, R1, R0], Lam);
    end
    
    % Ensure values are in valid range [0, 1]
    Ref_mirror = max(0, min(1, Ref_mirror));
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