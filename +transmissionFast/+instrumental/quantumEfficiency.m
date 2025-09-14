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
    %           Config = transmissionFast.inputConfig('default');
    %           Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %           Qe = transmissionFast.instrumental.quantumEfficiency(Lam, Config);
    %           % Custom parameters
    %           Config.Utils.SkewedGaussianModel.Default_amplitude = 350;
    %           Config.Utils.LegendreModel.Default_coeffs = [-0.30, 0.34, -1.89];
    %           Qe = transmissionFast.instrumental.quantumEfficiency(Lam, Config);
    
    arguments
        Lam = []  % Will use cached wavelength array from Config if empty
        Config = transmissionFast.inputConfig()
    end
    
    % Use cached wavelength array if Lam not provided
    if isempty(Lam)
        if isfield(Config, 'WavelengthArray') && ~isempty(Config.WavelengthArray)
            Lam = Config.WavelengthArray;
        else
            % Fallback to calculation if cached array not available
            Lam = transmissionFast.utils.makeWavelengthArray(Config);
        end
    end
    
    % Parameters are extracted and validated within the utils functions
    
    % Calculate individual components using Config
    Sg_component = transmissionFast.utils.skewedGaussianModel(Lam, Config);
    Legendre_component = transmissionFast.utils.legendreModel(Lam, Config);

    % Combined quantum efficiency
    Qe = Sg_component .* Legendre_component;
    
end