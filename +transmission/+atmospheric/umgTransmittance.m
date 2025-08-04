function Trans = umgTransmittance(Lam, Config)
    % Calculate Uniformly Mixed Gases (UMG) transmittance implementing SMARTS 2.9.5 model.
    % Input  : - Lam (double array): Wavelength array in nm.
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Atmospheric.Zenith_angle_deg
    %            Uses Config.Atmospheric.Temperature_C
    %            Uses Config.Atmospheric.Pressure_mbar
    %            Uses Config.Atmospheric.Components.Molecular_absorption.Co2_ppm
    %            Uses Config.Atmospheric.Components.Molecular_absorption.With_trace_gases
    % Output : Trans (double array): The calculated transmission values (0-1).
    % Author : D. Kovaleva (July 2025) 
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Example:  Config = transmission.inputConfig('default');
    %           Lam = transmission.utils.makeWavelengthArray(Config);
    %           Trans = transmission.atmospheric.umgTransmittance(Lam, Config);
    %           % Custom CO2 concentration:
    %           Config.Atmospheric.Components.Molecular_absorption.Co2_ppm = 415;
    %           Trans = transmission.atmospheric.umgTransmittance(Lam, Config);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config
    Z_ = Config.Atmospheric.Zenith_angle_deg;
    Tair = Config.Atmospheric.Temperature_C;
    Pressure = Config.Atmospheric.Pressure_mbar;
    Co2_ppm = Config.Atmospheric.Components.Molecular_absorption.Co2_ppm;
    With_trace_gases = Config.Atmospheric.Components.Molecular_absorption.With_trace_gases;
    
    % =========================================================================
    % INPUT VALIDATION AND PARAMETER SETUP
    % =========================================================================
    
    % Basic validation
    if Z_ < 0 || Z_ > 90
        error('transmission:umgTransmittance:invalidZenith', 'Zenith angle must be in [0,90] degrees');
    end
    if Pressure <= 0
        error('transmission:umgTransmittance:invalidPressure', 'Pressure must be positive');
    end
    
    % Convert temperature and normalize pressure/temperature
    Tair_kelvin = Tair + 273.15;
    Pp0 = Pressure / 1013.25;
    Tt0 = Tair_kelvin / 273.15;
    
    % Store original shape for output
    original_shape = size(Lam);
    
    % Ensure wavelength array is column vector for cache-friendly access
    Lam = Lam(:);
    Lam_length = length(Lam);
    
    % Pre-allocate total optical depth
    Tau_total = zeros(Lam_length, 1);
    
    % Load absorption data using dedicated module
    UMG_species = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4'};
    if With_trace_gases
        % Add all trace gases to match Python implementation exactly
        trace_species = {'NH3', 'NO', 'NO2', 'SO2U', 'SO2I', 'HNO3', 'NO3', 'HNO2', 'CH2O', 'BrO', 'ClNO'};
        UMG_species = [UMG_species, trace_species];
    end
    
    % Use memory-optimized data loader
    Abs_data = transmission.data.loadAbsorptionData([], UMG_species, false);
    
    % Pre-compute all airmass values at once for better performance
    Am_o2 = transmission.utils.airmassFromSMARTS('o2', Config);
    Am_ch4 = transmission.utils.airmassFromSMARTS('ch4', Config);
    Am_co = transmission.utils.airmassFromSMARTS('co', Config);
    Am_n2o = transmission.utils.airmassFromSMARTS('n2o', Config);
    Am_co2 = transmission.utils.airmassFromSMARTS('co2', Config);
    Am_n2 = transmission.utils.airmassFromSMARTS('n2', Config);
    Am_o4 = Am_o2;  % O4 uses O2 airmass
    
    % Pre-compute trace gas airmass values if needed
    if With_trace_gases
        Am_nh3 = transmission.utils.airmassFromSMARTS('nh3', Config);
        Am_no = transmission.utils.airmassFromSMARTS('no', Config);
        Am_no2 = transmission.utils.airmassFromSMARTS('no2', Config);
        Am_so2 = transmission.utils.airmassFromSMARTS('so2', Config);
        Am_hno3 = transmission.utils.airmassFromSMARTS('hno3', Config);
        Am_no3 = transmission.utils.airmassFromSMARTS('no3', Config);
        Am_hno2 = transmission.utils.airmassFromSMARTS('hno2', Config);
        Am_ch2o = transmission.utils.airmassFromSMARTS('ch2o', Config);
        Am_bro = transmission.utils.airmassFromSMARTS('bro', Config);
        Am_clno = transmission.utils.airmassFromSMARTS('clno', Config);
    end
    

    % Pre-compute all abundance factors (vectorized where possible)
    Abundance_o2 = 1.67766e5 * Pp0;
    Abundance_ch4 = 1.3255 * (Pp0 ^ 1.0574);
    Abundance_co = 0.29625 * (Pp0^2.4480) * exp(0.54669 - 2.4114 * Pp0 + 0.65756 * (Pp0^2));
    Abundance_n2o = 0.24730 * (Pp0^1.0791);
    Abundance_co2 = 0.802685 * Co2_ppm * Pp0;
    Abundance_n2 = 3.8269 * (Pp0^1.8374);
    Abundance_o4 = 1.8171e4 * (constant.Loschmidt^2) * (Pp0^1.7984) / (Tt0^0.344);
    
    % =========================================================================
    % UNIFORMLY MIXED GASES PROCESSING
    % Direct access to pre-loaded absorption data 
    % =========================================================================
    
    % 1. Oxygen (O2)
    if isfield(Abs_data, 'O2')
        O2_abs = interp1(Abs_data.O2.wavelength, Abs_data.O2.absorption, Lam, 'linear', 0);
        Tau_total = Tau_total + O2_abs .* Abundance_o2 .* Am_o2;
    end
    
    % 2. Methane (CH4)
    if isfield(Abs_data, 'CH4')
        Ch4_abs = interp1(Abs_data.CH4.wavelength, Abs_data.CH4.absorption, Lam, 'linear', 0);
        Tau_total = Tau_total + Ch4_abs .* Abundance_ch4 .* Am_ch4;
    end
    
    % 3. Carbon Monoxide (CO)
    if isfield(Abs_data, 'CO')
        Co_abs = interp1(Abs_data.CO.wavelength, Abs_data.CO.absorption, Lam, 'linear', 0);
        Tau_total = Tau_total + Co_abs .* Abundance_co .* Am_co;
    end
    
    % 4. Nitrous Oxide (N2O)
    if isfield(Abs_data, 'N2O')
        N2o_abs = interp1(Abs_data.N2O.wavelength, Abs_data.N2O.absorption, Lam, 'linear', 0);
        Tau_total = Tau_total + N2o_abs .* Abundance_n2o .* Am_n2o;
    end
    
    % 5. Carbon Dioxide (CO2)
    if isfield(Abs_data, 'CO2')
        Co2_abs = interp1(Abs_data.CO2.wavelength, Abs_data.CO2.absorption, Lam, 'linear', 0);
        Tau_total = Tau_total + Co2_abs .* Abundance_co2 .* Am_co2;
    end
    
    % 6. Nitrogen (N2)
    if isfield(Abs_data, 'N2')
        N2_abs = interp1(Abs_data.N2.wavelength, Abs_data.N2.absorption, Lam, 'linear', 0);
        Tau_total = Tau_total + N2_abs .* Abundance_n2 .* Am_n2;
    end
    
    % 7. Oxygen-Oxygen collision complex (O4)
    if isfield(Abs_data, 'O4')
        O4_abs = interp1(Abs_data.O4.wavelength, Abs_data.O4.absorption, Lam, 'linear', 0) * 1e-46;
        Tau_total = Tau_total + O4_abs .* Abundance_o4 .* Am_o4;
    end
    
    % =========================================================================
    % TRACE GASES PROCESSING
    % =========================================================================
    
    if With_trace_gases
  %      fprintf('Processing trace gases...\n');
        
        % TRACE GASES - following Python implementation exactly
        
        % 1. Nitric Acid, HNO3
        if isfield(Abs_data, 'HNO3')
            xs_and_b0 = interp1(Abs_data.HNO3.wavelength, Abs_data.HNO3.absorption, Lam, 'linear', 0);
            if size(Abs_data.HNO3.absorption, 2) >= 2
                xs = xs_and_b0(:, 1);
                b0 = xs_and_b0(:, 2);
                Hno3_abs = 1e-20 * xs .* exp(1e-3 * b0 * (234.2 - 298));  % Loschmidt already in data
            else
                Hno3_abs = xs_and_b0;
            end
            Hno3_abundance = 1e-4 * 3.637 * (Pp0^0.12319);
            Tau_total = Tau_total + Hno3_abs .* Hno3_abundance .* Am_hno3;
        end
        
        % 2. Nitrogen Dioxide, NO2
        if isfield(Abs_data, 'NO2')
            sigma_and_b0 = interp1(Abs_data.NO2.wavelength, Abs_data.NO2.absorption, Lam, 'linear', 0);
            if size(Abs_data.NO2.absorption, 2) >= 2
                sigma = sigma_and_b0(:, 1);
                b0 = sigma_and_b0(:, 2);
                No2_abs = (sigma + b0 * (228.7 - 220));  % Loschmidt already applied in loadAbsorptionData
            else
                No2_abs = sigma_and_b0;
            end
            No2_abundance = 1e-4 * min(1.8599 + 0.18453 * Pp0, 41.771 * Pp0);
            Tau_total = Tau_total + No2_abs .* No2_abundance .* Am_no2;
        end
        
        % 3. Nitrogen Trioxide, NO3
        if isfield(Abs_data, 'NO3')
            xs_and_b0 = interp1(Abs_data.NO3.wavelength, Abs_data.NO3.absorption, Lam, 'linear', 0);
            if size(Abs_data.NO3.absorption, 2) >= 2
                xs = xs_and_b0(:, 1);
                b0 = xs_and_b0(:, 2);
                No3_abs = (xs + b0 * (225.3 - 230));  % Loschmidt already in data
            else
                No3_abs = xs_and_b0;
            end
            No3_abundance = 5e-5;
            Tau_total = Tau_total + No3_abs .* No3_abundance .* Am_no3;
        end
        
       % 4. Nitric Oxide, NO
       if isfield(Abs_data, 'NO')
            No_abs = interp1(Abs_data.NO.wavelength, Abs_data.NO.absorption, Lam, 'linear', 0);
            No_abundance = 1e-4 * min(0.74307 + 2.4015 * Pp0, 57.079 * Pp0);
            Tau_total = Tau_total + No_abs .* No_abundance .* Am_no;
       end
        
        % 5. Sulfur Dioxide, SO2 (combination of SO2U and SO2I)
        So2_abs = zeros(size(Lam));
        if isfield(Abs_data, 'SO2U')
            sigma_and_b0 = interp1(Abs_data.SO2U.wavelength, Abs_data.SO2U.absorption, Lam, 'linear', 0);
            if size(Abs_data.SO2U.absorption, 2) >= 2
                sigma = sigma_and_b0(:, 1);
                b0 = sigma_and_b0(:, 2);
                So2_abs = So2_abs + (sigma + b0 * (247 - 213));  % Loschmidt already in data
            else
                So2_abs = So2_abs + sigma_and_b0;
            end
        end
        if isfield(Abs_data, 'SO2I')
            So2i_abs = interp1(Abs_data.SO2I.wavelength, Abs_data.SO2I.absorption, Lam, 'linear', 0);
            So2_abs = So2_abs + So2i_abs;
        end
        So2_abundance = 1e-4 * 0.11133 * (Pp0^0.812) * exp(0.81319 + 3.0557 * (Pp0^2) - 1.578 * (Pp0^3));
        Tau_total = Tau_total + So2_abs .* So2_abundance .* Am_so2;
        
        % 6. Ammonia, NH3
        if isfield(Abs_data, 'NH3') && Pp0 > 0
            Nh3_abs = interp1(Abs_data.NH3.wavelength, Abs_data.NH3.absorption, Lam, 'linear', 0);
            Log_pp0 = log(Pp0);
            Nh3_abundance = exp(-8.6499 + 2.1947 * Log_pp0 - 2.5936 * (Log_pp0^2) - ...
                               1.819 * (Log_pp0^3) - 0.65854 * (Log_pp0^4));
            Tau_total = Tau_total + Nh3_abs .* Nh3_abundance .* Am_nh3;
        end
        
        % 7. Bromine Monoxide, BrO
        if isfield(Abs_data, 'BrO')
            Bro_abs = interp1(Abs_data.BrO.wavelength, Abs_data.BrO.absorption, Lam, 'linear', 0);  % Loschmidt already in data
            Bro_abundance = 2.5e-6;
            Tau_total = Tau_total + Bro_abs .* Bro_abundance .* Am_bro;
        end
        
        % 8. Formaldehyde, CH2O
        if isfield(Abs_data, 'CH2O')
            xs_and_b0 = interp1(Abs_data.CH2O.wavelength, Abs_data.CH2O.absorption, Lam, 'linear', 0);
            if size(Abs_data.CH2O.absorption, 2) >= 2
                xs = xs_and_b0(:, 1);
                b0 = xs_and_b0(:, 2);
                Ch2o_abs = (xs + b0 * (264 - 293));  % Loschmidt already in data
            else
                Ch2o_abs = xs_and_b0;
            end
            Ch2o_abundance = 3e-4;
            Tau_total = Tau_total + Ch2o_abs .* Ch2o_abundance .* Am_ch2o;
        end
        
        % 9. Nitrous Acid, HNO2
        if isfield(Abs_data, 'HNO2')
            Hno2_abs = interp1(Abs_data.HNO2.wavelength, Abs_data.HNO2.absorption, Lam, 'linear', 0);  % Loschmidt already in data
            Hno2_abundance = 1e-4;
            Tau_total = Tau_total + Hno2_abs .* Hno2_abundance .* Am_hno2;
        end
        
        % 10. Chlorine Nitrate, ClNO3
        if isfield(Abs_data, 'ClNO')
            xs_b0_b1 = interp1(Abs_data.ClNO.wavelength, Abs_data.ClNO.absorption, Lam, 'linear', 0);
            if size(Abs_data.ClNO.absorption, 2) >= 3
                xs = xs_b0_b1(:, 1);
                b0 = xs_b0_b1(:, 2);
                b1 = xs_b0_b1(:, 3);
                TCl = 230;  % K
                Clno_abs = xs * (1 + b0 * (TCl - 296) + b1 * (TCl - 296)^2);  % Loschmidt already in data
            else
                Clno_abs = xs_b0_b1;
            end
            Clno_abundance = 1.2e-4;
            Tau_total = Tau_total + Clno_abs .* Clno_abundance .* Am_clno;
        end
    end
    
    % =========================================================================
    % FINAL TRANSMISSION CALCULATION
    % =========================================================================
    
    % Calculate transmission and clip to [0,1]
    Trans = exp(-Tau_total);
    % No clipping to preserve error detection
    
    % Restore original shape
    if original_shape(1) == 1 && original_shape(2) > 1
        Trans = Trans';  % Original was row vector, transpose back
    end
end

