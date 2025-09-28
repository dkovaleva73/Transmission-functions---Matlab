function Transm = ozoneTransmission_am(Lam, zenithAngle_deg, dobsonUnits, waveUnits, Args)
    % Fast ozone transmission using direct airmass calculation (no caching)
    % 6.5x faster airmass calculation than cached version
    %
    % Input:  - Lam (double array): Wavelength array
    %         - zenithAngle_deg (double): Zenith angle in degrees [0, 90] (default: 55.18)
    %         - dobsonUnits (double): Ozone column in Dobson Units (default: 300)
    %         - waveUnits (string): Wavelength units (default: 'nm')
    %         * ...,key,val,...
    %           'AbsorptionData' - Pre-loaded absorption data to avoid file I/O
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
        Args.AbsorptionData = []
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

    % Convert Dobson units to atm-cm
    Ozone_atm_cm = dobsonUnits * 0.001;

    % Calculate airmass using fast direct method (no caching)
    Am_ = transmissionFast.utils.airmassFromSMARTS_am('ozone', zenithAngle_deg);

    % Load ozone absorption data - use cached if provided
    if ~isempty(Args.AbsorptionData)
        Abs_data = Args.AbsorptionData;
    else
        Abs_data = transmissionFast.data.loadAbsorptionData([], {'O3UV'}, false);
    end

    % Extract ozone cross-section data directly
    if ~isfield(Abs_data, 'O3UV')
        error('O3UV data not found in absorption data structure');
    end

    Abs_wavelength = Abs_data.O3UV.wavelength;
    Ozone_cross_section = Abs_data.O3UV.absorption;

    % Interpolate ozone cross-sections to wavelength array
    Ozone_xs_interp = interp1(Abs_wavelength, Ozone_cross_section, Lam, 'linear', 0);

    % Absorption coefficients are already corrected in loadAbsorptionData
    Absorption_coeff = Ozone_xs_interp;

    % Calculate optical depth
    Tau_ozone = Absorption_coeff * Ozone_atm_cm;

    % Calculate transmission (no clipping to preserve error detection)
    Transm = exp(-Am_ .* Tau_ozone);
end