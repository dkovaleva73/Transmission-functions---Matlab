function [Cost, Residuals, DiffMag] = calculateCostFunction(CalibData, Config, Args)
    % Calculate cost function for transmission parameter optimization
    % This is a standalone version of the cost function used in minimizerFminGeneric
    %
    % Input:  - CalibData - Structure with calibrator data:
    %           .Spec - Gaia spectra
    %           .Mag - Magnitudes
    %           .Coords - Coordinates
    %           .LASTData - LAST catalog data  
    %           .Metadata - Observation metadata
    %         - Config - Configuration structure from transmission.inputConfig()
    %         - Args - Optional arguments:
    %           'UsePythonFieldModel' - Use Python-like Chebyshev field correction model (default: false)
    %           'UseChebyshev' - Use basic Chebyshev field model (default: false) 
    %           'ChebyshevOrder' - Order for Chebyshev polynomials (default: 4)
    %
    % Output: - Cost - Sum of squared magnitude differences
    %         - Residuals - Individual magnitude differences (DiffMag)
    %         - DiffMag - Magnitude differences: 2.5*log10(TotalFlux/FLUX_APER_3)
    %
    % Author: D. Kovaleva (Aug 2025)
    % Example:
    %   Config = transmission.inputConfig();
    %   [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords();
    %   CalibData = struct('Spec', Spec, 'Mag', Mag, 'Coords', Coords, 'LASTData', LASTData, 'Metadata', Metadata);
    %   [Cost, Residuals, DiffMag] = transmission.calculateCostFunction(CalibData, Config);
    
    arguments
        CalibData struct
        Config = transmission.inputConfig()
        Args.UsePythonFieldModel logical = false
        Args.UseChebyshev logical = false
        Args.ChebyshevOrder double = 4
    end
    
    % Get absorption data from Config (loaded during inputConfig)
    if isfield(Config, 'AbsorptionData')
        AbsorptionData = Config.AbsorptionData;
    else
        error('AbsorptionData not found in Config. Ensure transmission.inputConfig() was called properly.');
    end
    
    % Setup field correction model if requested
    if Args.UsePythonFieldModel
        % Python-like Chebyshev field model will use Config.FieldCorrection parameters
        ChebyshevModel = [];
        UsePythonModel = true;
    elseif Args.UseChebyshev
        % Setup basic Chebyshev model
        ChebyshevModel = setupChebyshevModel(CalibData, Args.ChebyshevOrder, Config);
        UsePythonModel = false;
    else
        ChebyshevModel = [];
        UsePythonModel = false;
    end
    
    % Apply transmission to calibrators
    [SpecTrans, Wavelength, ~] = transmission.calibrators.applyTransmissionToCalibrators(...
        CalibData.Spec, CalibData.Metadata, Config, 'AbsorptionData', AbsorptionData);
    
    % Convert to flux array
    if iscell(SpecTrans)
        TransmittedFluxArray = cell2mat(cellfun(@(x) x(:)', SpecTrans(:,1), 'UniformOutput', false));
    else
        TransmittedFluxArray = SpecTrans;
    end
    
    % Calculate total flux - use correct named parameter syntax
    TotalFlux = transmission.calibrators.calculateTotalFluxCalibrators(...
        Wavelength, TransmittedFluxArray, CalibData.Metadata, ...
        'Norm_', Config.General.Norm_);
    
    % Apply field corrections if provided
    if UsePythonModel
        % Apply Python-like Chebyshev field correction model using fieldCorrection
        FieldCorrectionMag = transmission.instrumental.fieldCorrection(...
            CalibData.LASTData.X, CalibData.LASTData.Y, Config);
        % Field correction is already in magnitude units, add directly to DiffMag
    elseif ~isempty(ChebyshevModel)
        % Apply basic Chebyshev model
        FieldCorrection = evaluateChebyshev(ChebyshevModel, CalibData.LASTData, Config);
        TotalFlux = TotalFlux .* FieldCorrection;
        FieldCorrectionMag = zeros(size(TotalFlux)); % No magnitude correction for simple model
    else
        FieldCorrectionMag = zeros(size(TotalFlux)); % No field correction
    end
    
    % Calculate magnitude differences
    DiffMag = 2.5 * log10(TotalFlux ./ CalibData.LASTData.FLUX_APER_3);
    
    % Add field correction if using Python model (magnitude units)
    if UsePythonModel
        DiffMag = DiffMag + FieldCorrectionMag;
    end
    
    % Calculate residuals and cost
    Residuals = DiffMag;
    Cost = sum(DiffMag.^2);
end

function ChebyshevModel = setupChebyshevModel(CalibData, order, Config)
    % Setup Chebyshev polynomial model for field corrections
    
    ChebyshevModel = struct();
    ChebyshevModel.Order = order;
    ChebyshevModel.XCoords = CalibData.LASTData.X;
    ChebyshevModel.YCoords = CalibData.LASTData.Y;
    
    % Normalize coordinates to [-1, 1] using rescaleInputData
    min_coor = Config.Instrumental.Detector.Min_coordinate;
    max_coor = Config.Instrumental.Detector.Max_coordinate;
    
    ChebyshevModel.XNorm = transmission.utils.rescaleInputData(ChebyshevModel.XCoords, min_coor, max_coor, [], [], Config);
    ChebyshevModel.YNorm = transmission.utils.rescaleInputData(ChebyshevModel.YCoords, min_coor, max_coor, [], [], Config);
end

function FieldCorrection = evaluateChebyshev(ChebyshevModel, LASTData, Config)
    % Evaluate Chebyshev field corrections using utils/chebyshevModel
    
    % Extract Chebyshev coefficients from Config if they exist
    if isfield(Config, 'FieldCorrection') && isfield(Config.FieldCorrection, 'Chebyshev')
        % Get coefficients for X
        cx = zeros(5, 1);
        if isfield(Config.FieldCorrection.Chebyshev, 'X')
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c0'), cx(1) = Config.FieldCorrection.Chebyshev.X.c0; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c1'), cx(2) = Config.FieldCorrection.Chebyshev.X.c1; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c2'), cx(3) = Config.FieldCorrection.Chebyshev.X.c2; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c3'), cx(4) = Config.FieldCorrection.Chebyshev.X.c3; end
            if isfield(Config.FieldCorrection.Chebyshev.X, 'c4'), cx(5) = Config.FieldCorrection.Chebyshev.X.c4; end
        end
        
        % Get coefficients for Y
        cy = zeros(5, 1);
        if isfield(Config.FieldCorrection.Chebyshev, 'Y')
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c0'), cy(1) = Config.FieldCorrection.Chebyshev.Y.c0; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c1'), cy(2) = Config.FieldCorrection.Chebyshev.Y.c1; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c2'), cy(3) = Config.FieldCorrection.Chebyshev.Y.c2; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c3'), cy(4) = Config.FieldCorrection.Chebyshev.Y.c3; end
            if isfield(Config.FieldCorrection.Chebyshev.Y, 'c4'), cy(5) = Config.FieldCorrection.Chebyshev.Y.c4; end
        end
        
        % Call utils/chebyshevModel to evaluate
        if exist('transmission.utils.chebyshevModel', 'file')
            % Prepare Config for chebyshevModel
            ConfigCheb = Config;
            ConfigCheb.Utils.ChebyshevModel.Default_mode = 'tr'; % transmission mode
            
            % Evaluate X Chebyshev
            ConfigCheb.Utils.ChebyshevModel.Default_coeffs = cx;
            CorrectionX = transmission.utils.chebyshevModel(ChebyshevModel.XNorm, ConfigCheb);
            
            % Evaluate Y Chebyshev  
            ConfigCheb.Utils.ChebyshevModel.Default_coeffs = cy;
            CorrectionY = transmission.utils.chebyshevModel(ChebyshevModel.YNorm, ConfigCheb);
            
            % Combine corrections multiplicatively
            FieldCorrection = CorrectionX .* CorrectionY;
        else
            % Fallback: Evaluate Chebyshev polynomials directly
            % T0 = 1, T1 = x, T2 = 2x^2 - 1, T3 = 4x^3 - 3x, T4 = 8x^4 - 8x^2 + 1
            X = ChebyshevModel.XNorm;
            Y = ChebyshevModel.YNorm;
            
            % Chebyshev polynomials for X using utility function
            Tx = zeros(length(X), 5);
            for i = 0:4
                Tx(:, i+1) = transmission.utils.evaluateChebyshevPolynomial(X, i);
            end
            
            % Chebyshev polynomials for Y using utility function
            Ty = zeros(length(Y), 5);
            for i = 0:4
                Ty(:, i+1) = transmission.utils.evaluateChebyshevPolynomial(Y, i);
            end
            
            % Combine corrections: multiplicative model
            CorrectionX = Tx * cx;
            CorrectionY = Ty * cy;
            
            % Field correction as exponential of polynomial sum (ensures positive)
            FieldCorrection = exp(CorrectionX + CorrectionY);
        end
    else
        % No field correction coefficients defined
        FieldCorrection = ones(height(LASTData), 1);
    end
end

function AbsorptionData = getCachedAbsorptionData()
    % Get cached absorption data using persistent variable
    % This function loads absorption data once and keeps it in memory
    
    persistent cachedData
    persistent loadTime
    
    % Check if data needs to be loaded
    if isempty(cachedData)
        % Load all molecular species for comprehensive atmospheric modeling
        AllSpecies = {'H2O', 'O3UV', 'O2', 'CH4', 'CO', 'N2O', 'CO2', 'N2', 'O4', ...
                      'NH3', 'NO', 'NO2', 'SO2U', 'SO2I', 'HNO3', 'NO3', 'HNO2', ...
                      'CH2O', 'BrO', 'ClNO'};
        
        % Load data silently (verbose=false)
        cachedData = transmission.data.loadAbsorptionData([], AllSpecies, false);
        loadTime = datetime('now');
        
        % Display loading message (only once)
        fprintf('Absorption data loaded and cached in memory at %s\n', ...
                string(loadTime));
    end
    
    AbsorptionData = cachedData;
end