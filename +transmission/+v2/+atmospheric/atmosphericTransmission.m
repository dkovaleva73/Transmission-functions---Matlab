function atm_trans = atmosphericTransmission(wavelength, param_values, config)
    % V2 Atmospheric transmission with flexible parameter arrays
    %
    % Parameters:
    %   wavelength (double array): Wavelength array in nm
    %   param_values (double array): Parameter values (only free parameters)
    %   config (ParameterConfig): Parameter configuration object
    %
    % Returns:
    %   atm_trans (double array): Atmospheric transmission values
    %
    % Example:
    %   import transmission.v2.parameters.AtmosphericParams
    %   config = AtmosphericParams.getStandardConfig();
    %   param_values = config.getFreeParameters();
    %   Lam = transmission.utils.makeWavelengthArray(400, 800, 201);
    %   atm_trans = transmission.v2.atmospheric.atmosphericTransmission(Lam, param_values, config);
    
    arguments
        wavelength (:,1) double
        param_values (:,1) double
        config (1,1) transmission.v2.parameters.ParameterConfig
    end
    
    % Update parameter values in config
    config.setFreeParameters(param_values);
    
    % Get all parameter values (fixed + free)
    all_params = config.getAllParameters();
    
    % Extract individual parameters
    Z = all_params.zenith_angle;
    pressure = all_params.pressure;
    temperature = all_params.temperature;
    rayleigh_scale = all_params.rayleigh_scale;
    
    % Initialize atmospheric transmission
    atm_trans = ones(size(wavelength));
    
    % Rayleigh scattering
    if config.hasParameter('rayleigh_scale')
        rayleigh_trans = transmission.atmospheric.rayleighTransmission(wavelength, Z, pressure, temperature);
        atm_trans = atm_trans .* rayleigh_trans.^rayleigh_scale;
    end
    
    % Aerosol extinction
    if config.hasParameter('aod_500')
        aod_500 = all_params.aod_500;
        
        if config.hasParameter('angstrom_exp')
            angstrom_exp = all_params.angstrom_exp;
        else
            angstrom_exp = 1.3;  % Default
        end
        
        aerosol_scale = 1.0;
        if config.hasParameter('aerosol_scale')
            aerosol_scale = all_params.aerosol_scale;
        end
        
        % Create aerosol parameter structure
        aerosol_params = struct();
        aerosol_params.aerosol_aod500 = aod_500;
        aerosol_params.aerosol_alpha = angstrom_exp;
        
        aerosol_trans = transmission.atmospheric.aerosolTransmission(wavelength, Z, aerosol_params);
        atm_trans = atm_trans .* aerosol_trans.^aerosol_scale;
    end
    
    % Advanced aerosol (fine + coarse modes)
    if config.hasParameter('aod_500_fine') && config.hasParameter('aod_500_coarse')
        aod_fine = all_params.aod_500_fine;
        aod_coarse = all_params.aod_500_coarse;
        angstrom_fine = all_params.angstrom_fine;
        angstrom_coarse = all_params.angstrom_coarse;
        fine_fraction = all_params.fine_fraction;
        
        % Fine mode
        aerosol_params_fine = struct();
        aerosol_params_fine.aerosol_aod500 = aod_fine;
        aerosol_params_fine.aerosol_alpha = angstrom_fine;
        aerosol_trans_fine = transmission.atmospheric.aerosolTransmission(wavelength, Z, aerosol_params_fine);
        
        % Coarse mode
        aerosol_params_coarse = struct();
        aerosol_params_coarse.aerosol_aod500 = aod_coarse;
        aerosol_params_coarse.aerosol_alpha = angstrom_coarse;
        aerosol_trans_coarse = transmission.atmospheric.aerosolTransmission(wavelength, Z, aerosol_params_coarse);
        
        % Combined aerosol
        aerosol_trans = (aerosol_trans_fine * fine_fraction) + (aerosol_trans_coarse * (1 - fine_fraction));
        atm_trans = atm_trans .* aerosol_trans;
    end
    
    % Ozone absorption
    if config.hasParameter('ozone_dobson')
        ozone_dobson = all_params.ozone_dobson;
        
        ozone_scale = 1.0;
        if config.hasParameter('ozone_scale')
            ozone_scale = all_params.ozone_scale;
        end
        
        % Create ozone parameter structure
        ozone_params = struct();
        ozone_params.ozone_dobson = ozone_dobson;
        
        ozone_trans = transmission.atmospheric.ozoneTransmission(wavelength, Z, ozone_params);
        atm_trans = atm_trans .* ozone_trans.^ozone_scale;
    end
    
    % Water vapor absorption
    if config.hasParameter('precipitable_water')
        precipitable_water = all_params.precipitable_water;
        
        water_scale = 1.0;
        if config.hasParameter('water_scale')
            water_scale = all_params.water_scale;
        end
        
        % Create water vapor parameter structure
        water_params = struct();
        water_params.precipitable_water = precipitable_water;
        
        % Add advanced water vapor parameters if available
        if config.hasParameter('water_temp_coeff')
            water_params.temp_coeff = all_params.water_temp_coeff;
        end
        if config.hasParameter('water_pressure_coeff')
            water_params.pressure_coeff = all_params.water_pressure_coeff;
        end
        
        water_trans = transmission.atmospheric.waterVaporTransmission(wavelength, Z, water_params);
        atm_trans = atm_trans .* water_trans.^water_scale;
    end
    
    % UMG (Uniformly Mixed Gases) absorption
    if config.hasParameter('co2_ppm')
        co2_ppm = all_params.co2_ppm;
        
        umg_scale = 1.0;
        if config.hasParameter('umg_scale')
            umg_scale = all_params.umg_scale;
        end
        
        % Create UMG parameter structure
        umg_params = struct();
        umg_params.co2_ppm = co2_ppm;
        
        umg_trans = transmission.atmospheric.umgTransmission(wavelength, Z, umg_params);
        atm_trans = atm_trans .* umg_trans.^umg_scale;
    end
    
    % Ensure positive values
    atm_trans = max(atm_trans, 1e-10);
end