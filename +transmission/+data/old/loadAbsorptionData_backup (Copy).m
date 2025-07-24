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
    %          - .species.wavelength - Wavelength array [nm]
    %          - .species.absorption - Absorption coefficients / absorption
    %            cross-section of a molecula at a certain temperature)
    %          - .species.filename   - Source filename
    %          - .species.loaded     - Loading timestamp
    %            (additional fields depend on species)
    % Author  : D. Kovaleva (July 2025)
    % Example : abs_data = transmission.data.loadAbsorptionData();
    %           ozone_wavelength = abs_data.O3UV.wavelength;
    %           ozone_absorption = abs_data.O3UV.absorption;
    %           abs_data = transmission.data.loadAbsorptionData('/custom/path');
    %           abs_data = transmission.data.loadAbsorptionData([], {'O3UV', 'H2O'});
    %           abs_data = transmission.data.loadAbsorptionData([], {}, false);
    %           abs_data = transmission.data.loadAbsorptionData('/custom/path', {'O3UV', 'H2O'});
    %           abs_data = transmission.data.loadAbsorptionData([], {'O3UV', 'H2O'}, false, true);
    arguments
        Data_path = '/home/dana/matlab/data/transmission_fitter'
        Species = {}
        Verbose = true
        Validate = true
    end  

    % Use arguments directly with empty handling
    if isempty(Data_path)
        data_path = '/home/dana/matlab/data/transmission_fitter';
    else
        data_path = Data_path;
    end
    
    requested_species = Species;
    verbose = Verbose;
    validate_data = Validate;
    
    %% Initialize output structure
    Abs_data = struct();
    Abs_data.metadata = struct();
    Abs_data.metadata.loaded = datetime('now');
    Abs_data.metadata.loader_version = '1.0';
    
    %% Validate data path exists
    if ~exist(data_path, 'dir')
        error('Absorption data directory not found: %s', data_path);
    end
    
    Abs_data.metadata.data_path = data_path;
    
    if verbose
        fprintf('Loading molecular absorption data from: %s\n', data_path);
    end
    
    %% Define available molecular species and their file mappings
    species_files = containers.Map();
    
    % Atmospheric gases
    species_files('O3UV') = 'Abs_O3UV.dat';      % Ozone UV absorption
    species_files('O3IR') = 'Abs_O3IR.dat';      % Ozone IR absorption  
    species_files('H2O') = 'Abs_H2O.dat';        % Water vapor
    species_files('CO2') = 'Abs_CO2.dat';        % Carbon dioxide
    species_files('CH4') = 'Abs_CH4.dat';        % Methane
    species_files('N2O') = 'Abs_N2O.dat';        % Nitrous oxide
    species_files('CO') = 'Abs_CO.dat';          % Carbon monoxide
    species_files('NO2') = 'Abs_NO2.dat';        % Nitrogen dioxide
    species_files('NO') = 'Abs_NO.dat';          % Nitric oxide
    species_files('NO3') = 'Abs_NO3.dat';        % Nitrogen trioxide
    species_files('SO2I') = 'Abs_SO2I.dat';      % Sulfur dioxide (infrared)
    species_files('SO2U') = 'Abs_SO2U.dat';      % Sulfur dioxide (UV)
    species_files('NH3') = 'Abs_NH3.dat';        % Ammonia
    species_files('HNO2') = 'Abs_HNO2.dat';      % Nitrous acid
    species_files('HNO3') = 'Abs_HNO3.dat';      % Nitric acid
    species_files('CH2O') = 'Abs_CH2O.dat';      % Formaldehyde
    species_files('BrO') = 'Abs_BrO.dat';        % Bromine monoxide
    species_files('ClNO') = 'Abs_ClNO.dat';      % Nitrosyl chloride
    species_files('O2') = 'Abs_O2.dat';          % Oxygen
    species_files('O4') = 'Abs_O4.dat';          % Oxygen dimer
    species_files('N2') = 'Abs_N2.dat';          % Nitrogen
    
    %% Determine which species to load
    if isempty(requested_species)
        % Load all available species
        species_to_load = keys(species_files);
    else
        % Convert to cell array if needed
        if ischar(requested_species) || isstring(requested_species)
            species_to_load = {char(requested_species)};
        else
            species_to_load = requested_species;
        end
        
        % Validate requested species
        invalid_species = {};
        for i = 1:length(species_to_load)
            if ~species_files.isKey(species_to_load{i})
                invalid_species{end+1} = species_to_load{i}; %#ok<AGROW>
            end
        end
        
        if ~isempty(invalid_species)
            warning('Unknown species requested: %s\nAvailable species: %s', ...
                    strjoin(invalid_species, ', '), strjoin(keys(species_files), ', '));
            % Remove invalid species
            species_to_load = setdiff(species_to_load, invalid_species);
        end
    end
    
    Abs_data.metadata.requested_species = species_to_load;
    Abs_data.species = {};
    
    if verbose
        fprintf('Loading %d molecular species...\n', length(species_to_load));
    end
    
    %% Load each species data
    load_count = 0;
    for i = 1:length(species_to_load)
        species = species_to_load{i};
        filename = species_files(species);
        filepath = fullfile(data_path, filename);
        
        if verbose
            fprintf('  Loading %s from %s... ', species, filename);
        end
        
        try
            % Load species-specific data
            species_data = loadSpeciesData(filepath, species, verbose);
            
            % Apply absorption coefficient corrections
            species_data = applyAbsorptionCorrections(species_data, species);
            
            % Store in main structure
            Abs_data.(species) = species_data;
            Abs_data.species{end+1} = species;
            load_count = load_count + 1;
            
            if verbose
                fprintf('✓ (%d points)\n', length(species_data.wavelength));
            end
            
        catch ME
            if verbose
                fprintf('✗ Failed: %s\n', ME.message);
            end
            warning('Failed to load %s: %s', species, ME.message);
        end
    end
    
    Abs_data.metadata.loaded_count = load_count;
    Abs_data.metadata.total_requested = length(species_to_load);
    
    %% Validate loaded data
    if validate_data && load_count > 0
        if verbose
            fprintf('Validating loaded data...\n');
        end
        validation_results = validateAbsorptionData(Abs_data, verbose);
        Abs_data.metadata.validation = validation_results;
    end
    
    %% Summary
    if verbose
        fprintf('\nAbsorption Data Loading Summary:\n');
        fprintf('================================\n');
        fprintf('Successfully loaded: %d/%d species\n', load_count, length(species_to_load));
        fprintf('Available species: %s\n', strjoin(Abs_data.species, ', '));
        fprintf('Data path: %s\n', data_path);
        fprintf('Loading time: %s\n', char(Abs_data.metadata.loaded));
        
        if validate_data && isfield(Abs_data.metadata, 'validation')
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

