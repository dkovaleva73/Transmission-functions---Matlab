function Qe = quantumEfficiency(Lam, Config)
    % Calculate quantum efficiency using SkewedGaussian × Legendre model
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Utils.SkewedGaussianModel parameters
    %            Uses Config.Utils.LegendreModel.Default_coeffs
    % Output : - Qe (double array): Quantum efficiency values 
    % Author : D. Kovaleva (Jul 2025)
    % References: 1. Ofek et al. 2023, PASP 135, Issue 1054, id.124502 - 
    %                best-fit CCD quantum efficiency parameters for
    %                default values;
    %             2. Garrappa et al. 2025, A&A 699, A50.
    % Example : % Basic usage with default Config
    %           Config = transmission.inputConfig('default');
    %           Lam = transmission.utils.makeWavelengthArray(Config);
    %           Qe = transmission.instrumental.quantumEfficiency(Lam, Config);
    %           % Custom parameters
    %           Config.Utils.SkewedGaussianModel.Default_amplitude = 350;
    %           Config.Utils.LegendreModel.Default_coeffs = [-0.30, 0.34, -1.89];
    %           Qe = transmission.instrumental.quantumEfficiency(Lam, Config);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Parameters are extracted and validated within the utils functions
    
    % Calculate individual components using Config
    Sg_component = transmission.utils.skewedGaussianModel(Lam, Config);
    Legendre_component = transmission.utils.legendreModel(Lam, Config);

    % Combined quantum efficiency
    Qe = Sg_component .* Legendre_component;
    
end