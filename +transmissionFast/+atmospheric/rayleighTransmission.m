function Transm = rayleighTransmission(zenithAngle_deg, Args)
    % Approximate Rayleigh transmission of the Earth atmosphere with caching
    %
    % Usage:
    %   First call:  Transm = transmissionFast.atmospheric.rayleighTransmission(45); % Calculate for 45 degrees and cache
    %   Later calls: Transm = transmissionFast.atmospheric.rayleighTransmission();   % Return cached result
    %
    % Input :  - zenithAngle_deg: Zenith angle in degrees (optional if cached)
    %          - Args: Optional arguments
    %            'Pressure' - Atmospheric pressure in mbar (default: 1013.25)
    %            'Wavelength' - Wavelength array in nm (default: 300-1100 nm)
    %            'WaveUnits' - Wavelength units (default: 'nm')
    % Output : - Transm (double array): The calculated transmission values (0-1).
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253. SMARTS model.
    % Author:    D. Kovaleva (July 2025).
    % Example:   % First call with zenith angle
    %            Transm = transmissionFast.atmospheric.rayleighTransmission(45);
    %            % Later calls without arguments
    %            Transm = transmissionFast.atmospheric.rayleighTransmission();

    persistent cachedTransm cachedZenith cachedArgs

    arguments
        zenithAngle_deg = []
        Args.Pressure = 1013.25  % mbar, sea level standard
        Args.Wavelength = linspace(300, 1100, 401)  % nm
        Args.WaveUnits = 'nm'
    end

    % Check if requesting cached data (no zenith angle provided)
    if isempty(zenithAngle_deg)
        if isempty(cachedTransm)
            error('No cached Rayleigh transmission data. Call with zenithAngle_deg first.');
        end
        Transm = cachedTransm;
        return;
    end

    % Check if we can use cached data (same inputs)
    if ~isempty(cachedTransm) && isequal(zenithAngle_deg, cachedZenith) && isequal(Args, cachedArgs)
        Transm = cachedTransm;
        return;
    end

    % Validate zenith angle
    if zenithAngle_deg > 90 || zenithAngle_deg < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Get airmass for Rayleigh scattering from astro.atmosphere
    Constituent_Airmasses = astro.atmosphere.airmassFromSMARTS(zenithAngle_deg);
    Am_rayleigh = Constituent_Airmasses.rayleigh;

    % Calculate Rayleigh optical depth using AstroPack rayleighScattering
    Tau_rayleigh = astro.atmosphere.rayleighScattering(Args.Wavelength, Args.Pressure, Args.WaveUnits);

    % Calculate transmission
    Transm = exp(-Am_rayleigh .* Tau_rayleigh);

    % Cache the results
    cachedTransm = Transm;
    cachedZenith = zenithAngle_deg;
    cachedArgs = Args;
end
