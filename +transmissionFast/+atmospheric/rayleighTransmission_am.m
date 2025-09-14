function Transm = rayleighTransmission_am(Lam, zenithAngle_deg, pressure_mbar, waveUnits)
    % Fast Rayleigh transmission using direct airmass calculation (no caching)
    % 6.5x faster airmass calculation than cached version
    %
    % Input:  - Lam (double array): Wavelength array
    %         - zenithAngle_deg (double): Zenith angle in degrees [0, 90] (default: 55.18)
    %         - pressure_mbar (double): Atmospheric pressure in mbar (default: 1013.25)  
    %         - waveUnits (string): Wavelength units (default: 'nm')
    % Output: - Transm (double array): Transmission values (0-1)
    %
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author: D. Kovaleva (Sep 2025) - Fast direct calculation version
    % Example: Trans = transmissionFast.atmospheric.rayleighTransmission_am(Lam, 55.18, 1013.25, 'nm');
    
    arguments
        Lam double = []
        zenithAngle_deg (1,1) double {mustBeInRange(zenithAngle_deg, 0, 90)} = 55.18
        pressure_mbar (1,1) double {mustBePositive} = 1013.25
        waveUnits string = "nm"
    end
    
    % Use cached wavelength array if not provided
    if isempty(Lam)
        Config = transmissionFast.inputConfig();
        if isfield(Config, 'WavelengthArray') && ~isempty(Config.WavelengthArray)
            Lam = Config.WavelengthArray;
        else
            Lam = transmissionFast.utils.makeWavelengthArray(Config);
        end
    end
    
    % Calculate airmass using fast direct method (no caching)
    Am_ = transmissionFast.utils.airmassFromSMARTS_am('rayleigh', zenithAngle_deg);
    
    % Calculate Rayleigh optical depth using AstroPack
    Tau_rayleigh = astro.atmosphere.rayleighScattering(Lam, pressure_mbar, waveUnits);
    
    % Calculate transmission
    Transm = exp(-Am_ .* Tau_rayleigh);
end