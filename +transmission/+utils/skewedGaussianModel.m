function Sg_model = skewedGaussianModel(Lam, Amplitude, Center, Sigma, Gamma)
    % Calculate skewed Gaussian model for quantum efficiency
    % Input  : - Lam (double array): Wavelength array in nm
    %          - Amplitude (double): Peak amplitude
    %          - Center (double): Center wavelength in nm
    %          - Sigma (double): Width parameter
    %          - Gamma (double): Skewness parameter
    % Output : - Sg_model (double array): Skewed Gaussian values
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - 
    %                best-fit CCD quantum efficiency parameters for
    %                default values;
    %             2. Garrappa et al. 2025, A&A 699, A50.
    % Example: % Basic usage with defaults (unit Gaussian at center=0)
    %          Sg = transmission.instrumental.skewedGaussianModel();
    %          % Custom skewed Gaussian (amplitude=100, center=600nm, width=50nm, skew=0.2)
    %          Sg = transmission.instrumental.skewedGaussianModel(Lam, 100, 600, 50, 0.2);
    arguments
        Lam = transmission.utils.makeWavelengthArray()
        Amplitude = 328.19
        Center = 570.97
        Sigma = 139.77
        Gamma = -0.1517
    end
    
    % Normalized X values
    X = (Lam - Center) / Sigma;
    
    % Standard Gaussian component
    Gaussian = exp(-0.5 * X.^2);
    
    % Skewness component using error function
    Skew = 1 + erf(Gamma * X / sqrt(2));
    
    % Combined skewed Gaussian
    Sg_model = Amplitude * Gaussian .* Skew;
end