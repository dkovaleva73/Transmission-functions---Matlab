function parameterSweep_TauAOD_optimized()
    % Optimized parameter sweep script for Tau_aod500 parameter
    % Runs calibrator selection once, then varies Tau_aod500 from 0.05 to 0.15 with step 0.01
    % and plots RelDiffFluxMean vs Tau_aod500
    % Author: D. Kovaleva
    % Date: Aug 2025
    
    fprintf('=== OPTIMIZED PARAMETER SWEEP: Tau_aod500 ===\n');
    fprintf('Range: 0.05 to 0.15, Step: 0.01\n');
    fprintf('Running calibrator selection once, then varying transmission only...\n\n');
    
    % Define parameter range
    tau_values = 0.05:0.01:0.15;
    n_values = length(tau_values);
    
    % Pre-allocate results
    relDiffFluxMean_values = zeros(n_values, 1);
    
    try
        % STEP 1: Run calibrator selection once with default config
        fprintf('Step 1: Finding calibrators and extracting spectra...\n');
        Config = transmission.inputConfig();
        
        [Spec, Mag, Coords, LASTData, Metadata] = transmission.data.findCalibratorsWithCoords(...
            Config.Data.LAST_catalog_file, Config.Data.Search_radius_arcsec);
        
        fprintf('Found %d calibrators\n\n', length(Spec));
        
        if isempty(Spec)
            error('No calibrators found. Check catalog file and search parameters.');
        end
        
        % STEP 2: Parameter sweep loop - vary only transmission
        fprintf('Step 2: Parameter sweep over Tau_aod500...\n');
        
        for i = 1:n_values
            current_tau = tau_values(i);
            fprintf('Iteration %d/%d: Tau_aod500 = %.3f... ', i, n_values, current_tau);
            
            try
                % Update aerosol optical depth in config
                Config.Atmospheric.Components.Aerosol.Tau_aod500 = current_tau;
                
                % Apply transmission to calibrator spectra
                [SpecTrans, Wavelength, TransFunc] = transmission.calibrators.applyTransmissionToCalibrators(...
                    Spec, Metadata, Config);
                
                % Convert cell array to double array if needed
                if iscell(SpecTrans)
                    TransmittedFluxArray = cell2mat(cellfun(@(x) x(:)', SpecTrans(:,1), 'UniformOutput', false));
                else
                    TransmittedFluxArray = SpecTrans;
                end
                
                % Calculate total flux in photons
                TotalFlux = transmission.calibrators.calculateTotalFluxCalibrators(...
                    Wavelength, TransmittedFluxArray, Metadata);
                
                % Calculate RelDiffFlux = (TotalFlux - FLUX_APER_3)/FLUX_APER_3
                RelDiffFlux = (TotalFlux - LASTData.FLUX_APER_3) ./ LASTData.FLUX_APER_3;
                RelDiffFluxMean = mean(RelDiffFlux);
                
                % Store result
                relDiffFluxMean_values(i) = RelDiffFluxMean;
                
                fprintf('RelDiffFluxMean = %.4f\n', RelDiffFluxMean);
                
            catch ME
                fprintf('ERROR: %s\n', ME.message);
                relDiffFluxMean_values(i) = NaN;
            end
        end
        
    catch ME
        fprintf('FATAL ERROR in calibrator selection: %s\n', ME.message);
        return;
    end
    
    % Create figure
    figure('Name', 'Optimized Parameter Sweep: Tau_aod500', 'Position', [300, 100, 800, 600]);
    
    % Plot results
    plot(tau_values, relDiffFluxMean_values, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
         'MarkerFaceColor', 'red', 'MarkerEdgeColor', 'black');
    
    % Find and mark point closest to RelDiffFluxMean = 0
    [~, closest_idx] = min(abs(relDiffFluxMean_values));
    closest_tau = tau_values(closest_idx);
    closest_value = relDiffFluxMean_values(closest_idx);
    
    % Mark the closest point with a different color/size
    hold on;
    plot(closest_tau, closest_value, 'o', 'MarkerSize', 12, ...
         'MarkerFaceColor', 'green', 'MarkerEdgeColor', 'black', 'LineWidth', 2);
    
    % Add text annotation for the closest point
    text(closest_tau + 0.003, closest_value, ...
         sprintf('Tau = %.3f\nRelDiff = %.4f', closest_tau, closest_value), ...
         'FontSize', 10, 'BackgroundColor', 'yellow', 'EdgeColor', 'black');
    
    % Add horizontal line at y=0
    plot(xlim, [0 0], 'k--', 'LineWidth', 1);
    hold off;
    
    xlabel('Tau_{aod500}', 'FontSize', 12);
    ylabel('Cost function', 'FontSize', 12);
    title('RelDiffFluxMean vs Tau_{aod500} (Optimized)', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    % Format axes
    xlim([min(tau_values) - 0.005, max(tau_values) + 0.005]);
    set(gca, 'FontSize', 11);
    
    % Display results summary
    fprintf('\n=== PARAMETER SWEEP COMPLETE ===\n');
    fprintf('Total iterations: %d\n', n_values);
    fprintf('Successful runs: %d\n', sum(~isnan(relDiffFluxMean_values)));
    fprintf('Failed runs: %d\n', sum(isnan(relDiffFluxMean_values)));
    fprintf('Number of calibrators: %d\n', length(Spec));
    
    if ~all(isnan(relDiffFluxMean_values))
        fprintf('\nRelDiffFluxMean statistics:\n');
        [min_val, min_idx] = min(relDiffFluxMean_values);
        [max_val, max_idx] = max(relDiffFluxMean_values);
        [~, closest_idx] = min(abs(relDiffFluxMean_values));
        fprintf('  Min: %.4f (at Tau_aod500 = %.3f)\n', min_val, tau_values(min_idx));
        fprintf('  Max: %.4f (at Tau_aod500 = %.3f)\n', max_val, tau_values(max_idx));
        fprintf('  Mean: %.4f\n', mean_val);
        fprintf('  Range: %.4f\n', max_val - min_val);
        fprintf('  Closest to 0: %.4f (at Tau_aod500 = %.3f)\n', ...
                relDiffFluxMean_values(closest_idx), tau_values(closest_idx));
    end
    
    % Save results
    results = struct();
    results.tau_values = tau_values;
    results.relDiffFluxMean_values = relDiffFluxMean_values;
    results.num_calibrators = length(Spec);
    results.config_used = Config;
    results.timestamp = datetime('now');
    
    save('parameterSweep_TauAOD_optimized_results.mat', 'results');
    fprintf('\nResults saved to: parameterSweep_TauAOD_optimized_results.mat\n');
    
    fprintf('Optimized parameter sweep completed!\n');
end