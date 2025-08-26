function AstroCatalogAB = calculateAbsolutePhotometry(OptimizedParams, Config, Args)
    % Calculate absolute photometry (AB magnitudes) for all stars in LAST catalog
    % Uses optimized transmission parameters to calculate zero-point and AB magnitudes
    % Input:  - OptimizedParams - Structure with optimized parameters from TransmissionOptimizer
    %         - Config - Transmission configuration (default: inputConfig())
    %         - Args - Optional arguments:
    %           'AstroImageFile' - Path to LAST AstroImage file (default: from Config)
    %           'ImageNum' - Image number in AstroImage (default: 1)
    %           'Verbose' - Enable verbose output (default: true)
    %           'SaveResults' - Save results to file (default: false)
    % Output: - AstroCatalogAB - Enhanced AstroCatalog with additional columns:
    %           'MAG_ZP' - Zero-point magnitude for each star (position-dependent)
    %           'MAG_PSF_AB' - AB absolute magnitude for each star
    % Author: D. Kovaleva (Aug 2025)
    % Example:
    %   Config = transmission.inputConfig();
    %   optimizer = transmission.TransmissionOptimizer(Config);
    %   finalParams = optimizer.runFullSequence();
    %   AstroCatalogAB = transmission.photometry.calculateAbsolutePhotometry(finalParams, Config);
    
    arguments
        OptimizedParams struct
        Config = transmission.inputConfig()
        Args.AstroImageFile = []
        Args.ImageNum = 1
        Args.Verbose logical = true
        Args.SaveResults logical = false
    end
    
    % Get AstroImage file
    if isempty(Args.AstroImageFile)
        AstroImageFile = Config.Data.LAST_AstroImage_file;
    else
        AstroImageFile = Args.AstroImageFile;
    end
    
    if Args.Verbose
        fprintf('=== ABSOLUTE PHOTOMETRY CALCULATION ===\n');
        fprintf('Using optimized transmission parameters\n');
        fprintf('AstroImage: %s\n', AstroImageFile);
        fprintf('Image number: %d\n\n', Args.ImageNum);
    end
    
    % Load AstroImage
    if isa(AstroImageFile, 'AstroImage')
        AI = AstroImageFile;
    else        
        AI = io.files.load2(AstroImageFile);
    end
    
    % Get the catalog for specified image
    AC = AI(Args.ImageNum).CatData;
    LASTData = AC.Table;
    
    % Extract metadata from header
    Header = AI(Args.ImageNum).HeaderData;
    Metadata = struct();
    
    try
        Metadata.ExpTime = Header.getVal('EXPTIME');
    catch
        Metadata.ExpTime = NaN;
    end
    
    try
        Metadata.JD = Header.getVal('JD');
    catch
        Metadata.JD = NaN;
    end
    
    try
        Metadata.airMassFromLAST = Header.getVal('AIRMASS');
    catch
        Metadata.airMassFromLAST = NaN;
    end
    
    try
        Metadata.Temperature = Header.getVal('MNTTEMP');
    catch
        Metadata.Temperature = NaN;
    end
    
    try
        Metadata.Pressure = Header.getVal('PRESSURE');
    catch
        try
            Metadata.Pressure = Header.getVal('PRESS');
        catch
            Metadata.Pressure = NaN;
        end
    end
    
    if Args.Verbose
        fprintf('Catalog contains %d stars\n', height(LASTData));
        fprintf('Metadata: AirMass=%.3f, Temp=%.1f°C, ExpTime=%.1fs\n\n', ...
                Metadata.airMassFromLAST, Metadata.Temperature, Metadata.ExpTime);
    end
    
    % Update Config with optimized parameters
    ConfigOptimized = updateConfigWithOptimizedParams(Config, OptimizedParams);
    
    % Set atmospheric parameters from metadata
    if ~isnan(Metadata.airMassFromLAST)
        ZenithAngle = acosd(1/Metadata.airMassFromLAST);
        ConfigOptimized.Atmospheric.Zenith_angle_deg = ZenithAngle;
    end
    
    if ~isnan(Metadata.Temperature)
        ConfigOptimized.Atmospheric.Temperature_C = Metadata.Temperature;
    end
    
    if ~isnan(Metadata.Pressure)
        ConfigOptimized.Atmospheric.Pressure = Metadata.Pressure;
    end
    
    % Preload absorption data
    if Args.Verbose
        fprintf('Loading absorption data...\n');
    end
    AllSpecies = {'H2O', 'O3UV', 'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', ...
                  'NH3', 'NO', 'NO2', 'SO2U', 'SO2I', 'HNO3', 'NO3', 'HNO2', ...
                  'CH2O', 'BrO', 'ClNO'};
    AbsorptionData = transmission.data.loadAbsorptionData([], AllSpecies, false);
    
    % Calculate zero-point flux for AB system
    if Args.Verbose
        fprintf('Calculating zero-point flux...\n');
    end
    
    % Create flat Fnu spectrum for zero-point calculation
    Fnu = constant.Fnu('SI');  % AB system flux density
    Wavelength = transmission.utils.makeWavelengthArray(ConfigOptimized);
    FlatSpectrum = Fnu * ones(size(Wavelength));  % Flat spectrum in SI units
    
    % Calculate transmission function
    TransFunc = transmission.totalTransmission(Wavelength, ConfigOptimized, 'AbsorptionData', AbsorptionData);
    
    % Apply transmission to flat spectrum
    SpecTrans_ZP = FlatSpectrum(:) .* TransFunc(:);
    
    % Calculate total flux for zero-point directly
    % For zero-point: B = H (no photon conversion), Dt = 1, Ageom = 1
    H = constant.h('SI');
    
    % Calculate the integrand: transmitted_flux * wavelength
    Integrand = SpecTrans_ZP(:) .* Wavelength(:);
    
    % Integrate using trapezoidal rule
    A = trapz(Wavelength(:), Integrand);
    
    % For zero-point calculation: B = H (corrected version)
    B = H;  % No conversion factor as per your correction
    
    % Calculate total flux (SI units)
    TotalFlux_ZP_base = ConfigOptimized.General.Norm_ * A / B;
    
    if Args.Verbose
        fprintf('Base zero-point flux (no field corrections): %.4e SI\n', TotalFlux_ZP_base);
    end
    
    % Setup Chebyshev model if we have field corrections
    hasFieldCorrections = false;
    if isfield(OptimizedParams, 'cx0') || isfield(OptimizedParams, 'cy0')
        hasFieldCorrections = true;
        % Extract Chebyshev coefficients
        cx = zeros(5, 1);
        cy = zeros(5, 1);
        
        if isfield(OptimizedParams, 'cx0'), cx(1) = OptimizedParams.cx0; end
        if isfield(OptimizedParams, 'cx1'), cx(2) = OptimizedParams.cx1; end
        if isfield(OptimizedParams, 'cx2'), cx(3) = OptimizedParams.cx2; end
        if isfield(OptimizedParams, 'cx3'), cx(4) = OptimizedParams.cx3; end
        if isfield(OptimizedParams, 'cx4'), cx(5) = OptimizedParams.cx4; end
        
        if isfield(OptimizedParams, 'cy0'), cy(1) = OptimizedParams.cy0; end
        if isfield(OptimizedParams, 'cy1'), cy(2) = OptimizedParams.cy1; end
        if isfield(OptimizedParams, 'cy2'), cy(3) = OptimizedParams.cy2; end
        if isfield(OptimizedParams, 'cy3'), cy(4) = OptimizedParams.cy3; end
        if isfield(OptimizedParams, 'cy4'), cy(5) = OptimizedParams.cy4; end
        
        if Args.Verbose
            fprintf('Field corrections enabled with Chebyshev coefficients\n');
        end
    end
    
    % Initialize arrays for results
    Nstars = height(LASTData);
    MAG_ZP = zeros(Nstars, 1);
    MAG_PSF_AB = zeros(Nstars, 1);
    
    if Args.Verbose
        fprintf('\nCalculating AB magnitudes for %d stars...\n', Nstars);
    end
    
    % Process each star
    for i = 1:Nstars
        if mod(i, 100) == 1 && Args.Verbose
            fprintf('  Processing star %d/%d\n', i, Nstars);
        end
        
        % Calculate field correction for this star's position
        FieldCorrection = 1.0;  % Default: no correction
        
        if hasFieldCorrections
            % Normalize coordinates to [-1, 1] for Chebyshev
            X = LASTData.X(i);
            Y = LASTData.Y(i);
            
            % Assuming detector coordinates go from 1 to ~4000
            % You may need to adjust these based on your detector size
            X_norm = 2 * (X - 2000) / 4000;  % Normalize to [-1, 1]
            Y_norm = 2 * (Y - 2000) / 4000;
            
            % Evaluate Chebyshev polynomials
            if exist('utils.chebyshevModel', 'class') || exist('+utils/chebyshevModel.m', 'file')
                chebModel = utils.chebyshevModel('CoefficientsX', cx, 'CoefficientsY', cy);
                FieldCorrection = chebModel.evaluate(X_norm, Y_norm);
            else
                % Fallback: evaluate Chebyshev manually
                FieldCorrection = evaluateChebyshevManual(X_norm, Y_norm, cx, cy);
            end
        end
        
        % Calculate position-dependent zero-point flux
        TotalFlux_ZP = TotalFlux_ZP_base * FieldCorrection;
        
        % Calculate zero-point magnitude
        MAG_ZP(i) = -2.5 * log10(TotalFlux_ZP);
        
        % Calculate AB magnitude for this star
        % MAG_PSF is instrumental magnitude, convert to flux
        if ismember('MAG_PSF', LASTData.Properties.VariableNames)
            MAG_PSF_value = LASTData.MAG_PSF(i);
            if ~isnan(MAG_PSF_value)
                % Convert instrumental magnitude to flux
                Flux_PSF = 10^(-0.4 * MAG_PSF_value);
                
                % Calculate flux in SI units (flux - zero point)
                Flux_SI = Flux_PSF - TotalFlux_ZP;
                
                % Convert to AB magnitude
                if Flux_SI > 0
                    MAG_PSF_AB(i) = -2.5 * log10(Flux_SI);
                else
                    MAG_PSF_AB(i) = NaN;  % Negative flux
                end
            else
                MAG_PSF_AB(i) = NaN;
            end
        else
            MAG_PSF_AB(i) = NaN;
        end
    end
    
    % Add new columns to the catalog
    LASTData.MAG_ZP = MAG_ZP;
    LASTData.MAG_PSF_AB = MAG_PSF_AB;
    
    % Create output AstroCatalog
    AstroCatalogAB = AC;
    AstroCatalogAB.Table = LASTData;
    
    if Args.Verbose
        fprintf('\n=== PHOTOMETRY CALCULATION COMPLETE ===\n');
        validMags = ~isnan(MAG_PSF_AB);
        fprintf('Valid AB magnitudes calculated: %d/%d\n', sum(validMags), Nstars);
        if sum(validMags) > 0
            fprintf('AB magnitude range: %.2f to %.2f\n', ...
                    min(MAG_PSF_AB(validMags)), max(MAG_PSF_AB(validMags)));
            fprintf('Mean zero-point magnitude: %.3f\n', mean(MAG_ZP));
        end
    end
    
    % Save results if requested
    if Args.SaveResults
        filename = sprintf('AbsolutePhotometry_%s.mat', ...
                          datestr(datetime('now'), 'yyyymmdd_HHMMSS'));
        save(filename, 'AstroCatalogAB', 'OptimizedParams', 'MAG_ZP', 'MAG_PSF_AB');
        if Args.Verbose
            fprintf('\nResults saved to: %s\n', filename);
        end
    end
