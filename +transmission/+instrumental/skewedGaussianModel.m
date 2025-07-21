function Sg_model = skewedGaussianModel(Lam, Amplitude, Center, Sigma, Gamma)
    % Calculate skewed Gaussian model for quantum efficiency
    %
    % Parameters:
    %   Lam (double array): Wavelength array in nm
    %   Amplitude (double): Peak amplitude
    %   Center (double): Center wavelength in nm
    %   Sigma (double): Width parameter
    %   Gamma (double): Skewness parameter
    %
    % Returns:
    %   Sg_model (double array): Skewed Gaussian values
    
    arguments
        Lam (:,1) double
        Amplitude (1,1) double
        Center (1,1) double
        Sigma (1,1) double
        Gamma (1,1) double
    end
    
    % Normalized x values
    X = (Lam - Center) / Sigma;
    
    % Standard Gaussian component
    Gaussian = exp(-0.5 * X.^2);
    
    % Skewness component using error function
    Skew = 1 + erf(Gamma * X / sqrt(2));
    
    % Combined skewed Gaussian
    Sg_model = Amplitude * Gaussian .* Skew;
end