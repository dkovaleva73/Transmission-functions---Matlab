function CatalogAB = calculateAbsolutePhotometry(OptimizedParams, Config, Args)
    % Calculate absolute photometry (AB magnitudes) for all stars in LAST catalog
    % Uses optimized transmission parameters to calculate zero-point and AB magnitudes
    % Input:  - OptimizedParams - Structure with optimized parameters from TransmissionOptimizer
    %         - Config - Transmission configuration (default: inputConfig())
    %         - Args - Optional arguments:
    %           'AstroImageFile' - Path to LAST AstroImage file (default: from Config)
    %           'ImageNum' - Image number in AstroImage (default: 1)
    %           'Verbose' - Enable verbose output (default: true)
    %           'SaveResults' - Save results to file (default: false)
    % Output: - CatalogAB - MATLAB table containing:
    %           - All original LAST catalog columns
    %           - 'MAG_ZP' - Zero-point magnitude for each star (position-dependent)
    %           - 'MAG_PSF_AB' - AB absolute magnitude for each star
    %           - 'FIELD_CORRECTION_MAG' - Field correction applied
    % Author: D. Kovaleva (Aug 2025)
    % Example:
    %   Config = transmissionFast.inputConfig();
    %   optimizer = transmissionFast.TransmissionOptimizer(Config);
    %   finalParams = optimizer.runFullSequence();
    %   CatalogAB = transmissionFast.calculateAbsolutePhotometry(finalParams, Config);
    
    arguments
        OptimizedParams struct
        Config = transmissionFast.inputConfig()
        Args.AstroImageFile = []
        Args.ImageNum = 1
        Args.Verbose logical = true
        Args.SaveResults logical = false
    end

    Dt = 20;
    H = constant.h('SI');
    
    % Get AstroImage file
    if isempty(Args.AstroImageFile)
        AstroImageFile = Config.Data.LAST_AstroImage_file;
    else
        AstroImageFile = Args.AstroImageFile;
    end

    AstroCatFile = Config.Data.LAST_catalog_file;
      
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

    %Load AstroCatalog
