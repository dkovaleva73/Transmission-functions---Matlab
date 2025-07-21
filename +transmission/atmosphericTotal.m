function total_transmission = atmosphericTotal(Z_, Params, Lam, varargin)
    % Calculate total atmospheric transmission combining all effects.
    %
    % Parameters:
    %   Z_ (double): The zenith angle in degrees.
    %   Params (struct): Atmospheric parameters with fields:
    %     - pressure: Surface pressure in mbar (default: 1013.25)
    %     - precipitable_water: Precipitable water in cm (default: 2.0)
    %     - ozone_dobson: Ozone column in Dobson units (default: 300)
    %     - aerosol_aod500: Aerosol optical depth at 500nm (default: 0.1)
    %     - aerosol_alpha: Angstrom exponent (default: 1.3)
    %   Lam (double array): Wavelength array in nm.
    %   
    % Optional name-value pairs:
    %   'include_rayleigh' (logical): Include Rayleigh scattering (default: true)
    %   'include_aerosol' (logical): Include aerosol extinction (default: true)
    %   'include_ozone' (logical): Include ozone absorption (default: true)
    %   'include_water' (logical): Include water vapor absorption (default: true)
    %   'include_umg' (logical): Include uniformly mixed gases (default: false)
    %   'air_temperature' (double): Air temperature in °C for UMG (default: 15)
    %   'co2_ppm' (double): CO2 concentration in ppm for UMG (default: 415)
    %
    % Returns:
    %   total_transmission (double array): Combined transmission (0-1).
    %
    % Example:
    %   wvl = transmission.utils.make_wavelength_array();
    %   params.pressure = 1013.25;
    %   params.precipitable_water = 2.0;
    %   params.ozone_dobson = 300;
    %   params.aerosol_aod500 = 0.1;
    %   params.aerosol_alpha = 1.3;
    %   trans = transmission.atmospheric_total(30, params, wvl);
    
    % Parse input arguments
    p = inputParser;
    addParameter(p, 'include_rayleigh', true, @islogical);
    addParameter(p, 'include_aerosol', true, @islogical);
    addParameter(p, 'include_ozone', true, @islogical);
    addParameter(p, 'include_water', true, @islogical);
    addParameter(p, 'include_umg', false, @islogical);
    addParameter(p, 'air_temperature', 15, @isnumeric);
    addParameter(p, 'co2_ppm', 415, @isnumeric);
    parse(p, varargin{:});
    
    % Set default parameters if not provided
    if ~isfield(Params, 'pressure')
        Params.pressure = 1013.25;
    end
    if ~isfield(Params, 'precipitable_water')
        Params.precipitable_water = 2.0;
    end
    if ~isfield(Params, 'ozone_dobson')
        Params.ozone_dobson = 300;
    end
    if ~isfield(Params, 'aerosol_aod500')
        Params.aerosol_aod500 = 0.1;
    end
    if ~isfield(Params, 'aerosol_alpha')
        Params.aerosol_alpha = 1.3;
    end
    
    % Initialize total transmission to unity
    total_transmission = ones(size(Lam));
    
    % Import atmospheric functions
    import transmission.atmospheric.rayleighTransmission
    import transmission.atmospheric.aerosolTransmittance
    import transmission.atmospheric.ozoneTransmission
    import transmission.atmospheric.waterTransmittance
    import transmission.atmospheric.umgTransmittance
    
    % Apply Rayleigh scattering
    if p.Results.include_rayleigh
        Rayleigh_trans = rayleighTransmission(Z_, Params.pressure, Lam);
        total_transmission = total_transmission .* Rayleigh_trans;
    end
    
    % Apply aerosol extinction
    if p.Results.include_aerosol
        Aerosol_trans = aerosolTransmittance(Z_, Params.aerosol_aod500, ...
                                            Params.aerosol_alpha, Lam);
        total_transmission = total_transmission .* Aerosol_trans;
    end
    
    % Apply ozone absorption (primarily affects UV)
    if p.Results.include_ozone
        try
            Ozone_trans = ozoneTransmission(Z_, Params.ozone_dobson, Lam);
            total_transmission = total_transmission .* Ozone_trans;
        catch ME
            if contains(ME.message, 'Ozone data file')
                warning('Ozone data file not found, skipping ozone absorption');
            else
                rethrow(ME);
            end
        end
    end
    
    % Apply water vapor absorption
    if p.Results.include_water
        try
            Water_trans = waterTransmittance(Z_, Params.precipitable_water, ...
                                            Params.pressure, Lam);
            total_transmission = total_transmission .* Water_trans;
        catch ME
            if contains(ME.message, 'Water vapor data file')
                warning('Water vapor data file not found, skipping water absorption');
            else
                rethrow(ME);
            end
        end
    end
    
    % Apply uniformly mixed gases
    if p.Results.include_umg
        try
            Umg_trans = umgTransmittance(Z_, p.Results.air_temperature, ...
                                        Params.pressure, Lam, p.Results.co2_ppm, true);
            total_transmission = total_transmission .* Umg_trans;
        catch ME
            if contains(ME.message, 'Gas data file')
                warning('Some UMG data files not found, skipping UMG transmission');
            else
                rethrow(ME);
            end
        end
    end
    
    % Ensure result is in valid range
    total_transmission = max(0, min(1, total_transmission));
end