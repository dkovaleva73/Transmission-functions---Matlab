classdef TransmissionOptimizerAdvanced < handle
    % Description:  Controller class for sequential transmission optimization 
    %               with customizable minimizers. Manages the optimization sequence, 
    %               stores results between stages, and coordinates the overall calibration process
    %               Extends TransmissionOptimizer with support for different optimization
    %               algorithms per stage (nonlinear vs linear least squares)
    %               Default: Linear least squares for field correction
    %               parameters (Stage 3); Nonlinear optimization for other parameters
    %               (fmin)
    % Author   : D. Kovaleva (Sep 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50.
    % Example:  Config = transmissionFast.inputConfig();
    %           optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config);
    %           optimizer.setMinimizerForStage(3, 'linear');  % Use linear solver for field corrections
    %           finalParams = optimizer.runFullSequence();
    %           calibrators = optimizer.getCalibratorResults; % optimized fluxes for calibrators    
    
    properties (Access = public)
        Config                   % Configuration structure
        CalibratorData           % Loaded calibrator data
        OptimizedParams          % Accumulated optimized parameters
        Results                  % Results from each optimization stage
        ActiveSequence           % Current optimization sequence
        CurrentStage = 0         % Current stage index
        Verbose = false          % Enable verbose output
        SigmaClippingEnabled = true  % Enable sigma clipping globally
        StageMinimizers          % Minimizer type for each stage ('nonlinear' or 'linear')
    end
    
    methods
        function obj = TransmissionOptimizerAdvanced(Config, Args)
            % Constructor for TransmissionOptimizerAdvanced
            
            arguments
                Config = transmissionFast.inputConfig()
                Args.Sequence string = ""  % Empty means use Config default
                Args.SigmaClippingEnabled logical = true
                Args.Verbose logical = true
                Args.SaveIntermediateResults logical = false
            end
            
            obj.Config = Config;
            obj.SigmaClippingEnabled = Args.SigmaClippingEnabled;
            obj.Verbose = Args.Verbose;
            obj.OptimizedParams = struct();
            obj.CurrentStage = 0;
            obj.Results = {};
            
            % Select optimization sequence from Config
            if Args.Sequence == ""
                % Use default sequence from Config
                sequenceName = obj.Config.Optimization.DefaultSequence;
            else
                sequenceName = Args.Sequence;
            end
            
            % Get sequence from Config
            if isfield(obj.Config.Optimization.Sequences, sequenceName)
                obj.ActiveSequence = obj.Config.Optimization.Sequences.(sequenceName);
            else
                error('Unknown sequence: %s. Available sequences: %s', ...
                      sequenceName, strjoin(fieldnames(obj.Config.Optimization.Sequences), ', '));
            end
            
            % Initialize stage minimizers from sequence definitions
            numStages = length(obj.ActiveSequence);
            obj.StageMinimizers = string.empty(1, 0);
            
            for i = 1:numStages
                if isfield(obj.ActiveSequence(i), 'method')
                    obj.StageMinimizers(i) = obj.ActiveSequence(i).method;
                else
                    obj.StageMinimizers(i) = "nonlinear";  % Default fallback
                end
            end
            
            if obj.Verbose
                fprintf('=== ADVANCED TRANSMISSION OPTIMIZER INITIALIZED ===\n');
                fprintf('Sequence: %s\n', sequenceName);
                fprintf('Number of stages: %d\n', length(obj.ActiveSequence));
                fprintf('Sigma clipping: %s\n', string(Args.SigmaClippingEnabled));
                fprintf('Stage minimizers: %s\n', strjoin(obj.StageMinimizers, ', '));
                fprintf('\n');
            end
        end
        
        function setMinimizerForStage(obj, stageNum, minimizerType)
            % Set the minimizer type for a specific stage
            %
            % Input: - stageNum - Stage number (1-based)
            %        - minimizerType - 'nonlinear' or 'linear'
            
            if stageNum < 1 || stageNum > length(obj.ActiveSequence)
                error('Invalid stage number: %d. Must be 1-%d', stageNum, length(obj.ActiveSequence));
            end
            
            if ~ismember(lower(minimizerType), ["nonlinear", "linear"])
                error('Invalid minimizer type: %s. Must be ''nonlinear'' or ''linear''', minimizerType);
            end
            
            obj.StageMinimizers(stageNum) = lower(minimizerType);
            
            if obj.Verbose
                fprintf('Stage %d minimizer set to: %s\n', stageNum, lower(minimizerType));
            end
        end
        
        function finalParams = runFullSequence(obj, fieldNum)
            % Run the complete multi-stage optimization sequence
            % Input: fieldNum - Field number (1-24) for AstroImage (optional, default=1)
            
            if obj.Verbose
                fprintf('=== START OPTIMIZATION ===\n');
                fprintf('Total stages: %d\n', length(obj.ActiveSequence));
                for i = 1:length(obj.ActiveSequence)
                    fprintf('  Stage %d (%s): %s [%s]\n', i, obj.ActiveSequence(i).name, ...
                            obj.ActiveSequence(i).description, obj.StageMinimizers(i));
                end
                fprintf('\n');
            end
            
            if nargin < 2
                fieldNum = 1;  % Default to field 1 if not specified
            end
            
            % Load data if not already loaded
            if isempty(obj.CalibratorData)
                obj.loadCalibratorData(fieldNum);
            end
                      
            % Run each stage
            for stageIdx = 1:length(obj.ActiveSequence)
                obj.CurrentStage = stageIdx;
                stage = obj.ActiveSequence(stageIdx);
                minimizerType = obj.StageMinimizers(stageIdx);
                
                if obj.Verbose
                    fprintf('--- STAGE %d: %s [%s] ---\n', stageIdx, stage.name, minimizerType);
                    fprintf('Description: %s\n', stage.description);
                    fprintf('Free parameters: %s\n', strjoin(string(stage.freeParams), ', '));
                    
                end
                
                % Run the stage with appropriate minimizer
                stageResult = obj.runSingleStageAdvanced(stage, minimizerType);
                
                % Store results
                obj.Results{stageIdx} = stageResult;
                
                % Update optimized parameters
                obj.updateOptimizedParams(stageResult.OptimalParams);
                disp(stageResult.OptimalParams);
                if obj.Verbose
                    fprintf('Stage %d completed. Cost: %.4e\n', stageIdx, stageResult.Fval);
                    
                    fprintf('\n');
                end
            end
            
            % Return final optimized parameters
            finalParams = obj.OptimizedParams;
            
            if obj.Verbose
                fprintf('=== ADVANCED OPTIMIZATION SEQUENCE COMPLETE ===\n');
            end
        end
        
        function stageResult = runSingleStageAdvanced(obj, stage, minimizerType)
            % Run a single optimization stage with specified minimizer
            
            % Prepare arguments for the minimizer
            Args = struct();
            
            % Set free parameters
            if ~isempty(stage.freeParams)
                Args.FreeParams = stage.freeParams;
            end
            
            % Use previously optimized parameters as fixed, except for Norm_ which can be re-optimized
            Args.FixedParams = struct();
            optimizedFields = fieldnames(obj.OptimizedParams);
            for i = 1:length(optimizedFields)
                paramName = optimizedFields{i};
                % Special case: Norm_ can be re-optimized in multiple stages
                if strcmp(paramName, 'Norm_') && ismember("Norm_", string(stage.freeParams))
                    % Don't fix Norm_ if it's being optimized in this stage
                    continue;
                else
                    % Fix all other previously optimized parameters
                    Args.FixedParams.(paramName) = obj.OptimizedParams.(paramName);
                end
            end
            
            % Use previously optimized Norm_ as initial value if it's being re-optimized
            Args.InitialValues = struct();
            if ismember("Norm_", string(stage.freeParams)) && isfield(obj.OptimizedParams, 'Norm_')
                Args.InitialValues.Norm_ = obj.OptimizedParams.Norm_;
            end
            
            % Handle sigma clipping
            if isfield(stage, 'sigmaClipping') && any(stage.sigmaClipping) && obj.SigmaClippingEnabled
                Args.SigmaClipping = true;
                Args.SigmaThreshold = stage.sigmaThreshold;
                Args.SigmaIterations = stage.sigmaIterations;
            else
                Args.SigmaClipping = false;
            end
            
            % Handle Python field model
            if isfield(stage, 'usePythonFieldModel') && any(stage.usePythonFieldModel)
                Args.UsePythonFieldModel = true;
                % Add any fixed parameters for Python model (e.g., ky0 = 0)
                if isfield(stage, 'fixedParams')
                    fixedFields = fieldnames(stage.fixedParams);
                    for i = 1:length(fixedFields)
                        Args.FixedParams.(fixedFields{i}) = stage.fixedParams.(fixedFields{i});
                    end
                end
            end
            
            % Handle basic Chebyshev field corrections (for nonlinear solver)
            if isfield(stage, 'useChebyshev') && any(stage.useChebyshev)
                Args.UseChebyshev = true;
                if isfield(stage, 'chebyshevOrder')
                    Args.ChebyshevOrder = stage.chebyshevOrder;
                end
            end
            
            % Add regularization for linear solver
            if strcmp(minimizerType, 'linear') && isfield(stage, 'regularization')
                Args.Regularization = stage.regularization;
            end
           
            % Use cached calibrator data
            Args.InputData = obj.CalibratorData;
            
            % Set verbosity
            Args.Verbose = obj.Verbose;
            
            % Update Config with all optimized parameters before calling minimizer
            ConfigForMinimizer = obj.updateConfigWithOptimizedParams(obj.Config, obj.OptimizedParams);
            
            % Call appropriate minimizer
            if strcmp(minimizerType, 'linear')
                % Validate that only field correction parameters are being optimized
                validFieldParams = ["kx0", "ky0", "kx", "ky", "kx2", "ky2", "kx3", "ky3", "kx4", "ky4", "kxy"];
                for i = 1:length(stage.freeParams)
                    if ~ismember(stage.freeParams(i), validFieldParams)
                        error('Linear solver can only optimize field correction parameters. Invalid parameter: %s', stage.freeParams(i));
                    end
                end
                
                % Convert struct to name-value pairs for linear solver
                argCell = obj.structToNameValuePairs(Args);
                [stageResult.OptimalParams, stageResult.Fval, stageResult.ExitFlag, ...
                 stageResult.Output, stageResult.ResultData] = ...
                    transmissionFast.minimizerLinearLeastSquares(ConfigForMinimizer, argCell{:});
            else
                % Use nonlinear solver
                argCell = obj.structToNameValuePairs(Args);
                [stageResult.OptimalParams, stageResult.Fval, stageResult.ExitFlag, ...
                 stageResult.Output, stageResult.ResultData] = ...
                    transmissionFast.minimizerFminGeneric(ConfigForMinimizer, argCell{:});
            end
            
            % Add minimizer type to results
            stageResult.MinimizerType = minimizerType;
            
            % Update calibrator data if sigma clipping was used
            % This ensures subsequent stages use the cleaned data
            if Args.SigmaClipping && isfield(stageResult, 'ResultData') && isfield(stageResult.ResultData, 'CalibData')
                obj.CalibratorData = stageResult.ResultData.CalibData;
                if obj.Verbose
                    fprintf('Updated calibrator data after sigma clipping: %d calibrators remaining\n', ...
                            length(obj.CalibratorData.Spec));
                end
            end
        end
        
        function loadCalibratorData(obj, fieldNum)
            % Load calibrator data from LAST catalog
            % Input: fieldNum - Field number (1-24) for AstroImage (optional, default=1)
            
            if nargin < 2
                fieldNum = 1;  % Default to field 1 if not specified
            end
            
            if obj.Verbose
                fprintf('Loading calibrator data for field %d...\n', fieldNum);
            end
            
           CatalogFile = obj.Config.Data.LAST_AstroImage_file;
      %      CatalogFile = obj.Config.Data.LAST_catalog_file;
            SearchRadius = obj.Config.Data.Search_radius_arcsec;
            
     %       [Spec, Mag, Coords, LASTData, Metadata] = transmissionFast.data.findCalibratorsWithCoords(...
     %           CatalogFile, SearchRadius);
           [Spec, Mag, Coords, LASTData, Metadata] = ...
               transmissionFast.data.findCalibratorsForAstroImage(CatalogFile, SearchRadius, fieldNum);
     
            obj.CalibratorData = struct();
            obj.CalibratorData.Spec = Spec;
            obj.CalibratorData.Mag = Mag;
            obj.CalibratorData.Coords = Coords;
            obj.CalibratorData.LASTData = LASTData;
            obj.CalibratorData.Metadata = Metadata;
            
            if obj.Verbose
                fprintf('Loaded %d calibrators\n', length(Spec));
            end
        end
        
        
        function updateOptimizedParams(obj, newParams)
            % Update the accumulated optimized parameters
            
            paramFields = fieldnames(newParams);
            for i = 1:length(paramFields)
                obj.OptimizedParams.(paramFields{i}) = newParams.(paramFields{i});
            end
        end
        
        function ConfigUpdated = updateConfigWithOptimizedParams(~, Config, OptimizedParams)
            % Update Config structure with optimized parameters
            ConfigUpdated = Config;
            
            % Map optimized parameters to Config structure
            paramFields = fieldnames(OptimizedParams);
            for i = 1:length(paramFields)
                paramName = paramFields{i};
                paramValue = OptimizedParams.(paramName);
                
                % Map parameter names to Config paths
                switch paramName
                    case 'Norm_'
                        ConfigUpdated.General.Norm_ = paramValue;
                    case 'Center'
                        ConfigUpdated.Utils.SkewedGaussianModel.Default_center = paramValue;
                    case 'Amplitude'
                        ConfigUpdated.Utils.SkewedGaussianModel.Default_amplitude = paramValue;
                    case 'Sigma'
                        ConfigUpdated.Utils.SkewedGaussianModel.Default_sigma = paramValue;
                    case 'Gamma'
                        ConfigUpdated.Utils.SkewedGaussianModel.Default_gamma = paramValue;
                    case 'Pwv_cm'
                        ConfigUpdated.Atmospheric.Components.Water.Pwv_cm = paramValue;
                    case 'Tau_aod500'
                        ConfigUpdated.Atmospheric.Components.Aerosol.Tau_aod500 = paramValue;
                    case 'Alpha'
                        ConfigUpdated.Atmospheric.Components.Aerosol.Angstrom_exponent = paramValue;
                    case 'Dobson_units'
                        ConfigUpdated.Atmospheric.Components.Ozone.Dobson_units = paramValue;
                    case 'Temperature_C'
                        ConfigUpdated.Atmospheric.Temperature_C = paramValue;
                    case 'Pressure'
                        ConfigUpdated.Atmospheric.Pressure = paramValue;
                    % Field correction parameters
                    case {'kx0', 'ky0', 'kx', 'ky', 'kx2', 'ky2', 'kx3', 'ky3', 'kx4', 'ky4', 'kxy'}
                        ConfigUpdated.FieldCorrection.(paramName) = paramValue;
                end
            end
        end
        
        function argCell = structToNameValuePairs(~, Args)
            % Convert arguments structure to name-value pairs
            
            argFields = fieldnames(Args);
            numFields = length(argFields);
            argCell = cell(1, numFields * 2);  % Preallocate: each field needs name and value
            
            for i = 1:numFields
                argCell{2*i-1} = argFields{i};      % Field name
                argCell{2*i} = Args.(argFields{i}); % Field value
            end
        end
        
        function CalibratorTable = getCalibratorResults(obj)
            % Get final calibrator results as a MATLAB table
            % Returns table with all calibrator data and optimization residuals
            %
            % Output: CalibratorTable - MATLAB table containing:
            %         - All LAST catalog data for calibrators
            %         - DIFF_MAG - Final optimization residuals
            %         - Gaia coordinates and other calibrator-specific data
            %         - MINIMIZER_TYPE - Type of minimizer used in final stage
            
            if isempty(obj.Results)
                error('No optimization results available. Run optimization first.');
            end
            
            % Get the final stage results (contains final DiffMag)
            finalStageResult = obj.Results{end};
            
            if ~isfield(finalStageResult, 'ResultData') || ~isfield(finalStageResult.ResultData, 'DiffMag')
                error('No DiffMag found in optimization results');
            end
            
            % Extract calibrator data and DiffMag
            CalibData = finalStageResult.ResultData.CalibData;
            DiffMag = finalStageResult.ResultData.DiffMag;
            
            % Create table from calibrator LAST data
            CalibratorTable = CalibData.LASTData;
            
            % Add DiffMag column
            CalibratorTable.DIFF_MAG = DiffMag;
            
            % Add Gaia coordinates if available
            if isfield(CalibData, 'Coords') && ~isempty(CalibData.Coords)
                Coords = CalibData.Coords;
                numCoords = length(Coords);
                numRows = height(CalibratorTable);
                
                if numCoords == numRows
                    CalibratorTable.GAIA_RA = [Coords.Gaia_RA]';
                    CalibratorTable.GAIA_DEC = [Coords.Gaia_Dec]';
                    CalibratorTable.LAST_IDX = [Coords.LAST_idx]';
                else
                    warning('Coordinate array size (%d) does not match table height (%d). Skipping coordinates.', ...
                            numCoords, numRows);
                end
            end
            
            % Add information about minimizer type used
            if isfield(finalStageResult, 'MinimizerType')
                minimizerInfo = sprintf(' [%s minimizer]', finalStageResult.MinimizerType);
            else
                minimizerInfo = '';
            end
            
            % Add optimization metadata
            stageName = obj.ActiveSequence(end).name;
            CalibratorTable.Properties.Description = sprintf(...
                'Calibrator data with DiffMag from %s optimization%s (Cost: %.4e)', ...
                stageName, minimizerInfo, finalStageResult.Fval);
            
            if obj.Verbose
                fprintf('Calibrator table created:\n');
                fprintf('  Calibrators: %d\n', height(CalibratorTable));
                fprintf('  DiffMag mean: %.4f mag\n', mean(DiffMag));
                fprintf('  DiffMag std: %.4f mag\n', std(DiffMag));
                fprintf('  Final optimization cost: %.4e\n', finalStageResult.Fval);
                if isfield(finalStageResult, 'MinimizerType')
                    fprintf('  Final stage minimizer: %s\n', finalStageResult.MinimizerType);
                end
            end
        end
    end
end