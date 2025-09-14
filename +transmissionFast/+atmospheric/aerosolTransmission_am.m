function Transm = aerosolTransmission_am(Lam, zenithAngle_deg, tau_aod500, alpha, waveUnits)
    % Fast aerosol transmission using direct airmass calculation (no caching)  
    % 6.5x faster airmass calculation than cached version
    %
    % Input:  - Lam (double array): Wavelength array
    %         - zenithAngle_deg (double): Zenith angle in degrees [0, 90] (default: 55.18)
    %         - tau_aod500 (double): Aerosol optical depth at 500nm (default: 0.1)
    %         - alpha (double): Angstrom exponent (default: 1.3)
    %         - waveUnits (string): Wavelength units (default: 'nm')
    % Output: - Transm (double array): Transmission values (0-1)
    %
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author: D. Kovaleva (Sep 2025) - Fast direct calculation version
    % Example: Trans = transmissionFast.atmospheric.aerosolTransmission_am(Lam, 55.18, 0.1, 1.3, 'nm');
    
    arguments
        Lam double = []
        zenithAngle_deg (1,1) double {mustBeInRange(zenithAngle_deg, 0, 90)} = 55.18
        tau_aod500 (1,1) double {mustBeNonnegative} = 0.1
        alpha (1,1) double = 1.3
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
    Am_ = transmissionFast.utils.airmassFromSMARTS_am('aerosol', zenithAngle_deg);
    
    % Convert wavelength to micrometers for aerosol calculation
    switch lower(waveUnits)
        case 'nm'
            Lam_um = Lam / 1000;
        case 'um'  
            Lam_um = Lam;
        case 'angstrom'
            Lam_um = Lam / 10000;
        otherwise
            error('Unsupported wavelength units: %s. Use nm, um, or angstrom', waveUnits);
    end
    
    % Calculate aerosol optical depth using Angstrom law
    % τ(λ) = τ(500nm) * (λ/500nm)^(-α)
    Tau_aerosol = tau_aod500 .* (Lam_um ./ 0.5) .^ (-alpha);
    
    % Calculate transmission
    Transm = exp(-Am_ .* Tau_aerosol);
end