function zenithAngle = airmassToZenithAngle(airmass, constituent)
    % Convert airmass back to zenith angle for a specific atmospheric constituent
    % This reverses the SMARTS airmass calculation
    %
    % Input:
    %   airmass - Airmass value from observations
    %   constituent - Atmospheric constituent (default: 'rayleigh')
    %
    % Output:
    %   zenithAngle - Zenith angle in degrees
    %
    % Note: This uses numerical root finding to invert the SMARTS formula
    %
    % Author: D. Kovaleva (Sep 2025)
    
    arguments
        airmass (1,1) double {mustBePositive}
        constituent string = "rayleigh"
    end
    
    % Validate airmass range (1.0 to ~40 for zenith angles 0-89°)
    if airmass < 1.0 || airmass > 50
        error('Airmass %.2f is out of reasonable range [1.0, 50]', airmass);
    end
    
    % Get SMARTS coefficients for the constituent
    constituent_lower = lower(constituent);
    
    % Define coefficients (same as in airmassFromSMARTS)
    coefs = containers.Map();
    coefs('rayleigh') = [0.48353, 0.095846,  96.741, -1.754];
    coefs('aerosol')  = [0.16851, 0.18198,   95.318, -1.9542];
    coefs('o3')       = [1.0651,  0.6379,   101.8,   -2.2694];
    coefs('h2o')      = [0.10648, 0.11423,   93.781, -1.9203];
    coefs('ozone')    = coefs('o3');
    coefs('water')    = coefs('h2o');
    
    if ~isKey(coefs, constituent_lower)
        % Default to rayleigh if constituent not found
        warning('Unknown constituent %s, using rayleigh coefficients', constituent);
        constituent_lower = 'rayleigh';
    end
    
    P = coefs(constituent_lower);
    
    % Define the SMARTS airmass function to find root of
    % airmass = 1 / (cos(Z) + P(1) * (Z^P(2)) * (P(3) - Z)^P(4))
    % We want to solve: f(Z) = airmass_calculated - airmass_target = 0
    airmassFunc = @(Z_deg) (1 ./ (cos(deg2rad(Z_deg)) + P(1) .* (Z_deg.^P(2)) .* (P(3) - Z_deg).^P(4))) - airmass;
    
    % Find root using fzero (robust numerical root finder)
    try
        % Search in reasonable range: 0° to 85° zenith angle
        zenithAngle = fzero(airmassFunc, [0, 85]);
        
        % Validate result
        if zenithAngle < 0 || zenithAngle > 90
            error('Calculated zenith angle %.2f° is out of range [0°, 90°]', zenithAngle);
        end
        
    catch ME
        % If root finding fails, use simple approximation for small angles
        if airmass <= 3.0
            % For low airmass, use simple cos approximation: airmass ≈ 1/cos(Z)
            zenithAngle = rad2deg(acos(1/airmass));
            warning('Root finding failed, using simple approximation: Z = %.1f°', zenithAngle);
        else
            error('Failed to convert airmass %.2f to zenith angle: %s', airmass, ME.message);
        end
    end
end