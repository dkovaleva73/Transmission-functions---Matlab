function Transm = aerosolTransmission(Z_, Tau_aod500, Alpha, Lam, Args)
    % Approximate Aerosol transmission of the Earth atmosphere as a
    % function of zenith angle, aerosol optical depth, Angstrom's exponent 
    % and wavelength.
    % Input :   - Z_ (double): The zenith angle in degrees.
    %           - Tau_aod500 (double): The aerosol optical depth at 500nm.
    %           - Alpha (double): The Angstrom exponent.
    %           - Lam (double array): Wavelength array (by default, in nm).
    %           * ...,key,val,...
    %           'WaveUnits' -  'A','Ang'|'nm'
    % Output :  - Transm (double array): The calculated transmission values (0-1).
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author  :  D. Kovaleva (July 2025).
    % Example :  Lam = transmission.utils.make_wavelength_array();
    %            Trans = transmission.atmospheric.aerosolTransmission(45, 0.1, 1.3, Lam);    
    arguments
        Z_
        Tau_aod500 
        Alpha      
        Lam
        Args.WaveUnits  = 'nm';
    end  
    
    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Calculate airmass using SMARTS coefficients for aerosol, Gueymard, C. A. (2019) 
    Am_ = transmission.utils.airmassFromSMARTS(Z_, 'aerosol');

    % Convert wavelength to Angstrom
    %  LamAng = convert.energy(Args.WaveUnits,'Ang',Lam);

    % Calculate aerosol optical depth using AstroPack aerosolScattering
    Tau_lambda = astro.atmosphere.aerosolScattering(Lam, Tau_aod500, Alpha, Args.WaveUnits);

    % Calculate transmission and clip to [0,1]
    Transm = exp(-Am_ .* Tau_lambda);
    Transm = max(0, min(1, Transm));
end
