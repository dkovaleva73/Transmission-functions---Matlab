classdef FieldParams < handle
    % Field correction parameter templates
    % Pre-configured parameter sets for Chebyshev field correction
    
    methods (Static)
        function config = getStandardConfig()
            % Get standard field correction parameter configuration
            %
            % Returns:
            %   config (ParameterConfig): Configured field parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Chebyshev field correction coefficients (r0-r4)
            config.addParameter("r0", 0.0, false, [-10, 10], "Chebyshev field correction coefficient 0 (constant)");
            config.addParameter("r1", 0.0, false, [-10, 10], "Chebyshev field correction coefficient 1 (linear)");
            config.addParameter("r2", 0.0, false, [-10, 10], "Chebyshev field correction coefficient 2 (quadratic)");
            config.addParameter("r3", 0.0, false, [-10, 10], "Chebyshev field correction coefficient 3 (cubic)");
            config.addParameter("r4", 0.0, false, [-10, 10], "Chebyshev field correction coefficient 4 (quartic)");
        end
        
        function config = getDisabledConfig()
            % Field correction disabled (all coefficients fixed at 0)
            %
            % Returns:
            %   config (ParameterConfig): Disabled field correction parameters
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % All coefficients fixed at 0 (no field correction)
            config.addParameter("r0", 0.0, true, [-10, 10], "Chebyshev field correction coefficient 0 (DISABLED)");
            config.addParameter("r1", 0.0, true, [-10, 10], "Chebyshev field correction coefficient 1 (DISABLED)");
            config.addParameter("r2", 0.0, true, [-10, 10], "Chebyshev field correction coefficient 2 (DISABLED)");
            config.addParameter("r3", 0.0, true, [-10, 10], "Chebyshev field correction coefficient 3 (DISABLED)");
            config.addParameter("r4", 0.0, true, [-10, 10], "Chebyshev field correction coefficient 4 (DISABLED)");
        end
        
        function config = getLinearOnlyConfig()
            % Only linear field correction (r0, r1 free, others fixed)
            %
            % Returns:
            %   config (ParameterConfig): Linear field correction parameters
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Linear field correction only
            config.addParameter("r0", 0.0, false, [-10, 10], "Chebyshev constant term");
            config.addParameter("r1", 0.0, false, [-10, 10], "Chebyshev linear term");
            config.addParameter("r2", 0.0, true, [-10, 10], "Chebyshev quadratic term (FIXED)");
            config.addParameter("r3", 0.0, true, [-10, 10], "Chebyshev cubic term (FIXED)");
            config.addParameter("r4", 0.0, true, [-10, 10], "Chebyshev quartic term (FIXED)");
        end
        
        function config = getQuadraticConfig()
            % Quadratic field correction (r0, r1, r2 free)
            %
            % Returns:
            %   config (ParameterConfig): Quadratic field correction parameters
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Quadratic field correction
            config.addParameter("r0", 0.0, false, [-10, 10], "Chebyshev constant term");
            config.addParameter("r1", 0.0, false, [-10, 10], "Chebyshev linear term");
            config.addParameter("r2", 0.0, false, [-10, 10], "Chebyshev quadratic term");
            config.addParameter("r3", 0.0, true, [-10, 10], "Chebyshev cubic term (FIXED)");
            config.addParameter("r4", 0.0, true, [-10, 10], "Chebyshev quartic term (FIXED)");
        end
        
        function config = getCustomConfig(free_orders)
            % Custom field correction with specified free orders
            %
            % Parameters:
            %   free_orders (array): Orders to keep free (e.g., [0, 1, 2])
            %
            % Returns:
            %   config (ParameterConfig): Custom field correction parameters
            
            arguments
                free_orders (1,:) double = [0, 1]
            end
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % All orders (0-4)
            all_orders = 0:4;
            
            for order = all_orders
                param_name = sprintf("r%d", order);
                is_fixed = ~ismember(order, free_orders);
                
                if is_fixed
                    description = sprintf("Chebyshev coefficient %d (FIXED)", order);
                else
                    description = sprintf("Chebyshev coefficient %d (FREE)", order);
                end
                
                config.addParameter(param_name, 0.0, is_fixed, [-10, 10], description);
            end
        end
        
        function config = getTestConfig()
            % Test configuration with known coefficients
            %
            % Returns:
            %   config (ParameterConfig): Test field correction parameters
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Test values for validation
            config.addParameter("r0", 0.1, false, [-10, 10], "Chebyshev test coefficient 0");
            config.addParameter("r1", -0.05, false, [-10, 10], "Chebyshev test coefficient 1");
            config.addParameter("r2", 0.02, false, [-10, 10], "Chebyshev test coefficient 2");
            config.addParameter("r3", 0.0, true, [-10, 10], "Chebyshev test coefficient 3 (FIXED)");
            config.addParameter("r4", 0.0, true, [-10, 10], "Chebyshev test coefficient 4 (FIXED)");
        end
    end
end