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
        'Enable_instrumental', true ...
    );
    
    % DATA LOADING CONFIGURATION
    Config.Data = struct(...
        'Wave_units', 'nm' ...
    );
    
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
        'Zenith_angle_deg', 0.0, ...     % Zenith angle (0=zenith, airmass calculated via airmassFromSMARTS)
        'Pressure_mbar', 1013.25, ...    % Atmospheric pressure (mbar)
        'Temperature_C', 15.0, ...       % Air temperature (°C)
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
                'Pwv_cm', 1.0 ...        % Precipitable water vapor in cm
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
                'Method', 'polyfit_' ...     % 'polyfit_' or 'piecewise_'
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
                'Kx_coeffs', [0.0], ...      % X Chebyshev coefficients
                'Ky_coeffs', [0.0], ...      % Y Chebyshev coefficients
                'Kxy_coeffs', [0.0] ...      % Cross-term coefficients
            ) ...
        ) ...
    );
    
    % 4. TOTAL TRANSMISSION SETTINGS
    Config.Total = struct(...
        'Multiply_components', true, ... % atmospheric * instrumental
        'Check_bounds', true, ...        % Verify 0 <= transmission <= 1
        'Warn_out_of_bounds', true ...   % Issue warning if transmission out of bounds
    );
    
    % 5. DISPLAY AND OUTPUT SETTINGS
    Config.Utils.Display = struct(...
        'Show_summary', false, ...        % Display transmission summary
        'Show_plots', false ...          % Generate plots when no output requested
    );
    
    Config.Output = struct(...
        'Save_components', true, ...     % Save individual component transmissions
        'Plot_results', false, ...       % Generate plots
        'Verbose', false ...             % Print calculation progress
    );
    
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