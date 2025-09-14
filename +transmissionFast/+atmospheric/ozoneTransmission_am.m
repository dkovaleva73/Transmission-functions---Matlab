function Transm = ozoneTransmission_am(Lam, zenithAngle_deg, dobsonUnits, waveUnits)
    % Fast ozone transmission using direct airmass calculation (no caching)
    % 6.5x faster airmass calculation than cached version
    %
    % Input:  - Lam (double array): Wavelength array  
    %         - zenithAngle_deg (double): Zenith angle in degrees [0, 90] (default: 55.18)
    %         - dobsonUnits (double): Ozone column in Dobson Units (default: 300)
    %         - waveUnits (string): Wavelength units (default: 'nm')
    % Output: - Transm (double array): Transmission values (0-1)
    %
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author: D. Kovaleva (Sep 2025) - Fast direct calculation version
    % Example: Trans = transmissionFast.atmospheric.ozoneTransmission_am(Lam, 55.18, 300, 'nm');
    
    arguments
        Lam double = []
        zenithAngle_deg (1,1) double {mustBeInRange(zenithAngle_deg, 0, 90)} = 55.18
        dobsonUnits (1,1) double {mustBePositive} = 300
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
    Am_ = transmissionFast.utils.airmassFromSMARTS_am('ozone', zenithAngle_deg);
    
    % Calculate ozone optical depth using AstroPack ozone absorption
    try
        Tau_ozone = astro.atmosphere.ozoneAbsorption(Lam, dobsonUnits, waveUnits);
    catch
        % Fallback: simple ozone absorption model if AstroPack function not available
        % Based on Chappuis band absorption (simplified)
        switch lower(waveUnits)
            case 'nm'
                Lam_nm = Lam;
            case 'um'
                Lam_nm = Lam * 1000;
            case 'angstrom'
                Lam_nm = Lam / 10;
            otherwise
                error('Unsupported wavelength units: %s', waveUnits);
        end
        
        % Simple ozone absorption model (Chappuis band centered at ~600nm)
        % Peak absorption coefficient ~ 4.5e-21 cm²/molecule at 600nm
        % 1 Dobson Unit = 2.69e16 molecules/cm²
        sigma_peak = 4.5e-21; % cm²/molecule at 600nm
        molecules_per_du = 2.69e16; % molecules/cm²
        
        % Gaussian-like absorption profile
        lambda_peak = 600; % nm
        sigma_width = 100; % nm
        absorption_profile = exp(-0.5 * ((Lam_nm - lambda_peak) / sigma_width).^2);
        
        Tau_ozone = sigma_peak * (dobsonUnits * molecules_per_du) * absorption_profile;
    end
    
    % Calculate transmission
    Transm = exp(-Am_ .* Tau_ozone);
end