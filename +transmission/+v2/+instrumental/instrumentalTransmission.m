function inst_trans = instrumentalTransmission(wavelength, param_values, config)
    % V2 Instrumental transmission with flexible parameter arrays
    %
    % Parameters:
    %   wavelength (double array): Wavelength array in nm
    %   param_values (double array): Parameter values (only free parameters)
    %   config (ParameterConfig): Parameter configuration object
    %
    % Returns:
    %   inst_trans (double array): Instrumental transmission values
    %
    % Example:
    %   import transmission.v2.parameters.InstrumentalParams
    %   config = InstrumentalParams.getStandardConfig();
    %   param_values = config.getFreeParameters();
    %   Lam = transmission.utils.makeWavelengthArray(400, 800, 201);
    %   inst_trans = transmission.v2.instrumental.instrumentalTransmission(Lam, param_values, config);
    
    arguments
        wavelength (:,1) double
        param_values (:,1) double
        config (1,1) transmission.v2.parameters.ParameterConfig
    end
    
    % Update parameter values in config
    config.setFreeParameters(param_values);
    
    % Get all parameter values (fixed + free)
    all_params = config.getAllParameters();
    
    % Initialize instrumental transmission
    inst_trans = ones(size(wavelength));
    
    % Quantum Efficiency (QE) - Skewed Gaussian + Legendre polynomial
    if config.hasParameter('qe_amplitude')
        % Extract QE parameters
        qe_amplitude = all_params.qe_amplitude;
        qe_center = all_params.qe_center;
        qe_sigma = all_params.qe_sigma;
        qe_gamma = all_params.qe_gamma;
        
        % Extract Legendre coefficients
        legendre_coeffs = [];
        for i = 0:8
            coeff_name = sprintf('l%d', i);
            if config.hasParameter(coeff_name)
                legendre_coeffs(i+1) = all_params.(coeff_name);
            else
                legendre_coeffs(i+1) = 0.0;
            end
        end
        
        % Create QE parameter structure
        qe_params = struct();
        qe_params.amplitude = qe_amplitude;
        qe_params.center = qe_center;
        qe_params.sigma = qe_sigma;
        qe_params.gamma = qe_gamma;
        qe_params.l0 = legendre_coeffs(1);
        qe_params.l1 = legendre_coeffs(2);
        qe_params.l2 = legendre_coeffs(3);
        qe_params.l3 = legendre_coeffs(4);
        qe_params.l4 = legendre_coeffs(5);
        qe_params.l5 = legendre_coeffs(6);
        qe_params.l6 = legendre_coeffs(7);
        qe_params.l7 = legendre_coeffs(8);
        qe_params.l8 = legendre_coeffs(9);
        
        % Calculate QE transmission
        qe_trans = transmission.instrumental.qeTransmission(wavelength, qe_params);
        inst_trans = inst_trans .* qe_trans;
    end
    
    % Mirror transmission
    if config.hasParameter('use_mirror_data')
        use_mirror_data = all_params.use_mirror_data > 0.5;
        
        if use_mirror_data
            % Use mirror data file
            mirror_params = struct('use_orig_xlt', true);
        else
            % Use mirror polynomial (if coefficients are available)
            mirror_params = struct('use_orig_xlt', false);
            % Add mirror polynomial coefficients if they exist
            for i = 0:4
                coeff_name = sprintf('mirror_c%d', i);
                if config.hasParameter(coeff_name)
                    mirror_params.(sprintf('c%d', i)) = all_params.(coeff_name);
                end
            end
        end
        
        mirror_trans = transmission.instrumental.mirrorTransmission(wavelength, mirror_params);
        inst_trans = inst_trans .* mirror_trans;
    end
    
    % Corrector transmission
    if config.hasParameter('use_corrector_data')
        use_corrector_data = all_params.use_corrector_data > 0.5;
        
        if use_corrector_data
            % Use corrector data file
            corrector_params = struct();
            corrector_params.c0 = 0;
            corrector_params.c1 = 0;
            corrector_params.c2 = 0;
            corrector_params.c3 = 0;
            corrector_params.c4 = 0;
        else
            % Use corrector polynomial
            corrector_params = struct();
            for i = 0:4
                coeff_name = sprintf('corrector_c%d', i);
                if config.hasParameter(coeff_name)
                    corrector_params.(sprintf('c%d', i)) = all_params.(coeff_name);
                else
                    corrector_params.(sprintf('c%d', i)) = 0;
                end
            end
        end
        
        corrector_trans = transmission.instrumental.correctorTransmission(wavelength, corrector_params);
        inst_trans = inst_trans .* corrector_trans;
    end
    
    % Filter transmission (if configured)
    if config.hasParameter('filter_center')
        filter_center = all_params.filter_center;
        filter_width = all_params.filter_width;
        filter_type = 'gaussian';  % Default
        
        if config.hasParameter('filter_type')
            filter_type = all_params.filter_type;
        end
        
        % Create filter parameter structure
        filter_params = struct();
        filter_params.center = filter_center;
        filter_params.width = filter_width;
        filter_params.type = filter_type;
        
        % Apply filter transmission
        switch filter_type
            case 'gaussian'
                filter_trans = exp(-0.5 * ((wavelength - filter_center) / filter_width).^2);
            case 'lorentzian'
                filter_trans = 1 ./ (1 + ((wavelength - filter_center) / filter_width).^2);
            case 'tophat'
                filter_trans = double(abs(wavelength - filter_center) <= filter_width/2);
            otherwise
                filter_trans = ones(size(wavelength));
        end
        
        inst_trans = inst_trans .* filter_trans;
    end
    
    % Detector efficiency (if configured)
    if config.hasParameter('detector_efficiency')
        detector_efficiency = all_params.detector_efficiency;
        inst_trans = inst_trans * detector_efficiency;
    end
    
    % Detector quantum efficiency curve (if configured)
    if config.hasParameter('detector_qe_scale')
        detector_qe_scale = all_params.detector_qe_scale;
        
        % Simple detector QE model (can be extended)
        detector_qe = detector_qe_scale * (wavelength / 550).^(-0.5);  % Example wavelength dependence
        detector_qe = min(detector_qe, 1.0);  % Cap at 100% efficiency
        
        inst_trans = inst_trans .* detector_qe;
    end
    
    % Optical system losses (if configured)
    if config.hasParameter('optical_losses')
        optical_losses = all_params.optical_losses;
        inst_trans = inst_trans * (1 - optical_losses);
    end
    
    % Ensure positive values
    inst_trans = max(inst_trans, 1e-10);
end