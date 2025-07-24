function water_transmission_comparison_tool()
    % Water vapor transmittance comparison tool: Python vs MATLAB
    % Compares Python WaterTransmittance class with MATLAB waterTransmissionOptimizedVectorized
    
    fprintf('PYTHON vs MATLAB WATER VAPOR TRANSMITTANCE COMPARISON TOOL\n');
    fprintf('==========================================================\n\n');
    
    % Check if Python results are available
    python_results_file = 'python_water_results.mat';
    if ~exist(python_results_file, 'file')
        fprintf('⚠️  Python results not found. Please run the Python analysis first:\n');
        fprintf('   python python_water_analysis.py\n\n');
        fprintf('Proceeding with MATLAB-only analysis...\n\n');
        run_matlab_only_analysis();
        return;
    end
    
    % Load Python results and run full comparison
    python_data = load(python_results_file);
    fprintf('✅ Python results loaded successfully\n\n');
    run_full_comparison(python_data);
end

function run_matlab_only_analysis()
    % Run MATLAB water transmission analysis only
    
    fprintf('=== MATLAB WATER TRANSMISSION ANALYSIS ===\n\n');
    
    % Test parameters - varying water vapor amounts
    Z_test = 30.0;        % zenith angle
    Tair_test = 15.0;     % air temperature (°C)  
    P_test = 1013.25;     % pressure (hPa)
    
    % Test different precipitable water values
    Pw_values = [0.5, 1.0, 2.0, 4.0, 6.0];  % cm
    
    Lam = transmission.utils.makeWavelengthArray();
    fprintf('Test conditions:\n');
    fprintf('  Zenith angle: %.1f degrees\n', Z_test);
    fprintf('  Temperature: %.1f°C\n', Tair_test);
    fprintf('  Pressure: %.1f hPa\n', P_test);
    fprintf('  Wavelengths: %d points [%.0f-%.0f nm]\n', ...
            length(Lam), min(Lam), max(Lam));
    fprintf('  Water vapor amounts: %s cm\n\n', mat2str(Pw_values));
    
    % Load water vapor absorption data
    H2O_data = transmission.data.loadAbsorptionDataMemoryOptimized([], {'H2O'}, false);
    
    fprintf('%-8s | %-15s | %-10s | %-15s | %-10s\n', ...
            'Pw (cm)', 'Trans Range', 'Mean', 'Strong Abs Pts', 'Min Location');
    fprintf('%s\n', repmat('-', 1, 70));
    
    for i = 1:length(Pw_values)
        Pw = Pw_values(i);
        
        % Calculate water transmission
        Trans_water = transmission.atmospheric.waterTransmissionOptimizedVectorized(...
            Z_test, Pw, P_test, Lam, 'H2OData', H2O_data);
        
        % Analyze results
        min_trans = min(Trans_water);
        max_trans = max(Trans_water);
        mean_trans = mean(Trans_water);
        [min_val, min_idx] = min(Trans_water);
        strong_absorption_mask = Trans_water < 0.8;  % Strong water absorption
        n_absorbing = sum(strong_absorption_mask);
        
        fprintf('%-8.1f | [%.3f,%.3f] | %-10.6f | %-13d | λ=%.0fnm T=%.3f\n', ...
                Pw, min_trans, max_trans, mean_trans, n_absorbing, Lam(min_idx), min_val);
    end
    
    fprintf('%s\n', repmat('-', 1, 70));
    fprintf('\n✅ MATLAB water transmission analysis complete!\n');
    
    % Show spectral features analysis
    analyze_water_spectral_features(Lam, Pw_values, H2O_data, Z_test, Tair_test, P_test);
end

