classdef AtmosphericParams < handle
    % Atmospheric transmission parameter templates
    % Pre-configured parameter sets for atmospheric models
    
    methods (Static)
        function config = getStandardConfig()
            % Get standard atmospheric parameter configuration
            %
            % Returns:
            %   config (ParameterConfig): Configured parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Atmospheric observation conditions
            config.addParameter("zenith_angle", 30.0, false, [0, 89], "Zenith angle in degrees");
            config.addParameter("pressure", 1013.25, false, [500, 1100], "Surface pressure in mbar");
            config.addParameter("temperature", 15.0, false, [-20, 50], "Air temperature in °C");
            
            % Rayleigh scattering (usually fixed - physical constants)
            config.addParameter("rayleigh_scale", 1.0, true, [0.5, 2.0], "Rayleigh scattering scale factor");
            
            % Aerosol parameters
            config.addParameter("aod_500", 0.1, false, [0.01, 1.0], "Aerosol optical depth at 500nm");
            config.addParameter("angstrom_exp", 1.3, false, [0.1, 3.0], "Angstrom exponent");
            
            % Ozone parameters
            config.addParameter("ozone_dobson", 300.0, false, [100, 500], "Ozone column in Dobson units");
            config.addParameter("ozone_scale", 1.0, true, [0.5, 2.0], "Ozone cross-section scale factor");
            
            % Water vapor parameters
            config.addParameter("precipitable_water", 2.0, false, [0.1, 10.0], "Precipitable water in cm");
            config.addParameter("water_scale", 1.0, true, [0.5, 2.0], "Water vapor scale factor");
            
            % UMG parameters
            config.addParameter("co2_ppm", 415.0, false, [350, 500], "CO2 concentration in ppm");
            config.addParameter("umg_scale", 1.0, true, [0.5, 2.0], "UMG scale factor");
        end
        
        function config = getRayleighConfig()
            % Configuration for Rayleigh scattering only
            %
            % Returns:
            %   config (ParameterConfig): Rayleigh parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            config.addParameter("zenith_angle", 30.0, false, [0, 89], "Zenith angle in degrees");
            config.addParameter("pressure", 1013.25, false, [500, 1100], "Surface pressure in mbar");
            config.addParameter("rayleigh_scale", 1.0, false, [0.5, 2.0], "Rayleigh scattering scale factor");
        end
        
        function config = getAerosolConfig()
            % Configuration for aerosol extinction only
            %
            % Returns:
            %   config (ParameterConfig): Aerosol parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            config.addParameter("zenith_angle", 30.0, false, [0, 89], "Zenith angle in degrees");
            config.addParameter("aod_500", 0.1, false, [0.01, 1.0], "Aerosol optical depth at 500nm");
            config.addParameter("angstrom_exp", 1.3, false, [0.1, 3.0], "Angstrom exponent");
            config.addParameter("aerosol_scale", 1.0, false, [0.1, 5.0], "Aerosol scale factor");
        end
        
        function config = getAdvancedAerosolConfig()
            % Advanced aerosol configuration with multiple components
            %
            % Returns:
            %   config (ParameterConfig): Advanced aerosol parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            config.addParameter("zenith_angle", 30.0, false, [0, 89], "Zenith angle in degrees");
            
            % Component 1: Fine mode aerosols
            config.addParameter("aod_500_fine", 0.07, false, [0.001, 0.5], "Fine mode AOD at 500nm");
            config.addParameter("angstrom_fine", 1.8, false, [1.0, 3.0], "Fine mode Angstrom exponent");
            config.addParameter("fine_fraction", 0.7, false, [0.1, 1.0], "Fine mode fraction");
            
            % Component 2: Coarse mode aerosols  
            config.addParameter("aod_500_coarse", 0.03, false, [0.001, 0.5], "Coarse mode AOD at 500nm");
            config.addParameter("angstrom_coarse", 0.5, false, [0.1, 1.5], "Coarse mode Angstrom exponent");
        end
        
        function config = getWaterVaporConfig()
            % Configuration for water vapor absorption only
            %
            % Returns:
            %   config (ParameterConfig): Water vapor parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            config.addParameter("zenith_angle", 30.0, false, [0, 89], "Zenith angle in degrees");
            config.addParameter("pressure", 1013.25, false, [500, 1100], "Surface pressure in mbar");
            config.addParameter("precipitable_water", 2.0, false, [0.1, 10.0], "Precipitable water in cm");
            config.addParameter("water_scale", 1.0, false, [0.5, 2.0], "Water vapor scale factor");
            
            % Advanced water vapor parameters
            config.addParameter("water_temp_coeff", 0.0, true, [-0.01, 0.01], "Temperature dependence coefficient");
            config.addParameter("water_pressure_coeff", 0.0, true, [-0.001, 0.001], "Pressure dependence coefficient");
        end
        
        function config = getMinimalConfig()
            % Minimal configuration for quick testing
            %
            % Returns:
            %   config (ParameterConfig): Minimal parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            config.addParameter("zenith_angle", 30.0, false, [0, 89], "Zenith angle in degrees");
            config.addParameter("aod_500", 0.1, false, [0.01, 1.0], "Aerosol optical depth at 500nm");
            config.addParameter("precipitable_water", 2.0, false, [0.1, 10.0], "Precipitable water in cm");
        end
    end
end