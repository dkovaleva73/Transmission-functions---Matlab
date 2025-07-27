function Qe = quantumEfficiency(Lam, Amplitude, Center, Sigma, Gamma, Degr, Li, Min_wvl, Max_wvl)
    % Calculate quantum efficiency using SkewedGaussian × Legendre model
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Amplitude (double): Peak amplitude
    %          - Center (double): Center wavelength in nm
    %          - Sigma (double): Width parameter
    %          - Gamma (double): Skewness parameter
    %          - Degr (integer): degree of Legendre polynom used to
    %            represent QE disturbance
    %          - Li (double): vector of Legendre polynomial coefficients
    %          - Min_wvl (double): Minimum wavelength for normalization
    %          - Max_wvl (double): Maximum wavelength for normalization
    % Output : - Qe (double array): Quantum efficiency values 
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - 
    %                best-fit CCD quantum efficiency parameters for
    %                default values;
    %             2. Garrappa et al. 2025, A&A 699, A50.
    % Example : % Basic usage with default Ofek+23 parameters
    %           Qe = transmission.instrumental.quantumEfficiency();
    %           % Custom wavelength array
    %           Lam = linspace(350, 950, 301)';
    %           Qe = transmission.instrumental.quantumEfficiency(Lam);
    %           % Modified Legendre degree (e.g., 4th order only)
    %           Qe = transmission.instrumental.quantumEfficiency(Lam, 328.19, 570.97, 139.77, -0.1517, 4, [-0.30 0.34 -1.89 -0.82 -3.73]);
    %           % Different CCD parameters
    %           Qe = transmission.instrumental.quantumEfficiency(Lam, 350, 600, 150, -0.2);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray()
        Amplitude = 328.19
        Center = 570.97
        Sigma = 139.77
        Gamma = -0.1517
        Degr = 8
        Li = [-0.30 0.34 -1.89 -0.82 -3.73 -0.669 -2.06 -0.24 -0.60]
        Min_wvl = min(Lam)
        Max_wvl = max(Lam)
    end
    
    % Validate wavelength bounds
    if Min_wvl >= Max_wvl
        error('transmission:quantumEfficiency:invalidBounds', ...
              'Min_wvl must be less than Max_wvl');
    end
    if Min_wvl < min(Lam) || Max_wvl > max(Lam)
        error('transmission:quantumEfficiency:boundsOutOfRange', ...
              'Normalization bounds [%.1f, %.1f] exceed wavelength array range [%.1f, %.1f]', ...
              Min_wvl, Max_wvl, min(Lam), max(Lam));
    end
    
    % Calculate individual components
    Sg_component = transmission.utils.skewedGaussianModel(Lam, Amplitude, Center, Sigma, Gamma);
    Legendre_component = transmission.utils.legendreModel(Lam, Degr, Li, Min_wvl, Max_wvl);
    % Sg_component = transmission.utils.skewedGaussianModel();
    % Legendre_component = transmission.utils.legendreModel();

    % Combined quantum efficiency
    Qe = Sg_component .* Legendre_component;
    
end