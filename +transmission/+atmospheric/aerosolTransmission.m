function Transm = aerosolTransmission(Lam, Config)
    % Approximate Aerosol transmission of the Earth atmosphere as a
    % function of zenith angle, aerosol optical depth, Angstrom's exponent 
    % and wavelength.
    % Input :   - Lam (double array): Wavelength array.
    %           - Config (struct): Configuration struct from inputConfig()
    %             Uses Config.Atmospheric.Zenith_angle_deg
    %             Uses Config.Atmospheric.Components.Aerosol.Tau_aod500
    %             Uses Config.Atmospheric.Components.Aerosol.Angstrom_exponent
    %             Uses Config.Data.Wave_units
    % Output :  - Transm (double array): The calculated transmission values (0-1).
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author  :  D. Kovaleva (July 2025).
    % Example :  Config = transmission.inputConfig('default');
    %            Lam = transmission.utils.makeWavelengthArray(Config);
    %            Trans = transmission.atmospheric.aerosolTransmission(Lam, Config);
    %            % Custom AOD:
    %            Config.Atmospheric.Components.Aerosol.Tau_aod500 = 0.1;
    %            Trans = transmission.atmospheric.aerosolTransmission(Lam, Config);    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config
    Z_ = Config.Atmospheric.Zenith_angle_deg;
    Tau_aod500 = Config.Atmospheric.Components.Aerosol.Tau_aod500;
    Alpha = Config.Atmospheric.Components.Aerosol.Angstrom_exponent;
    WaveUnits = Config.Data.Wave_units;  
    
    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Calculate airmass using SMARTS coefficients for aerosol, Gueymard, C. A. (2019) 
    Am_ = transmission.utils.airmassFromSMARTS('aerosol', Config);

    % Convert wavelength to Angstrom
    %  LamAng = convert.energy(Args.WaveUnits,'Ang',Lam);

    % Calculate aerosol optical depth using AstroPack aerosolScattering
    Tau_lambda = astro.atmosphere.aerosolScattering(Lam, Tau_aod500, Alpha, WaveUnits);

    % Calculate transmission (no clipping to preserve error detection)
    Transm = exp(-Am_ .* Tau_lambda);
end