%       AC = AstroCatalog(AstroCatFile);
       

    % Get the catalog for specified image
    AC = AI(Args.ImageNum).CatData;
    
    % Extract LAST catalog data as a MATLAB table
    % Check what format the data is in
    if isprop(AC, 'Table')
        LASTData = AC.Table;
    elseif isprop(AC, 'Data')
        LASTData = AC.Data;
    elseif isprop(AC, 'Catalog')
        LASTData = AC.Catalog;
    else
        % Try to convert to table if it's a different format
        try
            LASTData = table(AC);
        catch
            error('Unable to extract catalog data from AstroCatalog object');
        end
    end
    
    % Ensure LASTData is a MATLAB table
    if ~istable(LASTData)
        % Try to convert to table
        if isstruct(LASTData)
            LASTData = struct2table(LASTData);
        elseif isa(LASTData, 'AstroCatalog')
            % Extract data from AstroCatalog object
            try
                LASTData = LASTData.getCatalog();
            catch
                error('Cannot convert AstroCatalog to table format');
            end
        else
            error('LASTData must be a MATLAB table');
        end
    end
    
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
    % Get absorption data from Config (already cached in memory)
    AbsorptionData = Config.AbsorptionData;
    
    % Calculate zero-point flux for AB system
    if Args.Verbose
        fprintf('Calculating zero-point flux...\n');
    end
    
    % Create flat Fnu spectrum for zero-point calculation
    Fnu = constant.Fnu('SI');  % AB system flux density
    Wavelength = transmissionFast.utils.makeWavelengthArray(ConfigOptimized);
    FlatSpectrum = Fnu * ones(size(Wavelength));  % Flat spectrum in SI units
 %   FlatSpectrum = Fnu ./ Wavelength(:).^2;  % Flat spectrum in SI units
    % Calculate transmission function
    TransFunc = transmissionFast.totalTransmission(Wavelength, ConfigOptimized, 'AbsorptionData', AbsorptionData);
     
    % Apply transmission to flat spectrum
    SpecTrans_ZP = FlatSpectrum(:) .* TransFunc(:);
  
    % Calculate total flux for zero-point directly
    % For zero-point: B = H, Dt = 1
    
    Integrand = SpecTrans_ZP(:) ./ Wavelength(:);
   
    % Use AstroPack trapzmat for integration
    A = tools.math.integral.trapzmat(Wavelength(:), Integrand(:), 1);
    B = H;  
    % Calculate zero-point flux 
    % For zero-point: dt=1, but we DO need Ageom for the telescope collecting area
    Ageom = Config.Instrumental.Telescope.Aperture_area_m2;  % LAST telescope aperture area from Config
    TotalFlux_ZP_base = ConfigOptimized.General.Norm_ * Ageom * A / B;
    
    % Convert flux to zero-point magnitude: ZP = -2.5*log10(flux_ZP)
    ZP_magnitude = 2.5 * log10(TotalFlux_ZP_base);
    
    if Args.Verbose
        fprintf('Base zero-point flux (no field corrections): %.4e SI\n', TotalFlux_ZP_base);
        fprintf('Base zero-point magnitude (no field corrections): %.4f mag\n', ZP_magnitude);
    end
    
    % Setup basic Chebyshev model if we have field corrections
    hasFieldCorrections = false;
    hasPythonFieldCorrections = false;
    
    % Check for basic Chebyshev field corrections (cx0, cy0, etc.)
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
    
    % Check for Python-like Chebyshev field corrections (kx0, kx, ky, etc.)
    pythonFieldParams = {'kx0', 'kx', 'ky', 'kx2', 'ky2', 'kx3', 'ky3', 'kx4', 'ky4', 'kxy'};
    for i = 1:length(pythonFieldParams)
        if isfield(OptimizedParams, pythonFieldParams{i})
            hasPythonFieldCorrections = true;
            hasFieldCorrections = true;  % Enable general field corrections
            break;
        end
    end
    
    if hasPythonFieldCorrections && Args.Verbose
        fprintf('Python-like Chebyshev field corrections detected from OptimizedParams\n');
    end
    
    % Initialize arrays for results
    Nstars = height(LASTData);
    MAG_ZP = zeros(Nstars, 1);
    MAG_PSF_AB = zeros(Nstars, 1);
    FIELD_CORRECTION_MAG = zeros(Nstars, 1);  % Store field correction separately
    
    if Args.Verbose
        fprintf('\nCalculating AB magnitudes for %d stars...\n', Nstars);
    end
    
    % Process each star
    for i = 1:Nstars
        if mod(i, 100) == 1 && Args.Verbose
            fprintf('  Processing star %d/%d\n', i, Nstars);
        end
        
        % Calculate field correction for this star's position (in magnitude space)
        FieldCorrection_mag = 0.0;  % Default: no correction (magnitude space)
        
        if hasFieldCorrections
            % Normalize coordinates to [-1, 1] for Chebyshev using detector dimensions from Config
            X = LASTData.X(i);
            Y = LASTData.Y(i);
           
            % Use detector dimensions from Config and rescaleInputData
            min_coord = Config.Instrumental.Detector.Min_coordinate;
            max_coord = Config.Instrumental.Detector.Max_coordinate;
            
            X_norm = transmissionFast.utils.rescaleInputData(X, min_coord, max_coord, [], [], Config);
            Y_norm = transmissionFast.utils.rescaleInputData(Y, min_coord, max_coord, [], [], Config);
            
            % Check for Python-like Chebyshev field correction model
            if hasPythonFieldCorrections || ...
               (isfield(ConfigOptimized, 'FieldCorrection') && ...
                isfield(ConfigOptimized.FieldCorrection, 'Mode') && ...
                strcmp(ConfigOptimized.FieldCorrection.Mode, 'python'))
                % Python-like Chebyshev field model: Cheb_x(xcoor_) + Cheb_y(ycoor_) + kx0 + Cheb_xy_x(xcoor_)*Cheb_xy_y(ycoor_)
                % Use OptimizedParams if available, otherwise use ConfigOptimized
                if hasPythonFieldCorrections
                    PythonParams = OptimizedParams;
                else
                    PythonParams = ConfigOptimized.FieldCorrection.Python;
                end
                
                % X Chebyshev (order 4): coeffs = [0, kx, kx2, kx3, kx4]
                kx_coeffs = [0, getFieldValue(PythonParams, 'kx', 0), getFieldValue(PythonParams, 'kx2', 0), ...
                           getFieldValue(PythonParams, 'kx3', 0), getFieldValue(PythonParams, 'kx4', 0)];
                % Calculate Chebyshev expansion using individual polynomials
                Cheb_x_val = 0;
                for i = 1:length(kx_coeffs)
                    if kx_coeffs(i) ~= 0
                        Cheb_x_val = Cheb_x_val + kx_coeffs(i) * transmissionFast.utils.evaluateChebyshevPolynomial(X_norm, i-1);
                    end
                end
             %   Cheb_x_val = evaluateChebyshevDirect(X_norm, [0, -0.0024413998425085737, -0.0007724793006609332, -0.001278415563733759, 0.0015160592703367115]);
                
                % Y Chebyshev (order 4): coeffs = [0, ky, ky2, ky3, ky4]  
                ky_coeffs = [0, getFieldValue(PythonParams, 'ky', 0), getFieldValue(PythonParams, 'ky2', 0), ...
                           getFieldValue(PythonParams, 'ky3', 0), getFieldValue(PythonParams, 'ky4', 0)];
                % Calculate Chebyshev expansion using individual polynomials
                Cheb_y_val = 0;
                for i = 1:length(ky_coeffs)
                    if ky_coeffs(i) ~= 0
                        Cheb_y_val = Cheb_y_val + ky_coeffs(i) * transmissionFast.utils.evaluateChebyshevPolynomial(Y_norm, i-1);
                    end
                end
             %   Cheb_y_val = evaluateChebyshevDirect(Y_norm, [0, -0.0014053779943274947, 0.0011508991911419741, -0.00020214313691013786, -0.0011522339536700343]);
                
                % XY cross-term (order 1): Cheb_xy_x and Cheb_xy_y both use [0, kxy]
                kxy = getFieldValue(PythonParams, 'kxy', 0);
                % XY cross-term: [0, kxy] means 0*T_0 + kxy*T_1 = kxy*x
                Cheb_xy_x_val = kxy * transmissionFast.utils.evaluateChebyshevPolynomial(X_norm, 1);
                Cheb_xy_y_val = kxy * transmissionFast.utils.evaluateChebyshevPolynomial(Y_norm, 1);
          
                
                % Constant terms
                kx0 = getFieldValue(PythonParams, 'kx0', 0);
                % ky0 is fixed at 0 in Python, but include for completeness
                ky0 = getFieldValue(PythonParams, 'ky0', 0);
                
                % Python-like Chebyshev field correction formula (line 388)
                FieldCorrection_mag = Cheb_x_val + Cheb_y_val + kx0 + ky0 + Cheb_xy_x_val * Cheb_xy_y_val;
                
            else
                 FieldCorrection_mag = 0;   
             %   FieldCorrection_mag = evaluateChebyshevManual(X_norm, Y_norm, cx, cy);
            end
        end
        
        % Store field correction separately
        FIELD_CORRECTION_MAG(i) = FieldCorrection_mag;
        
        % Calculate position-dependent zero-point magnitude
        % Field correction is already in magnitude space, so just add it
        MAG_ZP(i) = ZP_magnitude + FieldCorrection_mag;
        
       
        if ismember('FLUX_PSF', LASTData.Properties.VariableNames)
            FLUX_PSF_value = LASTData.FLUX_PSF(i);

       % Calculate AB magnitude for this star using flux-based formula:
        % MAG_AB = -2.5*log10(FLUX_PSF_value/Dt) + MAG_ZP;
           if ~isnan(FLUX_PSF_value) && FLUX_PSF_value > 0
                % Get exposure time (Dt)
           %    if ~isnan(Metadata.ExpTime)
           %         Dt = Metadata.ExpTime;
           %         Dt = 20.0;
           %     else
           %         Dt = 20.0;  % Default exposure time
           %     end
                % Calculate AB magnitude from flux
                MAG_PSF_AB(i) = -2.5 * log10(FLUX_PSF_value / Dt) + MAG_ZP(i);
            else
                MAG_PSF_AB(i) = NaN;
            end
        elseif ismember('MAG_PSF', LASTData.Properties.VariableNames)
            % Fallback: use instrumental magnitude if flux not available
            MAG_PSF_value = LASTData.MAG_PSF(i);
            if ~isnan(MAG_PSF_value)
                MAG_PSF_AB(i) = MAG_PSF_value + MAG_ZP(i);
            else
                MAG_PSF_AB(i) = NaN;
            end
        else
            MAG_PSF_AB(i) = NaN;
        end
    end
    
    % Add new columns to the MATLAB table
    LASTData.MAG_ZP = MAG_ZP;
    LASTData.MAG_PSF_AB = MAG_PSF_AB;
    LASTData.FIELD_CORRECTION_MAG = FIELD_CORRECTION_MAG;
    
    % Return the enhanced MATLAB table as output
    CatalogAB = LASTData;
    
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
                          string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
        save(filename, 'CatalogAB', 'OptimizedParams', 'MAG_ZP', 'MAG_PSF_AB');
        if Args.Verbose
            fprintf('\nResults saved to: %s\n', filename);
        end
    end
