function Trans = ozoneTransmission(Lam, Config)
    % Ozone transmission of the Earth atmosphere.
    % Based on SMARTS 2.9.5 model.
    % Input :  - Lam (double array): Wavelength array.
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Atmospheric.Zenith_angle_deg
    %            Uses Config.Atmospheric.Components.Ozone.Dobson_units
    %            Uses Config.Data.Wave_units
    % Output :  - transmission (double array): The calculated transmission values (0-1).
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    %             2. Garrappa et al. 2025, A&A 699, A50
    % Example:   Config = transmission.inputConfig('default');
    %            Lam = transmission.utils.makeWavelengthArray(Config);
    %            Trans = transmission.atmospheric.ozoneTransmission(Lam, Config);
    %            % Custom ozone column:
    %            Config.Atmospheric.Components.Ozone.Dobson_units = 350;
    %            Trans = transmission.atmospheric.ozoneTransmission(Lam, Config);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config
    Z_ = Config.Atmospheric.Zenith_angle_deg;
    Dobson_units = Config.Atmospheric.Components.Ozone.Dobson_units;
    WaveUnits = Config.Data.Wave_units;  
    
    % Convert Dobson units to atm-cm
    Ozone_atm_cm = Dobson_units * 0.001;
    
    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Calculate airmass using SMARTS coefficients for ozone
    Am_ = transmission.utils.airmassFromSMARTS('o3', Config);
    

    % Load ozone absorption data using dedicated module
    Abs_data = transmission.data.loadAbsorptionData([], {'O3UV'}, false);
    
    % Extract ozone cross-section data directly
    if ~isfield(Abs_data, 'O3UV')
        error('O3UV data not found in absorption data structure');
    end
    
    Abs_wavelength = Abs_data.O3UV.wavelength;
    Ozone_cross_section = Abs_data.O3UV.absorption;
    
    
    % Interpolate ozone cross-sections to wavelength array
    Ozone_xs_interp = interp1(Abs_wavelength, Ozone_cross_section, Lam, 'linear', 0);
    %Ozone_xs_interp = tools.interp.interp1evenlySpaced(Abs_wavelength, Ozone_cross_section, Lam);

    % Absorption coefficients are already corrected in loadAbsorptionData
    Absorption_coeff = Ozone_xs_interp;
    
  
    % Calculate optical depth
    Tau_ozone = Absorption_coeff * Ozone_atm_cm;
    
    % Calculate transmission (no clipping to preserve error detection)
    Trans = exp(-Am_ .* Tau_ozone);
end
