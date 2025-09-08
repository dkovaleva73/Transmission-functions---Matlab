classdef TransmissionOptimizer < handle
    % Description:  Controller class for sequential transmission optimization
    %               This class manages the optimization sequence, stores results between stages,
    %               and coordinates the overall calibration process following the Garappa et al. (2025) pattern
    % Author:    D. Kovaleva (Sep 2025)
    % Reference: Garrappa et al. 2025, A&A 699, A50
    % Example:  Config = transmission.inputConfig();
    %           optimizer = transmission.TransmissionOptimizer(Config);
    %           finalParams = optimizer.runFullSequence();
    %           calibrators = optimizer.getCalibratorResults; % optimized fluxes for calibrators                                             % fluxes for calibrators
    
    properties
        Config              % Transmission configuration
        ActiveSequence      % Currently selected optimization sequence
        OptimizedParams     % Accumulated optimized parameters
        CurrentStage        % Current stage index
        CalibratorData      % Calibrator data (persists between stages)
        ChebyshevModel      % Basic Chebyshev field correction model
        SigmaClippingEnabled % Global sigma clipping enable/disable
        Verbose             % Verbose output flag
        Results             % Store results from each stage
    end
    
    methods
        function obj = TransmissionOptimizer(Config, Args)
            % Constructor - Initialize the optimizer with configuration
            
            arguments
                Config = transmission.inputConfig()
                Args.Sequence string = "Standard"  
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
            
            if obj.Verbose
                fprintf('=== TRANSMISSION OPTIMIZER INITIALIZED ===\n');
                fprintf('Sequence: %s\n', sequenceName);
                fprintf('Number of stages: %d\n', length(obj.ActiveSequence));
                fprintf('Sigma clipping: %s\n', string(Args.SigmaClippingEnabled));
                fprintf('\n');
            end
        end
             
        function setCustomSequence(obj, customStages)
            % Set a custom optimization sequence
            
            obj.validateSequence(customStages);
            obj.ActiveSequence = customStages;
            
            if obj.Verbose
                fprintf('Custom sequence set with %d stages\n', length(customStages));
            end
        end
        
        function validateSequence(obj, stages)
            % Validate that a sequence has required fields
            requiredFields = {'name', 'freeParams', 'method'};
            
            if ~isstruct(stages)
                error('Sequence must be a struct array');
            end
            
            for i = 1:length(stages)
                stage = stages(i);
                for j = 1:length(requiredFields)
                    if ~isfield(stage, requiredFields{j})
                        error('Stage %d missing required field: %s', i, requiredFields{j});
                    end
                end
                
                % Validate method
                if ~ismember(stage.method, {'linear', 'nonlinear'})
                    error('Stage %d: method must be "linear" or "nonlinear"', i);
                end
            end
        end
        
        function finalParams = runFullSequence(obj, fieldNum)
            % Run the complete optimization sequence
            % Input: fieldNum - Field number (1-24) for AstroImage, default: 1
            
            if nargin < 2
                fieldNum = 1;  % Default field number
            end
            
            if isempty(obj.ActiveSequence)
                error('No optimization sequence defined');
            end
            
            if obj.Verbose
                fprintf('=== STARTING FULL OPTIMIZATION SEQUENCE ===\n');
                fprintf('Field number: %d\n', fieldNum);
                fprintf('Total stages: %d\n\n', length(obj.ActiveSequence));
            end
            
            % Load initial calibrator data for specified field
            obj.loadCalibratorData(fieldNum);
            
            % Absorption data is already available in Config.AbsorptionData
            
            % Run each stage
            for stageIdx = 1:length(obj.ActiveSequence)
                obj.CurrentStage = stageIdx;
                stage = obj.ActiveSequence(stageIdx);
                
                if obj.Verbose
                    fprintf('--- STAGE %d: %s ---\n', stageIdx, stage.name);
                    fprintf('Description: %s\n', stage.description);
                    fprintf('Free parameters: %s\n', strjoin(string(stage.freeParams), ', '));
                    
                end
                
                % Run the stage
                stageResult = obj.runSingleStage(stage);
                
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
                fprintf('=== OPTIMIZATION SEQUENCE COMPLETE ===\n');
            end
        end
        
        function stageResult = runSingleStage(obj, stage)
            % Run a single optimization stage
            
            % Prepare arguments for minimizerFminGeneric
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
            
            % Handle basic Chebyshev field corrections 
            if isfield(stage, 'useChebyshev') && any(stage.useChebyshev)
                Args.UseChebyshev = true;
                if isfield(stage, 'chebyshevOrder')
                    Args.ChebyshevOrder = stage.chebyshevOrder;
                end
            end
            
            % Handle Python-like Chebyshev field model (advanced)
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
            
            % Use cached calibrator data
            Args.InputData = obj.CalibratorData;
            
            % Set verbosity
            Args.Verbose = obj.Verbose;
            
            % Choose solver based on stage method
            if isfield(stage, 'method') && strcmp(stage.method, 'linear')
                % Use linear least squares solver
                if obj.Verbose
                    fprintf('Using linear least squares solver\n');
                end
                
                % Convert struct to name-value pairs for linear solver
                argCell = {};
                if isfield(Args, 'FreeParams')
                    argCell = [argCell, {'FreeParams', Args.FreeParams}];
                end
                if isfield(Args, 'FixedParams')
                    argCell = [argCell, {'FixedParams', Args.FixedParams}];
                end
                if isfield(Args, 'SigmaClipping')
                    argCell = [argCell, {'SigmaClipping', Args.SigmaClipping}];
                end
                if isfield(Args, 'SigmaThreshold')
                    argCell = [argCell, {'SigmaThreshold', Args.SigmaThreshold}];
                end
                if isfield(Args, 'SigmaIterations')
                    argCell = [argCell, {'SigmaIterations', Args.SigmaIterations}];
                end
                if isfield(Args, 'InputData')
                    argCell = [argCell, {'InputData', Args.InputData}];
                end
                if isfield(Args, 'Verbose')
                    argCell = [argCell, {'Verbose', Args.Verbose}];
                end
                
                [OptimalParams, Fval, ExitFlag, Output, ResultData] = ...
                    transmission.minimizerLinearLeastSquares(obj.Config, argCell{:});
            else
                % Use nonlinear solver (default)
                if obj.Verbose
                    fprintf('Using nonlinear solver (fminsearch)\n');
                end
                
                % Convert struct to name-value pairs for nonlinear solver
                argCell = {};
                if isfield(Args, 'FreeParams')
                    argCell = [argCell, {'FreeParams', Args.FreeParams}];
                end
                if isfield(Args, 'FixedParams')
                    argCell = [argCell, {'FixedParams', Args.FixedParams}];
                end
                if isfield(Args, 'InitialValues')
                    argCell = [argCell, {'InitialValues', Args.InitialValues}];
                end
                if isfield(Args, 'SigmaClipping')
                    argCell = [argCell, {'SigmaClipping', Args.SigmaClipping}];
                end
                if isfield(Args, 'SigmaThreshold')
                    argCell = [argCell, {'SigmaThreshold', Args.SigmaThreshold}];
                end
                if isfield(Args, 'SigmaIterations')
                    argCell = [argCell, {'SigmaIterations', Args.SigmaIterations}];
                end
                if isfield(Args, 'UseChebyshev')
                    argCell = [argCell, {'UseChebyshev', Args.UseChebyshev}];
                end
                if isfield(Args, 'ChebyshevOrder')
                    argCell = [argCell, {'ChebyshevOrder', Args.ChebyshevOrder}];
                end
                if isfield(Args, 'UsePythonFieldModel')
                    argCell = [argCell, {'UsePythonFieldModel', Args.UsePythonFieldModel}];
                end
                if isfield(Args, 'InputData')
                    argCell = [argCell, {'InputData', Args.InputData}];
                end
                if isfield(Args, 'Verbose')
                    argCell = [argCell, {'Verbose', Args.Verbose}];
                end
                
                [OptimalParams, Fval, ExitFlag, Output, ResultData] = ...
                    transmission.minimizerFminGeneric(obj.Config, argCell{:});
            end
            disp(Args.FreeParams);
            disp(Args.FixedParams);
            disp(Args.InputData);
            disp(OptimalParams);
            disp(Fval);
            disp(Output);
            disp(ResultData);
            % Update calibrator data if sigma clipping was applied
            if Args.SigmaClipping
                obj.CalibratorData = ResultData.CalibData;
            end
            
            % Package results
            stageResult = struct();
            stageResult.StageName = stage.name;
            stageResult.OptimalParams = OptimalParams;
            stageResult.Fval = Fval;
            stageResult.ExitFlag = ExitFlag;
            stageResult.Output = Output;
            stageResult.ResultData = ResultData;
            stageResult.StageConfig = stage;
        end
        
        function loadCalibratorData(obj, fieldNum)
            % Load calibrator data from catalog for specific field
            % Input: fieldNum - Field number (1-24) for AstroImage, default: 1
            
            if nargin < 2
                fieldNum = 1;  % Default field number
            end
            
            if obj.Verbose
                fprintf('Loading calibrator data for field %d...\n', fieldNum);
            end
            
      %     CatalogFile = obj.Config.Data.LAST_AstroImage_file;
            SearchRadius = obj.Config.Data.Search_radius_arcsec;
            CatalogFile = obj.Config.Data.LAST_catalog_file;
    
    
        [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords(...
            CatalogFile, SearchRadius);

            
      %      [Spec, Mag, Coords, LASTData, Metadata] = ...
      %          transmission.data.findCalibratorsForAstroImage(CatalogFile, SearchRadius, fieldNum);
            
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
        
        function saveResults(obj, filename)
            % Save optimization results to file
            
            if nargin < 2
                filename = sprintf('TransmissionOptimizer_results_%s.mat', ...
                                  string(datetime('now', 'Format', 'yyyyMMdd_HHmmss')));
            end
            
            SavedData = struct();
            SavedData.OptimizedParams = obj.OptimizedParams;
            SavedData.Config = obj.Config;
            SavedData.Sequence = obj.ActiveSequence;
            SavedData.StageResults = obj.Results;
            SavedData.Timestamp = datetime('now');
            
            save(filename, 'SavedData');
            
            if obj.Verbose
                fprintf('Results saved to: %s\n', filename);
            end
        end
       
     
        function params = getOptimizedParams(obj)
            % Get current optimized parameters
            params = obj.OptimizedParams;
        end
        
        function stage = getCurrentStage(obj)
            % Get current stage information
            if obj.CurrentStage > 0 && obj.CurrentStage <= length(obj.ActiveSequence)
                stage = obj.ActiveSequence(obj.CurrentStage);
            else
                stage = [];
            end
        end
        
        function CalibratorTable = getCalibratorResults(obj)
            % Create a table with calibrator data and final DiffMag values
            % Output: CalibratorTable - MATLAB table containing:
            %         - All LAST catalog data for calibrators
            %         - DIFF_MAG - Final optimization residuals
            %         - Gaia coordinates and other calibrator-specific data
            
            if isempty(obj.Results)
                error('No optimization results available. Run optimization first.');
            end
            
            % Get the final stage results (contains final DiffMag)
            finalStageResult = obj.Results{end};
            
            if ~isfield(finalStageResult.ResultData, 'DiffMag')
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
            if ~isempty(CalibData.Coords)
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
            
            % Add optimization metadata
            CalibratorTable.Properties.Description = sprintf(...
                'Calibrator data with DiffMag from %s optimization (Cost: %.4e)', ...
                finalStageResult.StageName, finalStageResult.Fval);
            
            if obj.Verbose
                fprintf('Calibrator table created:\n');
                fprintf('  Calibrators: %d\n', height(CalibratorTable));
                fprintf('  DiffMag mean: %.4f mag\n', mean(DiffMag));
                fprintf('  DiffMag std: %.4f mag\n', std(DiffMag));
                fprintf('  Final optimization cost: %.4e\n', finalStageResult.Fval);
            end
        end
    end
end