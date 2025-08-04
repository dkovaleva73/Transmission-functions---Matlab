function Ota_transmission = otaTransmission(Lam, Config)
    % Calculate complete OTA (Optical Telescope Assembly) transmission
    % Input :  - Lam (double array): Wavelength array in nm
    %          - Config (struct): Configuration struct from inputConfig()
    %            Uses Config.Instrumental.Components for all instrumental components
    %            Uses Config.Utils.ChebyshevModel for transmission corrections
    % Output:  - Ota_transmission (double array): Complete OTA transmission (0-1)
    % Author: D. Kovaleva (Jul 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50.
    % Example: Config = transmission.inputConfig('default');
    %          Lam = transmission.utils.makeWavelengthArray(Config);
    %          Ota = transmission.instrumental.otaTransmission(Lam, Config);
    %          % Enable Chebyshev corrections
    %          Config.Utils.ChebyshevModel.enable = true;
    %          Ota = transmission.instrumental.otaTransmission(Lam, Config);
    
    arguments
        Lam = transmission.utils.makeWavelengthArray(transmission.inputConfig())
        Config = transmission.inputConfig()
    end
    
    % Extract parameters from Config - parameters are handled within each component function
    
    % Calculate individual components using Config
    
    % 1. Quantum efficiency (using Skewed Gaussian + Legendre polynomials)
    Qe = transmission.instrumental.quantumEfficiency(Lam, Config);
    
    % 2. Mirror reflectance
    Ref_mirror = transmission.instrumental.mirrorReflectance(Lam, Config);
    
    % 3. Corrector transmission
    Trans_corrector = transmission.instrumental.correctorTransmission(Lam, Config);
    
    % 4. Calculate OTA transmission before Chebyshev correction
    OTA_transmission = Qe .* Ref_mirror .* Trans_corrector;
    
    % 5. Apply Chebyshev polynomial correction if enabled
    Cheb_params = Config.Utils.ChebyshevModel;
    if isfield(Cheb_params, 'enable') && Cheb_params.enable
        % Calculate Chebyshev polynomial term (transmission mode returns exp(expansion))
        pol_term = transmission.utils.chebyshevModel(Lam, Config);
        
        % Apply polynomial correction to OTA transmission
        Ota_transmission = OTA_transmission .* pol_term;
    else
        % No Chebyshev correction
        Ota_transmission = OTA_transmission;
    end
    
end