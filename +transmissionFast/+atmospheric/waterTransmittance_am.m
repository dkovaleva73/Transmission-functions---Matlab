function Transm = waterTransmittance_am(Lam, zenithAngle_deg, pwv_cm, waveUnits)
    % Fast water vapor transmission using direct airmass calculation (no caching)
    % 6.5x faster airmass calculation than cached version
    %
    % Input:  - Lam (double array): Wavelength array
    %         - zenithAngle_deg (double): Zenith angle in degrees [0, 90] (default: 55.18)
    %         - pwv_cm (double): Precipitable water vapor in cm (default: 2.5)
    %         - waveUnits (string): Wavelength units (default: 'nm')
    % Output: - Transm (double array): Transmission values (0-1)
    %
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author: D. Kovaleva (Sep 2025) - Fast direct calculation version  
    % Example: Trans = transmissionFast.atmospheric.waterTransmittance_am(Lam, 55.18, 2.5, 'nm');
    
    arguments
        Lam double = []
        zenithAngle_deg (1,1) double {mustBeInRange(zenithAngle_deg, 0, 90)} = 55.18
        pwv_cm (1,1) double {mustBeNonnegative} = 2.5
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
    Am_ = transmissionFast.utils.airmassFromSMARTS_am('water', zenithAngle_deg);
    
    % Calculate water vapor optical depth using AstroPack
    try
        Tau_water = astro.atmosphere.waterVaporAbsorption(Lam, pwv_cm, waveUnits);
    catch
        % Fallback: Load cached absorption data if AstroPack function not available
        Config = transmissionFast.inputConfig();
        if isfield(Config, 'AbsorptionData') && isfield(Config.AbsorptionData, 'H2O')
            % Use cached absorption coefficients
            AbsData = Config.AbsorptionData.H2O;
            
            % Convert wavelength to match absorption data units
            switch lower(waveUnits)
                case 'nm'
                    Lam_query = Lam;
                case 'um'
                    Lam_query = Lam * 1000;
                case 'angstrom'
                    Lam_query = Lam / 10;
                otherwise
                    error('Unsupported wavelength units: %s', waveUnits);
            end
            
            % Interpolate absorption coefficients
            if isfield(AbsData, 'Wavelength') && isfield(AbsData, 'CrossSection')
                absorption_coef = interp1(AbsData.Wavelength, AbsData.CrossSection, Lam_query, 'linear', 0);
            else
                error('Invalid absorption data structure');
            end
            
            % Calculate optical depth: τ = σ * N * PWV
            % where σ is cross-section, N is number density, PWV is column amount
            % Simplified: τ ≈ absorption_coef * pwv_cm
            Tau_water = absorption_coef * pwv_cm;
            
        else
            error('Water vapor absorption data not available and AstroPack function failed');
        end
    end
    
    % Calculate transmission
    Transm = exp(-Am_ .* Tau_water);
end