function Trans = ozoneTransmission(Z_, Dobson_units, Lam, Args)
    % Ozone transmission.
    % Input :  - Z_ (double): The zenith angle in degrees.
    %          - Dobson_units (double): The ozone column in Dobson units.
    %          - Lam (double array): Wavelength array (by default, in nm).
    %          - Abs_data (struct, optional): Pre-loaded absorption data from loadAbsorptionData()
    %          * ...,key,val,...
    %             'WaveUnits' -  'A','Ang'|'nm'
    %             'AbsData' - Pre-loaded absorption data structure
    % Output :  - transmission (double array): The calculated transmission values (0-1).
    % Author : D. Kovaleva (Jul 2025)
    % Example:   Lam = transmission.utils.make_wavelength_array(280, 400, 121);
    %            Trans = transmission.atmospheric.ozoneTransmission(30, 300, Lam);
    %            % Or with pre-loaded data:
    %            Abs_data = transmission.data.loadAbsorptionData();
    %            Trans = transmission.atmospheric.ozoneTransmission(30, 300, Lam, 'AbsData', Abs_data);
    
    arguments
        Z_
        Dobson_units 
        Lam
        Args.WaveUnits  = 'nm';
        Args.AbsData = transmission.data.loadAbsorptionData([], {'O3UV'}, false);
    end  
    
    % Convert Dobson units to atm-cm
    Ozone_atm_cm = Dobson_units * 0.001;
    
    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Calculate airmass using SMARTS coefficients for ozone
    Am_ = transmission.utils.airmassFromSMARTS(Z_, 'o3');
    

    % Extract ozone cross-section data using getAbsorptionData
    [Abs_wavelength, Ozone_cross_section] = transmission.data.getAbsorptionData(Args.AbsData, 'O3UV', 'Units', Args.WaveUnits);
    
    
    % Interpolate ozone cross-sections to wavelength array
    Ozone_xs_interp = interp1(Abs_wavelength, Ozone_cross_section, Lam, 'linear', 0);
    
    % Absorption coefficients are already corrected in loadAbsorptionData
    Absorption_coeff = Ozone_xs_interp;
    
  
    % Calculate optical depth
    Tau_ozone = Absorption_coeff * Ozone_atm_cm;
    
    % Calculate transmission and clip to [0,1]
    Trans = exp(-Am_ .* Tau_ozone);
    Trans = max(0, min(1, Trans));
end
