classdef TransmissionOptimizerAdvanced < handle
    % Advanced multi-stage transmission parameter optimizer with customizable minimizers
    % Extends TransmissionOptimizer with support for different optimization algorithms per stage
    % 
    % Features:
    % - Stage-specific minimizer selection (nonlinear vs linear least squares)
    % - Linear least squares for field correction parameters (Stage 3)
    % - Nonlinear optimization for other parameters
    % - Full compatibility with existing optimization sequences
    %
    % Author: D. Kovaleva (Aug 2025)
    % Usage:
    %   Config = transmission.inputConfig();
    %   optimizer = transmission.TransmissionOptimizerAdvanced(Config);
    %   optimizer.setMinimizerForStage(3, 'linear');  % Use linear solver for field corrections
    %   finalParams = optimizer.runFullSequence();
    
    properties (Access = public)
        Config                    % Configuration structure
        CalibratorData           % Loaded calibrator data
        AbsorptionData           % Loaded absorption data
        OptimizedParams          % Accumulated optimized parameters
        Results                  % Results from each optimization stage
        ActiveSequence           % Current optimization sequence
        CurrentStage = 0         % Current stage index
        Verbose = true           % Enable verbose output
        SigmaClippingEnabled = true  % Enable sigma clipping globally
        StageMinimizers          % Minimizer type for each stage ('nonlinear' or 'linear')
    end
    
    methods
        function obj = TransmissionOptimizerAdvanced(Config, varargin)
            % Constructor for TransmissionOptimizerAdvanced
            
            if nargin == 0
                obj.Config = transmission.inputConfig();
            else
                obj.Config = Config;
            end
            
            % Parse optional arguments
            p = inputParser;
            addParameter(p, 'Verbose', true, @islogical);
            addParameter(p, 'SigmaClipping', true, @islogical);
            addParameter(p, 'Sequence', 'default', @(x) ischar(x) || isstring(x));
            parse(p, varargin{:});
            
            obj.Verbose = p.Results.Verbose;
            obj.SigmaClippingEnabled = p.Results.SigmaClipping;
            
            % Initialize optimization sequence
            switch lower(p.Results.Sequence)
                case 'default'
                    obj.ActiveSequence = obj.defineAdvancedSequence();
                case 'simple'
                    obj.ActiveSequence = obj.defineSimpleFieldCorrectionSequence();
                case 'atmospheric'
                    obj.ActiveSequence = obj.defineAtmosphericSequence();
                otherwise
                    obj.ActiveSequence = obj.defineAdvancedSequence();
            end
            
            % Initialize stage minimizers (default: nonlinear for all stages)
            numStages = length(obj.ActiveSequence);
            obj.StageMinimizers = repmat("nonlinear", 1, numStages);
            
            % Set linear minimizer for field correction stage (Stage 3) by default
            if numStages >= 3
                obj.StageMinimizers(3) = "linear";
            end
            
            % Initialize other properties
            obj.OptimizedParams = struct();
            obj.Results = {};
            
            if obj.Verbose
                fprintf('Advanced Transmission Optimizer initialized\n');
                fprintf('Optimization sequence: %s (%d stages)\n', p.Results.Sequence, numStages);
                fprintf('Default minimizers: Stage 3 = linear (field corrections), others = nonlinear\n');
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
        
        function finalParams = runFullSequence(obj)
            % Run the complete multi-stage optimization sequence
            
            if obj.Verbose
                fprintf('=== ADVANCED MULTI-STAGE OPTIMIZATION ===\n');
                fprintf('Total stages: %d\n', length(obj.ActiveSequence));
                for i = 1:length(obj.ActiveSequence)
                    fprintf('  Stage %d (%s): %s [%s]\n', i, obj.ActiveSequence(i).name, ...
                            obj.ActiveSequence(i).description, obj.StageMinimizers(i));
                end
                fprintf('\n');
            end
            
            % Load data if not already loaded
            if isempty(obj.CalibratorData)
                obj.loadCalibratorData();
            end
            if isempty(obj.AbsorptionData)
                obj.loadAbsorptionData();
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
            
            % Handle Chebyshev field corrections (for nonlinear solver)
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
                    transmission.minimizerLinearLeastSquares(ConfigForMinimizer, argCell{:});
            else
                % Use nonlinear solver
                argCell = obj.structToNameValuePairs(Args);
                [stageResult.OptimalParams, stageResult.Fval, stageResult.ExitFlag, ...
                 stageResult.Output, stageResult.ResultData] = ...
                    transmission.minimizerFminGeneric(ConfigForMinimizer, argCell{:});
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
        
        function loadCalibratorData(obj)
            % Load calibrator data from LAST catalog
            
            if obj.Verbose
                fprintf('Loading calibrator data...\n');
            end
            
            CatalogFile = obj.Config.Data.LAST_catalog_file;
            SearchRadius = obj.Config.Data.Search_radius_arcsec;
            
            [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords(...
                CatalogFile, SearchRadius);
            
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
        
        function loadAbsorptionData(obj)
            % Get absorption data from Config (already cached in memory)
            
            if obj.Verbose
                fprintf('Using cached absorption data from Config...\n');
            end
            
            obj.AbsorptionData = obj.Config.AbsorptionData;
            
            if obj.Verbose
                fprintf('Absorption data ready\n');
            end
        end
        
        function updateOptimizedParams(obj, newParams)
            % Update the accumulated optimized parameters
            
            paramFields = fieldnames(newParams);
            for i = 1:length(paramFields)
                obj.OptimizedParams.(paramFields{i}) = newParams.(paramFields{i});
            end
        end
        
        function ConfigUpdated = updateConfigWithOptimizedParams(obj, Config, OptimizedParams)
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
        
        function argCell = structToNameValuePairs(obj, Args)
            % Convert arguments structure to name-value pairs
            
            argCell = {};
            argFields = fieldnames(Args);
            for i = 1:length(argFields)
                argCell = [argCell, {argFields{i}, Args.(argFields{i})}];
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
        
        function plotResults(obj)
            % Plot optimization results across stages
            
            if isempty(obj.Results)
                warning('No results to plot');
                return;
            end
            
            figure('Name', 'Advanced Multi-Stage Optimization Results', 'Position', [100, 100, 1400, 800]);
            
            % Extract costs and stage names
            numStages = length(obj.Results);
            stageCosts = zeros(numStages, 1);
            stageNames = cell(numStages, 1);
            minimizerTypes = cell(numStages, 1);
            
            for i = 1:numStages
                stageCosts(i) = obj.Results{i}.Fval;
                stageNames{i} = obj.ActiveSequence(i).name;
                if isfield(obj.Results{i}, 'MinimizerType')
                    minimizerTypes{i} = obj.Results{i}.MinimizerType;
                else
                    minimizerTypes{i} = 'unknown';
                end
            end
            
            % Plot 1: Cost per stage
            subplot(2, 2, 1);
            bar(stageCosts);
            xlabel('Stage');
            ylabel('Final Cost');
            title('Cost Function by Stage');
            set(gca, 'XTick', 1:numStages);
            set(gca, 'XTickLabel', stageNames);
            xtickangle(45);
            grid on;
            
            % Add minimizer type annotations
            for i = 1:numStages
                text(i, stageCosts(i), sprintf('[%s]', minimizerTypes{i}), ...
                     'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
            end
            
            % Plot 2: Cost reduction over stages
            subplot(2, 2, 2);
            semilogy(stageCosts, 'o-', 'LineWidth', 2, 'MarkerSize', 8);
            xlabel('Stage');
            ylabel('Cost (log scale)');
            title('Cost Reduction Across Stages');
            grid on;
            set(gca, 'XTick', 1:numStages);
            set(gca, 'XTickLabel', stageNames);
            xtickangle(45);
            
            % Plot 3: Final residuals histogram
            subplot(2, 2, 3);
            if isfield(obj.Results{end}.ResultData, 'DiffMag')
                DiffMag = obj.Results{end}.ResultData.DiffMag;
                histogram(DiffMag, 30);
                xlabel('DiffMag (magnitudes)');
                ylabel('Count');
                title(sprintf('Final Residuals Distribution (RMS: %.4f)', std(DiffMag)));
                grid on;
            end
            
            % Plot 4: Number of calibrators per stage
            subplot(2, 2, 4);
            numCalibrators = zeros(numStages, 1);
            for i = 1:numStages
                if isfield(obj.Results{i}.ResultData, 'NumCalibrators')
                    numCalibrators(i) = obj.Results{i}.ResultData.NumCalibrators;
                else
                    numCalibrators(i) = NaN;
                end
            end
            bar(numCalibrators);
            xlabel('Stage');
            ylabel('Number of Calibrators');
            title('Calibrators Used per Stage');
            set(gca, 'XTick', 1:numStages);
            set(gca, 'XTickLabel', stageNames);
            xtickangle(45);
            grid on;
            
            sgtitle('Advanced Transmission Optimization Results', 'FontSize', 14, 'FontWeight', 'bold');
        end
    end
    
    methods (Static)
        function stages = defineAdvancedSequence()
            % Define the advanced optimization sequence with mixed minimizers
            % Stage 3 uses linear least squares for field correction parameters
            % This matches defineDefaultSequence() exactly from TransmissionOptimizer
            
            % Stage 1: Normalize only with sigma clipping
            stages(1).name = "NormOnly_Initial";
            stages(1).freeParams = "Norm_";
            stages(1).sigmaClipping = true;
            stages(1).sigmaThreshold = 3.0;
            stages(1).sigmaIterations = 3;
            stages(1).usePythonFieldModel = true;  % Use Python field correction model
            stages(1).fixedParams = struct('ky0', 0);  % Keep ky0 fixed at 0
            stages(1).description = "Initial normalization with outlier removal";
            
            % Stage 2: Norm + QE center (nonlinear)
            stages(2).name = "NormAndCenter";
            stages(2).freeParams = ["Norm_", "Center"];
            stages(2).sigmaClipping = false;
            stages(2).usePythonFieldModel = true;
            stages(2).fixedParams = struct('ky0', 0);
            stages(2).description = "Optimize normalization and QE center";
            
            % Stage 3: Field corrections (LINEAR LEAST SQUARES)
            stages(3).name = "FieldCorrection_Linear";
            stages(3).freeParams = ["kx0", "kx", "ky", "kx2", "ky2", "kx3", "ky3", "kx4", "ky4", "kxy"];
            stages(3).fixedParams = struct('ky0', 0);  % ky0 = 0 and fixed
            stages(3).usePythonFieldModel = true;
            stages(3).sigmaClipping = true;
            stages(3).sigmaThreshold = 2.0;
            stages(3).sigmaIterations = 3;
            stages(3).regularization = 1e-6;  % Small regularization for stability
            stages(3).description = "Linear least squares field correction optimization";
            
            % Stage 4: Norm refinement (nonlinear)
            stages(4).name = "NormRefinement";
            stages(4).freeParams = "Norm_";
            stages(4).sigmaClipping = false;
            stages(4).usePythonFieldModel = true;
            stages(4).fixedParams = struct('ky0', 0);
            stages(4).description = "Refine normalization after field corrections";
            
            % Stage 5: Atmospheric parameters (nonlinear)
            stages(5).name = "Atmospheric";
            stages(5).freeParams = ["Pwv_cm", "Tau_aod500"];
            stages(5).usePythonFieldModel = true;
            stages(5).sigmaClipping = false;
            stages(5).fixedParams = struct('ky0', 0);
            stages(5).description = "Optimize water vapor and aerosol parameters";
        end
        
        function stages = defineSimpleFieldCorrectionSequence()
            % Define simple field correction sequence (for comparison)
            
            % Stage 1: Initial normalization
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
            
            % Stage 3: Simple Chebyshev field corrections (LINEAR)
            stages(3).name = "FieldCorrection_Simple_Linear";
            stages(3).freeParams = ["cx0", "cx1", "cy0", "cy1"];  % Simple field correction
            stages(3).useChebyshev = true;
            stages(3).chebyshevOrder = 4;
            stages(3).sigmaClipping = true;
            stages(3).sigmaThreshold = 2.0;
            stages(3).regularization = 1e-6;
            stages(3).description = "Linear simple Chebyshev field correction coefficients";
            
            % Stage 4: Norm refinement
            stages(4).name = "NormRefinement";
            stages(4).freeParams = "Norm_";
            stages(4).sigmaClipping = false;
            stages(4).description = "Refine normalization after field corrections";
        end
        
        function stages = defineAtmosphericSequence()
            % Define atmospheric sequence using stages 1, 2, 3, 5 from default sequence
            
            % Stage 1: Normalize only with sigma clipping (from default stage 1)
            stages(1).name = "NormOnly_Initial";
            stages(1).freeParams = "Norm_";
            stages(1).sigmaClipping = true;
            stages(1).sigmaThreshold = 3.0;
            stages(1).sigmaIterations = 3;
            stages(1).usePythonFieldModel = true;
            stages(1).fixedParams = struct('ky0', 0);
            stages(1).description = "Initial normalization with outlier removal";
            
            % Stage 2: Norm + QE center (from default stage 2)
            stages(2).name = "NormAndCenter";
            stages(2).freeParams = ["Norm_", "Center"];
            stages(2).sigmaClipping = false;
            stages(2).usePythonFieldModel = true;
            stages(2).fixedParams = struct('ky0', 0);
            stages(2).description = "Optimize normalization and QE center";
            
            % Stage 3: Field corrections (from default stage 3) - LINEAR LEAST SQUARES
            stages(3).name = "FieldCorrection_Linear";
            stages(3).freeParams = ["kx0", "kx", "ky", "kx2", "ky2", "kx3", "ky3", "kx4", "ky4", "kxy"];
            stages(3).fixedParams = struct('ky0', 0);  % ky0 = 0 and fixed
            stages(3).usePythonFieldModel = true;
            stages(3).sigmaClipping = true;
            stages(3).sigmaThreshold = 2.0;
            stages(3).sigmaIterations = 3;
            stages(3).regularization = 1e-6;  % Small regularization for stability
            stages(3).description = "Linear least squares field correction optimization";
            
            % Stage 4: Atmospheric parameters (from default stage 5)
            stages(4).name = "Atmospheric";
            stages(4).freeParams = ["Pwv_cm", "Tau_aod500"];
            stages(4).usePythonFieldModel = true;
            stages(4).sigmaClipping = false;
            stages(4).fixedParams = struct('ky0', 0);
            stages(4).description = "Optimize water vapor and aerosol parameters";
        end
    end
end