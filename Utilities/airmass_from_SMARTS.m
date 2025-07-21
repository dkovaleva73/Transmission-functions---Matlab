function airmass = airmass_from_SMARTS(z_, constituent)
    % Calculate the airmass using SMARTS2.9.5 tabulated values.
    %
    % Parameters:
    %   z_ (double): The zenith angle in degrees.
    %   constituent (char): The atmospheric constituent. Default is 'rayleigh'.
    %
    % Returns:
    %   airmass (double): The calculated airmass.
    %
    % Raises:
    %   error: If the constituent is not valid.
    
    if nargin < 2
        constituent = 'rayleigh';
    end
    
    % Define coefficients for different atmospheric constituents
    coefs = containers.Map();
    coefs('rayleigh') = [0.48353, 0.095846,  96.741, -1.754];
    coefs('aerosol')  = [0.16851, 0.18198,   95.318, -1.9542];
    coefs('o3')       = [1.0651,  0.6379,   101.8,   -2.2694];
    coefs('h2o')      = [0.10648, 0.11423,   93.781, -1.9203];
    coefs('o2')       = [0.65779, 0.064713,  96.974, -1.8084];
    coefs('ch4')      = [0.49381, 0.35569,   98.23,  -2.1616];
    coefs('co')       = [0.505,   0.063191,  95.899, -1.917];
    coefs('n2o')      = [0.61696, 0.060787,  96.632, -1.8279];
    coefs('co2')      = [0.65786, 0.064688,  96.974, -1.8083];
    coefs('n2')       = [0.38155, 8.871e-05, 95.195, -1.8053];
    coefs('hno3')     = [1.044,   0.78456,  103.15,  -2.4794];
    coefs('no2')      = [1.1212,  1.6132,   111.55,  -3.2629];
    coefs('no')       = [0.77738, 0.11075,  100.34,  -1.5794];
    coefs('so2')      = [0.63454, 0.00992,   95.804, -2.0573];
    coefs('nh3')      = [0.32101, 0.010793,  94.337, -2.0548];
    
    % Add aliases
    coefs('no3')   = coefs('no2');
    coefs('bro')   = coefs('o3');
    coefs('ch2o')  = coefs('n2o');
    coefs('hno2')  = coefs('hno3');
    coefs('clno')  = coefs('no2');
    coefs('ozone') = coefs('o3');
    coefs('water') = coefs('h2o');
    
    % Check if constituent is valid
    constituent_lower = lower(constituent);
    if ~isKey(coefs, constituent_lower)
        error('%s is not a valid constituent.', constituent);
    end
    
    % Get coefficients
    p = coefs(constituent_lower);
    
    % Calculate airmass
    cosz = cos(deg2rad(z_));
    airmass = 1 / (cosz + p(1) * (z_^p(2)) * (p(3) - z_)^p(4));
end
