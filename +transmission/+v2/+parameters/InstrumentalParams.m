classdef InstrumentalParams < handle
    % Instrumental transmission parameter templates
    % Pre-configured parameter sets for instrumental models (QE, Mirror, Corrector)
    % NOTE: Field correction (r0-r4) is handled separately in FieldParams
    
    methods (Static)
        function config = getStandardConfig()
            % Get standard instrumental parameter configuration
            %
            % Returns:
            %   config (ParameterConfig): Configured instrumental parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Quantum Efficiency - Skewed Gaussian parameters
            config.addParameter("qe_amplitude", 328.19, false, [50, 1000], "QE Skewed Gaussian amplitude");
            config.addParameter("qe_center", 570.97, false, [400, 800], "QE Skewed Gaussian center wavelength (nm)");
            config.addParameter("qe_sigma", 139.77, false, [50, 300], "QE Skewed Gaussian width parameter");
            config.addParameter("qe_gamma", -0.1517, false, [-2, 2], "QE Skewed Gaussian skewness parameter");
            
            % Quantum Efficiency - Legendre polynomial coefficients (disturbation model)
            config.addParameter("l0", -0.30, false, [-5, 5], "Legendre coefficient 0 (constant)");
            config.addParameter("l1", 0.34, false, [-5, 5], "Legendre coefficient 1 (linear)");
            config.addParameter("l2", -1.89, false, [-5, 5], "Legendre coefficient 2");
            config.addParameter("l3", -0.82, false, [-5, 5], "Legendre coefficient 3");
            config.addParameter("l4", -3.73, false, [-5, 5], "Legendre coefficient 4");
            config.addParameter("l5", -0.669, false, [-5, 5], "Legendre coefficient 5");
            config.addParameter("l6", -2.06, false, [-5, 5], "Legendre coefficient 6");
            config.addParameter("l7", -0.24, false, [-5, 5], "Legendre coefficient 7");
            config.addParameter("l8", -0.60, false, [-5, 5], "Legendre coefficient 8");
            
            % Mirror and Corrector control
            config.addParameter("use_mirror_data", 1.0, true, [0, 1], "Use mirror data file (1) or polynomial (0)");
            config.addParameter("use_corrector_data", 1.0, true, [0, 1], "Use corrector data file (1) or polynomial (0)");
        end
        
        function config = getQEOnlyConfig()
            % Configuration for QE fitting only
            %
            % Returns:
            %   config (ParameterConfig): QE-only parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Only QE parameters free
            config.addParameter("qe_amplitude", 328.19, false, [50, 1000], "QE Skewed Gaussian amplitude");
            config.addParameter("qe_center", 570.97, false, [400, 800], "QE Skewed Gaussian center wavelength (nm)");
            config.addParameter("qe_sigma", 139.77, false, [50, 300], "QE Skewed Gaussian width parameter");
            config.addParameter("qe_gamma", -0.1517, true, [-2, 2], "QE Skewed Gaussian skewness (FIXED)");
            
            % Legendre coefficients - simplified (only first few terms)
            config.addParameter("l0", -0.30, false, [-5, 5], "Legendre coefficient 0");
            config.addParameter("l1", 0.34, false, [-5, 5], "Legendre coefficient 1");
            config.addParameter("l2", -1.89, false, [-5, 5], "Legendre coefficient 2");
            config.addParameter("l3", 0.0, true, [-5, 5], "Legendre coefficient 3 (FIXED)");
            config.addParameter("l4", 0.0, true, [-5, 5], "Legendre coefficient 4 (FIXED)");
            config.addParameter("l5", 0.0, true, [-5, 5], "Legendre coefficient 5 (FIXED)");
            config.addParameter("l6", 0.0, true, [-5, 5], "Legendre coefficient 6 (FIXED)");
            config.addParameter("l7", 0.0, true, [-5, 5], "Legendre coefficient 7 (FIXED)");
            config.addParameter("l8", 0.0, true, [-5, 5], "Legendre coefficient 8 (FIXED)");
        end
        
        function config = getLegendreOnlyConfig()
            % Configuration for Legendre disturbation fitting only
            %
            % Returns:
            %   config (ParameterConfig): Legendre-only parameter object
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Fixed Skewed Gaussian
            config.addParameter("qe_amplitude", 328.19, true, [50, 1000], "QE amplitude (FIXED)");
            config.addParameter("qe_center", 570.97, true, [400, 800], "QE center (FIXED)");
            config.addParameter("qe_sigma", 139.77, true, [50, 300], "QE sigma (FIXED)");
            config.addParameter("qe_gamma", -0.1517, true, [-2, 2], "QE gamma (FIXED)");
            
            % Free Legendre coefficients
            config.addParameter("l0", -0.30, false, [-5, 5], "Legendre coefficient 0");
            config.addParameter("l1", 0.34, false, [-5, 5], "Legendre coefficient 1");
            config.addParameter("l2", -1.89, false, [-5, 5], "Legendre coefficient 2");
            config.addParameter("l3", -0.82, false, [-5, 5], "Legendre coefficient 3");
            config.addParameter("l4", -3.73, false, [-5, 5], "Legendre coefficient 4");
            config.addParameter("l5", -0.669, false, [-5, 5], "Legendre coefficient 5");
            config.addParameter("l6", -2.06, false, [-5, 5], "Legendre coefficient 6");
            config.addParameter("l7", -0.24, false, [-5, 5], "Legendre coefficient 7");
            config.addParameter("l8", -0.60, false, [-5, 5], "Legendre coefficient 8");
        end
        
        function config = getMinimalConfig()
            % Minimal instrumental configuration for quick fitting
            %
            % Returns:
            %   config (ParameterConfig): Minimal instrumental parameters
            
            import transmission.v2.parameters.ParameterConfig
            config = ParameterConfig();
            
            % Only essential QE parameters
            config.addParameter("qe_amplitude", 328.19, false, [50, 1000], "QE amplitude");
            config.addParameter("qe_center", 570.97, false, [400, 800], "QE center wavelength");
            config.addParameter("qe_sigma", 139.77, false, [50, 300], "QE width");
            config.addParameter("qe_gamma", 0.0, true, [-2, 2], "QE skewness (FIXED)");
            
            % Minimal Legendre (constant + linear)
            config.addParameter("l0", 0.0, false, [-2, 2], "Legendre constant");
            config.addParameter("l1", 0.0, false, [-2, 2], "Legendre linear");
            config.addParameter("l2", 0.0, true, [-5, 5], "Legendre quadratic (FIXED)");
            config.addParameter("l3", 0.0, true, [-5, 5], "Legendre cubic (FIXED)");
            config.addParameter("l4", 0.0, true, [-5, 5], "Legendre quartic (FIXED)");
            config.addParameter("l5", 0.0, true, [-5, 5], "Legendre quintic (FIXED)");
            config.addParameter("l6", 0.0, true, [-5, 5], "Legendre sextic (FIXED)");
            config.addParameter("l7", 0.0, true, [-5, 5], "Legendre septic (FIXED)");
            config.addParameter("l8", 0.0, true, [-5, 5], "Legendre octic (FIXED)");
        end
    end
end