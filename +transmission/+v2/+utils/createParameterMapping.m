function param_mapping = createParameterMapping(atm_config, inst_config, field_config)
    % Create unified parameter mapping for v2 transmission components
    %
    % Parameters:
    %   atm_config (ParameterConfig): Atmospheric parameter configuration
    %   inst_config (ParameterConfig): Instrumental parameter configuration
    %   field_config (ParameterConfig): Field correction parameter configuration
    %
    % Returns:
    %   param_mapping (ParameterMapping): Unified parameter mapping object
    %
    % Example:
    %   import transmission.v2.parameters.*
    %   atm_config = AtmosphericParams.getStandardConfig();
    %   inst_config = InstrumentalParams.getStandardConfig();
    %   field_config = FieldParams.getStandardConfig();
    %   param_mapping = transmission.v2.utils.createParameterMapping(atm_config, inst_config, field_config);
    
    arguments
        atm_config (1,1) transmission.v2.parameters.ParameterConfig
        inst_config (1,1) transmission.v2.parameters.ParameterConfig
        field_config (1,1) transmission.v2.parameters.ParameterConfig
    end
    
    % Create parameter mapping object
    param_mapping = transmission.v2.utils.ParameterMapping(atm_config, inst_config, field_config);
end