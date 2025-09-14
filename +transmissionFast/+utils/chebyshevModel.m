function Cheb_model = chebyshevModel(Dat, Config)
    % Calculate Chebyshev polynomial model for instrumental corrections
    % Input  : - Dat (double array): input data - coordinates (X,Y) of
    %            calibrators; or wavelength array
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Utils.ChebyshevModel.Default_coeffs
    %            Uses Config.Utils.ChebyshevModel.Default_mode ('tr'|'zp')
    %            Uses Config.Utils.RescaleInputData.Target_min/max for normalization
    % Output : - Cheb_model (double array): Exponential of Chebyshev polynomial expansion
    % Author : D. Kovaleva (Jul 2025)
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Example : % Basic usage with default config
    %           Config = transmissionFast.inputConfig('default');
    %           Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %           Cheb = transmissionFast.utils.chebyshevModel(Lam, Config);
    %           % Custom coefficients
    %           Config.Utils.ChebyshevModel.Default_coeffs = [0.1, -0.05, 0.02, -0.01, 0.005];
    %           Config.Utils.ChebyshevModel.Default_mode = 'tr';
    %           Cheb = transmissionFast.utils.chebyshevModel(Lam, Config);
    
    arguments
        Dat = transmissionFast.utils.makeWavelengthArray(transmissionFast.inputConfig())
        Config = transmissionFast.inputConfig()
    end
    
    
    % Extract parameters from Config
    Ci = Config.Utils.ChebyshevModel.Default_coeffs;
    Mode = Config.Utils.ChebyshevModel.Default_mode;
    Target_min = Config.Utils.RescaleInputData.Target_min;
    Target_max = Config.Utils.RescaleInputData.Target_max;
    
    % Transform coordinates to target range for Chebyshev polynomials
    Re_Dat = transmissionFast.utils.rescaleInputData(Dat, min(Dat), max(Dat), Target_min, Target_max, Config);
    Re_Dat = Re_Dat(:);  % Ensure column vector

    % Initialize Chebyshev polynomials using recursive relation
    Cheb_polynomials = repmat(0, length(Re_Dat), length(Ci));%#ok<*RPMT0>
    
    % T_0(x) = 1 (always included)
    Cheb_polynomials(:, 1) = repmat(1, size(Re_Dat));%#ok<*RPMT1>
    
    % T_1(x) = x (if degree >= 1)
    if length(Ci) >= 2
        Cheb_polynomials(:, 2) = Re_Dat;
    end
    
    % Generate higher order polynomials: T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
    for n = 2:length(Ci)-1
        Cheb_polynomials(:, n+1) = 2 * Re_Dat .* Cheb_polynomials(:, n) - Cheb_polynomials(:, n-1);
    end
    
    % Calculate Chebyshev expansion
    Cheb_expansion = repmat(0, size(Re_Dat));
    
    % Determine starting index based on mode
    if Mode == 'tr'
        % Transmission: use all coefficients starting from T_0
        k_start = 1;
    elseif Mode == 'zp'
        % Zero-point: skip T_0, start from T_1
        k_start = 2;
    end
    
    % Sum the polynomial expansion
    for k = k_start:length(Ci)
        Cheb_expansion = Cheb_expansion + Ci(k) * Cheb_polynomials(:, k);
    end
    
    % Return result based on mode
    if Mode == 'tr'
        % Transmission mode: return exponential of the expansion
        Cheb_model = exp(Cheb_expansion);
    elseif Mode == 'zp'
        % Zero-point mode: return expansion directly (no exponential)
        Cheb_model = Cheb_expansion;
    end
end