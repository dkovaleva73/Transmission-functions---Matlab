function Lam = makeWavelengthArray(Config)
    % Generate wavelength array for photometric calculations (CACHED)
    % Input :  - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.WavelengthArray (pre-calculated and cached)
    %            Fallback: Uses Config.General.Wavelength_min, Wavelength_max, Wavelength_points
    %            Uses Config.Data.Wave_units for output units
    % Output : - Lam (double array): Wavelength array 
    % Notes :  401 points mimics Gaia sampling (dLambda = 2nm)
    %          81 points gives dLambda = 10nm 
    % Author : D. Kovaleva (Jan 2025)
    % Example: Config = transmissionFast.inputConfig('default');
    %          Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %          % Custom wavelength range:
    %          Config.General.Wavelength_min = 300;
    %          Config.General.Wavelength_max = 1100;
    %          Lam = transmissionFast.utils.makeWavelengthArray(Config);
    arguments
        Config = transmissionFast.inputConfig()
    end
    
    % Use cached wavelength array from Config if available
    if isfield(Config, 'WavelengthArray') && ~isempty(Config.WavelengthArray)
        Lam = Config.WavelengthArray;
        return;
    end
    
    % Fallback: Calculate wavelength array if cached version not available
    warning('transmissionFast:makeWavelengthArray:usingFallback', ...
            'Using fallback calculation - cached wavelength array not available');
    
    % Extract wavelength parameters from config
    Min_wvl = Config.General.Wavelength_min;
    Max_wvl = Config.General.Wavelength_max;
    Num_points = Config.General.Wavelength_points;
    Wave_units = Config.Data.Wave_units;
    
    LamIni = linspace(Min_wvl, Max_wvl, Num_points);

    % Convert wavelength if needed
    Lam = convert.energy('nm', Wave_units, LamIni);
end