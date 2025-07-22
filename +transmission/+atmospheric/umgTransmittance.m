function transmission = umgTransmittance(Z_, Tair, Pressure, Lam, Co2_ppm, With_trace_gases, Args)
    % Calculate Uniformly Mixed Gases (UMG) transmission.
    % MEMORY OPTIMIZED VERSION: Enhanced for better memory layout and cache performance
    % Input :
    %   Z_ (double): The zenith angle in degrees.
    %   Tair (double): Air temperature in degrees Celsius.
    %   Pressure (double): Atmospheric pressure in hPa.
    %   Lam (double array): Wavelength array in nm.
    %   Co2_ppm (double): CO2 concentration in ppm (default: 395).
    %   With_trace_gases (logical): Include trace gases (default: true).
    %   Args.AbsData (struct, optional): Pre-loaded absorption data from loadAbsorptionData()
    %
    % Returns:
    %   transmission (double array): The calculated transmission values (0-1).
    %
    % Author: D. Kovaleva (July 2025) - Memory optimized version
    % Reference: SMARTS 2.9.5 model implementation
    %
    % Example:
    %   % Standalone usage (loads data internally):
    %   Lam = transmission.utils.makeWavelengthArray();
    %   Trans = transmission.atmospheric.umgTransmittanceOptimized(30, 15, 1013.25, Lam, 415, true);
    %   
    %   % Pipeline usage (RECOMMENDED for best performance):
    %   Abs_data = transmission.data.loadAbsorptionData();
    %   Trans = transmission.atmospheric.umgTransmittanceOptimized(30, 15, 1013.25, Lam, 415, true, 'AbsData', Abs_data);
    
    arguments
        Z_
        Tair 
        Pressure
        Lam
        Co2_ppm = 395.0
        With_trace_gases = true
        Args.AbsData = [];
    end
    
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
    
    % Ensure wavelength array is column vector for cache-friendly access
    Lam = Lam(:);
    Lam_length = length(Lam);
    
    % Pre-allocate total optical depth
    Tau_total = zeros(Lam_length, 1);
    
    % =========================================================================
    % EFFICIENT DATA LOADING WITH MEMORY-OPTIMIZED LOADER
    % =========================================================================
    
    % Get absorption data using memory-optimized loader
    if isempty(Args.AbsData)
        % Load all UMG species at once for better I/O performance
        UMG_species = {'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4'};
        if With_trace_gases
            UMG_species{end+1} = 'NH3';  % Add trace gases as needed
        end
        
        fprintf('Loading UMG absorption data (memory-optimized)...\n');
        
        % Use memory-optimized data loader
        Abs_data = transmission.data.loadAbsorptionData([], UMG_species, false);
    else
        Abs_data = Args.AbsData;
    end
    
    % =========================================================================
    % PRE-COMPUTE AIRMASS VALUES
    % =========================================================================
    
    % Import airmass function
    import transmission.utils.*
    
    % Pre-compute all airmass values at once for better performance
    Am_o2 = airmassFromSMARTS(Z_, 'o2');
    Am_ch4 = airmassFromSMARTS(Z_, 'ch4');
    Am_co = airmassFromSMARTS(Z_, 'co');
    Am_n2o = airmassFromSMARTS(Z_, 'n2o');
    Am_co2 = airmassFromSMARTS(Z_, 'co2');
    Am_n2 = airmassFromSMARTS(Z_, 'n2');
    Am_o4 = Am_o2;  % O4 uses O2 airmass
    
    % =========================================================================
    % PRE-COMPUTE ABUNDANCE FACTORS
    % =========================================================================
    
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
    % Direct access to pre-loaded absorption data for maximum efficiency
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
        fprintf('Processing trace gases...\n');
        
        % NH3 (Ammonia)
        if isfield(Abs_data, 'NH3') && Pp0 > 0  % Avoid log(0)
            try
                Nh3_abs = interp1(Abs_data.NH3.wavelength, Abs_data.NH3.absorption, Lam, 'linear', 0);
                Log_pp0 = log(Pp0);
                Nh3_abundance = exp(-8.6499 + 2.1947 * Log_pp0 - 2.5936 * (Log_pp0^2) - ...
                                   1.819 * (Log_pp0^3) - 0.65854 * (Log_pp0^4));
                Am_nh3 = airmassFromSMARTS(Z_, 'nh3');
                Tau_total = Tau_total + Nh3_abs .* Nh3_abundance .* Am_nh3;
            catch ME
                warning('NH3 trace gas calculation failed: %s', ME.message);
            end
        end
        
        % Additional trace gases can be added here following the same pattern
    end
    
    % =========================================================================
    % FINAL TRANSMISSION CALCULATION
    % =========================================================================
    
    % Calculate transmission and clip to [0,1]
    transmission = exp(-Tau_total);
    transmission = max(0, min(1, transmission));
end

