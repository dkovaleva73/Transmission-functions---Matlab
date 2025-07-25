function Abs_data = loadAbsorptionData(Data_path, Species, Verbose, Validate)
    % Load all molecular absorption data for atmospheric transmission
    % calculations (based on the SMARTS 2.9.5 model)
    % Input :   - Data_path - Custom path to absorption data files
    %                         (default: fixed)
    %           - Species   - Cell array of species to load (default: all available)
    %                         'O3UV'|'O3IR'|'H20'|'O2'|'N2'|'CO'|'CO2'|'CH4'|'O4'|'N2O'|'NH3'|
    %                         'NO'|'NO2'|'SO2U'|'SO2I'|'HNO3'|'NO3'|'HNO2'|'CH2O'|'BrO'|'ClNO'
    %           - Verbose   - Display loading progress (default: true)
    %           - Validate  - Validate data after loading (default: true)
    % Output : - Abs_data - Structured data containing all absorption information:
    %          - .Species - Cell array of available species names
    %          - .metadata - Loading information and file paths
    %          - .O3UV, .O3IR, .H2O, .CO2, etc. - Individual species data structures
    %          - .Species.wavelength - Wavelength array [nm]
    %          - .Species.absorption - Absorption coefficients / absorption
    %            cross-section of a molecula at a certain temperature)
    %          - .Species.filename   - Source filename
    %          - .Species.loaded     - Loading timestamp
    %            (additional fields depend on species)
    % Author  : D. Kovaleva (July 2025)
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Example : Abs_data = transmission.data.loadAbsorptionData();
    %           Ozone_wavelength = abs_data.O3UV.wavelength;
    %           Ozone_absorption = abs_data.O3UV.absorption;
    %           Abs_data = transmission.data.loadAbsorptionData('/custom/path');
    %           Abs_data = transmission.data.loadAbsorptionData([], {'O3UV', 'H2O'});
    %           Abs_data = transmission.data.loadAbsorptionData([], {}, false);
    %           Abs_data = transmission.data.loadAbsorptionData('/custom/path', {'O3UV', 'H2O'});
    %           Abs_data = transmission.data.loadAbsorptionData([], {'O3UV', 'H2O'}, false, true);
    arguments
        Data_path = '/home/dana/matlab/data/transmission_fitter'
        Species = {}
        Verbose = true
        Validate = true
    end  

    % Use arguments directly with empty handling
    if isempty(Data_path)
        Data_path_resolved = '/home/dana/matlab/data/transmission_fitter';
    else
        Data_path_resolved = Data_path;
    end
    
    Requested_species = Species;
    Verbose_flag = Verbose;
    Validate_data = Validate;
    
    %% Initialize output structure
    Abs_data = struct();
    Abs_data.metadata = struct();
    Abs_data.metadata.loaded = datetime('now');
    Abs_data.metadata.loader_version = '1.0';
    
    %% Validate data path exists
    if ~exist(Data_path_resolved, 'dir')
        error('Absorption data directory not found: %s', Data_path_resolved);
    end
    
    Abs_data.metadata.data_path = Data_path_resolved;
    
    if Verbose_flag
        fprintf('Loading molecular absorption data from: %s\n', Data_path_resolved);
    end
    
    %% Define available molecular species and their file mappings
    Species_files = containers.Map();
    
    % Atmospheric gases
    Species_files('O3UV') = 'Abs_O3UV.dat';      % Ozone UV absorption
    Species_files('O3IR') = 'Abs_O3IR.dat';      % Ozone IR absorption  
    Species_files('H2O') = 'Abs_H2O.dat';        % Water vapor
    Species_files('CO2') = 'Abs_CO2.dat';        % Carbon dioxide
    Species_files('CH4') = 'Abs_CH4.dat';        % Methane
    Species_files('N2O') = 'Abs_N2O.dat';        % Nitrous oxide
    Species_files('CO') = 'Abs_CO.dat';          % Carbon monoxide
    Species_files('NO2') = 'Abs_NO2.dat';        % Nitrogen dioxide
    Species_files('NO') = 'Abs_NO.dat';          % Nitric oxide
    Species_files('NO3') = 'Abs_NO3.dat';        % Nitrogen trioxide
    Species_files('SO2I') = 'Abs_SO2I.dat';      % Sulfur dioxide (infrared)
    Species_files('SO2U') = 'Abs_SO2U.dat';      % Sulfur dioxide (UV)
    Species_files('NH3') = 'Abs_NH3.dat';        % Ammonia
    Species_files('HNO2') = 'Abs_HNO2.dat';      % Nitrous acid
    Species_files('HNO3') = 'Abs_HNO3.dat';      % Nitric acid
    Species_files('CH2O') = 'Abs_CH2O.dat';      % Formaldehyde
    Species_files('BrO') = 'Abs_BrO.dat';        % Bromine monoxide
    Species_files('ClNO') = 'Abs_ClNO.dat';      % Nitrosyl chloride
    Species_files('O2') = 'Abs_O2.dat';          % Oxygen
    Species_files('O4') = 'Abs_O4.dat';          % Oxygen dimer
    Species_files('N2') = 'Abs_N2.dat';          % Nitrogen
    
    %% Determine which species to load
    if isempty(Requested_species)
        % Load all available species
        Species_to_load = keys(Species_files);
    else
        % Convert to cell array if needed
        if ischar(Requested_species) || isstring(Requested_species)
            Species_to_load = {char(Requested_species)};
        else
            Species_to_load = Requested_species;
        end
        
        % Validate requested species
        Invalid_species = {};
        for i = 1:length(Species_to_load)
            if ~Species_files.isKey(Species_to_load{i})
                Invalid_species{end+1} = Species_to_load{i}; %#ok<AGROW>
            end
        end
        
        if ~isempty(Invalid_species)
            warning('Unknown species requested: %s\nAvailable species: %s', ...
                    strjoin(Invalid_species, ', '), strjoin(keys(Species_files), ', '));
            % Remove invalid species
            Species_to_load = setdiff(Species_to_load, Invalid_species);
        end
    end
    
    Abs_data.metadata.requested_species = Species_to_load;
    Abs_data.species = {};
    
    if Verbose_flag
        fprintf('Loading %d molecular species...\n', length(Species_to_load));
    end
    
    %% Load each species data
    Load_count = 0;
    for i = 1:length(Species_to_load)
        Species = Species_to_load{i};
        Filename = Species_files(Species);
        Filepath = fullfile(Data_path_resolved, Filename);
        
        if Verbose_flag
            fprintf('  Loading %s from %s... ', Species, Filename);
        end
        
        try
            % Load species-specific data
            Species_data = loadSpeciesData(Filepath, Species, Verbose_flag);
            
            % Apply absorption coefficient corrections
            Species_data = applyAbsorptionCorrections(Species_data, Species);
            
            % Store in main structure
            Abs_data.(Species) = Species_data;
            Abs_data.species{end+1} = Species;
            Load_count = Load_count + 1;
            
            if Verbose_flag
                fprintf('✓ (%d points)\n', length(Species_data.wavelength));
            end
            
        catch ME
            if Verbose_flag
                fprintf('✗ Failed: %s\n', ME.message);
            end
            warning('Failed to load %s: %s', Species, ME.message);
        end
    end
    
    Abs_data.metadata.loaded_count = Load_count;
    Abs_data.metadata.total_requested = length(Species_to_load);
    
    %% Validate loaded data
    if Validate_data && Load_count > 0
        if Verbose_flag
            fprintf('Validating loaded data...\n');
        end
        Validation_results = validateAbsorptionData(Abs_data, Verbose_flag);
        Abs_data.metadata.validation = Validation_results;
    end
    
    %% Summary
    if Verbose_flag
        fprintf('\nAbsorption Data Loading Summary:\n');
        fprintf('================================\n');
        fprintf('Successfully loaded: %d/%d species\n', Load_count, length(Species_to_load));
        fprintf('Available species: %s\n', strjoin(Abs_data.species, ', '));
        fprintf('Data path: %s\n', Data_path_resolved);
        fprintf('Loading time: %s\n', char(Abs_data.metadata.loaded));
        
        if Validate_data && isfield(Abs_data.metadata, 'validation')
            val = Abs_data.metadata.validation;
            fprintf('Validation: %d warnings, %d errors\n', val.warning_count, val.error_count);
        end
        
        fprintf('\nUsage examples:\n');
        fprintf('  %% Load all species (default):\n');
        fprintf('  abs_data = transmission.data.loadAbsorptionData();\n');
        fprintf('  \n');
        fprintf('  %% Load specific species with default path:\n');
        fprintf('  abs_data = transmission.data.loadAbsorptionData([], {''O3UV'', ''H2O''});\n');
        fprintf('  \n');
        fprintf('  %% Load specific species, silent mode:\n');
        fprintf('  abs_data = transmission.data.loadAbsorptionData([], {''BrO''}, false);\n');
        fprintf('  \n');
        fprintf('  %% Access loaded data:\n');
        fprintf('  ozone_data = abs_data.O3UV;\n');
        fprintf('  wavelength = ozone_data.wavelength;\n');
        fprintf('  absorption = ozone_data.absorption;\n');
    end
