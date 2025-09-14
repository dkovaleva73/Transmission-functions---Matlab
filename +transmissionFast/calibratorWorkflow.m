function [totalFlux, SpecTrans, Wavelength, Metadata, Results] = calibratorWorkflow(Config, Args)
    % Complete calibrator processing workflow for transmission calculations
    % Performs the full pipeline: LAST catalog → Gaia cross-matching → transmission → flux calculation
    % Input :  - Config - (optional) Configuration structure from transmissionFast.inputConfig()
    %            If empty, uses default configuration
    %          * ...,key,val,...
    %            'CatalogFile' - Override LAST catalog file path
    %            'SearchRadius' - Override search radius (arcsec)
    %            'PlotResults' - Display summary plots (default: false)
    %            'Verbose' - Enable verbose output (default: true)
    %            'SaveResults' - Save results to file (default: false)
    %            'OutputDir' - Directory for saved results (default: current dir)
    % Output :  - totalFlux - Array of total flux in photons for each calibrator
    %           - SpecTrans - Cell array of transmitted spectra
    %           - Wavelength - Wavelength array (nm)
    %           - Metadata - LAST observation metadata structure
    %           - Results - Complete results structure with all intermediate data
    % Reference: Garrappa et al. 2025, A&A 699, A50.
    % Author: D. Kovaleva
    % Date: Aug 2025
    % Examples: 
    %   % Basic usage with defaults
    %   totalFlux = transmissionFast.calibratorWorkflow();
    %   % With custom configuration
    %   Config = transmissionFast.inputConfig('photometric_night');
    %   [totalFlux, SpecTrans, Wavelength] = transmissionFast.calibratorWorkflow(Config);
    %   % With plotting and verbose output
    %   totalFlux = transmissionFast.calibratorWorkflow([], 'PlotResults', true, 'Verbose', true);
    %   % Override catalog file
    %   totalFlux = transmissionFast.calibratorWorkflow([], 'CatalogFile', '/path/to/custom_catalog.fits');
   
    arguments
        Config = transmissionFast.inputConfig()
        Args.CatalogFile {mustBeTextScalar} = Config.Data.LAST_catalog_file
        Args.SearchRadius {mustBeNumeric, mustBePositive} = Config.Data.Search_radius_arcsec
        Args.PlotResults logical = false
        Args.Verbose logical = true
        Args.SaveResults logical = false
        Args.OutputDir {mustBeTextScalar} = "."
    end
    
    % Extract parameters from Args
    catalogFile = Args.CatalogFile;
    searchRadius = Args.SearchRadius;
    plotResults = Args.PlotResults;
    verbose = Args.Verbose;
    saveResults = Args.SaveResults;
    outputDir = Args.OutputDir;
    
    if verbose
        fprintf('=== TRANSMISSION CALIBRATOR WORKFLOW ===\n');
        fprintf('Catalog file: %s\n', catalogFile);
        fprintf('Search radius: %.1f arcsec\n', searchRadius);
        fprintf('Configuration scenario: default\n');
        fprintf('\n');
    end
    
    try
        % STEP 1: Find calibrators with coordinates
        if verbose
            fprintf('Step 1: Finding Gaia calibrators around LAST sources...\n');
            tic;
        end
        
        [Spec, Mag, Coords, LASTData, Metadata] = transmissionFast.data.findCalibratorsWithCoords(catalogFile, searchRadius);
        
        if verbose
            elapsed1 = toc;
            fprintf('  Found %d calibrator spectra\n', length(Spec));
            fprintf('  Magnitude range: %.2f - %.2f\n', min(Mag), max(Mag));
            fprintf('  Time elapsed: %.2f seconds\n\n', elapsed1);
        end
        
        % Check if any calibrators were found
        if isempty(Spec)
            warning('No calibrators found. Check catalog file and search parameters.');
            totalFlux = [];
            SpecTrans = {};
            Wavelength = [];
            Results = struct();
            return;
        end
        
        % STEP 2: Apply transmission to calibrator spectra
        if verbose
            fprintf('Step 2: Applying atmospheric and instrumental transmissionFast...\n');
            tic;
        end
        
        [SpecTrans, Wavelength, TransFunc] = transmissionFast.calibrators.applyTransmissionToCalibrators(Spec, Metadata, Config);
        
        if verbose
            elapsed2 = toc;
            fprintf('  Extended spectra from %d-%d nm to %d-%d nm\n', ...
                min(Config.Utils.Gaia_wavelength), max(Config.Utils.Gaia_wavelength), ...
                min(Wavelength), max(Wavelength));
            fprintf('  Mean transmission: %.3f\n', mean(TransFunc));
            fprintf('  Time elapsed: %.2f seconds\n\n', elapsed2);
        end
        
        % STEP 3: Calculate total flux in photons
        if verbose
            fprintf('Step 3: Calculating total flux in photons...\n');
            tic;
        end
        
        % Convert cell array to double array (extract flux values only, column 1)
        if iscell(SpecTrans)
            TransmittedFluxArray = cell2mat(cellfun(@(x) x(:)', SpecTrans(:,1), 'UniformOutput', false));
        else
            TransmittedFluxArray = SpecTrans;
        end
        
        totalFlux = transmissionFast.calibrators.calculateTotalFluxCalibrators(Wavelength, TransmittedFluxArray, Metadata);
        
        if verbose
            elapsed3 = toc;
            fprintf('  Calculated flux for %d calibrators\n', length(totalFlux));
            fprintf('  Flux range: %.2e - %.2e photons\n', min(totalFlux), max(totalFlux));
            fprintf('  Mean flux: %.2e photons\n', mean(totalFlux));
            fprintf('  Time elapsed: %.2f seconds\n\n', elapsed3);
        end
        
        % STEP 4: Create comprehensive results structure
        Results = struct();
        Results.Summary = struct(...
            'NumCalibrators', length(totalFlux), ...
            'MagnitudeRange', [min(Mag), max(Mag)], ...
            'FluxRange', [min(totalFlux), max(totalFlux)], ...
            'MeanFlux', mean(totalFlux), ...
            'MedianFlux', median(totalFlux), ...
            'StdFlux', std(totalFlux), ...
            'MeanTransmission', mean(TransFunc) ...
        );
        
        Results.Data = struct(...
            'TotalFlux', totalFlux, ...
            'Magnitudes', Mag, ...
            'Coordinates', Coords, ...
            'LASTData', LASTData, ...
            'TransmittedSpectra', {SpecTrans}, ...
            'Wavelength', Wavelength, ...
            'TransmissionFunction', TransFunc ...
        );
        
        Results.Metadata = Metadata;
        Results.Config = Config;
        Results.ProcessingInfo = struct(...
            'CatalogFile', catalogFile, ...
            'SearchRadius', searchRadius, ...
            'ProcessingDate', datetime('now'), ...
            'MATLABVersion', version ...
        );
        
        % STEP 5: Display summary
        if verbose
            fprintf('=== WORKFLOW COMPLETE ===\n');
            fprintf('Summary:\n');
            fprintf('  Total calibrators processed: %d\n', Results.Summary.NumCalibrators);
            fprintf('  Magnitude range: %.2f - %.2f mag\n', Results.Summary.MagnitudeRange);
     %       fprintf('  Flux statistics:\n');
     %       fprintf('    Mean: %.2e photons\n', Results.Summary.MeanFlux);
     %       fprintf('    Median: %.2e photons\n', Results.Summary.MedianFlux);
     %       fprintf('    Std dev: %.2e photons\n', Results.Summary.StdFlux);
     %       fprintf('  Mean transmission: %.1f%%\n', Results.Summary.MeanTransmission * 100);
            fprintf('\n');
        end
        
        % STEP 6: Generate plots if requested
        if plotResults
            if verbose
                fprintf('Step 6: Generating summary plots...\n');
            end
            generateSummaryPlots(Results, Wavelength, TransFunc);
        end
        
        % STEP 7: Save results if requested
        if saveResults
            if verbose
                fprintf('Step 7: Saving results...\n');
            end
            saveWorkflowResults(Results, outputDir, verbose);
        end
        
        if verbose
            fprintf('Calibrator workflow completed successfully!\n');
        end
        
    catch ME
        fprintf('ERROR in calibrator workflow:\n');
        fprintf('  %s\n', ME.message);
        fprintf('  Location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        rethrow(ME);
    end
end

function generateSummaryPlots(Results, Wavelength, TransFunc)
    % Generate summary plots for calibrator workflow results
    
    figure('Name', 'Calibrator Workflow Results', 'Position', [100, 100, 1200, 800]);
    
    % Plot 1: Flux distribution
    subplot(2, 3, 1);
    histogram(Results.Data.TotalFlux, 'EdgeColor', 'k', 'FaceAlpha', 0.7);
    xlabel('Total Flux (photons)');
    ylabel('Number of Calibrators');
    title('Flux Distribution');
    grid on;
    
    % Plot 2: Flux vs Magnitude
    subplot(2, 3, 2);
    loglog(Results.Data.TotalFlux, Results.Data.Magnitudes, 'o', 'MarkerSize', 6, 'MarkerFaceColor', 'blue', 'MarkerEdgeColor', 'k');
    xlabel('Total Flux (photons)');
    ylabel('LAST PSF Magnitude');
    title('Flux vs Magnitude');
    grid on;
    set(gca, 'YDir', 'reverse'); % Flip Y-axis for magnitudes
    
    % Plot 3: Transmission function
    subplot(2, 3, 3);
    plot(Wavelength, TransFunc * 100, 'LineWidth', 2);
    xlabel('Wavelength (nm)');
    ylabel('Transmission (%)');
    title('System Transmission');
    grid on;
    xlim([min(Wavelength), max(Wavelength)]);
    
    % Plot 4: Spatial distribution of calibrators
    subplot(2, 3, 4);
    if ~isempty(Results.Data.Coordinates)
        ra_vals = [Results.Data.Coordinates.LAST_RA];
        dec_vals = [Results.Data.Coordinates.LAST_Dec];
        scatter(ra_vals, dec_vals, 50, Results.Data.TotalFlux, 'filled');
        xlabel('RA (degrees)');
        ylabel('Dec (degrees)');
        title('Calibrator Spatial Distribution');
        colorbar;
        colormap('viridis');
        grid on;
        axis equal;
    else
        text(0.5, 0.5, 'No coordinate data available', 'HorizontalAlignment', 'center');
        title('Calibrator Spatial Distribution');
    end
    
    % Plot 5: Sample transmitted spectra
    subplot(2, 3, 5);
    nSamples = min(5, length(Results.Data.TransmittedSpectra));
    colors = lines(nSamples);
    for i = 1:nSamples
        semilogy(Wavelength, Results.Data.TransmittedSpectra{i, 1}, 'Color', colors(i, :), 'LineWidth', 1.5);
        hold on;
    end
    xlabel('Wavelength (nm)');
    ylabel('Transmitted Flux');
    title(sprintf('Sample Transmitted Spectra (first %d)', nSamples));
    grid on;
    legend(cellstr(num2str((1:nSamples)', 'Calibrator %d')), 'Location', 'best');
    
    % Plot 6: Summary statistics
    subplot(2, 3, 6);
    stats = [Results.Summary.MeanFlux, Results.Summary.MedianFlux, Results.Summary.StdFlux];
    statNames = {'Mean', 'Median', 'Std Dev'};
    bar(stats, 'FaceColor', [0.2, 0.6, 0.8], 'EdgeColor', 'k');
    set(gca, 'XTickLabel', statNames, 'YScale', 'log');
    ylabel('Flux (photons)');
    title('Flux Statistics');
    grid on;
    
    sgtitle(sprintf('Calibrator Workflow Results (%d sources)', Results.Summary.NumCalibrators), ...
        'FontSize', 14, 'FontWeight', 'bold');
end

function saveWorkflowResults(Results, outputDir, verbose)
    % Save workflow results to files
    
    % Create output directory if it doesn't exist
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    % Generate timestamp for filenames
    timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    
    % Save complete results structure
    resultsFile = fullfile(outputDir, sprintf('calibrator_workflow_results_%s.mat', timestamp));
    save(resultsFile, 'Results', '-v7.3');
    
    % Save summary as CSV
    summaryFile = fullfile(outputDir, sprintf('calibrator_summary_%s.csv', timestamp));
    summaryTable = table(...
        (1:Results.Summary.NumCalibrators)', ...
        Results.Data.TotalFlux, ...
        Results.Data.Magnitudes, ...
        'VariableNames', {'CalibratorID', 'TotalFlux_photons', 'LAST_PSF_Magnitude'});
    writetable(summaryTable, summaryFile);
    
    % Save transmission function
    transFile = fullfile(outputDir, sprintf('transmission_function_%s.csv', timestamp));
    transTable = table(Results.Data.Wavelength, Results.Data.TransmissionFunction, ...
        'VariableNames', {'Wavelength_nm', 'Transmission'});
    writetable(transTable, transFile);
    
    if verbose
        fprintf('  Results saved to:\n');
        fprintf('    Complete results: %s\n', resultsFile);
        fprintf('    Summary CSV: %s\n', summaryFile);
        fprintf('    Transmission: %s\n', transFile);
    end
end