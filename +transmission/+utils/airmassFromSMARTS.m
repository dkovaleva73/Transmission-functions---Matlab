function Airmass = airmassFromSMARTS(Z_, Constituent)
    % Calculate the airmass using SMARTS2.9.5 tabulated values.
    % Input:   - Z_ (double): The zenith angle in degrees.
    %          - Constituent (char): The atmospheric constituent. Default is 'rayleigh'.
    %            Constituents available are: 'rayleigh'; 'aerosol'; 'o3'/'ozone';
    %            'h2o'/'water'; 'o2'; 'ch4'; 'co'; 'n2o'; 'co2'; 'n2'; 'hno3';
    %            'no2'; 'no'; 'so2'; 'nh3'.
    % Output:  - Airmass (double): The calculated airmass.
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author:    D. Kovaleva (July 2025).
    % Example:   Am_ = transmission.utils.airmassFromSMARTS(Z_, 'rayleigh');
    arguments
        Z_
        Constituent = 'rayleigh';
    end
    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end
    
    % Define coefficients for different atmospheric constituents
    Coefs = containers.Map();
    Coefs('rayleigh') = [0.48353, 0.095846,  96.741, -1.754];
    Coefs('aerosol')  = [0.16851, 0.18198,   95.318, -1.9542];
    Coefs('o3')       = [1.0651,  0.6379,   101.8,   -2.2694];
    Coefs('h2o')      = [0.10648, 0.11423,   93.781, -1.9203];
    Coefs('o2')       = [0.65779, 0.064713,  96.974, -1.8084];
    Coefs('ch4')      = [0.49381, 0.35569,   98.23,  -2.1616];
    Coefs('co')       = [0.505,   0.063191,  95.899, -1.917];
    Coefs('n2o')      = [0.61696, 0.060787,  96.632, -1.8279];
    Coefs('co2')      = [0.65786, 0.064688,  96.974, -1.8083];
    Coefs('n2')       = [0.38155, 8.871e-05, 95.195, -1.8053];
    Coefs('hno3')     = [1.044,   0.78456,  103.15,  -2.4794];
    Coefs('no2')      = [1.1212,  1.6132,   111.55,  -3.2629];
    Coefs('no')       = [0.77738, 0.11075,  100.34,  -1.5794];
    Coefs('so2')      = [0.63454, 0.00992,   95.804, -2.0573];
    Coefs('nh3')      = [0.32101, 0.010793,  94.337, -2.0548];
    
    % Add aliases
    Coefs('no3')   = Coefs('no2');
    Coefs('bro')   = Coefs('o3');
    Coefs('ch2o')  = Coefs('n2o');
    Coefs('hno2')  = Coefs('hno3');
    Coefs('clno')  = Coefs('no2');
    Coefs('ozone') = Coefs('o3');
    Coefs('water') = Coefs('h2o');
    
    % Check if constituent is valid
    Constituent_lower = lower(Constituent);
    if ~isKey(Coefs, Constituent_lower)
        error('%s is not a valid constituent.', Constituent);
    end
    
    % Get coefficients
    P = Coefs(Constituent_lower);
    
    % Calculate airmass
    Cosz = cos(deg2rad(Z_));
    Airmass = 1 / (Cosz + P(1) * (Z_^P(2)) * (P(3) - Z_)^P(4));
end