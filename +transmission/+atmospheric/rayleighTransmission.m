function Transm = rayleighTransmission(Z_, Pressure, Lam, Args)
    % Approximate Rayleigh transmission of the Earth atmosphere as a
    % function of zenith angle, atmospheric pressure and wavelength.
    % Input :  - Z_ (double): The zenith angle in degrees.
    %          - Pressure (double): The atmospheric pressure in mbar.
    %          - Lam (double array): Wavelength array.
    %          * ...,key,val,...
    %          'WaveUnits' -  'A','Ang'|'nm'
    % Output : - Transm (double array): The calculated transmission values (0-1).
    % Reference: Gueymard, C. A. (2019). Solar Energy, 187, 233-253.
    % Author:    D. Kovaleva (July 2025).
    % Example:   Lam = transmission.utils.make_wavelength_array();
    %            Trans = transmission.atmospheric.rayleighTransmission(30, 1013.25, Lam);   
    arguments
        Z_
        Pressure
        Lam
        Args.WaveUnits = 'nm';
    %   Args.P0        = 1013.25;  % standard pressure
    end

    % Checkup for zenith angle value correctness
    if Z_ > 90 || Z_ < 0
        error('Zenith angle out of range [0, 90] deg');
    end

    % Calculate airmass from SMARTS model by Gueymard, C. A. (2019) 
    Am_ = transmission.utils.airmassFromSMARTS(Z_, 'rayleigh');
    
    % Convert wavelength to Angstroms
    % LamAng = convert.energy('nm',Args.WaveUnits,Lam);
    
    % Calculate Rayleigh optical depth using AstroPack rayleighScattering
    Tau_rayleigh = astro.atmosphere.rayleighScattering(Lam, Pressure, Args.WaveUnits);
    
    % Calculate transmission and clip to [0,1]
    Transm = exp(-Am_ .* Tau_rayleigh);
    Transm = max(0, min(1, Transm));
end