function run_full_comparison(python_data)
    % Run full Python vs MATLAB comparison
    
    fprintf('=== FULL PYTHON vs MATLAB COMPARISON ===\n\n');
    
    % Test parameters (must match Python script)
    Z_test = python_data.test_conditions.zenith_angle;
    Tair_test = python_data.test_conditions.temperature;
    P_test = python_data.test_conditions.pressure;
    Pw_values = python_data.test_conditions.pw_values;
    
    % Get wavelength array
    Lam = transmission.utils.makeWavelengthArray();
    
    % Load MATLAB water vapor data
    H2O_data = transmission.data.loadAbsorptionDataMemoryOptimized([], {'H2O'}, false);
    
    fprintf('Test conditions: Z=%.1f°, T=%.1f°C, P=%.1f hPa\n', ...
            Z_test, Tair_test, P_test);
    fprintf('Water vapor amounts: %s cm\n\n', mat2str(Pw_values));
    
    fprintf('%-8s | %-15s | %-15s | %-12s | %-12s\n', ...
            'Pw (cm)', 'Python Range', 'MATLAB Range', 'Max Diff', 'Agreement');
    fprintf('%s\n', repmat('-', 1, 75));
    
    total_max_diff = 0;
    perfect_matches = 0;
    
    for i = 1:length(Pw_values)
        Pw = Pw_values(i);
        
        % Get Python results
        python_field = sprintf('pw_%.1f_transmission', Pw);
        python_field = strrep(python_field, '.', '_');
        
        if ~isfield(python_data, python_field)
            fprintf('%-8.1f | Missing Python data\n', Pw);
            continue;
        end
        python_trans = python_data.(python_field);
        
        % Calculate MATLAB results
        matlab_trans = transmission.atmospheric.waterTransmissionOptimizedVectorized(...
            Z_test, Pw, P_test, Lam, 'H2OData', H2O_data);
        
        % Compare results
        python_range = [min(python_trans), max(python_trans)];
        matlab_range = [min(matlab_trans), max(matlab_trans)];
        
        % Calculate differences
        abs_diff = abs(python_trans - matlab_trans);
        max_diff = max(abs_diff);
        
        % Track overall statistics
        total_max_diff = max(total_max_diff, max_diff);
        if max_diff < 1e-14
            perfect_matches = perfect_matches + 1;
        end
        
        % Determine agreement level
        if max_diff < 1e-14
            agreement = 'Perfect';
            status = '✅';
        elseif max_diff < 1e-12
            agreement = 'Excellent';
            status = '✅';
        elseif max_diff < 1e-6
            agreement = 'Good';
            status = '✓';
        else
            agreement = 'Poor';
            status = '⚠️';
        end
        
        fprintf('%s %-6.1f | [%.6f,%.6f] | [%.6f,%.6f] | %.2e | %s\n', ...
                status, Pw, python_range(1), python_range(2), ...
                matlab_range(1), matlab_range(2), max_diff, agreement);
    end
    
    fprintf('%s\n', repmat('-', 1, 75));
    
    % Overall assessment
    fprintf('\n=== VALIDATION SUMMARY ===\n');
    fprintf('Perfect matches: %d/%d water amounts\n', perfect_matches, length(Pw_values));
    fprintf('Maximum difference: %.2e\n', total_max_diff);
    
    if total_max_diff < 1e-14
        fprintf('🎯 PERFECT: All water amounts match at machine precision\n');
    elseif total_max_diff < 1e-6
        fprintf('✅ EXCELLENT: All differences within scientific tolerance\n');
    else
        fprintf('⚠️ WARNING: Some differences exceed tolerance\n');
    end
    
    % Detailed analysis
    analyze_water_differences(python_data, Pw_values, Lam, H2O_data, Z_test, Tair_test, P_test);
    
    fprintf('\n✅ Full water transmission comparison complete!\n');
    fprintf('MATLAB implementation validated against Python original.\n');
end

