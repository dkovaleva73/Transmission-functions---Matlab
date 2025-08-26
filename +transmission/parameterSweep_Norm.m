function parameterSweep_Norm()
    % Parameter sweep script for Norm_ parameter
    % Varies Norm_ from 0.2 to 0.8 with step 0.05 and plots RelDiffFluxMean vs Norm_
    % Author: D. Kovaleva
    % Date: Aug 2025
    
    fprintf('=== PARAMETER SWEEP: Norm_ ===\n');
    fprintf('Range: 0.2 to 0.8, Step: 0.05\n\n');
    
    % Define parameter range
    norm_values = 0.2:0.05:0.8;
    n_values = length(norm_values);
    
    % Pre-allocate results
    relDiffFluxMean_values = zeros(n_values, 1);
    
    % Store original configuration file content for restoration
    configFile = '/home/dana/matlab_projects/+transmission/inputConfig.m';
    
    % Main loop
    for i = 1:n_values
        current_norm = norm_values(i);
        fprintf('Running iteration %d/%d: Norm_ = %.2f\n', i, n_values, current_norm);
        
        try
            % Modify inputConfig.m file
            updateNormValue(configFile, current_norm);
            
            % Clear functions to ensure config is reloaded
            clear functions;
            
            % Get configuration and run costFunction
            Config = transmission.inputConfig();
            [~, ~, ~, ~, ~, RelDiffFlux] = transmission.costFunction(Config, 'Verbose', false);
            
            % Calculate and store RelDiffFluxMean
            relDiffFluxMean_values(i) = mean(RelDiffFlux);
            
            fprintf('  RelDiffFluxMean = %.4f\n\n', relDiffFluxMean_values(i));
            
        catch ME
            fprintf('  ERROR: %s\n', ME.message);
            relDiffFluxMean_values(i) = NaN;
        end
    end
    
    % Create figure
    figure('Name', 'Parameter Sweep: Norm_', 'Position', [100, 100, 800, 600]);
    
    % Plot results
    plot(norm_values, relDiffFluxMean_values, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
         'MarkerFaceColor', 'blue', 'MarkerEdgeColor', 'black');
    
    xlabel('Norm\_', 'FontSize', 12);
    ylabel('RelDiffFluxMean', 'FontSize', 12);
    title('RelDiffFluxMean vs Norm\_', 'FontSize', 14, 'FontWeight', 'bold');
    grid on;
    
    % Add text with statistics
    if ~all(isnan(relDiffFluxMean_values))
        valid_values = relDiffFluxMean_values(~isnan(relDiffFluxMean_values));
        min_val = min(valid_values);
        max_val = max(valid_values);
        mean_val = mean(valid_values);
        
        text_str = sprintf('Min: %.4f\nMax: %.4f\nMean: %.4f', min_val, max_val, mean_val);
        text(0.02, 0.98, text_str, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
             'BackgroundColor', 'white', 'EdgeColor', 'black', 'FontSize', 10);
    end
    
    % Format axes
    xlim([min(norm_values) - 0.02, max(norm_values) + 0.02]);
    set(gca, 'FontSize', 11);
    
    % Display results summary
    fprintf('=== PARAMETER SWEEP COMPLETE ===\n');
    fprintf('Total iterations: %d\n', n_values);
    fprintf('Successful runs: %d\n', sum(~isnan(relDiffFluxMean_values)));
    fprintf('Failed runs: %d\n', sum(isnan(relDiffFluxMean_values)));
    
    if ~all(isnan(relDiffFluxMean_values))
        fprintf('\nRelDiffFluxMean statistics:\n');
        fprintf('  Min: %.4f (at Norm_ = %.2f)\n', min_val, norm_values(relDiffFluxMean_values == min_val));
        fprintf('  Max: %.4f (at Norm_ = %.2f)\n', max_val, norm_values(relDiffFluxMean_values == max_val));
        fprintf('  Mean: %.4f\n', mean_val);
    end
    
    % Save results
    results = struct();
    results.norm_values = norm_values;
    results.relDiffFluxMean_values = relDiffFluxMean_values;
    results.timestamp = datetime('now');
    
    save('parameterSweep_Norm_results.mat', 'results');
    fprintf('\nResults saved to: parameterSweep_Norm_results.mat\n');
    
    fprintf('Parameter sweep completed!\n');
end

function updateNormValue(configFile, newNorm)
    % Update Norm_ value in inputConfig.m file
    
    % Read the file
    fid = fopen(configFile, 'r');
    if fid == -1
        error('Could not open file: %s', configFile);
    end
    
    content = fread(fid, '*char')';
    fclose(fid);
    
    % Find and replace the Norm_ value
    % Pattern matches: 'Norm_', 0.5 ...
    pattern = '''Norm_'',\s*[\d\.]+';
    replacement = sprintf('''Norm_'', %.2f', newNorm);
    
    newContent = regexprep(content, pattern, replacement);
    
    % Write back to file
    fid = fopen(configFile, 'w');
    if fid == -1
        error('Could not write to file: %s', configFile);
    end
    
    fwrite(fid, newContent, 'char');
    fclose(fid);
end