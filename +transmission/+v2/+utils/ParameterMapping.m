classdef ParameterMapping < handle
    % Parameter mapping utility for v2 transmission system
    % Manages parameter distribution across atmospheric, instrumental, and field components
    
    properties (Access = private)
        atm_config
        inst_config
        field_config
        total_free_params
        atm_indices
        inst_indices
        field_indices
        param_names
        param_bounds
    end
    
    methods
        function obj = ParameterMapping(atm_config, inst_config, field_config)
            % Constructor for ParameterMapping
            %
            % Parameters:
            %   atm_config (ParameterConfig): Atmospheric parameter configuration
            %   inst_config (ParameterConfig): Instrumental parameter configuration
            %   field_config (ParameterConfig): Field correction parameter configuration
            
            obj.atm_config = atm_config;
            obj.inst_config = inst_config;
            obj.field_config = field_config;
            
            obj.buildParameterMapping();
        end
        
        function buildParameterMapping(obj)
            % Build the parameter mapping indices
            
            % Get free parameters from each component
            atm_free = obj.atm_config.getFreeParameters();
            inst_free = obj.inst_config.getFreeParameters();
            field_free = obj.field_config.getFreeParameters();
            
            % Calculate indices for each component
            n_atm = length(atm_free);
            n_inst = length(inst_free);
            n_field = length(field_free);
            
            obj.atm_indices = 1:n_atm;
            obj.inst_indices = (n_atm + 1):(n_atm + n_inst);
            obj.field_indices = (n_atm + n_inst + 1):(n_atm + n_inst + n_field);
            
            obj.total_free_params = n_atm + n_inst + n_field;
            
            % Build parameter names and bounds
            obj.param_names = {};
            obj.param_bounds = [];
            
            % Atmospheric parameters
            atm_names = obj.atm_config.getFreeParameterNames();
            atm_bounds = obj.atm_config.getFreeParameterBounds();
            for i = 1:length(atm_names)
                obj.param_names{end+1} = ['atm_' atm_names{i}];
                obj.param_bounds = [obj.param_bounds; atm_bounds(i, :)];
            end
            
            % Instrumental parameters
            inst_names = obj.inst_config.getFreeParameterNames();
            inst_bounds = obj.inst_config.getFreeParameterBounds();
            for i = 1:length(inst_names)
                obj.param_names{end+1} = ['inst_' inst_names{i}];
                obj.param_bounds = [obj.param_bounds; inst_bounds(i, :)];
            end
            
            % Field parameters
            field_names = obj.field_config.getFreeParameterNames();
            field_bounds = obj.field_config.getFreeParameterBounds();
            for i = 1:length(field_names)
                obj.param_names{end+1} = ['field_' field_names{i}];
                obj.param_bounds = [obj.param_bounds; field_bounds(i, :)];
            end
        end
        
        function param_values = getFreeParameters(obj)
            % Get all free parameters as a single array
            %
            % Returns:
            %   param_values (double array): All free parameter values
            
            atm_params = obj.atm_config.getFreeParameters();
            inst_params = obj.inst_config.getFreeParameters();
            field_params = obj.field_config.getFreeParameters();
            
            param_values = [atm_params; inst_params; field_params];
        end
        
        function setFreeParameters(obj, param_values)
            % Set all free parameters from a single array
            %
            % Parameters:
            %   param_values (double array): All free parameter values
            
            if length(param_values) ~= obj.total_free_params
                error('Parameter array length (%d) does not match expected (%d)', ...
                      length(param_values), obj.total_free_params);
            end
            
            % Extract parameters for each component
            if ~isempty(obj.atm_indices)
                atm_params = param_values(obj.atm_indices);
                obj.atm_config.setFreeParameters(atm_params);
            end
            
            if ~isempty(obj.inst_indices)
                inst_params = param_values(obj.inst_indices);
                obj.inst_config.setFreeParameters(inst_params);
            end
            
            if ~isempty(obj.field_indices)
                field_params = param_values(obj.field_indices);
                obj.field_config.setFreeParameters(field_params);
            end
        end
        
        function [atm_params, inst_params, field_params] = getComponentParameters(obj)
            % Get free parameters for each component separately
            %
            % Returns:
            %   atm_params (double array): Atmospheric free parameters
            %   inst_params (double array): Instrumental free parameters
            %   field_params (double array): Field correction free parameters
            
            atm_params = obj.atm_config.getFreeParameters();
            inst_params = obj.inst_config.getFreeParameters();
            field_params = obj.field_config.getFreeParameters();
        end
        
        function names = getParameterNames(obj)
            % Get names of all free parameters
            %
            % Returns:
            %   names (cell array): Parameter names with component prefixes
            
            names = obj.param_names;
        end
        
        function bounds = getParameterBounds(obj)
            % Get bounds for all free parameters
            %
            % Returns:
            %   bounds (double array): Parameter bounds [min, max] for each parameter
            
            bounds = obj.param_bounds;
        end
        
        function n_params = getNumParameters(obj)
            % Get total number of free parameters
            %
            % Returns:
            %   n_params (integer): Total number of free parameters
            
            n_params = obj.total_free_params;
        end
        
        function summary = getSummary(obj)
            % Get summary of parameter mapping
            %
            % Returns:
            %   summary (struct): Summary information
            
            summary = struct();
            summary.total_parameters = obj.total_free_params;
            summary.atmospheric_parameters = length(obj.atm_indices);
            summary.instrumental_parameters = length(obj.inst_indices);
            summary.field_parameters = length(obj.field_indices);
            summary.parameter_names = obj.param_names;
            summary.parameter_bounds = obj.param_bounds;
            
            % Component ranges
            summary.atm_range = obj.atm_indices;
            summary.inst_range = obj.inst_indices;
            summary.field_range = obj.field_indices;
        end
        
        function printSummary(obj)
            % Print parameter mapping summary
            
            fprintf('Parameter Mapping Summary\n');
            fprintf('========================\n');
            fprintf('Total free parameters: %d\n', obj.total_free_params);
            fprintf('  Atmospheric: %d (indices %d-%d)\n', length(obj.atm_indices), ...
                    min(obj.atm_indices), max(obj.atm_indices));
            fprintf('  Instrumental: %d (indices %d-%d)\n', length(obj.inst_indices), ...
                    min(obj.inst_indices), max(obj.inst_indices));
            fprintf('  Field correction: %d (indices %d-%d)\n', length(obj.field_indices), ...
                    min(obj.field_indices), max(obj.field_indices));
            
            fprintf('\nParameter Details:\n');
            for i = 1:length(obj.param_names)
                fprintf('  %2d. %-20s [%.3f, %.3f]\n', i, obj.param_names{i}, ...
                        obj.param_bounds(i, 1), obj.param_bounds(i, 2));
            end
        end
    end
end