function analyze_water_spectral_features(Lam, Pw_values, H2O_data, Z_test, Tair_test, P_test)
    % Analyze water vapor spectral absorption features
    
    fprintf('\n=== WATER VAPOR SPECTRAL FEATURES ANALYSIS ===\n\n');
    
    % Calculate for moderate water amount
    Pw_ref = 2.0;  % cm
    Trans_ref = transmission.atmospheric.waterTransmissionOptimizedVectorized(...
        Z_test, Pw_ref, P_test, Lam, 'H2OData', H2O_data);
    
    % Find major absorption bands
    absorption_threshold = 0.5;  % Strong absorption
    strong_abs_mask = Trans_ref < absorption_threshold;
    
    if sum(strong_abs_mask) > 0
        fprintf('Major water vapor absorption bands (Pw=%.1f cm):\n', Pw_ref);
        
        % Group consecutive absorption regions
        abs_wavelengths = Lam(strong_abs_mask);
        abs_transmissions = Trans_ref(strong_abs_mask);
        
        % Find wavelength regions
        diff_wvl = diff(abs_wavelengths);
        band_breaks = find(diff_wvl > 20);  % More than 20nm gap
        
        band_start = 1;
        band_count = 0;
        
        for i = 1:length(band_breaks)+1
            if i <= length(band_breaks)
                band_end = band_breaks(i);
            else
                band_end = length(abs_wavelengths);
            end
            
            if band_end >= band_start
                band_count = band_count + 1;
                wvl_range = abs_wavelengths(band_start:band_end);
                trans_range = abs_transmissions(band_start:band_end);
                
                [min_trans, min_idx] = min(trans_range);
                
                fprintf('  Band %d: %.0f-%.0f nm, deepest absorption T=%.3f at %.0f nm\n', ...
                        band_count, min(wvl_range), max(wvl_range), ...
                        min_trans, wvl_range(min_idx));
            end
            
            band_start = band_end + 1;
        end
    else
        fprintf('No strong absorption bands found (T > %.1f everywhere)\n', absorption_threshold);
    end
    
    % Show water vapor sensitivity
    fprintf('\nWater vapor amount sensitivity:\n');
    for i = 1:length(Pw_values)
        Pw = Pw_values(i);
        Trans = transmission.atmospheric.waterTransmissionOptimizedVectorized(...
            Z_test, Pw, P_test, Lam, 'H2OData', H2O_data);
        
        very_strong_abs = sum(Trans < 0.1);  % Nearly opaque
        strong_abs = sum(Trans < 0.5);       % Strong absorption
        moderate_abs = sum(Trans < 0.8);     % Moderate absorption
        
        fprintf('  Pw=%.1f cm: %d opaque, %d strong, %d moderate absorption points\n', ...
                Pw, very_strong_abs, strong_abs, moderate_abs);
    end
end

function analyze_water_differences(python_data, Pw_values, Lam, H2O_data, Z_test, Tair_test, P_test)
    % Analyze differences between Python and MATLAB implementations
    
    fprintf('\n=== DETAILED DIFFERENCE ANALYSIS ===\n\n');
    
    for i = 1:length(Pw_values)
        Pw = Pw_values(i);
        
        % Get Python results
        python_field = sprintf('pw_%.1f_transmission', Pw);
        python_field = strrep(python_field, '.', '_');
        
        if ~isfield(python_data, python_field)
            continue;
        end
        
        python_trans = python_data.(python_field);
        
        % Calculate MATLAB results
        matlab_trans = transmission.atmospheric.waterTransmissionOptimizedVectorized(...
            Z_test, Pw, P_test, Lam, 'H2OData', H2O_data);
        
        % Analyze differences
        abs_diff = abs(python_trans - matlab_trans);
        max_diff = max(abs_diff);
        mean_diff = mean(abs_diff);
        
        % Find largest differences
        [~, max_idx] = max(abs_diff);
        
        % Analyze where differences occur
        strong_abs_mask = python_trans < 0.5;
        weak_abs_mask = python_trans > 0.9;
        
        if sum(strong_abs_mask) > 0
            strong_abs_diff = mean(abs_diff(strong_abs_mask));
        else
            strong_abs_diff = 0;
        end
        
        if sum(weak_abs_mask) > 0
            weak_abs_diff = mean(abs_diff(weak_abs_mask));
        else
            weak_abs_diff = 0;
        end
        
        fprintf('Pw=%.1f cm analysis:\n', Pw);
        fprintf('  Max difference: %.2e at λ=%.0f nm\n', max_diff, Lam(max_idx));
        fprintf('  Mean difference: %.2e\n', mean_diff);
        fprintf('  Strong absorption regions: %.2e\n', strong_abs_diff);
        fprintf('  Weak absorption regions: %.2e\n', weak_abs_diff);
        fprintf('  Python min/mean: %.6f/%.6f\n', min(python_trans), mean(python_trans));
        fprintf('  MATLAB min/mean: %.6f/%.6f\n\n', min(matlab_trans), mean(matlab_trans));
    end
end