end

function Species_data = loadSpeciesData(Filepath, Species, ~)
    % Load data for a specific molecular species
    
    Species_data = struct();
    Species_data.filename = Filepath;
    Species_data.species = Species;
    Species_data.loaded = datetime('now');
    
    if ~exist(Filepath, 'file')
        error('File not found: %s', Filepath);
    end
    
    % Determine loading method based on species
    switch Species
        case {'H2O'}
            % Water vapor has complex multi-column format
            Species_data = loadWaterVaporData(Filepath, Species_data);
            
        case {'O3UV', 'O3IR'}
            % Ozone data (UV and IR bands)
            Species_data = loadOzoneData(Filepath, Species_data);
            
        otherwise
            % Generic molecular absorption data (simple 2-column format)
            Species_data = loadGenericAbsorptionData(Filepath, Species_data);
    end
    
    % Basic validation
    if isempty(Species_data.wavelength) || isempty(Species_data.absorption)
        error('No data loaded from file');
    end
    
    % Ensure column vectors
    Species_data.wavelength = Species_data.wavelength(:);
    Species_data.absorption = Species_data.absorption(:);
    
    % Check for matching lengths
    if length(Species_data.wavelength) ~= length(Species_data.absorption)
        error('Wavelength and absorption arrays have different lengths');
    end