function species_data = loadSpeciesData(filepath, species, ~)
    % Load data for a specific molecular species
    
    species_data = struct();
    species_data.filename = filepath;
    species_data.species = species;
    species_data.loaded = datetime('now');
    
    if ~exist(filepath, 'file')
        error('File not found: %s', filepath);
    end
    
    % Determine loading method based on species
    switch species
        case {'H2O'}
            % Water vapor has complex multi-column format
            species_data = loadWaterVaporData(filepath, species_data);
            
        case {'O3UV', 'O3IR'}
            % Ozone data (UV and IR bands)
            species_data = loadOzoneData(filepath, species_data);
            
        otherwise
            % Generic molecular absorption data (simple 2-column format)
            species_data = loadGenericAbsorptionData(filepath, species_data);
    end
    
    % Basic validation
    if isempty(species_data.wavelength) || isempty(species_data.absorption)
        error('No data loaded from file');
    end
    
    % Ensure column vectors
    species_data.wavelength = species_data.wavelength(:);
    species_data.absorption = species_data.absorption(:);
    
    % Check for matching lengths
    if length(species_data.wavelength) ~= length(species_data.absorption)
        error('Wavelength and absorption arrays have different lengths');
    end
end

function data = loadWaterVaporData(filepath, data)
    % Load water vapor absorption data with multiple coefficients
    
    % Read the complex water vapor file format
    raw_data = readtable(filepath, 'Delimiter', '\t', 'ReadVariableNames', false, 'HeaderLines', 1);
    
    % Extract basic wavelength and absorption
    data.wavelength = raw_data.Var1;        % nm
    data.absorption = raw_data.Var2;        % absorption coefficient
    data.band = raw_data.Var3;              % band identifier
    
    % Extract fitting coefficients (for advanced calculations)
    if size(raw_data, 2) >= 21
        data.fit_coeffs = struct();
        data.fit_coeffs.Ifitw = raw_data.Var5;
        data.fit_coeffs.Bwa0 = raw_data.Var6;
        data.fit_coeffs.Bwa1 = raw_data.Var7;
        data.fit_coeffs.Bwa2 = raw_data.Var8;
        data.fit_coeffs.Ifitm = raw_data.Var10;
        data.fit_coeffs.Bma0 = raw_data.Var11;
        data.fit_coeffs.Bma1 = raw_data.Var12;
        data.fit_coeffs.Bma2 = raw_data.Var13;
        data.fit_coeffs.Ifitmw = raw_data.Var15;
        data.fit_coeffs.Bmwa0 = raw_data.Var16;
        data.fit_coeffs.Bmwa1 = raw_data.Var17;
        data.fit_coeffs.Bmwa2 = raw_data.Var18;
        data.fit_coeffs.Bpa1 = raw_data.Var20;
        data.fit_coeffs.Bpa2 = raw_data.Var21;
    end
    
    data.format = 'water_vapor_complex';
