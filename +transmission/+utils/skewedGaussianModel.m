function Sg_model = skewedGaussianModel(Lam, Config)
    % Calculate skewed Gaussian model for quantum efficiency
    % Input  : - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Utils.SkewedGaussianModel.Default_amplitude
    %            Uses Config.Utils.SkewedGaussianModel.Default_center
    %            Uses Config.Utils.SkewedGaussianModel.Default_sigma
    %            Uses Config.Utils.SkewedGaussianModel.Default_gamma
    % Output : - Sg_model (double array): Skewed Gaussian values
    % Author : D. Kovaleva (Jan 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - 
    %                best-fit CCD quantum efficiency parameters for
    %                default values;
    %             2. Garrappa et al. 2025, A&A 699, A50.
    % Example: % Basic usage with default config
    %          Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          Sg = transmission.utils.skewedGaussianModel(Lam, Config);
    %          % Custom parameters
    %          Config.Utils.SkewedGaussianModel.Default_amplitude = 100;
    %          Config.Utils.SkewedGaussianModel.Default_center = 600;
    %          Sg = transmission.utils.skewedGaussianModel(Lam, Config);
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config
    Amplitude = Config.Utils.SkewedGaussianModel.Default_amplitude;
    Center = Config.Utils.SkewedGaussianModel.Default_center;
    Sigma = Config.Utils.SkewedGaussianModel.Default_sigma;
    Gamma = Config.Utils.SkewedGaussianModel.Default_gamma;
    
    % Normalized X values
    X = (Lam - Center) / Sigma;
    
    % Standard Gaussian component
    Gaussian = exp(-0.5 * X.^2);
    
    % Skewness component using error function
    Skew = 1 + erf(Gamma * X / sqrt(2));
    
    % Combined skewed Gaussian with proper normalization (Formula 8, Garrappa et al. 2025)
    normalization = 1 / (Sigma * sqrt(2 * pi));
    Sg_model = Amplitude * normalization * Gaussian .* Skew;
end