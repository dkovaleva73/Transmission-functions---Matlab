function Ota_transmission = otaTransmission(Lam, Config)
    % Calculate complete OTA (Optical Telescope Assembly) transmission
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Instrumental.Components for all instrumental components
    %            Uses Config.Utils.ChebyshevModel for transmission corrections
    % Output:  - Ota_transmission (double array): Complete OTA transmission (0-1)
    % Author: D. Kovaleva (Jul 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50.
    % Example: Config = transmissionFast.inputConfig('default');
    %          Lam = transmissionFast.utils.makeWavelengthArray(Config);
    %          Ota = transmissionFast.instrumental.otaTransmission(Lam, Config);
    %          % Enable Chebyshev corrections
    %          Config.Utils.ChebyshevModel.enable = true;
    %          Ota = transmissionFast.instrumental.otaTransmission(Lam, Config);
    
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
    
    % Extract parameters from Config - parameters are handled within each component function
    
    % Calculate individual components using Config
    
    % 1. Quantum efficiency (using Skewed Gaussian + Legendre polynomials)
    Qe = transmissionFast.instrumental.quantumEfficiency(Lam, Config);
    
    % 2. Mirror reflectance
    Ref_mirror = transmissionFast.instrumental.mirrorReflectance(Lam, Config);
    
    % 3. Corrector transmission
    Trans_corrector = transmissionFast.instrumental.correctorTransmission(Lam, Config);
    
    % 4. Calculate OTA transmission before Chebyshev correction
    OTA_transmission = Qe .* Ref_mirror .* Trans_corrector;
    
    % 5. Apply Chebyshev polynomial correction if enabled
    Cheb_params = Config.Utils.ChebyshevModel;
    if isfield(Cheb_params, 'enable') && Cheb_params.enable
        % Calculate Chebyshev polynomial term (transmission mode returns exp(expansion))
        pol_term = transmissionFast.utils.chebyshevModel(Lam, Config);
        
        % Apply polynomial correction to OTA transmission
        Ota_transmission = OTA_transmission .* pol_term;
    else
        % No Chebyshev correction
        Ota_transmission = OTA_transmission;
    end
    
end