end

%% Helper Functions

function ConfigOptimized = updateConfigWithOptimizedParams(Config, OptimizedParams)
    % Update Config structure with optimized parameters
    % Preserves existing Config.FieldCorrection if no field params in OptimizedParams
    
    ConfigOptimized = Config;
    
    % Ensure FieldCorrection structure exists and is properly initialized
    if ~isfield(ConfigOptimized, 'FieldCorrection')
        ConfigOptimized.FieldCorrection = struct('Enable', false, 'Mode', 'none');
    end
    if ~isfield(ConfigOptimized.FieldCorrection, 'Python')
        ConfigOptimized.FieldCorrection.Python = struct();
    end
    if ~isfield(ConfigOptimized.FieldCorrection, 'Simple')
        ConfigOptimized.FieldCorrection.Simple = struct();
    end
    
    % Track if we find field correction params
    hasPythonFieldParams = false;
    hasSimpleFieldParams = false;
    
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
            % Python-like Chebyshev field correction parameters
            case 'kx0'
                ConfigOptimized.FieldCorrection.Python.kx0 = paramValue;
                ConfigOptimized.FieldCorrection.Enable = true;
                ConfigOptimized.FieldCorrection.Mode = 'python';
                hasPythonFieldParams = true;
            case 'ky0'
                ConfigOptimized.FieldCorrection.Python.ky0 = paramValue;
                hasPythonFieldParams = true;
            case 'kx'
                ConfigOptimized.FieldCorrection.Python.kx = paramValue;
                hasPythonFieldParams = true;
            case 'ky'
                ConfigOptimized.FieldCorrection.Python.ky = paramValue;
                hasPythonFieldParams = true;
            case 'kx2'
                ConfigOptimized.FieldCorrection.Python.kx2 = paramValue;
                hasPythonFieldParams = true;
            case 'ky2'
                ConfigOptimized.FieldCorrection.Python.ky2 = paramValue;
                hasPythonFieldParams = true;
            case 'kx3'
                ConfigOptimized.FieldCorrection.Python.kx3 = paramValue;
                hasPythonFieldParams = true;
            case 'ky3'
                ConfigOptimized.FieldCorrection.Python.ky3 = paramValue;
                hasPythonFieldParams = true;
            case 'kx4'
                ConfigOptimized.FieldCorrection.Python.kx4 = paramValue;
                hasPythonFieldParams = true;
            case 'ky4'
                ConfigOptimized.FieldCorrection.Python.ky4 = paramValue;
                hasPythonFieldParams = true;
            case 'kxy'
                ConfigOptimized.FieldCorrection.Python.kxy = paramValue;
                hasPythonFieldParams = true;
            % Simple Chebyshev coefficients
            case 'cx0'
                ConfigOptimized.FieldCorrection.Simple.cx0 = paramValue;
                ConfigOptimized.FieldCorrection.Enable = true;
                ConfigOptimized.FieldCorrection.Mode = 'simple';
                hasSimpleFieldParams = true;
            case 'cx1'
                ConfigOptimized.FieldCorrection.Simple.cx1 = paramValue;
                hasSimpleFieldParams = true;
            case 'cx2'
                ConfigOptimized.FieldCorrection.Simple.cx2 = paramValue;
                hasSimpleFieldParams = true;
            case 'cx3'
                ConfigOptimized.FieldCorrection.Simple.cx3 = paramValue;
                hasSimpleFieldParams = true;
            case 'cx4'
                ConfigOptimized.FieldCorrection.Simple.cx4 = paramValue;
                hasSimpleFieldParams = true;
            case 'cy0'
                ConfigOptimized.FieldCorrection.Simple.cy0 = paramValue;
                hasSimpleFieldParams = true;
            case 'cy1'
                ConfigOptimized.FieldCorrection.Simple.cy1 = paramValue;
                hasSimpleFieldParams = true;
            case 'cy2'
                ConfigOptimized.FieldCorrection.Simple.cy2 = paramValue;
                hasSimpleFieldParams = true;
            case 'cy3'
                ConfigOptimized.FieldCorrection.Simple.cy3 = paramValue;
                hasSimpleFieldParams = true;
            case 'cy4'
                ConfigOptimized.FieldCorrection.Simple.cy4 = paramValue;
                hasSimpleFieldParams = true;
        end
    end
