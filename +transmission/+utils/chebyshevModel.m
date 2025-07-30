function Cheb_model = chebyshevModel(Dat, Degr, Ci, Args)
    % Calculate Chebyshev polynomial model for instrumental corrections
    % Input  : - Coo (double array): input data - coordinates (X,Y) of
    %            calibrators; or wavelength array
    %          - Degr (integer): degree of Chebyshev polynomial
    %          - Ci (double): vector of Chebyshev polynomial coefficient    
    % Output : - Cheb_model (double array): Exponential of Chebyshev polynomial expansion
    %          * ...,key,val,... 
    %         'X' - 'tr'|'zp' (what we are disturbing,transmission | photometric zero-point. 
    %          'tr' - wavelengths for argument, 'zp' - coordinates for
    %          argument.
    % Author : D. Kovaleva (Jul 2025)
    % Reference : Garrappa et al. 2025, A&A 699, A50.
    % Example : % Basic usage with default coefficients for transmission
    %           Cheb = transmission.utils.chebyshevModel();
    %           % Custom wavelength array with 4th degree polynomial for transmission
    %           Lam = linspace(350, 950, 301)';
    %           Cheb = transmission.utils.chebyshevModel(Lam, 4, [0.1 -0.05 0.02 -0.01 0.005], 'X', 'tr');
    %           % Custom coordinate array for photometric zero-point
    %           % Note: For 'zp', first coefficient (for T_0) is ignored
    %           Coords = linspace(1, 1726, 1726)';
    %           Cheb = transmission.utils.chebyshevModel(Coords, 4, [0.0 0.1 -0.05 0.02 -0.01], 'X', 'zp');
    %           % 1st order (linear) for zero-point (only T_1 is used)
    %           Cheb = transmission.utils.chebyshevModel(Coords, 1, [0.0 0.1], 'X', 'zp');
    
    arguments
        Dat = transmission.utils.makeWavelengthArray() 
        Degr = 4
        Ci = [0.0, 0.0, 0.0, 0.0, 0.0]  % Default: no correction (all zeros)
        Args.X = 'zp' 
       
    end
    
    
    % Check coefficient vector length
    if length(Ci) ~= (Degr + 1)
        error('transmission:chebyshevModel:coefficientMismatch', ...
              'Number of coefficients (%d) must equal degree + 1 (%d)', ...
              length(Ci), Degr + 1);
    end
    
    % Transform wavelength to [-1, 1] range for Chebyshev polynomials
    if numel(Dat) == 1 || (max(Dat) - min(Dat)) < eps
        % Single point or all same values: already normalized
        Re_Dat = Dat(:);
    else
        Re_Dat = transmission.utils.rescaleInputData(Dat, min(Dat), max(Dat), -1.0, 1.0);
        Re_Dat = Re_Dat(:);  % Ensure column vector
    end

    % Initialize Chebyshev polynomials using recursive relation
    Cheb_polynomials = repmat(0, length(Re_Dat), Degr + 1);%#ok<*RPMT0>
    
    % T_0(x) = 1 (always included)
    Cheb_polynomials(:, 1) = repmat(1, size(Re_Dat));%#ok<*RPMT1>
    
    % T_1(x) = x (if degree >= 1)
    if Degr >= 1
        Cheb_polynomials(:, 2) = Re_Dat;
    end
    
    % Generate higher order polynomials: T_n(x) = 2*x*T_{n-1}(x) - T_{n-2}(x)
    for n = 2:Degr
        Cheb_polynomials(:, n+1) = 2 * Re_Dat .* Cheb_polynomials(:, n) - Cheb_polynomials(:, n-1);
    end
    
    % Calculate Chebyshev expansion
    Cheb_expansion = repmat(0, size(Re_Dat));
    
    % Determine starting index based on mode
    if Args.X == 'tr'
        % Transmission: use all coefficients starting from T_0
        k_start = 1;
    elseif Args.X == 'zp'
        % Zero-point: skip T_0, start from T_1
        k_start = 2;
    end
    
    % Sum the polynomial expansion
    for k = k_start:(Degr + 1)
        Cheb_expansion = Cheb_expansion + Ci(k) * Cheb_polynomials(:, k);
    end
    
    % Return result based on mode
    if Args.X == 'tr'
        % Transmission mode: return exponential of the expansion
        Cheb_model = exp(Cheb_expansion);
    elseif Args.X == 'zp'
        % Zero-point mode: return expansion directly (no exponential)
        Cheb_model = Cheb_expansion;
    end
end