function Config = inputConfig(scenario)
    % Central configuration for all transmission calculations
    % Input:  scenario (string) - Configuration scenario name
    %         'default' - Standard configuration with all components
    %         'minimal' - Essential components only
    %         'atmospheric_only' - Only atmospheric transmission
    %         'instrumental_only' - Only instrumental transmission
    %         'custom' - Base configuration for user modification
    % Output: Config (struct) - Complete configuration structure
    % Author: D. Kovaleva (Jul 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502;
    %             2. Garrappa et al. 2025, A&A 699, A50.
    %             3. Gueymard, C. A. (2019). Solar Energy, 187, 233-253. 
    % Example: % Get default configuration
    %          config = transmission.inputConfig('default');
    %          % Modify water vapor
    %          config.atmospheric.components.water.pwv_mm = 20;
    %          % Disable aerosols
    %          config.atmospheric.components.aerosol.enable = false;
    
    arguments
        scenario = 'default'
    end
    
    % Initialize base configuration
    Config = struct();
    
    % 1. GENERAL SETTINGS
    Config.General = struct(...
        'Wavelength_min', 300, ... %336, ...       % nm (optical astronomy range)
        'Wavelength_max', 1100, ...%1020, ...      % nm
        'Wavelength_points', 401, ...%343, ...    % number of points (~2nm resolution)
        'Enable_atmospheric', true, ...
        'Enable_instrumental', true, ...
        'Norm_', 0.5 ...
    );
    
    % DATA LOADING CONFIGURATION
    Config.Data = struct(...
        'Wave_units', 'nm', ...
        'LAST_AstroImage_file', '/home/dana/matlab/data/transmission_fitter/LASTfiles/Coadd.mat', ...
        'LAST_catalog_file', "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.10.04_20240311.194154.510_clear_923_010_001_016_sci_proc_Cat_1.fits", ...
        'Search_radius_arcsec', 1.0 ...  % Search radius for Gaia-LAST cross-matching
    );
          %  'LAST_catalog_file', "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.08.03_20230616.222625.384_clear_346+79_000_001_001_sci_coadd_Cat_1.fits", ...
         % 'LAST_catalog_file', "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.10.04_20240311.194154.510_clear_923_010_001_004_sci_proc_Cat_1.fits", ...
      %'LAST_catalog_file', "/home/dana/matlab/data/transmission_fitter/LASTfiles/LAST.01.10.04_20240303.191215.553_clear_923_002_001_016_sci_proc_Cat_1.fits", ...
          % UTILS FUNCTIONS CONFIGURATION
    Config.Utils = struct(...
        'LegendreModel', struct(...
            'Default_coeffs', [-0.30, 0.34, -1.89, -0.82, -3.73, -0.669, -2.06, -0.24, -0.60] ...
        ), ...
        'ChebyshevModel', struct(...
            'Default_coeffs', [0.0, 0.0, 0.0, 0.0, 0.0], ...
            'Default_mode', 'zp', ...    % 'tr' for transmission, 'zp' for zero-point
            'Normalization_range', [-1.0, 1.0] ... % Fixed range for Chebyshev
        ), ...
        'RescaleInputData', struct(...
            'Target_min', -1.0, ...      % Default rescaling target minimum
            'Target_max', 1.0 ...        % Default rescaling target maximum
        ), ...
        'SkewedGaussianModel', struct(...
            'Default_amplitude', 328.1936, ...
            'Default_center', 570.973, ... % nm
            'Default_sigma', 139.77, ...  % nm
            'Default_gamma', -0.1517 ...  % Skewness parameter
        ), ...
        'Gaia_wavelength', 336:2:1020 ... % Gaia XP wavelength grid: 336-1020 nm in 2 nm steps (343 points)
    );

    % 2. ATMOSPHERIC TRANSMISSION
    Config.Atmospheric = struct(...
        'Enable', true, ...
        'Zenith_angle_deg', 0, ...     % Zenith angle (0=zenith, airmass calculated via airmassFromSMARTS)fals
        'Pressure_mbar', 965, ... %1013.25, ...    % Atmospheric pressure (mbar)
        'Temperature_C', 15.2, ...       % Air temperature (°C)
        'Components', struct(...
            'Rayleigh', struct(...
                'Enable', true ...       % Uses astro.atmosphere.rayleighScattering()
            ), ...
            'Ozone', struct(...
                'Enable', true, ...
                'Dobson_units', 300 ...  % Ozone column (250-350 DU typical)
            ), ...
            'Water', struct(...
                'Enable', true, ...
                'Pwv_cm', 1.4 ...        % Precipitable water vapor in cm
            ), ...
            'Aerosol', struct(...
                'Enable', true, ...
                'Tau_aod500', 0.084, ...   % AOD at 500nm (0.05 excellent, 0.54 sand storm)
                'Angstrom_exponent', 0.6 ... % ~ no wavelength dependence in optical region in desert-like conditions
            ), ...
            'Molecular_absorption', struct(...
                'Enable', true, ...
                'Co2_ppm', 395, ...      % CO2 concentration (current atmospheric)
                'With_trace_gases', true ... % Include NH3, NO, NO2, etc.
            ) ...
        ) ...
    );
    
    % 3. INSTRUMENTAL TRANSMISSION (OTA)
    Config.Instrumental = struct(...
        'Enable', true, ...
        'Telescope', struct(...
            'Aperture_diameter_m', 0.1397, ...   % LAST telescope aperture diameter (m)
            'Aperture_area_m2', pi * (0.1397^2), ... % Calculated aperture area (m²)
            'Name', 'LAST' ...                   % Telescope identification
        ), ...
        'Detector', struct(...
            'Size_pixels', 1726, ...         % LAST detector size (square)
            'Min_coordinate', 0.0, ...       % Minimum pixel coordinate
            'Max_coordinate', 1726.0 ...     % Maximum pixel coordinate
        ), ...
        'Components', struct(...
            'Quantum_efficiency', struct(...
                'Enable', true ...  % Parameters taken from Config.Utils
            ), ...
            'Mirror', struct(...
                'Enable', true, ...
                'Use_data_file', true, ...
                'Data_file', '/home/dana/matlab/data/transmission_fitter/StarBrightXLT_Mirror_Reflectivity.csv', ...
                'Method', 'polyfit_' ...     % 'polyfit_' or 'piecewise_'
            ), ...
            'Corrector', struct(...
                'Enable', true, ...
                'Use_data_file', true, ...
                'Data_file', '/home/dana/matlab/data/transmission_fitter/StarBrightXLT_Corrector_Trasmission.csv', ...
                'Method', 'polyfit_' ...    
            ), ...
            'Chebyshev', struct(...
                'Enable', true ...  % Coeffs and Mode taken from Config.Utils.ChebyshevModel
            ), ...
            'Field_correction', struct(...
                'Enable', false, ...         % Field-dependent corrections
                'Reference_x', 0, ...        % Reference field position
                'Reference_y', 0, ...        % Reference field position
                'Kx0', 0.0, ...              % X offset
                'Ky0', 0.0, ...              % Y offset
                'Kx_coeffs', 0.0, ...      % X Chebyshev coefficients
                'Ky_coeffs', 0.0, ...      % Y Chebyshev coefficients
                'Kxy_coeffs', 0.0 ...      % Cross-term coefficients
            ) ...
        ) ...
    );
    
    % 4. FIELD CORRECTION SETTINGS (for Python model compatibility)
    Config.FieldCorrection = struct(...
        'Enable', false, ...              % Enable field corrections
        'Mode', 'none', ...               % 'none', 'simple', or 'python'
        'Python', struct(...              % Python field correction parameters
            'kx0', 0.0, ...               % Constant offset X
            'ky0', 0.0, ...               % Constant offset Y (usually fixed at 0)
            'kx', 0.0, ...                % Linear term X
            'ky', 0.0, ...                % Linear term Y
            'kx2', 0.0, ...               % Quadratic term X
            'ky2', 0.0, ...               % Quadratic term Y
            'kx3', 0.0, ...               % Cubic term X
            'ky3', 0.0, ...               % Cubic term Y
            'kx4', 0.0, ...               % Quartic term X
            'ky4', 0.0, ...               % Quartic term Y
            'kxy', 0.0 ...                % Cross term XY
        ), ...
        'Simple', struct(...              % Simple Chebyshev field correction
            'cx0', 0.0, ...               % X order 0
            'cx1', 0.0, ...               % X order 1
            'cx2', 0.0, ...               % X order 2
            'cx3', 0.0, ...               % X order 3
            'cx4', 0.0, ...               % X order 4
            'cy0', 0.0, ...               % Y order 0
            'cy1', 0.0, ...               % Y order 1
            'cy2', 0.0, ...               % Y order 2
            'cy3', 0.0, ...               % Y order 3
            'cy4', 0.0 ...                % Y order 4
        ) ...
    );
    
    % 5. TOTAL TRANSMISSION SETTINGS
    Config.Total = struct(...
        'Multiply_components', true, ... % atmospheric * instrumental
        'Check_bounds', true, ...        % Verify 0 <= transmission <= 1
        'Warn_out_of_bounds', true ...   % Issue warning if transmission out of bounds
    );
    
    % 6. DISPLAY AND OUTPUT SETTINGS
    Config.Utils.Display = struct(...
        'Show_summary', false, ...        % Display transmission summary
        'Show_plots', false ...          % Generate plots when no output requested
    );
    
    Config.Output = struct(...
        'Save_components', true, ...     % Save individual component transmissions
        'Plot_results', false, ...       % Generate plots
        'Verbose', false ...             % Print calculation progress
    );
    
    % 7. OPTIMIZATION BOUNDS (from Python AbsoluteCalibration class)
    Config.Optimization = struct();
    Config.Optimization.Bounds = getDefaultOptimizationBounds();
    
    % Apply scenario-specific settings
    switch lower(scenario)
        case 'default'
            % Use defaults as defined above
            
        case 'minimal'
            % Minimal setup - only essential components
            Config.Atmospheric.Components.Aerosol.Enable = false;
            Config.Atmospheric.Components.Molecular_absorption.Enable = false;
            Config.Instrumental.Components.Field_correction.Enable = false;
            Config.Utils.ChebyshevModel.Default_coeffs = [0.0, 0.0, 0.0, 0.0, 0.0];
            
        case 'atmospheric_only'
            Config.General.Enable_instrumental = false;
            Config.Instrumental.Enable = false;
            
        case 'instrumental_only'
            Config.General.Enable_atmospheric = false;
            Config.Atmospheric.Enable = false;
            
        case 'dry_conditions'
            % Low water vapor scenario
            Config.Atmospheric.Components.Water.Pwv_cm = 0.2;  % 2mm
            
        case 'humid_conditions'
            % High water vapor scenario  
            Config.Atmospheric.Components.Water.Pwv_cm = 3.0;  % 30mm
            
        case 'high_altitude'
            % High altitude observatory (e.g., Mauna Kea)
            Config.Atmospheric.Pressure_mbar = 610.0;  % ~4.2km altitude
            Config.Atmospheric.Components.Water.Pwv_cm = 0.2;  % Very dry
            Config.Atmospheric.Components.Aerosol.Tau_aod500 = 0.02;  % Excellent conditions
            
        case 'sea_level'
            % Sea level observatory
            Config.Atmospheric.Pressure_mbar = 1013.25;
            Config.Atmospheric.Components.Water.Pwv_cm = 2.0;  % 20mm
            
        case 'photometric_night'
            % Excellent photometric conditions
            Config.Atmospheric.Components.Water.Pwv_cm = 0.5;  % 5mm
            Config.Atmospheric.Components.Aerosol.Tau_aod500 = 0.05;
            Config.Atmospheric.Components.Aerosol.Angstrom_exponent = 1.5;
            
        case 'dusty_conditions'
            % High aerosol loading
            Config.Atmospheric.Components.Aerosol.Tau_aod500 = 0.3;
            Config.Atmospheric.Components.Aerosol.Angstrom_exponent = 0.8;
            
        case 'python_field_correction'
            % Enable Python field correction model
            Config.FieldCorrection.Enable = true;
            Config.FieldCorrection.Mode = 'python';
            % Parameters will be set by optimizer
            
        case 'simple_field_correction'
            % Enable simple Chebyshev field correction model
            Config.FieldCorrection.Enable = true;
            Config.FieldCorrection.Mode = 'simple';
            % Parameters will be set by optimizer
            
        case 'custom'
            % Base configuration for user modification
            % User should modify the returned config struct
            
        otherwise
            warning('transmission:inputConfig:unknownScenario', ...
                    'Unknown scenario: %s. Using default configuration.', scenario);
    end
    
    % Validate configuration
    validateConfig(Config);
end

function validateConfig(Config)
    % Validate configuration parameters
    
    % Check wavelength range
    if Config.General.Wavelength_min >= Config.General.Wavelength_max
        error('transmission:inputConfig:invalidWavelength', ...
              'Wavelength_min must be less than Wavelength_max');
    end
    
    % Check physical parameters
    if Config.Atmospheric.Zenith_angle_deg < 0 || Config.Atmospheric.Zenith_angle_deg > 90
        error('transmission:inputConfig:invalidZenith', ...
              'Zenith angle must be between 0 and 90 degrees');
    end
    
    if Config.Atmospheric.Pressure_mbar <= 0
        error('transmission:inputConfig:invalidPressure', ...
              'Atmospheric pressure must be > 0 mbar');
    end
    
    if Config.Atmospheric.Components.Water.Pwv_cm < 0
        error('transmission:inputConfig:invalidPWV', ...
              'Precipitable water vapor must be >= 0 cm');
    end
    
    if Config.Atmospheric.Components.Ozone.Dobson_units < 0
        error('transmission:inputConfig:invalidOzone', ...
              'Ozone column must be >= 0 Dobson units');
    end
    
    if Config.Atmospheric.Components.Aerosol.Tau_aod500 < 0
        error('transmission:inputConfig:invalidAOD', ...
              'Aerosol optical depth must be >= 0');
    end
    
    if Config.Atmospheric.Components.Molecular_absorption.Co2_ppm < 0
        error('transmission:inputConfig:invalidCO2', ...
              'CO2 concentration must be >= 0 ppm');
    end
    
    % Check instrumental file paths if components are enabled
    if Config.Instrumental.Components.Mirror.Enable && ...
       Config.Instrumental.Components.Mirror.Use_data_file
        if isempty(Config.Instrumental.Components.Mirror.Data_file) || ...
           ~exist(Config.Instrumental.Components.Mirror.Data_file, 'file')
            warning('transmission:inputConfig:missingFile', ...
                    'Mirror data file not found: %s', ...
                    Config.Instrumental.Components.Mirror.Data_file);
        end
    end
    
    if Config.Instrumental.Components.Corrector.Enable && ...
       Config.Instrumental.Components.Corrector.Use_data_file
        if isempty(Config.Instrumental.Components.Corrector.Data_file) || ...
           ~exist(Config.Instrumental.Components.Corrector.Data_file, 'file')
            warning('transmission:inputConfig:missingFile', ...
                    'Corrector data file not found: %s', ...
                    Config.Instrumental.Components.Corrector.Data_file);
        end
    end
end

function bounds = getDefaultOptimizationBounds()
    % Default parameter bounds from Python AbsoluteCalibration class
    % These bounds are designed to keep parameters within physically reasonable ranges
    
    bounds = struct();
    
    % Lower bounds
    bounds.Lower = struct();
    bounds.Lower.Norm_ = 0.1;           % Normalization factor  
    bounds.Lower.Center = 300;          % QE center wavelength (nm) - from Python AbsoluteCalibration
    bounds.Lower.Amplitude = 0.5;       % QE amplitude
    bounds.Lower.Sigma = 500;           % QE sigma (nm)
    bounds.Lower.Gamma = 0.1;           % QE gamma
    bounds.Lower.Pwv_cm = 0.1;          % Water vapor (cm)
    bounds.Lower.Tau_aod500 = 0.0;      % Aerosol optical depth
    bounds.Lower.Alpha = 0.5;           % Aerosol Angstrom exponent
    bounds.Lower.Dobson_units = 200;    % Ozone (DU)
    bounds.Lower.Temperature_C = -20;   % Temperature (°C)
    bounds.Lower.Pressure = 800;        % Pressure (hPa)
    
    % Chebyshev field correction bounds (simple mode)
    for i = 0:4
        bounds.Lower.(sprintf('cx%d', i)) = -0.5;
        bounds.Lower.(sprintf('cy%d', i)) = -0.5;
    end
    
    % Python field correction bounds
    bounds.Lower.kx0 = -0.3;            % Constant offset X
    bounds.Lower.ky0 = -0.3;            % Constant offset Y (typically fixed at 0)
    bounds.Lower.kx = -0.2;             % Linear term X
    bounds.Lower.ky = -0.2;             % Linear term Y
    bounds.Lower.kx2 = -0.1;            % Quadratic term X
    bounds.Lower.ky2 = -0.1;            % Quadratic term Y
    bounds.Lower.kx3 = -0.05;           % Cubic term X
    bounds.Lower.ky3 = -0.05;           % Cubic term Y
    bounds.Lower.kx4 = -0.02;           % Quartic term X
    bounds.Lower.ky4 = -0.02;           % Quartic term Y
    bounds.Lower.kxy = -0.1;            % Cross term XY
    
    % Upper bounds
    bounds.Upper = struct();
    bounds.Upper.Norm_ = 2.0;           % Normalization factor
    bounds.Upper.Center = 1000;         % QE center wavelength (nm) - from Python AbsoluteCalibration  
    bounds.Upper.Amplitude = 2.0;       % QE amplitude
    bounds.Upper.Sigma = 3000;          % QE sigma (nm)
    bounds.Upper.Gamma = 2.0;           % QE gamma
    bounds.Upper.Pwv_cm = 10.0;         % Water vapor (cm)
    bounds.Upper.Tau_aod500 = 1.0;      % Aerosol optical depth
    bounds.Upper.Alpha = 3.0;           % Aerosol Angstrom exponent
    bounds.Upper.Dobson_units = 500;    % Ozone (DU)
    bounds.Upper.Temperature_C = 50;    % Temperature (°C)
    bounds.Upper.Pressure = 1100;       % Pressure (hPa)
    
    % Chebyshev field correction bounds (simple mode)
    for i = 0:4
        bounds.Upper.(sprintf('cx%d', i)) = 0.5;
        bounds.Upper.(sprintf('cy%d', i)) = 0.5;
    end
    
    % Python field correction bounds
    bounds.Upper.kx0 = 0.3;             % Constant offset X
    bounds.Upper.ky0 = 0.3;             % Constant offset Y (typically fixed at 0)
    bounds.Upper.kx = 0.2;              % Linear term X
    bounds.Upper.ky = 0.2;              % Linear term Y
    bounds.Upper.kx2 = 0.1;             % Quadratic term X
    bounds.Upper.ky2 = 0.1;             % Quadratic term Y
    bounds.Upper.kx3 = 0.05;            % Cubic term X
    bounds.Upper.ky3 = 0.05;            % Cubic term Y
    bounds.Upper.kx4 = 0.02;            % Quartic term X
    bounds.Upper.ky4 = 0.02;            % Quartic term Y
    bounds.Upper.kxy = 0.1;             % Cross term XY
end