function Qe = quantumEfficiency(Lam, Amplitude, Center, Sigma, Gamma, L0, L1, L2, L3, L4, L5, L6, L7, L8)
    % Calculate quantum efficiency using SkewedGaussian × Legendre model
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   Amplitude (double): SkewedGaussian amplitude
    %   Center (double): SkewedGaussian center wavelength in nm
    %   Sigma (double): SkewedGaussian width parameter
    %   Gamma (double): SkewedGaussian skewness parameter
    %   L0-L8 (double): Legendre polynomial coefficients
    %
    % Returns:
    %   Qe (double array): Quantum efficiency values (0-1)
    
    arguments
        Lam (:,1) double
        Amplitude (1,1) double
        Center (1,1) double
        Sigma (1,1) double
        Gamma (1,1) double
        L0 (1,1) double
        L1 (1,1) double
        L2 (1,1) double
        L3 (1,1) double
        L4 (1,1) double
        L5 (1,1) double
        L6 (1,1) double
        L7 (1,1) double
        L8 (1,1) double
    end
    
    % Import models
    import transmission.instrumental.skewedGaussianModel
    import transmission.instrumental.legendreModel
    
    % Calculate wavelength range for Legendre normalization
    Min_wvl = min(Lam);
    Max_wvl = max(Lam);
    
    % Calculate individual components
    Sg_component = skewedGaussianModel(Lam, Amplitude, Center, Sigma, Gamma);
    Legendre_component = legendreModel(Lam, L0, L1, L2, L3, L4, L5, L6, L7, L8, Min_wvl, Max_wvl);
    
    % Combined quantum efficiency
    Qe = Sg_component .* Legendre_component;
    
    % Normalize to ensure values are between 0 and 1
    Qe = max(0, min(1, Qe));
end