end

%% Helper Functions

function ConfigOptimized = updateConfigWithOptimizedParams(Config, OptimizedParams)
    % Update Config structure with optimized parameters
    
    ConfigOptimized = Config;
    
    % Map optimized parameters to Config structure
    paramNames = fieldnames(OptimizedParams);
    for i = 1:length(paramNames)
        paramName = paramNames{i};
        paramValue = OptimizedParams.(paramName);
        
        % Map parameter to Config path
        switch paramName
            case 'Norm_'
                ConfigOptimized.General.Norm_ = paramValue;
            case 'Tau_aod500'
                ConfigOptimized.Atmospheric.Components.Aerosol.Tau_aod500 = paramValue;
            case 'Alpha'
                ConfigOptimized.Atmospheric.Components.Aerosol.Angstrom_exponent = paramValue;
            case 'Pwv_cm'
                ConfigOptimized.Atmospheric.Components.Water.Pwv_cm = paramValue;
            case 'Dobson_units'
                ConfigOptimized.Atmospheric.Components.Ozone.Dobson_units = paramValue;
            case 'Temperature_C'
                ConfigOptimized.Atmospheric.Temperature_C = paramValue;
            case 'Pressure'
                ConfigOptimized.Atmospheric.Pressure = paramValue;
            case 'Center'
                ConfigOptimized.Utils.SkewedGaussianModel.Default_center = paramValue;
            case 'Amplitude'
                ConfigOptimized.Utils.SkewedGaussianModel.Default_amplitude = paramValue;
            case 'Sigma'
                ConfigOptimized.Utils.SkewedGaussianModel.Default_sigma = paramValue;
            case 'Gamma'
                ConfigOptimized.Utils.SkewedGaussianModel.Default_gamma = paramValue;
            % Chebyshev coefficients are handled separately
        end
    end
end


function FieldCorrection = evaluateChebyshevManual(X_norm, Y_norm, cx, cy)
    % Manually evaluate Chebyshev polynomials for field correction
    
    % Chebyshev polynomials up to order 4
    Tx = zeros(5, 1);
    Tx(1) = 1;
    Tx(2) = X_norm;
    Tx(3) = 2*X_norm^2 - 1;
    Tx(4) = 4*X_norm^3 - 3*X_norm;
    Tx(5) = 8*X_norm^4 - 8*X_norm^2 + 1;
    
    Ty = zeros(5, 1);
    Ty(1) = 1;
    Ty(2) = Y_norm;
    Ty(3) = 2*Y_norm^2 - 1;
    Ty(4) = 4*Y_norm^3 - 3*Y_norm;
    Ty(5) = 8*Y_norm^4 - 8*Y_norm^2 + 1;
    
    % Combine corrections
    CorrectionX = Tx' * cx;
    CorrectionY = Ty' * cy;
    
    % Field correction as exponential (ensures positive)
    FieldCorrection = exp(CorrectionX + CorrectionY);
end