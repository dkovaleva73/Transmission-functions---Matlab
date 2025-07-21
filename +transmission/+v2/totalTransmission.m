function total_trans = totalTransmission(wavelength, param_values, atm_config, inst_config, field_config, options)
    % V2 Total transmission combining all components with parameter arrays
    %
    % Parameters:
    %   wavelength (double array): Wavelength array in nm
    %   param_values (double array): All parameter values (free parameters only)
    %   atm_config (ParameterConfig): Atmospheric parameter configuration
    %   inst_config (ParameterConfig): Instrumental parameter configuration
    %   field_config (ParameterConfig): Field correction parameter configuration
    %   options (struct): Optional settings for component inclusion
    %
    % Options:
    %   include_atmospheric (logical): Include atmospheric transmission (default: true)
    %   include_instrumental (logical): Include instrumental transmission (default: true)
    %   include_field (logical): Include field correction (default: true)
    %
    % Returns:
    %   total_trans (double array): Total transmission values
    %
    % Example:
    %   import transmission.v2.parameters.*
    %   atm_config = AtmosphericParams.getStandardConfig();
    %   inst_config = InstrumentalParams.getStandardConfig();
    %   field_config = FieldParams.getStandardConfig();
    %   
    %   % Get parameter mapping
    %   param_mapping = transmission.v2.utils.createParameterMapping(atm_config, inst_config, field_config);
    %   param_values = param_mapping.getFreeParameters();
    %   
    %   Lam = transmission.utils.makeWavelengthArray(400, 800, 201);
    %   
    %   % Include all components
    %   total_trans = transmission.v2.totalTransmission(Lam, param_values, atm_config, inst_config, field_config);
    %   
    %   % Neglect atmospheric transmission (set to 1)
    %   options.include_atmospheric = false;
    %   total_trans = transmission.v2.totalTransmission(Lam, param_values, atm_config, inst_config, field_config, options);
    
    arguments
        wavelength (:,1) double
        param_values (:,1) double
        atm_config (1,1) transmission.v2.parameters.ParameterConfig
        inst_config (1,1) transmission.v2.parameters.ParameterConfig
        field_config (1,1) transmission.v2.parameters.ParameterConfig
        options (1,1) struct = struct()
    end
    
    % Set default options
    if ~isfield(options, 'include_atmospheric')
        options.include_atmospheric = true;
    end
    if ~isfield(options, 'include_instrumental')
        options.include_instrumental = true;
    end
    if ~isfield(options, 'include_field')
        options.include_field = true;
    end
    
    % Create parameter mapping and distribute parameters
    param_mapping = transmission.v2.utils.createParameterMapping(atm_config, inst_config, field_config);
    param_mapping.setFreeParameters(param_values);
    
    % Extract parameter values for each component
    [atm_params, inst_params, field_params] = param_mapping.getComponentParameters();
    
    % Initialize transmission to unity
    total_trans = ones(size(wavelength));
    
    % Calculate atmospheric transmission (or set to 1 if neglected)
    if options.include_atmospheric
        atm_trans = transmission.v2.atmospheric.atmosphericTransmission(wavelength, atm_params, atm_config);
        total_trans = total_trans .* atm_trans;
    end
    
    % Calculate instrumental transmission (or set to 1 if neglected)
    if options.include_instrumental
        inst_trans = transmission.v2.instrumental.instrumentalTransmission(wavelength, inst_params, inst_config);
        total_trans = total_trans .* inst_trans;
    end
    
    % Calculate field correction (or set to 1 if neglected)
    if options.include_field
        field_trans = transmission.v2.field.fieldCorrection(wavelength, field_params, field_config);
        total_trans = total_trans .* field_trans;
    end
    
    % Ensure positive values
    total_trans = max(total_trans, 1e-10);
end