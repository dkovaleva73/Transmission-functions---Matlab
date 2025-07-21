function field_trans = fieldCorrection(wavelength, param_values, config)
    % V2 Field correction with flexible parameter arrays
    %
    % Parameters:
    %   wavelength (double array): Wavelength array in nm
    %   param_values (double array): Parameter values (only free parameters)
    %   config (ParameterConfig): Parameter configuration object
    %
    % Returns:
    %   field_trans (double array): Field correction transmission values
    %
    % Example:
    %   import transmission.v2.parameters.FieldParams
    %   config = FieldParams.getStandardConfig();
    %   param_values = config.getFreeParameters();
    %   Lam = transmission.utils.makeWavelengthArray(400, 800, 201);
    %   field_trans = transmission.v2.field.fieldCorrection(Lam, param_values, config);
    
    arguments
        wavelength (:,1) double
        param_values (:,1) double
        config (1,1) transmission.v2.parameters.ParameterConfig
    end
    
    % Update parameter values in config
    config.setFreeParameters(param_values);
    
    % Get all parameter values (fixed + free)
    all_params = config.getAllParameters();
    
    % Extract Chebyshev coefficients
    r0 = 0.0; r1 = 0.0; r2 = 0.0; r3 = 0.0; r4 = 0.0;
    
    if config.hasParameter('r0')
        r0 = all_params.r0;
    end
    if config.hasParameter('r1')
        r1 = all_params.r1;
    end
    if config.hasParameter('r2')
        r2 = all_params.r2;
    end
    if config.hasParameter('r3')
        r3 = all_params.r3;
    end
    if config.hasParameter('r4')
        r4 = all_params.r4;
    end
    
    % Use the existing Chebyshev field correction function
    field_trans = transmission.v2.field.chebyshevFieldCorrection(wavelength, r0, r1, r2, r3, r4, min(wavelength), max(wavelength));
end