end


%function FieldCorrection = evaluateChebyshevManual(X_norm, Y_norm, cx, cy)
%    % Manually evaluate Chebyshev polynomials for field correction
    
%    % Chebyshev polynomials up to order 4
%    Tx = zeros(5, 1);
%    Tx(1) = 1;
%    Tx(2) = X_norm;
%    Tx(3) = 2*X_norm^2 - 1;
%    Tx(4) = 4*X_norm^3 - 3*X_norm;
%    Tx(5) = 8*X_norm^4 - 8*X_norm^2 + 1;
    
%    Ty = zeros(5, 1);
%    Ty(1) = 1;
%    Ty(2) = Y_norm;
%    Ty(3) = 2*Y_norm^2 - 1;
%    Ty(4) = 4*Y_norm^3 - 3*Y_norm;
%    Ty(5) = 8*Y_norm^4 - 8*Y_norm^2 + 1;
    
    % Combine corrections
%    CorrectionX = Tx' * cx;
%    CorrectionY = Ty' * cy;
    
    % Field correction in magnitude space (no exponential)
%    FieldCorrection = CorrectionX + CorrectionY;
%end


function value = getFieldValue(structure, fieldname, defaultValue)
    % Safe field extraction with default value
    if isfield(structure, fieldname)
        value = structure.(fieldname);
    else
        value = defaultValue;
    end
end