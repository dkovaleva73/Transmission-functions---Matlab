function Trans = ozoneTransmission(Z_, Dobson_units, Lam, Args)
    % Ozone transmission of the Earth atmosphere.
    % Based on SMARTS 2.9.5 model.
    % Input :  - Z_ (double): The zenith angle in degrees.
    %          - Dobson_units (double): The ozone column in Dobson units.
    %          - Lam (double array): Wavelength array (by default, in nm).
    %          - Abs_data (struct, optional): Pre-loaded absorption data from loadAbsorptionData()
    %          * ...,key,val,...
    %             'WaveUnits' -  'A','Ang'|'nm'
    %             'AbsData' - Pre-loaded absorption data structure
    % Output :  - transmission (double array): The calculated transmission values (0-1).
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    %             2. Garrappa et al. 2025, A&A 699, A50
    % Example:   % Standalone usage (loads data internally, slower):
    %            Lam = transmission.utils.make_wavelength_array(280, 400, 121);
    %            Trans = transmission.atmospheric.ozoneTransmission(30, 300, Lam);
    %            % Pipeline usage (load once, reuse multiple times, faster):
    %            Abs_data = transmission.data.loadAbsorptionData();  % Load once
    %            Trans1 = transmission.atmospheric.ozoneTransmission(30, 300, Lam, 'AbsData', Abs_data);
    %            Trans2 = transmission.atmospheric.ozoneTransmission(45, 350, Lam, 'AbsData', Abs_data);
    
    arguments
        Z_
        Dobson_units 
        Lam
        Args.WaveUnits  = 'nm';
        Args.AbsData = [];
    end  
    
    % Convert Dobson units to atm-cm
    Ozone_atm_cm = Dobson_units * 0.001;
    
    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Calculate airmass using SMARTS coefficients for ozone
    Am_ = transmission.utils.airmassFromSMARTS(Z_, 'o3');
    

    % Get ozone absorption data
    if isempty(Args.AbsData)
        % Load data if not provided (standalone usage)
        Abs_data = transmission.data.loadAbsorptionData([], {'O3UV'}, false);
    else
        % Use pre-loaded data (pipeline usage)
        Abs_data = Args.AbsData;
    end
    
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
    
    % Calculate transmission and clip to [0,1]
    Trans = exp(-Am_ .* Tau_ozone);
    Trans = max(0, min(1, Trans));
end
