function Lam = makeWavelengthArray(Config)
    % Generate wavelength array for photometric calculations
    % Input :  - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.General.Wavelength_min, Wavelength_max, Wavelength_points
    %            Uses Config.Data.Wave_units for output units
    % Output : - Lam (double array): Wavelength array 
    % Notes :  401 points mimics Gaia sampling (dLambda = 2nm)
    %          81 points gives dLambda = 10nm 
    % Author : D. Kovaleva (Jan 2025)
    % Example: Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          % Custom wavelength range:
    %          Config.General.Wavelength_min = 300;
    %          Config.General.Wavelength_max = 1100;
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    arguments
        Config = transmission.inputConfig()
    end
    
    % Extract wavelength parameters from config
    Min_wvl = Config.General.Wavelength_min;
    Max_wvl = Config.General.Wavelength_max;
    Num_points = Config.General.Wavelength_points;
    Wave_units = Config.Data.Wave_units;
    
    LamIni = linspace(Min_wvl, Max_wvl, Num_points);

    % Convert wavelength if needed
    Lam = convert.energy('nm', Wave_units, LamIni);
end