end

function Data = loadWaterVaporData(Filepath, Data)
    % Load water vapor absorption data with multiple coefficients
    % Modified to match Python np.loadtxt behavior (removes NaN separator columns)
    
    % Read as numeric matrix and remove NaN separator columns to match Python np.loadtxt
    Raw_matrix = readmatrix(Filepath, 'FileType', 'text', 'Delimiter', '\t', 'NumHeaderLines', 1);
    
    % Remove NaN separator columns (columns 4, 9, 14, 19, 22) to match Python np.loadtxt
    % Python np.loadtxt automatically skips these, resulting in 17 columns instead of 22
    keep_columns = [1:3, 5:8, 10:13, 15:18, 20:21]; % Skip columns 4, 9, 14, 19, 22
    Raw_data_clean = Raw_matrix(:, keep_columns);
    
    % Extract basic wavelength and absorption (now matching Python column indices)
    Data.wavelength = Raw_data_clean(:, 1);        % Column 0 in Python
    Data.absorption = Raw_data_clean(:, 2);        % Column 1 in Python
    Data.band = Raw_data_clean(:, 3);              % Column 2 in Python
    
    % Extract fitting coefficients (for advanced calculations)
    % Column mapping now matches Python np.loadtxt exactly (17 columns total)
    if size(Raw_data_clean, 2) >= 17
        Data.fit_coeffs = struct();
        Data.fit_coeffs.Ifitw = Raw_data_clean(:, 4);    % Column 3 in Python (was Var5)
        Data.fit_coeffs.Bwa0 = Raw_data_clean(:, 5);     % Column 4 in Python (was Var6)
        Data.fit_coeffs.Bwa1 = Raw_data_clean(:, 6);     % Column 5 in Python (was Var7)
        Data.fit_coeffs.Bwa2 = Raw_data_clean(:, 7);     % Column 6 in Python (was Var8)
        Data.fit_coeffs.Ifitm = Raw_data_clean(:, 8);    % Column 7 in Python (was Var10)
        Data.fit_coeffs.Bma0 = Raw_data_clean(:, 9);     % Column 8 in Python (was Var11)
        Data.fit_coeffs.Bma1 = Raw_data_clean(:, 10);    % Column 9 in Python (was Var12)
        Data.fit_coeffs.Bma2 = Raw_data_clean(:, 11);    % Column 10 in Python (was Var13)
        Data.fit_coeffs.Ifitmw = Raw_data_clean(:, 12);  % Column 11 in Python (was Var15)
        Data.fit_coeffs.Bmwa0 = Raw_data_clean(:, 13);   % Column 12 in Python (was Var16)
        Data.fit_coeffs.Bmwa1 = Raw_data_clean(:, 14);   % Column 13 in Python (was Var17)
        Data.fit_coeffs.Bmwa2 = Raw_data_clean(:, 15);   % Column 14 in Python (was Var18)
        Data.fit_coeffs.Bpa1 = Raw_data_clean(:, 16);    % Column 15 in Python (was Var20)
        Data.fit_coeffs.Bpa2 = Raw_data_clean(:, 17);    % Column 16 in Python (was Var21)
    end
    
    Data.format = 'water_vapor_complex';