end

function data = loadOzoneData(filepath, data)
    % Load ozone absorption data
    
    raw_data = readtable(filepath, 'Delimiter', '\t', 'ReadVariableNames', false);
    
    data.wavelength = raw_data.Var1;     % nm
    data.absorption = raw_data.Var2;     % absorption cross-section
    
    % Additional ozone-specific data if available
    if size(raw_data, 2) >= 3
        data.temperature_coeff = raw_data.Var3;  % Temperature coefficient
    end
    
    data.format = 'ozone';
end

function data = loadGenericAbsorptionData(filepath, data)
    % Load generic 2-column absorption data
    
    raw_data = readtable(filepath, 'Delimiter', '\t', 'ReadVariableNames', false);
    
    data.wavelength = raw_data.Var1;     % nm
    data.absorption = raw_data.Var2;     % absorption coefficient/cross-section
    
    data.format = 'generic';
end

function validation = validateAbsorptionData(abs_data, verbose)
    % Validate loaded absorption data
    
    validation = struct();
    validation.warning_count = 0;
    validation.error_count = 0;
    validation.issues = {};
    
    species_list = abs_data.species;
    
    for i = 1:length(species_list)
        species = species_list{i};
        species_data = abs_data.(species);
        
        % Check for NaN values
        if any(isnan(species_data.wavelength)) || any(isnan(species_data.absorption))
            validation.warning_count = validation.warning_count + 1;
            validation.issues{end+1} = sprintf('%s: Contains NaN values', species);
        end
        
        % Check for negative values
        if any(species_data.wavelength <= 0)
            validation.error_count = validation.error_count + 1;
            validation.issues{end+1} = sprintf('%s: Negative or zero wavelengths', species);
        end
        
        if any(species_data.absorption < 0)
            validation.warning_count = validation.warning_count + 1;
            validation.issues{end+1} = sprintf('%s: Negative absorption coefficients', species);
        end
        
        % Check wavelength range
        wvl_range = [min(species_data.wavelength), max(species_data.wavelength)];
        if wvl_range(1) > 200 || wvl_range(2) > 2000
            validation.warning_count = validation.warning_count + 1;
            validation.issues{end+1} = sprintf('%s: Unusual wavelength range [%.1f, %.1f] nm', ...
                                              species, wvl_range(1), wvl_range(2));
        end
        
        % Check for monotonic wavelength
        if ~issorted(species_data.wavelength)
            validation.warning_count = validation.warning_count + 1;
            validation.issues{end+1} = sprintf('%s: Wavelength array not sorted', species);
        end
    end
    
    if verbose && validation.warning_count > 0
        fprintf('  Validation warnings:\n');
        for i = 1:length(validation.issues)
            fprintf('    %s\n', validation.issues{i});
        end
    end
end

