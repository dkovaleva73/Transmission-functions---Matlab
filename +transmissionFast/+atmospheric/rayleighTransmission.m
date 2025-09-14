function Transm = rayleighTransmission(Lam, Config)
    % Approximate Rayleigh transmission of the Earth atmosphere as a
    % function of zenith angle, atmospheric pressure and wavelength.
    % Input :  - Lam (double array): Wavelength array.
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Atmospheric.Zenith_angle_deg
    %            Uses Config.Atmospheric.Pressure_mbar
    %            Uses Config.Data.Wave_units
    % Output : - Transm (double array): The calculated transmission values (0-1).
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253. SMARTS
    % model.
    % Author:    D. Kovaleva (July 2025).
    % Example:   Config = transmissionFast.inputConfig('default');
    %            Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %            Trans = transmissionFast.atmospheric.rayleighTransmission(Lam, Config);   
    arguments
        Lam = []  % Will use cached wavelength array from Config if empty
        Config = transmissionFast.inputConfig()
    end
    
    % Use cached wavelength array if Lam not provided
    if isempty(Lam)
        if isfield(Config, 'WavelengthArray') && ~isempty(Config.WavelengthArray)
            Lam = Config.WavelengthArray;
        else
            % Fallback to calculation if cached array not available
            Lam = transmissionFast.utils.makeWavelengthArray(Config);
        end
    end
    
    % Extract parameters from Config
    Z_ = Config.Atmospheric.Zenith_angle_deg;
    Pressure = Config.Atmospheric.Pressure_mbar;
    WaveUnits = Config.Data.Wave_units;

    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Calculate airmass using fast direct method (no caching)
    Am_ = transmissionFast.utils.airmassFromSMARTS_am('rayleigh', Z_);
    
    % Convert wavelength to Angstroms
    % LamAng = convert.energy('nm',Args.WaveUnits,Lam);
    
    % Calculate Rayleigh optical depth using AstroPack rayleighScattering
    Tau_rayleigh = astro.atmosphere.rayleighScattering(Lam, Pressure, WaveUnits);
    
    % Calculate transmission (no clipping to preserve error detection)
    Transm = exp(-Am_ .* Tau_rayleigh);
end
