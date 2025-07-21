classdef ParameterConfig < handle
    % Parameter configuration system for transmission model v2
    % Manages which parameters are fixed vs free for fitting
    
    properties (Access = private)
        parameter_definitions = struct()
        parameter_values = []
        parameter_names = {}
        fixed_mask = []
        free_indices = []
        fixed_indices = []
    end
    
    methods
        function obj = ParameterConfig()
            % Constructor - initialize empty parameter configuration
            obj.parameter_definitions = struct();
        end
        
        function addParameter(obj, name, initial_value, is_fixed, bounds, description)
            % Add a parameter to the configuration
            %
            % Parameters:
            %   name (string): Parameter name (e.g., 'qe_amplitude')
            %   initial_value (double): Initial/fixed value
            %   is_fixed (logical): True if parameter is fixed
            %   bounds (1x2 double): [min_value, max_value] for fitting
            %   description (string): Parameter description
            
            arguments
                obj
                name (1,1) string
                initial_value (1,1) double
                is_fixed (1,1) logical = false
                bounds (1,2) double = [-Inf, Inf]
                description (1,1) string = ""
            end
            
            % Store parameter definition
            param_def = struct();
            param_def.name = name;
            param_def.initial_value = initial_value;
            param_def.is_fixed = is_fixed;
            param_def.bounds = bounds;
            param_def.description = description;
            param_def.index = length(obj.parameter_names) + 1;
            
            obj.parameter_definitions.(name) = param_def;
            obj.parameter_names{end+1} = char(name);
            obj.parameter_values(end+1) = initial_value;
            obj.fixed_mask(end+1) = is_fixed;
            
            % Update free/fixed indices
            obj.updateIndices();
        end
        
        function updateIndices(obj)
            % Update the free and fixed parameter indices
            obj.free_indices = find(~obj.fixed_mask);
            obj.fixed_indices = find(obj.fixed_mask);
        end
        
        function free_params = getFreeParameters(obj)
            % Get array of free parameter values for fitting
            free_params = obj.parameter_values(obj.free_indices);
        end
        
        function setFreeParameters(obj, free_params)
            % Set free parameter values from fitting array
            %
            % Parameters:
            %   free_params (array): Values for free parameters only
            
            if length(free_params) ~= length(obj.free_indices)
                error('Free parameter array size mismatch. Expected %d, got %d', ...
                      length(obj.free_indices), length(free_params));
            end
            
            obj.parameter_values(obj.free_indices) = free_params;
        end
        
        function all_params = getAllParameters(obj)
            % Get array of all parameter values (fixed + free)
            all_params = obj.parameter_values;
        end
        
        function value = getParameter(obj, name)
            % Get value of a specific parameter by name
            %
            % Parameters:
            %   name (string): Parameter name
            %
            % Returns:
            %   value (double): Parameter value
            
            if ~isfield(obj.parameter_definitions, name)
                error('Parameter "%s" not found', name);
            end
            
            idx = obj.parameter_definitions.(name).index;
            value = obj.parameter_values(idx);
        end
        
        function setParameter(obj, name, value)
            % Set value of a specific parameter by name
            %
            % Parameters:
            %   name (string): Parameter name
            %   value (double): New parameter value
            
            if ~isfield(obj.parameter_definitions, name)
                error('Parameter "%s" not found', name);
            end
            
            idx = obj.parameter_definitions.(name).index;
            obj.parameter_values(idx) = value;
        end
        
        function fixParameter(obj, name)
            % Fix a parameter (remove from fitting)
            %
            % Parameters:
            %   name (string): Parameter name
            
            if ~isfield(obj.parameter_definitions, name)
                error('Parameter "%s" not found', name);
            end
            
            obj.parameter_definitions.(name).is_fixed = true;
            idx = obj.parameter_definitions.(name).index;
            obj.fixed_mask(idx) = true;
            obj.updateIndices();
        end
        
        function freeParameter(obj, name)
            % Free a parameter (include in fitting)
            %
            % Parameters:
            %   name (string): Parameter name
            
            if ~isfield(obj.parameter_definitions, name)
                error('Parameter "%s" not found', name);
            end
            
            obj.parameter_definitions.(name).is_fixed = false;
            idx = obj.parameter_definitions.(name).index;
            obj.fixed_mask(idx) = false;
            obj.updateIndices();
        end
        
        function bounds = getFittingBounds(obj)
            % Get bounds for free parameters only
            %
            % Returns:
            %   bounds (Nx2 array): [min, max] for each free parameter
            
            bounds = zeros(length(obj.free_indices), 2);
            
            for i = 1:length(obj.free_indices)
                param_idx = obj.free_indices(i);
                param_name = obj.parameter_names{param_idx};
                param_bounds = obj.parameter_definitions.(param_name).bounds;
                bounds(i, :) = param_bounds;
            end
        end
        
        function names = getFreeParameterNames(obj)
            % Get names of free parameters only
            %
            % Returns:
            %   names (cell array): Names of free parameters
            
            names = obj.parameter_names(obj.free_indices);
        end
        
        function printConfiguration(obj)
            % Print current parameter configuration
            
            fprintf('Parameter Configuration:\n');
            fprintf('========================\n');
            fprintf('%-20s %-12s %-8s %-15s %s\n', 'Name', 'Value', 'Status', 'Bounds', 'Description');
            fprintf('%-20s %-12s %-8s %-15s %s\n', '----', '-----', '------', '------', '-----------');
            
            for i = 1:length(obj.parameter_names)
                param_name = obj.parameter_names{i};
                param_def = obj.parameter_definitions.(param_name);
                
                status = 'FREE';
                if param_def.is_fixed
                    status = 'FIXED';
                end
                
                bounds_str = sprintf('[%.2g, %.2g]', param_def.bounds(1), param_def.bounds(2));
                
                fprintf('%-20s %-12.4g %-8s %-15s %s\n', ...
                        param_name, param_def.initial_value, status, bounds_str, param_def.description);
            end
            
            fprintf('\nSummary: %d total parameters (%d free, %d fixed)\n', ...
                    length(obj.parameter_names), length(obj.free_indices), length(obj.fixed_indices));
        end
        
        function config_struct = exportConfiguration(obj)
            % Export configuration as a structure for saving
            %
            % Returns:
            %   config_struct (struct): Configuration data
            
            config_struct = struct();
            config_struct.parameter_definitions = obj.parameter_definitions;
            config_struct.parameter_values = obj.parameter_values;
            config_struct.parameter_names = obj.parameter_names;
            config_struct.fixed_mask = obj.fixed_mask;
        end
        
        function importConfiguration(obj, config_struct)
            % Import configuration from a structure
            %
            % Parameters:
            %   config_struct (struct): Configuration data
            
            obj.parameter_definitions = config_struct.parameter_definitions;
            obj.parameter_values = config_struct.parameter_values;
            obj.parameter_names = config_struct.parameter_names;
            obj.fixed_mask = config_struct.fixed_mask;
            obj.updateIndices();
        end
    end
end