function species_data = applyAbsorptionCorrections(species_data, species)
    % Apply species-specific absorption coefficient corrections
    % Based on SMARTS 2.9.5 model corrections and temperature dependencies
    
    switch species
        case 'O4'
            % O4 scaling factor
            species_data.absorption = 1e-46 * species_data.absorption;
            species_data.correction_applied = 'O4_scaling_1e-46';
            
        case 'NO2'
            % NO2 temperature correction: sigma + b0*(T-T0)
            % Assumes data has sigma in column 1, b0 in column 2
            if size(species_data.absorption, 2) >= 2
                sigma = species_data.absorption(:, 1);
                b0 = species_data.absorption(:, 2);
                T_ref = 228.7;  % K
                T0 = 220.0;     % K reference
                species_data.absorption = constant.Loschmidt * (sigma + b0 * (T_ref - T0));
                species_data.correction_applied = 'NO2_temperature_correction';
            else
                % Apply Loschmidt scaling only
                species_data.absorption = constant.Loschmidt * species_data.absorption;
                species_data.correction_applied = 'NO2_loschmidt_scaling';
            end
            
        case 'SO2U'
            % SO2U temperature correction: sigma + b0*(T-T0)
            if size(species_data.absorption, 2) >= 2
                sigma = species_data.absorption(:, 1);
                b0 = species_data.absorption(:, 2);
                T_ref = 247.0;  % K
                T0 = 213.0;     % K reference
                species_data.absorption = constant.Loschmidt * (sigma + b0 * (T_ref - T0));
                species_data.correction_applied = 'SO2U_temperature_correction';
            else
                species_data.absorption = constant.Loschmidt * species_data.absorption;
                species_data.correction_applied = 'SO2U_loschmidt_scaling';
            end
            
        case 'SO2I'
            % SO2I gets added to SO2U, but apply Loschmidt scaling
            species_data.absorption = constant.Loschmidt * species_data.absorption;
            species_data.correction_applied = 'SO2I_loschmidt_scaling';
            
        case 'HNO3'
            % HNO3 exponential temperature correction: xs*exp(b0*(T-T0))
            if size(species_data.absorption, 2) >= 2
                xs = species_data.absorption(:, 1);
                b0 = species_data.absorption(:, 2);
                T_ref = 234.2;  % K
                T0 = 298.0;     % K reference
                species_data.absorption = 1e-20 * constant.Loschmidt * xs .* exp(1e-3 * b0 * (T_ref - T0));
                species_data.correction_applied = 'HNO3_exponential_temperature_correction';
            else
                species_data.absorption = 1e-20 * constant.Loschmidt * species_data.absorption;
                species_data.correction_applied = 'HNO3_scaling';
            end
            
        case 'NO3'
            % NO3 temperature correction: xs + b0*(T-T0)
            if size(species_data.absorption, 2) >= 2
                xs = species_data.absorption(:, 1);
                b0 = species_data.absorption(:, 2);
                T_ref = 225.3;  % K
                T0 = 230.0;     % K reference
                species_data.absorption = constant.Loschmidt * (xs + b0 * (T_ref - T0));
                species_data.correction_applied = 'NO3_temperature_correction';
            else
                species_data.absorption = constant.Loschmidt * species_data.absorption;
                species_data.correction_applied = 'NO3_loschmidt_scaling';
            end
            
        case 'HNO2'
            % HNO2 Loschmidt scaling
            species_data.absorption = constant.Loschmidt * species_data.absorption;
            species_data.correction_applied = 'HNO2_loschmidt_scaling';
            
        case 'CH2O'
            % CH2O temperature correction: xs + b0*(T-T0)
            if size(species_data.absorption, 2) >= 2
                xs = species_data.absorption(:, 1);
                b0 = species_data.absorption(:, 2);
                T_ref = 264.0;  % K
                T0 = 293.0;     % K reference
                species_data.absorption = constant.Loschmidt * (xs + b0 * (T_ref - T0));
                species_data.correction_applied = 'CH2O_temperature_correction';
            else
                species_data.absorption = constant.Loschmidt * species_data.absorption;
                species_data.correction_applied = 'CH2O_loschmidt_scaling';
            end
            
        case 'BrO'
            % BrO Loschmidt scaling
            species_data.absorption = constant.Loschmidt * species_data.absorption;
            species_data.correction_applied = 'BrO_loschmidt_scaling';
            
        case 'ClNO'
            % ClNO quadratic temperature correction: xs*(1+b0*(T-T0)+b1*(T-T0)^2)
            if size(species_data.absorption, 2) >= 3
                xs = species_data.absorption(:, 1);
                b0 = species_data.absorption(:, 2);
                b1 = species_data.absorption(:, 3);
                T_ref = 230.0;  % K
                T0 = 296.0;     % K reference
                dT = T_ref - T0;
                species_data.absorption = xs * constant.Loschmidt .* (1 + b0 * dT + b1 * dT^2);
                species_data.correction_applied = 'ClNO_quadratic_temperature_correction';
            else
                species_data.absorption = constant.Loschmidt * species_data.absorption;
                species_data.correction_applied = 'ClNO_loschmidt_scaling';
            end
            
        case {'O3UV', 'O3IR'}
            % Ozone Loschmidt scaling
            species_data.absorption = constant.Loschmidt * species_data.absorption;
            species_data.correction_applied = 'ozone_loschmidt_scaling';
            
        otherwise
            % No corrections needed for other species (O2, N2, CO, CO2, CH4, N2O, H2O)
            species_data.correction_applied = 'none';
    end
    
    % Ensure absorption remains a column vector
    species_data.absorption = species_data.absorption(:);
end