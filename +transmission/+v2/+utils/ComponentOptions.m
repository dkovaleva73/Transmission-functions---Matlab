classdef ComponentOptions < handle
    % Utility class for creating component inclusion options
    % Provides predefined combinations for common transmission scenarios
    
    methods (Static)
        function options = allComponents()
            % Include all transmission components
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = true;
            options.include_instrumental = true;
            options.include_field = true;
        end
        
        function options = atmosphericOnly()
            % Include only atmospheric transmission
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = true;
            options.include_instrumental = false;
            options.include_field = false;
        end
        
        function options = instrumentalOnly()
            % Include only instrumental transmission
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = false;
            options.include_instrumental = true;
            options.include_field = false;
        end
        
        function options = fieldOnly()
            % Include only field correction
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = false;
            options.include_instrumental = false;
            options.include_field = true;
        end
        
        function options = atmosphericAndInstrumental()
            % Include atmospheric and instrumental transmission (no field correction)
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = true;
            options.include_instrumental = true;
            options.include_field = false;
        end
        
        function options = atmosphericAndField()
            % Include atmospheric transmission and field correction (no instrumental)
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = true;
            options.include_instrumental = false;
            options.include_field = true;
        end
        
        function options = instrumentalAndField()
            % Include instrumental transmission and field correction (no atmospheric)
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = false;
            options.include_instrumental = true;
            options.include_field = true;
        end
        
        function options = noAtmospheric()
            % Include everything except atmospheric transmission
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = false;
            options.include_instrumental = true;
            options.include_field = true;
        end
        
        function options = noInstrumental()
            % Include everything except instrumental transmission
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = true;
            options.include_instrumental = false;
            options.include_field = true;
        end
        
        function options = noField()
            % Include everything except field correction
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = true;
            options.include_instrumental = true;
            options.include_field = false;
        end
        
        function options = unityTransmission()
            % Unity transmission (all components neglected)
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            options = struct();
            options.include_atmospheric = false;
            options.include_instrumental = false;
            options.include_field = false;
        end
        
        function options = custom(atmospheric, instrumental, field)
            % Custom component inclusion
            %
            % Parameters:
            %   atmospheric (logical): Include atmospheric transmission
            %   instrumental (logical): Include instrumental transmission
            %   field (logical): Include field correction
            %
            % Returns:
            %   options (struct): Component inclusion options
            
            arguments
                atmospheric (1,1) logical
                instrumental (1,1) logical
                field (1,1) logical
            end
            
            options = struct();
            options.include_atmospheric = atmospheric;
            options.include_instrumental = instrumental;
            options.include_field = field;
        end
        
        function summary = printAvailableOptions()
            % Print summary of available component options
            %
            % Returns:
            %   summary (cell array): List of available options
            
            fprintf('Available Component Options:\n');
            fprintf('==========================\n');
            
            options_list = {
                'allComponents()', 'Include all transmission components';
                'atmosphericOnly()', 'Include only atmospheric transmission';
                'instrumentalOnly()', 'Include only instrumental transmission';
                'fieldOnly()', 'Include only field correction';
                'atmosphericAndInstrumental()', 'Include atmospheric and instrumental (no field)';
                'atmosphericAndField()', 'Include atmospheric and field (no instrumental)';
                'instrumentalAndField()', 'Include instrumental and field (no atmospheric)';
                'noAtmospheric()', 'Include everything except atmospheric';
                'noInstrumental()', 'Include everything except instrumental';
                'noField()', 'Include everything except field correction';
                'unityTransmission()', 'Unity transmission (all components neglected)';
                'custom(atm, inst, field)', 'Custom component inclusion'
            };
            
            for i = 1:size(options_list, 1)
                fprintf('  %-30s : %s\n', options_list{i, 1}, options_list{i, 2});
            end
            
            fprintf('\nExample Usage:\n');
            fprintf('options = transmission.v2.utils.ComponentOptions.atmosphericOnly();\n');
            fprintf('total_trans = transmission.v2.totalTransmission(Lam, params, atm_config, inst_config, field_config, options);\n');
            
            summary = options_list;
        end
    end
end