end

function Data = loadOzoneData(Filepath, Data)
    % Load ozone absorption data
    
    Raw_data = readtable(Filepath, 'Delimiter', '\t', 'ReadVariableNames', false);
    
    Data.wavelength = Raw_data.Var1;     % nm
    Data.absorption = Raw_data.Var2;     % absorption cross-section
    
    % Additional ozone-specific data if available
    if size(Raw_data, 2) >= 3
        Data.temperature_coeff = Raw_data.Var3;  % Temperature coefficient
    end
    
    Data.format = 'ozone';
end

function Data = loadGenericAbsorptionData(Filepath, Data)
    % Load generic 2-column absorption data
    
    Raw_data = readtable(Filepath, 'Delimiter', '\t', 'ReadVariableNames', false);
    
    Data.wavelength = Raw_data.Var1;     % nm
    Data.absorption = Raw_data.Var2;     % absorption coefficient/cross-section
    
    Data.format = 'generic';
end

function Validation = validateAbsorptionData(Abs_data, Verbose)
    % Validate loaded absorption data
    
    Validation = struct();
    Validation.warning_count = 0;
    Validation.error_count = 0;
    Validation.issues = {};
    
    Species_list = Abs_data.species;
    
    for i = 1:length(Species_list)
        Species = Species_list{i};
        Species_data = Abs_data.(Species);
        
        % Check for NaN values
        if any(isnan(Species_data.wavelength)) || any(isnan(Species_data.absorption))
            Validation.warning_count = Validation.warning_count + 1;
            Validation.issues{end+1} = sprintf('%s: Contains NaN values', Species);
        end
        
        % Check for negative values
        if any(Species_data.wavelength <= 0)
            Validation.error_count = Validation.error_count + 1;
            Validation.issues{end+1} = sprintf('%s: Negative or zero wavelengths', Species);
        end
        
        if any(Species_data.absorption < 0)
            Validation.warning_count = Validation.warning_count + 1;
            Validation.issues{end+1} = sprintf('%s: Negative absorption coefficients', Species);
        end
        
        % Check wavelength range
        Wvl_range = [min(Species_data.wavelength), max(Species_data.wavelength)];
        if Wvl_range(1) > 200 || Wvl_range(2) > 2000
            Validation.warning_count = Validation.warning_count + 1;
            Validation.issues{end+1} = sprintf('%s: Unusual wavelength range [%.1f, %.1f] nm', ...
                                              Species, Wvl_range(1), Wvl_range(2));
        end
        
        % Check for monotonic wavelength
        if ~issorted(Species_data.wavelength)
            Validation.warning_count = Validation.warning_count + 1;
            Validation.issues{end+1} = sprintf('%s: Wavelength array not sorted', Species);
        end
    end
    
    if Verbose && Validation.warning_count > 0
        fprintf('  Validation warnings:\n');
        for i = 1:length(Validation.issues)
            fprintf('    %s\n', Validation.issues{i});
        end
    end
end

