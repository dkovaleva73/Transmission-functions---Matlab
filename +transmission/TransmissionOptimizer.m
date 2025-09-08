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
                Args.Sequence string = "DefaultSequence"
           %     Args.Sequence string = "AtmosphericOnly"
           %     Args.Sequence string = "FieldCorrectionOnly"
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
            
            % Select optimization sequence
            switch Args.Sequence
                case "DefaultSequence"
                    obj.ActiveSequence = transmission.TransmissionOptimizer.defineDefaultSequence();
                case "AtmosphericOnly"
                    obj.ActiveSequence = transmission.TransmissionOptimizer.defineAtmosphericSequence();
                case "FieldCorrectionOnly"
                    obj.ActiveSequence = transmission.TransmissionOptimizer.defineFieldCorrectionSequence();
                otherwise
                    error('Unknown sequence: %s', Args.Sequence);
            end
            
            if obj.Verbose
                fprintf('=== TRANSMISSION OPTIMIZER INITIALIZED ===\n');
                fprintf('Sequence: %s\n', Args.Sequence);
                fprintf('Number of stages: %d\n', length(obj.ActiveSequence));
                fprintf('Sigma clipping: %s\n', string(Args.SigmaClippingEnabled));
                fprintf('\n');
            end
        end
             
        function setCustomSequence(obj, customStages)
            % Set a custom optimization sequence
            
            transmission.TransmissionOptimizer.validateSequence(customStages);
            obj.ActiveSequence = customStages;
            
            if obj.Verbose
                fprintf('Custom sequence set with %d stages\n', length(customStages));
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
            
            % Run optimization - convert struct to name-value pairs
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
    
    methods (Static)
        function stages = defineDefaultSequence()
            
            % Uses Python-like optimization sequence and Chebyshev field correction model
            
            % Stage 1: Normalize only with sigma clipping
            stages(1).name = "NormOnly_Initial";
            stages(1).freeParams = "Norm_";
            stages(1).sigmaClipping = true;
            stages(1).sigmaThreshold = 3.0;
            stages(1).sigmaIterations = 3;
            stages(1).usePythonFieldModel = true;  % Use Python-like Chebyshev field correction model
            stages(1).fixedParams = struct('ky0', 0);  % Keep ky0 fixed at 0
            stages(1).description = "Initial normalization with outlier removal";
            
            % Stage 2: Norm + QE center (no sigma clipping)
            stages(2).name = "NormAndCenter";
            stages(2).freeParams = ["Norm_", "Center"];
            stages(2).sigmaClipping = false;
            stages(2).usePythonFieldModel = true;  % Use Python-like Chebyshev field correction model
            stages(2).fixedParams = struct('ky0', 0);  % Keep ky0 fixed at 0
            stages(2).description = "Optimize normalization and QE center";
            
            % Stage 3: Python-compliant field corrections 
            % kx0 varies, ky0=0 fixed, order 4 for X,Y, order 1 for XY
            stages(3).name = "FieldCorrection_Python";
            stages(3).freeParams = ["kx0", "kx", "ky", "kx2", "ky2", "kx3", "ky3", "kx4", "ky4", "kxy"];
            stages(3).fixedParams = struct('ky0', 0);  % ky0 = 0 and fixed
            stages(3).usePythonFieldModel = true;  % Use Python-like Chebyshev field correction model
            stages(3).sigmaClipping = true;
            stages(3).sigmaThreshold = 2.0;  % Tighter threshold
            stages(3).sigmaIterations = 3;
            stages(3).description = "Python-like Chebyshev field corrections";
            
            % Stage 4: Norm refinement
            stages(4).name = "NormRefinement";
            stages(4).freeParams = "Norm_";
            stages(4).sigmaClipping = false;
            stages(4).usePythonFieldModel = true;  % Use Python-like Chebyshev field correction model
            stages(4).fixedParams = struct('ky0', 0);  % Keep ky0 fixed at 0
            stages(4).description = "Refine normalization after field corrections";
            
            % Stage 5: Atmospheric parameters
            stages(5).name = "Atmospheric";
            stages(5).freeParams = ["Pwv_cm", "Tau_aod500"];
            stages(5).usePythonFieldModel = true;  % Use Python-like Chebyshev field correction model
            stages(5).sigmaClipping = false;
            stages(5).fixedParams = struct('ky0', 0);  % Keep ky0 fixed at 0
            stages(5).description = "Optimize water vapor and aerosol parameters";
        end
        
        function stages = defineSimpleFieldCorrectionSequence()
            % Define the simple field correction sequence (original behavior)
            % Uses basic Chebyshev model with order 4
            
            % Stage 1: Normalize only with sigma clipping
            stages(1).name = "NormOnly_Initial";
            stages(1).freeParams = "Norm_";
            stages(1).sigmaClipping = true;
            stages(1).sigmaThreshold = 3.0;
            stages(1).sigmaIterations = 3;
            stages(1).description = "Initial normalization with outlier removal";
            
            % Stage 2: Norm + QE center
            stages(2).name = "NormAndCenter";
            stages(2).freeParams = ["Norm_", "Center"];
            stages(2).sigmaClipping = false;
            stages(2).description = "Optimize normalization and QE center";
            
            % Stage 3: Simple field corrections using existing Chebyshev
            stages(3).name = "FieldCorrection_Simple";
            stages(3).freeParams = ["cx0", "cx1", "cx2", "cx3", "cx4", "cy0", "cy1", "cy2", "cy3", "cy4"];
            stages(3).useChebyshev = true;
            stages(3).chebyshevOrder = 4;
            stages(3).sigmaClipping = true;
            stages(3).sigmaThreshold = 2.0;
            stages(3).sigmaIterations = 3;
            stages(3).description = "Basic Chebyshev field correction coefficients";
            
            % Stage 4: Norm refinement
            stages(4).name = "NormRefinement";
            stages(4).freeParams = "Norm_";
            stages(4).sigmaClipping = false;
            stages(4).description = "Refine normalization after field corrections";
            
            % Stage 5: Atmospheric parameters
            stages(5).name = "Atmospheric";
            stages(5).freeParams = ["Pwv_cm", "Tau_aod500"];
            stages(5).sigmaClipping = false;
            stages(5).description = "Optimize water vapor and aerosol parameters";
        end
        
        function stages = defineAtmosphericSequence()
            % Sequence focusing on atmospheric parameters
            
         % Stage 1: Normalize only with sigma clipping
            stages(1).name = "NormOnly_Initial";
            stages(1).freeParams = "Norm_";
            stages(1).sigmaClipping = true;
            stages(1).sigmaThreshold = 3.0;
            stages(1).sigmaIterations = 3;
            stages(1).description = "Initial normalization with outlier removal";
            
            % Stage 2: Norm + QE center (no sigma clipping)
            stages(2).name = "NormAndCenter";
            stages(2).freeParams = ["Norm_", "Center"];
            stages(2).sigmaClipping = false;
            stages(2).description = "Optimize normalization and QE center";
            
            % Stage 3: Atmospheric parameters
            stages(3).name = "Atmospheric";
            stages(3).freeParams = ["Pwv_cm", "Tau_aod500"];
            stages(3).sigmaClipping = false;
            stages(3).description = "Optimize water vapor and aerosol parameters";
        end
        
        
        function stages = defineQuickSequence()
            % Minimal sequence for quick calibration
            
            stages(1).name = "QuickNorm";
            stages(1).freeParams = "Norm_";
            stages(1).sigmaClipping = true;
            stages(1).sigmaThreshold = 3.0;
            stages(1).sigmaIterations = 1;  % Fewer iterations for speed
            stages(1).description = "Quick normalization";
            
            stages(2).name = "QuickAtmospheric";
            stages(2).freeParams = "Tau_aod500";
            stages(2).sigmaClipping = false;
            stages(2).description = "Quick aerosol adjustment";
        end
        
        function stages = defineFieldCorrectionSequence()
            % Sequence focusing on field-dependent corrections
            
            stages(1).name = "NormOnly";
            stages(1).freeParams = "Norm_";
            stages(1).sigmaClipping = true;
            stages(1).sigmaThreshold = 3.0;
            stages(1).sigmaIterations = 2;
            stages(1).description = "Initial normalization";
            
               % Stage 2: Python-compliant field corrections 
            % kx0 varies, ky0=0 fixed, order 4 for X,Y, order 1 for XY
            stages(2).name = "FieldCorrection_Python";
            stages(2).freeParams = ["kx0", "kx", "ky", "kx2", "ky2", "kx3", "ky3", "kx4", "ky4", "kxy"];
            stages(2).fixedParams = struct('ky0', 0);  % ky0 = 0 and fixed
            stages(2).usePythonFieldModel = true;  % Use Python field correction model
            stages(2).sigmaClipping = true;
            stages(2).sigmaThreshold = 2.0;  % Tighter threshold
            stages(2).sigmaIterations = 3;
            stages(2).description = "Python-like Chebyshev field corrections";
        end

        function validateSequence(stages)
            % Validate that a sequence structure is properly formatted
            
            if isempty(stages)
                error('Sequence cannot be empty');
            end
            
            requiredFields = {'name', 'freeParams', 'description'};
            
            for i = 1:length(stages)
                for j = 1:length(requiredFields)
                    if ~isfield(stages(i), requiredFields{j})
                        error('Stage %d missing required field: %s', i, requiredFields{j});
                    end
                end
            end
        end
    end
end