function CatalogAB_all = AbsolutePhotometryAstroImage(OptimizedParams, Config, Args)
    % Calculate absolute photometry for all 24 subimages in an AstroImage
    % Processes each subimage individually using calculateAbsolutePhotometry
    % Input : - OptimizedParams - Either:
    %             1) Structure with optimized parameters (same for all fields)
    %             2) {24x1} cell array of structures from optimizeAllFieldsAI (field-specific)
    %         - Config - Transmission configuration (default: inputConfig())
    %         - Args - Optional arguments:
    %           'AstroImageFile' - Path to LAST AstroImage file (default: from Config)
    %           'Verbose' - Enable verbose output (default: true)
    %           'SaveResults' - Save results to files (default: false)
    %           'OutputDir' - Directory for saving results (default: current directory)
    % Output : - CatalogAB_all - Cell array {24x1} containing MATLAB tables with:
    %           - All original LAST catalog columns for each subimage
    %           - 'MAG_ZP' - Zero-point magnitude for each star (position-dependent)
    %           - 'MAG_PSF_AB' - AB absolute magnitude for each star  
    %           - 'FIELD_CORRECTION_MAG' - Field correction applied
    % Author: D. Kovaleva (Sep 2025)
    % Example:
    %   % Method 1: Single parameters for all fields
    %   Config = transmissionFast.inputConfig();
    %   optimizer = transmissionFast.TransmissionOptimizerAdvanced(Config);
    %   finalParams = optimizer.runFullSequence(1);
    %   CatalogAB_all = transmissionFast.AbsolutePhotometryAstroImage(finalParams, Config);
    %
    %   % Method 2: Field-specific parameters from optimizeAllFieldsAI
    %   [params_all, ~, ~] = transmissionFast.optimizeAllFieldsAI('Nfields', 24);
    %   CatalogAB_all = transmissionFast.AbsolutePhotometryAstroImage(params_all, Config);
    
    arguments
        OptimizedParams  % Can be struct or {24x1} cell array of structs
        Config = transmissionFast.inputConfig()
        Args.AstroImageFile = []
        Args.Verbose logical = true
        Args.SaveResults logical = false
        Args.OutputDir string = ""
    end
    
    % Handle different input formats for OptimizedParams
    if iscell(OptimizedParams)
        % Cell array from optimizeAllFieldsAI - use field-specific parameters
        if length(OptimizedParams) ~= 24
            error('OptimizedParams cell array must have 24 elements (one per field)');
        end
        use_field_specific = true;
    elseif isstruct(OptimizedParams)
        % Single structure - use same parameters for all fields
        use_field_specific = false;
    else
        error('OptimizedParams must be a structure or 24x1 cell array of structures');
    end
    
    % Initialize output cell array
    CatalogAB_all = cell(24, 1);
    
    % Determine AstroImage file to use
    if isempty(Args.AstroImageFile)
        AstroImageFile = Config.Data.LAST_AstroImage_file;
    else
        AstroImageFile = Args.AstroImageFile;
    end
    
    if Args.Verbose
        fprintf('=== PROCESSING ABSOLUTE PHOTOMETRY FOR ALL 24 SUBIMAGES ===\n');
        fprintf('AstroImage file: %s\n', AstroImageFile);
        fprintf('Starting at: %s\n\n', string(datetime('now')));
    end
    
    % Create output directory if saving results
    if Args.SaveResults && Args.OutputDir ~= ""
        if ~exist(Args.OutputDir, 'dir')
            mkdir(Args.OutputDir);
        end
    end
    
    % Process statistics
    success_count = 0;
    total_stars = 0;
    processing_times = zeros(24, 1);
    
    % Process each subimage (1-24)
    for imageNum = 1:24
        if Args.Verbose
            fprintf('Processing subimage %d/24... ', imageNum);
        end
        
        tic_image = tic;
        
        try
            % Select appropriate parameters for this field
            if use_field_specific
                % Use field-specific parameters from cell array
                if isempty(OptimizedParams{imageNum})
                    % Skip if no parameters for this field
                    if Args.Verbose
                        fprintf('No parameters for field %d, skipping\n', imageNum);
                    end
                    continue;
                end
                currentParams = OptimizedParams{imageNum};
            else
                % Use same parameters for all fields
                currentParams = OptimizedParams;
            end
            
            % Calculate absolute photometry for this subimage
            CatalogAB = transmissionFast.calculateAbsolutePhotometry(...
                currentParams, Config, ...
                'AstroImageFile', AstroImageFile, ...
                'ImageNum', imageNum, ...
                'Verbose', false, ...  % Disable verbose for individual calls
                'SaveResults', false);  % Handle saving at this level
            
            % Store result
            CatalogAB_all{imageNum} = CatalogAB;
            
            % Update statistics
            success_count = success_count + 1;
            num_stars = height(CatalogAB);
            total_stars = total_stars + num_stars;
            processing_times(imageNum) = toc(tic_image);
            
            if Args.Verbose
                fprintf('%d stars, %.2f s\n', num_stars, processing_times(imageNum));
            end
            
            % Save individual catalog if requested
            if Args.SaveResults
                if Args.OutputDir ~= ""
                    output_file = fullfile(Args.OutputDir, sprintf('subimage_%02d_catalog_AB.csv', imageNum));
                else
                    output_file = sprintf('subimage_%02d_catalog_AB.csv', imageNum);
                end
                writetable(CatalogAB, output_file);
                
                if Args.Verbose && imageNum == 1
                    fprintf('  Saving catalogs to: %s\n', output_file);
                end
            end
            
        catch ME
            % Handle errors gracefully
            CatalogAB_all{imageNum} = [];
            processing_times(imageNum) = toc(tic_image);
            
            if Args.Verbose
                fprintf('ERROR: %s\n', ME.message);
            else
                warning('Failed to process subimage %d: %s', imageNum, ME.message);
            end
        end
    end
    
    % Summary statistics
    if Args.Verbose
        fprintf('\n=== PROCESSING SUMMARY ===\n');
        fprintf('Successfully processed: %d/24 subimages\n', success_count);
        fprintf('Total stars processed: %d\n', total_stars);
        fprintf('Total processing time: %.2f minutes\n', sum(processing_times)/60);
        fprintf('Average time per subimage: %.2f seconds\n', mean(processing_times(processing_times > 0)));
        
        if success_count > 0
            fprintf('Average stars per subimage: %.1f\n', total_stars/success_count);
        end
        
        fprintf('Completed at: %s\n', string(datetime('now')));
    end
    
    % Save summary if requested
    if Args.SaveResults
        % Create summary table
        ImageNum = (1:24)';
        Success = ~cellfun(@isempty, CatalogAB_all);
        NumStars = zeros(24, 1);
        
        for i = 1:24
            if Success(i)
                NumStars(i) = height(CatalogAB_all{i});
            end
        end
        
        ProcessingTime_seconds = processing_times;
        
        summary_table = table(ImageNum, Success, NumStars, ProcessingTime_seconds);
        
        if Args.OutputDir ~= ""
            summary_file = fullfile(Args.OutputDir, 'absolute_photometry_summary.csv');
            mat_file = fullfile(Args.OutputDir, 'absolute_photometry_all.mat');
        else
            summary_file = 'absolute_photometry_summary.csv';
            mat_file = 'absolute_photometry_all.mat';
        end
        
        writetable(summary_table, summary_file);
        save(mat_file, 'CatalogAB_all', 'OptimizedParams', 'summary_table', '-v7.3');
        
        if Args.Verbose
            fprintf('\nSummary saved to: %s\n', summary_file);
            fprintf('MAT file saved to: %s\n', mat_file);
        end
    end
    
    if Args.Verbose
        fprintf('\n🎯 ABSOLUTE PHOTOMETRY COMPLETE for all 24 subimages!\n');
        if success_count == 24
            fprintf('✅ All subimages processed successfully\n');
        elseif success_count > 20
            fprintf('✅ Most subimages processed successfully (%d/24)\n', success_count);
        else
            fprintf('⚠️  Some subimages failed (%d/24 successful)\n', success_count);
        end
    end
end