function Species_data = applyAbsorptionCorrections(Species_data, Species)
    % Apply species-specific absorption coefficient corrections
    % Based on SMARTS 2.9.5 model corrections and temperature dependencies
    
    switch Species
        case 'O4'
            % O4 scaling factor - CRITICAL: DO NOT APPLY HERE
            % The original function applies this scaling in the main function, NOT in data loading
            % Keep raw absorption data and let main function handle scaling
            Species_data.correction_applied = 'none_o4_scaling_in_main_function';
            
        case 'NO2'
            % NO2 temperature correction: sigma + b0*(T-T0)
            % Assumes data has sigma in column 1, b0 in column 2
            if size(Species_data.absorption, 2) >= 2
                Sigma = Species_data.absorption(:, 1);
                B0 = Species_data.absorption(:, 2);
                T_ref = 228.7;  % K
                T0 = 220.0;     % K reference
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * (Sigma + B0 * (T_ref - T0));
                Species_data.correction_applied = 'NO2_temperature_correction';
            else
                % Apply Loschmidt scaling only
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
                Species_data.correction_applied = 'NO2_loschmidt_scaling';
            end
            
        case 'SO2U'
            % SO2U temperature correction: sigma + b0*(T-T0)
            if size(Species_data.absorption, 2) >= 2
                Sigma = Species_data.absorption(:, 1);
                B0 = Species_data.absorption(:, 2);
                T_ref = 247.0;  % K
                T0 = 213.0;     % K reference
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * (Sigma + B0 * (T_ref - T0));
                Species_data.correction_applied = 'SO2U_temperature_correction';
            else
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
                Species_data.correction_applied = 'SO2U_loschmidt_scaling';
            end
            
        case 'SO2I'
            % SO2I gets added to SO2U, but apply Loschmidt scaling
            NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
            Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
            Species_data.correction_applied = 'SO2I_loschmidt_scaling';
            
        case 'HNO3'
            % HNO3 exponential temperature correction: xs*exp(b0*(T-T0))
            if size(Species_data.absorption, 2) >= 2
                Xs = Species_data.absorption(:, 1);
                B0 = Species_data.absorption(:, 2);
                T_ref = 234.2;  % K
                T0 = 298.0;     % K reference
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = 1e-20 * NLOSCHMIDT * Xs .* exp(1e-3 * B0 * (T_ref - T0));
                Species_data.correction_applied = 'HNO3_exponential_temperature_correction';
            else
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = 1e-20 * NLOSCHMIDT * Species_data.absorption;
                Species_data.correction_applied = 'HNO3_scaling';
            end
            
        case 'NO3'
            % NO3 temperature correction: xs + b0*(T-T0)
            if size(Species_data.absorption, 2) >= 2
                Xs = Species_data.absorption(:, 1);
                B0 = Species_data.absorption(:, 2);
                T_ref = 225.3;  % K
                T0 = 230.0;     % K reference
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * (Xs + B0 * (T_ref - T0));
                Species_data.correction_applied = 'NO3_temperature_correction';
            else
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
                Species_data.correction_applied = 'NO3_loschmidt_scaling';
            end
            
        case 'HNO2'
            % HNO2 Loschmidt scaling
            NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
            Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
            Species_data.correction_applied = 'HNO2_loschmidt_scaling';
            
        case 'CH2O'
            % CH2O temperature correction: xs + b0*(T-T0)
            if size(Species_data.absorption, 2) >= 2
                Xs = Species_data.absorption(:, 1);
                B0 = Species_data.absorption(:, 2);
                T_ref = 264.0;  % K
                T0 = 293.0;     % K reference
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * (Xs + B0 * (T_ref - T0));
                Species_data.correction_applied = 'CH2O_temperature_correction';
            else
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
                Species_data.correction_applied = 'CH2O_loschmidt_scaling';
            end
            
        case 'BrO'
            % BrO Loschmidt scaling
            NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
            Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
            Species_data.correction_applied = 'BrO_loschmidt_scaling';
            
        case 'ClNO'
            % ClNO quadratic temperature correction: xs*(1+b0*(T-T0)+b1*(T-T0)^2)
            if size(Species_data.absorption, 2) >= 3
                Xs = Species_data.absorption(:, 1);
                B0 = Species_data.absorption(:, 2);
                B1 = Species_data.absorption(:, 3);
                T_ref = 230.0;  % K
                T0 = 296.0;     % K reference
                DT = T_ref - T0;
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = Xs * NLOSCHMIDT .* (1 + B0 * DT + B1 * DT^2);
                Species_data.correction_applied = 'ClNO_quadratic_temperature_correction';
            else
                NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
                Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
                Species_data.correction_applied = 'ClNO_loschmidt_scaling';
            end
            
        case {'O3UV', 'O3IR'}
            % Ozone Loschmidt scaling
            NLOSCHMIDT = 2.6867811e19;  % cm-3, Loschmidt number
            Species_data.absorption = NLOSCHMIDT * Species_data.absorption;
            Species_data.correction_applied = 'ozone_loschmidt_scaling';
            
        otherwise
            % No corrections needed for other species (O2, N2, CO, CO2, CH4, N2O, H2O)
            Species_data.correction_applied = 'none';
    end
    
    % Ensure absorption remains a column vector
    Species_data.absorption = Species_data.absorption(:);
end