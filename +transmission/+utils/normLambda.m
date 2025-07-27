function New_lambda = normLambda(Lam, Min_wvl, Max_wvl, Min_norm, Max_norm)
    % Normalize wavelength array to target range for orthogonal polynomial basis functions
    % (Jakobi, including Legendre, Chebyshev)
    % Input  : - Lam (double array): Wavelength array in nm
    %          - Min_wvl (double): Minimum wavelength of the array (default from makeWavelengthArray)
    %          - Max_wvl (double): Maximum wavelength of the array (default from makeWavelengthArray)
    %          - Min_norm (double): Minimum value for new lambda (default: -1, for Legendre/Chebyshev polynoms)
    %          - Max_norm (double): Maximum value for new lambda (default: +1, for Legendre/Chebyshev polynoms)
    % Output :   New_lambda (double array): Transformed wavelength array
    % Get default wavelength range from makeWavelengthArray
    % Author : D. Kovaleva (Jul 2025)
    % Example : % Basic usage with defaults (normalizes to [-1,+1] for Legendre polynomials)
    %           Lam_norm = transmission.utils.normLambda();
    %           % Custom wavelength range
    %           Lam_norm = transmission.utils.normLambda(Lam, 400, 800);
    %           % Custom normalization range (e.g., [0,1] for other polynomial bases)
    %           Lam_norm = transmission.utils.normLambda(Lam, 300, 1100, 0, 1);

arguments
     Lam  = transmission.utils.makeWavelengthArray()
     Min_wvl = min(Lam)
     Max_wvl = max(Lam)
     Min_norm = -1
     Max_norm = 1
end
    
    % Validate wavelength bounds
    if Min_wvl >= Max_wvl
        error('transmission:normLambda:invalidBounds', ...
              'Min_wvl must be less than Max_wvl');
    end
    if Min_wvl < min(Lam) || Max_wvl > max(Lam)
        error('transmission:normLambda:boundsOutOfRange', ...
              'Normalization bounds [%.1f, %.1f] exceed wavelength array range [%.1f, %.1f]', ...
              Min_wvl, Max_wvl, min(Lam), max(Lam));
    end
    
    % Linear transformation to map [Min_wvl, Max_wvl] to [Min_norm, Max_norm]
    New_lambda = (Max_norm - Min_norm) ./ (Max_wvl - Min_wvl) .* (Lam - Max_wvl) + Max_norm;
end